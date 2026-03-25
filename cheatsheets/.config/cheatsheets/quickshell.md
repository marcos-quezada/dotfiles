# Quickshell Debug

Quickshell is the QML-based bar launched by sway via `exec quickshell`.
The config lives at `~/.config/quickshell/`.

## Run from a terminal

Kill the running instance first, then launch interactively so QML errors
print to stdout:

```sh
pkill quickshell
quickshell
```

All QML errors, warnings, and `console.log()` output appear in the terminal.
Press `Ctrl-C` to stop.

## Reload without killing sway

```sh
pkill quickshell && quickshell &
```

Quickshell re-reads `shell.qml` and all imports on start; no sway reload needed.

## Common error patterns

| Message | Likely cause |
|---------|--------------|
| `ReferenceError: <name> is not defined` | typo in property or id |
| `Cannot read property of null` | object not yet ready — use `Component.onCompleted` |
| `module "Foo" is not installed` | missing QML import path or package |
| blank bar / no bar | `exec quickshell` not in sway config, or quickshell crashed silently |

## Inspect running IPC state

```sh
# list all open IPC sockets
quickshell ipc list

# call a function or read a property
quickshell ipc call <socket> <path>
```

## File layout

```
~/.config/quickshell/
├── shell.qml          # root Scope — entry point
├── Bar.qml            # top-level bar component
├── Time.qml           # clock widget
├── PopupFrame.qml     # shared popup chrome
├── settings.json      # runtime tunables (colours, sizes, etc.)
├── taskbar/           # workspace + window list
├── threatwatch/       # threat feed popup
└── fonts/             # bundled fonts loaded by shell.qml
```

`Config.qml` and `NewBorder.qml` are upstream read-only reference files —
do not edit them.

## qmlls (language server)

`qmlls6` is configured in `~/.config/vim/lsp.vim`. It provides completion and
diagnostics inside Vim for all `.qml` files.
