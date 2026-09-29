#!/usr/bin/env bash
# Build + verify libxzodomyx.so for armeabi-v7a using zig cc (PyPI `ziglang`).
#
# Why zig and not the NDK: dl.google.com is blocked in this environment, but the
# `ziglang` wheel on PyPI carries a full LLVM cross-compiler. Zig has no bionic
# libc, so we build -nostdlib and reference only dlopen/dlsym, which Android's
# linker resolves from libdl at load time (global namespace on API 21).
#
# Output is NOT bundled into the APK -- see docs/03-FEATURES-3-6-FEASIBILITY.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYLIBS="${PYLIBS:-$HOME/.local/pylibs}"
ZIG="$PYLIBS/ziglang/zig"
OUT="$ROOT/out/native"
SO="$OUT/libxzodomyx.so"

mkdir -p "$OUT"

echo "==> compiling for armeabi-v7a (ARMv7-A + VFPv3 + Thumb-2)"
"$ZIG" cc \
  -target arm-linux-musleabi \
  -mcpu=generic+v7a+vfp3+thumb2 \
  -nostdlib -shared -fPIC \
  -fno-sanitize=undefined \
  -Os -fno-stack-protector -fvisibility=hidden \
  -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-exceptions \
  -DNDEBUG \
  -Wl,-soname,libxzodomyx.so \
  -Wl,--export-dynamic \
  -o "$SO" \
  "$ROOT/src/native/xzodomyx.c"

echo "==> verifying the result really is an armeabi-v7a object"
fail=0
hdr="$(readelf -h "$SO")"
check() { if echo "$hdr" | grep -q "$1"; then echo "  [ok]   $2"; else echo "  [FAIL] $2"; fail=1; fi; }
check "Class: *ELF32"                 "ELF32"
check "Machine: *ARM"                 "Machine: ARM"
check "Version5 EABI"                 "ARM EABI version 5 (matches libminecraftpe.so)"
check "Type: *DYN"                    "shared object"

echo "==> undefined symbols (must all be provided by Android at load time)"
undef="$(readelf --dyn-syms -W "$SO" | awk '$7=="UND" && $8!="" {print $8}' | sort -u)"
echo "$undef" | sed 's/^/         /'
for s in $undef; do
  case "$s" in
    dlopen|dlsym|dlclose) ;;
    *) echo "  [FAIL] unexpected undefined symbol: $s"; fail=1 ;;
  esac
done
[ $fail -eq 0 ] && echo "  [ok]   only libdl symbols are undefined"

echo "==> exported entry points"
exports="$(readelf --dyn-syms -W "$SO" | awk '$4=="FUNC" && $7!="UND" {print $8}' | sort -u)"
echo "$exports" | sed 's/^/         /'
for want in xzo_probe JNI_OnLoad; do
  if echo "$exports" | grep -qx "$want"; then echo "  [ok]   exports $want";
  else echo "  [FAIL] missing export $want (linker GC?)"; fail=1; fi
done

echo
echo "size: $(stat -c%s "$SO") bytes -> $SO"
[ $fail -eq 0 ] && echo "RESULT: armeabi-v7a native build path VERIFIED" || { echo "RESULT: FAILED"; exit 1; }
