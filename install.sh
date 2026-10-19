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
. "$REPO_DIR/install.d/base.sh"
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

base_select_main

desktop_select_main

base_post_config_main
