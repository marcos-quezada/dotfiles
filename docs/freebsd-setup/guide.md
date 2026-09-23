# FreeBSD Desktop Setup Guide — MSI PS42 8RB

A complete record of setting up FreeBSD 15.0-RELEASE as a Wayland desktop on
the MSI PS42 8RB laptop. Every value here is drawn directly from the running
system, not guessed.

---

## Hardware

| Component   | Detail                                          |
|-------------|-------------------------------------------------|
| CPU         | Intel Core i7-8550U (Kaby Lake, 4C/8T, 1.8 GHz) |
| RAM         | 8 GB                                            |
| Storage     | Kingston A1000 256 GB NVMe (`nda0`)             |
| Display GPU | Intel UHD Graphics 620 (`vgapci0`, device 5917) |
| Offload GPU | NVIDIA GeForce MX150 (`vgapci1`, device 1d10)   |
| Wi-Fi       | Intel Dual Band Wireless-AC 3168 (`iwlwifi0`)   |
| Audio       | Realtek ALC298 (HDA, `pcm0`/`pcm1`)             |
| Webcam      | SunplusIT HD Webcam (USB)                       |

---

## 1. Boot & Kernel — `/boot/loader.conf`

### Console resolution

Force UEFI GOP to 1080p so the VT console is full resolution from the first
frame, before any driver loads:

```text
efi_max_resolution="1080p"
kern.vt.fb.default_mode="1920x1080"
```

### Console font (boot-time)

The boot loader can display a custom font if it is placed in `/boot/fonts/`
and registered in `/boot/fonts/INDEX.fonts`. The `screen.font` key selects
it by the filename stem:

```text
screen.font=12x22
```

