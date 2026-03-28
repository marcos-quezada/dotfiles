# staging/

drop output files here. the installer and setup scripts will read from this
directory so nothing sensitive ever has to be typed inline.

this directory is in .gitignore — nothing here is ever committed.

---

## freebsd initial setup — what we need from your running system

run each command below on your FreeBSD machine (as root or with doas/sudo)
and paste the output into the matching file in this directory.

---

### 1. current user and group memberships

**file:** `staging/id.txt`

```sh
id
```

shows your uid, primary gid, and every supplementary group you are already in.
we need this to know what groups exist and which ones your user already has.

---

### 2. full group database entries for relevant groups

**file:** `staging/groups.txt`

```sh
grep -E '^(wheel|operator|video|input|_shutdown|webcamd|cups|dialer|network|audio):' /etc/group
```

shows the gid and current member list for each group we care about.
paste the full output — groups that don't exist on your system will simply
produce no output for that name, which is fine.

---

### 3. existing doas.conf (if any)

**file:** `staging/doas.conf.current`

```sh
cat /usr/local/etc/doas.conf 2>/dev/null || echo "not installed"
```

if doas is already installed and configured, paste the existing config so we
don't overwrite rules you rely on.

---

### 4. installed privilege escalation tools

**file:** `staging/priv.txt`

```sh
which doas 2>/dev/null || echo "doas: not found"
which sudo 2>/dev/null || echo "sudo: not found"
pkg info -e doas && echo "doas pkg: installed" || echo "doas pkg: not installed"
pkg info -e sudo && echo "sudo pkg: installed" || echo "sudo pkg: not installed"
```

tells us whether doas is already installed via pkg, or only sudo, or neither.

---

### 5. your username

**file:** `staging/username.txt`

```sh
whoami
```

just your login name. used to template the doas.conf permit line and the
pw useradd / pw groupmod commands.

---

### 6. video / drm group membership (Wayland/sway prerequisite)

**file:** `staging/video.txt`

```sh
ls -la /dev/dri/ 2>/dev/null || echo "/dev/dri not present"
ls -la /dev/video* 2>/dev/null || echo "no /dev/video* devices"
stat -f '%g %p %N' /dev/dri/card* /dev/dri/renderD* 2>/dev/null
```

wayland compositors (sway) need access to DRM devices. the owning group
determines which group the user must be in. on FreeBSD this is usually `video`
(gid 44) but varies by kernel config.

---

### 7. input devices group

**file:** `staging/input.txt`

```sh
ls -la /dev/input/ 2>/dev/null || echo "/dev/input not present"
stat -f '%g %p %N' /dev/input/event* 2>/dev/null || echo "no input event devices"
```

sway also needs read access to input event devices. the owning group is
typically `input` or `wheel` on FreeBSD.

---

### 8. rc.conf relevant lines (for context)

**file:** `staging/rc.conf.txt`

```sh
grep -E '(dbus|polkit|seatd|elogind|hald|devd|moused|kld|linux)' /etc/rc.conf 2>/dev/null || echo "no matching lines"
```

shows which daemons are enabled. seatd or elogind is required for unprivileged
wayland sessions. knowing what's running avoids suggesting redundant setup steps.

---

## after you drop these files

once all eight files are in `staging/`, say so and we will:

1. write `scripts/freebsd-adduser.sh` — idempotent root script that creates
   the user, assigns groups, and sets /bin/sh as the login shell
2. add doas install + config to `install.sh` (idempotent, FreeBSD only)
3. write `docs/freebsd-setup/user-setup.md` with the full bootstrap sequence
