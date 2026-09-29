# Feature 1 — "XZO-Domyx PE" pre-launch screen

**Status:** implemented, built and mechanically verified.
**Output:** `out/XZO-Domyx-PE-0.14.3.apk` (20.8 MB — 79 MB under the ceiling)

Built with `tools/build.sh`, checked with `tools/verify.py`.

---

## What was built

`com.xzodomyx.LauncherActivity` (`src/smali/com/xzodomyx/LauncherActivity.smali`):

- forced portrait (`setRequestedOrientation(1)` *and* `android:screenOrientation="portrait"`)
- title **XZO-Domyx PE** + version subtitle
- `EditText` for the username, prefilled from our own prefs
- **Choose / Upload Skin** → `ACTION_GET_CONTENT`, mime `image/*`, via `createChooser`
- two toggles: *Show FPS counter in game*, *Keep screen awake*
- **LAUNCH** button
- everything inside a `ScrollView` so it fits small portrait screens

Settings live in `getSharedPreferences("xzo_domyx_prefs", MODE_PRIVATE)` — **this Activity's own
prefs, never the game's**, as specified.

## Design decisions, and the recon that forced them

### Username → the game's own `options.txt`
Not a native hook. `mp_username` was recovered verbatim from `libminecraftpe.so` `.rodata`
(docs/00-RECON.md §3a), so on **Launch** the activity rewrites
`<external>/games/com.mojang/minecraftpe/options.txt`, replacing the `mp_username:` line in place
(or appending it) and leaving every other line untouched. The game then loads it through its own
`Options` path exactly as if the user had typed it in-game.

Zero native patching, zero new game mechanics, and it cannot desync from the game's own state.

Usernames are sanitised: trimmed, with control characters and `:` stripped, because either would
corrupt the `key:value` line format.

### Skin → staged into the MediaStore, applied by the game's own picker
This is the one place where the obvious implementation is wrong, and recon caught it.

The chain is `SkinRepository::pickCustomSkin` → AppPlatform vtable → Java
`MainActivity.pickImage(long)` → `ACTION_PICK` over `MediaStore.Images.Media` → `onActivityResult`
→ `nativeOnPickImageSuccess(long, String)` → `storeCustomSkin(path)`.

I disassembled the relevant functions (`tools/ndis.py`) and found:
- `SkinRepository::getCustomSkinPath()` is a 14-byte getter returning the member at `this+0x34` —
  **runtime state, not a fixed on-disk location**;
- the options key is `game_lastcustomskinnew`, and `getLastCustomSkinId` returns a **skin ID**, not
  a path.

So writing a PNG to a guessed path, or stuffing a path into `game_lastcustomskinnew`, would both
be fabricated mechanisms that quietly do nothing. **A launcher cannot inject a custom skin into
0.14.3 without native work.**

What it does instead: validates the image's dimensions (warns, but does not block, if it isn't
64x32 / 64x64), copies it to `Pictures/XZO-Domyx/xzo_skin.png`, and calls
`MediaScannerConnection.scanFile` so it is indexed immediately. Because the game's own skin picker
*is* an `ACTION_PICK` over MediaStore images, the staged skin then shows up in the in-game Skins
screen and is applied by the game's own confirmed code path.

### The toggles
Both are persisted now and inert until their in-game consumer exists. The FPS counter needs an
overlay, and the overlay mechanism is already pinned down (see below) — but the HUD itself was in
the truncated part of the request, so it is **not** implemented. The toggle does not pretend to
work.

### Overlay mechanism, for whatever comes next
`MainActivity` is a `NativeActivity`; `takeInputQueue()` means motion events bypass the Java view
hierarchy entirely, so a view added to the decor view would draw but never receive touches. The
game's own `setupKeyboardViews()` solves this with a `PopupWindow` (separate window, own input
channel) + `setTouchInterceptor`. That is the path any future HUD/touch widget should use.

## Build pipeline

```
apktool d -r        keeps resources.arsc + AndroidManifest.xml as raw binary
  + src/smali       our class, overlaid
apktool b           harvest build/apk/classes.dex (resource stage skipped; see below)
patch_manifest.py   binary AXML edit, byte-exact round-trip proven
repack.py           substitute 2 entries, copy 1579 raw, align, sign
```

`aapt` v1 is only obtainable as a 32-bit binary that cannot execute here, so the pipeline never
calls it. New UI is built programmatically instead of from layout XML, which means **no resource
ever changes** — the strongest available guarantee for "stock UI/UX unchanged".

## Verification (`tools/verify.py`)

```
[ok] no stock entries lost (1581 checked)
[ok] exactly ['AndroidManifest.xml', 'classes.dex'] differ; other 1579 byte-identical
[ok] package / versionName / versionCode / minSdk(17) / targetSdk(22) unchanged
[ok] permissions unchanged (no new permissions requested)
[ok] receivers unchanged
[ok] launcher activity is now com.xzodomyx.LauncherActivity
[ok] MainActivity still declared
[ok] NativeActivity lib_name meta-data intact
[ok] minecraft: VIEW/BROWSABLE filter retained on MainActivity
[ok] no stock classes removed (1053 intact)
[ok] added exactly: ['Lcom/xzodomyx/LauncherActivity;']
[ok] all 8894 stock methods present and unmodified
[ok] all STORED entries 4-byte aligned
[ok] MANIFEST.MF covers all 1581 entries; every SHA-256 digest matches
[ok] CERT.SF manifest digest matches; CERT.RSA parses as PKCS#7
```

`libminecraftpe.so`, `libfmod.so`, `libgnustl_shared.so`, `resources.arsc` and all 1577 other
assets are bit-for-bit the stock bytes. armeabi-v7a remains the only ABI. No new permission is
requested (`WRITE_EXTERNAL_STORAGE` was already in the stock manifest).

## Compatibility

- `minSdk 17` / `targetSdk 22` unchanged → installs and runs on **Android 5.0 (API 21)**.
- No AndroidX, no support library; only `android.*` framework classes from API ≤ 17.
- Signed with a v1 (JAR) signature. That is valid on every Android version for this app: the
  "v2 signature required" rule only applies to APKs targeting SDK 30+.
- **Caveat unrelated to this mod:** Android 14+ refuses to install *any* APK with `targetSdk < 23`.
  That is a property of the stock 0.14.3 build, not of these changes. Test on the Android 5–13
  range.

## Installing

The signature differs from Mojang's, so:

1. **Back up `/sdcard/games/com.mojang/` first** if you want to keep your worlds.
2. Uninstall the original Minecraft PE.
3. Install `out/XZO-Domyx-PE-0.14.3.apk`.
4. Restore `games/com.mojang/` if you backed it up.

The signing key is `xzodomyx.p12` (password `xzodomyx`), generated on first build and **kept out of
git**. Keep it — reusing it lets later builds update-install over this one. Delete it and the next
build makes a new identity, requiring another uninstall.

## Not done (was in the truncated part of the request)

The request was cut off at *"On Launc…"*, and Features 2–7 never arrived. Outstanding:
the rest of Feature 1's launch behaviour, Features 2–7, and the in-game consumer for the
FPS toggle.
