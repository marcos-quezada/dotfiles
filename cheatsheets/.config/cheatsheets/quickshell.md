# Quickshell Debug

Quickshell is the QML-based bar launched by sway via `exec quickshell`.
The config lives at `~/.config/quickshell/`.

## Dev loop

`watchFiles = true` is the default — saving any `.qml` file triggers an
automatic sub-second reload. no command needed for normal editing.

## IPC reload

```sh
qs ipc call shell reload       # soft reload — reuses windows
qs ipc call shell hardReload   # hard reload — destroys and recreates all windows
```

`qs log` shows runtime output and QML errors from the running instance.

## Full restart from a terminal

Kill the running instance and relaunch interactively so QML errors print to
stdout:

```sh
pkill quickshell
quickshell
```

Press `Ctrl-C` to stop. useful when you need to see startup errors or test a
change that `watchFiles` reload doesn't catch (e.g. changes to `shell.qml`
root structure).

## Common error patterns

| Message | Likely cause |
|---------|--------------|
| `ReferenceError: <name> is not defined` | typo in property or id |
| `Cannot read property of null` | object not yet ready — use `Component.onCompleted` |
| `module "Foo" is not installed` | missing QML import path or package |
| blank bar / no bar | `exec quickshell` not in sway config, or quickshell crashed silently |

## File layout

```
~/.config/quickshell/
├── shell.qml          # root Scope — entry point, IpcHandler
├── Bar.qml            # top-level bar component (one instance per screen)
├── Time.qml           # clock widget
├── PopupFrame.qml     # shared popup chrome
├── settings.json      # runtime tunables (colours, sizes, etc.)
├── .qmlls.ini         # qmlls LSP import paths (auto-populated by Quickshell)
├── taskbar/           # workspace switcher
├── threatwatch/       # threat feed widget + popup
│   ├── ThreatWatchModel.qml  # singleton data layer
│   ├── ThreatWatchWidget.qml # bar item
│   ├── ThreatWatchPopup.qml  # map overlay
│   ├── Utils.qml             # pure logic (no Quickshell imports; testable)
│   └── qmldir
└── fonts/             # bundled fonts loaded by shell.qml
```

`Config.qml` and `NewBorder.qml` are upstream read-only reference files —
do not edit them.

## qmlls (language server)

`qmlls6` is configured in `~/.config/vim/lsp.vim`. It provides completion and
diagnostics inside Vim for all `.qml` files. import paths come from
`.qmlls.ini` — no `--build-dir` needed.