See [Section 6 — VT Console Font](#6-vt-console-font--uw-ttyp0) for how the
font is built and installed.

### Console colours

These two keys control the VT palette used during boot and in the raw console.
Values are ANSI colour indices (10 = bright green, 8 = dark grey):

```text
teken.fg_color="10"
teken.bg_color="8"
```

### Intel GPU firmware path

The `i915kms` driver (drm-66-kmod) looks for firmware under a Linux-style
path. The FreeBSD package ships a `.ko` wrapper but not the raw binary. The
raw binary must be placed manually:

```text
drm.i915.firmware_path="/boot/firmware"
```

The file itself lives at `/boot/firmware/i915/kbl_dmc_ver1_04.bin`.

**How to obtain it:**

```sh
cd /usr/ports/graphics/gpu-firmware-intel-kmod
make fetch extract
mkdir -p /boot/firmware/i915
cp work/kms-firmware-*/i915/kbl_dmc_ver1_04.bin /boot/firmware/i915/
```

Confirm it loaded correctly after reboot:

```sh
dmesg | grep -i dmc
# expect: drmn0: successfully loaded firmware image 'i915/kbl_dmc_ver1_04.bin'
```

### Intel GPU tuning

```text
drm.i915.enable_rc6="1"     # GPU render power gating
drm.i915.semaphores="1"     # inter-ring synchronisation
drm.i915.intel_iommu_enabled="0"  # avoid hangs with IOMMU on this board
```

### NVIDIA — kept compute-only, not KMS/DRM (see Section 4)

no `hw.nvidiadrm.modeset` tunable is set. this used to be documented here as
required (`hw.nvidiadrm.modeset=1`), but PRIME graphics offload doesn't
actually work on this machine — confirmed via a real kernel panic, see
Section 4 for the full investigation. only the base `nvidia` module loads
(via `kld_list` in Section 2), providing device nodes for future
CUDA/compute use without the DRM/KMS integration layer that's broken.

### Wi-Fi — blocklist legacy driver

The old `if_iwm` driver conflicts with the modern `if_iwlwifi` and tries to
load firmware before the filesystem is mounted:

```text
devmatch_blocklist="if_iwm iwm3168fw"
hw.iwlwifi.uapsd_disable=1
hw.iwlwifi.power_save=0
```

Power save is disabled here and managed instead via `sysctl` at runtime to
avoid `SIOCS80211` errors during association.

### Power & hardware tweaks

```text
hw.pci.do_power_nodriver="3"       # power down PCI devices with no driver
hint.p4tcc.0.disabled="1"          # disable legacy P4 throttling
hint.acpi_throttle.0.disabled="1"  # disable ACPI throttling (Speed Shift handles it)
hint.ahcich.0.pm_level="3"         # AHCI port power management (repeated for each port)
```

### Kernel limits (desktop usage)

```text
kern.maxproc="100000"
kern.ipc.shmseg="1024"
kern.ipc.shmmni="1024"
```

These are set in `loader.conf` rather than `sysctl.conf` because some Wayland
compositors and browsers check them at startup before `sysctl.conf` is applied.

### Filesystem & sound

```text
zfs_load="YES"
snd_hda_load="YES"        # note: trailing colon in the file is harmless but a typo
fuse_load="YES"
libiconv_load="YES"
cd9660_iconv_load="YES"
msdosfs_iconv_load="YES"
```

### Networking performance

```text
cc_htcp_load="YES"          # H-TCP: aggressive ramp-up, good for high-latency links
net.link.ifqmaxlen="2048"   # larger NIC transmit queue
```

### Miscellaneous

```text
autoboot_delay="2"          # shorter boot menu timeout
aesni_load="YES"            # hardware AES (speeds up TLS/ZFS encryption)
cpuctl_load="YES"           # CPU microcode updates
coretemp_load="YES"         # CPU temperature via sysctl
acpi_video_load="YES"       # backlight control via acpi_video(4)
acpi_wmi_load="YES"         # WMI bridge (MSI EC events)
cuse4bsd_load="YES"         # webcam support (cuse kernel interface)
hw.psm.trackpoint_support="1"
hw.psm.synaptics_support="1"
hw.snd.latency="5"
```

---

## 2. Services & Driver Order — `/etc/rc.conf`

### Driver load order

The order in `kld_list` matters. GPU firmware must precede the GPU driver:

```text
kld_list="if_iwlwifi i915_kbl_dmc_ver1_04_bin i915kms fusefs nvidia"
```

only the base `nvidia` module loads — `nvidia-drm`/`nvidia-modeset` are
deliberately excluded. see Section 4 for why (a confirmed, reproducible
kernel panic when Sway/`seatd` opens the NVIDIA DRM device).

### Wayland prerequisites

```text
seatd_enable="YES"    # seat management — required by sway
dbus_enable="YES"     # D-Bus session bus
```

### Networking

```text
wlans_iwlwifi0="wlan0"
ifconfig_wlan0="WPA DHCP"
ifconfig_wlan0_ipv6="inet6 accept_rtadv"
create_args_wlan0="country DE regdomain ETSI"
```

The `country` and `regdomain` args set the correct regulatory domain for
Germany. Wi-Fi credentials live in `/etc/wpa_supplicant.conf` (not in this
repo — contains PSK).

### Display manager

```text
lightdm_enable="NO"
```

Ly is used instead. See [Section 8 — Ly Display Manager](#8-ly-display-manager).

### USB automount

```text
autofs_enable="YES"
devfs_system_ruleset="localrules"
```

The devd rule that triggers `automount(8)` lives at
`/usr/local/etc/devd/automount_devd.conf`. It handles USB drives, SD cards,
and optical media:

```text
notify 100 {
    match "system"  "DEVFS";
    match "type"    "CREATE";
    match "cdev"    "(da|mmcsd|ugen)[0-9]+.*";
    action "/usr/local/sbin/automount $cdev attach &";
};
```

On attach, `automount` mounts the device under `/media/<label>` and (if
configured) opens the file manager.

### Other services

```text
sshd_enable="YES"
ntpd_enable="YES"
ntpd_sync_on_start="YES"
ntpd_flags="-g"          # allow large initial time jumps
avahi_daemon_enable="YES"
avahi_dnsconfig_enable="YES"   # mDNS / Zeroconf
hcsecd_enable="YES"            # Bluetooth key management
sdpd_enable="YES"              # Bluetooth SDP
cupsd_enable="YES"             # printing
webcamd_enable="YES"           # webcam (works in Firefox/Chromium)
wireguard_enable="YES"
wireguard_interfaces="wg0"
```

```text
# reduce noise
moused_nondefault_enable="NO"  # Wayland handles pointer natively
syslogd_flags="-ss"            # no network sockets
sendmail_enable="NONE"
dumpdev="NO"
```

`dumpdev` was temporarily set to a real device (`AUTO`, or an explicit
swap partition) once, to capture a kernel crash dump during the NVIDIA DRM
panic investigation (Section 4) — reverted back to `NO` afterward. worth
noting here so a future sighting of `dumpdev` set to something other than
`NO` in this file's history is understood as a deliberate, one-off
debugging step, not an accidental leftover.

### ZFS

```text
zfs_enable="YES"
```

No `/etc/fstab` ZFS entries needed. Root pool is `zroot/ROOT/default`. The
only `fstab` entries are the EFI partition and swap:

```text
/dev/gpt/efiboot0   /boot/efi   msdosfs   rw   2   2
/dev/nda0p3         none        swap      sw   0   0
```

---

## 3. Runtime Tuning — `/etc/sysctl.conf`

```text
vfs.zfs.vdev.min_auto_ashift=12   # align ZFS to 4K sectors (NVMe optimisation)
hw.acpi.lid_switch_state=S3       # suspend to RAM on lid close (Handbook 14.6.7.1)
```

Most of the values that are commonly put here (IPC shm, TCP algorithm, NIC
queue) are instead set in `loader.conf` so they apply before any service
starts. The H-TCP module is loaded via `cc_htcp_load="YES"` and activated
automatically as the default congestion control algorithm.

S4 (hibernate/suspend-to-disk) isn't supported by FreeBSD at all — S3 is the
only sleep state worth configuring here. Confirm this hardware actually
supports it first: `sysctl hw.acpi.supported_sleep_state`.

---

## 4. Graphics — Intel + NVIDIA (compute-available, PRIME offload not supported)

The desktop runs entirely on the Intel GPU (card0). The NVIDIA MX150 (card1)
is kept driver-available for future GPU-compute work (CUDA-style workloads),
but **PRIME render offload for graphics apps does not work** on this
machine/driver combination — confirmed via a real kernel panic, not assumed.
This section used to document PRIME offload as a working feature; it wasn't
actually verified end to end at the time, and it doesn't hold up.

### What was tried, and what was found

Switching to the correct driver branch for this GPU generation
(`nvidia-driver-580`/`nvidia-kmod-580`/`nvidia-drm-66-kmod-580` — the MX150
is Pascal-generation, dropped by the 595.x "production" branch this system
had installed) fixed the version-mismatch/unsupported-GPU errors, but
Sway/`seatd` opening the NVIDIA DRM device (`/dev/drm/1`) reliably triggers a
kernel page fault: `drm_stub_open` → `drm_release`, confirmed via a full
`kgdb` backtrace against a captured `vmcore` (not just the partial on-screen
scroll). Checked FreeBSD's bug tracker and forums for this exact
combination — nothing found; this looks like a genuinely under-tested
configuration (NVIDIA as a PRIME-offload *secondary* GPU under Sway),
unlike the more common NVIDIA-as-*primary*-GPU setups that do have real
working precedent on FreeBSD.

### The actual, current, verified state

`nvidia.ko` alone is loaded at boot (`nvidia-drm`/`nvidia-modeset` removed
from `kld_list`, `hw.nvidiadrm.modeset` removed from `loader.conf`) —
providing `/dev/nvidiactl`/`/dev/nvidia0` for future CUDA-toolkit use,
without needing the DRM/KMS integration layer that's actually broken.

confirmed directly, not assumed: even with `nvidia.ko` loaded, the DRM
device node (`/dev/drm/1`) still exists (this driver version registers it
as part of the same module, not a separately-loadable file the way the
package names suggest) — but Sway never opens it. verified via
`fstat -p <sway pid>`: Sway holds `/dev/drm/0` and `/dev/drm/128` open
(Intel's primary + render nodes), nothing NVIDIA-related. wlroots picked
Intel as its sole GPU and leaves the NVIDIA device alone entirely, which is
why normal daily use has never triggered the crash.

**what this means in practice:**

| use case | status |
|---|---|
| normal desktop use, Sway, all apps | safe — confirmed, Sway never touches the NVIDIA device |
| CUDA/GPU-compute workloads | should work — only needs `/dev/nvidiactl`/`/dev/nvidia0`, never touches DRM |
| `__NV_PRIME_RENDER_OFFLOAD=1` on a graphics app | **do not use** — opens `/dev/drm/1` directly, will very likely reproduce the same kernel panic |

### Verify both cards are visible

```sh
pciconf -lv | grep -A3 vgapci
# vgapci0 → Intel UHD 620 (8086:5917)  — primary, runs Wayland
# vgapci1 → NVIDIA MX150 (10de:1d10)   — compute-only, not used for display/offload
```

```sh
sysctl dev.drm
# dev.drm.0.PCI_ID: 8086:5917  (Intel, minor 0)
# dev.drm.1.PCI_ID: 10de:1d10  (NVIDIA, minor 1 — exists, but never opened by Sway)
```

---

## 5. Wi-Fi — `iwlwifi` vs `iwm`

The Intel 3168 is supported by two drivers. The modern `if_iwlwifi` is
preferred; the legacy `if_iwm` causes "Error 0" on this board because it
attempts firmware loading before the root filesystem mounts.

### Block the legacy driver

In `/boot/loader.conf`:

```text
devmatch_blocklist="if_iwm iwm3168fw"
```

### Firmware package

```sh
pkg install wifi-firmware-iwlwifi-kmod
```

The firmware (`iwlwifi-3168-29.ucode`) is confirmed loaded in `dmesg`:

```
iwlwifi0: successfully loaded firmware image 'iwlwifi-3168-29.ucode'
iwlwifi0: loaded firmware version 29.0bd893f3.0
```

### Power save

Managed at runtime rather than in `loader.conf` to avoid association errors:

```sh
sysctl dev.iwlwifi.0.power_save=1
```

---

## 6. VT Console Font — uw-ttyp0

`uw-ttyp0` is a monospace bitmap screen font by Dr. Uwe Waldmann
(<https://people.mpi-inf.mpg.de/~uwe/misc/uw-ttyp0/>). It supports a large
Unicode range and comes as a pre-built `.fnt` binary for several size/variant
combinations — no ports build or `vtfontcvt(8)` required.

The font is committed to this repo as `vt/boot/fonts/12x22.fnt.gz`. The `vt`
stow package uses `--target=/` (requires `doas`/`sudo`) to place files under
`/boot/fonts/`.

### Install steps

1. Download the pre-built `.fnt` file from the author's page (the `ttyp0`
   distribution includes ready-to-use bitmap fonts in multiple sizes).

2. Rename to match the glyph dimensions. The 12×22 variant was chosen here:

   ```sh
   mv uw-ttyp0-<variant>.fnt 12x22.fnt
   ```

3. Gzip it — the FreeBSD loader requires compressed fonts in `/boot/fonts/`:

   ```sh
   gzip 12x22.fnt          # produces 12x22.fnt.gz
   ```

4. Copy to `/boot/fonts/` (root-owned):

   ```sh
   doas cp 12x22.fnt.gz /boot/fonts/
   ```

5. Register the font in `/boot/fonts/INDEX.fonts` so the loader and
   `vidfont(8)` can find it. Add these three lines (matching the filename stem
   `12x22`):

   ```text
   12x22.fnt:en:UW ttyp0 BSD Console, size 22
   12x22.fnt:da:UW ttyp0 BSD-konsol, størrelse 22
   12x22.fnt:de:UW ttyp0 BSD Console, Größe 22
   ```

6. Select it in `/boot/loader.conf`:

   ```text
   screen.font=12x22
   ```

   The key is the filename stem without `.fnt`. This takes effect from the
   very first loader frame — before the kernel loads.

   Alternatively, install the whole `vt` stow package from this repo:

   ```sh
   doas stow --dir=~/dotfiles --target=/ --restow vt
   # or: sh ~/dotfiles/install.sh  (prompts for vt)
   ```

### Colours

The VT colour palette is controlled by two `loader.conf` keys. They apply both
during the boot loader phase and in the VT console after the kernel takes over:

```text
teken.fg_color="10"   # bright green (ANSI colour index 10)
teken.bg_color="8"    # dark grey    (ANSI colour index 8)
```

The bright-green-on-dark-grey combination matches the Gameboy DMG palette used
in `foot.ini`, so the console and terminal feel visually consistent.

> **Reference:** The FreeBSD Forums thread
> [*The gallant console font got supercharged*](https://forums.freebsd.org/threads/the-gallant-console-font-got-supercharged.99074/post-715734)
> documents the exact procedure for placing pre-built `.fnt.gz` fonts in
> `/boot/fonts/` and registering them for loader-time use.

---

## 7. Desktop Environment — Sway + Wayland

### Session startup

Sway is launched by Ly (see [Section 8](#8-ly-display-manager)). The config
is managed via this dotfiles repository and stowed to `~/.config/sway/config`.

Key settings:

| Setting       | Value                                      |
|---------------|--------------------------------------------|
| Modifier      | Super (Mod4)                               |
| Direction keys| vim-style h/j/k/l                          |
| Terminal      | `foot`                                     |
| Launcher      | `wmenu-run`                                |
| Keyboard      | `de` layout, `evdev` rules                 |
| Touchpad      | tap enabled, dwt, middle emulation         |
| Bar           | `quickshell` (launched via `exec quickshell`) |
| Idle lock     | `swaylock` at 300 s idle, DPMS off at 600 s |

### Media keys

Audio is handled by `mixer(8)` (FreeBSD base system, OSS). Brightness is
handled by `backlight(8)` (base system, requires `acpi_video_load="YES"` in
`loader.conf`). These are bound to the hardware keys in `sway/config`:

| Key | Command |
|-----|---------|
| `XF86AudioMute` | `mixer vol.mute toggle` |
| `XF86AudioLowerVolume` | `mixer vol -5` |
| `XF86AudioRaiseVolume` | `mixer vol +5` |
| `XF86AudioMicMute` | `mixer mic.mute toggle` |
| `XF86MonBrightnessDown` | `backlight - 10%` |
| `XF86MonBrightnessUp` | `backlight + 10%` |

> If you migrate to pipewire-pulse in future, replace the `mixer` calls with
> `pactl set-sink-{mute,volume}` and update `sway/config` accordingly.

### Wallpaper

Downloaded from Vermaden's FreeBSD wallpaper collection:
<https://vermaden.wordpress.com/2023/10/04/freebsd-unix-wallpapers/>

Committed to this repo at `sway/walls/freebsd-kilmynda-wide.png`. Stowing the
`sway` package places it at `~/walls/freebsd-kilmynda-wide.png`, which matches
the sway config reference:

```text
output * bg ~/walls/freebsd-kilmynda-wide.png stretch
```

### Wayland IPC / shared memory

These values are set in `loader.conf` rather than `sysctl.conf` so they are
available before any compositor starts:

```text
kern.ipc.shmseg="1024"
kern.ipc.shmmni="1024"
```

### PRIME offload from Sway — not supported, do not use

```sh
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia foot
```

this was previously documented here as a working feature. it isn't —
confirmed via a real kernel panic (`drm_stub_open` → `drm_release` page
fault) when something opens the NVIDIA DRM device. see Section 4 for the
full investigation and the actual, verified current state (NVIDIA kept
available for compute workloads only, not graphics offload).

---

## 8. Ly Display Manager

Ly is a lightweight TUI display manager. It handles session selection and
PAM authentication, then execs the chosen session (Sway).

### Install — built from a fork, pinned to a specific commit and Zig version

not installed via `pkg` — built from source, from this project's own fork
of upstream `ly` (`github.com/fairyglade/ly`, itself a live, kept-in-sync
mirror of the real upstream on Codeberg). the fork lives at
`github.com/marcos-quezada/ly`, branch `freebsd-1.4.0-working`.

this specific commit/branch/build combination was arrived at after an
extensive investigation, not chosen arbitrarily — see "why this exact
combination" below before changing any part of it.

**prerequisite — a pinned Zig version, not the current default:**

```sh
doas pkg install zig015
```

the currently-`pkg`-installed default `zig` (0.16) has real, breaking API
changes vs. what this era of `ly` expects — confirmed two separate ways
(a `build.zig` compile error on a removed `std.process.SpawnOptions.StdIo`
variant, and a missing-argument compile error in a different code path).
`zig015` installs as a separate, version-suffixed binary — it does not
replace or conflict with the default `zig`.

**build and install:**

```sh
git clone git@github.com:marcos-quezada/ly.git ~/ly
cd ~/ly
git checkout freebsd-1.4.0-working
zig015 build -Dprefix_directory=/usr/local -Dconfig_directory=/usr/local/etc -Dinit_system=freebsd
doas zig015 build installnoconf -Dprefix_directory=/usr/local -Dconfig_directory=/usr/local/etc -Dinit_system=freebsd
```

`installnoconf` (not `installexe`) is deliberate — `installexe` installs a
fresh default config file every time, silently overwriting any existing
customised one. `installnoconf` only installs the binary and init-system
service files, leaving whatever's already at `/usr/local/etc/ly/config.ini`
untouched.

**do not pass `-Denable_x11_support=false`** even though this is a
Wayland-only setup — that flag triggers a genuine, pre-existing compile
bug in this specific commit's x11-disabled code path (a missing function
argument). the X11-session-crawl warning this flag would have silenced is
handled separately instead:

```sh
doas mkdir -p /usr/local/share/xsessions /usr/local/etc/ly/custom-sessions
```
(empty directories are enough — `ly` crawls them for `.desktop` files and
just finds none, no error)

the wrapper script and PAM config also need installing manually — `zig
build` doesn't handle these two FreeBSD-specific extras on its own (this
matches what the FreeBSD port's own `post-install` step does):

```sh
sed 's,$PREFIX_DIRECTORY,/usr/local,g; s,$EXECUTABLE_NAME,ly,g' res/ly-freebsd-wrapper | doas tee /usr/local/bin/ly_wrapper >/dev/null
doas chmod +x /usr/local/bin/ly_wrapper
doas install -m 644 res/pam.d/ly-freebsd /usr/local/etc/pam.d/ly
```

### Why this exact combination — a real bug, not a preference

current upstream `ly` (and every commit tested between `v1.4.1` and
current `master`, roughly 100 commits) has a real, reproducible bug on
this FreeBSD setup: after authenticating, the session (Sway *or* a plain
shell, doesn't matter which) launches, then immediately bounces back to
the Ly prompt — `Ctrl-C` followed by logging in again is needed to
actually reach a usable session.

bisected extensively (both by testing specific upstream-linked TTY/session
commits, e.g. the chown/chmod TTY rework from issue `#944`, and by binary
search across the full `v1.4.1`→`master` commit range) without finding a
single commit boundary — the bug was present at every point tested. that
ruled out "a specific `ly` commit regression" as the explanation.

the actual working combination (`0d887ef`, Zig `0.15.2`, X11 support left
at its default) was found by returning to the exact commit this project's
original, already-working install had been built from (confirmed via
`git reflog`, not guessed), and removing every unrelated variable that had
accumulated during testing (a newer Zig compiler, `-Denable_x11_support=false`).
that combination has zero reported session-bounce issues. the exact
responsible variable (Zig compiler version vs. the X11 flag) was **not**
fully isolated — deferred, see `ly-fork-freebsd-fixes`'s task list.

consequence of pinning to this commit: it predates upstream's Lua-based
config format entirely, so this setup uses the older, still fully-supported
`config.ini` format, not Lua. a Lua migration was done and worked correctly
in isolation, but had to be abandoned for now since it isn't compatible
with the one commit that's actually confirmed to work correctly.

### Enable — `/etc/gettytab` and `/etc/ttys`

On FreeBSD, ly is not started by an rc service. Instead, `init(8)` invokes
it through the standard `getty(8)` mechanism. Two files must be edited.

**1. Add an entry to `/etc/gettytab`:**

```text
Ly:\
	:lo=/usr/local/bin/ly_wrapper:\
	:al=root:
```

**2. Replace the getty command on `ttyv1` in `/etc/ttys`:**

```text
ttyv1  "/usr/libexec/getty Ly"  xterm  on  secure
```

`ttyv1` is the second virtual console (FreeBSD TTYs start at `ttyv0`).
After this change, `init` will run `ly_wrapper` on `ttyv1` instead of the
standard login prompt. A reboot (or `kill -HUP 1`) is needed for the
`ttys` change to take effect.

> If the login screen does not appear after reboot, switch to `ttyv1`
> with **Alt+F2**. If Ly is running on `ttyv0` instead, use **Alt+F1**.

`seatd` must also be running before the session starts:

```text
seatd_enable="YES"   # in /etc/rc.conf — must start before the first login
```

### Configuration

Config lives at `/usr/local/etc/ly/config.ini`, tracked and stowed via this
repo's `ly` package (`ly/usr/local/etc/ly/config.ini`). Key customisations
on this machine:

| Key | Value | Effect |
|-----|-------|--------|
| `animation` | `matrix` | CMatrix rain plays on the login screen |
| `bigclock` | `en` | Large ASCII clock shown in English |
| `battery_id` | `BAT0` | Battery percentage shown top-left, via this fork's FreeBSD `sysctlbyname` patch |
| `lang` | `de` | German locale for UI strings |
| `full_color` | `true` | 24-bit colour in the TUI |
| `vi_mode` | `false` | Standard keybindings (not vi) |
| `waylandsessions` | `/usr/local/share/wayland-sessions` | Where Ly looks for `.desktop` session files; picks up sway automatically |
| `brightness_down_cmd` | `/usr/bin/backlight -q - 10%` | Invoked by F5 |
| `brightness_up_cmd` | `/usr/bin/backlight -q + 10%` | Invoked by F6 |
| `cmatrix_fg` | `0x0000FF00` | Matrix rain colour — green |
| `cmatrix_head_col` | `0x01FFFFFF` | Matrix head character — bold white (`0x01` = `TB_BOLD`) |
| `shutdown_key` | `F1` | `/sbin/shutdown -p now` |
| `restart_key` | `F2` | `/sbin/shutdown -r now` |
| `save` | `true` | Last-used session and login saved across reboots |

---

## 9. USB Automount

Uses the `automount` port together with a custom devd rule.

### Packages

```sh
pkg install automount
```

### devd rule

`/usr/local/etc/devd/automount_devd.conf` — triggers on DEVFS CREATE/DESTROY
events for USB mass storage (`da*`), SD cards (`mmcsd*`), and optical media
(`cd*`):

```text
notify 100 {
    match "system"  "DEVFS";
    match "type"    "CREATE";
    match "cdev"    "(da|mmcsd|ugen)[0-9]+.*";
    action "/usr/local/sbin/automount $cdev attach &";
};

notify 100 {
    match "system"  "DEVFS";
    match "type"    "DESTROY";
    match "cdev"    "(da|mmcsd|ugen)[0-9]+.*";
    action "/usr/local/sbin/automount $cdev detach &";
};
```

The `autofs_enable="YES"` and `devfs_system_ruleset="localrules"` entries in
`rc.conf` are prerequisites.

---

## 10. Bluetooth

```text
hcsecd_enable="YES"   # key/PIN management
sdpd_enable="YES"     # Service Discovery Protocol daemon
```

The `ng_ubt` and `netgraph` modules load automatically via devd when a
Bluetooth adapter is detected (confirmed in `kldstat`).

---

## 11. Printing — CUPS

```sh
pkg install cups
```

```text
cupsd_enable="YES"
```

A custom devd rule at `/usr/local/etc/devd/cups.conf` handles USB printer
attach/detach events (installed by the CUPS package).

---

## 12. Webcam

```sh
pkg install webcamd
```

```text
webcamd_enable="YES"
cuse4bsd_load="YES"   # in loader.conf
```

The SunplusIT HD Webcam is detected as `ugen0.4` and works in Firefox and
Chromium without additional configuration.

---

## 13. Hardware Security — U2F / FIDO2

```sh
pkg install libfido2 u2f-devd
```

The `u2f-devd` package drops `/usr/local/etc/devd/u2f.conf`, which grants the
current user read/write access to the FIDO2 device node when it is plugged in.
No additional PAM configuration is needed for browser-based WebAuthn.

The Synaptics fingerprint reader (`ugen0.3`, vendor 06cb) is present but has
no FreeBSD driver support at this time.

---

## 14. Package List

Full list of explicitly installed packages (`pkg prime-list`):

> note: this snapshot predates the NVIDIA driver-branch switch in Section 4
> (`nvidia-drm-66-kmod`/`nvidia-kmod` at 595.x → `nvidia-driver-580`/
> `nvidia-kmod-580`/`nvidia-drm-66-kmod-580`, plus `egl-wayland`/
> `egl-wayland2`/`egl-x11`/`xorg-server` pulled in as real dependencies of
> `nvidia-driver-580`). worth a fresh `pkg prime-list` next time this section
> is touched, rather than hand-patching individual known-stale entries.

```
ImageMagick7        bat                 ca_root_nss
cli11               cmake               dmenu
dmenu-wayland       dmidecode           doas
drm-66-kmod         en-freebsd-doc      feh
firefox             focuswriter         foot
git                 gmake               gpu-firmware-intel-kmod-kabylake
jq                  libfido2            maim
neovim              nerd-fonts          ninja
noto-emoji          nss_mdns            nvidia-drm-66-kmod
pkg                 pkgconf             qt6-base
qt6-declarative     qt6-shadertools     qt6-wayland
quickshell          rust                sakura
seatd               spleen-font         stow
sway                swayidle            swaylock-effects
u2f-devd            vim                 w3m
webcamd             wifi-firmware-iwlwifi-kmod  wireguard-tools
xclip               xdg-desktop-portal  xinit
xkbcomp             xkeyboard-config    zig
automount
```

---

## 15. Known Issues & Notes

| Issue | Status |
|-------|--------|
| ACPI EC errors at boot (`No handler for Region [EC__]`) | Cosmetic, confirmed — `apm -l`, `acpiconf -i0`, and `sysctl hw.acpi.battery.life` all report consistent, correct battery data (capacity, voltage, remaining time, percentage) despite these boot-time errors; EC is fully functional at runtime |
| `hdac0: Command timeout on address 2` in dmesg | Intermittent; audio works correctly. Confirmed as [FreeBSD bug 229190](https://bugs.freebsd.org/229190) — widely shared across many Intel Kaby Lake/Cannon Lake laptops (address 2 is the Intel HDMI/DP audio codec, `hdacc1`, not the Realtek ALC298 at address 0). marked "Closed FIXED" upstream, but the actual linked commits only improved diagnostic logging (showing which command timed out / which codec isn't responding), not a functional fix. one FreeBSD committer's working theory: likely an `i915kms` power-management interaction — the HDMI codec sits behind the display driver's own port power state, and legitimately times out when no external display is connected (the normal case here). no actionable fix exists upstream as of this writing |
| Synaptics fingerprint reader (`06cb:009b`) | No FreeBSD driver; unsupported |
| `atrtc0: Warning: Couldn't map I/O` | Known, harmless — confirmed as [FreeBSD bug 207677](https://bugs.freebsd.org/207677) ("atrtc should be rewritten with ACPI: harmless warning"), a long-standing limitation of the legacy `atrtc` driver predating proper ACPI resource enumeration. RTC still registers and works correctly immediately after this warning |
| `WARNING: Device "psm" is Giant locked and may be deleted before FreeBSD 16.0.` | Informational, not an error — forward-compatibility notice about the PS/2 touchpad driver possibly being removed in FreeBSD 16.0. nothing to fix; worth knowing before the next major upgrade |
| `tmpfs` double-register warning at boot | **Fixed** — removed redundant `tmpfs_load="YES"` from `loader.conf`; `GENERIC` already compiles `tmpfs` in, the explicit module load was racing against that and failing every boot |
| `pci0: <simple comms>` (Intel ME, device 22.0) | No driver attached; expected and harmless |
| Sway startup flashes a red `eglQueryDeviceStringEXT`/`EGL_BAD_PARAMETER` message | Cosmetic — confirmed via wlroots' own source (`render/egl.c`): this is part of the normal device-matching loop that queries *every* EGL device to find the one matching wlroots' already-selected (Intel-only) DRM device; on failure the code does `continue` and moves on, exactly as designed — wlroots just logs it at `ERROR` level even though it's an expected, handled outcome. `WLR_DRM_DEVICES` was tried as a possible fix and reverted — it restricts the DRM *backend*'s device selection, but this query happens in a separate EGL device-matching path that isn't affected by it. no wlroots env var controls this (checked the full list). not fixable without patching wlroots' log level or hiding the NVIDIA EGL device from the system entirely (higher-risk, not pursued). **deferred**: wanted to independently confirm this predates the NVIDIA driver-branch fix by booting `pre-nvidia-fix` and checking, but that boot environment reverts *everything* from today's work (NVIDIA fix, tmpfs fix, ly fixes), not just Sway's behavior — decided the cost wasn't worth it given the source-level confirmation is already solid; revisit later if there's ever a cheaper way to check (e.g. a dedicated, narrower snapshot next time, rather than reusing one that predates too much else) |

---

## 16. Safe Upgrade Workflow — ZFS Boot Environments

Root is ZFS (`zroot/ROOT/default`), so every package/OS upgrade has a real,
cheap safety net via `bectl(8)` — confirmed available on this machine
(`bectl list` returns a real table). This isn't optional insurance to skip
when in a hurry: on package-based FreeBSD 15.x, `pkg upgrade` does **not**
create a boot environment automatically the way 14's `freebsd-update` used
to — it has to be a deliberate, remembered step every time.

### Before any `pkg upgrade` (patch-level or point-release)

```sh
doas bectl create <name>
doas pkg upgrade
```

no `-r` (recursive) flag is needed here — this machine uses the "shallow"
boot environment layout (`bectl(8)`'s own term): `/home` lives on its own
sibling dataset (`zroot/home/mquezada`), not nested under
`zroot/ROOT/default`, so a plain `bectl create` already captures the full
root boot environment correctly. `-r` is specifically for "deep" layouts
with subordinate datasets nested under the boot environment itself — not
this machine's layout, confirmed via `bectl(8)`'s own documented examples.

### Naming convention

two shapes, matching what's already naturally present on this machine
(auto-generated boot environments from past upgrades already look like
`15.1-RELEASE-p3_2026-08-26_124152`) and `bectl(8)`'s own manual page
example (`bectl create -r \`date +%Y%m%d\``):

- **routine, no specific concern** — before a regular `pkg upgrade`: plain
  date, e.g. `20260922`
- **deliberate, tied to a specific risky change** — descriptive name, e.g.
  `pre-nvidia-fix` (as already used today). these are worth keeping longer
  than routine dated ones, as an explicit safety net for that specific change

### Rollback

two ways, depending on whether the system is still bootable normally:

- **from the boot loader menu**: select the prior boot environment directly
  at boot — works even if the current one is broken enough that you can't
  get a shell
- **from a working shell**: `doas bectl activate <name>` then reboot

### Retention — manual review, not automated pruning

boot environments consume real disk space (`bectl list` showed one old
auto-generated environment at 437 MB) and `bectl` has no automatic
expiry — checked the man page, nothing built-in prunes old environments on
a schedule. the practical approach here: review `bectl list` periodically
(a natural time is right before creating a new one for the next upgrade),
and `bectl destroy <name>` anything no longer needed. **no automated
pruning script** — deliberately not built, for the same reason no wrapper
script exists for the create/upgrade step itself (see below): a script
destroying boot environments unattended needs real scrutiny before being
added just for convenience, and the actual frequency of this task (around
upgrades, not continuously) doesn't justify the risk.

### Why no wrapper script

a script automating `bectl create` + `pkg upgrade` + reboot was considered
and deliberately not built. two commands run manually, in order, with a
chance to actually look at the output between them, is safer than a script
that has to correctly handle every partial-failure case (what if `bectl
create` succeeds but `pkg upgrade` fails partway through? what if the
reboot should NOT happen automatically because something looked wrong?) —
same reasoning as this project's other boot-critical-file decisions:
convenience isn't worth the risk here.

---

## References

- [FreeBSD Handbook — Graphics (DRM/KMS)](https://docs.freebsd.org/en/books/handbook/x11/)
- [FreeBSD Forums — The gallant console font got supercharged](https://forums.freebsd.org/threads/the-gallant-console-font-got-supercharged.99074/)
- [UW ttyp0 Monospace Bitmap Fonts](https://people.mpi-inf.mpg.de/~uwe/misc/uw-ttyp0/)
- [Vermaden — FreeBSD Unix Wallpapers](https://vermaden.wordpress.com/2023/10/04/freebsd-unix-wallpapers/)
- [FreeBSD Ports — graphics/drm-66-kmod](https://www.freshports.org/graphics/drm-66-kmod)
- [FreeBSD Ports — graphics/gpu-firmware-intel-kmod](https://www.freshports.org/graphics/gpu-firmware-intel-kmod)
- Man pages: `fwget(8)`, `backlight(8)`, `loader.conf(5)`, `vtfontcvt(8)`, `automount(8)`, `devd.conf(5)`
