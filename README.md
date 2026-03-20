# dotfiles

personal config for macOS, FreeBSD, and headless Linux. managed with [GNU Stow](https://www.gnu.org/software/stow/).

---

## quick start

```sh
git clone git@github.com:marcos-quezada/dotfiles.git ~/dotfiles
cd ~/dotfiles
sh install.sh
```

the installer detects your OS, checks dependencies, and prompts you to choose which packages to stow.

---

## packages

| package | platforms | what it provides |
|---|---|---|
| `quickshell` | FreeBSD only | sway statusbar — workspaces, systray, threatwatch widget |
| `threatwatch` | all | threat monitor script + config template |

---

## stow manually

```sh
# from the repo root:
stow quickshell     # symlinks quickshell/.config/quickshell → ~/.config/quickshell
stow threatwatch    # symlinks threatwatch/.local/bin/threatwatch → ~/.local/bin/threatwatch
                    #         threatwatch/.config/threatwatch/  → ~/.config/threatwatch/
```

to remove a package:

```sh
stow -D threatwatch
```

---

## threatwatch setup

1. copy the config template and fill in your Mapbox token:

```sh
cp ~/.config/threatwatch/config.env.template ~/.config/threatwatch/config.env
chmod 600 ~/.config/threatwatch/config.env
$EDITOR ~/.config/threatwatch/config.env
```

2. get a free Mapbox token at <https://account.mapbox.com> (no credit card needed).

3. run a first update:

```sh
threatwatch update
threatwatch data
```

see [docs/architecture.md](docs/architecture.md) for data sources, threat level logic, and Mapbox rate limiting details.

---

## secrets

`config.env` is in `.gitignore` and will never be committed. only `config.env.template` (with placeholder values) is tracked.

---

## docs

- [docs/architecture.md](docs/architecture.md) — design decisions, data flow, MVC split, map calibration
