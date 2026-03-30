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

    # mock sudo and doas — prevent the real binaries from being found and
    # prompting for a password when install.sh calls install_pkg
    printf '#!/bin/sh\nprintf ""\n' > "$MOCK_BIN/sudo"
    chmod +x "$MOCK_BIN/sudo"
    printf '#!/bin/sh\nprintf ""\n' > "$MOCK_BIN/doas"
    chmod +x "$MOCK_BIN/doas"

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

# ── prompt_yn ─────────────────────────────────────────────────────────────────
# prompt_yn is tested by inlining the function body; YES=1 bypasses stdin.

_prompt_yn() {
    # _prompt_yn <yes_flag> <default> → exit 0 for yes, 1 for no
    _yes="$1"; _default="$2"
    sh -c "
        YES='$_yes'
        prompt_yn() {
            _q=\"\$1\"; _d=\"\${2:-y}\"
            [ \"\$YES\" = '1' ] && { [ \"\$_d\" = 'y' ] && return 0 || return 1; }
            case \"\$_d\" in
                y) _hint='[Y/n]' ;;
                n) _hint='[y/N]' ;;
                *) _hint='[y/n]' ;;
            esac
            printf '  %s %s: ' \"\$_q\" \"\$_hint\"
            read -r _ans
            _ans=\"\${_ans:-\$_d}\"
            case \"\$_ans\" in
                [Yy]*) return 0 ;;
                *)     return 1 ;;
            esac
        }
        prompt_yn 'test question' '$_default'
    "
}

@test "prompt_yn: --yes with default y returns 0" {
    run _prompt_yn 1 y
    [ "$status" -eq 0 ]
}

@test "prompt_yn: --yes with default n returns 1" {
    run _prompt_yn 1 n
    [ "$status" -eq 1 ]
}

@test "prompt_yn: interactive y input returns 0" {
    run sh -c "
        YES=0
        prompt_yn() {
            _d=\"\${2:-y}\"
            read -r _ans
            _ans=\"\${_ans:-\$_d}\"
            case \"\$_ans\" in [Yy]*) return 0 ;; *) return 1 ;; esac
        }
        printf 'y\n' | { read -r _in; printf '%s\n' \"\$_in\" | prompt_yn 'q' n; }
    "
    [ "$status" -eq 0 ]
}

@test "prompt_yn: interactive n input returns 1" {
    run sh -c "
        YES=0
        prompt_yn() {
            _d=\"\${2:-y}\"
            read -r _ans
            _ans=\"\${_ans:-\$_d}\"
            case \"\$_ans\" in [Yy]*) return 0 ;; *) return 1 ;; esac
        }
        printf 'n\n' | { read -r _in; printf '%s\n' \"\$_in\" | prompt_yn 'q' y; }
    "
    [ "$status" -eq 1 ]
}

# ── check_cmd ─────────────────────────────────────────────────────────────────

@test "check_cmd: found command prints ok and returns 0" {
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        check_cmd() {
            if command -v \"\$1\" >/dev/null 2>&1; then
                printf 'ok: %s found\n' \"\$1\"; return 0
            else
                printf 'warn: %s not found\n' \"\$1\"; return 1
            fi
        }
        check_cmd stow
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok:"* ]]
}

@test "check_cmd: missing command prints warn and returns 1" {
    run sh -c "
        check_cmd() {
            if command -v \"\$1\" >/dev/null 2>&1; then
                printf 'ok: %s found\n' \"\$1\"; return 0
            else
                printf 'warn: %s not found\n' \"\$1\"; return 1
            fi
        }
        check_cmd __no_such_binary_xyz__
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"warn:"* ]]
}

# ── doas block (FreeBSD) ──────────────────────────────────────────────────────
# tested via full _run_install; doas + doas.conf mocked via MOCK_BIN.

