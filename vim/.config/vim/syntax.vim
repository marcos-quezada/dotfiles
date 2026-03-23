" configure vim syntax and colorscheme

" if &t_Co == 256 "for vim only
if $COLORTERM == "truecolor" || $COLORTERM == "24bit"
  set termguicolors       " enable true color support
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum" " tmux true color support
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum" " tmux true color support
endif

syntax on
set background=dark     " background color (light|dark)
let g:one_allow_italics = 1

packadd lsp

" Register the qmlls server for QML files
call LspAddServer([#{
    \   name: 'qmlls',
    \   filetype: 'qml',
    \   path: 'qmlls6',
    \   args: ['--build-dir', 'build']
    \ }])

" LSP Keybindings for yegappan/lsp
nnoremap <leader>gd :LspGotoDefinition<CR>
nnoremap <leader>gr :LspPeekReferences<CR>
nnoremap <leader>gi :LspPeekImplementation<CR>
nnoremap <leader>gt :LspPeekTypedef<CR>
nnoremap <leader>rn :LspRename<CR>
nnoremap <leader>ca :LspCodeAction<CR>
nnoremap K :LspHover<CR>

" Diagnostic navigation
nnoremap [d :LspDiag prev<CR>
nnoremap ]d :LspDiag next<CR>
nnoremap <leader>df :LspDiag show<CR>
