# CLI Cheatsheet

## Shell Aliases
| Alias   | Expands to                              |
|---------|-----------------------------------------|
| `ll`    | `ls -laFo`                              |
| `l`     | `ls -l`                                 |
| `g`     | `grep -Ei`                              |
| `m`     | `$PAGER`                                |
| `j`     | `jobs`                                  |
| `h`     | `fc -l` (history)                       |

## Git Aliases (shell)
| Alias    | Expands to                                                  |
|----------|-------------------------------------------------------------|
| `gs`     | `git status`                                                |
| `gc`     | `git commit`                                                |
| `gcam`   | `git commit -am`                                            |
| `gp`     | `git pull --rebase`                                         |
| `gl`     | pretty graph log (hash, branch, message, date, author)      |

## Git Aliases (.gitconfig)
| Alias   | Action                                                       |
|---------|--------------------------------------------------------------|
| `lool`  | graph log — hash, subject, branch, author                    |
| `lol`   | graph log — last commit, oneline, all branches               |
| `ll`    | graph log — last 10 commits, oneline, all branches           |
| `cfw`   | clone bare repo for worktree workflow (runs `git-clone-bare-for-worktrees`) |

## Git Worktree Workflow
| Command                    | Action                                               |
|----------------------------|------------------------------------------------------|
| `git cfw <url>`            | Clone bare repo; creates `<repo>/.bare` + `.git`     |
| `git cfw <url> <name>`     | Clone bare repo into `<name>/` directory             |
| `git worktree add <path>`  | Create a new worktree at `<path>`                    |
| `git worktree list`        | List all active worktrees                            |
| `git worktree remove <path>` | Remove a worktree                                  |

## Git Functions (shell)
| Command           | Action                                                   |
|-------------------|----------------------------------------------------------|
| `gsync <branch>`  | Pull from upstream and push to origin                    |

## SSH Helpers
| Command        | Action                                        |
|----------------|-----------------------------------------------|
| `knownrm <n>`  | Remove line `n` from `~/.ssh/known_hosts`     |

## FreeBSD
| Command      | Action                                           |
|--------------|--------------------------------------------------|
| `handbook`   | Open FreeBSD handbook in w3m                     |

## Threatwatch
| Command                | Action                                         |
|------------------------|------------------------------------------------|
| `threatwatch`          | Print statusbar text (current threat level)    |
| `threatwatch data`     | Print full JSON summary                        |
| `threatwatch update`   | Fetch and cache all sources                    |
| `threatwatch --help`   | Show all flags                                 |

## Script Generator
| Command                     | Action                                              |
|-----------------------------|-----------------------------------------------------|
| `new_script`                | Interactive: prompts for name, purpose, options     |
| `new_script <file>`         | Interactive: write generated template to `<file>`   |
| `new_script -q <file>`      | Quiet: write default POSIX sh template, no prompts  |
| `new_script -s <file>`      | Add root-privilege check to generated script        |
| `new_script -h`             | Show help                                           |

## Dotfiles
| Command                                                          | Action                            |
|------------------------------------------------------------------|-----------------------------------|
| `stow --dir=~/dotfiles --target="$HOME" --restow <pkg>`          | Stow (or re-stow) a package       |
| `stow --dir=~/dotfiles --target="$HOME" --delete <pkg>`          | Unstow a package                  |
| `stow --dir=~/dotfiles --target="$HOME" --simulate --restow <pkg>` | Dry-run: preview changes        |
| `doas stow --dir=~/dotfiles --target=/ --restow vt`              | Re-stow `vt` (root target)        |

Packages: `cheatsheets` `foot` `git` `inputrc` `nvim` `quickshell` `sh` `sketchybar` `sway` `threatwatch` `vim` `vt` `xdg` `zsh`

## Sway Wallpapers
| File                          | Set via `sway/config`                          |
|-------------------------------|------------------------------------------------|
| `freebsd-kilmynda-wide.png`   | `output * bg ~/walls/freebsd-kilmynda-wide.png stretch` |
| `metropolis.png`              | `output * bg ~/walls/metropolis.png stretch`   |

## Dev / Testing
| Command                                    | Action                                            |
|--------------------------------------------|---------------------------------------------------|
| `bats tests/`                              | Run full bats suite (all suites)                  |
| `bats tests/lint.bats`                     | Run ShellCheck gate only                          |
| `bats tests/vim.bats`                      | Run headless Vim sourcing tests only              |
| `bats tests/qml.bats`                      | Run QML pure-logic tests (skips if no Qt)         |
| `shellcheck <file>`                        | Lint a shell script                               |
| `shfmt -ln posix <file>`                   | Format-check a POSIX sh script                    |
| `shfmt -ln bash <file>`                    | Format-check a bash script                        |

## Cheatsheets
| Command   | Action                                           |
|-----------|--------------------------------------------------|
| `clue`    | Show this cheatsheet (bat with paging)           |
