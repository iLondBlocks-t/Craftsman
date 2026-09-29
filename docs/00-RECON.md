# Step 0 — Recon Report

**Target:** `Minecraft-PE-0-14-3.apk` (in repo root)
**Date:** 2026-09-29
**Status:** Recon complete. No game code modified yet.

Everything below was *verified against the actual binary in this repo*. Where something is
inferred rather than directly observed, it is explicitly labelled **INFERRED**.

---

## 1. Public symbol database check

Checked `https://github.com/1503Dev/minecraft-ida-database` (cloned, README read in full).

**There is no 0.14.x entry.** Its alpha-era coverage is:
`0.10.5, 0.9.5, 0.8.1, 0.7.6, 0.6.1, 0.5.0, 0.4.0, 0.3.3, 0.2.2, 0.1.1`
— then it jumps to `1.2.11.4` and later. Nothing between 0.10.5 and 1.2.

Additional notes:
- The repo tree holds only `LICENSE` + `README.md`; the `.i64` files are GitHub *release
  assets*, which are unreachable from this sandbox (see §6), and they require IDA 9.0+ to open.
- The linked FloppyDolphin57 MediaFire mirror is **server-only** databases, and also unreachable.

**Conclusion: no prebuilt symbol DB for this exact build. Falling back to manual analysis.**
This turned out not to matter much — see §3.

## 2. APK facts (verified)

| Property | Value |
|---|---|
| package | `com.mojang.minecraftpe` |
| versionName / versionCode | `0.14.3` / `760140300` |
| minSdk / targetSdk | **17 / 22** (API 21 requirement already satisfied) |
| launcher activity | `com.mojang.minecraftpe.MainActivity` |
| activities / services / receivers | 1 / 0 / 1 (`com.amazon.device.iap.ResponseReceiver`) |
| permissions | INTERNET, BILLING, ACCESS_NETWORK_STATE, WRITE_EXTERNAL_STORAGE, VIBRATE |
| dex | single `classes.dex`, 1053 classes / 8894 methods / 11037 strings |
| native libs | `armeabi-v7a` **only**: `libminecraftpe.so` (7.7 MB), `libfmod.so` (1.2 MB), `libgnustl_shared.so` (661 KB) |
| APK size | 21.8 MB → ~78 MB of headroom under the 100 MB ceiling |

There is **no `android:name` on `<application>`**, i.e. no custom `Application` class — so one can be
added cleanly without displacing anything.

## 3. Native analysis — `libminecraftpe.so`

**This build is not stripped of dynamic symbols.** `readelf --dyn-syms` yields **30,996 entries,
19,561 of them `GLOBAL FUNC`**, with full Itanium C++ mangling. This is a far better position than
the usual blind pattern-scan, and it substantially replaces the missing IDA database.

Confirmed exports directly relevant to the launcher feature:

```
_ZNK7Options11getUsernameEv              Options::getUsername() const
_ZN7Options11setUsernameERKSs            Options::setUsername(std::string const&)
_ZN13OptionStrings20Multiplayer_UsernameE  OptionStrings::Multiplayer_Username   (OBJECT)
_ZN6Player15isValidUserNameERKSs         Player::isValidUserName(std::string const&)
_ZN6Player19filterValidUserNameERKSs     Player::filterValidUserName(std::string const&)
_ZN7Options17setLimitFramerateEb         Options::setLimitFramerate(bool)
_ZNK7Options17getLimitFramerateEv        Options::getLimitFramerate() const
_ZN14SkinRepository14pickCustomSkinESt8functionIFvNS_20PickCustomSkinResultEEE
_ZN14SkinRepository15storeCustomSkinERKSs
_ZNK14SkinRepository17getCustomSkinPathEv
_ZNK14SkinRepository18hasValidCustomSkinEv
_ZN7Options19setLastCustomSkinIdERKSs
_ZNK15MinecraftClient17getSkinRepositoryEv
```

### 3a. Username storage key — CONFIRMED, not guessed

