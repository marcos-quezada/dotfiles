# ESP-IDF on FreeBSD — native toolchain, no Linuxulator

Setup for building/flashing ESP32-family firmware (starting with
`had-badge-mod`, the Hackaday Supercon 2025 Communicator badge) on this
FreeBSD machine, using a genuinely native toolchain — no Linux binary
compatibility layer involved.

## Why native, not Linuxulator

ESP-IDF's own `idf_tools.py` explicitly maps `FreeBSD-amd64` to the same
platform identifier as `linux-amd64` — meaning its *default* toolchain
download is a Linux binary requiring the Linuxulator (`linux_enable=YES`,
`linux_base-rl9`). That path works, but was set aside in favor of a better
option found via web research: FreeBSD has a genuine, official,
**native** port providing the exact same compiler:

- `devel/xtensa-esp-elf` — GCC 13.2.0, crosstool-NG build
  `esp-13.2.0_20240530`, zero compat layer needed at all

This version pins to **ESP-IDF v5.3.3** specifically, because that
release's own `tools/tools.json` requires *exactly* that toolchain
version (confirmed by reading it directly, not guessed) — matching the
native port precisely, with zero version mismatch.

If a future project needs a newer ESP-IDF release and its native
toolchain isn't yet packaged for FreeBSD, fall back to the Linuxulator
path (documented for reference, not currently used):

```sh
sysrc linux_enable="YES"
service linux start
pkg install linux_base-rl9
```

## One-time setup

```sh
esp-idf-setup
```

(from the `bin` stow package — `bin/.local/bin/esp-idf-setup` in the
dotfiles repo). Idempotent, safe to re-run. Handles, in order:

1. `pkg install xtensa-esp-elf py312-cryptography`
2. adds the current user to the `dialer` group (needed for `/dev/cuaU*`
   access — see "Serial port access" below)
3. clones ESP-IDF (`v5.3.3`, `--recursive`) if not already present
4. `git submodule update --init --recursive` (ESP-IDF has *nested*
   submodules — e.g. the NimBLE Bluetooth stack has its own submodule
   inside `components/bt/host/nimble/nimble` — a single `--recursive`
   clone can still miss these if interrupted; this step re-runs safely)
5. creates the Python venv with **`--system-site-packages`**, and
   installs ESP-IDF's core requirements — see "The cryptography
   workaround" below for why this specific flag matters
6. creates a placeholder `ESP_ROM_ELF_DIR` (see "Known cosmetic
   workarounds" below)

After running it once (or after it prompts you to, if the `dialer` group
was just added), log out and back in, then every session:

```sh
. ~/.esp-idf-env
```

sets `IDF_PATH`, `IDF_PYTHON_ENV_PATH`, `PATH` (native toolchain
prepended), `ESP_ROM_ELF_DIR`, and activates the venv — all in one
sourced command. Must be *sourced*, not executed (it refuses to run
standalone with a clear error if you try).

## The `cryptography` workaround (why the venv needs `--system-site-packages`)

`esptool` (ESP-IDF's flashing tool) depends on `cryptography`, a
compiled Rust/C extension. Confirmed directly: **it has no published
wheel for FreeBSD on PyPI**, and pip can't build it from source here
either. FreeBSD's own `security/py-cryptography` port is a real, current,
working alternative (`py312-cryptography`, confirmed compiled and
importable) — but ESP-IDF's own `espidf.constraints.v5.3.txt` caps it at
`<43`, while the FreeBSD package is newer (48.x).

The fix, all handled by `esp-idf-setup`:

1. install `py312-cryptography` via `pkg`
2. create the venv with `--system-site-packages`, so it's visible
3. strip the `cryptography` line from **both** the requirements file pip
   installs from, and the constraints file pip checks against — so pip
   never tries to resolve/install its own copy at all
4. `idf.py` itself re-checks the *real* constraints file on every
   invocation (not just at install time) — the script also edits that
   file in place (keeping a `.orig` backup), since a filtered copy
   passed only at install time isn't enough

This is a known trade-off, not a silent risk: it means using a newer
`cryptography` than ESP-IDF's own CI pins. No issues found in practice
for basic build/flash/monitor use.

## Known cosmetic workarounds

- **`ESP_ROM_ELF_DIR`**: CMake's `gdbinit.cmake` does
  `file(TO_CMAKE_PATH $ENV{ESP_ROM_ELF_DIR} ...)`, which errors with
  "must be called with exactly three arguments" if the variable is
  unset (an empty env-var expansion drops an argument). Normally
  populated by `idf_tools.py`'s full install flow (which we skip, using
  the native toolchain instead). A placeholder empty directory is
  enough to satisfy the check — this only matters for real once you
  want on-chip GDB debugging, not for building/flashing.

## Serial port access

The badge attaches as `umodem0` — "Espressif USB JTAG/serial debug
unit" (the ESP32-S3's *native* USB-JTAG peripheral, no external
CP210x/CH340 USB-UART bridge chip). Confirmed via the actual `ucom(4)`
man page: `/dev/ttyU0` (callin) and `/dev/cuaU0` (callout) — not
Linux's `/dev/ttyUSB0` convention. The callout device is owned
`uucp:dialer`; `esp-idf-setup` adds the current user to that group.
Needs a fresh login session to take effect.

