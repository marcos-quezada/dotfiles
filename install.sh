#!/bin/sh
# install.sh — bootstrap dotfiles on macOS, FreeBSD, or Linux
# usage: sh install.sh [--yes]
#   --yes  accept all defaults non-interactively

set -e

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; RST='\033[0m'
ok()   { printf "${GRN}  ✔${RST} %s\n" "$*"; }
info() { printf "${BLU}  ·${RST} %s\n" "$*"; }
warn() { printf "${YLW}  ⚠${RST} %s\n" "$*"; }
die()  { printf "${RED}  ✘${RST} %s\n" "$*" >&2; exit 1; }

# ── detect OS ─────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Darwin)  PLATFORM=macos   ;;
    FreeBSD) PLATFORM=freebsd ;;
    Linux)   PLATFORM=linux   ;;
    *)       die "unsupported platform: $OS" ;;
esac

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
YES=0
[ "${1:-}" = "--yes" ] && YES=1

# ── helpers ───────────────────────────────────────────────────────────────────

prompt_yn() {
    # prompt_yn "question" default_y_or_n
    # returns 0 for yes, 1 for no
    _q="$1"; _d="${2:-y}"
    [ "$YES" = "1" ] && { [ "$_d" = "y" ] && return 0 || return 1; }
    case "$_d" in
        y) _hint="[Y/n]" ;;
        n) _hint="[y/N]" ;;
        *) _hint="[y/n]" ;;
    esac
    printf "  %s %s: " "$_q" "$_hint"
    read -r _ans
    _ans="${_ans:-$_d}"
    case "$_ans" in
        [Yy]*) return 0 ;;
        *)     return 1 ;;
    esac
}

check_cmd() {
    # check_cmd cmd "install hint"
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1 found"
        return 0
    else
        warn "$1 not found — $2"
        return 1
    fi
}

install_pkg() {
    # install_pkg pkg [pkg ...]  — installs via the platform package manager
    case "$PLATFORM" in
        macos)
            command -v brew >/dev/null 2>&1 || die "homebrew not found — install from https://brew.sh"
            brew install "$@"
            ;;
        freebsd)
            SUDO=""
            command -v doas >/dev/null 2>&1 && SUDO=doas
            command -v sudo >/dev/null 2>&1 && SUDO=sudo
            ${SUDO} pkg install -y "$@"
            ;;
        linux)
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get install -y "$@"
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm "$@"
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y "$@"
            else
                die "no supported package manager found (tried apt, pacman, dnf)"
            fi
            ;;
    esac
}

pkg_name() {
    # pkg_name macos_name freebsd_name linux_name
    case "$PLATFORM" in
        macos)   printf '%s' "$1" ;;
        freebsd) printf '%s' "$2" ;;
        linux)   printf '%s' "$3" ;;
    esac
}

# ── banner ────────────────────────────────────────────────────────────────────
printf '\n'
printf '  dotfiles installer\n'
printf '  platform: %s\n' "$PLATFORM"
printf '  repo:     %s\n' "$REPO_DIR"
printf '\n'

# ── stow check ────────────────────────────────────────────────────────────────
if ! command -v stow >/dev/null 2>&1; then
    warn "stow not found"
    if prompt_yn "install stow now?" y; then
        install_pkg "$(pkg_name stow stow stow)"
    else
        die "stow is required — install it and re-run"
    fi
else
    ok "stow found"
fi

