#!/usr/bin/env bash
# Build this tree inside WSL from a Windows checkout.
#
#   wsl -d Ubuntu -- bash tools/wsl-build.sh
#
# The sources are copied into a Linux filesystem first, because compiling in a
# tree on /mnt is much slower; the image is written back into this tree's out/.
#
# Environment:
#   ANDROID_NDK_HOME   NDK to build with                 (default: ~/android-ndk-r29)
#   SKYWARD_BUILD_DIR  Linux tree the sources build in   (default: ~/skyward-build)
#   SKYWARD_OFFLINE=1  build without fetching crates, from ~/.cargo/registry
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD_DIR="${SKYWARD_BUILD_DIR:-$HOME/skyward-build}"
NDK="${ANDROID_NDK_HOME:-$HOME/android-ndk-r29}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

export PATH="$HOME/.cargo/bin:$PATH"

[ -f "$ROOT/build.sh" ] || die "$ROOT does not hold build.sh; run this from the repository"
[ -d "$NDK" ] || die "no NDK at $NDK: set ANDROID_NDK_HOME to an Android NDK (r29 was used)"
command -v rsync >/dev/null 2>&1 || die "rsync is missing: install it (apt-get install rsync)"
command -v cargo >/dev/null 2>&1 || die "cargo is missing: install Rust (https://rustup.rs)"

if ! command -v lz4 >/dev/null 2>&1; then
  if [ -x "$HOME/.local/lz4/root/usr/bin/lz4" ]; then
    PATH="$HOME/.local/lz4/root/usr/bin:$PATH"
  else
    die "lz4 is missing: install it (apt-get install lz4, or brew install lz4)"
  fi
fi

export ANDROID_NDK_HOME="$NDK"
export ANDROID_NDK_ROOT="$NDK"
if [ "${SKYWARD_OFFLINE:-0}" = "1" ]; then
  export CARGO_NET_OFFLINE=true
fi

case "$ROOT" in
  /mnt/*)
    echo "== copy $ROOT into $BUILD_DIR =="
    mkdir -p "$BUILD_DIR"
    rsync -a --delete \
      --exclude .git --exclude out --exclude target --exclude stock \
      --exclude assets --exclude slides \
      "$ROOT"/ "$BUILD_DIR"/
    mkdir -p "$BUILD_DIR/stock/pd2304"
    if [ -f "$ROOT/stock/pd2304/recovery.img" ]; then
      ln -sf "$ROOT/stock/pd2304/recovery.img" "$BUILD_DIR/stock/pd2304/recovery.img"
    fi
    SRC="$BUILD_DIR"
    ;;
  *)
    SRC="$ROOT"
    ;;
esac

echo "== build =="
cd "$SRC"
time bash build.sh

echo "== copy the image back =="
mkdir -p "$ROOT/out"
cp "$SRC/out/skyward-pd2304.img" "$ROOT/out/"
sha256sum "$ROOT/out/skyward-pd2304.img"
