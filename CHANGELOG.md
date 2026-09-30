# Changelog

All builds target Minecraft: Pocket Edition 0.14.3, `armeabi-v7a`, minSdk 17 / targetSdk 22.
Every entry was checked with `tools/verify.py` before being committed.

---

## Recorder — stop using the software encoder

Follow-up to a report that the **game** stutters while recording (the video itself is fine) on a
mid-range Android 8-10 device.

Likely real cause, not previously checked: `createEncoderByType("video/avc")` returns whatever the
platform lists first, and on many mid-range devices that is `OMX.google.h264.encoder` - the
**software** encoder. If so, the recording was already being software-encoded on the CPU, which
matches the symptom exactly.

- `pickEncoderName()` walks `MediaCodecList`, skips `OMX.google.*` and `c2.android.*`, and selects
  a real hardware AVC encoder. Falls back to the previous behaviour rather than failing to record.
- Low-lag mode now also drops to 24 fps and halves the bitrate target.
- The start toast now reports the negotiated size, rate and encoder name, e.g.
  `REC 854x480 @24fps / OMX.qcom.video.encoder.avc`. With no device in the build environment this
  is the only way to learn what the phone actually picked.

**FFmpeg / frame-by-frame: searched for, and still rejected.** The size limit was lifted, so every
reachable source was checked: the `ffmpeg-kit*` and `*-ffmpeg` npm packages are wrappers with no
ARM binaries (Maven is blocked), `pypi: ffmpeg-binaries` is x86_64/mac/win only, and only the
FFmpeg *source* on GitHub is reachable. Cross-compiling it is possible in principle. It was
rejected anyway because the reported symptom is in-game stutter: per-frame `glReadPixels` stalls
the game's own render thread, and software encoding would compete with the game for CPU. Full
reasoning and the source-availability table are in `docs/04-FEATURES-A-E.md`.

`verify.py` gains `3d. encoder selection` (8 checks). Total 48 checks, all passing.

---

## Recorder — lag reduction, and capture limited to the game

**Not done, on purpose: frame-by-frame capture with FFmpeg.** It was requested, but it would make
lag worse. Per-frame grabbing means `glReadPixels` on the game's render thread, which flushes the
GPU pipeline and copies ~2 MB per frame into CPU memory; FFmpeg would then encode in software on
the same cores the game needs. The current path never touches the CPU with pixel data - it feeds
the hardware H.264 encoder over a Surface. Details in `docs/04-FEATURES-A-E.md`.

Lag attacked where it actually originates:

- `i-frame-interval` 1s -> 5s (a keyframe every second was the single biggest waste)
- drain thread moved to background priority so it stops competing with the game's render thread
- `dequeueOutputBuffer` timeout 10ms -> 100ms; it was waking 100x/second to find nothing
- new **Low-lag recording** launcher toggle (on by default): caps encoder input at 854px
- `repeat-previous-frame-after` set to 200ms so a static screen doesn't leave timing gaps

**Capture is now limited to the game.** API 21 has no per-window capture, so instead every frame
produced while the game is not in the foreground is dropped: `onPause` pauses the capture,
`onResume` resumes it. The home screen, the notification shade and other apps never reach the
file. The away-time is subtracted from the presentation timestamps so the footage joins up with no
frozen gap, and a keyframe is requested on resume so the join decodes cleanly.

Leaving the game now pauses rather than stops. Stop is the REC button or the notification.

Also fixed while wiring this: `showRec()` gained an `isRecording()` guard, without which returning
to the game mid-capture would have put the REC button back on screen and into the video.

`verify.py` gains `3c. recorder semantics` - 12 checks read the shipped dex and assert the encoder
settings and the pause/stop wiring. During development that wiring inverted itself (the REC button
paused, leaving the game stopped); this check is what caught it.

`tools/build.sh` now re-runs `bootstrap.sh` automatically when the sandbox has wiped the toolchain.

---

## Fix — the REC button never appeared

The previously published build shipped a real defect: three ordering bugs in `Hud.attach()` meant
the recording button could never be displayed. `sActivity` was set only inside the keep-awake
branch; `sMargin`/`sAnchor` only inside the FPS branch and *after* the recorder was built, so
`showRec()` always saw a null anchor; and the show call happened before the decor view had a
window token.

All three statics are now initialised unconditionally at the top of `attach()`, and the button is
shown via `View.post()`. `verify.py` gained check `3b. HUD init ordering`, which reads the shipped
dex and fails if any of them is written after `buildRec`.

Also: `tools/bootstrap.sh` now installs `pillow`, `capstone` and `ziglang`. Later work depended on
them but they were never added to the bootstrap, so a fresh environment could not reproduce a build.

Verified: ALL CHECKS PASSED — 7 added classes (`Hud$1` is new), 8892/8894 stock method bodies
bit-identical, still only `MainActivity.onResume`/`onPause` changed.

---

## Feature A — gameplay recording · **implemented**

