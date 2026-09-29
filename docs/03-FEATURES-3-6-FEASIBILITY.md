# Features 3–6 — feasibility, with evidence

Short version: **Features 3, 4, 5 and 6 cannot be implemented in this environment.**

- **Feature 3** is blocked by the game's own code. It would not work on this build even with a
  perfect toolchain and a rack of devices, in the form specified.
- **Features 4, 5, 6** each need code running inside the game's process, reached through an
  **inline hook** that this container can never execute even once. Cross-compiling is possible
  (see the correction below); *validating* is not.

I am reporting this rather than shipping something that looks like the feature and quietly does
nothing, per the brief's instruction to say so plainly instead of silently downgrading.

---

## CORRECTION to an earlier claim

An earlier revision of this document said *"no ARM cross-compiler is available and none is
reachable."* **That was wrong, and I am correcting it rather than leaving it to stand.**

The `ziglang` wheel on PyPI carries a full LLVM-based cross-compiler. `tools/build_native.sh`
now builds a real `armeabi-v7a` shared object here and verifies it:

```
[ok] ELF32
[ok] Machine: ARM
[ok] ARM EABI version 5 (matches libminecraftpe.so)
[ok] only libdl symbols are undefined
[ok] exports xzo_probe, JNI_OnLoad
size: 2524 bytes -> out/native/libxzodomyx.so
```

So "cannot compile" is **not** the blocker. The real blockers are narrower and more specific, and
they are described per-feature below. Two of them apply across Features 4, 5 and 6.

### Real blocker 1 — no way to execute or test ARM code here

This container is x86_64 with no KVM, no emulator, no `adb`, and no device. **Nothing built for
ARM can be run, even once.**

That matters because every remaining feature requires code running *inside the game's process*.
The project's own reliability rule is that anything on the frame path or a background thread must
never crash or freeze gameplay. Inline hooks into a C++ engine, shipped without a single
execution, cannot honestly be claimed to meet that bar. An untested hook does not degrade
gracefully — it segfaults on launch.

### Real blocker 2 — the instance-pointer problem (no exported accessor)

Calling the engine is easy: `libminecraftpe.so` exports 19,561 `GLOBAL FUNC`s, so a hook can
resolve any of them by name with `dlsym` — no offsets, no pattern scanning, no fragility.

Getting a `this` pointer to call them *on* is the hard part. I searched the symbol table for an
accessor and there is none:

```
_ZN16MoveInputHandlerC1ER12InputHandlerRK7Options   0x00386875   <- constructor only
```
No `getMoveInputHandler`, no global singleton, no `sInstance`. The only way to obtain a live
`MoveInputHandler*` is to **hook the constructor and capture `this`** — which means an inline
trampoline (patching the function prologue, relocating displaced ARM/Thumb instructions), not a
simple `dlsym` call. No hooking library (Dobby, Substrate) can be obtained and validated here
either.

Inline hooking + zero test capability is the combination that actually stops Features 4 and 6.

### What was built instead

`src/native/xzodomyx.c` + `tools/build_native.sh`: a tiny, **read-only** probe that `dlsym`s the
exact symbols Features 4 and 6 would need and returns a bitmask of which resolved. It installs no
hooks, writes no memory, and calls nothing in the engine, so it cannot perturb gameplay. It is
deliberately **not bundled into the APK** — it exists so the next person can validate these
assumptions on a real device before writing anything that runs every frame.

---

## Feature 3 — "Domyx" identity badge → **not implementable as specified**

This one fails on the game's own logic, and it is worth being precise because the failure is
non-obvious.

### The invisible marker cannot survive

I disassembled `Player::filterValidUserName` (`0x00514c6c`, 160 bytes). It walks the string
**byte by byte** and keeps only:

| test in the disassembly | accepts |
|---|---|
| `r4 - 0x30 <= 9` | `0`–`9` |
| `(r4 & ~0x20) - 0x41 <= 0x19` | `A`–`Z`, `a`–`z` |
| `r4 == 0x5f` | `_` |
| `(r4 - 0x28) <= 1` | `(` and `)` |
| `r4 == 0x20` | space |

