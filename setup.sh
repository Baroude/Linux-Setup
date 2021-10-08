#!/bin/bash


# MAJ

sudo apt update -y
sudo apt upgrade -y
sudo apt install vim firefox libncursesw5-dev git curl zsh vlc filezilla terminator -y

# Récupération du thème nord

wget https://github.com/EliverLara/Nordic/releases/download/2.0.0/Nordic-darker-v40.tar.xz
tar xf Nordic-darker-v40.tar.xz
sudo mv Nordic-darker-v40 /usr/share/themes/
gsettings set org.gnome.desktop.interface gtk-theme "Nordic-darker-v40"
gsettings set org.gnome.desktop.wm.preferences theme "Nordic-darker-v40"

# Récupération wallpaper

sudo wget -O /usr/share/backgrounds/gnome/nord.jpg https://i.redd.it/4s62fcy37st61.jpg
gsettings get org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/nord.jpg'

# Cbonsai

git clone https://gitlab.com/jallbrit/cbonsai
cd cbonsai
sudo make install
cd ~/
rm -rf cbonsai/
# zsh, oh my zsh

chsh -s /bin/zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cd ~/.oh-my-zsh/plugins/
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
git clone https://github.com/zsh-users/zsh-autosuggestions

cd ~/Documents/Linux-Setup/

#Font
cd /tmp
git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
./install.sh Go-Mono
cd ..
rm -rf nerd-fonts/
fc-cache --force --verbose

# Starship 
cd ~/Documents/Linux-Setup/
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
cp ./starship.toml ~/.config/starship.toml

# zshrc

cp ./.zshrc ~/.zshrc


# Neovim 

sudo wget https://github.com/neovim/neovim/releases/download/v0.5.0/nvim.appimage
sudo chmod +x /usr/local/bin/nvim.appimage
sudo mv /usr/local/bin/nvim.appimage /usr/local/bin/nvim 
curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
curl -sL install-node.now.sh/lts | bash
cp -r ./nvim/vim-plug ~/.config/nvim
cp ./nvim/init.vim ~/.config/nvim

# Cleaning

rm Nordic-darker-v40.tar.xz 

# Update shell

source ~/.bashrc
source ~/.zshrc
