# freebsd user setup

bootstrap sequence for creating your user account on a fresh FreeBSD install
before `install.sh` can be run. run everything in this file as root.

---

## context

`install.sh` runs as the target user. on a fresh install only `root` exists.
this document covers the gap: creating the user, assigning groups, and setting
a password so the user can log in and run the installer.

doas is handled separately — see [doas](#doas) below.

---

## 1. create the user

```sh
sh ~/dotfiles/scripts/freebsd-adduser.sh <username>
```

the script is idempotent — safe to run again if the user already exists or
already belongs to some groups. it will skip any step that is already done.

what it sets:
- login shell: `/bin/sh` (`.profile` + `.shrc` are in the dotfiles)
- home: `/home/<username>`
- groups: `wheel`, `operator`, `video`, `webcamd`

### why these groups

| group | gid | reason |
|---|---|---|
| `wheel` | 0 | doas privilege escalation; `/dev/input/event*` access (gid 0, mode 0600) |
| `operator` | 5 | shutdown/reboot via `shutdown(8)`; some device access |
| `video` | 44 | DRM/KMS devices (`/dev/dri/*`); required for sway/Wayland |
| `webcamd` | 145 | webcam devices (`/dev/video*`); required for webcamd(8) |

**input devices note:** on this machine `/dev/input/event*` are owned by
`wheel` (gid 0) with mode `0600`. there is no separate `input` group. wheel
membership is sufficient — no extra group is needed for sway input.

---

## 2. set a password

```sh
passwd <username>
```

---

## 3. doas

doas should already be installed on the running system (`pkg info -e doas`).
if it is not, install it before the user tries to log in:

```sh
pkg install -y doas
```

the config at `/usr/local/etc/doas.conf` allows the wheel group to escalate
with a cached credential (one password prompt per session):

```
permit persist :wheel
```

if the file does not exist yet:

```sh
printf 'permit persist :wheel\n' > /usr/local/etc/doas.conf
chmod 640 /usr/local/etc/doas.conf
```

`install.sh` checks for doas and its config on FreeBSD and will prompt to
create the config if it is missing — but having it in place before the first
login makes the bootstrap smoother.

---

## 4. log in and run the installer

```sh
# from root, or reboot and log in directly
login <username>

# clone the dotfiles if not already present
git clone git@github.com:marcos-quezada/dotfiles.git ~/dotfiles

# run the installer
sh ~/dotfiles/install.sh
```

the installer will stow packages, check core dependencies, and prompt for
optional ones. on FreeBSD it will also verify doas is configured correctly.

---

## reference: group membership on this machine

observed on auryn (MSI PS42 8RB, FreeBSD 15.0):

```
uid=1001(mquezada) gid=1001(mquezada)
groups=0(wheel),5(operator),44(video),116(u2f),145(webcamd),1001(mquezada)
```

the `u2f` group (gid 116) is added automatically by the `u2f-devd` package
via its devd rules when a FIDO2 key is plugged in — no manual `pw groupmod`
needed for that one.
