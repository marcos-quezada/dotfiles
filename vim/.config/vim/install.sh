#!/bin/sh
# install vim plugins that cannot be covered by built-in features.
#
# uses vim's native package system (vim 8+): plugins live under
# ~/.vim/pack/<bucket>/opt/<name> and are loaded on demand via :packadd.
#
# plugins managed here:
#   yegappan/lsp — LSP client (loaded on demand via 'packadd lsp' in lsp.vim)
#
# usage:
#   sh ~/.config/vim/install.sh
#   sh ~/.config/vim/install.sh --update

set -e

OPT_DIR="$HOME/.vim/pack/plugins/opt"

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

mkdir -p "$OPT_DIR"

# ── plugins ───────────────────────────────────────────────────────────────────

# yegappan/lsp: LSP client — loaded on demand via 'packadd lsp' in lsp.vim
install_or_update \
    "yegappan/lsp" \
    "https://github.com/yegappan/lsp.git" \
    "$OPT_DIR/lsp"

printf '\ndone. restart vim to apply changes.\n'
