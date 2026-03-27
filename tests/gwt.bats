#!/usr/bin/env bats
# gwt.bats — tests for gwt.sh bare-worktree helpers
# run: bats tests/gwt.bats
#
# gwt.sh is a sourced library, not an executable. we source it in each test
# to get the functions into scope without polluting the global shell.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GWT="$REPO_ROOT/sh/.config/sh/gwt.sh"

setup() {
    TMPDIR=$(mktemp -d)

    # build a local bare-worktree hub so _gwt_bare_root can resolve it
    HUB="$TMPDIR/hub"
    REMOTE="$TMPDIR/remote.git"
    WORK="$TMPDIR/work"

    mkdir "$WORK"
    git -C "$WORK" init -q
    git -C "$WORK" config user.email "test@test"
    git -C "$WORK" config user.name "Test"
    touch "$WORK/README"
    git -C "$WORK" add README
    git -C "$WORK" commit -q -m "init"
    git clone --bare -q "$WORK" "$REMOTE"

    mkdir "$HUB"
    git clone --bare -q "$REMOTE" "$HUB/.bare"
    printf 'gitdir: ./.bare\n' > "$HUB/.git"
    git -C "$HUB/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git -C "$HUB/.bare" fetch -q origin

    # resolve canonical path — macOS /var/… symlinks to /private/var/…;
    # git worktree list returns the physical path so $HUB must match it.
    HUB=$(cd "$HUB" && pwd -P)
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── _gwt_bare_root ────────────────────────────────────────────────────────────

@test "_gwt_bare_root: resolves from hub root" {
    # shellcheck disable=SC1090
    . "$GWT"
    cd "$HUB"
    ROOT=$(_gwt_bare_root)
    [ "$ROOT" = "$HUB" ]
}

@test "_gwt_bare_root: returns 1 outside a hub" {
    # shellcheck disable=SC1090
    . "$GWT"
    cd "$TMPDIR"
    run _gwt_bare_root
    [ "$status" -ne 0 ]
}

# ── dispatcher: unknown subcommand prints help ────────────────────────────────

@test "gwt: no args prints usage" {
    # shellcheck disable=SC1090
    . "$GWT"
    run gwt
    [[ "$output" == *"usage"* ]]
}

@test "gwt: unknown subcommand prints usage" {
    # shellcheck disable=SC1090
    . "$GWT"
    run gwt boguscommand
    [[ "$output" == *"usage"* ]]
}

# ── gwt ls ───────────────────────────────────────────────────────────────────

@test "gwt ls: lists worktrees from inside hub" {
    # shellcheck disable=SC1090
    . "$GWT"
    cd "$HUB"
    run gwt ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"PATH"* ]]
}

# ── gwt add (local branch from fixture hub) ───────────────────────────────────

@test "gwt add: creates worktree directory" {
    # shellcheck disable=SC1090
    . "$GWT"
    cd "$HUB"
    # suppress $EDITOR — gwt add opens it after creating the worktree
    EDITOR=true
    # use 'master' or 'main' — whichever the fixture remote has
    DEFAULT_BRANCH=$(git -C "$HUB/.bare" symbolic-ref --short HEAD 2>/dev/null || echo main)
    run gwt add "test-branch" "$DEFAULT_BRANCH"
    [ "$status" -eq 0 ]
    [ -d "$HUB/test-branch" ]
}

# ── gwt go ────────────────────────────────────────────────────────────────────

@test "gwt go: jumps into matching worktree" {
    # shellcheck disable=SC1090
    . "$GWT"
    cd "$HUB"
    # suppress $EDITOR — gwt add opens it after creating the worktree
    EDITOR=true
    DEFAULT_BRANCH=$(git -C "$HUB/.bare" symbolic-ref --short HEAD 2>/dev/null || echo main)
    gwt add "feature-xyz" "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
    cd "$HUB"
    gwt go "feature-xyz"
    [ "$PWD" = "$HUB/feature-xyz" ]
}

@test "gwt go: fails with no match" {
    # shellcheck disable=SC1090
    . "$GWT"
    cd "$HUB"
    run gwt go "no-such-branch-xyz"
    [ "$status" -ne 0 ]
}
