# dpkg path-rewrite patches

**Status:** Unneeded since v2026.05.06-r8. The pre-install hook repacks every package as a com.zdroid one, so the rewrite never matches; the patched dpkg stays in the base until a `pkg upgrade` installs Termux's (repacked) dpkg in its place. The patches are still in the Zdroid repository's history.

Two patches in crates/gpui_android/termux-patches/dpkg/: lib-dpkg-tarfn.c.patch rewrites /data/data/com.termux/* paths in dpkg's tar_extractor; src-deb-extract.c.patch does the same in dpkg-deb. Lets pkg install <upstream-deb> land files at our prefix instead of com.termux. Layer 1 of the three-layer L2g patch stack.

**Detailed writeup: TODO.** Stub created so the index links resolve.