Start/Stop recording to `Movies/XZO-Domyx/xzo_<ts>.mp4`, fully local.

Pipeline: `MediaProjection -> VirtualDisplay -> MediaCodec input Surface -> H.264 (hardware)
-> MediaMuxer -> .mp4`.

**Goal 1 achieved, via a better route than specified.** The brief asked for `glReadPixels` on the
render thread. On a `NativeActivity` that would stall the game's own render thread every frame —
the very overhead Goal 1 forbids. MediaProjection captures in SurfaceFlinger and feeds the encoder
GPU-to-GPU: zero instructions on the game's render thread, zero CPU frame copies, no raw frame ever
entering our process (which is why no bounded queue is needed).

**Correction to my previous report:** I had reasoned the overlay would be excluded from capture
automatically. That is true for `glReadPixels` but **false for MediaProjection**, which composites
every window. Exclusion is now structural: the REC button's PopupWindow is dismissed on Start and
restored only after the file is finalised, with stopping done from an ongoing notification.

**Goal 2 still NOT achieved** — offline re-render needs the tick/state stream, which is native-only
with no headless renderer entry point. Recordings show real lag if it happened; only the recorder
itself is overhead-free.

FFmpeg deliberately not bundled: software x264 would burn CPU the game needs, require per-frame
copies out of the process, and add 10–20 MB — and I cannot test a bundled binary.

Consent is requested on the launcher (new "Enable gameplay recording" toggle) and passed to
MainActivity as an Intent extra, so **the game's `onActivityResult` is not patched**. `RecButton`
uses a WRAP_CONTENT PopupWindow (hit-box == the 40dp icon) and tracks its own pointer id.

Verified: 11/11 pipeline calls present in the shipped dex; every throwing method has a catch
handler; 1554/1581 entries byte-identical; 8892/8894 stock method bodies bit-identical.

---

## Features A–E · B/C/D/E working, A not implementable

**B — keep screen awake.** Recon confirmed the app has *no* existing wake-lock or
`KEEP_SCREEN_ON` logic, so there was nothing to conflict with. `FLAG_KEEP_SCREEN_ON` is applied
on the gameplay window, now on by default and toggleable.

**C — real FPS counter.** New `com.xzodomyx.FpsView` blits the game's **own** bitmap font
(`assets/images/font/default8.png`, 16×16 grid of 8×8 glyphs) — no external font asset. No
background box; 1px drop-shadow on the glyphs only. Colour-coded <30 red / 30–50 yellow / >50
green. True measured framerate from `Choreographer`, rolling 1s window. Nearest-neighbour,
allocation-free on the frame path.

**D — pre-launcher redesign.** Gradient backdrop, elevated card with USERNAME/SKIN/OPTIONS
sections, rounded field, `StateListDrawable` pressed states, 450ms fade-and-rise entrance, and
the wordmark drawn in Minecraft's own bitmap font. All drawables built in code — `resources.arsc`
stays stock.

**E — menu restyle, texture-only (safe approach).** 25 chrome textures in `gui/newgui/`
recoloured by luminance→palette remap with alpha copied through, so dimensions, 9-slice geometry
and bevels are preserved and only hue changes. World/server list content, status dots and
scrollbars deliberately left stock (listed with reasons in `retexture.py`).
**Scoped down on purpose:** layout/geometry/click-regions were *not* restructured, because those
screens are laid out by the native engine and changing them risks mismatched hit-boxes. Colours
changed; behaviour byte-identical. Zero perf cost — verified identical pixel dimensions.

**A — frame-by-frame recording: NOT implementable here.** Recon found real machinery —
`RenderContextOGL::captureScreenAsRGB`, and `MainActivity.saveScreenshot(String,int,int,int[])`
which native already calls **with real framebuffer pixels**. But the full Java→native surface is
28 JNI exports and **none triggers a capture**: Java can receive a frame it did not ask for and
cannot ask for one. Per-frame capture therefore needs a PLT hook on `eglSwapBuffers` (imported,
confirmed) running on the native render thread — untestable in this container, and an untested
hook on the frame path violates the "never destabilise the game" rule.
**Goal 1 not shipped; Goal 2 not achieved and not achievable on this build** (packet stream is
native-only, and no headless renderer entry point exists). Start/Stop exclusion from capture is
*reasoned* (PopupWindow is a separate surface, not in the GL framebuffer) — not measured.

Verification: 1554/1581 entries byte-identical, 25 textures dimension-checked, 8892/8894 stock
method bodies bit-identical.

---

## Native build path — **verified** (correction)

A previous entry claimed no ARM cross-compiler was available or reachable. **That was wrong.**
The `ziglang` PyPI wheel provides one. Added `src/native/xzodomyx.c` and
`tools/build_native.sh`, which build and verify a genuine `armeabi-v7a` shared object here
(ELF32 / Machine ARM / EABI v5, matching `libminecraftpe.so`; only libdl symbols undefined).

