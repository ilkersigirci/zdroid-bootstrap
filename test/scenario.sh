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

mkdir -p "$APP/logs"
step=0
run() {
    step=$((step + 1))
    echo "::group::$*"
    # A step that waits on something Android has and the container lacks
    # would otherwise hang the job until GitHub's six-hour limit.
    timeout --kill-after=30 1200 "$@" < /dev/null 2>&1 | tee "$APP/logs/$step"
    local status=${PIPESTATUS[0]}
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
        # The README's order: upgrade first, fix-broken when apt asks, then
        # the upgrade again.
        run pkg update
        run pkg upgrade
        run apt --fix-broken install
        run pkg upgrade
        ;;
esac
# apt can still fetch, and what it installs runs.
run apt update
run apt install jq
run jq --version
