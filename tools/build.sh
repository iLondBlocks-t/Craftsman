#!/usr/bin/env bash
# Build the XZO-Domyx PE APK from the stock 0.14.3 APK + src/smali.
#
#   tools/bootstrap.sh     # once, to fetch the toolchain
#   tools/build.sh
#
# Output: out/XZO-Domyx-PE-0.14.3.apk  (zipaligned + signed)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_APK="$ROOT/Minecraft-PE-0-14-3.apk"
WORK="$ROOT/build"
OUT="$ROOT/out"
TOOLS="${TOOLS:-$HOME/.local/tools}"
PYLIBS="${PYLIBS:-$HOME/.local/pylibs}"

export PYTHONPATH="$PYLIBS:$ROOT/tools"

# This sandbox periodically wipes ~/.local, which silently leaves the build
# with no JRE and no apktool. Re-bootstrap instead of failing in a confusing way.
if ! python3 -c 'import jdk4py' 2>/dev/null || [ ! -f "$TOOLS/apktool-2.0.3.jar" ]; then
  echo "==> toolchain missing, running bootstrap.sh"
  bash "$ROOT/tools/bootstrap.sh"
fi

JAVA="$(python3 -c 'import jdk4py; print(jdk4py.JAVA_HOME)')/bin/java"
APKTOOL="$TOOLS/apktool-2.0.3.jar"

mkdir -p "$OUT"

echo "==> 1/5  decode stock APK (raw resources: resources.arsc is never re-encoded)"
if [ ! -d "$WORK/dec" ]; then
  mkdir -p "$WORK"
  "$JAVA" -jar "$APKTOOL" d -r -f -o "$WORK/dec" "$BASE_APK" >/dev/null
fi

echo "==> 2/5  overlay our smali sources + patch the game's smali"
mkdir -p "$WORK/dec/smali"
cp -r "$ROOT/src/smali/." "$WORK/dec/smali/"
python3 "$ROOT/tools/patch_smali.py" "$WORK/dec"

echo "==> 3/5  assemble classes.dex"
rm -rf "$WORK/dec/build"
# apktool 2.0.3 builds sources first, then dies trying to exec the 32-bit `aapt`
# we cannot run. The dex it produced is complete and correct, so harvest it and
# skip the resource stage entirely (we never change resources by design).
set +e
"$JAVA" -jar "$APKTOOL" b -o /dev/null "$WORK/dec" > "$WORK/apktool.log" 2>&1
set -e
DEX="$WORK/dec/build/apk/classes.dex"
if [ ! -f "$DEX" ]; then
  echo "!! smali assembly failed:"; grep -vE '^\s+at |^\s+\.\.\.' "$WORK/apktool.log" | head -30; exit 1
fi
echo "    classes.dex: $(stat -c%s "$DEX") bytes"

echo "==> 4/5  patch AndroidManifest.xml"
python3 "$ROOT/tools/patch_manifest.py" "$WORK/dec/AndroidManifest.xml" "$WORK/AndroidManifest.patched.xml"

echo "==> 5/5  restyle menu textures, repack, zipalign, sign"
python3 "$ROOT/tools/retexture.py" "$WORK/dec" "$WORK/textures"

python3 "$ROOT/tools/repack.py" \
  --base "$BASE_APK" \
  --dex "$DEX" \
  --manifest "$WORK/AndroidManifest.patched.xml" \
  --override "$WORK/textures" \
  --keystore "$ROOT/xzodomyx.p12" \
  --out "$OUT/XZO-Domyx-PE-0.14.3.apk"

echo
echo "Done: $OUT/XZO-Domyx-PE-0.14.3.apk"
