#!/bin/sh
# install.sh — bootstrap dotfiles on macOS, FreeBSD, or Linux
# usage: sh install.sh [--yes]
#   --yes  accept all defaults non-interactively

set -e

# ── detect OS ─────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Darwin)  PLATFORM=macos   ;;
    FreeBSD) PLATFORM=freebsd ;;
    Linux)   PLATFORM=linux   ;;
    *)       die "unsupported platform: $OS" ;;
esac

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# install.d/ modules — order matters: common.sh must come first (defines
# ok/warn/die/prompt_yn/etc. that every other module depends on).
. "$REPO_DIR/install.d/common.sh"
. "$REPO_DIR/install.d/check-deps.sh"
. "$REPO_DIR/install.d/freebsd.sh"
. "$REPO_DIR/install.d/desktop.sh"
YES=0
[ "${1:-}" = "--yes" ] && YES=1

# ── banner ────────────────────────────────────────────────────────────────────
printf '\n'
printf '  dotfiles installer\n'
printf '  platform: %s\n' "$PLATFORM"
printf '  repo:     %s\n' "$REPO_DIR"
printf '\n'

# ── stow check ────────────────────────────────────────────────────────────────
check_deps_main

# ── FreeBSD setup ─────────────────────────────────────────────────────────────
[ "$PLATFORM" = "freebsd" ] && freebsd_setup_main

# ── select packages to stow ───────────────────────────────────────────────────
printf '\n  packages available:\n\n'

# threatwatch is available on all platforms
DO_THREATWATCH=1

# core packages — available everywhere
DO_GIT=1
DO_BIN=1
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
    prompt_yn "stow bin (.local/bin/new_script — general-purpose tools)?" y && DO_BIN=1 || DO_BIN=0
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
fi

# ── run stow ──────────────────────────────────────────────────────────────────
printf '\n  stowing packages...\n\n'

[ "$DO_GIT"         = "1" ] && stow_pkg git
[ "$DO_BIN"         = "1" ] && stow_pkg bin
[ "$DO_VIM"         = "1" ] && stow_pkg vim
[ "$DO_INPUTRC"     = "1" ] && stow_pkg inputrc
[ "$DO_CHEATSHEETS" = "1" ] && stow_pkg cheatsheets
[ "$DO_SSH"         = "1" ] && stow_pkg ssh
[ "$DO_TMUX"        = "1" ] && stow_pkg tmux
[ "$DO_CURL"        = "1" ] && stow_pkg curl
[ "$DO_ZSH"         = "1" ] && stow_pkg zsh
[ "$DO_NVIM"        = "1" ] && stow_pkg nvim
[ "$DO_SKETCHYBAR"  = "1" ] && stow_pkg sketchybar
[ "$DO_THREATWATCH" = "1" ] && stow_pkg threatwatch

desktop_select_main

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
