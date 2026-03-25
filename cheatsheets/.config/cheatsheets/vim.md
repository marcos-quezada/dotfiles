# Vim Advanced Incantations

## Splits & Panels
| Key              | Action                                        |
|------------------|-----------------------------------------------|
| `Ctrl+W v`       | Split vertically (side-by-side)               |
| `Ctrl+W s`       | Split horizontally (top-and-bottom)           |
| `Ctrl+W =`       | Make all splits equal size                    |
| `Ctrl+W \|`      | Max out width of current split                |
| `Ctrl+W _`       | Max out height of current split               |
| `Ctrl+W H/J/K/L` | Move split to Far Left/Bottom/Top/Right       |
| `Ctrl+W T`       | Move current split into its own new tab       |
| `Ctrl+W h/j/k/l` | Navigate between splits                       |
| `Ctrl+W q`       | Close current split                           |

## File Explorer (netrw)
| Key     | Action                                    |
|---------|-------------------------------------------|
| `<F2>`  | Toggle the netrw sidebar                  |
| `Enter` | Open file in the previous window          |
| `v`     | Open file in a new vertical split         |
| `d`     | Create a new directory                    |
| `%`     | Create a new file                         |
| `D`     | Delete a file or directory                |
| `R`     | Rename a file or directory                |
| `-`     | Go up one directory                       |

## LSP & Code Navigation (Leader = Space)
| Key            | Action                          |
|----------------|---------------------------------|
| `<leader>gd`   | Go to Definition                |
| `<leader>gr`   | Peek References                 |
| `<leader>gi`   | Peek Implementation             |
| `<leader>gt`   | Peek Type Definition            |
| `<leader>rn`   | Rename symbol under cursor      |
| `<leader>ca`   | Code Actions                    |
| `K`            | Hover Documentation             |
| `[d` / `]d`    | Jump to Prev / Next Diagnostic  |
| `<leader>df`   | Show all diagnostics in file    |

## Buffers
| Key           | Action                                      |
|---------------|---------------------------------------------|
| `:ls`         | List all open buffers                       |
| `:b <number>` | Switch to buffer by number                  |
| `:bd`         | Delete (close) current buffer               |
| `Ctrl+^`      | Toggle between current and last buffer      |

## Folds
| Key    | Action                         |
|--------|--------------------------------|
| `za`   | Toggle fold open / closed      |
| `zR`   | Open all folds in file         |
| `zM`   | Close all folds in file        |
| `zc`   | Close fold under cursor        |
| `zo`   | Open fold under cursor         |

## Search & Replace
| Key            | Action                                      |
|----------------|---------------------------------------------|
| `*`            | Search for word under cursor (forward)      |
| `#`            | Search for word under cursor (backward)     |
| `:noh`         | Clear search highlights                     |
| `:%s/old/new/g`| Replace all occurrences in file             |
| `:s/old/new/g` | Replace all occurrences in current line     |

## Command History
| Key  | Action                                    |
|------|-------------------------------------------|
| `q:` | Open command-line history window          |
| `q/` | Open search history window                |

## Cheatsheet
| Key            | Action                         |
|----------------|--------------------------------|
| `<leader>?`    | Open this cheatsheet           |