# ── doas (FreeBSD) ────────────────────────────────────────────────────────────
# doas is the privilege escalation tool used on FreeBSD. install.sh itself uses
# it for stow_vt and any pkg installs. check early so the rest of the script
# can rely on it being present.
if [ "$PLATFORM" = "freebsd" ]; then
    printf '\n  checking doas...\n\n'
    if command -v doas >/dev/null 2>&1; then
        ok "doas found"
        # confirm /usr/local/etc/doas.conf exists — without it doas blocks everything
        if [ -f /usr/local/etc/doas.conf ]; then
            ok "doas.conf found"
        else
            warn "doas is installed but /usr/local/etc/doas.conf does not exist"
            info "minimal config to allow wheel group: permit persist :wheel"
            if prompt_yn "write a minimal doas.conf now? (requires sudo)" n; then
                printf 'permit persist :wheel\n' | sudo tee /usr/local/etc/doas.conf >/dev/null
                chmod 640 /usr/local/etc/doas.conf
                ok "wrote /usr/local/etc/doas.conf"
            else
                warn "doas will not work until doas.conf is created — run as root:"
                info "  printf 'permit persist :wheel\\n' > /usr/local/etc/doas.conf"
                info "  chmod 640 /usr/local/etc/doas.conf"
            fi
        fi
    else
        warn "doas not found"
        if prompt_yn "install doas via pkg? (requires sudo)" y; then
            sudo pkg install -y doas
            ok "doas installed"
            if [ ! -f /usr/local/etc/doas.conf ]; then
                printf 'permit persist :wheel\n' | sudo tee /usr/local/etc/doas.conf >/dev/null
                chmod 640 /usr/local/etc/doas.conf
                ok "wrote /usr/local/etc/doas.conf"
            fi
        else
            warn "doas is required for vt font install and pkg operations — install it manually"
        fi
    fi
fi

# ── core deps ─────────────────────────────────────────────────────────────────
printf '\n  checking core dependencies...\n\n'
MISSING_CORE=""

check_cmd curl "$(pkg_name curl curl curl)" || MISSING_CORE="$MISSING_CORE curl"
check_cmd jq   "$(pkg_name jq jq jq)"       || MISSING_CORE="$MISSING_CORE jq"
check_cmd awk  "built into base system"

# bat is required on FreeBSD (powers the clue alias); optional elsewhere
if [ "$PLATFORM" = "freebsd" ]; then
    check_cmd bat "bat" || MISSING_CORE="$MISSING_CORE bat"
fi

# w3m is required on FreeBSD (powers the handbook alias)
if [ "$PLATFORM" = "freebsd" ]; then
    check_cmd w3m "w3m" || MISSING_CORE="$MISSING_CORE w3m"
fi

if [ -n "$MISSING_CORE" ]; then
    printf '\n'
    warn "missing required tools:$MISSING_CORE"
    if prompt_yn "install them now?" y; then
        # shellcheck disable=SC2086
        install_pkg $MISSING_CORE
    else
        warn "some features will not work correctly without the above tools"
    fi
fi

# ── font deps (FreeBSD) ───────────────────────────────────────────────────────
# foot.ini uses Spleen 8x16 and Symbols Nerd Font Mono; check via fc-list.
if [ "$PLATFORM" = "freebsd" ]; then
    printf '\n  checking fonts...\n\n'
    MISSING_FONTS=""

    if command -v fc-list >/dev/null 2>&1; then
        if fc-list | grep -qi "spleen"; then
            ok "Spleen found"
        else
            warn "Spleen not found — required by foot.ini"
            MISSING_FONTS="$MISSING_FONTS spleen"
        fi

        if fc-list | grep -qi "symbols nerd font"; then
            ok "Symbols Nerd Font Mono found"
        else
            warn "Symbols Nerd Font Mono not found — required by foot.ini"
            # nerd-fonts is the FreeBSD port; covers all Nerd Font families
            MISSING_FONTS="$MISSING_FONTS nerd-fonts"
        fi
    else
        warn "fc-list not available — skipping font check (install fontconfig)"
    fi

    if [ -n "$MISSING_FONTS" ]; then
        printf '\n'
        if prompt_yn "install missing fonts now?" y; then
            # shellcheck disable=SC2086
            install_pkg $MISSING_FONTS
        else
            warn "foot terminal will not render correctly without the above fonts"
        fi
    fi
fi

# ── optional deps ─────────────────────────────────────────────────────────────
printf '\n  checking optional dependencies...\n\n'

if ! check_cmd notify-send "$(pkg_name terminal-notifier libnotify libnotify-bin) — desktop notifications"; then
    warn "desktop notifications will fall back to stdout"
fi

