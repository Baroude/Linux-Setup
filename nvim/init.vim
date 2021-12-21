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

let g:tokyonight_style = "night"
colorscheme tokyonight
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

lua << EOF

require'lualine'.setup {
  options = {
    icons_enabled = true,
    theme = 'tokyonight',
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  extensions = {}
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
