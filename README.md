# XZO-Domyx PE

Mod of **Minecraft: Pocket Edition 0.14.3** (ARM32 / `armeabi-v7a`, Android 5.0+).

| # | Feature | Status |
|---|---|---|
| 1 | "XZO-Domyx PE" pre-launch screen | **working** — skin needs one in-game step ([why](docs/01-FEATURE-1-LAUNCHER.md)) |
| 2 | Always-on FPS counter | **working**, not yet device-tested |
| 3 | "Domyx" identity badge | **not feasible** on this build ([evidence](docs/03-FEATURES-3-6-FEASIBILITY.md)) |
| 4 | Modern touch controls | **blocked** — needs an inline hook + on-device testing |
| 5 | QuickJS scripting bridge | **blocked** — no bionic libc; untestable hook surface |
| 6 | Replay capture + offline re-render | **blocked** — untestable hook; offline re-render unproven |
| 7 | GitHub repository | **working** |
| A | Frame-by-frame recording | **not implementable here** ([why](docs/04-FEATURES-A-E.md)) |
| B | Keep screen awake in game | **working** |
| C | FPS counter: game font, colour-coded, no box | **working**, not device-tested |
| D | Pre-launcher redesign | **working** |
| E | Menu restyle (texture-only, safe) | **working** |

## Build

```bash
tools/bootstrap.sh          # once: fetches JRE + apktool + aapt2 from PyPI/npm
tools/build.sh              # -> out/XZO-Domyx-PE-0.14.3.apk
python3 tools/verify.py Minecraft-PE-0-14-3.apk out/XZO-Domyx-PE-0.14.3.apk
```

The APK is gitignored; the sources and the full build pipeline are committed.

## Install

The signature differs from Mojang's, so a clean install is required:

1. **Back up `/sdcard/games/com.mojang/`** to keep your worlds.
2. Uninstall the original Minecraft PE.
3. Install `out/XZO-Domyx-PE-0.14.3.apk`.
4. Restore `games/com.mojang/`.

Keep `xzodomyx.p12` (password `xzodomyx`, gitignored) so later builds update-install over this
one instead of forcing another uninstall.

> Android 14+ refuses to install *any* APK with `targetSdk < 23`. That is a property of stock
> 0.14.3, not of this mod. Use an Android 5–13 device.

## How it is built, and why

`aapt` v1 is only obtainable here as a 32-bit binary that cannot execute, so the pipeline **never
calls it**. All new UI is constructed programmatically instead of from layout XML, which means no
resource is ever re-encoded:

```
apktool d -r        raw resources.arsc + binary AndroidManifest.xml
  + src/smali       new classes overlaid
  + patch_smali.py  anchored edits to the game's own smali (asserts each anchor is unique)
apktool b           harvest classes.dex
  patch_manifest.py binary AXML edit (byte-exact round-trip proven by axml.py selftest)
  repack.py         substitute 2 entries, copy 1579 raw, zipalign, v1-sign
```

Result: **1554 of 1581 stock APK entries are byte-for-byte identical**; only `classes.dex`,
`AndroidManifest.xml` and 25 deliberately restyled GUI textures change (each keeping its exact
stock dimensions). `libminecraftpe.so` is **never patched**.

### `tools/`

| file | purpose |
|---|---|
| `bootstrap.sh` | assembles the toolchain from PyPI/npm (no Android SDK reachable) |
| `build.sh` | full build |
| `axml.py` | binary AXML reader/writer; `selftest` proves byte-exact round-trip |
| `patch_manifest.py` | moves MAIN/LAUNCHER onto the launcher activity |
| `patch_smali.py` | anchored edits to the game's smali |
| `repack.py` | raw-preserving repack + zipalign + v1 signing (pure Python) |
| `ndis.py` | targeted ARM/Thumb disassembler for `libminecraftpe.so`, annotates literal loads |
| `verify.py` | mechanical post-build checks |
| `retexture.py` | Feature E: luminance→palette recolour of menu chrome, alpha/size preserved |
| `build_native.sh` | builds + verifies `armeabi-v7a` `libxzodomyx.so` via `zig cc` (not bundled) |

## Verification

`tools/verify.py` is run after every feature, not just at the end:

```
[ok] no stock entries lost (1581 checked)
[ok] exactly ['AndroidManifest.xml', 'classes.dex'] differ; other 1579 byte-identical
[ok] package / versionName / versionCode / minSdk(17) / targetSdk(22) unchanged
[ok] permissions unchanged (no new permissions requested)
[ok] NativeActivity lib_name meta-data intact
[ok] no stock classes removed (1053 intact)
[ok] exactly 2 stock method bodies changed, all intended: ['onPause', 'onResume']
[ok] 8892 stock method bodies bit-identical
[ok] all STORED entries 4-byte aligned
[ok] v1 signature: all 1581 entries covered, every SHA-256 digest matches
```

## Two findings that shaped everything

**A. `MainActivity` is a `NativeActivity`.** It calls `takeInputQueue()`, so motion events go
straight to the native `AInputQueue` and **never reach the Java view hierarchy**. A plain overlay
`View` would draw but never receive a touch. The game's own `setupKeyboardViews()` solves this
with a `PopupWindow` + `setTouchInterceptor`; that is what any touch widget here must use.

**B. A launcher cannot apply a custom skin end-to-end.** `getCustomSkinPath()` returns runtime
state (`this+0x34`), and `game_lastcustomskinnew` holds a skin *ID*, not a path. The launcher
stages the picked image to `Pictures/XZO-Domyx/` and media-scans it; **you select it once inside
the game's own Skins screen.** This is a documented limitation, not automatic skin injection.

## Docs

- [`docs/00-RECON.md`](docs/00-RECON.md) — Step 0: symbol DB check, native/Java split, toolchain
- [`docs/01-FEATURE-1-LAUNCHER.md`](docs/01-FEATURE-1-LAUNCHER.md)
- [`docs/02-FEATURE-2-FPS.md`](docs/02-FEATURE-2-FPS.md)
- [`docs/03-FEATURES-3-6-FEASIBILITY.md`](docs/03-FEATURES-3-6-FEASIBILITY.md)
- [`docs/04-FEATURES-A-E.md`](docs/04-FEATURES-A-E.md) — recording, wake-lock, FPS font, redesign, retexture

## Legal

For personal use with a copy of the game you own. Not affiliated with or endorsed by Mojang or
Microsoft. The stock APK in this repo is the unmodified original; do not redistribute modified
builds.
