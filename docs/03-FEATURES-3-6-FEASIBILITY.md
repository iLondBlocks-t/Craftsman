# Features 3–6 — feasibility, with evidence

Short version: **Features 3, 4, 5 and 6 cannot be implemented in this environment.** Three of them
are blocked by a hard environmental limit, and Feature 3 is blocked by the game's own code — it
would not work even with a full toolchain, in the form specified.

I am reporting this rather than shipping something that looks like the feature and quietly does
nothing, per the brief's instruction to say so plainly instead of silently downgrading.

---

## The environmental blocker (Features 4, 5, 6)

All three need **new ARM32 native code** in the process — either a new `.so` or inline hooks into
`libminecraftpe.so`.

There is **no ARM cross-compiler available and none is reachable**:

- installed compilers: `gcc-12` for **x86_64 only**; no `arm-linux-androideabi-*`, no `clang`
- `dl.google.com` (NDK) — blocked at the network level
- `deb.debian.org` (`apt install gcc-arm-*`) — blocked
- `api.adoptium.net`, Maven Central, `raw.githubusercontent.com`, and **all GitHub release
  assets** (`objects.githubusercontent.com`) — blocked
- PyPI/npm reachable, but neither carries an Android NDK or an ARM sysroot
  (`pypi:android-ndk`, `npm:android-ndk`, `npm:ndk-build` → 404)

Even the existing toolchain had to be assembled from a JRE wheel and an npm-packaged apktool jar
(see `docs/00-RECON.md` §6). A working ARM toolchain plus bionic sysroot is simply not obtainable
here.

This is an environment limitation, not a design dead end. Each feature below lists the exact
symbols to target if you build it elsewhere with an NDK.

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

## Feature 4 — Modern touch controls → **blocked, needs native**

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

**Target symbols if you build this with an NDK** (all exported, confirmed present):
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
to feed, and `_updateButtonDown(bool*,bool)` is the press/release primitive for
Attack/Build-style repeat with instant release. The hard part of the recon is done; only the
compile step is missing.

---

## Feature 5 — Embedded QuickJS scripting bridge → **blocked, needs native**

QuickJS is C. It must be cross-compiled for `armeabi-v7a` and bound over JNI. No ARM compiler
(above), so the engine cannot be produced.

A pure-Java engine (Rhino) would sidestep the compiler, but it would not be the feature: the
useful half of a ModPE-style bridge is the **hook surface into the game**, and from Java the
reachable surface is limited to `options.txt`, our own preferences, and the 16 text/lifecycle
`native` methods on `MainActivity`. No block, entity, level, player or tick hook is reachable
without native code. A scripting bridge with no game hooks would be a JS console, not a mod API —
so I am not shipping one and calling it Feature 5.

Size note, for when it is built elsewhere: QuickJS for a single ABI is roughly 1–2 MB stripped,
comfortably inside the 100 MB ceiling (current build: 20.8 MB).

---

## Feature 6 — Replay-style capture + offline re-render → **blocked, needs native**

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

So Feature 6 is blocked twice: it needs native code that cannot be compiled here, **and** its core
premise (offline re-render) is unverified. The brief explicitly said not to silently downgrade to
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
| 4 | Modern touch controls | **blocked** | no ARM toolchain; no Java→native movement path |
| 5 | QuickJS bridge | **blocked** | no ARM toolchain; no Java-reachable game hooks |
| 6 | Replay capture/re-render | **blocked** | no ARM toolchain; offline re-render unproven |
| 7 | GitHub repo | **working** | — |

To unblock 4, 5 and 6: build on a machine with the Android NDK (r16b or earlier for
`armeabi-v7a` + API 21 comfort). The recon in this repo — exported symbols, addresses, the
`ndis.py` disassembler, the confirmed hook points — carries straight over and is the part that
usually takes longest.
