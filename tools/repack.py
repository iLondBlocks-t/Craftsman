#!/usr/bin/env python3
"""Repack + zipalign + v1-sign the modified APK.

Neither `zipalign` nor `apksigner` is obtainable in this sandbox (see docs/00-RECON.md
section 6), so both are implemented here directly.

The repack copies every entry's *raw compressed bytes* straight out of the stock APK and
only substitutes classes.dex and AndroidManifest.xml. Nothing else is recompressed, so
all 1580+ assets, resources.arsc and the three armeabi-v7a .so files come out
bit-for-bit identical to the original.
"""
import argparse
import base64
import hashlib
import os
import struct
import sys
import zlib

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives.serialization import pkcs7, pkcs12
from cryptography.x509.oid import NameOID
import datetime

EOCD_SIG = b'PK\x05\x06'
CEN_SIG = b'PK\x01\x02'
LOC_SIG = b'PK\x03\x04'
STORED, DEFLATED = 0, 8


class Entry:
    __slots__ = ('name', 'method', 'crc', 'csize', 'usize', 'raw', 'extra',
                 'flag', 'time', 'date', 'attr_int', 'attr_ext')


def read_zip(path):
    d = open(path, 'rb').read()
    i = d.rfind(EOCD_SIG)
    assert i >= 0, 'no EOCD'
    total, cd_size, cd_off = struct.unpack_from('<HII', d, i + 10)
    entries = []
    p = cd_off
    for _ in range(total):
        assert d[p:p + 4] == CEN_SIG
        (_ver, _vneed, flag, method, time, date, crc, csize, usize,
         nlen, elen, clen, _disk, attr_int, attr_ext, loc_off) = \
            struct.unpack_from('<HHHHHHIIIHHHHHII', d, p + 4)
        name = d[p + 46:p + 46 + nlen]
        extra = d[p + 46 + nlen:p + 46 + nlen + elen]
        p += 46 + nlen + elen + clen

        # This APK was built with streaming data descriptors (flag bit 3), so the
        # local headers carry zero sizes. The central directory is authoritative;
        # we rewrite proper local headers below and clear the flag.
        flag &= ~0x8
        # walk the local header to find where the payload actually starts
        assert d[loc_off:loc_off + 4] == LOC_SIG
        lnlen, lelen = struct.unpack_from('<HH', d, loc_off + 26)
        data_off = loc_off + 30 + lnlen + lelen

        e = Entry()
        e.name, e.method, e.crc = name, method, crc
        e.csize, e.usize = csize, usize
        e.raw = d[data_off:data_off + csize]
        e.extra = extra
        e.flag, e.time, e.date = flag, time, date
        e.attr_int, e.attr_ext = attr_int, attr_ext
        entries.append(e)
    return entries


def inflate(e):
    if e.method == STORED:
        return e.raw
    return zlib.decompressobj(-15).decompress(e.raw)


def make_entry(name, data, method=DEFLATED):
    e = Entry()
    e.name = name if isinstance(name, bytes) else name.encode()
    e.method = method
    e.crc = zlib.crc32(data) & 0xFFFFFFFF
    e.usize = len(data)
    if method == DEFLATED:
        co = zlib.compressobj(9, zlib.DEFLATED, -15)
        e.raw = co.compress(data) + co.flush()
    else:
        e.raw = data
    e.csize = len(e.raw)
    e.extra = b''
    e.flag = 0
    e.time, e.date = 0x0000, 0x2821   # fixed timestamp -> reproducible builds
    e.attr_int, e.attr_ext = 0, 0
    return e


def write_zip(path, entries, align=4):
    out = bytearray()
    cd = bytearray()
    for e in entries:
        # zipalign: uncompressed payloads must begin on a 4-byte boundary so they
        # can be mmap'd in place by the runtime.
        extra = e.extra
        if e.method == STORED and align:
            pos = len(out) + 30 + len(e.name) + len(extra)
            pad = (align - (pos % align)) % align
            extra = extra + b'\0' * pad
        loc_off = len(out)
        out += struct.pack('<IHHHHHIIIHH', 0x04034B50, 20, e.flag, e.method,
                           e.time, e.date, e.crc, e.csize, e.usize,
                           len(e.name), len(extra))
        out += e.name + extra + e.raw
        cd += struct.pack('<IHHHHHHIIIHHHHHII', 0x02014B50, 20, 20, e.flag, e.method,
                          e.time, e.date, e.crc, e.csize, e.usize,
                          len(e.name), len(e.extra), 0, 0, e.attr_int, e.attr_ext, loc_off)
        cd += e.name + e.extra
    cd_off = len(out)
    out += cd
    out += struct.pack('<IHHHHIIH', 0x06054B50, 0, 0, len(entries), len(entries),
                       len(cd), cd_off, 0)
    open(path, 'wb').write(out)
    return len(out)


