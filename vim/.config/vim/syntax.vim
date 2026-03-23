" ── true colour ──────────────────────────────────────────────────────────────
" only enable termguicolors when the terminal actually supports 24-bit colour;
" without this guard, colours break on terminals that only support 256 colours.
if $COLORTERM == "truecolor" || $COLORTERM == "24bit"
    set termguicolors                          " enable 24-bit RGB colour
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"   " tmux foreground true colour sequence
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"   " tmux background true colour sequence
endif

" ── theme ─────────────────────────────────────────────────────────────────────
" catppuccin is managed via vim's native package system (~/.vim/pack/).
" run vim/install.sh to fetch it on a new machine.
set background=dark
colorscheme catppuccin_mocha

" ── lsp ───────────────────────────────────────────────────────────────────────
" yegappan/lsp is managed via vim's native package system (~/.vim/pack/).
" run vim/install.sh to fetch it on a new machine.
packadd lsp

" register qmlls as the language server for QML files
call LspAddServer([#{
    \   name:     'qmlls',
    \   filetype: 'qml',
    \   path:     'qmlls6',
    \   args:     ['--build-dir', 'build']
    \ }])

" ── lsp keymaps ───────────────────────────────────────────────────────────────
nnoremap <leader>gd :LspGotoDefinition<CR>    " go to definition
nnoremap <leader>gr :LspPeekReferences<CR>    " peek references
nnoremap <leader>gi :LspPeekImplementation<CR> " peek implementation
nnoremap <leader>gt :LspPeekTypedef<CR>       " peek type definition
nnoremap <leader>rn :LspRename<CR>            " rename symbol
nnoremap <leader>ca :LspCodeAction<CR>        " code actions
nnoremap K          :LspHover<CR>             " hover documentation

" ── diagnostic navigation ─────────────────────────────────────────────────────
nnoremap [d :LspDiag prev<CR>                 " jump to previous diagnostic
nnoremap ]d :LspDiag next<CR>                 " jump to next diagnostic
nnoremap <leader>df :LspDiag show<CR>         " show diagnostics for current file
