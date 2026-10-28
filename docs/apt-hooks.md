# Apt Post-Invoke + Pre-Install hooks

**Status:** Active

Several DPkg hooks in $PREFIX/etc/apt/apt.conf.d/: 99-zed-rewrite-postinst (sed maintainer scripts), 97-zed-node-platform (re-apply node platform patch after pkg install nodejs), and 97-zed-pre-install, which rewrites com.termux paths in every file of each incoming .deb, ELF files and their DT_RUNPATH included, before dpkg unpacks it. Each hook is idempotent.

Until v2026.05.06-r6 a DPkg::Post-Invoke hook, 98-zed-patchelf, patched installed ELF files instead. It ran only after the whole dpkg run, so packages' scripts ran with libraries that still pointed at com.termux, and it only looked in bin/, sbin/, libexec/ and lib/*.so*: `pkg upgrade` reinstalls apt from Termux's repository, and the new lib/apt/methods/http kept com.termux in its RUNPATH, so apt couldn't fetch anything (zdroid-bootstrap#1).

**Detailed writeup: TODO.** Stub created so the index links resolve.
