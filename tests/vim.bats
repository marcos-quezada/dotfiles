#!/usr/bin/env bats
# vim.bats — headless sourcing tests for vim config files
# run: bats tests/vim.bats
#
# uses `vim -es` (silent ex mode) to source each config file and assert:
#   - no E-series errors (exit 0)
#   - expected options are set
#   - keymaps are registered
#
# --cmd "set cpoptions-=C" is required in all tests: in -es mode the C flag
# treats lines starting with \ as new commands rather than continuation lines,
# which breaks the multiline #{...} dict literal in lsp.vim.
#
# --cmd "set packpath=$TMPDIR" points vim at a minimal stub plugin that defines
# LspAddServer() so packadd lsp succeeds without a real checkout.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VIM_DIR="$REPO_ROOT/vim"

setup() {
    TMPDIR=$(mktemp -d)

    # minimal lsp stub — packadd lsp needs the directory tree and a plugin
    # file that defines LspAddServer so the call in lsp.vim doesn't fail
    mkdir -p "$TMPDIR/pack/plugins/opt/lsp/plugin"
    printf 'function! LspAddServer(servers) abort\nendfunction\n' \
        > "$TMPDIR/pack/plugins/opt/lsp/plugin/lsp.vim"

    # fake home with symlinks so .vimrc's `source ~/.config/vim/…` paths resolve
    mkdir -p "$TMPDIR/home/.config/vim"
    ln -s "$VIM_DIR/.config/vim/theme.vim" "$TMPDIR/home/.config/vim/theme.vim"
    ln -s "$VIM_DIR/.config/vim/lsp.vim"   "$TMPDIR/home/.config/vim/lsp.vim"
}

teardown() {
    rm -rf "$TMPDIR"
}

# shared --cmd flags used by every test that needs the lsp stub and continuation fix
_vim_base_cmd() {
    printf '%s' "vim --clean -es -u NONE --cmd 'set packpath=$TMPDIR' --cmd 'set cpoptions-=C'"
}

@test "vim is available" {
    command -v vim >/dev/null 2>&1
}

@test "theme.vim: sources without error" {
    run vim --clean -es -u NONE \
        --cmd "set cpoptions-=C" \
        -c "source $VIM_DIR/.config/vim/theme.vim" \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test "lsp.vim: sources without error" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        -c "source $VIM_DIR/.config/vim/lsp.vim" \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test ".vimrc: sources without error" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        --cmd "let \$HOME='$TMPDIR/home'" \
        -c "source $VIM_DIR/.vimrc" \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test ".vimrc: tabstop is 2" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        --cmd "let \$HOME='$TMPDIR/home'" \
        -c "source $VIM_DIR/.vimrc" \
        -c 'if &tabstop != 2 | cq | endif' \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test ".vimrc: expandtab is set" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        --cmd "let \$HOME='$TMPDIR/home'" \
        -c "source $VIM_DIR/.vimrc" \
        -c 'if !&expandtab | cq | endif' \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test ".vimrc: mapleader is space" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        --cmd "let \$HOME='$TMPDIR/home'" \
        -c "source $VIM_DIR/.vimrc" \
        -c 'if mapleader != " " | cq | endif' \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test "lsp.vim: <leader>gd is mapped" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        -c "source $VIM_DIR/.config/vim/lsp.vim" \
        -c 'if maparg("<leader>gd", "n") == "" | cq | endif' \
        -c 'qa!'
    [ "$status" -eq 0 ]
}

@test "lsp.vim: <leader>rn is mapped" {
    run vim --clean -es -u NONE \
        --cmd "set packpath=$TMPDIR" \
        --cmd "set cpoptions-=C" \
        -c "source $VIM_DIR/.config/vim/lsp.vim" \
        -c 'if maparg("<leader>rn", "n") == "" | cq | endif' \
        -c 'qa!'
    [ "$status" -eq 0 ]
}
