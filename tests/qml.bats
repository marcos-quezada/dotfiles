#!/usr/bin/env bats
# qml.bats — Qt Quick Test gate for QML pure-logic files
# run: bats tests/qml.bats
#
# tests run headlessly via qmltestrunner with -platform offscreen.
# only Utils.qml (no Quickshell imports) is tested — Quickshell types
# that require a live Wayland compositor cannot be exercised this way.
#
# qmltestrunner location varies by platform:
#   FreeBSD:  /usr/local/lib/qt6/bin/qmltestrunner  (qt6-declarative)
#   macOS:    $(brew --prefix qt)/bin/qmltestrunner  (qt formula)
# override via: QML_TEST_RUNNER=/path/to/qmltestrunner bats tests/qml.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
QS_DIR="$REPO_ROOT/quickshell/.config/quickshell"

# resolve qmltestrunner — check override, PATH, then known platform paths.
# returns empty string (not an error) when not found; callers skip on empty.
_find_runner() {
    if [ -n "${QML_TEST_RUNNER:-}" ]; then
        printf '%s' "$QML_TEST_RUNNER"
        return
    fi
    if command -v qmltestrunner >/dev/null 2>&1; then
        printf '%s' "qmltestrunner"
        return
    fi
    # FreeBSD qt6-declarative installs here
    if [ -x "/usr/local/lib/qt6/bin/qmltestrunner" ]; then
        printf '%s' "/usr/local/lib/qt6/bin/qmltestrunner"
        return
    fi
    # not found — return empty string so tests can skip gracefully
    printf ''
}

setup() {
    export QT_QPA_PLATFORM=offscreen
    # suppress Qt startup noise that doesn't affect exit code
    export QT_LOGGING_RULES="qt.qpa.*=false"
    QML_RUNNER="$(_find_runner)"
}

@test "qmltestrunner is available" {
    if [ -z "${QML_RUNNER:-}" ]; then
        skip "qmltestrunner not found (install qt6-declarative or set QML_TEST_RUNNER)"
    fi
    command -v "$QML_RUNNER" >/dev/null 2>&1 || [ -x "$QML_RUNNER" ]
}

@test "Utils.qml: all pure-logic tests pass" {
    if [ -z "${QML_RUNNER:-}" ]; then
        skip "qmltestrunner not found (install qt6-declarative or set QML_TEST_RUNNER)"
    fi
    run "$QML_RUNNER" \
        -import "$QS_DIR/threatwatch" \
        -input  "$REPO_ROOT/tests/tst_threatwatch.qml"
    [ "$status" -eq 0 ]
}
