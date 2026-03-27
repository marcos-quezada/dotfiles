# Sway Keybindings

> Mod = Super (Windows key) — direction keys are vim-style h/j/k/l

## Basics
| Key               | Action                        |
|-------------------|-------------------------------|
| `Mod+Enter`       | open terminal (foot)          |
| `Mod+d`           | open launcher (wmenu-run)     |
| `Mod+Shift+q`     | kill focused window           |
| `Mod+Shift+c`     | reload config                 |
| `Mod+Shift+e`     | exit sway (prompts via swaynag) |

## Focus
| Key               | Action                        |
|-------------------|-------------------------------|
| `Mod+h/j/k/l`     | focus left/down/up/right      |
| `Mod+←↓↑→`        | focus (arrow keys)            |
| `Mod+Space`       | toggle focus: tiling ↔ floating |
| `Mod+a`           | focus parent container        |

## Move
| Key                   | Action                        |
|-----------------------|-------------------------------|
| `Mod+Shift+h/j/k/l`   | move window left/down/up/right |
| `Mod+Shift+←↓↑→`      | move window (arrow keys)      |

## Workspaces
| Key               | Action                        |
|-------------------|-------------------------------|
| `Mod+1..0`        | switch to workspace 1–10      |
| `Mod+Shift+1..0`  | move window to workspace 1–10 |

## Layout
| Key               | Action                        |
|-------------------|-------------------------------|
| `Mod+b`           | split horizontal              |
| `Mod+v`           | split vertical                |
| `Mod+e`           | toggle split direction        |
| `Mod+s`           | stacking layout               |
| `Mod+w`           | tabbed layout                 |
| `Mod+f`           | toggle fullscreen             |
| `Mod+Shift+Space` | toggle floating               |

## Resize mode  (`Mod+r` to enter, `Esc`/`Enter` to exit)
| Key       | Action                |
|-----------|-----------------------|
| `h` / `←` | shrink width 10px     |
| `l` / `→` | grow width 10px       |
| `k` / `↑` | shrink height 10px    |
| `j` / `↓` | grow height 10px      |

## Scratchpad
| Key               | Action                              |
|-------------------|-------------------------------------|
| `Mod+Shift+-`     | send focused window to scratchpad   |
| `Mod+-`           | show/cycle scratchpad windows       |

## Utilities
| Key                    | Action                          |
|------------------------|---------------------------------|
| `XF86AudioMute`        | toggle mute (pactl)             |
| `XF86AudioLowerVolume` | volume −5% (pactl)              |
| `XF86AudioRaiseVolume` | volume +5% (pactl)              |
| `XF86AudioMicMute`     | toggle mic mute (pactl)         |
| `XF86MonBrightnessDown`| brightness −5% (brightnessctl)  |
| `XF86MonBrightnessUp`  | brightness +5% (brightnessctl)  |
| `Print`                | screenshot (grim)               |

## Quickshell dev workflow
| Command                             | Action                                                      |
|-------------------------------------|-------------------------------------------------------------|
| *(save any `.qml` file)*            | auto-reload — `watchFiles = true` by default, sub-second   |
| `qs ipc call shell reload`          | soft reload: reuse windows, re-evaluate QML                 |
| `qs ipc call shell hardReload`      | hard reload: destroy and recreate all windows               |
| `qs log`                            | view Quickshell runtime log / errors                        |
| `qs list`                           | list running Quickshell instances                           |
| `qs kill`                           | stop the running Quickshell instance                        |