## The manual BOOT+RESET flashing quirk — and why it doesn't happen on macOS

Auto-reset into download mode reliably fails on FreeBSD with:

```
Failed to get VID/PID of a device on /dev/cuaU0 ... Using standard reset sequence.
A fatal error occurred: Failed to connect to ESP32-S3: Wrong boot mode detected (0x2a)!
```

Root-caused by reading `esptool`'s actual source (`esp_pylib`/`pyserial`
call chain), not assumed: `pyserial`'s FreeBSD backend
(`list_ports_posix.py`) is a bare `glob.glob('/dev/cua*')` fallback with
**zero USB metadata** — no VID/PID, no manufacturer string. Compare
Linux's backend (a real `/sys/bus/usb/devices/...` walk) or macOS's
(real IOKit queries) — both give `esptool` enough information to pick
the exact reset strategy this chip's native USB-JTAG peripheral needs.
Without it, `esptool` falls back to a generic reset sequence that
doesn't correctly trigger bootloader entry for this specific hardware.

This is a genuine, confirmed **upstream `pyserial` gap** — not a mistake
in this setup, and not something either ESP-IDF or FreeBSD introduced
deliberately. It's also why this doesn't happen on macOS: the VID/PID
lookup succeeds there, so the correct reset strategy gets picked
automatically.

**Workaround** (the project's own documented fallback, confirmed
needed every time on this machine, not a one-off): hold **BOOT**, tap
**RESET**, release **BOOT**, *then* run the `idf.py`/`esptool` command.
Needs repeating before every flash/erase invocation specifically (not
just once per session).

## Monitor exit key

`idf_monitor`'s default exit key (`Ctrl+]`) didn't register in the
terminal used for initial testing. Confirmed alternate (from
`esp-idf-monitor`'s own `key_config.py`, not guessed): **`Ctrl+T`, then
`Ctrl+X`** (the menu-prefix key followed by the exit-menu key).

## Versioning

`FW_VERSION` was originally a hardcoded string in
`components/bsp/include/app_config.h` — it had gone stale (still read
`1.0.0` despite real progress). Fixed (upstream in the fork, not a
FreeBSD-specific patch) to use ESP-IDF's own `esp_app_get_description()`
API instead, which is populated from `git describe --tags` at build
time and can't go stale the same way. Fork-specific releases use a
`+<name>` SemVer build-metadata suffix (e.g. `v1.2.0+axo`) — this can
never collide with upstream's own bare-SemVer tags, since it's an
explicitly different, additional identifier, not a competing version
number.

## Reference

- Full investigation and decision trail:
  `openspec/changes/embedded-dev-environment` (dotfiles repo,
  gitignored — local planning scaffolding only)
- `bin/.local/bin/esp-idf-setup` — the one-time bootstrap script
- `bin/.esp-idf-env` — the per-session activation script
