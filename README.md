# zdroid-bootstrap

Termux-flavored userland tarball that the [Zdroid Android port of Zed](https://github.com/ilkersigirci/zed-android-port) extracts into `$PREFIX` for the **Bootstrap** runtime adapter.

This is a fork of Dylan Murzello's [`Dylanmurzello/zdroid-bootstrap`](https://github.com/Dylanmurzello/zdroid-bootstrap), which stopped receiving updates after `v2026.05.06-r4`. It keeps that release's userland and publishes new releases with changes to `patches/`.

The bootstrap is the rebuilt Termux userland with Zdroid-specific patches baked in:
- `applicationId=com.zdroid` (instead of `com.termux`) — every binary's `DT_RUNPATH` and shebang resolves to our app's data dir
- Patched dpkg / apt for cross-package-name `pkg install`
- Permission fixes for app-private storage exec
- libtermux-exec built with our paths
- apt Pre/Post-Invoke hooks + dpkg path-protect + dpkg/patchelf pins + node platform hook (Phase 8b — see `patches/`)
- musl loader with `/etc/resolv.conf` → `/sdcard/.zed/r` baked in
- npm wrapper + launcher-generator under `.zed/bin/`
- bash-`-l` self-bootstrap shim under `etc/profile.d/`

## Distribution

Releases ship `bootstrap-aarch64.zip` (~241 MB) as a release asset. Zdroid installs it when the user taps **Install** on the Bootstrap card of the runtime picker. Each Zdroid version pins one release of this repository, by tag and SHA-256, so a new release reaches users with the next Zdroid release. The picker can also download the latest release of another repository that publishes `bootstrap-aarch64.zip`.

Tag naming: `v<termux-bootstrap-version>-r<revision>` (e.g. `v2026.05.06-r5`). The editor stores the tag in `$PREFIX/.bootstrap-version`.

## Building

Pushing an annotated `v*` tag runs `.github/workflows/release.yml`, which builds the zip and publishes it as the tag's release, with the tag's message as the release notes:

```sh
git tag -a v2026.05.06-r6 -m "What changed, for users"
git push origin v2026.05.06-r6
```

Two source inputs:
1. A base `bootstrap-aarch64.zip`. Dylan built the first one from [termux-packages](https://github.com/termux/termux-packages) with `TERMUX_APP_PACKAGE=com.zdroid` and a patched dpkg, but neither that build nor the zip is published. The workflow starts from his last release, `v2026.05.06-r4`, pinned by SHA-256: `build.sh` only overlays files and rewrites paths, so running it again on its own output is harmless. One limit follows: deleting a file from `patches/` doesn't remove it from the zip.
2. The `patches/` directory in this repo — every static file the editor's `apply_runtime_patches` used to drop at first boot. Pure shell / config / one binary blob (musl loader).

To build locally:

```sh
./build.sh <input zip> <output zip>
```

What `build.sh` does:
- Unzips the input.
- Copies `patches/` over the rootfs (preserving 0755 / 0644 modes baked in).
- Runs `perl -i -pe` rewrites of `/data/data/com.termux/` → `/data/data/com.zdroid/` over every dpkg metadata file type (preinst/postinst/prerm/postrm + conffiles + md5sums + list + triggers + templates) and the master status DB. Catches the maintainer-script content gap that the termux-packages CI sed misses for libcompiler-rt + termux-tools.
- Appends a `SYMLINKS.txt` entry for `libc.musl-aarch64.so.1` → `ld-musl-aarch64.so.1` so the editor's extractor replays the alias at unpack time.
- Re-zips.

## Patches directory

| Path | Source | Purpose |
|---|---|---|
| `etc/profile.d/zed-init.sh` | install_profile_d_init | `bash -l` self-bootstrap (PREFIX/PATH/HOME) for sideband shells (run-as, adb, ssh subprocess) |
| `etc/apt/preferences.d/zed-pin-dpkg` | install_apt_dpkg_pin | Pin-Priority 1001 holds for `dpkg` and `patchelf` packages — refuses upstream upgrade that would brick path-rewrite |
| `etc/dpkg/dpkg.cfg.d/zed-protect-libs` | install_dpkg_path_protect | dpkg path-exclude for `libc++_shared.so` — protects our build-time variant from upstream replacement |
| `etc/apt/apt.conf.d/99-zed-rewrite-postinst` | install_apt_rewrite_hook | DPkg::Post-Invoke sed over every metadata file type rewriting com.termux→com.zdroid |
| `etc/apt/apt.conf.d/98-zed-patchelf` + `etc/apt/zed-patchelf-hook.sh` | install_apt_patchelf_hook | patchelf-set-rpath + perl-hex-patch on freshly-installed ELFs (handles upstream binaries with com.termux DT_RUNPATH + rodata) |
| `etc/apt/apt.conf.d/97-zed-pre-install` + `etc/apt/zed-pre-install-rewrite.sh` | install_apt_pre_install_hook | Reads .deb stdin, unpacks, rewrites com.termux→com.zdroid in text files, repacks |
| `etc/apt/apt.conf.d/97-zed-node-platform` + `etc/apt/zed-node-platform-hook.sh` | install_apt_node_platform_hook | perl rewrites `\x00android\x00` → `\x00linux\x00\x00` in `$PREFIX/bin/node` so `process.platform === 'linux'` |
| `.zed/bin/npm` | install_npm_wrapper | PATH-precedence wrapper setting LD_PRELOAD=libtermux-exec.so + npm_config_libc=musl, post-invokes launcher generator |
| `etc/apt/zed-launcher-gen.sh` | install_npm_launcher_generator | Walks `$PREFIX/bin/*` and `$PREFIX/lib/node_modules/**`, classifies ld-musl vs ld-linux, generates musl-static + grun wrappers |
| `lib/ld-musl-aarch64.so.1` | install_musl_linker | Alpine's musl loader with the `/etc/resolv.conf` → `/sdcard/.zed/r` resolv.conf path hex-patched in (Bun-compiled CLIs route DNS through our materialized resolv file) |

See `docs-extraction-notes.md` for the original Rust source-line mapping per file.

## History

Pre-Phase-6 of the Termux-divestment refactor, the zip lived under [Dylanmurzello/zed-android-port releases](https://github.com/Dylanmurzello/zed-android-port/releases) (`bootstrap-2026.05.06-r2` and earlier). Phase 6 moved distribution here. Phase 8a deleted the editor-side APK-asset extraction path. Phase 8b moved the runtime patches into `patches/` here so the zip ships pre-patched; the editor's `apply_runtime_patches` Rust path is then redundant.
