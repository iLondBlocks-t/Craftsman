#!/usr/bin/env bash
# Reproducible toolchain bootstrap for MCPE 0.14.3 modding in this sandbox.
#
# Egress here is limited to pypi.org, registry.npmjs.org and github.com (git only).
# In particular ALL GitHub *release assets* (objects.githubusercontent.com), the
# Android SDK (dl.google.com), Maven Central and apt (deb.debian.org) are blocked,
# so every tool below is sourced from PyPI or npm. See docs/00-RECON.md section 6.
set -euo pipefail

TOOLS="${TOOLS:-$HOME/.local/tools}"
PYLIBS="${PYLIBS:-$HOME/.local/pylibs}"
mkdir -p "$TOOLS/bin" "$PYLIBS"

echo "==> Python tooling (JRE, dex analysis, aapt2, crypto for signing)"
pip install --quiet --target="$PYLIBS" jdk4py androguard aapt2 cryptography pillow capstone ziglang

export PYTHONPATH="$PYLIBS"
JAVA_HOME="$(python3 -c 'import jdk4py; print(jdk4py.JAVA_HOME)')"
echo "    JAVA_HOME=$JAVA_HOME"
"$JAVA_HOME/bin/java" -version

echo "==> apktool 2.0.3 (+ shaded smali/baksmali/dexlib2) from npm"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && npm pack apktool >/dev/null 2>&1 && tar xzf apktool-*.tgz )
cp "$tmp/package/bin/apktool.jar" "$TOOLS/apktool-2.0.3.jar"

echo "==> aapt2 (x86_64) — fallback only; the build pipeline avoids it"
cp "$PYLIBS/aapt2/bin/Linux/aapt2" "$TOOLS/bin/aapt2"
chmod +x "$TOOLS/bin/aapt2"

cat > "$TOOLS/env.sh" <<EOF
export PYTHONPATH="$PYLIBS"
export JAVA_HOME="$JAVA_HOME"
export PATH="$TOOLS/bin:\$JAVA_HOME/bin:\$PATH"
export APKTOOL_JAR="$TOOLS/apktool-2.0.3.jar"
apktool() { java -jar "\$APKTOOL_JAR" "\$@"; }
smali()   { java -cp "\$APKTOOL_JAR" org.jf.smali.main "\$@"; }
EOF

echo
echo "Done. Activate with:  source $TOOLS/env.sh"
