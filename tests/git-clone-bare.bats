#!/usr/bin/env bats
# git-clone-bare.bats — integration tests for git-clone-bare-for-worktrees
# run: bats tests/git-clone-bare.bats
#
# creates a local bare repo as the "remote" so no network is needed.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CLONE_SCRIPT="$REPO_ROOT/git/.local/bin/git-clone-bare-for-worktrees"

setup() {
    TMPDIR=$(mktemp -d)

    # create a local "remote" — a bare repo with one commit
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

    CLONEDIR="$TMPDIR/clones"
    mkdir "$CLONEDIR"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "clone: no args prints usage and exits non-zero" {
    run "$CLONE_SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage"* ]]
}

@test "clone: creates hub directory with .bare and .git" {
    cd "$CLONEDIR"
    run "$CLONE_SCRIPT" "$REMOTE" myclone
    [ "$status" -eq 0 ]
    [ -d "$CLONEDIR/myclone/.bare" ]
    [ -f "$CLONEDIR/myclone/.git" ]
}

@test "clone: .git file contains gitdir redirect" {
    cd "$CLONEDIR"
    "$CLONE_SCRIPT" "$REMOTE" myclone
    grep -q 'gitdir: ./.bare' "$CLONEDIR/myclone/.git"
}

@test "clone: remote.origin.fetch is configured correctly" {
    cd "$CLONEDIR"
    "$CLONE_SCRIPT" "$REMOTE" myclone
    FETCH=$(git -C "$CLONEDIR/myclone/.bare" config remote.origin.fetch)
    [ "$FETCH" = "+refs/heads/*:refs/remotes/origin/*" ]
}

@test "clone: remote tracking refs are populated" {
    cd "$CLONEDIR"
    "$CLONE_SCRIPT" "$REMOTE" myclone
    # at least one remotes/origin ref should exist after fetch
    COUNT=$(git -C "$CLONEDIR/myclone/.bare" for-each-ref refs/remotes/origin | wc -l)
    [ "$COUNT" -gt 0 ]
}

@test "clone: name defaults to repo name without .git extension" {
    cd "$CLONEDIR"
    run "$CLONE_SCRIPT" "$REMOTE"
    [ "$status" -eq 0 ]
    # REMOTE ends in "remote.git" so default name is "remote"
    [ -d "$CLONEDIR/remote" ]
}

@test "clone: fails when target directory already exists" {
    mkdir "$CLONEDIR/exists"
    cd "$CLONEDIR"
    run "$CLONE_SCRIPT" "$REMOTE" exists
    [ "$status" -ne 0 ]
}
