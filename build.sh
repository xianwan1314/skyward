#!/bin/bash
# Build the Skyward recovery image for the vivo iQOO 11S (PD2304 / V2304A).
#
#   ./build.sh
#
# Needs the Rust toolchain `rust-toolchain.toml` names, its
# aarch64-linux-android target, cargo-ndk, an Android NDK (r29 was used) and the
# lz4 command line tool, which the packer compresses the ramdisk with.
#
# The stock recovery partition the image is built on goes in
# stock/pd2304/recovery.img; one tree may also keep it at stock/recovery.img,
# and STOCK points at another image. stock/ and out/ are ignored by git.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

: "${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME to an Android NDK (r29 was used)}"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export PATH="$HOME/.cargo/bin:$PATH"

command -v lz4 >/dev/null 2>&1 || {
  echo "error: lz4 is missing: install it (apt-get install lz4, or brew install lz4)" >&2
  exit 1
}

STOCK="${STOCK:-}"
if [ -z "$STOCK" ]; then
  if [ -f "$ROOT/stock/pd2304/recovery.img" ]; then
    STOCK="$ROOT/stock/pd2304/recovery.img"
  elif [ -f "$ROOT/stock/recovery.img" ]; then
    STOCK="$ROOT/stock/recovery.img"
  else
    echo "error: put the stock recovery image at $ROOT/stock/pd2304/recovery.img" >&2
    echo "       (the recovery partition of the official full package, AVB footer included)" >&2
    exit 1
  fi
fi

LIBS="$ROOT/libs/pd2304"
[ -d "$LIBS" ] || {
  echo "error: no shared libraries in $LIBS" >&2
  exit 1
}

cd "$ROOT"

echo "== host: skyward-pack"
cargo build --release -p skyward-pack

echo "== android: skyward"
cargo ndk -t arm64-v8a --platform 30 build --release -p skyward

echo "== android: skyward-system-init (static)"
RUSTFLAGS="-C target-feature=+crt-static" \
  cargo ndk -t arm64-v8a --platform 30 build --release \
  -p skyward-system-init --target-dir target/system-init

mkdir -p "$ROOT/out"
echo "== pack: skyward-pd2304.img"
target/release/skyward-pack recovery \
  --stock "$STOCK" \
  --binary target/aarch64-linux-android/release/skyward \
  --system-init target/system-init/aarch64-linux-android/release/system-init \
  --config "$ROOT/devices/pd2304.toml" \
  --font "$ROOT/resources/fonts/MiSansVF.ttf" \
  --mono "$ROOT/resources/fonts/KirkMono-Regular.ttf" \
  --mono-license "$ROOT/resources/fonts/KirkMono-OFL.txt" \
  --libraries "$LIBS" \
  --out "$ROOT/out/skyward-pd2304.img"

ls -lh "$ROOT/out/skyward-pd2304.img"
sha256sum "$ROOT/out/skyward-pd2304.img"
