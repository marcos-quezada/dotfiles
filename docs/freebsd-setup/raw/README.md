# FreeBSD Setup — Raw Source Files

Drop files collected from the FreeBSD machine into this directory,
then commit and push. The guide will be assembled from these.

Files can be added in any order. Once everything listed below is present,
the final guide will be written to `docs/freebsd-setup/guide.md`.

---

## System configuration files

Copy these verbatim. No need to redact anything unless there are passwords.

| File on the machine          | Save as here                     |
|------------------------------|----------------------------------|
| `/boot/loader.conf`          | `loader.conf`                    |
| `/etc/rc.conf`               | `rc.conf`                        |
| `/etc/sysctl.conf`           | `sysctl.conf`                    |
| `/etc/fstab`                 | `fstab`                          |
| `/etc/devd.conf` (if edited) | `devd.conf`                      |
| `/etc/login.conf` (if edited)| `login.conf`                     |

---

## Command outputs

Run each command and save the output as the filename shown.

```sh
# installed packages (explicitly installed only, no auto-deps)
pkg prime-list > pkg-prime-list.txt

# kernel modules currently loaded
kldstat > kldstat.txt

# dmesg — useful for GPU firmware load confirmation and ACPI noise
dmesg > dmesg.txt

# PCI devices — confirms Intel + NVIDIA cards are visible
pciconf -lv > pciconf.txt

# ACPI battery / thermal zones
sysctl hw.acpi > sysctl-hw-acpi.txt

# DRM / GPU info
sysctl dev.drm > sysctl-dev-drm.txt 2>/dev/null || true
sysctl dev.vgapci > sysctl-dev-vgapci.txt 2>/dev/null || true

# active Wayland compositor check
swaymsg -t get_version > swaymsg-version.txt 2>/dev/null || true
```

---

## Fonts

If you installed `uw-ttyp0` from a port or by hand, note the path:

```sh
find /usr/local/share/fonts /usr/share/fonts -name "*ttyp0*" 2>/dev/null > font-paths.txt
# also capture whatever allscreens_flags is set to (usually in rc.conf already)
```

---

## Optional but useful

These help document the Optimus / PRIME offload setup and any devd rules
you may have written for lid-close or backlight events.

```sh
# any custom devd rules you created
ls /usr/local/etc/devd/ > devd-local-list.txt
# copy any custom .conf files from there alongside this

# backlight state
backlight 2>/dev/null > backlight.txt || true

# check which card is rendering
glxinfo 2>/dev/null | grep "OpenGL renderer" > glxinfo-renderer.txt || true
```

---

## What NOT to include

- `/etc/wpa_supplicant.conf` — contains Wi-Fi PSK, keep it off git
- Any file under `~/.gnupg/`, `~/.ssh/`
- `/etc/pwd.db`, `/etc/master.passwd`
