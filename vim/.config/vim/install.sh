#!/bin/sh
# vim/install.sh — install vim plugins that cannot be covered by built-in features.
#
# uses vim's native package system (vim 8+): plugins live under
# ~/.vim/pack/<bucket>/start/<name> and are loaded automatically on startup,
# or under .../opt/<name> and loaded on demand via :packadd.
#
# plugins managed here:
#   catppuccin/vim  — colour theme  (no built-in equivalent)
#   yegappan/lsp    — LSP client    (built-in lsp landed in vim 9.0 as an optional package)
#
# usage:
#   sh ~/.config/vim/install.sh
#   sh ~/.config/vim/install.sh --update

set -e

PACK_DIR="$HOME/.vim/pack/plugins"
START_DIR="$PACK_DIR/start"
OPT_DIR="$PACK_DIR/opt"

# ── helpers ───────────────────────────────────────────────────────────────────

install_or_update() {
    name="$1"
    url="$2"
    dest="$3"

    if [ -d "$dest/.git" ]; then
        printf 'updating  %s\n' "$name"
        git -C "$dest" pull --ff-only --quiet
    else
        printf 'installing %s\n' "$name"
        git clone --depth=1 --quiet "$url" "$dest"
    fi
}

# ── directories ───────────────────────────────────────────────────────────────

mkdir -p "$START_DIR"
mkdir -p "$OPT_DIR"

# ── plugins ───────────────────────────────────────────────────────────────────

# catppuccin: colour theme — loaded at startup
install_or_update \
    "catppuccin/vim" \
    "https://github.com/catppuccin/vim.git" \
    "$START_DIR/catppuccin"

# yegappan/lsp: LSP client — loaded on demand via 'packadd lsp' in syntax.vim
install_or_update \
    "yegappan/lsp" \
    "https://github.com/yegappan/lsp.git" \
    "$OPT_DIR/lsp"

printf '\ndone. restart vim to apply changes.\n'