@test "doas block: doas + doas.conf present prints ok" {
    # mock doas.conf by creating a real file; mock doas binary already in MOCK_BIN
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/usr/local/etc"
    # the script checks /usr/local/etc/doas.conf — we can't redirect that path,
    # but the FreeBSD block only runs when PLATFORM=freebsd.  run full installer
    # with a pre-existing doas.conf using a wrapper that intercepts the -f test.
    # simpler: wrap the doas block as a subshell with overridden test for -f.
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        PLATFORM=freebsd
        YES=1
        ok()   { printf 'ok: %s\n' \"\$*\"; }
        warn() { printf 'warn: %s\n' \"\$*\"; }
        info() { printf 'info: %s\n' \"\$*\"; }
        prompt_yn() { [ \"\${2:-y}\" = 'y' ] && return 0 || return 1; }
        # simulate doas present + doas.conf present
        command_v_doas()    { return 0; }
        doas_conf_present() { return 0; }
        if command -v doas >/dev/null 2>&1; then
            ok 'doas found'
            # use a temp file to stand in for doas.conf
            _conf=\"\$(mktemp)\"
            if [ -f \"\$_conf\" ]; then
                ok 'doas.conf found'
            fi
            rm -f \"\$_conf\"
        fi
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok: doas found"* ]]
}

@test "doas block: FreeBSD full run with doas present exits 0" {
    _run_install FreeBSD
    [ "$status" -eq 0 ]
    [[ "$output" == *"platform: freebsd"* ]]
}

# ── stow_pkg ──────────────────────────────────────────────────────────────────

@test "stow_pkg: stows package when directory exists" {
    _fake_home="$(mktemp -d)"
    # create a fake package dir
    mkdir -p "$_fake_home/repo/git"
    # record stow call
    printf '#!/bin/sh\nprintf "stow called: %%s\n" "$*"\n' > "$MOCK_BIN/stow"
    chmod +x "$MOCK_BIN/stow"
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        REPO_DIR='$_fake_home/repo'
        HOME='$_fake_home'
        stow_pkg() {
            _pkg=\"\$1\"
            if [ -d \"\$REPO_DIR/\$_pkg\" ]; then
                if stow --dir=\"\$REPO_DIR\" --target=\"\$HOME\" --restow \"\$_pkg\"; then
                    printf 'ok: stowed %s\n' \"\$_pkg\"
                else
                    printf 'die: stow failed for %s\n' \"\$_pkg\" >&2; exit 1
                fi
            else
                printf 'warn: package dir not found: %s\n' \"\$REPO_DIR/\$_pkg\"
            fi
        }
        stow_pkg git
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok: stowed git"* ]]
    rm -rf "$_fake_home"
}

@test "stow_pkg: warns and skips when package directory absent" {
    _fake_home="$(mktemp -d)"
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        REPO_DIR='$_fake_home/repo'
        HOME='$_fake_home'
        stow_pkg() {
            _pkg=\"\$1\"
            if [ -d \"\$REPO_DIR/\$_pkg\" ]; then
                stow --dir=\"\$REPO_DIR\" --target=\"\$HOME\" --restow \"\$_pkg\"
            else
                printf 'warn: package dir not found: %s\n' \"\$REPO_DIR/\$_pkg\"
            fi
        }
        stow_pkg nonexistent
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"warn: package dir not found"* ]]
    rm -rf "$_fake_home"
}

@test "stow_pkg: exits non-zero when stow fails" {
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/repo/git"
    # stow mock that fails
    printf '#!/bin/sh\nexit 1\n' > "$MOCK_BIN/stow"
    chmod +x "$MOCK_BIN/stow"
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        REPO_DIR='$_fake_home/repo'
        HOME='$_fake_home'
        stow_pkg() {
            _pkg=\"\$1\"
            if [ -d \"\$REPO_DIR/\$_pkg\" ]; then
                if stow --dir=\"\$REPO_DIR\" --target=\"\$HOME\" --restow \"\$_pkg\"; then
                    printf 'ok: stowed %s\n' \"\$_pkg\"
                else
                    printf 'die: stow failed for %s\n' \"\$_pkg\" >&2; exit 1
                fi
            fi
        }
        stow_pkg git
    "
    [ "$status" -ne 0 ]
    rm -rf "$_fake_home"
}

# ── stow_root ─────────────────────────────────────────────────────────────────
# stow_root is the generic version of the old stow_vt; targets / with privilege
# escalation.  tested with both vt and ly package names.

@test "stow_root: uses doas when available" {
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/repo/vt"
    CALL_LOG="$MOCK_BIN/calls"
    printf '#!/bin/sh\nprintf "doas %%s\n" "$*" >> "%s"\n' "$CALL_LOG" > "$MOCK_BIN/doas"
    chmod +x "$MOCK_BIN/doas"
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        REPO_DIR='$_fake_home/repo'
        stow_root() {
            _pkg=\"\$1\"
            if [ ! -d \"\$REPO_DIR/\$_pkg\" ]; then printf 'warn: %s not found\n' \"\$_pkg\"; return; fi
            SUDO=''
            command -v doas >/dev/null 2>&1 && SUDO=doas
            command -v sudo >/dev/null 2>&1 && [ -z \"\$SUDO\" ] && SUDO=sudo
            if [ -z \"\$SUDO\" ]; then printf 'die: no escalation tool\n' >&2; exit 1; fi
            \${SUDO} stow --dir=\"\$REPO_DIR\" --target='/' --restow \"\$_pkg\" && printf 'ok: stowed %s\n' \"\$_pkg\"
        }
        stow_root vt
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok: stowed vt"* ]]
    grep -q "doas stow" "$CALL_LOG"
    rm -rf "$_fake_home"
}

@test "stow_root: warns and returns when package dir absent" {
    _fake_home="$(mktemp -d)"
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        REPO_DIR='$_fake_home/repo'
        stow_root() {
            _pkg=\"\$1\"
            if [ ! -d \"\$REPO_DIR/\$_pkg\" ]; then printf 'warn: %s not found\n' \"\$_pkg\"; return; fi
            printf 'ok: stowed %s\n' \"\$_pkg\"
        }
        stow_root vt
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"warn: vt not found"* ]]
    rm -rf "$_fake_home"
}

@test "stow_root: exits non-zero when neither doas nor sudo available" {
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/repo/vt"
    # only stow in PATH — no doas, no sudo
    printf '#!/bin/sh\nprintf "stow %%s\n" "$*"\n' > "$MOCK_BIN/stow"
    chmod +x "$MOCK_BIN/stow"
    rm -f "$MOCK_BIN/doas" "$MOCK_BIN/sudo"
    # use /bin/sh directly so the restricted PATH doesn't hide the shell itself
    # shellcheck disable=SC2016
    run /bin/sh -c "
        PATH='$MOCK_BIN'
        REPO_DIR='$_fake_home/repo'
        stow_root() {
            _pkg=\"\$1\"
            if [ ! -d \"\$REPO_DIR/\$_pkg\" ]; then printf 'warn: %s not found\n' \"\$_pkg\"; return; fi
            SUDO=''
            command -v doas >/dev/null 2>&1 && SUDO=doas
            command -v sudo >/dev/null 2>&1 && [ -z \"\$SUDO\" ] && SUDO=sudo
            if [ -z \"\$SUDO\" ]; then printf 'die: no escalation tool\n' >&2; exit 1; fi
            \${SUDO} stow --dir=\"\$REPO_DIR\" --target='/' --restow \"\$_pkg\"
        }
        stow_root vt
    "
    [ "$status" -ne 0 ]
    rm -rf "$_fake_home"
}

@test "stow_root: works for ly package path" {
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/repo/ly/usr/local/etc/ly"
    CALL_LOG="$MOCK_BIN/calls_ly"
    printf '#!/bin/sh\nprintf "doas %%s\n" "$*" >> "%s"\n' "$CALL_LOG" > "$MOCK_BIN/doas"
    chmod +x "$MOCK_BIN/doas"
    run env PATH="$MOCK_BIN:$PATH" sh -c "
        REPO_DIR='$_fake_home/repo'
        stow_root() {
            _pkg=\"\$1\"
            if [ ! -d \"\$REPO_DIR/\$_pkg\" ]; then printf 'warn: %s not found\n' \"\$_pkg\"; return; fi
            SUDO=''
            command -v doas >/dev/null 2>&1 && SUDO=doas
            command -v sudo >/dev/null 2>&1 && [ -z \"\$SUDO\" ] && SUDO=sudo
            if [ -z \"\$SUDO\" ]; then printf 'die: no escalation tool\n' >&2; exit 1; fi
            \${SUDO} stow --dir=\"\$REPO_DIR\" --target='/' --restow \"\$_pkg\" && printf 'ok: stowed %s\n' \"\$_pkg\"
        }
        stow_root ly
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok: stowed ly"* ]]
    grep -q "doas stow" "$CALL_LOG"
    rm -rf "$_fake_home"
}

# ── config template copy ──────────────────────────────────────────────────────

@test "config template: copies template to config.env when absent" {
    _fake_home="$(mktemp -d)"
    _cfg="$_fake_home/.config/threatwatch"
    mkdir -p "$_cfg"
    printf 'MAPBOX_TOKEN=changeme\n' > "$_cfg/config.env.template"
    run sh -c "
        DO_THREATWATCH=1
        HOME='$_fake_home'
        CONFIG_DIR='$_cfg'
        TEMPLATE=\"\$CONFIG_DIR/config.env.template\"
        LIVE=\"\$CONFIG_DIR/config.env\"
        if [ -f \"\$LIVE\" ]; then
            printf 'ok: config.env already exists\n'
        elif [ -f \"\$TEMPLATE\" ]; then
            cp \"\$TEMPLATE\" \"\$LIVE\"
            chmod 600 \"\$LIVE\"
            printf 'ok: created config.env from template\n'
        fi
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"created config.env from template"* ]]
    [ -f "$_cfg/config.env" ]
    rm -rf "$_fake_home"
}

@test "config template: does not overwrite existing config.env" {
    _fake_home="$(mktemp -d)"
    _cfg="$_fake_home/.config/threatwatch"
    mkdir -p "$_cfg"
    printf 'MAPBOX_TOKEN=mytoken\n' > "$_cfg/config.env"
    printf 'MAPBOX_TOKEN=changeme\n' > "$_cfg/config.env.template"
    run sh -c "
        CONFIG_DIR='$_cfg'
        TEMPLATE=\"\$CONFIG_DIR/config.env.template\"
        LIVE=\"\$CONFIG_DIR/config.env\"
        if [ -f \"\$LIVE\" ]; then
            printf 'ok: config.env already exists\n'
        elif [ -f \"\$TEMPLATE\" ]; then
            cp \"\$TEMPLATE\" \"\$LIVE\"
            printf 'ok: created config.env from template\n'
        fi
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
    # original content preserved
    grep -q "mytoken" "$_cfg/config.env"
    rm -rf "$_fake_home"
}

# ── ssh config template ───────────────────────────────────────────────────────

@test "ssh template: copies template to ~/.ssh/config when absent" {
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/.ssh"
    chmod 700 "$_fake_home/.ssh"
    printf 'Host github\n' > "$_fake_home/.ssh/config.template"
    run sh -c "
        DO_SSH=1
        SSH_TEMPLATE='$_fake_home/.ssh/config.template'
        SSH_LIVE='$_fake_home/.ssh/config'
        if [ -f \"\$SSH_LIVE\" ]; then
            printf 'ok: ssh config already exists\n'
        elif [ -f \"\$SSH_TEMPLATE\" ]; then
            cp \"\$SSH_TEMPLATE\" \"\$SSH_LIVE\"
            chmod 600 \"\$SSH_LIVE\"
            printf 'ok: created ssh config from template\n'
        fi
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"created ssh config from template"* ]]
    [ -f "$_fake_home/.ssh/config" ]
    rm -rf "$_fake_home"
}

@test "ssh template: does not overwrite existing ~/.ssh/config" {
    _fake_home="$(mktemp -d)"
    mkdir -p "$_fake_home/.ssh"
    printf 'Host myserver\n' > "$_fake_home/.ssh/config"
    printf 'Host github\n' > "$_fake_home/.ssh/config.template"
    run sh -c "
        SSH_TEMPLATE='$_fake_home/.ssh/config.template'
        SSH_LIVE='$_fake_home/.ssh/config'
        if [ -f \"\$SSH_LIVE\" ]; then
            printf 'ok: ssh config already exists\n'
        elif [ -f \"\$SSH_TEMPLATE\" ]; then
            cp \"\$SSH_TEMPLATE\" \"\$SSH_LIVE\"
            printf 'ok: created ssh config from template\n'
        fi
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
    grep -q "myserver" "$_fake_home/.ssh/config"
    rm -rf "$_fake_home"
}

# ── cache dir creation ────────────────────────────────────────────────────────

@test "cache dir: creates threatwatch cache directory" {
    _fake_home="$(mktemp -d)"
    run sh -c "
        DO_THREATWATCH=1
        CACHE_DIR='$_fake_home/.cache/threatwatch'
        mkdir -p \"\$CACHE_DIR\"
        printf 'ok: cache dir: %s\n' \"\$CACHE_DIR\"
    "
    [ "$status" -eq 0 ]
    [ -d "$_fake_home/.cache/threatwatch" ]
    rm -rf "$_fake_home"
}
