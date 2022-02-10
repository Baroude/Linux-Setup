#!/bin/bash


# MAJ

sudo apt update -y
sudo apt upgrade -y
sudo apt install vim libncursesw6-dev git curl zsh vlc filezilla terminator python3-pip imagemagick build-essential clangd ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip doxygen -y


chsh -s /bin/zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cd ~/.oh-my-zsh/plugins/
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
git clone https://github.com/zsh-users/zsh-autosuggestions

cd ~/Documents/Linux-Setup/

git clone https://gitlab.com/jallbrit/cbonsai
cd cbonsai
sudo make install
cd ..
sudo rm -rf cbonsai/

# Starship 
cd ~/Documents/Linux-Setup/
sh -c "$(curl -fsSL https://starship.rs/install.sh)"

# Neovim 

cd ~
git clone https://github.com/neovim/neovim
cd neovim && make 
sudo make install
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
 #      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt -y install nodejs
sudo npm i -g typescript typescript-language-server bash-language-server pyright

# Auto update nvim 
cd ~/Documents/Linux-Setup/
chmod +x nvimUpdate.sh
(crontab -l 2>/dev/null; echo "0 12 * * 1 /home/mathias/Documents/Linux-Setup/nvimUpdate.sh ") | crontab -

