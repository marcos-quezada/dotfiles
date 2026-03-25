# CLI Cheatsheet

## Git Aliases
| Alias          | Expands to                                                    |
|----------------|---------------------------------------------------------------|
| `gs`           | `git status`                                                  |
| `gc`           | `git commit`                                                  |
| `gcam`         | `git commit -am`                                              |
| `gp`           | `git pull --rebase`                                           |
| `gl`           | pretty graph log (hash, decorators, message, date, author)    |

## Git Functions
| Command           | Action                                                   |
|-------------------|----------------------------------------------------------|
| `gsync <branch>`  | Pull upstream branch and push to origin                  |

## Docker Functions
| Command           | Action                                                   |
|-------------------|----------------------------------------------------------|
| `dockrun [image]` | One-shot ansible test container (default: ubuntu1604)    |
| `denter <id>`     | `docker exec -it <id> bash`                              |

## SSH Helpers
| Command        | Action                                                      |
|----------------|-------------------------------------------------------------|
| `knownrm <n>`  | Remove line `n` from `~/.ssh/known_hosts`                   |

## Threatwatch
| Command                  | Action                                           |
|--------------------------|--------------------------------------------------|
| `threatwatch`            | Print statusbar text (current threat level)      |
| `threatwatch data`       | Print full JSON summary                          |
| `threatwatch update`     | Fetch and cache all sources                      |
| `threatwatch --help`     | Show all flags                                   |

## Cheatsheets
| Command   | Action                                     |
|-----------|--------------------------------------------|
| `clue`    | Show this CLI cheatsheet (via bat)         |
