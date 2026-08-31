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
| `module "Foo" is not installed` | missing QML import path or package, or a subdirectory missing its `qmldir` |
| `<Type> is not a type` | directory import resolved but the type isn't declared in that directory's `qmldir` |
| `Cannot override FINAL property` | property name collides with a built-in Qt property (e.g. `Button.icon`) — rename it |
| blank bar / no bar | `exec quickshell` not in sway config, or quickshell crashed silently |

## File layout

```
~/.config/quickshell/
├── shell.qml           # root Scope — entry point, IpcHandler
├── Config.qml          # colours + settings singleton
├── Fonts.qml           # font resources singleton — semantic roles (body/icon/title)
├── Time.qml            # clock singleton
├── settings.json       # runtime tunables (colours, sizes, etc.)
├── .qmlls.ini          # qmlls LSP import paths (auto-populated by Quickshell)
├── components/         # shared, generic UI atoms — no feature-specific knowledge
│   ├── NewBorder.qml       # retro bevel border effect
│   ├── PopupFrame.qml      # shared popup chrome (title bar, borders, fade)
│   ├── TaskbarButton.qml   # icon-only toggle button (Button-based, native hit-testing)
│   └── qmldir
├── taskbar/            # workspace switcher, tray, clock
│   ├── Bar.qml             # PanelWindow, one per screen
│   ├── Workspaces.qml      # sway workspace switcher
│   ├── SysTray.qml         # system tray row (clock only — ThreatWatch moved to a TaskbarButton)
│   ├── ClockWidget.qml
│   └── qmldir
├── threatwatch/         # threat feed model + popup
│   ├── ThreatWatchModel.qml   # singleton data layer
│   ├── ThreatWatchWidget.qml  # deprecated — superseded by components/TaskbarButton, pending removal
│   ├── ThreatWatchPopup.qml   # map overlay + status summary
│   └── qmldir
├── ThreatWatchUtils/     # pure logic (no Quickshell imports; testable with qmltestrunner)
│   ├── Utils.qml
│   └── qmldir
└── fonts/               # bundled fonts loaded by Fonts.qml
```

`components/`, `taskbar/`, and `threatwatch/` each have their own `qmldir` and
are imported with an explicit `as Namespace` (e.g. `import "../components" as
Components`, `Components.NewBorder { ... }`). `Config.qml`, `Fonts.qml`, and
`Time.qml` are root-level singletons with no `qmldir` — any file can reference
them directly by name without an import, as long as it isn't nested more than
one directory deep (subdirectories still need `import ".."` to reach root).

## qmlls (language server)

`qmlls6` is configured in `~/.config/vim/lsp.vim`. It provides completion and
diagnostics inside Vim for all `.qml` files. import paths come from
`.qmlls.ini` — no `--build-dir` needed.

## qmllint

Batch linter, separate from `qmlls`'s live diagnostics. Requires the
`qt6-declarative` package (FreeBSD) — not currently installed by `install.sh`;
install manually with `doas pkg install qt6-declarative` until that gap is
closed.

`<leader>lq` no longer exists — it was removed after causing more Vim quirks
than it solved (see `docs/architecture.md`'s "vim integration" section for
why). Run it directly from a terminal for a full-tree batch report instead:

```sh
cd ~/.config/quickshell
qmllint -I . $(find . -name "*.qml")
```

Live diagnostics in Vim come from `qmlls` instead — `<leader>df`, `[d`/`]d`.
See `docs/architecture.md`'s "QML quality" section for the full tool reference
and the current list of known, accepted warnings.
