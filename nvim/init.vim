source $HOME/.config/nvim/vim-plug/plugins.vim

inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm() : "\<C-g>u\<CR>"
