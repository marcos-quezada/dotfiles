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
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"   " foreground true colour sequence
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"   " background true colour sequence
set background=dark
colorscheme zaibatsu

" ── cursor ───────────────────────────────────────────────────────────────────
" Nothing here previously set 'guicursor' at all, so the terminal's own
" cursor rendering was whatever foot's static [cursor] config in foot.ini
" said (fixed gameboy-palette colors), completely independent of vim's own
" theme — and hard to track against zaibatsu's own dark background. Vim
" (8.2+, with termguicolors active and a terminal that supports it) sends a
" real OSC 12 escape code to recolour the actual terminal cursor based on
" the 'Cursor' highlight group below, overriding whatever the terminal's
" own static config says — a fixed, bright, unmistakable colour regardless
" of terminal or theme.
hi Cursor guifg=#000000 guibg=#ffffff
set guicursor=n-v-c:block-Cursor,i-ci-ve:ver25-Cursor,r-cr:hor20-Cursor
