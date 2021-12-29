#!/bin/bash


# MAJ

sudo apt update -y
sudo apt upgrade -y
sudo apt install vim libncursesw5-dev git curl zsh vlc filezilla terminator python3-pip imagemagick -y

# Récupération du thème nord

wget https://github.com/EliverLara/Nordic/releases/download/2.0.0/Nordic-darker-v40.tar.xz
tar xf Nordic-darker-v40.tar.xz
sudo mv Nordic-darker-v40 /usr/share/themes/
gsettings set org.gnome.desktop.interface gtk-theme "Nordic-darker-v40"
gsettings set org.gnome.desktop.wm.preferences theme "Nordic-darker-v40"

# Récupération wallpaper

gsettings set org.gnome.desktop.background picture-uri 'file:///home/mathias/Documents/Linux-Setup/images/forest.jpg'

#sudo wget -O /usr/share/backgrounds/gnome/nord.jpg https://i.redd.it/4s62fcy37st61.jpg
#pip3 install pywal
#wal -i /usr/share/backgrounds/gnome/nord.jpg


# Cbonsai

git clone https://gitlab.com/jallbrit/cbonsai
cd cbonsai
sudo make install
cd ..
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
wget https://github.com/be5invis/Iosevka/releases/download/v11.2.2/super-ttc-iosevka-11.2.2.zip
unzip super-ttc-iosevka-11.2.2.zip
sudo mkdir /usr/share/fonts/ioveska 
mv iosevka.ttc /usr/share/fonts/ioveska/iosevka.ttc
rm super-ttc-iosevka-11.2.2.zip
fc-cache --force --verbose

# Starship 
cd ~/Documents/Linux-Setup/
sh -c "$(curl -fsSL https://starship.rs/install.sh)"

# Neovim 

sudo wget https://github.com/neovim/neovim/releases/download/v0.5.0/nvim.appimage
sudo mv nvim.appimage /usr/local/bin/nvim
sudo chmod +x /usr/local/bin/nvim 
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt -y install nodejs
# Cleaning

rm Nordic-darker-v40.tar.xz 

# Update shell

source ~/.bashrc
source ~/.zshrc