if ! check_cmd magick "" && ! check_cmd convert ""; then
    warn "ImageMagick not found — map overlays will be skipped"
    info "to install: $(pkg_name 'brew install imagemagick' 'pkg install ImageMagick7' 'apt-get install imagemagick')"
fi

# bat on non-FreeBSD is optional; clue falls back to cat
if [ "$PLATFORM" != "freebsd" ]; then
    if ! check_cmd bat "$(pkg_name bat bat bat) — syntax-highlighted cheatsheet viewer"; then
        warn "clue alias will fall back to cat"
    fi
fi

# ── dev tools (optional) ─────────────────────────────────────────────────────
# these tools are only needed when hacking on the shell scripts themselves.
# not required for normal dotfiles use.
if prompt_yn "install shell dev tools (shellcheck, shfmt, bats-core)?" n; then
    printf '\n  checking shell dev tools...\n\n'
    MISSING_DEV=""
    check_cmd shellcheck "$(pkg_name shellcheck hs-ShellCheck shellcheck)" || MISSING_DEV="$MISSING_DEV $(pkg_name shellcheck hs-ShellCheck shellcheck)"
    check_cmd shfmt      "$(pkg_name shfmt shfmt shfmt)"                   || MISSING_DEV="$MISSING_DEV $(pkg_name shfmt shfmt shfmt)"
    check_cmd bats       "$(pkg_name bats-core bats-core bats-core)"       || MISSING_DEV="$MISSING_DEV $(pkg_name bats-core bats-core bats-core)"
    if [ -n "$MISSING_DEV" ]; then
        printf '\n'
        # shellcheck disable=SC2086  # word-split is intentional — space-delimited pkg list
        install_pkg $MISSING_DEV
    fi
fi

# ── select packages to stow ───────────────────────────────────────────────────
printf '\n  packages available:\n\n'

# threatwatch is available on all platforms
DO_THREATWATCH=1
# quickshell, sh, sway are only meaningful on freebsd/linux (Wayland)
DO_QUICKSHELL=0
DO_SH=0
DO_FOOT=0
DO_SWAY=0
DO_VT=0
[ "$PLATFORM" = "freebsd" ] && DO_QUICKSHELL=1
[ "$PLATFORM" = "freebsd" ] && DO_SH=1
# foot and sway are Wayland-native; default on for freebsd and linux
[ "$PLATFORM" = "freebsd" ] && DO_FOOT=1
[ "$PLATFORM" = "freebsd" ] && DO_SWAY=1
[ "$PLATFORM" = "linux" ]   && DO_FOOT=1
[ "$PLATFORM" = "linux" ]   && DO_SWAY=1
# vt console font — FreeBSD only; stows to /boot/fonts/ (root-owned)
[ "$PLATFORM" = "freebsd" ] && DO_VT=1
# ly display manager config — FreeBSD only; stows to /usr/local/etc/ly/ (root-owned)
DO_LY=0
[ "$PLATFORM" = "freebsd" ] && DO_LY=1

# core packages — available everywhere
DO_GIT=1
DO_VIM=1
DO_INPUTRC=1
DO_CHEATSHEETS=1
DO_SSH=1
DO_TMUX=1
DO_CURL=1

# macOS-only packages
DO_ZSH=0
DO_NVIM=0
DO_SKETCHYBAR=0
[ "$PLATFORM" = "macos" ] && DO_ZSH=1
[ "$PLATFORM" = "macos" ] && DO_NVIM=1
[ "$PLATFORM" = "macos" ] && DO_SKETCHYBAR=1

