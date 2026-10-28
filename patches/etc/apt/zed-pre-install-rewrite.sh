#!/data/data/com.zdroid/files/usr/bin/sh
# apt's DPkg::Pre-Install-Pkgs runs this with the .deb paths on stdin before
# dpkg unpacks them. Termux's repository builds every package for
# com.termux, so each one is rewritten for com.zdroid first, in every file,
# maintainer scripts and ELF binaries alike:
#   - /data/data/com.termux/ -> /data/data/com.zdroid/, which also fixes
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
[ -x "$PREFIX/bin/dpkg-deb" ] || exit 0
[ -x "$PREFIX/bin/perl" ] || exit 0
while IFS= read -r deb; do
    case "$deb" in *.deb) ;; *) continue ;; esac
    [ -f "$deb" ] || continue
    tmp=$(mktemp -d 2>/dev/null) || continue
    if dpkg-deb -R "$deb" "$tmp" 2>/dev/null; then
        files=$(grep -rl -a -e '/data/data/com.termux/' -e '/etc/resolv.conf' "$tmp" 2>/dev/null)
        if [ -n "$files" ]; then
            printf '%s\n' "$files" | "$PREFIX/bin/perl" -e '
                my $changed = 0;
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
                            $changed = 1;
                        }
                        close $fh;
                    }
                    chmod($mode, $path);
                }
                exit($changed ? 0 : 1);
            '
            if [ $? -eq 0 ]; then
                # dpkg-deb -R extracts maintainer scripts at 0644; -b refuses
                # to rebuild unless they're 0555..0775.
                for s in preinst postinst prerm postrm; do
                    [ -f "$tmp/DEBIAN/$s" ] && chmod 0755 "$tmp/DEBIAN/$s" 2>/dev/null
                done
                # --nocheck: Termux builds packages with its own tooling, and
                # some list conffiles they don't ship (tor), which dpkg-deb -b
                # rejects. dpkg's own path rewrite turns the com.termux paths
                # into com.zdroid while it unpacks, matching the rewritten
                # DEBIAN/conffiles. Uncompressed: the package only goes to
                # dpkg, right after.
                dpkg-deb --nocheck -Znone -b "$tmp" "$deb" >/dev/null 2>&1 \
                    || echo "zed-pre-install-rewrite: couldn't repack $deb; it installs with com.termux paths" >&2
            fi
        fi
    fi
    rm -rf "$tmp"
done
exit 0
