#!/bin/sh
# scripts/freebsd-adduser.sh — bootstrap a new user on a fresh FreeBSD install
# run as root before install.sh
# usage: sh scripts/freebsd-adduser.sh <username>
#
# what it does:
#   - creates the user with /bin/sh login shell and /home/<user> home dir
#   - assigns required groups: wheel, operator, video, webcamd
#   - skips groups the user already belongs to (idempotent)
#   - does NOT set a password — run passwd <user> after this script
#   - does NOT install doas — run install.sh as the new user for that

set -e

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'; RST='\033[0m'
ok()   { printf "${GRN}  ✔${RST} %s\n" "$*"; }
info() { printf "${BLU}  ·${RST} %s\n" "$*"; }
warn() { printf "${YLW}  ⚠${RST} %s\n" "$*"; }
die()  { printf "${RED}  ✘${RST} %s\n" "$*" >&2; exit 1; }

# ── require root ──────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "must run as root"

# ── argument ──────────────────────────────────────────────────────────────────
USERNAME="${1:-}"
[ -n "$USERNAME" ] || die "usage: sh scripts/freebsd-adduser.sh <username>"

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
    warn "no password set — run:  passwd $USERNAME"
fi

# ── assign groups ─────────────────────────────────────────────────────────────
# wheel    — doas/privilege escalation; required for install.sh to run doas
# operator — shutdown, reboot, and some device access
# video    — DRM/KMS devices (/dev/dri/*); required for sway/Wayland
# webcamd  — webcam devices (/dev/video*); required for video capture
#
# /dev/input/event* on FreeBSD are owned by wheel (gid 0) with mode 0600.
# wheel membership covers input device access — no separate input group needed.

_GROUPS="wheel operator video webcamd"

for grp in $_GROUPS; do
    # check if the group exists on this system
    if ! grep -q "^${grp}:" /etc/group; then
        warn "group $grp not found in /etc/group — skipping"
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
ok "done — next steps:"
printf '    1. passwd %s           # set a password\n' "$USERNAME"
printf '    2. login as %s\n' "$USERNAME"
printf '    3. cd ~/dotfiles && sh install.sh   # stow packages + install doas\n'
printf '\n'
