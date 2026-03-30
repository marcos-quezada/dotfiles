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

### NVIDIA KMS

```text
hw.nvidiadrm.modeset=1
```

Must be set in `loader.conf` (not `rc.conf`) so it is visible before the
kernel module is loaded.

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
tmpfs_load="YES"
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

The order in `kld_list` matters. GPU firmware must precede the GPU driver,
and NVIDIA modeset must load before the desktop starts:

```text
kld_list="if_iwlwifi i915_kbl_dmc_ver1_04_bin i915kms nvidia-drm fusefs nvidia-modeset"
```

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
```

Most of the values that are commonly put here (IPC shm, TCP algorithm, NIC
queue) are instead set in `loader.conf` so they apply before any service
starts. The H-TCP module is loaded via `cc_htcp_load="YES"` and activated
automatically as the default congestion control algorithm.

---

## 4. Graphics — Intel + NVIDIA Optimus (Headless Hybrid)

The desktop runs entirely on the Intel GPU (card0). The NVIDIA MX150 (card1)
is available for offloading specific applications via PRIME.

### Verify both cards are visible

```sh
pciconf -lv | grep -A3 vgapci
# vgapci0 → Intel UHD 620 (8086:5917)  — primary, runs Wayland
# vgapci1 → NVIDIA MX150 (10de:1d10)   — offload only
```

```sh
sysctl dev.drm
# dev.drm.0.PCI_ID: 8086:5917  (Intel, minor 0)
# dev.drm.1.PCI_ID: 10de:1d10  (NVIDIA, minor 1)
```

### PRIME render offload

To launch a specific application on the MX150:

```sh
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <program>
```

This is intentionally not set globally — it would force everything onto the
discrete GPU, drain battery, and prevent idle power-gating.

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

### PRIME offload from Sway

To launch an app on the NVIDIA GPU from within a Sway session:

```sh
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia foot
```

---

## 8. Ly Display Manager

Ly is a lightweight TUI display manager. It handles session selection and
PAM authentication, then execs the chosen session (Sway).

### Install

```sh
pkg install ly
```

> **TODO:** a local fork of ly is planned that fixes battery percentage
> reporting on FreeBSD. When ready, the install step above will be replaced
> with a `zig build` from source. The rest of this section remains valid
> regardless of which variant is used.

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

Config lives at `/usr/local/etc/ly/config.ini` (ly is a port; everything
installs under `/usr/local`). Key customisations on this machine:

| Key | Value | Effect |
|-----|-------|--------|
| `animation` | `matrix` | CMatrix rain plays on the login screen |
| `bigclock` | `en` | Large ASCII clock shown in English |
| `battery_id` | `BAT0` | Battery percentage shown top-left |
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
| ACPI EC errors at boot (`No handler for Region [EC__]`) | Cosmetic — suppressed by `acpi_wmi_load="YES"` and `acpi_video_load="YES"`; EC is functional |
| `hdac0: Command timeout` in dmesg | Intermittent; audio works correctly |
| Synaptics fingerprint reader (`06cb:009b`) | No FreeBSD driver; unsupported |
| `tmpfs` double-register warning at boot | Harmless; `tmpfs_load="YES"` in loader.conf races with built-in |
| `pci0: <simple comms>` (Intel ME, device 22.0) | No driver attached; expected and harmless |

---

## References

- [FreeBSD Handbook — Graphics (DRM/KMS)](https://docs.freebsd.org/en/books/handbook/x11/)
- [FreeBSD Forums — The gallant console font got supercharged](https://forums.freebsd.org/threads/the-gallant-console-font-got-supercharged.99074/)
- [UW ttyp0 Monospace Bitmap Fonts](https://people.mpi-inf.mpg.de/~uwe/misc/uw-ttyp0/)
- [Vermaden — FreeBSD Unix Wallpapers](https://vermaden.wordpress.com/2023/10/04/freebsd-unix-wallpapers/)
- [FreeBSD Ports — graphics/drm-66-kmod](https://www.freshports.org/graphics/drm-66-kmod)
- [FreeBSD Ports — graphics/gpu-firmware-intel-kmod](https://www.freshports.org/graphics/gpu-firmware-intel-kmod)
- Man pages: `fwget(8)`, `backlight(8)`, `loader.conf(5)`, `vtfontcvt(8)`, `automount(8)`, `devd.conf(5)`
