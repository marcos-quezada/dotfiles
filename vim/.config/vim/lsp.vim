" ── lsp ──────────────────────────────────────────────────────────────────────
" yegappan/lsp is managed via vim's native package system (~/.vim/pack/).
" run ~/.config/vim/install.sh to fetch it on a new machine.
packadd lsp

" register qmlls as the language server for QML files
call LspAddServer([#{
    \   name:     'qmlls',
    \   filetype: 'qml',
    \   path:     'qmlls6',
    \   args:     ['--build-dir', 'build']
    \ }])

" ── keymaps ───────────────────────────────────────────────────────────────────
nnoremap <leader>gd :LspGotoDefinition<CR>     " go to definition
nnoremap <leader>gr :LspPeekReferences<CR>     " peek references
nnoremap <leader>gi :LspPeekImplementation<CR> " peek implementation
nnoremap <leader>gt :LspPeekTypedef<CR>        " peek type definition
nnoremap <leader>rn :LspRename<CR>             " rename symbol
nnoremap <leader>ca :LspCodeAction<CR>         " code actions
nnoremap K          :LspHover<CR>              " hover documentation

" ── diagnostics ───────────────────────────────────────────────────────────────
nnoremap [d          :LspDiag prev<CR>         " jump to previous diagnostic
nnoremap ]d          :LspDiag next<CR>         " jump to next diagnostic
nnoremap <leader>df  :LspDiag show<CR>         " show diagnostics for current file
