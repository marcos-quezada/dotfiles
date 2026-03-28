#!/usr/bin/env bats
# lint.bats — ShellCheck gate for all POSIX sh scripts
# run: bats tests/lint.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "shellcheck is available" {
    command -v shellcheck >/dev/null 2>&1
}

@test "new_script: shellcheck clean" {
    run shellcheck "$REPO_ROOT/git/.local/bin/new_script"
    [ "$status" -eq 0 ]
}

@test "git-clone-bare-for-worktrees: shellcheck clean" {
    run shellcheck "$REPO_ROOT/git/.local/bin/git-clone-bare-for-worktrees"
    [ "$status" -eq 0 ]
}

@test "gwt.sh: shellcheck clean" {
    run shellcheck "$REPO_ROOT/sh/.config/sh/gwt.sh"
    [ "$status" -eq 0 ]
}

@test "threatwatch: shellcheck clean" {
    run shellcheck "$REPO_ROOT/threatwatch/.local/bin/threatwatch"
    [ "$status" -eq 0 ]
}

@test "install.sh: shellcheck clean" {
    run shellcheck "$REPO_ROOT/install.sh"
    [ "$status" -eq 0 ]
}

@test "vim install.sh: shellcheck clean" {
    run shellcheck "$REPO_ROOT/vim/.config/vim/install.sh"
    [ "$status" -eq 0 ]
}

@test "sketchybar battery.sh: shellcheck clean" {
    run shellcheck "$REPO_ROOT/sketchybar/.config/sketchybar/plugins/battery.sh"
    [ "$status" -eq 0 ]
}

@test "sketchybar icon_map_fn.sh: shellcheck clean" {
    run shellcheck "$REPO_ROOT/sketchybar/.config/sketchybar/plugins/icon_map_fn.sh"
    [ "$status" -eq 0 ]
}

@test "sketchybar space.sh: shellcheck clean" {
    run shellcheck "$REPO_ROOT/sketchybar/.config/sketchybar/plugins/space.sh"
    [ "$status" -eq 0 ]
}

# ── bats test files ───────────────────────────────────────────────────────────
# bats files are bash; lint them so new tests can't silently introduce warnings.

@test "threatwatch.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/threatwatch.bats"
    [ "$status" -eq 0 ]
}

@test "gwt.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/gwt.bats"
    [ "$status" -eq 0 ]
}

@test "git-clone-bare.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/git-clone-bare.bats"
    [ "$status" -eq 0 ]
}

@test "lint.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/lint.bats"
    [ "$status" -eq 0 ]
}

@test "new_script.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/new_script.bats"
    [ "$status" -eq 0 ]
}

@test "vim.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/vim.bats"
    [ "$status" -eq 0 ]
}

@test "qml.bats: shellcheck clean" {
    run shellcheck --shell=bash "$REPO_ROOT/tests/qml.bats"
    [ "$status" -eq 0 ]
}
