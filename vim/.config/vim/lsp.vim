" ── lsp ──────────────────────────────────────────────────────────────────────
" yegappan/lsp is managed via vim's native package system (~/.vim/pack/).
" run ~/.config/vim/install.sh to fetch it on a new machine.
" 
" per language LspAddServer registration lives in ftplugin/<filetype>.vim,
" not here -- see ftplugin/qml.vim for the first example. this file is onlyfor
" the plugin load itself and keymaps that apply regardles of filetype.
packadd lsp

" ── keymaps ───────────────────────────────────────────────────────────────────
nnoremap <leader>gd :LspGotoDefinition<CR>     " go to definition
nnoremap <leader>gr :LspPeekReferences<CR>     " peek references
nnoremap <leader>gi :LspPeekImplementation<CR> " peek implementation
nnoremap <leader>gt :LspPeekTypedef<CR>        " peek type definition
nnoremap <leader>rn :LspRename<CR>             " rename symbol
nnoremap <leader>ca :LspCodeAction<CR>         " code actions

" ── diagnostics ───────────────────────────────────────────────────────────────
nnoremap [d          :LspDiag prev<CR>         " jump to previous diagnostic
nnoremap ]d          :LspDiag next<CR>         " jump to next diagnostic
nnoremap <leader>df  :LspDiag show<CR>         " show diagnostics for current file
