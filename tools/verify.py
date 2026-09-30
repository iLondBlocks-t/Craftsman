#!/usr/bin/env python3
"""Post-build verification.

The headline requirement is "stock behaviour 100% unchanged except for the additions",
so this checks that claim mechanically rather than by eyeballing:

  1. every stock entry is byte-identical, except the two we meant to change
  2. the manifest changed in exactly the intended way
  3. the dex gained exactly the intended classes
  4. STORED entries are 4-byte aligned (zipalign)
  5. the v1 signature is internally consistent and covers every entry
"""
import base64
import hashlib
import struct
import sys
import zipfile

sys.path.insert(0, __file__.rsplit('/', 1)[0])

STOCK, MODDED = sys.argv[1], sys.argv[2]
fails, warns = [], []


def ok(msg):
    print('  [ok]   %s' % msg)


def bad(msg):
    fails.append(msg)
    print('  [FAIL] %s' % msg)


print('== 1. stock content preserved ==')
za, zb = zipfile.ZipFile(STOCK), zipfile.ZipFile(MODDED)
na = {n for n in za.namelist() if not n.startswith('META-INF/')}
nb = {n for n in zb.namelist() if not n.startswith('META-INF/')}
EXPECTED_CHANGED = {'classes.dex', 'AndroidManifest.xml'}
_mf = 'build/textures/MANIFEST.txt'
import os as _os
if _os.path.exists(_mf):
    EXPECTED_CHANGED |= {l.strip() for l in open(_mf) if l.strip()}

if na - nb:
    bad('entries missing from build: %s' % sorted(na - nb)[:5])
else:
    ok('no stock entries lost (%d checked)' % len(na))
if nb - na:
    bad('unexpected new entries: %s' % sorted(nb - na)[:5])
else:
    ok('no unexpected new entries')

changed = []
for n in sorted(na & nb):
    if hashlib.sha256(za.read(n)).digest() != hashlib.sha256(zb.read(n)).digest():
        changed.append(n)
if set(changed) == EXPECTED_CHANGED:
    ok('exactly %d intended entries differ (2 code + %d textures); '
       'other %d entries byte-identical'
       % (len(changed), len(changed) - 2, len(na) - len(changed)))
else:
    unexp = sorted(set(changed) - EXPECTED_CHANGED)
    miss = sorted(EXPECTED_CHANGED - set(changed))
    if unexp:
        bad('UNINTENDED entry changes: %s' % unexp[:6])
    if miss:
        bad('expected change missing: %s' % miss[:6])

# Feature E safety: restyled textures must keep identical pixel dimensions
try:
    from PIL import Image as _Im
    import io as _io
    dims = [(n, _Im.open(_io.BytesIO(za.read(n))).size, _Im.open(_io.BytesIO(zb.read(n))).size)
            for n in changed if n.endswith('.png')]
    off = [d for d in dims if d[1] != d[2]]
    if off:
        bad('texture dimension drift: %s' % off[:4])
    elif dims:
        ok('all %d restyled textures keep stock dimensions' % len(dims))
except ImportError:
    pass

print('== 2. manifest ==')
from androguard.core.apk import APK  # noqa: E402
A, B = APK(STOCK), APK(MODDED)
checks = [
    ('package', A.get_package(), B.get_package()),
    ('versionName', A.get_androidversion_name(), B.get_androidversion_name()),
    ('versionCode', A.get_androidversion_code(), B.get_androidversion_code()),
    ('minSdk', A.get_min_sdk_version(), B.get_min_sdk_version()),
    ('targetSdk', A.get_target_sdk_version(), B.get_target_sdk_version()),
    ('permissions', sorted(A.get_permissions()), sorted(B.get_permissions())),
    ('receivers', sorted(A.get_receivers()), sorted(B.get_receivers())),
]
for label, x, y in checks:
    (ok if x == y else bad)('%s unchanged: %r' % (label, x) if x == y
                            else '%s changed %r -> %r' % (label, x, y))

if B.get_main_activity() == 'com.xzodomyx.LauncherActivity':
    ok('launcher activity is now com.xzodomyx.LauncherActivity')
