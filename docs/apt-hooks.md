# Apt Post-Invoke + Pre-Install hooks

**Status:** Active

Several DPkg hooks in $PREFIX/etc/apt/apt.conf.d/: 99-zed-rewrite-postinst (sed maintainer scripts), 98-zed-patchelf (hex-patch com.termux paths, DT_RUNPATH included, and the standalone /etc/resolv.conf in every ELF the dpkg run installed, found through a stamp its Pre-Invoke hook touches; before v2026.05.06-r6 it only looked in bin/, sbin/, libexec/ and lib/*.so*, so a reinstalled apt kept com.termux in lib/apt/methods/http and couldn't fetch: zdroid-bootstrap#1), 97-zed-node-platform (re-apply node platform patch after pkg install nodejs), pre-install hook for shebang fixups. Each hook is idempotent.

**Detailed writeup: TODO.** Stub created so the index links resolve.
