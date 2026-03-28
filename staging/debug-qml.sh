#!/bin/sh
# debug-qml.sh — gather qmltestrunner diagnostics
# run from the FreeBSD machine, then push staging/debug-qml-output.txt

REPO="$HOME/git/dotfiles"
QS_DIR="$REPO/quickshell/.config/quickshell"
RUNNER="/usr/local/lib/qt6/bin/qmltestrunner"
OUT="$REPO/staging/debug-qml-output.txt"

{
    echo "=== 1. import path used by qml.bats ==="
    grep -A5 "run.*QML_RUNNER" "$REPO/tests/qml.bats"

    echo ""
    echo "=== 2a. repo quickshell dir ==="
    ls -la "$QS_DIR/"

    echo ""
    echo "=== 2b. stow target quickshell dir ==="
    ls -la "$HOME/.config/quickshell/"

    echo ""
    echo "=== 2c. ThreatWatchUtils/ via repo path ==="
    ls -la "$QS_DIR/ThreatWatchUtils/"

    echo ""
    echo "=== 2d. ThreatWatchUtils/ via stow target ==="
    ls -la "$HOME/.config/quickshell/ThreatWatchUtils/"

    echo ""
    echo "=== 3. qmldir content ==="
    cat "$QS_DIR/ThreatWatchUtils/qmldir"

    echo ""
    echo "=== 4a. qmltestrunner with repo path as -import ==="
    QT_QPA_PLATFORM=offscreen "$RUNNER" \
        -import "$QS_DIR" \
        -input  "$REPO/tests/tst_threatwatch.qml" 2>&1
    echo "exit: $?"

    echo ""
    echo "=== 4b. qmltestrunner with stow target path as -import ==="
    QT_QPA_PLATFORM=offscreen "$RUNNER" \
        -import "$HOME/.config/quickshell" \
        -input  "$REPO/tests/tst_threatwatch.qml" 2>&1
    echo "exit: $?"

} > "$OUT" 2>&1

echo "output written to $OUT"
echo "now run: cd ~/dotfiles && git add staging/debug-qml-output.txt && git commit -m 'staging: qml debug output' && git push"
