# Sets PREFIX, PATH, HOME and the rest for a login shell whose parent
# didn't (an SSH session into Zdroid, adb run-as); Zdroid's own terminal
# gets them from the app.
if [ -z "$PREFIX" ]; then
    export PREFIX="/data/data/com.zdroid/files/usr"
fi
if [ -z "$TERMUX__PREFIX" ]; then
    export TERMUX__PREFIX="$PREFIX"
fi
if [ -z "$TERMUX__ROOTFS" ]; then
    export TERMUX__ROOTFS="/data/data/com.zdroid/files"
fi
# Override HOME if it's empty, or any Android-flavored app data
# dir form, but leave a custom-set HOME alone.
case "$HOME" in
    "$TERMUX__ROOTFS/home"|"$TERMUX__ROOTFS/home/"*) ;;  # already correct
    ""|/data/user/0/*|/data/data/*) export HOME="$TERMUX__ROOTFS/home" ;;
esac
if [ -z "$TMPDIR" ]; then
    export TMPDIR="$PREFIX/tmp"
fi
if [ -z "$LANG" ]; then
    export LANG="en_US.UTF-8"
fi
case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) export PATH="$PREFIX/bin:$PATH" ;;
esac
# Zed's apt-untouchable bin dir. Holds shims (npm wrapper, etc.)
# that need to survive `pkg install --reinstall` of upstream
# packages owning the same name in $PREFIX/bin. Prepended so it
# wins via PATH precedence.
case ":$PATH:" in
    *":$PREFIX/.zed/bin:"*) ;;
    *) export PATH="$PREFIX/.zed/bin:$PATH" ;;
esac