# ---------------------------------------------------------------- signing

def load_or_create_key(p12_path, password=b'xzodomyx'):
    if os.path.exists(p12_path):
        key, cert, _ = pkcs12.load_key_and_certificates(open(p12_path, 'rb').read(), password)
        return key, cert
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, 'XZO-Domyx PE'),
        x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, 'Modding'),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, 'XZO-Domyx'),
    ])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (x509.CertificateBuilder()
            .subject_name(subject).issuer_name(subject)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=365 * 30))
            .sign(key, hashes.SHA256()))
    blob = pkcs12.serialize_key_and_certificates(
        b'xzodomyx', key, cert, None,
        serialization.BestAvailableEncryption(password))
    open(p12_path, 'wb').write(blob)
    print('  * generated new signing key -> %s (password: %s)'
          % (p12_path, password.decode()))
    return key, cert


def b64(x):
    return base64.b64encode(x).decode()


def sign_v1(entries, key, cert):
    """Classic JAR signing. Sufficient here: the app targets SDK 22, and the
    'must have v2+' rule only applies to APKs targeting SDK 30+."""
    signed = [e for e in entries if not e.name.startswith(b'META-INF/')]

    mf = b'Manifest-Version: 1.0\r\nCreated-By: XZO-Domyx PE build\r\n\r\n'
    sections = []
    for e in signed:
        digest = hashlib.sha256(inflate(e)).digest()
        sec = b'Name: ' + e.name + b'\r\nSHA-256-Digest: ' + b64(digest).encode() + b'\r\n\r\n'
        sections.append((e.name, sec))
        mf += sec

    sf = (b'Signature-Version: 1.0\r\nCreated-By: XZO-Domyx PE build\r\n'
          b'SHA-256-Digest-Manifest: ' + b64(hashlib.sha256(mf).digest()).encode() + b'\r\n\r\n')
    for name, sec in sections:
        sf += (b'Name: ' + name + b'\r\nSHA-256-Digest: '
               + b64(hashlib.sha256(sec).digest()).encode() + b'\r\n\r\n')

    p7 = (pkcs7.PKCS7SignatureBuilder()
          .set_data(sf)
          .add_signer(cert, key, hashes.SHA256())
          .sign(serialization.Encoding.DER,
                [pkcs7.PKCS7Options.DetachedSignature,
                 pkcs7.PKCS7Options.Binary,
                 pkcs7.PKCS7Options.NoCapabilities]))

    return [make_entry('META-INF/MANIFEST.MF', mf),
            make_entry('META-INF/CERT.SF', sf),
            make_entry('META-INF/CERT.RSA', p7)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', required=True, help='stock APK')
    ap.add_argument('--dex', required=True)
    ap.add_argument('--manifest', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--keystore', default='xzodomyx.p12')
    a = ap.parse_args()

    entries = read_zip(a.base)
    print('  * stock APK: %d entries' % len(entries))

    new_dex = open(a.dex, 'rb').read()
    new_mf = open(a.manifest, 'rb').read()

    out, replaced, dropped = [], [], 0
    for e in entries:
        if e.name.startswith(b'META-INF/'):
            dropped += 1
            continue
        if e.name == b'classes.dex':
            out.append(make_entry('classes.dex', new_dex, e.method))
            replaced.append('classes.dex')
        elif e.name == b'AndroidManifest.xml':
            out.append(make_entry('AndroidManifest.xml', new_mf, e.method))
            replaced.append('AndroidManifest.xml')
        else:
            out.append(e)                      # raw bytes, untouched
    print('  * replaced: %s' % ', '.join(replaced))
    print('  * dropped %d old signature entries' % dropped)
    print('  * carried over %d entries byte-for-byte' % (len(out) - len(replaced)))

    key, cert = load_or_create_key(a.keystore)
    sigs = sign_v1(out, key, cert)
    size = write_zip(a.out, sigs + out)
    print('  * wrote %s (%.1f MB)' % (a.out, size / 1048576.0))


if __name__ == '__main__':
    main()