else:
    bad('main activity is %r' % B.get_main_activity())
if 'com.mojang.minecraftpe.MainActivity' in B.get_activities():
    ok('MainActivity still declared')
else:
    bad('MainActivity missing!')

mx = B.get_android_manifest_axml().get_xml().decode()
if 'android.app.lib_name' in mx and 'minecraftpe' in mx:
    ok('NativeActivity lib_name meta-data intact')
else:
    bad('lib_name meta-data lost -- game would not start')
if 'android.intent.category.BROWSABLE' in mx:
    ok('minecraft: VIEW/BROWSABLE filter retained on MainActivity')
else:
    bad('VIEW filter lost')

print('== 3. dex ==')
from androguard.core.dex import DEX  # noqa: E402
da, db = DEX(za.read('classes.dex')), DEX(zb.read('classes.dex'))
ca = {c.get_name() for c in da.get_classes()}
cb = {c.get_name() for c in db.get_classes()}
added, removed = cb - ca, ca - cb
if removed:
    bad('classes removed from stock dex: %s' % sorted(removed)[:5])
else:
    ok('no stock classes removed (%d intact)' % len(ca))
EXPECTED_NEW = {'Lcom/xzodomyx/LauncherActivity;', 'Lcom/xzodomyx/Hud;',
                'Lcom/xzodomyx/FpsView;', 'Lcom/xzodomyx/Rec;',
                'Lcom/xzodomyx/Rec$1;', 'Lcom/xzodomyx/RecButton;', 'Lcom/xzodomyx/Hud$1;'}
if added == EXPECTED_NEW:
    ok('added exactly: %s' % sorted(added))
else:
    bad('unexpected added classes: %s (expected %s)' % (sorted(added), sorted(EXPECTED_NEW)))

ma = {(m.get_class_name(), m.get_name(), m.get_descriptor()) for m in da.get_methods()}
mb = {(m.get_class_name(), m.get_name(), m.get_descriptor()) for m in db.get_methods()}
stock_missing = {m for m in ma - mb}
if stock_missing:
    bad('stock methods missing: %d e.g. %s' % (len(stock_missing), list(stock_missing)[:2]))
else:
    ok('all %d stock method signatures present' % len(ma))

# Bytecode-level diff: which stock method BODIES actually changed?
# This is the check that proves we did not disturb game logic anywhere else.
EXPECTED_PATCHED = {
    ('Lcom/mojang/minecraftpe/MainActivity;', 'onResume', '()V'),
    ('Lcom/mojang/minecraftpe/MainActivity;', 'onPause', '()V'),
}


def bodies(dex):
    # NB: DEX.get_methods() yields MethodIdItem (no code); EncodedMethod, which
    # actually carries the bytecode, only comes from the class defs.
    out = {}
    for cls in dex.get_classes():
        for m in cls.get_methods():
            key = (m.get_class_name(), m.get_name(), m.get_descriptor())
            c = m.get_code()
            if c is None:
                out[key] = ''
                continue
            # Compare *resolved* disassembly, not raw bytes: adding classes shifts the
            # dex string/type/method index tables, so identical logic has different
            # operand indices. get_output() resolves those back to names.
            out[key] = '\n'.join(
                '%s %s' % (i.get_name(), i.get_output())
                for i in c.get_bc().get_instructions())
    return out


ba, bb = bodies(da), bodies(db)
touched = {k for k in ma & mb if ba.get(k) != bb.get(k)}
if touched == EXPECTED_PATCHED:
    ok('exactly %d stock method bodies changed, all intended: %s'
       % (len(touched), sorted(n for _, n, _ in touched)))
else:
    unexpected = touched - EXPECTED_PATCHED
    missing = EXPECTED_PATCHED - touched
    if unexpected:
        bad('UNINTENDED stock code changes: %s' % sorted(unexpected)[:5])
    if missing:
        bad('expected hook not applied: %s' % sorted(missing))

if not touched - EXPECTED_PATCHED:
    ok('%d stock method bodies bit-identical' % (len(ma & mb) - len(touched)))

