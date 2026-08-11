" ============================================================
" Minimal Vi/Vim Configuration
" ============================================================
set nocompatible              " Disable legacy vi compatibility (enables standard features)
syntax on                     " Enable syntax highlighting
set number                    " Show line numbers

" Indentation
set autoindent                " Maintain indent of current line
set smartindent               " Smart autoindenting on new lines
set tabstop=4                 " Tab width is 4 spaces
set shiftwidth=4              " Indent width is 4 spaces
set expandtab                 " Use spaces instead of tabs

" Search
set incsearch                 " Search as you type
set ignorecase                " Case insensitive search...
set smartcase                 " ...unless uppercase letters are used

" User Interface
set backspace=indent,eol,start " Allow backspacing over everything in insert mode
set ruler                     " Show cursor position in footer
