" C/C++ language server (clangd) -- only loaded when a C buffer is opened.
if exists('b:loaded_c_ftplugin')
  finish
endif
let b:loaded_c_ftplugin = 1

call LspAddServer ([#{
    \   name:     'clangd',
    \   filetype: 'c',
    \   path:     'clangd19',
    \   args:     []
    \ }])