print('== 3b. HUD init ordering ==')
# Regression guard: sActivity/sMargin/sAnchor must all be written BEFORE
# buildRec runs, otherwise the REC overlay has no anchor and never appears.
# This bug shipped once; the check exists so it cannot ship again.
_hud = {c.get_name(): c for c in db.get_classes()}.get('Lcom/xzodomyx/Hud;')
if _hud is None:
    bad('Hud class missing')
else:
    _att = [m for m in _hud.get_methods() if m.get_name() == 'attach']
    _seq = []
    for _i in _att[0].get_code().get_bc().get_instructions():
        _o = _i.get_output()
        for _k in ('sActivity', 'sMargin', 'sAnchor', 'buildRec'):
            if _k in _o:
                _seq.append((_i.get_name(), _k))

    def _first(k, pre=None):
        for _n, (_op, _kk) in enumerate(_seq):
            if _kk == k and (pre is None or _op.startswith(pre)):
                return _n
        return 999

    _b = _first('buildRec')
    for _f in ('sActivity', 'sMargin', 'sAnchor'):
        if _first(_f, 'sput') < _b:
            ok('%s initialised before buildRec' % _f)
        else:
            bad('%s written AFTER buildRec -- REC button would never appear' % _f)

print('== 3c. recorder semantics ==')
# The pause/stop wiring inverted itself once during development (the REC button
# paused and leaving the game stopped, instead of the reverse). These read the
# SHIPPED dex so that can never go out unnoticed.
_cl = {c.get_name(): c for c in db.get_classes()}


def _ins(cn, mn):
    _c = _cl.get(cn)
    if _c is None:
        return []
    for _m in _c.get_methods():
        if _m.get_name() == mn and _m.get_code():
            return [_i.get_name() + ' ' + _i.get_output()
                    for _i in _m.get_code().get_bc().get_instructions()]
    return []


_R, _H = 'Lcom/xzodomyx/Rec;', 'Lcom/xzodomyx/Hud;'
_st, _run, _sp = _ins(_R, 'start'), _ins(_R, 'run'), _ins(_R, 'setPaused')
_at, _dt = _ins(_H, 'attach'), _ins(_H, 'detach')
_ot, _sr = _ins(_H, 'onRecTapped'), _ins(_H, 'showRec')

for _label, _cond in [
    ('encoder i-frame-interval is 5, not 1',
     any('i-frame-interval' in o for o in _st)
     and any(o.strip().endswith(', 5') for o in _st)),
    ('encoder sets repeat-previous-frame-after',
     any('repeat-previous-frame-after' in o for o in _st)),
    ('drain thread runs at background priority',
     any('setPriority' in o for o in _st)),
    ('encoder width capped via sMaxW', any('sMaxW' in o for o in _st)),
    ('drain loop blocks 100ms, does not spin at 10ms',
     any('100000' in o for o in _run) and not any('10000,' in o for o in _run)),
    ('drain loop drops frames while sPaused', any('sPaused' in o for o in _run)),
    ('drain loop removes the paused gap from PTS',
     any('sSkipUs' in o for o in _run)
     and any(o.startswith('iput-wide') and 'presentationTimeUs' in o for o in _run)),
    ('resume requests a keyframe',
     any('request-sync' in o for o in _sp) and any('setParameters' in o for o in _sp)),
    ('attach() resumes capture', any('setPaused' in o for o in _at)),
    ('detach() PAUSES and does not stop',
     any('setPaused' in o for o in _dt) and not any('Rec;->stop' in o for o in _dt)),
    ('REC button still STOPS', any('Rec;->stop' in o for o in _ot)),
    ('showRec() will not show while recording', any('isRecording' in o for o in _sr)),
]:
    (ok if _cond else bad)(_label)

