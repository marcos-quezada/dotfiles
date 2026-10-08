#!/bin/sh
# install.d/common.sh — shared helpers for install.sh and its modules
# sourced only, never executed directly: . install.d/common.sh

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; RST='\033[0m'
ok()   { printf "${GRN}  ✔${RST} %s\n" "$*"; }
info() { printf "${BLU}  ·${RST} %s\n" "$*"; }
warn() { printf "${YLW}  ⚠${RST} %s\n" "$*"; }
die()  { printf "${RED}  ✘${RST} %s\n" "$*" >&2; exit 1; }

# ── prompt_yn ─────────────────────────────────────────────────────────────────
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

# ── detect_sudo ───────────────────────────────────────────────────────────────
# sets the global $SUDO to "doas" (preferred) or "sudo" (fallback), or "" if
# neither is found. callers check [ -z "$SUDO" ] to detect the latter case.
detect_sudo() {
    SUDO=""
    command -v doas >/dev/null 2>&1 && SUDO=doas
    command -v sudo >/dev/null 2>&1 && [ -z "$SUDO" ] && SUDO=sudo
    return 0
}

# ── check_cmd ─────────────────────────────────────────────────────────────────
check_cmd() {
    # check_cmd cmd "install hint"
    if command -v "$1" >/dev/null 2>&1; then
      ok "$1 found"
      return 0
    else
      warn "$1 not found - $2"
      return 1
    fi
}

# ── install_pkg ───────────────────────────────────────────────────────────────
install_pkg() {
    # install_pkg pkg [pkg ...] — installs via the platform package manager
    case "$PLATFORM" in
      macos)
        command -v brew>/dev/null 2>&1 || die "homebrew not found – install from https://brew.sh"
        brew install "$@"
        ;;
      freebsd)
        detect_sudo
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

# ── pkg_name ──────────────────────────────────────────────────────────────────
pkg_name() {
    # pkg_name macos_name freebsd_name linux_name
    case "$PLATFORM" in
      macos)   printf '%s' "$1" ;;
      freebsd) printf '%s' "$2" ;;
      linux)   printf '%s' "$3" ;;
    esac
}

# ── stow_pkg ──────────────────────────────────────────────────────────────────
stow_pkg() {
    _pkg="$1"
    if [ -d "$REPO_DIR/$_pkg" ]; then
      if stow --dir="$REPO_DIR" --target="$HOME" --restow "$_pkg"; then
        ok "stowed $_pkg"
      else
        die "stow failed for $_pkg"
      fi
    else
      warn "package dir not found: $REPO_DIR/$_pkg – skipping"
    fi
}

# stow_root pkg — stow a package that targets / (root owned paths like /boot or /usr/local/etc).
# requires doas or sudo; used for ly (display manager config).
stow_root() {
    _pkg="$1"
    if [ ! -d "$REPO_DIR/$_pkg" ]; then
      warn "$_pkg package dir not found – skipping"
      return
    fi
    detect_sudo
    if [ -z "$SUDO" ]; then
      die "doas or sudo required to stow $_pkg (target isi /)"
    fi
    if ${SUDO} stow --dir="$REPO_DIR" --target="/" --restow "$_pkg"; then
      ok "stowed $_pkg → /"
    else
      die "stow failed for $_pkg"
    fi
}