Everything else is dropped. And the loop is gated by `cmp r2, #0xf; bhi` on `len-1`, so **names
longer than 16 characters are rejected wholesale** (the function returns empty).

`Player::isValidUserName` (`0x00514f50`) is just `filterValidUserName(s)` followed by a non-empty
length check.

Consequences:
1. A zero-width space, or any non-ASCII marker, is **byte-filtered out**. It never reaches
   networking. The premise of the feature does not hold on this build.
2. An ASCII marker would survive but is by definition **visible** (every accepted character is
   printable), and would burn characters from a 16-char budget.

### The rendering half is native-only

Name tags are drawn by `NameTagRenderer::render(MinecraftClient&, shared_ptr<UIControl>&, int)`
(`0x003415f5`, 560 bytes). There is no Java path to name-tag rendering anywhere in the dex — the
only Java↔native surface is the 16 `native` methods on `MainActivity`, all of which are lifecycle,
text-input, store or image-picker related.

**Verdict: not implementable.** Not "hard" — the marker mechanism is contradicted by
`filterValidUserName` on this exact binary. Any implementation would be theatre.

*If you want a Domyx badge anyway*, the honest options are (a) a client-side cosmetic badge on
**your own** HUD, which needs no marker at all, or (b) a native hook on `NameTagRenderer::render`
with an out-of-band player list. Both are different features from the one specified. And as the
brief already notes, this would be cosmetic only — never a verification or security mechanism,
since any client can claim anything.

---

## Feature 4 — Modern touch controls → **blocked: instance pointer + no test capability**

Confirmed finding A tells us the *widgets* must use `PopupWindow` + `setTouchInterceptor`. That
part is fine and I could build it. The blocker is the other end: **there is no way to deliver the
resulting input to the game from Java.**

What I checked:

- **`nativeKeyHandler(II)Z` is not a general input path.** Disassembly of
  `Java_com_mojang_minecraftpe_MainActivity_nativeKeyHandler` (`0x002df134`, 54 bytes):
  ```
  cmp r2, #4      ; arg0 != 4 (KEYCODE_BACK) -> r0 = 0, return
  cmp r3, #1      ; arg1 != 1 (action)       -> r0 = 1, return
  ```
  It handles **only the BACK key**. It cannot carry movement.
- The remaining Java→native methods (`nativeTypeCharacter`, `nativeBackSpacePressed`,
  `nativeReturnKeyPressed`, `nativeSetTextboxText`) are all soft-keyboard text plumbing.
- `MainActivity` overrides no `onTouchEvent`/`dispatchTouchEvent`; all real input arrives through
  the native `AInputQueue` (finding A).
- Injecting synthetic events via `InputManager.injectInputEvent` / `Instrumentation` needs the
  signature-level `INJECT_EVENTS` permission. Not available to a third-party app.

So a joystick could be drawn and tracked per-pointer in Java, and would be **unable to move the
player**.

**Target symbols** (all exported, confirmed present, resolvable by `dlsym`):
```
_ZN16MoveInputHandler17_updateMoveVectorEff    0x0035b839   (float x, float y)
_ZN16MoveInputHandler17_updateButtonDownEPbb   0x0035b835   (bool*, bool)
_ZN16MoveInputHandler12_toggleSneakEv          0x0035b825
_ZN16MoveInputHandler15clearInputStateEv       0x0035b7d1
_ZN16MoveInputHandler18clearMovementStateEv    0x0035b801
_ZNK16MoveInputHandler15isMovingForwardEv      0x003866ed
_ZN11LocalPlayer11setSneakingEb                0x003697e5
```
`_updateMoveVector(float,float)` is exactly the analog movement axis the brief wants the joystick
to feed, and `_updateButtonDown(bool*,bool)` is the press/release primitive for Attack/Build-style
repeat with instant release.

The recon is done and the compiler now exists. What remains is (a) an inline hook on
`MoveInputHandlerC1` to capture the instance, and (b) on-device iteration. Neither is possible in
this container. Note the Java half — `PopupWindow` + `setTouchInterceptor`, per-pointer-ID
tracking, tight hit-boxes, texture swap — is fully buildable here; I have not shipped it because
on-screen controls that cannot move the player are worse than none.

