#!/usr/bin/env bash
# Builds bootstrap-aarch64.zip from a base zip, an earlier release of this
# bootstrap: copies patches/ over it, and deletes what earlier releases
# shipped and patches/ no longer has.
#
# Usage: ./build.sh <input zip> <output zip>
set -euo pipefail

IN_ZIP="${1:?usage: $0 <input zip> <output zip>}"
OUT_ZIP="$(realpath -m "${2:?usage: $0 <input zip> <output zip>}")"
[ -f "$IN_ZIP" ] || { echo "input zip not found: $IN_ZIP" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOTFS="$WORK/rootfs"
mkdir -p "$ROOTFS"

unzip -q "$IN_ZIP" -d "$ROOTFS"
cp -a "$SCRIPT_DIR/patches"/. "$ROOTFS"/

REMOVED=(
    # Made dpkg delete lib/libc++_shared.so when it upgraded libc++.
    etc/dpkg/dpkg.cfg.d/zed-protect-libs
    # Patched installed files after each dpkg run, too late and in too few
    # places; zed-pre-install-rewrite.sh now patches packages beforehand.
    etc/apt/apt.conf.d/98-zed-patchelf
    etc/apt/zed-patchelf-hook.sh
    # Unneeded once the pre-install hook repacks packages as com.zdroid
    # ones: stock dpkg installs them, and their metadata is already right.
    etc/apt/preferences.d/zed-pin-dpkg
    etc/apt/apt.conf.d/99-zed-rewrite-postinst
    # Didn't change what Node reports on every device; the npm wrapper sets
    # npm_config_os=linux instead.
    etc/apt/apt.conf.d/97-zed-node-platform
    etc/apt/zed-node-platform-hook.sh
)
for path in "${REMOVED[@]}"; do
    rm -f "$ROOTFS/$path"
done

rm -f "$OUT_ZIP"
(cd "$ROOTFS" && zip -qry "$OUT_ZIP.tmp" .)
mv "$OUT_ZIP.tmp" "$OUT_ZIP"
echo "build: $OUT_ZIP ($(($(stat -c%s "$OUT_ZIP") / 1024 / 1024)) MB)"
