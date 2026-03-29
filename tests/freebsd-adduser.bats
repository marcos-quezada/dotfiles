#!/usr/bin/env bats
# freebsd-adduser.bats — functional tests for scripts/freebsd-adduser.sh
# run: bats tests/freebsd-adduser.bats
#
# all FreeBSD-specific binaries (pw, id, grep) are mocked via PATH prepend.
# the script is never run with real root; the id mock returns uid=0 by default.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/freebsd-adduser.sh"

setup() {
    MOCK_BIN="$(mktemp -d)"
    CALL_LOG="$MOCK_BIN/calls"
    touch "$CALL_LOG"
    export MOCK_BIN CALL_LOG

    # id mock:
    #   id -u            → 0 (root)
    #   id <username>    → controlled by $MOCK_BIN/id_user_result:
    #                       file absent or "0" → exit 1 (user not found)
    #                       "1"               → exit 0 + groups line
    #   pw mock records calls, then writes "1" to id_user_result so that the
    #   summary call to `id <username>` at end of script always succeeds.
    cat > "$MOCK_BIN/id" << EOF
#!/bin/sh
if [ "\${1:-}" = "-u" ]; then printf '0\n'; exit 0; fi
if [ -n "\${1:-}" ]; then
    _r="\$(cat "$MOCK_BIN/id_user_result" 2>/dev/null || printf '0')"
    [ "\$_r" = "1" ] || exit 1
    printf 'uid=1001(%s) gid=1001(%s) groups=%s\n' \\
        "\$1" "\$1" "\${USER_GROUPS:-1001(\$1)}"
    exit 0
fi
EOF
    chmod +x "$MOCK_BIN/id"

    # pw mock — records every invocation, then marks user as existing so the
    # final `id <username>` summary call succeeds (mirrors real pw useradd)
    cat > "$MOCK_BIN/pw" << EOF
#!/bin/sh
printf 'pw %s\n' "\$*" >> "$CALL_LOG"
printf '1' > "$MOCK_BIN/id_user_result"
EOF
    chmod +x "$MOCK_BIN/pw"

    # grep mock — intercepts grep -q "^<grp>:" /etc/group
    # controlled by GROUPS_PRESENT env var (space-separated group names)
    cat > "$MOCK_BIN/grep" << 'EOF'
#!/bin/sh
_pat="" _file=""
for _a in "$@"; do
    case "$_a" in
        -q|-e|-i|-w|-n) ;;
        /etc/group) _file="$_a" ;;
        *) [ -z "$_pat" ] && _pat="$_a" ;;
    esac
done
if [ "$_file" = "/etc/group" ]; then
    _grp="${_pat#^}"; _grp="${_grp%:}"
    for _g in ${GROUPS_PRESENT:-wheel operator video webcamd}; do
        [ "$_g" = "$_grp" ] && exit 0
    done
    exit 1
fi
exec /usr/bin/grep "$@"
EOF
    chmod +x "$MOCK_BIN/grep"
}

teardown() {
    rm -rf "$MOCK_BIN"
}

# seed id_user_result before running; USER_EXISTS=1 means user already exists
_run_script() {
    [ "${USER_EXISTS:-0}" = "1" ] && printf '1' > "$MOCK_BIN/id_user_result"
    # shellcheck disable=SC2030
    run env PATH="$MOCK_BIN:$PATH" \
        USER_GROUPS="${USER_GROUPS:-}" \
        GROUPS_PRESENT="${GROUPS_PRESENT:-wheel operator video webcamd}" \
        sh "$SCRIPT" "$@"
}

# ── root check ────────────────────────────────────────────────────────────────

@test "freebsd-adduser: exits non-zero when not run as root" {
    cat > "$MOCK_BIN/id" << 'EOF'
#!/bin/sh
if [ "${1:-}" = "-u" ]; then printf '1001\n'; exit 0; fi
exit 1
EOF
    chmod +x "$MOCK_BIN/id"
    _run_script testuser
    [ "$status" -ne 0 ]
    [[ "$output" == *"must run as root"* ]]
}

# ── argument check ────────────────────────────────────────────────────────────

@test "freebsd-adduser: exits non-zero with no username argument" {
    _run_script
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage:"* ]]
}

# ── user creation ─────────────────────────────────────────────────────────────

@test "freebsd-adduser: creates user when absent" {
    # id_user_result absent → user not found → pw useradd runs → pw mock sets result=1
    USER_EXISTS=0 _run_script newuser
    [ "$status" -eq 0 ]
    grep -q "pw useradd newuser" "$CALL_LOG"
}

@test "freebsd-adduser: sets login shell to /bin/sh" {
    USER_EXISTS=0 _run_script newuser
    [ "$status" -eq 0 ]
    grep -q -- "-s /bin/sh" "$CALL_LOG"
}

@test "freebsd-adduser: skips pw useradd when user already exists" {
    USER_EXISTS=1 _run_script newuser
    [ "$status" -eq 0 ]
    _script_output="$output"
    run ! grep -q "pw useradd" "$CALL_LOG"
    [[ "$_script_output" == *"already exists"* ]]
}

# ── group assignment ──────────────────────────────────────────────────────────

@test "freebsd-adduser: adds user to all required groups when member of none" {
    # USER_GROUPS empty → id reports only primary group
    USER_EXISTS=1 USER_GROUPS="1001(newuser)" _run_script newuser
    [ "$status" -eq 0 ]
    grep -q "pw groupmod wheel" "$CALL_LOG"
    grep -q "pw groupmod operator" "$CALL_LOG"
    grep -q "pw groupmod video" "$CALL_LOG"
    grep -q "pw groupmod webcamd" "$CALL_LOG"
}

@test "freebsd-adduser: skips group user is already a member of" {
    # USER_GROUPS includes wheel → pw groupmod wheel must not be called
    USER_EXISTS=1 USER_GROUPS="0(wheel),1001(newuser)" _run_script newuser
    [ "$status" -eq 0 ]
    run ! grep -q "pw groupmod wheel" "$CALL_LOG"
}

@test "freebsd-adduser: skips and warns when group does not exist on system" {
    # webcamd absent from /etc/group mock
    USER_EXISTS=1 USER_GROUPS="1001(newuser)" \
        GROUPS_PRESENT="wheel operator video" \
        _run_script newuser
    [ "$status" -eq 0 ]
    _script_output="$output"
    run ! grep -q "pw groupmod webcamd" "$CALL_LOG"
    [[ "$_script_output" == *"webcamd not found"* ]]
}

# ── summary output ────────────────────────────────────────────────────────────

@test "freebsd-adduser: prints next steps after success" {
    USER_EXISTS=1 _run_script newuser
    [ "$status" -eq 0 ]
    [[ "$output" == *"passwd newuser"* ]]
    [[ "$output" == *"install.sh"* ]]
}
