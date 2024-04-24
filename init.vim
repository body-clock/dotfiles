call plug#begin()
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'mhartington/formatter.nvim'
Plug 'junegunn/fzf'
call plug#end()

set number
set clipboard=unnamedplus
set showmatch

syntax on 
