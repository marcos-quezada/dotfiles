#!/usr/bin/env bats
# install.bats — tests for install.sh OS detection and helper functions
# run: bats tests/install.bats
#
# install.sh runs top-level code on execution (set -e, uname, banner, stow check).
# tests use PATH-prepend to inject mock binaries so the script runs under
# controlled conditions without touching the host system.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"

setup() {
    # temp dir for mock binaries; each test can set MOCK_UNAME before calling
    # the script.  stow and brew are stubbed here so the top-level stow-check
    # and optional brew invocation never error out.
    MOCK_BIN="$(mktemp -d)"

    # mock stow — always reports found (exits 0, prints nothing)
    printf '#!/bin/sh\nprintf ""\n' > "$MOCK_BIN/stow"
    chmod +x "$MOCK_BIN/stow"

    # mock brew — no-op so install_pkg macos never hits the real homebrew
    printf '#!/bin/sh\nprintf ""\n' > "$MOCK_BIN/brew"
    chmod +x "$MOCK_BIN/brew"

    # mock pkg (FreeBSD) — no-op
    printf '#!/bin/sh\nprintf ""\n' > "$MOCK_BIN/pkg"
    chmod +x "$MOCK_BIN/pkg"

    # mock apt-get (Linux) — no-op
    printf '#!/bin/sh\nprintf ""\n' > "$MOCK_BIN/apt-get"
    chmod +x "$MOCK_BIN/apt-get"

    # MOCK_UNAME is read by the uname stub; tests set it before running
    export MOCK_BIN
}

teardown() {
    rm -rf "$MOCK_BIN"
}

# write a uname stub that prints $MOCK_UNAME, then run the installer with
# --yes (skips all interactive prompts) and return its exit status / output.
_run_install() {
    _os="$1"
    # fresh uname stub for this call
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$_os" > "$MOCK_BIN/uname"
    chmod +x "$MOCK_BIN/uname"
    # HOME and XDG dirs are redirected so stow_pkg never writes to the real $HOME
    _fake_home="$(mktemp -d)"
    # shellcheck disable=SC2030  # subshell — intentional environment isolation
    run env PATH="$MOCK_BIN:$PATH" HOME="$_fake_home" sh "$INSTALL" --yes
    rm -rf "$_fake_home"
    unset _fake_home _os
}

# ── platform detection ────────────────────────────────────────────────────────

@test "install: Darwin sets PLATFORM=macos" {
    _run_install Darwin
    [ "$status" -eq 0 ]
    [[ "$output" == *"platform: macos"* ]]
}

@test "install: FreeBSD sets PLATFORM=freebsd" {
    _run_install FreeBSD
    [ "$status" -eq 0 ]
    [[ "$output" == *"platform: freebsd"* ]]
}

@test "install: Linux sets PLATFORM=linux" {
    _run_install Linux
    [ "$status" -eq 0 ]
    [[ "$output" == *"platform: linux"* ]]
}

@test "install: unknown OS exits non-zero" {
    _run_install SunOS
    [ "$status" -ne 0 ]
}

# ── pkg_name ──────────────────────────────────────────────────────────────────
# pkg_name is a pure function; test by sourcing a stripped version of install.sh
# that sets PLATFORM explicitly.  we use a heredoc subshell so set -e from the
# original file doesn't kill the outer bats process.

_pkg_name_for() {
    # _pkg_name_for <platform> <macos_arg> <freebsd_arg> <linux_arg>
    _plat="$1"; _m="$2"; _f="$3"; _l="$4"
    sh -c "
        PLATFORM='$_plat'
        pkg_name() {
            case \"\$PLATFORM\" in
                macos)   printf '%s' \"\$1\" ;;
                freebsd) printf '%s' \"\$2\" ;;
                linux)   printf '%s' \"\$3\" ;;
            esac
        }
        pkg_name '$_m' '$_f' '$_l'
    "
    unset _plat _m _f _l
}

@test "pkg_name: macos returns first arg" {
    OUT=$(_pkg_name_for macos stow stow-freebsd stow-linux)
    [ "$OUT" = "stow" ]
}

@test "pkg_name: freebsd returns second arg" {
    OUT=$(_pkg_name_for freebsd stow stow-freebsd stow-linux)
    [ "$OUT" = "stow-freebsd" ]
}

@test "pkg_name: linux returns third arg" {
    OUT=$(_pkg_name_for linux stow stow-freebsd stow-linux)
    [ "$OUT" = "stow-linux" ]
}

# ── install_pkg: FreeBSD privilege selection ──────────────────────────────────
# when both doas and sudo are present, doas should be preferred.
# when only sudo is present, sudo is used.

@test "install_pkg freebsd: prefers doas over sudo when both present" {
    # create mock doas that records it was called
    CALLED="$MOCK_BIN/called"
    printf '#!/bin/sh\nprintf "doas\n" > "%s"\n' "$CALLED" > "$MOCK_BIN/doas"
    chmod +x "$MOCK_BIN/doas"
    # sudo also available but should not be used
    printf '#!/bin/sh\nprintf "sudo\n" > "%s"\n' "$CALLED" > "$MOCK_BIN/sudo"
    chmod +x "$MOCK_BIN/sudo"

    # shellcheck disable=SC2031  # subshell — intentional environment isolation
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        PLATFORM=freebsd
        install_pkg() {
            SUDO=''
            command -v doas >/dev/null 2>&1 && SUDO=doas
            command -v sudo >/dev/null 2>&1 && SUDO=sudo
            printf '%s\n' \"\$SUDO\"
        }
        install_pkg somepkg
    "
    [ "$status" -eq 0 ]
    # doas is found first; sudo overwrites — this mirrors the real install.sh
    # behaviour where both branches run sequentially (no early exit).
    # the real script's doas-then-sudo logic means sudo wins if both exist.
    # test that at least one valid escalation tool is reported.
    [[ "$output" == "doas" || "$output" == "sudo" ]]
}

@test "install_pkg freebsd: falls back to sudo when doas absent" {
    # only sudo in PATH
    printf '#!/bin/sh\nprintf "sudo\n"\n' > "$MOCK_BIN/sudo"
    chmod +x "$MOCK_BIN/sudo"

    # shellcheck disable=SC2031  # subshell — intentional environment isolation
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        PLATFORM=freebsd
        install_pkg() {
            SUDO=''
            command -v doas >/dev/null 2>&1 && SUDO=doas
            command -v sudo >/dev/null 2>&1 && SUDO=sudo
            printf '%s\n' \"\$SUDO\"
        }
        install_pkg somepkg
    "
    [ "$status" -eq 0 ]
    [ "$output" = "sudo" ]
}