if [ "$YES" = "0" ]; then
    printf '\n  core packages (all platforms):\n\n'
    prompt_yn "stow git (.gitconfig + .color.gitconfig)?" y && DO_GIT=1 || DO_GIT=0
    prompt_yn "stow vim (.vimrc)?" y                         && DO_VIM=1 || DO_VIM=0
    prompt_yn "stow inputrc (.inputrc)?" y                   && DO_INPUTRC=1 || DO_INPUTRC=0
    prompt_yn "stow cheatsheets (.config/cheatsheets/)?" y   && DO_CHEATSHEETS=1 || DO_CHEATSHEETS=0
    prompt_yn "stow ssh (.ssh/config.template)?" y           && DO_SSH=1 || DO_SSH=0
    prompt_yn "stow tmux (.tmux.conf)?" y                    && DO_TMUX=1 || DO_TMUX=0
    prompt_yn "stow curl (.curlrc)?" y                       && DO_CURL=1 || DO_CURL=0
    prompt_yn "stow threatwatch (threat monitor)?" y         && DO_THREATWATCH=1 || DO_THREATWATCH=0

    if [ "$PLATFORM" = "macos" ]; then
        printf '\n  macOS packages:\n\n'
        prompt_yn "stow zsh (.zshrc + git-worktree helpers)?" y && DO_ZSH=1 || DO_ZSH=0
        prompt_yn "stow nvim (.config/nvim/)?" y                && DO_NVIM=1 || DO_NVIM=0
        prompt_yn "stow sketchybar (.config/sketchybar/)?" y    && DO_SKETCHYBAR=1 || DO_SKETCHYBAR=0
    fi

    if [ "$PLATFORM" = "freebsd" ]; then
        printf '\n  FreeBSD packages:\n\n'
        prompt_yn "stow sh (.shrc + .profile)?" y && DO_SH=1 || DO_SH=0
        prompt_yn "stow foot (Wayland terminal emulator)?" y && DO_FOOT=1 || DO_FOOT=0
        prompt_yn "stow sway (window manager config)?" y && DO_SWAY=1 || DO_SWAY=0
        if prompt_yn "stow quickshell (sway statusbar — Wayland only)?" y; then
            DO_QUICKSHELL=1
        else
            DO_QUICKSHELL=0
        fi
        if prompt_yn "install vt console font to /boot/fonts/ (requires doas/sudo)?" y; then
            DO_VT=1
        else
            DO_VT=0
        fi
        if prompt_yn "install ly config to /usr/local/etc/ly/ (requires doas/sudo)?" y; then
            DO_LY=1
        else
            DO_LY=0
        fi
    elif [ "$PLATFORM" = "linux" ]; then
        printf '\n  Linux packages:\n\n'
        prompt_yn "stow foot (Wayland terminal emulator)?" y && DO_FOOT=1 || DO_FOOT=0
        prompt_yn "stow sway (window manager config)?" y && DO_SWAY=1 || DO_SWAY=0
    else
        info "sh skipped — FreeBSD /bin/sh config only"
        info "foot skipped — Wayland terminal, FreeBSD/Linux only"
        info "sway skipped — Wayland window manager, FreeBSD/Linux only"
        info "quickshell skipped — sway/Wayland package, FreeBSD only"
        info "ly skipped — FreeBSD display manager, FreeBSD only"
    fi
fi

# ── run stow ──────────────────────────────────────────────────────────────────
printf '\n  stowing packages...\n\n'

stow_pkg() {
    _pkg="$1"
    if [ -d "$REPO_DIR/$_pkg" ]; then
        if stow --dir="$REPO_DIR" --target="$HOME" --restow "$_pkg"; then
            ok "stowed $_pkg"
        else
            die "stow failed for $_pkg"
        fi
    else
        warn "package dir not found: $REPO_DIR/$_pkg — skipping"
    fi
}

# stow_root pkg — stow a package that targets / (root-owned paths like /boot or /usr/local/etc).
# requires doas or sudo; used for vt (console font) and ly (display manager config).
stow_root() {
    _pkg="$1"
    if [ ! -d "$REPO_DIR/$_pkg" ]; then
        warn "$_pkg package dir not found — skipping"
        return
    fi
    SUDO=""
    command -v doas >/dev/null 2>&1 && SUDO=doas
    command -v sudo >/dev/null 2>&1 && [ -z "$SUDO" ] && SUDO=sudo
    if [ -z "$SUDO" ]; then
        die "doas or sudo required to stow $_pkg (target is /)"
    fi
    if ${SUDO} stow --dir="$REPO_DIR" --target="/" --restow "$_pkg"; then
        ok "stowed $_pkg → /"
    else
        die "stow failed for $_pkg"
    fi
}