---

## Feature 5 — Embedded QuickJS scripting bridge → **blocked: no libc, no testable hook surface**

QuickJS is C, and cross-compiling it is now possible in principle. Two things still stop it.

**No bionic libc.** QuickJS needs a real libc — `malloc`, `printf`, `math`. Zig ships musl, not
bionic. Statically linking musl *inside* a library loaded into a bionic process means two
allocators and two TLS models in one address space; that is a well-known way to get
hard-to-diagnose corruption, and it is exactly the kind of thing that must be validated by
running it. The probe above builds `-nostdlib` precisely because it needs no libc at all.

**The hook surface is the actual product.** Even with the engine running, a ModPE-style API needs
block/entity/level/tick hooks, which require the same inline hooking as Feature 4.

A pure-Java engine (Rhino) would sidestep the compiler, but it would not be the feature: the
useful half of a ModPE-style bridge is the **hook surface into the game**, and from Java the
reachable surface is limited to `options.txt`, our own preferences, and the 16 text/lifecycle
`native` methods on `MainActivity`. No block, entity, level, player or tick hook is reachable
without native code. A scripting bridge with no game hooks would be a JS console, not a mod API —
so I am not shipping one and calling it Feature 5.

Size note, for when it is built elsewhere: QuickJS for a single ABI is roughly 1–2 MB stripped,
comfortably inside the 100 MB ceiling (current build: 20.8 MB).

---

## Feature 6 — Replay-style capture + offline re-render → **blocked: unproven premise + no test capability**

Per the brief, Step 0 had to establish two things before implementation. Results:

**1. Is the packet stream reachable?** Yes — but only from native. The dispatch surface is large
and fully symbolised, e.g.:
```
_ZN16NetEventCallback6handleERKN6RakNet10RakNetGUIDEP11LoginPacket
_ZNK10TextPacket6handleERKN6RakNet10RakNetGUIDEP16NetEventCallback
_ZNK14InteractPacket6handleERKN6RakNet10RakNetGUIDEP16NetEventCallback
_ZN9Minecraft19getNetEventCallbackEv
_ZN9Minecraft15getPacketSenderEv
_ZN20ClientNetworkHandlerC1ER12PacketSenderR15MinecraftClientR5Level
```
`Minecraft::getNetEventCallback()` / `getPacketSender()` are clean interception points. All native.
Nothing in the dex touches packets.

**2. Can the renderer be driven offline from recorded state?** **Not established, and I will not
claim it.** The renderer is entangled with `MinecraftClient`, `Level` and the GL context; there is
no headless or offscreen entry point visible in the symbol table. Answering this properly needs
dynamic analysis on a device, which this environment cannot do.

So Feature 6 is blocked twice: intercepting the stream needs an inline hook that cannot be
validated here, **and** its core premise (offline re-render) is unverified. The brief explicitly said not to silently downgrade to
plain screen capture, so I have not built a screen recorder and labelled it a replay mod. Note
also that the Record/Stop buttons would additionally need the `PopupWindow` + `setTouchInterceptor`
treatment from finding A — but that is the easy part; the capture and re-render are the problem.

---

## Summary

| # | Feature | Status | Blocker |
|---|---|---|---|
| 1 | Pre-launch screen | **working** | — (skin needs one in-game step, finding B) |
| 2 | FPS counter | **working** (not device-tested) | — |
| 3 | Domyx identity badge | **not feasible** | `filterValidUserName` strips the marker; rendering is native-only |
| 4 | Modern touch controls | **blocked** | no exported instance accessor → inline hook, untestable here |
| 5 | QuickJS bridge | **blocked** | no bionic libc; hook surface needs the same inline hooking |
| 6 | Replay capture/re-render | **blocked** | inline hook untestable; offline re-render unproven |
| 7 | GitHub repo | **working** | — |

To unblock 4, 5 and 6 you need **a device or emulator in the loop**, plus the Android NDK for a
bionic sysroot. The recon here — exported symbols, addresses, the `ndis.py` disassembler, the
confirmed hook points, and the verified cross-compile setup — carries straight over and is
normally the slowest part. The missing ingredient is the ability to run and iterate, not the
ability to build.
