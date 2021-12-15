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
colorscheme tokyonight
set termguicolors
highlight Search ctermfg=0


" TreeSitter
lua <<EOF
  require'nvim-treesitter.configs'.setup {
    highlight = {
      enable = true,
    },
    indent = {
      enable = false,
    },
    rainbow = {
      enable = true,
      -- Highlight also non-parentheses delimiters, boolean or table: lang -> boolean
      extended_mode = true,
    },
    context_commentstring = {
      enable = true,
      enable_autocmd = true,
    }
  }
EOF

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction

inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

map <C-n> :NERDTreeToggle<CR>
