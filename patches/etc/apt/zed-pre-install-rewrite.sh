#!/data/data/com.zdroid/files/usr/bin/sh
# apt's DPkg::Pre-Install-Pkgs runs this with the .deb paths on stdin before
# dpkg unpacks them. Termux's repository builds every package for
# com.termux; each one is repacked as a com.zdroid package, so plain dpkg
# installs it where Zdroid's userland lives:
#   - data/data/com.termux/ becomes data/data/com.zdroid/, and symlinks
#     pointing into it are re-pointed.
#   - in every file, ELF binaries and DEBIAN/ metadata included,
#     /data/data/com.termux/ -> /data/data/com.zdroid/, which also fixes
#     DT_RUNPATH. Both are 22 bytes, so no offset in an ELF file moves.
#   - a standalone "/etc/resolv.conf" -> "/sdcard/.zed/r", which
#     gpui_android::dns_bridge fills with Android's DNS servers. Only with
#     NUL on both sides: "$PREFIX/etc/resolv.conf", which Termux's builds
#     read and the bootstrap ships, must stay.
# Rewriting the package, not the installed files, means nothing from it
# runs unpatched. An earlier DPkg::Post-Invoke hook patched files after the
# whole dpkg run, so its packages' scripts ran with libraries that still
# pointed at com.termux, and it only looked in some directories: pkg upgrade
# left apt unable to fetch (zdroid-bootstrap#1).
set -u
PREFIX=/data/data/com.zdroid/files/usr
export PATH="$PREFIX/bin:$PATH"
# The bootstrap's dpkg-deb, a build with a com.termux path rewrite, renames
# paths while it extracts when this is set, which Zdroid did before 0.9.19.
# Unset, it unpacks packages as published, like Termux's own dpkg-deb.
unset TERMUX_APP__PACKAGE_NAME
[ -x "$PREFIX/bin/dpkg-deb" ] || exit 0
[ -x "$PREFIX/bin/perl" ] || exit 0
while IFS= read -r deb; do
    case "$deb" in *.deb) ;; *) continue ;; esac
    [ -f "$deb" ] || continue
    tmp=$(mktemp -d 2>/dev/null) || continue
    if dpkg-deb -R "$deb" "$tmp" 2>/dev/null; then
        # Packages without files have no data directory.
        if [ -d "$tmp/data/data/com.termux" ]; then
            mv "$tmp/data/data/com.termux" "$tmp/data/data/com.zdroid"
        fi
        find "$tmp" -type l | while IFS= read -r link; do
            target=$(readlink "$link")
            case "$target" in
                /data/data/com.termux/*)
                    ln -sfn "/data/data/com.zdroid/${target#/data/data/com.termux/}" "$link"
                    ;;
            esac
        done
        grep -rl -a -e '/data/data/com.termux/' -e '/etc/resolv.conf' "$tmp" 2>/dev/null \
            | "$PREFIX/bin/perl" -e '
                while (my $path = <STDIN>) {
                    chomp $path;
                    # A package can ship files read-only.
                    my $mode = (stat $path)[2] & 07777;
                    chmod($mode | 0200, $path);
                    if (open my $fh, "+<:raw", $path) {
                        my $data = do { local $/; <$fh> };
                        my $count = ($data =~ s{/data/data/com\.termux/}{/data/data/com.zdroid/}g)
                            + ($data =~ s{\x00/etc/resolv\.conf\x00}{\x00/sdcard/.zed/r\x00\x00\x00}g);
                        if ($count) {
                            seek $fh, 0, 0;
                            print $fh $data;
                        }
                        close $fh;
                    }
                    chmod($mode, $path);
                }
            '
        # dpkg-deb -R extracts maintainer scripts at 0644; -b refuses to
        # rebuild unless they're 0555..0775.
        for s in preinst postinst prerm postrm; do
            [ -f "$tmp/DEBIAN/$s" ] && chmod 0755 "$tmp/DEBIAN/$s" 2>/dev/null
        done
        # --nocheck: Termux builds packages with its own tooling, and some
        # list conffiles they don't ship (tor), which dpkg-deb -b rejects.
        # Uncompressed: the package only goes to dpkg, right after.
        dpkg-deb --nocheck -Znone -b "$tmp" "$deb" >/dev/null 2>&1 \
            || echo "zed-pre-install-rewrite: couldn't repack $deb; it installs with com.termux paths" >&2
    fi
    rm -rf "$tmp"
done
exit 0
