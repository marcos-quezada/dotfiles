#!/bin/sh
# common.sh — shared setup/teardown helpers for bats suites
# source with:  # shellcheck source=tests/common.sh
#               . "$REPO_ROOT/tests/common.sh"

# create a private temp directory and export it.
# caller is responsible for teardown via common_tmp_teardown.
common_tmp_setup() {
    BATS_TMPDIR="$(mktemp -d)"
    export BATS_TMPDIR
}

# remove the temp directory created by common_tmp_setup.
common_tmp_teardown() {
    rm -rf "${BATS_TMPDIR:-}"
}

# strip the main dispatcher from a threatwatch script so it can be sourced
# without executing the case block that calls tobar() on every invocation.
# writes the result to $1; reads from $2 (the full script path).
# relies on the sentinel comment "# ── main" anchored by convention.
tw_funcs_strip() {
    _dst="$1"
    _src="$2"
    awk '/^# ── main/{exit} {print}' "$_src" > "$_dst"
    unset _dst _src
}
