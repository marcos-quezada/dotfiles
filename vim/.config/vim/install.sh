#!/bin/sh
# ---------------------------------------------------------------------------
# install.sh - install or update vim plugins not covered by built-in features
#
# Copyright 2026, Marcos Quezada Pérez <mquezada@auryn>
# All rights reserved.
#
# Usage: install.sh [-h|--help] [-u|--update]
#
# Revision history:
# 2026-10-07  Created by new_script ver. 3.3-posix
# ---------------------------------------------------------------------------

PROGNAME="${0##*/}"
VERSION="0.1"

set -e

clean_up() { # perform pre-exit housekeeping
    return
}

error_exit() {
    printf '%s: %s\n' "$PROGNAME" "${1:-unknown error}" >&2
    clean_up
    exit 1
}

graceful_exit() {
    clean_up
    exit 0
}

# shellcheck disable=SC2329  # called via trap string, not directly
signal_exit() { # handle trapped signals
    case "$1" in
        INT)  error_exit "program interrupted by user" ;;
        TERM) printf '\n%s: program terminated\n' "$PROGNAME" >&2; graceful_exit ;;
        *)    error_exit "terminating on unknown signal" ;;
    esac
}

usage() {
    printf '%s\n' "install.sh [-h|--help] [-u|--update]"
}

help_message() {
    cat <<- _EOF_
	$PROGNAME ver. $VERSION
	install or update vim plugins not covered by built-in features

	$(usage)

	Options:

	  -h, --help  Display this help message and exit.
	  -u, --update  update already-installed plugins (same as default behavior, kept for backward-compatible invocation)

	_EOF_
}

# trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT



# parse command-line
while [ -n "${1:-}" ]; do
    case "$1" in
        -h | --help) help_message; graceful_exit ;;
        -u | --update)
            # update already-installed plugins (same as default behavior, kept for backward-compatible invocation)
            ;;
        -*)
            usage
            error_exit "unknown option $1" ;;
        *)
            # positional argument: $1
            ;;
    esac
    shift
done

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

graceful_exit
