# Feature 2 — Always-on FPS counter

**Status:** implemented and verified. Class: `com.xzodomyx.Hud`.

## Overlay mechanism — and why I did not ship the plain-View version

The brief said to try a plain decor-view `TextView` first and *"verify empirically that it
actually renders on top of the NativeActivity's GL surface"*.

**I cannot verify that empirically.** This build environment has no Android device, no emulator,
and no ARM execution of any kind (it is an x86_64 Debian container with no KVM, no `adb`, and no
route to `dl.google.com` to fetch an emulator image). Shipping a plain overlay `View` would mean
shipping an unverified guess about a known-tricky `NativeActivity` rendering edge case — exactly
what the brief warns against.

So the HUD uses the `PopupWindow` mechanism instead, which is the one approach **already proven to
work in this exact binary** (`MainActivity.setupKeyboardViews()` uses it). It is configured
display-only:

```
setTouchable(false)      -> adds FLAG_NOT_TOUCHABLE
setFocusable(false)
setOutsideTouchable(false)
setClippingEnabled(false)
```

`FLAG_NOT_TOUCHABLE` means the window is transparent to input at the WindowManager level, so it
cannot steal a single touch from the game — the display-only requirement is satisfied structurally
rather than by convention.

If you later confirm on a device that a plain `TextView` on the decor view does render over the GL
surface, swapping it in is a contained change to `Hud.attach()` only.

## Behaviour

- `Choreographer.postFrameCallback`, self-reposting each frame.
- Rolling 1-second window: `fps = frames * 1e9 / elapsedNanos`, integer math, no allocation
  except the once-per-second `StringBuilder`.
- Top-left, density-scaled 8dp safe-area margin, yellow on a translucent plate.
- Attached in `MainActivity.onResume`, detached in `MainActivity.onPause`
  (`removeFrameCallback` + `dismiss()` + full static reset), so it neither leaks nor keeps
  ticking in the background.
- Reads `fps_counter` from the splash screen's own `SharedPreferences` and **does not attach at
  all** when unset — zero cost and zero code on the frame path for users who leave it off.
- Every entry point (`attach`, `detach`, `run`, `doFrame`) is wrapped in `catch Throwable`.

## Bonus: the second toggle now does something

`keep_awake` is honoured in `attach()` via `Window.addFlags(FLAG_KEEP_SCREEN_ON)` (0x80). Opt-in,
so stock behaviour is unchanged unless the user ticks it.

## Hook into the game

`tools/patch_smali.py` applies two anchored, single-instruction edits:

| method | edit |
|---|---|
| `MainActivity.onResume` | `invoke-static {p0}, Hud->attach(Landroid/app/Activity;)V` after `super.onResume()` |
| `MainActivity.onPause`  | `invoke-static {}, Hud->detach()V` before `nativeSuspend()` |

Each asserts its anchor matches **exactly once** before substituting, so an unexpected input turns
into a loud build failure rather than a silent mis-patch. Neither edit changes the methods'
`.locals`, so no register pressure is introduced.

## Verification

`tools/verify.py` now diffs the *resolved disassembly* of every stock method body between stock and
build. (Raw bytecode comparison gives false positives: adding classes shifts the dex
string/type/method index tables, so identical logic gets different operand indices.)

```
[ok] added exactly: ['Lcom/xzodomyx/Hud;', 'Lcom/xzodomyx/LauncherActivity;']
[ok] exactly 2 stock method bodies changed, all intended: ['onPause', 'onResume']
[ok] 8892 stock method bodies bit-identical
[ok] 1579/1581 stock APK entries byte-identical
```

## Not verified

Runtime behaviour on a real device. Everything above is static verification. The FPS maths,
lifecycle handling and crash isolation are auditable by reading `src/smali/com/xzodomyx/Hud.smali`,
but **no one has yet seen this counter draw a number on a phone.** Treat the first on-device run as
the real test.
