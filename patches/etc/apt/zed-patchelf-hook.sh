#!/data/data/com.zdroid/files/usr/bin/sh
# Runs after every dpkg invocation (apt.conf.d/98-zed-patchelf) on the ELF
# files that invocation installed. Termux's repository builds them for
# com.termux, so:
#   1. hex-patch /data/data/com.termux/ -> /data/data/com.zdroid/ everywhere
#      in the file, which also fixes DT_RUNPATH. Both are 22 bytes, so the
#      rewrite is in place and no offsets move.
#   2. hex-patch a standalone "/etc/resolv.conf" -> "/sdcard/.zed/r", which
#      gpui_android::dns_bridge fills with Android's DNS servers. Only when
#      NUL sits on both sides: "$PREFIX/etc/resolv.conf", which Termux's
#      builds read and the bootstrap ships, must stay.
#   3. if perl is missing and the RUNPATH still names com.termux, patchelf
#      it to $PREFIX/lib.
#
# Files are picked by what the dpkg run changed (newer than the stamp the
# Pre-Invoke hook touches), wherever they are: apt's own methods live in
# lib/apt/methods and are executables, not .so files. A run that missed
# them left `pkg upgrade`'s reinstalled apt unable to fetch anything:
# "library libandroid-glob.so not found" (zdroid-bootstrap#1).
#
# Invariants learned the hard way:
# 1. No --force-rpath: it converts DT_RUNPATH to DT_RPATH and has
#    truncated the dynamic section of some libraries.
# 2. Never patchelf the musl loader or libc++_shared.so: growing them
#    broke apt, patchelf and every musl CLI.
# 3. Never patchelf a file just because it has no RUNPATH: Termux builds
#    that need $PREFIX libraries carry one, and adding one to others
#    (Go tools, Bun CLIs) only risks breaking them.
set -u
PREFIX=/data/data/com.zdroid/files/usr
STAMP="$PREFIX/var/lib/dpkg/zed-patchelf.stamp"
[ -f "$STAMP" ] || exit 0

PATCHELF=""
if [ -x "$PREFIX/bin/patchelf" ]; then PATCHELF="$PREFIX/bin/patchelf"; elif [ -x "$PREFIX/glibc/bin/patchelf" ]; then PATCHELF="$PREFIX/glibc/bin/patchelf"; fi

is_elf() {
    [ "$(head -c 4 "$1" 2>/dev/null | tail -c 3)" = ELF ]
}

maybe_patchelf() {
    [ -n "$PATCHELF" ] || return 0
    case "${1##*/}" in
        ld-musl-aarch64.so.1|libc.musl-aarch64.so.1|libc++_shared.so) return 0 ;;
    esac
    current=$("$PATCHELF" --print-rpath "$1" 2>/dev/null) || return 0
    case "$current" in
        *com.termux*) "$PATCHELF" --set-rpath "$PREFIX/lib" "$1" 2>/dev/null || true ;;
    esac
}

maybe_hex_patch() {
    [ -x "$PREFIX/bin/perl" ] || return 0
    grep -q -a -e '/data/data/com.termux/' -e '/etc/resolv.conf' "$1" 2>/dev/null || return 0
    "$PREFIX/bin/perl" -e '
        my $path = $ARGV[0];
        open my $fh, "+<:raw", $path or exit 0;
        my $data = do { local $/; <$fh> };
        my ($termux, $resolv) = (0, 0);
        while ($data =~ m{/data/data/com\.termux/}g) {
            seek $fh, $-[0], 0;
            print $fh "/data/data/com.zdroid/";
            $termux++;
        }
        while ($data =~ m{\x00/etc/resolv\.conf\x00}g) {
            seek $fh, $-[0] + 1, 0;
            print $fh "/sdcard/.zed/r\x00\x00";
            $resolv++;
        }
        close $fh;
        print STDERR "zed-rodata-hex: $termux com.termux, $resolv /etc/resolv.conf in $path\n" if $termux || $resolv;
    ' "$1" 2>&1
}

# node_modules belongs to the npm wrapper's launcher generator; tmp and var
# hold no installed programs.
find "$PREFIX" \( -path "$PREFIX/tmp" -o -path "$PREFIX/var" -o -path "$PREFIX/lib/node_modules" \) -prune \
    -o -type f -cnewer "$STAMP" -print 2>/dev/null | while IFS= read -r f; do
    is_elf "$f" || continue
    maybe_hex_patch "$f"
    maybe_patchelf "$f"
done
exit 0
