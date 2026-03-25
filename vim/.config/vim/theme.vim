" ── theme ────────────────────────────────────────────────────────────────────
" zaibatsu ships with vim 9+ and degrades gracefully on 8-colour terminals;
" no terminal-capability guards needed.
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"   " foreground true colour sequence
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"   " background true colour sequence
set background=dark
colorscheme zaibatsu
