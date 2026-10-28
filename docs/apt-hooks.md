# Apt Post-Invoke + Pre-Install hooks

**Status:** Active

One DPkg hook in $PREFIX/etc/apt/apt.conf.d/: 97-zed-pre-install repacks each incoming .deb as a com.zdroid package before dpkg unpacks it. It renames the data/data/com.termux tree, re-points symlinks into it, and rewrites com.termux paths in every file, ELF files and their DT_RUNPATH included. 99-zed-rewrite-postinst (sed over dpkg's records) and 97-zed-node-platform (the Node platform patch) were removed in v2026.05.06-r8.

Until v2026.05.06-r6 a DPkg::Post-Invoke hook, 98-zed-patchelf, patched installed ELF files instead. It ran only after the whole dpkg run, so packages' scripts ran with libraries that still pointed at com.termux, and it only looked in bin/, sbin/, libexec/ and lib/*.so*: `pkg upgrade` reinstalls apt from Termux's repository, and the new lib/apt/methods/http kept com.termux in its RUNPATH, so apt couldn't fetch anything (zdroid-bootstrap#1).

**Detailed writeup: TODO.** Stub created so the index links resolve.
