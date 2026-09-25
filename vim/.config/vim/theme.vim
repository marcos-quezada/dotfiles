scriptencoding utf-8
" ── theme ────────────────────────────────────────────────────────────────────
" default.vim ships with vim itself and works well on both foot and the
" FreeBSD VT console — chosen after directly comparing several built-ins
" (zaibatsu, habamax, quiet, industry, slate, murphy, retrobox) side by
" side on both terminals: zaibatsu/habamax read fine on foot but too bright
" on VT; default reads exactly right on VT already.
"
" default.vim deliberately does NOT set an explicit background at all —
" its own comment says so directly ("It doesn't define the Normal
" highlighting, it uses whatever the colors used to be") and it runs
" `set bg&` to reset to the terminal's own ambient default. That's exactly
" why it looked right on VT (whose native console background is already
" dark) but showed foot's own gameboy light-green background completely
" untouched — nothing overrode it. Force one explicitly here, without
" touching anything else default.vim provides.
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"   " foreground true colour sequence
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"   " background true colour sequence
set background=dark
colorscheme default

hi Normal      guibg=#000000 ctermbg=black
hi NonText     guibg=#000000 ctermbg=black
hi EndOfBuffer guibg=#000000 ctermbg=black

" ── cursor ───────────────────────────────────────────────────────────────────
" Nothing here previously set 'guicursor' at all, so the terminal's own
" cursor rendering was whatever foot's static [cursor] config in foot.ini
" said (fixed gameboy-palette colors), completely independent of vim's own
" theme — and hard to track against a dark background close in luminance
" to foot's own configured cursor color. Vim (8.2+, with termguicolors
" active and a terminal that supports it) sends a real OSC 12 escape code
" to recolour the actual terminal cursor based on the 'Cursor' highlight
" group below, overriding whatever the terminal's own static config says —
" a fixed, bright, unmistakable colour regardless of terminal or theme.
hi Cursor guifg=#000000 guibg=#ffffff
set guicursor=n-v-c:block-Cursor,i-ci-ve:ver25-Cursor,r-cr:hor20-Cursor
