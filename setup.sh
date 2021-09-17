#!/bin/bash

cd ~/

# MAJ

sudo apt update -y
sudo apt upgrade -y
sudo apt install vim firefox libncursesw5-dev git curl zsh vlc filezilla  -y


# Récupération du thème nord

wget https://github.com/EliverLara/Nordic/releases/download/2.0.0/Nordic-darker-v40.tar.xz
tar xf Nordic-darker-v40.tar.xz
sudo mv Nordic-darker-v40 /usr/share/themes/
gsettings set org.gnome.desktop.interface gtk-theme "Nordic-darker-v40"
gsettings set org.gnome.desktop.wm.preferences theme "Nordic-darker-v40"

# Récupération wallpaper

sudo wget -O /usr/share/backgrounds/gnome/nord.jpg https://i.redd.it/4s62fcy37st61.jpg
gsettings get org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/nord.jpg'

# Cbonsai

git clone https://gitlab.com/jallbrit/cbonsai
cd cbonsai
sudo make install
echo "cbonsai -p" >> ~/.bashrc
echo "cbonsai -p" >> ~/.zshrc
cd ~/
# zsh, oh my zsh

chsh -s /bin/zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
cd ~/.oh-my-zsh/plugins/
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
git clone https://github.com/zsh-users/zsh-autosuggestions
vim ~/.zshrc
cd ~/

#Font
cd /tmp
git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
./install.sh Go-Mono
cd ..
rm -rf nerd-fonts/
fc-cache --force --verbose

# Starship 

sh -c "$(curl -fsSL https://starship.rs/install.sh)"
cp ./starship.toml ~/.config/starship.toml
echo 'eval "$(starship init bash)"' >> ~/.bashrc
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Cleaning

rm Nordic-darker-v40.tar.xz 

# Update shell

source ~/.bashrc
source ~/.zshrc
