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
| `git` | all | `.gitconfig` + `.color.gitconfig` — personal identity, aliases, good defaults |
| `vim` | all | `.vimrc` — syntax, indent, clipboard, visual tweaks |
| `inputrc` | all | `.inputrc` — history search, case-insensitive completion |
| `ssh` | all | `.ssh/config.template` — port-443 GitHub alias, ControlMaster, ServerAlive |
| `tmux` | all | `.tmux.conf` — C-a prefix, vim keys, true colour, split/nav bindings |
| `curl` | all | `.curlrc` — silent+show-error, follow redirects, fail-on-error, 30s timeout |
| `cheatsheets` | all | `.config/cheatsheets/` — CLI and vim quick-reference |
| `zsh` | macOS | `.zshrc` + `.git-worktree-functions.zsh` — prompt, aliases, mise, direnv |
| `nvim` | macOS | `.config/nvim/` — lazy.nvim config (`lazy-lock.json` gitignored) |
| `sketchybar` | macOS | `.config/sketchybar/` — statusbar items + plugins |
| `sh` | FreeBSD | `.profile` + `.shrc` — login env, editline bindings, gwt.sh |
| `foot` | FreeBSD, Linux | `.config/foot/` — Wayland terminal config |
| `sway` | FreeBSD, Linux | `.config/sway/` — window manager config |
| `quickshell` | FreeBSD | `.config/quickshell/` — sway bar, workspaces, threatwatch widget |
| `vt` | FreeBSD | `/boot/fonts/` — console bitmap font (requires doas/sudo) |
| `threatwatch` | all | `.local/bin/threatwatch` + `.config/threatwatch/config.env.template` |

---

## stow manually

```sh
# from the repo root — stow any combination:
stow git vim inputrc ssh tmux curl   # essentials, works on any machine
stow zsh nvim sketchybar             # macOS extras
stow sh foot sway quickshell         # FreeBSD/Linux extras
stow threatwatch                     # all platforms
```

to remove a package:

```sh
stow -D nvim
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

---

## development

### running tests

```sh
bats tests/
```

bats directory mode discovers all suites automatically — no separate runner
needed. to run a single suite:

```sh
bats tests/lint.bats
```

all tests are network-free.

### shellcheck

```sh
shellcheck <file>
```

or run the full lint gate (covers all scripts and all `.bats` files):

```sh
bats tests/lint.bats
```

### dev tool install

answer yes to the dev tools prompt in the installer:

```sh
sh install.sh
# … answer yes when asked about shellcheck / shfmt / bats-core
```

this installs `shellcheck`, `shfmt`, and `bats-core` via your platform's
package manager.
