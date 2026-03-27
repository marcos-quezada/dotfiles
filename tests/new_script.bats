#!/usr/bin/env bats
# new_script.bats — unit tests for new_script template generator
# run: bats tests/new_script.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
NEW_SCRIPT="$REPO_ROOT/git/.local/bin/new_script"

setup() {
    TMPDIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "new_script: -h prints usage and exits 0" {
    run "$NEW_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "new_script: --help prints usage and exits 0" {
    run "$NEW_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "new_script: unknown option exits non-zero" {
    run "$NEW_SCRIPT" --bogus
    [ "$status" -ne 0 ]
}

@test "new_script: -q writes file to given path" {
    OUT="$TMPDIR/myscript.sh"
    run "$NEW_SCRIPT" -q "$OUT"
    [ "$status" -eq 0 ]
    [ -f "$OUT" ]
}

@test "new_script: -q output is executable" {
    OUT="$TMPDIR/myscript.sh"
    "$NEW_SCRIPT" -q "$OUT"
    [ -x "$OUT" ]
}

@test "new_script: -q output has POSIX shebang" {
    OUT="$TMPDIR/myscript.sh"
    "$NEW_SCRIPT" -q "$OUT"
    head -1 "$OUT" | grep -q '^#!/bin/sh'
}

@test "new_script: -q output has usage() function" {
    OUT="$TMPDIR/myscript.sh"
    "$NEW_SCRIPT" -q "$OUT"
    grep -q 'usage()' "$OUT"
}

@test "new_script: -q output has signal traps" {
    OUT="$TMPDIR/myscript.sh"
    "$NEW_SCRIPT" -q "$OUT"
    grep -q 'trap.*signal_exit' "$OUT"
}

@test "new_script: -q output passes shellcheck" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not available"
    OUT="$TMPDIR/myscript.sh"
    "$NEW_SCRIPT" -q "$OUT"
    run shellcheck "$OUT"
    [ "$status" -eq 0 ]
}

@test "new_script: -q with existing non-writable file exits non-zero" {
    OUT="$TMPDIR/readonly.sh"
    touch "$OUT"
    chmod 444 "$OUT"
    run "$NEW_SCRIPT" -q "$OUT"
    [ "$status" -ne 0 ]
}

@test "new_script: -q with non-existent directory exits non-zero" {
    run "$NEW_SCRIPT" -q "$TMPDIR/nosuchdir/myscript.sh"
    [ "$status" -ne 0 ]
}

@test "new_script: -q -s output has root check" {
    OUT="$TMPDIR/rootscript.sh"
    run "$NEW_SCRIPT" -q -s "$OUT"
    [ "$status" -eq 0 ]
    grep -q 'superuser' "$OUT"
}
