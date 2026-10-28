# Apt dpkg pin

**Status:** Active

$PREFIX/etc/apt/preferences.d/zed-pin-dpkg pins dpkg to the bootstrap's version (1.22.6-5) at Pin-Priority 1001. Stops `pkg upgrade` from replacing our patched dpkg with Termux's build, which lacks the com.termux path rewrite. Until v2026.05.06-r6 it used `Pin: release *`, which matched the repository's versions too, so it would have installed Termux's next dpkg instead of holding ours; it also pinned patchelf, which only needs to stay installed.

**Detailed writeup: TODO.** Stub created so the index links resolve.