print('== 3d. encoder selection ==')
# createEncoderByType() returns whatever the platform lists first for video/avc,
# which on many mid-range devices is the Google SOFTWARE encoder. That is the
# difference between recording being free and recording eating the game's CPU.
_pk, _mk, _st2 = _ins(_R, 'pickEncoderName'), _ins(_R, 'makeCodec'), _ins(_R, 'start')
for _label, _cond in [
    ('encoder list is enumerated',
     any('getCodecCount' in o for o in _pk) and any('getCodecInfoAt' in o for o in _pk)),
    ('software encoders (OMX.google.*, c2.android.*) are skipped',
     any('OMX.google.' in o for o in _pk) and any('c2.android.' in o for o in _pk)),
    ('only video/avc encoders are considered',
     any('video/avc' in o for o in _pk) and any('isEncoder' in o for o in _pk)),
    ('makeCodec prefers createByCodecName', any('createByCodecName' in o for o in _mk)),
    ('makeCodec still falls back rather than failing to record',
     any('createEncoderByType' in o for o in _mk)),
    ('start() goes through makeCodec',
     any('makeCodec' in o for o in _st2)
     and not any('createEncoderByType' in o for o in _st2)),
    ('frame rate is 24 in low-lag and 30 otherwise',
     any(o.strip().endswith(', 24') for o in _st2)
     and any(o.strip().endswith(', 30') for o in _st2)),
    ('chosen encoder name is surfaced to the user',
     any('sCodecName' in o for o in _st2) and any('toast' in o for o in _st2)),
]:
    (ok if _cond else bad)(_label)

print('== 4. zipalign ==')
raw = open(MODDED, 'rb').read()
misaligned = 0
with zipfile.ZipFile(MODDED) as z:
    for i in z.infolist():
        if i.compress_type != zipfile.ZIP_STORED:
            continue
        lo = i.header_offset
        nlen, elen = struct.unpack_from('<HH', raw, lo + 26)
        if (lo + 30 + nlen + elen) % 4:
            misaligned += 1
if misaligned:
    bad('%d STORED entries not 4-byte aligned' % misaligned)
else:
    ok('all STORED entries 4-byte aligned')

print('== 5. v1 signature ==')
mf = zb.read('META-INF/MANIFEST.MF')
sf = zb.read('META-INF/CERT.SF')
p7 = zb.read('META-INF/CERT.RSA')


def parse_sections(blob):
    out = {}
    for chunk in blob.split(b'\r\n\r\n'):
        if not chunk.strip():
            continue
        lines = dict(l.split(b': ', 1) for l in chunk.split(b'\r\n') if b': ' in l)
        if b'Name' in lines:
            out[lines[b'Name'].decode()] = lines
    return out


sections = parse_sections(mf)
signed_entries = {n for n in zb.namelist() if not n.startswith('META-INF/')}
if set(sections) == signed_entries:
    ok('MANIFEST.MF covers all %d entries' % len(sections))
else:
    bad('manifest coverage gap: %s' % sorted(signed_entries ^ set(sections))[:5])

bad_digest = [n for n, h in sections.items()
              if base64.b64encode(hashlib.sha256(zb.read(n)).digest()) != h[b'SHA-256-Digest']]
if bad_digest:
    bad('%d wrong digests, e.g. %s' % (len(bad_digest), bad_digest[:3]))
else:
    ok('every SHA-256 entry digest matches actual content')

sfd = dict(l.split(b': ', 1) for l in sf.split(b'\r\n\r\n')[0].split(b'\r\n') if b': ' in l)
if sfd[b'SHA-256-Digest-Manifest'] == base64.b64encode(hashlib.sha256(mf).digest()):
    ok('CERT.SF manifest digest matches MANIFEST.MF')
else:
    bad('CERT.SF manifest digest mismatch')

from cryptography.hazmat.primitives.serialization import pkcs7 as _p7  # noqa: E402
try:
    certs = _p7.load_der_pkcs7_certificates(p7)
    ok('CERT.RSA parses as PKCS#7, %d cert(s), subject: %s'
       % (len(certs), certs[0].subject.rfc4514_string()))
except Exception as e:  # pragma: no cover
    bad('CERT.RSA unparseable: %s' % e)

print()
print('MB: %.2f (limit 100)' % (len(raw) / 1048576.0))
print('RESULT: %s' % ('ALL CHECKS PASSED' if not fails else '%d FAILURE(S)' % len(fails)))
sys.exit(1 if fails else 0)
