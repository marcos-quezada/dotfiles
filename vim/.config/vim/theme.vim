scriptencoding utf-8
" ── theme ────────────────────────────────────────────────────────────────────
" zaibatsu ships with vim 9+ and degrades gracefully on 8-colour terminals;
" no terminal-capability guards needed. Chosen after directly comparing
" several built-ins (zaibatsu, habamax, quiet, industry, slate, murphy,
" retrobox, default) side by side on both foot and the FreeBSD VT console:
" zaibatsu was the best middle ground on both. (default.vim looked right on
" VT, but doesn't set an explicit background at all — showed foot's own
" gameboy palette unmodified, and forcing one on top looked worse than
" zaibatsu's own considered palette.)
"
" Cursor visibility on foot: tried vim's own 'guicursor'/OSC 12 cursor-color
" override here — confirmed NOT to take effect (likely a foot/vim termcap
" capability mismatch for TERM=foot, not chased further). Fixed instead at
" the terminal level: foot.ini's own [cursor] section now uses a fixed
" black-on-white block, independent of any app's colorscheme.
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"   " foreground true colour sequence
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"   " background true colour sequence
set background=dark
colorscheme zaibatsu
