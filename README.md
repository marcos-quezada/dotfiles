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
| `zsh` | macOS | `.zshrc` + `.git-worktree-functions.zsh` — prompt, aliases, mise, direnv |
| `nvim` | macOS | `.config/nvim/` — lazy.nvim config (`lazy-lock.json` gitignored) |
| `sketchybar` | macOS | `.config/sketchybar/` — statusbar items + plugins |
| `quickshell` | FreeBSD only | `.config/quickshell/` — sway bar, workspaces, threatwatch widget |
| `threatwatch` | all | `.local/bin/threatwatch` + `.config/threatwatch/config.env.template` |

---

## stow manually

```sh
# from the repo root — stow any combination:
stow git vim inputrc          # essentials, works on any machine
stow zsh nvim sketchybar      # macOS extras
stow quickshell               # FreeBSD/sway only
stow threatwatch              # all platforms
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