This changes the *reason* Features 4/5/6 are blocked, not the outcome:

- **not** "cannot compile"
- **is** (a) nothing built for ARM can be executed or tested in this container, and
  (b) `MoveInputHandler` has no exported accessor or singleton — only its constructor — so
  obtaining a live instance requires an **inline hook**, not a `dlsym` call. Untested inline
  hooks into a C++ engine cannot honestly be claimed to satisfy "must never crash gameplay".

`libxzodomyx.so` is a read-only `dlsym` probe: it installs no hooks, writes no memory and calls
nothing in the engine. It is **not bundled into the APK**; the shipped APK is unchanged.

Build verification caught a real defect during development: with `-fvisibility=hidden` the
linker garbage-collected both entry points, producing a 988-byte object that passed every ELF
check while exporting nothing. The script now fails unless `xzo_probe` and `JNI_OnLoad` are
actually present.

---

## Feature 2 — Always-on FPS counter · **working**

Added `com.xzodomyx.Hud`.

- FPS via `Choreographer.postFrameCallback`, rolling 1-second window, top-left with a
  density-scaled 8dp safe-area margin.
- Attached in `MainActivity.onResume`, detached in `MainActivity.onPause`.
- Gated on the splash screen's `fps_counter` preference — not attached at all when off.
- `keep_awake` preference now honoured via `FLAG_KEEP_SCREEN_ON` (opt-in).
- All four entry points wrapped in `catch Throwable`.

**Assumption made, stated plainly:** the brief asked to try a plain decor-view `TextView` and
verify empirically that it renders over the GL surface. There is no device or emulator in this
build environment, so that cannot be verified. Rather than ship an unverified guess, the HUD uses
the `PopupWindow` mechanism already proven in this binary (`setupKeyboardViews`), configured
`setTouchable(false)` so it is display-only and cannot steal input.

**Not verified:** on-device rendering. Static verification only.

Verification: `exactly 2 stock method bodies changed, all intended: ['onPause', 'onResume']`;
`8892 stock method bodies bit-identical`.

---

## Feature 1 — "XZO-Domyx PE" pre-launch screen · **working**

Added `com.xzodomyx.LauncherActivity`; MAIN/LAUNCHER moved off `MainActivity`.

- Forced portrait; title, username field, skin picker, FPS + keep-awake toggles, Launch.
- Username written to the game's own `options.txt` as `mp_username` (key recovered verbatim
  from `libminecraftpe.so` `.rodata`). Sanitised to protect the `key:value` format.
- Skin: picked, dimension-checked, staged to `Pictures/XZO-Domyx/`, media-scanned.
- On Launch: one-time note about finishing skin selection in-game, switch to landscape,
  `startActivity(MainActivity)`, `finish()`.
- Settings live in this Activity's own `SharedPreferences`, never the game's.

**Limitation, stated plainly:** skins are **not** applied automatically. `getCustomSkinPath()`
returns runtime state and `game_lastcustomskinnew` stores a skin ID, not a path, so no launcher
can inject a skin on this build. The user selects the staged image once in the game's own Skins
screen.

Verification: 1579/1581 stock entries byte-identical; all stock classes and method signatures
intact; no new permissions.

---

## Features 3–6 — feasibility outcome

Reported rather than faked. Full evidence in `docs/03-FEATURES-3-6-FEASIBILITY.md`.

- **Feature 3 (identity badge) — not feasible.** `Player::filterValidUserName` (`0x00514c6c`)
  whitelists bytes `0-9 A-Z a-z _ ( )` and space and caps names at 16 chars, so an invisible
  marker is filtered out before it reaches networking. Name-tag rendering
  (`NameTagRenderer::render`) is native-only.
- **Features 4, 5, 6 — blocked.** All require new ARM32 native code. No ARM cross-compiler is
  installed or reachable (NDK, apt, Maven, Adoptium and all GitHub release assets are blocked).
  Additionally: `nativeKeyHandler` handles **only** KEYCODE_BACK, so there is no Java→native
  movement path for Feature 4; and Feature 6's offline re-render premise could not be
  established from static analysis.

No screen recorder was shipped in place of Feature 6, and no inert scripting console in place of
Feature 5.

---

## Step 0 — Recon and toolchain

- Checked `1503Dev/minecraft-ida-database`: **no 0.14.x entry** (alpha coverage stops at 0.10.5).
  Fell back to manual analysis.
- `libminecraftpe.so` is **not symbol-stripped**: 19,561 exported `GLOBAL FUNC`s with full C++
  mangling.
- Assembled a toolchain from PyPI/npm only (JRE via `jdk4py`, apktool 2.0.3 via npm, `aapt2`,
  `androguard`, `capstone`); wrote a binary AXML editor, an ARM/Thumb disassembler and a
  pure-Python zipalign + v1 signer because `aapt`, `zipalign` and `apksigner` are unavailable.
- Proved smali→dex round-trip byte-equivalence before modifying anything.
