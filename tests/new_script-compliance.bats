#!/usr/bin/env bats
# new_script-compliance.bats — provenance gate for standalone shell scripts
# run: bats tests/new_script-compliance.bats
#
# asserts every standalone, directly-executed shell script authored by this
# project carries a "Created by new_script" provenance line. deliberately
# explicit, one assertion per known file — no dynamic repo-wide scanning,
# same style as tests/lint.bats. a new script needs a line added here
# (either asserting compliance, or explaining why it's exempt) the same way
# it needs an entry in tests/lint.bats.
#
# exception categories (see openspec/changes/new-script-compliance-retrofit
# and docs/architecture.md's "script modularization" section):
#   - sourced-only (never directly executed): gwt.sh, common.sh
#   - the new_script tool itself (nothing to scaffold it with)
#   - a documented multi-file-orchestrator exception: install.sh
#   - vendored/third-party, not this project's own authorship: sketchybar/*
#   - known, tracked, temporary exception: threatwatch (see
#     threatwatch-modularization — expected to become a documented
#     orchestrator exception too, once modularized, not retrofitted)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

_assert_has_provenance() {
    run grep -q "Created by new_script" "$REPO_ROOT/$1"
    [ "$status" -eq 0 ]
}

@test "esp-idf-env: has new_script provenance" {
    _assert_has_provenance "bin/.esp-idf-env"
}

@test "esp-idf-setup: has new_script provenance" {
    _assert_has_provenance "bin/.local/bin/esp-idf-setup"
}

@test "gem-launch: has new_script provenance" {
    _assert_has_provenance "bin/.local/bin/gem-launch"
}

@test "queue-track: has new_script provenance" {
    _assert_has_provenance "bin/.local/bin/queue-track"
}

@test "sound-status: has new_script provenance" {
    _assert_has_provenance "bin/.local/bin/sound-status"
}

@test "switch-audio-output: has new_script provenance" {
    _assert_has_provenance "bin/.local/bin/switch-audio-output"
}

@test "git-clone-bare-for-worktrees: has new_script provenance" {
    _assert_has_provenance "git/.local/bin/git-clone-bare-for-worktrees"
}

@test "freebsd-adduser.sh: has new_script provenance" {
    _assert_has_provenance "scripts/freebsd-adduser.sh"
}

@test "vim install.sh: has new_script provenance" {
    _assert_has_provenance "vim/.config/vim/install.sh"
}

# ── documented exceptions (no provenance expected, asserted not to regress) ──

@test "gwt.sh: confirmed sourced-only, not a new_script candidate" {
    run grep -q "^# source from .shrc" "$REPO_ROOT/sh/.config/sh/gwt.sh"
    [ "$status" -eq 0 ]
}

@test "common.sh: confirmed sourced-only, not a new_script candidate" {
    run grep -q "sourcing point for future shared helpers" "$REPO_ROOT/tests/common.sh"
    [ "$status" -eq 0 ]
}
