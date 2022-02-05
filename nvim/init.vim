let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

source $HOME/.config/nvim/vim-plug/plugins.vim

set tabstop=4
set smarttab
set expandtab
set autoindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set number
set noerrorbells
set hidden
set nobackup
set nowritebackup
set noswapfile
set confirm 
set scrolloff=8
set termguicolors
set background=dark
let g:everforest_background='dark'
let g:everforest_transparent_background = 1
colorscheme everforest
highlight Search ctermfg=0
let mapleader = " "
set completeopt=menu,menuone,noselect

lua require('config')


nnoremap <C-n> :NvimTreeToggle<CR>
nnoremap <leader>r :NvimTreeRefresh<CR>
nnoremap <leader>n :NvimTreeFindFile<CR>e
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>af <C-^>
nnoremap <silent> <esc> :noh<cr> 

