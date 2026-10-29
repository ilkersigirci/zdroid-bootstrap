> [!IMPORTANT]  
> Since https://github.com/ilkersigirci/zed-android-port 0.10.0 release, zdroid uses its own runtime. Hence, bootstrap runtime removed and it is not needed anymore.

# zdroid-bootstrap

The Termux userland that [Zdroid](https://github.com/ilkersigirci/zed-android-port), the Android port of Zed, installs into `/data/data/com.zdroid/files/usr` (`$PREFIX`) for its **Bootstrap** runtime: the shell, the terminal's tools, language servers and package manager, running without root.

This is a fork of Dylan Murzello's [`Dylanmurzello/zdroid-bootstrap`](https://github.com/Dylanmurzello/zdroid-bootstrap), which stopped receiving updates after `v2026.05.06-r4`. It keeps that release's userland and changes the files in `patches/`.

## What's in it

**The base userland.** Termux's bootstrap, which Dylan built from [termux-packages](https://github.com/termux/termux-packages) with `TERMUX_APP_PACKAGE=com.zdroid`, so its programs look for files under `/data/data/com.zdroid`. It includes bash, coreutils, apt and dpkg, git, OpenSSH, curl, Perl, Python, Node.js, Go, rust-analyzer and patchelf. Neither that build nor its input is published, so every release starts from his `v2026.05.06-r4`. Its dpkg is his build with a `com.termux` path rewrite (the patches are in `base/dpkg/`), which nothing uses since `v2026.05.06-r8`; a `pkg upgrade` that brings a newer dpkg replaces it with Termux's.

**`patches/`**, copied over the base:

| Path | Purpose |
|---|---|
| `etc/apt/apt.conf.d/97-zed-pre-install`, `etc/apt/zed-pre-install-rewrite.sh` | Make packages from Termux's repository install under `com.zdroid` (below) |
| `.zed/bin/npm` | npm wrapper, first on Zdroid's `PATH`: sets npm's platform settings and runs the launcher generator afterwards (below) |
| `etc/apt/zed-launcher-gen.sh` | Makes the Linux binaries npm packages ship run here (below) |
| `lib/ld-musl-aarch64.so.1` | Alpine's musl 1.2.5 loader, for those binaries, with `/etc/resolv.conf` rewritten to `/sdcard/.zed/r` (below) |
| `etc/profile.d/zed-init.sh` | Sets `PREFIX`, `PATH`, `HOME` and the rest for login shells Zdroid didn't start, such as an SSH session into Zdroid |
| `etc/apt/sources.list` | Termux's own repository as the starting mirror |

## Packages from Termux's repository

Termux builds every package for `/data/data/com.termux`. Before dpkg unpacks a package, apt runs `zed-pre-install-rewrite.sh`, which repacks it as a `com.zdroid` package:

- its `data/data/com.termux` tree becomes `data/data/com.zdroid`, and symlinks pointing into it follow;
- `/data/data/com.termux/` becomes `/data/data/com.zdroid/` in every file, scripts, metadata and binaries alike, which also fixes the library path (`DT_RUNPATH`) of ELF files. Both names are 22 bytes, so no offset inside a binary moves; that's why the app is called `com.zdroid`;
- a standalone `/etc/resolv.conf` in a file becomes `/sdcard/.zed/r` (see DNS below).

Plain dpkg then installs it, and nothing from a package ever runs with `com.termux` paths. Two limits:

- `dpkg -i file.deb` skips apt's hooks; install local packages with `apt install ./file.deb`.
- Repacked packages stay uncompressed in apt's cache until dpkg has installed them, so a large transaction, such as the clang toolchain, briefly needs about its unpacked size.

## npm packages' Linux binaries

Packages such as Claude Code and Codex ship native Linux binaries as optional dependencies, built for musl or glibc, not for Android's bionic.

- **The npm wrapper** sets `npm_config_os=linux` and `npm_config_libc=musl`, so npm installs the musl Linux builds: npm compares a package's `os` with Node's `process.platform`, which is `android` here, and can't identify bionic. It also preloads `libtermux-exec.so` for npm's processes, which rewrites `#!/usr/bin/env` shebangs, as Android has no `/usr/bin/env`.
- **The launcher generator** runs after every npm command, over `$PREFIX/lib/node_modules`. A musl-dynamic binary gets the bundled loader as its interpreter, the DNS rewrite, and a `$PREFIX/bin` wrapper that drops `LD_PRELOAD`, since musl can't load the bionic `libtermux-exec.so`. A glibc-dynamic one gets a wrapper through glibc-runner (`grun`), or one saying how to install it. Static binaries, such as Codex's, only need the DNS rewrite.

## DNS

Android has no `/etc/resolv.conf`; its resolver goes through the system's DNS service. Programs with their own resolver, such as musl's or a statically linked one, read `/etc/resolv.conf` and fail. Zdroid writes Android's current DNS servers to `/sdcard/.zed/r` at startup (`gpui_android::dns_bridge`), and the rewrites above point those programs at it. Termux's own builds read `$PREFIX/etc/resolv.conf` or use the system resolver, and are left alone.

## Releases

Each release publishes `bootstrap-aarch64.zip` (~241 MB). Zdroid's runtime picker installs the latest release of the repository in its **Download from** field, this one by default, when the user taps **Install** or **Reinstall**, and checks it against the SHA-256 GitHub records for it. A release reaches new installs and reinstalls as soon as it's published; installed userlands keep theirs. Tags look like `v2026.05.06-r8`: the Termux bootstrap version, then a revision.

To release, push an annotated tag. `.github/workflows/release.yml` runs the tests, and only if they pass builds the zip and publishes it, with the tag's message as the release notes:

```sh
git tag -a v2026.05.06-r9 -m "What changed, for users"
git push origin v2026.05.06-r9
```

## Building and testing

`build.sh <input zip> <output zip>` unzips the base, copies `patches/` over it, deletes the files listed in its `REMOVED` (files earlier releases shipped; the base is one of them) and zips the result. The workflows download the base from Dylan's release, pinned by SHA-256.

`.github/workflows/test.yml` runs on every push. On a GitHub arm64 runner, it installs the zip the way Zdroid does into [Termux's Docker image](https://github.com/termux/termux-docker), which runs Termux's binaries with Android's linker. It then runs three orders of package operations: the one from [zdroid-bootstrap#1](https://github.com/Dylanmurzello/zdroid-bootstrap/issues/1), the one from Zdroid's README with a full `pkg upgrade`, and an `npm install -g` of Codex and Claude Code. Each must leave apt able to update and to install a package that runs, the CLIs runnable, and no installed binary or dpkg record naming `com.termux`. The results appear as annotations on the run.
