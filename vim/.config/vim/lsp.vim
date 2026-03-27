" ── lsp ──────────────────────────────────────────────────────────────────────
" yegappan/lsp is managed via vim's native package system (~/.vim/pack/).
" run ~/.config/vim/install.sh to fetch it on a new machine.
packadd lsp

" register qmlls as the language server for QML files.
" no --build-dir: pure-QML projects use .qmlls.ini instead, which quickshell
" auto-populates with its module import paths on first run.
call LspAddServer([#{
    \   name:     'qmlls',
    \   filetype: 'qml',
    \   path:     'qmlls6',
    \   args:     []
    \ }])

" ── qmllint quickfix ──────────────────────────────────────────────────────────
" <leader>lq runs qmllint on the current file and populates the quickfix list.
" :copen / :cclose toggle the window; :cn / :cp navigate between findings.
augroup qml_lint
    autocmd!
    autocmd FileType qml setlocal makeprg=qmllint\ %
    autocmd FileType qml setlocal errorformat=%f:%l:%c:\ %m
augroup END
nnoremap <silent> <leader>lq :make<CR>:copen<CR>

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
