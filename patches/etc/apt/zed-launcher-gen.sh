#!/data/data/com.zdroid/files/usr/bin/sh
# Run by the npm wrapper (.zed/bin/npm) after every npm command. Makes the
# Linux binaries npm packages ship (Claude Code, Codex, ...) run here, for
# each ELF file under $PREFIX/lib/node_modules and each $PREFIX/bin symlink
# into it:
#   1. A musl-dynamic binary asks for /lib/ld-musl-aarch64.so.1, which
#      Android doesn't have: point it at the bundled
#      $PREFIX/lib/ld-musl-aarch64.so.1, and give it a $PREFIX/bin wrapper
#      that drops LD_PRELOAD. Zdroid's terminal and the npm wrapper preload
#      the bionic libtermux-exec.so, which musl's loader can't load.
#   2. Rewrite a standalone "/etc/resolv.conf" to "/sdcard/.zed/r" (same
#      length, NUL on both sides), which gpui_android::dns_bridge fills
#      with Android's DNS servers.
#   3. A glibc-dynamic binary gets a wrapper through glibc-runner (grun),
#      or one that says how to install it.
# Idempotent: a second run finds nothing left to change.
set -u
PREFIX=/data/data/com.zdroid/files/usr
[ -d "$PREFIX/lib/node_modules" ] || exit 0
PATCHELF="$PREFIX/bin/patchelf"
[ -x "$PATCHELF" ] || exit 0

write_if_changed() {
    dst="$1"; want="$2"
    if [ -f "$dst" ] && [ "$(cat -- "$dst" 2>/dev/null)" = "$want" ]; then
        return 0
    fi
    rm -f -- "$dst"
    printf '%s\n' "$want" > "$dst"
    chmod +x -- "$dst"
}

is_elf() {
    [ "$(head -c 4 -- "$1" 2>/dev/null | tail -c 3)" = ELF ]
}

# Empty for static binaries, which have no interpreter.
interpreter() {
    "$PATCHELF" --print-interpreter "$1" 2>/dev/null
}

patch_resolv_conf() {
    bin="$1"
    [ -x "$PREFIX/bin/perl" ] || return 0
    grep -q -a -- '/etc/resolv.conf' "$bin" 2>/dev/null || return 0
    "$PREFIX/bin/perl" -e '
        my $path = $ARGV[0];
        open my $fh, "+<:raw", $path or exit 0;
        my $data = do { local $/; <$fh> };
        my $count = 0;
        while ($data =~ /\x00\/etc\/resolv\.conf\x00/g) {
            seek $fh, $-[0] + 1, 0;
            print $fh "/sdcard/.zed/r\x00\x00";
            $count++;
        }
        close $fh;
        print STDERR "zed-launcher-gen: rewrote $count /etc/resolv.conf in $path\n" if $count > 0;
    ' "$bin" 2>&1
}

handle_elf() {
    bin="$1"
    is_elf "$bin" || return 0
    if [ "$(interpreter "$bin")" = /lib/ld-musl-aarch64.so.1 ]; then
        "$PATCHELF" --set-interpreter "$PREFIX/lib/ld-musl-aarch64.so.1" "$bin" 2>/dev/null || true
        "$PATCHELF" --set-rpath "$PREFIX/lib" "$bin" 2>/dev/null || true
    fi
    patch_resolv_conf "$bin"
    if [ "$(interpreter "$bin")" = "$PREFIX/lib/ld-musl-aarch64.so.1" ]; then
        name=$(basename -- "$bin")
        want="#!$PREFIX/bin/sh
exec env -u LD_PRELOAD \"$bin\" \"\$@\""
        write_if_changed "$PREFIX/bin/$name" "$want"
    fi
}

handle_link() {
    link="$1"
    target=$(readlink -f -- "$link" 2>/dev/null)
    [ -n "$target" ] && [ -f "$target" ] || return 0
    case "$target" in
        "$PREFIX"/lib/node_modules/*) ;;
        *) return 0 ;;
    esac
    handle_elf "$target"
    case "$(interpreter "$target")" in
        */ld-linux-*)
            name=$(basename -- "$link")
            if [ -x "$PREFIX/bin/grun" ]; then
                want="#!$PREFIX/bin/sh
exec \"$PREFIX/bin/grun\" \"$target\" \"\$@\""
            else
                want="#!$PREFIX/bin/sh
echo \"error: $name needs glibc-runner. Install via:\" >&2
echo \"  pkg install tur-repo && pkg install glibc-runner\" >&2
exit 1"
            fi
            write_if_changed "$link" "$want"
            ;;
    esac
}

for link in "$PREFIX"/bin/*; do
    [ -L "$link" ] || continue
    handle_link "$link"
done

find "$PREFIX/lib/node_modules" -type f -perm -u+x \
    ! -name '*.js' ! -name '*.cjs' ! -name '*.mjs' ! -name '*.json' \
    ! -name 'node' ! -name 'corepack' \
    2>/dev/null | while IFS= read -r bin; do
    handle_elf "$bin"
done
exit 0
