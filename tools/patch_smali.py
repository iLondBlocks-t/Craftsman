#!/usr/bin/env python3
"""Apply anchored edits to the game's own decompiled smali.

Every edit asserts its anchor occurs EXACTLY once before substituting, so a future
apktool/version change turns into a loud build failure instead of a silently
mis-applied or half-applied patch.

Current edits (Feature 2): attach/detach the FPS HUD on MainActivity's resume/pause.
Both are single invoke-static calls with no arguments beyond `this`, so neither
changes any method's register requirements.
"""
import sys

MAIN = 'smali/com/mojang/minecraftpe/MainActivity.smali'

EDITS = [
    # ---- FPS HUD attach: immediately after super.onResume() -----------------
    (MAIN,
     'attach HUD in onResume',
     """    .line 813
    invoke-super {p0}, Landroid/app/NativeActivity;->onResume()V
""",
     """    .line 813
    invoke-super {p0}, Landroid/app/NativeActivity;->onResume()V

    invoke-static {p0}, Lcom/xzodomyx/Hud;->attach(Landroid/app/Activity;)V
"""),

    # ---- FPS HUD detach: before the game suspends itself --------------------
    (MAIN,
     'detach HUD in onPause',
     """    .line 830
    invoke-virtual {p0}, Lcom/mojang/minecraftpe/MainActivity;->nativeSuspend()V
""",
     """    .line 830
    invoke-static {}, Lcom/xzodomyx/Hud;->detach()V

    invoke-virtual {p0}, Lcom/mojang/minecraftpe/MainActivity;->nativeSuspend()V
"""),
]


def main(dec_dir):
    for rel, label, old, new in EDITS:
        path = '%s/%s' % (dec_dir, rel)
        src = open(path).read()
        # Idempotency must be checked BEFORE the anchor assertion: applying an edit
        # can consume its own anchor, so on a re-run over an existing build/dec the
        # anchor legitimately matches zero times.
        if new.strip() in src:
            print('  = %s (already applied)' % label)
            continue
        n = src.count(old)
        if n != 1:
            sys.exit('!! anchor for %r matched %d times (expected 1) in %s' % (label, n, rel))
        open(path, 'w').write(src.replace(old, new, 1))
        print('  + %s' % label)


if __name__ == '__main__':
    main(sys.argv[1])
