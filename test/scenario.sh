# Runs in termux-docker as the app's user, with the environment Zdroid's
# Bootstrap runtime gives its terminal (zdroid_runtime's bootstrap adapter).
APP=/data/data/com.zdroid
export PREFIX="$APP/files/usr"
export HOME="$APP/files/home"
export TERMUX__ROOTFS="$APP/files"
export TERMUX__PREFIX="$PREFIX"
export TERMUX__HOME="$HOME"
export TERMUX_APP__PACKAGE_NAME=com.zdroid
export TMPDIR="$PREFIX/tmp"
export PATH="$PREFIX/.zed/bin:$PREFIX/bin:/system/bin"
export LD_PRELOAD="$PREFIX/lib/libtermux-exec.so"
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
export CURL_CA_BUNDLE="$SSL_CERT_FILE"
export LANG=en_US.UTF-8
export TERM=xterm-256color
cd "$HOME" || exit 1

# Answers apt's and dpkg's questions with their defaults, as pressing Enter
# would.
cat > "$PREFIX/etc/apt/apt.conf.d/00-test-noninteractive" <<'EOF'
APT::Get::Assume-Yes "true";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

run() {
    echo "::group::$*"
    "$@" < /dev/null
    local status=$?
    echo "::endgroup::"
    echo "$* -> exit $status" >> "$APP/results"
}

case "$1" in
    issue-1)
        # zdroid-bootstrap#1: fix-broken first, then the README's upgrade.
        run apt --fix-broken install
        run pkg update
        run pkg upgrade
        ;;
    readme)
        # The README's order: upgrade first, fix-broken when apt asks.
        run pkg update
        run pkg upgrade
        run apt --fix-broken install
        ;;
esac
run apt update
