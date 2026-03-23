""""""""""""""""""""
" SETTINGS SECTION "
""""""""""""""""""""

" General config
let mapleader = " "                   " set leader to Space
set ai cindent sw=2			              " indentation
set backspace=indent,eol,start        " modern text editor bckspc h
set expandtab				                  " convert tabs to spaces
set exrc				                      " source .vimrc files in project dirs
set secure                            " prevent sourced files from running shell commands
set foldmethod=syntax			            " folding (manual, indent, syntax, expr, marker, diff)
set hidden				                    " allow unsaved hidden buffers
set history=5000			                " number of items to keep in history
set hlsearch				                  " highlight search
set listchars=tab:▸\ ,eol:¬,space:. 	" custom symbols for hidden characters
set mouse=  				                  " disable mouse support
set noequalalways			                " do not resize window on close
set nu 				                        " add line numbers
set path+=**				                  " search subfolders (find, ...)
set ruler				                      " show cursor position
set sessionoptions-=options		        " do not save options in session
set sessionoptions-=blank		          " do not save empty options in buffer
set showcmd				                    " show command in status bar
set sm					                      " color matching braces/parenthesis
set t_vb=				                      " no viasual bell
set ts=2 sts=2    			              " TAB width
set completeopt=menu,menuone,noinsert	" show only menu for completion (no preview)
set pumheight=20			                " maximum menu height
set fillchars+=vert:\ 			          " use space as vertical script
set fillchars+=eob:\ 			            " use space as end of buffer (-) character
set signcolumn=number			            " show signs in number column
set nocursorline			                " hidecursorline highlight

" netrw/Explore (almost) like NERDTree
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netwr_browse_split = 4
let g:netwr_altv = 1
let g:netrw_winsize = 25

syntax on               " enable syntax highlighting
" set background=dark   " darker color scheme
set nobackup            " don't create pointless backup files; Use VCS instead
set autoread            " watch for file changes
set showmode            " show INSERT, VISUAL, etc. mode
set smarttab            " better backspace and tab functionality
set scrolloff=5         " show at least 5 lines above/below
filetype on             " enable filetype detection
filetype indent on      " enable filetype-specific indenting
filetype plugin on      " enable filetype-specific plugins
" colorscheme cobalt      " requires cobalt.vim to be in ~/.vim/colors

" column-width visual indication
let &colorcolumn=join(range(81,999),",")
highlight ColorColumn ctermbg=235 guibg=#001D2F

" tabs and indenting
set tabstop=2           " 2 spaces for tabs

" other
set guioptions=aAace    " don't show scrollbar in MacVim
" call pathogen#infect()  " use pathogen

" clipboard
set clipboard=unnamed   " allow yy, etc. to interact with OS X clipboard

" shortcuts
map <F2> :NERDTreeToggle<CR>

" remapped keys
inoremap {      {}<Left>
inoremap {<CR>  {<CR>}<Esc>O
inoremap {{     {
inoremap {}     {}

""""""""""""""""""""
" Included configs "
""""""""""""""""""""

" other config files
source ~/.config/vim/syntax.vim
