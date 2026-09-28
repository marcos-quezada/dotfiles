" QML language server (qmlls) -- only loaded when a QML buffer is opened.
if exists('b:loaded_qml_ftplugin')
  finish
endif
let b:loaded_qml_ftplugin = 1

" no --build-dir: pure-QML projects use .qmlls.ini instead, which quickshell
" auto populates with its module import paths on the first run.
call LspAddServer ([#{
    \   name:     'qmlls',
    \   filetype: 'qml',
    \   path:     'qmlls6',
    \   args:     []
    \ }])
