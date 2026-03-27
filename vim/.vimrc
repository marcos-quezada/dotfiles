scriptencoding utf-8
" ── general ──────────────────────────────────────────────────────────────────
let mapleader = ' '                    " leader key: Space
set nobackup                           " don't create backup files; use VCS instead
set autoread                           " reload file when changed on disk
set hidden                             " allow switching buffers without saving
set history=5000                       " command/search history depth
set exrc                               " load project-local .vimrc files
set secure                             " prevent local .vimrc from running shell commands
set sessionoptions-=options            " don't save options into session files
set sessionoptions-=blank              " don't save empty windows into session files
set clipboard=unnamed                  " yank/paste use the OS clipboard

" ── ui ────────────────────────────────────────────────────────────────────────
set number                             " line numbers
set signcolumn=number                  " show git/lsp signs inside the number column
set ruler                              " show cursor position in status bar
set showcmd                            " show partial command in status bar
set showmode                           " show current mode (INSERT, VISUAL, …)
set scrolloff=5                        " keep at least 5 lines visible above/below cursor
set nocursorline                       " no full-row highlight under cursor
set noequalalways                      " don't auto-resize all splits when opening/closing one
set fillchars+=vert:\                  " blank vertical split separator (no pipe character)
set fillchars+=eob:\                   " blank end-of-buffer indicator (no tildes)
set pumheight=20                       " cap autocomplete popup at 20 entries

" ── search ────────────────────────────────────────────────────────────────────
set hlsearch                           " highlight all search matches
set showmatch                          " briefly jump to matching bracket on insert

" ── indentation ───────────────────────────────────────────────────────────────
set expandtab                          " use spaces instead of tab characters
set tabstop=2 softtabstop=2 shiftwidth=2  " tab width / soft tab / shift width: all 2 spaces
set autoindent smartindent             " autoindent + smartindent
set smarttab                           " backspace over indent in multiples of shiftwidth

" ── editing ───────────────────────────────────────────────────────────────────
set backspace=indent,eol,start         " backspace works across indent, line breaks, and insert start
set path+=**                           " recursive file search (powers :find)
set foldmethod=syntax                  " fold blocks using language syntax rules
set completeopt=menu,menuone,noinsert  " autocomplete: show menu, don't auto-insert
set mouse=                             " disable mouse (keep terminal copy/paste behaviour)

" ── visual helpers ────────────────────────────────────────────────────────────
set listchars=tab:▸\ ,trail:-,extends:>,precedes:<,nbsp:+
                                       " symbols for invisible characters (active with :set list)

" ── filetypes ─────────────────────────────────────────────────────────────────
filetype on                            " enable filetype detection
filetype indent on                     " filetype-specific indentation rules
filetype plugin on                     " filetype-specific plugins

" markdown: conceal syntax markers so the file reads cleanly
augroup markdown_display
    autocmd!
    autocmd FileType markdown setlocal conceallevel=2 concealcursor=nc
    autocmd FileType markdown setlocal wrap linebreak nolist
    autocmd FileType markdown setlocal spell spelllang=en_us
augroup END

" ── bells ─────────────────────────────────────────────────────────────────────
set noerrorbells                       " no audio bell on errors
set visualbell                         " use visual bell instead (intercepted below)
set t_vb=                              " clear visual bell terminal code — total silence

" ── netrw (built-in file explorer) ────────────────────────────────────────────
" configured to behave like a lightweight NERDTree sidebar
let g:netrw_banner      = 0           " hide the banner
let g:netrw_liststyle   = 3           " tree view
let g:netrw_browse_split = 4          " open files in the previous window
let g:netrw_altv        = 1           " open vertical splits to the right
let g:netrw_winsize     = 25          " sidebar takes 25% of screen width

" ── keymaps ───────────────────────────────────────────────────────────────────
map  <F2>      :Lexplore<CR>          " toggle file explorer sidebar

" cheatsheet split — opens vim.md read-only on the right; q closes it
augroup cheatsheet
    autocmd!
    autocmd BufReadPost *cheatsheets/vim.md
        \ setlocal ro nomodifiable filetype=markdown |
        \ nnoremap <buffer><silent> q :close<CR>
augroup END
nnoremap <silent> <leader>? :vsplit ~/.config/cheatsheets/vim.md<CR>

" auto-close curly braces
inoremap {     {}<Left>
inoremap {<CR> {<CR>}<Esc>O
inoremap {{    {
inoremap {}    {}

" ── theme / lsp ──────────────────────────────────────────────────────────────
syntax on
source ~/.config/vim/theme.vim
source ~/.config/vim/lsp.vim
