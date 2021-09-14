#!/bin/bash

# MAJ

sudo apt update -y
sudo apt upgrade -y
sudo apt install -y vim firefox libncursesw5-dev git


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
mv starship.toml ~/.config/starship.toml
echo 'eval "$(starship init bash)"' >> ~/.bashrc

# Cleaning

rm Nordic-darker-v40.tar.xz 

# Update shell

source ~/.bashrc