The literal `mp_username` exists in `.rodata`, inside a contiguous run of the game's `options.txt`
keys. Adjacent keys recovered verbatim:

```
... vr_use_comfort_controls, vr_show_comfort_select_screen,
mp_username, mp_multiplayer_game, mp_server_visible, mp_xboxlive_visible,
gfx_renderdistance, gfx_renderdistance_new, gfx_particleviewdistance, gfx_viewbobbing,
gfx_pixeldensity, gfx_dpadscale, gfx_fancygraphics, gfx_transparentleaves, gfx_fancyskies,
gfx_animatetextures, gfx_hidegui, gfx_gamma, gfx_field_of_view, gfx_msaa, gfx_texel_aa,
gfx_fullscreen, gfx_guiscale,
ctrl_sensitivity, ctrl_invertmouse, ctrl_usetouchscreen, ctrl_usetouchjoypad,
ctrl_swapjumpandsneak, ctrl_islefthanded, feedback_vibration, ctrl_autojump
```

Path strings also present: `/games/com.mojang/`, `/minecraftpe`, `/options.txt`.

**Consequence:** the pre-launch screen can set the in-game username by writing
`mp_username:<name>` into `<external>/games/com.mojang/minecraftpe/options.txt` **before**
starting `MainActivity`. This reuses the game's own persistence layer — **zero native patching,
zero new game mechanics.** This is the approach I recommend.

### 3b. FPS

There is no stock on-screen FPS counter. The only framerate-related asset is an internal profiler
format string:
`FPS(%s): %.1f, SIMTICKS: %.1f, Tick:%.1fms/%.1fms, Render:%.1fms/%.1fms, ...`
and the `Options::*LimitFramerate` pair (a frame *cap*, not a counter).
So an FPS counter must be **new UI**, and belongs in the Java layer (see §4b).

## 4. Java layer — `MainActivity`

### 4a. It is a `NativeActivity`

```smali
.class public Lcom/mojang/minecraftpe/MainActivity;
.super Landroid/app/NativeActivity;
```
with `<meta-data android:name="android.app.lib_name" android:value="minecraftpe"/>`.
`onCreate` calls `super.onCreate()` and **never calls `setContentView`** during normal startup.

**This is the single most important structural fact for any overlay/touch feature.**
`NativeActivity.onCreate` performs `getWindow().takeSurface(...)` and
`getWindow().takeInputQueue(...)`. Once a window's input queue is taken, `ViewRootImpl` routes
motion events straight to the native `AInputQueue` and they **never traverse the Java view
hierarchy**. So the naive approach — "add a Button to the decor view" — would render but would
**never receive touches**. Any plan built on that assumption would silently fail.

### 4b. …but the game itself already solves this, and we should reuse its solution

`MainActivity.setupKeyboardViews(Ljava/lang/String;IZZ)V` (line ~3255 of the baksmali) does exactly
this overlay, for the soft-keyboard text proxy:

- builds a `LinearLayout` programmatically (no layout XML),
- calls `MainActivity.setContentView(View, ViewGroup$LayoutParams)`,
- creates a `PopupWindow`, `setClippingEnabled(false)`, `setWindowLayoutMode(-1,-1)`,
- `setTouchInterceptor(MainActivity$4)` ← **a Java touch listener that does fire**,
- `showAtLocation(view, 0, 0, 0)`.

A `PopupWindow` is a *separate window* with its own input channel, so it is not affected by
`takeInputQueue`. **This is the confirmed, in-game-precedented mechanism for any new touch widget
or HUD overlay**, and it is pure Java.

### 4c. Skin picking already exists natively — reuse it

```smali
.method pickImage(J)V          # ACTION_PICK on MediaStore.Images.Media.EXTERNAL_CONTENT_URI
.method native nativeOnPickImageSuccess(JLjava/lang/String;)V
.method native nativeOnPickImageCanceled(J)V
```
`MainActivity.pickImage(long callback)` is called *from native* (`SkinRepository::pickCustomSkin`),
launches the system picker, and `onActivityResult` feeds the chosen path back via
`nativeOnPickImageSuccess`. The game then does its own `SkinRepository::storeCustomSkin`.

