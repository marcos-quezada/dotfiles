#!/bin/sh
# ---------------------------------------------------------------------------
# freebsd-adduser.sh - bootstrap a new user on a fresh FreeBSD install
#
# Copyright 2026, Marcos Quezada Pérez <mquezada@auryn>
# All rights reserved.
#
# Usage: freebsd-adduser.sh [-h|--help]
#
# Revision history:
# 2026-10-06  Created by new_script ver. 3.3-posix
# ---------------------------------------------------------------------------

PROGNAME="${0##*/}"
GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; RST='\033[0m'
ok()   { printf "${GRN}  ✔${RST} %s\n" "$*"; }
info() { printf "${BLU}  ·${RST} %s\n" "$*"; }
warn() { printf "${YLW}  ⚠${RST} %s\n" "$*"; }
VERSION="0.1"

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
    printf '%s\n' "freebsd-adduser.sh [-h|--help] <username>"
}

help_message() {
    cat <<- _EOF_
	$PROGNAME ver. $VERSION
	bootstrap a new user on a fresh FreeBSD install

	$(usage)

  what it does:
    - creates the user with /bin/sh login shell and /home/<user> home dir
    - assigns required groups: wheel, operator, video, webcamd
    - skip groups the user already belongs to (idempotent)
    - does NOT set a password -- run passwd <user> after this script
    - does NOT install doas -- run install.sh as the new user for that

	Options:

	  -h, --help  Display this help message and exit.

	NOTE: Must run as root.

	_EOF_
}

# trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT

# check for root UID
if [ "$(id -u)" != "0" ]; then
    error_exit "must run as root"
fi

# parse command-line
while [ -n "${1:-}" ]; do
    case "$1" in
        -h | --help) help_message; graceful_exit ;;
        -*)
            usage
            error_exit "unknown option $1" ;;
        *)
            USERNAME="$1"
            ;;
    esac
    shift
done

[ -n "$USERNAME" ] || error_exit "usage: sh scripts/freebsd-adduser.sh <username>"

printf '\n  freebsd user bootstrap\n'
printf '  user: %s\n\n' "$USERNAME"

# ── create user if absent ─────────────────────────────────────────────────────
if id "$USERNAME" >/dev/null 2>&1; then
  ok "user $USERNAME already exists"
else
  # pw useradd: -m creates home dir, -s sets login shell, -G sets supplementary
  # groups at creation time. primary group is created automatically with the same
  # name as the user (FreeBSD convention).
  pw useradd "$USERNAME" \
    -m \
    -d "/home/$USERNAME" \
    -s /bin/sh \
    -c "$USERNAME"
  ok "created user $USERNAME (shell: /bin/sh, home: /home/$USERNAME)"
  warn "no password set – run:   passwd $USERNAME"
fi

# ── assign groups ─────────────────────────────────────────────────────────────
# wheel    - doas/privileges escalation; required for install.sh to run doas
# operator - shutdown, reboot, and some device access
# video    - DRM/KMS devices (/dev/dri/*); required for sway/Wayland
# webcamd  - webcam devices (/dev/video*); required for video capture
#
# /dev/input/event* on FreeBSD are owned by wheel (gid 0) with mode 0600.
# wheel membership covers input device access - no separate input group needed.

_GROUPS="wheel operator video webcamd"

for grp in $_GROUPS; do
  # check if the group exists on this system
  if ! grep -q "^${grp}:" /etc/group; then
    warn "group $grp not found in /etc/group - skipping"
    continue
  fi
  # check if user is already a member
  if id "$USERNAME" 2>/dev/null | grep -qw "$grp"; then
    ok "$USERNAME already in $grp"
  else
    pw groupmod "$grp" -m "$USERNAME"
    ok "added $USERNAME to $grp"
  fi
done

# ── summary ───────────────────────────────────────────────────────────────────
printf '\n'
info "final group membership:"
id "$USERNAME"
printf '\n'
ok "done - next steps:"
printf '    1. passwd %s           # set a password\n' "$USERNAME"
printf '    2. login as %s\n' "$USERNAME"
printf '    3. cd ~/dotfiles && sh install.sh   # stow packages + install doas\n'
printf '\n'

graceful_exit
