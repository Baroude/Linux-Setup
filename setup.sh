#!/bin/bash


# MAJ

sudo apt update -y
sudo apt upgrade -y
sudo apt install vim libncursesw5-dev git curl zsh vlc filezilla terminator python3-pip imagemagick build-essential clangd ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip doxygen -y

# Récupération du thème nord

wget https://github.com/EliverLara/Nordic/releases/download/2.0.0/Nordic-darker-v40.tar.xz
tar xf Nordic-darker-v40.tar.xz
sudo mv Nordic-darker-v40 /usr/share/themes/
gsettings set org.gnome.desktop.interface gtk-theme "Nordic-darker-v40"
gsettings set org.gnome.desktop.wm.preferences theme "Nordic-darker-v40"
rm Nordic-darker-v40.tar.xz 
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
sudo mkdir /usr/share/fonts/iosevka 
sudo mv iosevka.ttc /usr/share/fonts/iosevka/iosevka.ttc
rm super-ttc-iosevka-11.2.2.zip
fc-cache --force --verbose

# Starship 
cd ~/Documents/Linux-Setup/
sh -c "$(curl -fsSL https://starship.rs/install.sh)"

# Neovim 

cd ~
git clone https://github.com/neovim/neovim
cd neovim && make 
sudo make install
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt -y install nodejs
sudo npm i -g typescript typescript-language-server bash-language-server pyright

# Auto update nvim 
cd ~/Documents/Linux-Setup/
chmod +x nvimUpdate.sh
(crontab -l 2>/dev/null; echo "0 12 * * 1 /home/mathias/Documents/Linux-Setup/nvimUpdate.sh ") | crontab -