[ "$DO_GIT"         = "1" ] && stow_pkg git
[ "$DO_VIM"         = "1" ] && stow_pkg vim
[ "$DO_INPUTRC"     = "1" ] && stow_pkg inputrc
[ "$DO_CHEATSHEETS" = "1" ] && stow_pkg cheatsheets
[ "$DO_SSH"         = "1" ] && stow_pkg ssh
[ "$DO_TMUX"        = "1" ] && stow_pkg tmux
[ "$DO_CURL"        = "1" ] && stow_pkg curl
[ "$DO_SH"          = "1" ] && stow_pkg sh
[ "$DO_ZSH"         = "1" ] && stow_pkg zsh
[ "$DO_NVIM"        = "1" ] && stow_pkg nvim
[ "$DO_SKETCHYBAR"  = "1" ] && stow_pkg sketchybar
[ "$DO_FOOT"        = "1" ] && stow_pkg foot
[ "$DO_SWAY"        = "1" ] && stow_pkg sway
[ "$DO_THREATWATCH" = "1" ] && stow_pkg threatwatch
[ "$DO_QUICKSHELL"  = "1" ] && stow_pkg quickshell
[ "$DO_VT"          = "1" ] && stow_root vt
[ "$DO_LY"          = "1" ] && stow_root ly

# ── config template ───────────────────────────────────────────────────────────
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/threatwatch"
TEMPLATE="$CONFIG_DIR/config.env.template"
LIVE="$CONFIG_DIR/config.env"

if [ "$DO_THREATWATCH" = "1" ]; then
    printf '\n  threatwatch config...\n\n'

    if [ -f "$LIVE" ]; then
        ok "config.env already exists — not overwriting"
    elif [ -f "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$LIVE"
        chmod 600 "$LIVE"
        ok "created config.env from template"
        warn "edit $LIVE and set MAPBOX_TOKEN before running threatwatch"
        info "get a free token (no credit card): https://account.mapbox.com"
    else
        warn "template not found at $TEMPLATE — stow may not have run correctly"
    fi
fi

# ── ssh config template ───────────────────────────────────────────────────────
if [ "$DO_SSH" = "1" ]; then
    printf '\n  ssh config...\n\n'

    SSH_TEMPLATE="$HOME/.ssh/config.template"
    SSH_LIVE="$HOME/.ssh/config"

    if [ -f "$SSH_LIVE" ]; then
        ok "$HOME/.ssh/config already exists — not overwriting"
    elif [ -f "$SSH_TEMPLATE" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        cp "$SSH_TEMPLATE" "$SSH_LIVE"
        chmod 600 "$SSH_LIVE"
        ok "created ~/.ssh/config from template"
        warn "edit $SSH_LIVE — replace placeholder host aliases and key paths"
    else
        warn "template not found at $SSH_TEMPLATE — stow may not have run correctly"
    fi
fi

# ── cache dir ─────────────────────────────────────────────────────────────────
if [ "$DO_THREATWATCH" = "1" ]; then
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/threatwatch"
    mkdir -p "$CACHE_DIR"
    ok "cache dir: $CACHE_DIR"
fi

# ── PATH reminder ─────────────────────────────────────────────────────────────
case ":${PATH}:" in
    *":$HOME/.local/bin:"*) ;;
    *)
        printf '\n'
        warn "\$HOME/.local/bin is not in your PATH"
        info "add this to your shell profile (~/.profile, ~/.zshrc, etc.):"
        # shellcheck disable=SC2016  # $HOME is literal advice text, not an expansion
        printf '      export PATH="$HOME/.local/bin:$PATH"\n'
        ;;
esac

# ── done ──────────────────────────────────────────────────────────────────────
printf '\n'
ok "done!"

if [ "$DO_THREATWATCH" = "1" ]; then
    printf '\n  quick test:\n'
    printf '    threatwatch update   # fetch all sources\n'
    printf '    threatwatch data     # print summary\n'
    printf '    threatwatch          # statusbar text\n'
fi
printf '\n'
