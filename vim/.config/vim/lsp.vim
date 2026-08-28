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
"
" qmllint location varies vy platform, same as qmltestrunner (see
" tests/qml.bats):
"   FreeBSD: /usr/local/lib/qt6/bin/qmllint (qt6-declarative; not on PATH by
"   default)
"   macOS:   qmllint on PATH via the qt brew formula
function! s:FindQmllint() abort
    if executable('qmllint')
        return 'qmllint'
    elseif executable('/usr/local/lib/qt6/bin/qmllint')
        return '/usr/local/lib/qt6/bin/qmllint'
    endif
    return ''
endfunction

let s:qmllint_bin = s:FindQmllint()

function! s:RunQmllint() abort
    if empty(s:qmllint_bin)
        echoerr 'qmllint not fount on PATH or at /usr/local/lib/qt6/bin/qmllint'
        return
    endif
    let l:output = systemlist(s:qmllint_bin . ' ' . shellescape(expand('%')) . ' 2>&1')
    copen 10
endfunction

nnoremap <silent> <leader>lq :call <SID>RunQmllint()<CR>

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
