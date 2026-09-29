# Changelog

All builds target Minecraft: Pocket Edition 0.14.3, `armeabi-v7a`, minSdk 17 / targetSdk 22.
Every entry was checked with `tools/verify.py` before being committed.

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
