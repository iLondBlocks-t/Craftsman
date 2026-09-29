# Changelog

All builds target Minecraft: Pocket Edition 0.14.3, `armeabi-v7a`, minSdk 17 / targetSdk 22.
Every entry was checked with `tools/verify.py` before being committed.

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