**Consequence:** the launcher's "Choose/Upload Skin" button should *not* reimplement skin
installation. It should either (a) copy the picked PNG to the path the game itself uses
(`SkinRepository::getCustomSkinPath`), or (b) simply hand off and let the in-game skin picker do
it. Either way we reuse the existing mechanic rather than inventing one. **(Exact on-disk custom
skin path still needs one more pass to pin down — flagged, not guessed.)**

## 5. Verified round-trip

Before touching anything, I proved the rebuild pipeline is lossless:

- `apktool d` (with `-r`, raw resources) → OK
- reassemble smali → `classes.dex` → **1053 classes / 8894 methods / 11037 strings — identical to
  the original dex.**

### Build strategy: never invoke `aapt`

`aapt` v1 is only obtainable here as a 32-bit i386 binary that cannot execute in this sandbox
(see §6). Rather than fight that, the pipeline deliberately avoids it:

1. `apktool d -r` — keeps `resources.arsc` and `AndroidManifest.xml` as raw binary.
2. Modify **smali only**; build all new UI **programmatically in code** (this is also what the
   game itself does in `setupKeyboardViews`, so it is idiomatic here).
3. Patch the binary `AndroidManifest.xml` with a purpose-built AXML editor.
4. Repackage from the **original APK**, substituting only `classes.dex` + `AndroidManifest.xml`.

This has a real correctness benefit beyond convenience: **every resource, asset and native library
stays byte-identical to stock**, which is the strongest possible guarantee for the
"visible base-game UI/UX must remain UNCHANGED" requirement. No resource re-encoding, no
ID renumbering, no PNG recompression.

## 6. Sandbox toolchain — constraints and what was actually obtained

Network egress is restricted to `github.com`, `api.github.com`, `codeload.github.com`,
`pypi.org`/`files.pythonhosted.org`, and `registry.npmjs.org`. **Blocked:** `dl.google.com`
(Android SDK), `repo1.maven.org`, `deb.debian.org` (apt), `raw.githubusercontent.com`,
`objects.githubusercontent.com` (**all GitHub release assets**), adoptium, bitbucket.

| Need | Resolution |
|---|---|
| JRE | `jdk4py` (PyPI) → Temurin 25.0.2. **JRE only — no `javac`, no `jar`, no `jarsigner`.** |
| apktool | `apktool` npm package bundles `bin/apktool.jar` **2.0.3** (Dec 2015 — contemporaneous with this 2016 APK). Runs fine on Java 25. |
| smali/baksmali | shaded inside that apktool jar (`org.jf.smali`, `org.jf.dexlib2`). |
| aapt v1 | ✗ both available copies (npm `aapt`, apktool's `prebuilt/aapt/linux/aapt`) are **ELF32 i386**; no i386 loader and no way to install one. → designed around (§5). |
| aapt2 | ✓ `aapt2` (PyPI) → x86_64, v2.19. Available as a fallback if resources ever must change. |
| dex analysis | `androguard` 4.1.4 (PyPI). |
| jadx | ✗ release-asset only. Not needed — baksmali output is sufficient and authoritative. |
| signing | `apksigner`/`jarsigner` unavailable → will implement v1(+v2) signing with `cryptography` (PyPI), keypair via `keytool` (present in jdk4py) or generated directly. |

Bootstrap is scripted and reproducible: `tools/bootstrap.sh`.

## 7. Open questions before writing feature code

1. **Exact custom-skin on-disk path** (§4c) — needs one targeted pass over
   `SkinRepository::getCustomSkinPath` / `storeCustomSkin`. Not guessing it.
2. **External storage root at API 21+** — the game uses `getExternalStoragePath()`; the launcher
   must use that same value, not a hardcoded `/sdcard`, or `options.txt` will be written to the
   wrong place on some devices.
