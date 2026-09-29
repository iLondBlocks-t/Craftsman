# Features A–E

| | Feature | Status |
|---|---|---|
| A | Frame-by-frame recording | **not implementable here** — Goal 1 needs a native hook that cannot be tested; Goal 2 impossible on this build |
| B | Keep screen awake in game | **working** |
| C | Real FPS counter, game font, colour-coded, no box | **working** (not device-tested) |
| D | Pre-launcher redesign | **working** |
| E | Menu restyle via textures | **working**, scoped to a safe texture-only swap |

---

## Feature A — frame-by-frame recording → **not implementable in this environment**

### Step 0 recon: what actually exists

I found more than expected, so this is worth stating precisely.

**1. The engine already has a screen-capture path, and pixels genuinely reach Java.**
```
mce::RenderContextOGL::captureScreenAsRGB(std::string&, int&, int&)
MinecraftClient::captureScreenAsImage(ImageData&)
MinecraftClient::requestScreenshot()
MinecraftClient::_updateScreenshot()
```
…and in the dex:
```java
// called FROM native, with real framebuffer pixels
public static void MainActivity.saveScreenshot(String filename, int w, int h, int[] pixels)
```
So the native→Java direction for frame pixels **already exists and works**.

**2. But Java cannot *trigger* a capture.** The complete Java→native surface is 28 JNI exports
(`nativeKeyHandler`, `nativeTypeCharacter`, `nativeSuspend`, the store/input callbacks…). **None
of them requests a screenshot.** `requestScreenshot()` is called only from inside the engine, by
the game's own screenshot UI.

The asymmetry is the whole problem: **Java can receive a frame it did not ask for, and cannot ask
for one.** There is no Java-side way to drive this per-frame.

**3. `eglSwapBuffers` is imported**, so it is a textbook PLT-hook point for per-frame capture, and
`glBindFramebuffer`/`glGenFramebuffers` confirm the engine uses FBOs. This is the right technique —
it just requires native code in-process.

### Why Goal 1 is not shipped

Goal 1 (recording adds ~zero overhead) is a genuinely achievable design, and the recon above gives
the exact hook point. It cannot be built **here**:

- `glReadPixels` must run on the thread owning the GL context. That is a native render thread
  inside `libminecraftpe.so`. Java has no handle to that context — `NativeActivity` took the
  surface. So the capture *must* be native.
- Reaching it means PLT-hooking `eglSwapBuffers` — a self-modifying-code technique against a
  7.7 MB C++ binary, on the hot path of every single frame.
- **This container cannot execute ARM code even once** (x86_64, no KVM, no emulator, no device).

A frame hook that has never been run, sitting on the render path, is precisely the thing the
standing rule forbids: it does not degrade gracefully, it deadlocks or segfaults. Per this batch's
top-priority rule, the safe choice is to not ship it.

### Goal 2 — explicitly not achieved, and not achievable on this build

Goal 2 (re-render offline as if lag never happened) needs the tick/state stream. The packet
surface exists natively (`NetEventCallback::handle(...)`, `Minecraft::getNetEventCallback()`), but:

- it is **native-only** — nothing in the dex touches packets; and
- there is **no headless/offscreen renderer entry point** anywhere in the symbol table, so
  driving the renderer offline from recorded state is unproven on this build.

**Goal 2 is not achieved. I am not claiming otherwise.** Had Goal 1 shipped alone, this document
would still say that.

### The one thing I can answer without a device

You asked me to verify rather than assume that the Start/Stop buttons would be excluded from
captured frames. The reasoning holds and is structural, not empirical: `glReadPixels` reads the
**GL framebuffer** the engine renders into, whereas a `PopupWindow` is a **separate window with
its own surface**, composited by SurfaceFlinger *after* the app's frame. The overlay is not in
that framebuffer, so it cannot appear in the capture. (A plain decor-view child would also be a
different surface from the native one here.) Marked as reasoned, not measured.

### If you build this elsewhere

1. PLT-hook `eglSwapBuffers` in `libminecraftpe.so`.
2. `glReadPixels` into a pre-allocated PBO ring; never allocate on the render thread.
3. Hand `(buffer, timestampNanos)` to a bounded SPSC queue; on overload drop only
   duplicate/near-duplicate frames.
4. Encode on a separate thread with `MediaCodec` (hardware H.264) + `MediaMuxer` → local `.mp4`.
5. Start/Stop as a `PopupWindow` + `setTouchInterceptor` (finding A).

Everything except steps 1–2 is buildable in Java here; I have not shipped a half-system whose
capture stage cannot work.

---

## Feature B — keep screen awake · **working**

Recon first, as instructed: I grepped the entire dex for `KEEP_SCREEN_ON`, `WakeLock`,
`PowerManager`, `setKeepScreenOn`. **There is no existing wake-lock logic anywhere in the app**, so
there is nothing to conflict with and no duplicate to avoid.

`Hud.attach()` applies `Window.addFlags(FLAG_KEEP_SCREEN_ON)` on the gameplay window during
`MainActivity.onResume`. It is now **on by default** (the launcher checkbox reflects this) and can
be turned off. Cleared naturally when the activity pauses.

---

## Feature C — real FPS counter · **working**

- **True measured framerate.** `Choreographer.postFrameCallback` counts *real* delivered frame
  callbacks over a rolling 1-second window: `fps = frames * 1e9 / elapsedNanos`. Nothing smoothed,
  nothing estimated. (Hooking the native render tick would be marginally truer, but that is the
  same untestable native hook as Feature A — not worth the risk for a counter.)
