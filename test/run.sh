#!/usr/bin/env bash
# Installs a bootstrap zip the way Zdroid's extractor does, runs a scenario
# in termux-docker as the app's user would in Zdroid's terminal, then reports
# what changed. Needs root (file ownership) and an arm64 host.
#
# Usage: sudo test/run.sh <bootstrap zip> <scenario>
set -uo pipefail

ZIP="$(realpath "$1")"
SCENARIO="$2"
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
# Mounted at /data/data/com.zdroid in the container.
APP="$WORK/com.zdroid"
PREFIX="$APP/files/usr"

# Android creates every app's cache directory, where apt keeps downloads.
mkdir -p "$PREFIX" "$APP/files/home" "$APP/cache"
unzip -q "$ZIP" -d "$PREFIX"
# Zdroid's extractor keeps only the owner's permission bits.
find "$APP" -type d -exec chmod 700 {} +
find "$PREFIX" -type f -perm -u+x -exec chmod 700 {} +
find "$PREFIX" -type f ! -perm -u+x -exec chmod 600 {} +
# Then it creates the symlinks SYMLINKS.txt lists as `target←link`.
(
    cd "$PREFIX"
    while IFS= read -r line; do
        target="${line%%←*}"
        link="${line#*←}"
        mkdir -p "$(dirname "$link")"
        ln -s "$target" "$link"
    done < SYMLINKS.txt
    rm SYMLINKS.txt
)
mkdir -p "$PREFIX/tmp"
cp "$TEST_DIR/scenario.sh" "$APP/scenario.sh"
cp -a "$PREFIX/lib/apt/methods" "$WORK/methods.pristine"
chown -R 1000:1000 "$APP"
# After chown, which changes every inode.
touch "$WORK/installed"

docker run --rm --privileged -v "$APP:/data/data/com.zdroid" termux/termux-docker:aarch64 \
    /data/data/com.zdroid/files/usr/bin/bash /data/data/com.zdroid/scenario.sh "$SCENARIO"

annotate() {
    # GitHub shows these on the run's page; %0A keeps the line breaks.
    echo "::warning title=$SCENARIO: $1::$(tail -n 40 | sed ':a;N;$!ba;s/%/%25/g;s/\n/%0A/g')"
}
annotate "steps" < "$APP/results"
for log in "$APP"/logs/*; do
    annotate "output of step $(basename "$log")" < "$log"
done
{
    ls -la "$PREFIX/lib/apt/methods/"
    readelf -d "$PREFIX/lib/apt/methods/http" | grep -E "RUNPATH|NEEDED"
    cmp "$WORK/methods.pristine/http" "$PREFIX/lib/apt/methods/http" && echo "http unchanged"
} 2>&1 | annotate "https method"
{
    ls -la "$PREFIX"/lib/libandroid-glob*
    sha256sum "$PREFIX/lib/libandroid-glob.so"
} 2>&1 | annotate "libandroid-glob"
# dpkg keeps each file's mtime from the package, so compare inode change times.
find "$PREFIX" -type f -cnewer "$WORK/installed" | while IFS= read -r file; do
    if [ "$(head -c 4 "$file" | tail -c 3)" = ELF ]; then
        echo "${file#"$PREFIX"/}"
    fi
done | sort | annotate "ELF files changed after install"
grep -E "^(Commandline|Install|Upgrade|Remove|Reinstall|Error)" "$PREFIX/var/log/apt/history.log" 2>&1 \
    | cut -c1-400 | annotate "apt history"

grep -q "^apt update -> exit 0$" "$APP/results"