- **The game's own font.** `assets/images/font/default8.png`, already in this APK: a 128×128 atlas,
  16×16 grid of 8×8 glyphs indexed by char code. `FpsView` blits glyphs with
  `Canvas.drawBitmap(src,dst)` using a `PorterDuffColorFilter(SRC_IN)` for tinting. No external
  font asset is introduced.
- **No background box.** Glyphs are drawn straight over the game. The only legibility aid is a
  1-pixel dark drop-shadow pass under the glyphs — on the glyphs themselves, not a panel.
- **Colour-coded:** `<30` red `#FF5555`, `30–50` yellow `#FFAA00`, `>50` green `#55FF55`.
  Reasonable for this device class: 0.14.3 targets Android 5-era hardware where 60 is the cap,
  ~50+ is smooth, and sub-30 is where touch response visibly suffers.
- Nearest-neighbour only (`setAntiAlias/setFilterBitmap/setDither(false)`), integer pixel scale, so
  the pixel art stays crisp instead of blurring.
- Top-left with a density-scaled safe-area margin. Allocation-free on the frame path: the colour
  filter is rebuilt only when the colour *band* changes, and `Rect`s are reused.

**Still not device-verified.** The counter renders through the same `PopupWindow` proven in this
binary (`setTouchable(false)` → `FLAG_NOT_TOUCHABLE`, so it cannot take input). You asked me to
confirm a plain overlay View renders over the GL surface before finalising — I cannot, for the
same reason as Feature A, so I kept the proven mechanism.

---

## Feature D — pre-launcher redesign · **working**

Pure Android UI, zero bearing on in-game performance, so this got the detail.

- Diagonal gradient backdrop (`#0B1220` → `#102A22`).
- **Wordmark rendered in Minecraft's own bitmap font** via the same `FpsView` glyph blitter, in
  accent green — the launcher and the in-game counter share one typeface.
- Elevated card (rounded, 1dp teal stroke, translucent `#E6121A26`) grouping
  **USERNAME / SKIN / OPTIONS** sections with small-caps dim labels.
- Rounded `EditText` with its own fill + stroke and proper hint colour.
- Buttons use `StateListDrawable` with real pressed states — secondary green for the skin picker,
  bright accent for **LAUNCH**.
- Entrance motion: the card fades and rises 24dp over 450 ms (`ViewPropertyAnimator`).
- Still a `ScrollView`, so it fits small portrait screens.

All drawables are constructed in code — no new resource files, so `resources.arsc` stays stock.

---

## Feature E — menu restyle · **working, scoped to the safe approach**

### What I did
`tools/retexture.py` recolours **25** chrome textures in `assets/images/gui/newgui/`, matching the
launcher's identity. The stock chrome is greyscale, so each pixel's **luminance** is remapped
through a palette ramp while its **alpha is copied through untouched**. Dimensions, format, 9-slice
geometry and bevel shapes are all preserved — only hue changes.

Restyled: `NormalButton*`, `DarkButton*`, `ButtonWithBorder*`, `classic-button*`, `buttonNew`,
all `Tab*` (including in-game tabs), `dialog-background-atlas`, `TopBar`.

### What I deliberately did NOT touch
As requested, the world/server **list content** is untouched — and I extended that to anything that
would leak into an unrelated screen. Explicitly excluded, with reasons, in `EXCLUDE_REASON`:
`World.png`, `WorldDemoScreen.png`, `Realms/Friends/FriendsDiversity/Local` (server list rows),
`onlineLight`/`offlineLight`/`Dot1-3` (status dots — recolouring these would destroy their
red/amber/green meaning), and every scrollbar texture.

### Which parts had to stay texture-only, and why
**All of it — and this was the right call.** The requested "strong redesign" of Play / Settings /
Skins could in principle also mean new layouts, repositioned controls, different panel geometry.
Those screens are laid out by the **native engine**; changing structure means editing native
screen code and click regions, which risks mismatched hit-boxes and crashes in exactly the code
paths this batch says must not be destabilised.

So: **colours and materials changed; layout, geometry, click regions and logic are byte-identical
to stock.** Buttons sit where they always sat and respond exactly as before.

### Performance
Zero cost, and verified rather than asserted: every replacement has **identical pixel dimensions**
to the original (`verify.py` checks this), so texture memory, atlas layout and upload cost are
unchanged. Total APK size went *down* slightly (20.82 → 20.79 MB). No new texture, no larger
texture, no extra draw call.

---

## Verification after this batch

```
[ok] no stock entries lost (1581 checked)
[ok] exactly 27 intended entries differ (2 code + 25 textures); other 1554 byte-identical
[ok] all 25 restyled textures keep stock dimensions
[ok] package / version / minSdk(17) / targetSdk(22) / permissions / receivers unchanged
[ok] NativeActivity lib_name meta-data intact
[ok] no stock classes removed (1053 intact)
[ok] added exactly: ['FpsView', 'Hud', 'LauncherActivity']
[ok] exactly 2 stock method bodies changed, all intended: ['onPause', 'onResume']
[ok] 8892 stock method bodies bit-identical
[ok] all STORED entries 4-byte aligned; v1 signature valid over all 1581 entries
```

`libminecraftpe.so` remains **never patched**.
