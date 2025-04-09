#!/bin/bash

# Exit on error
set -e

echo "Setting up Hyprland environment on Debian"

# Update package repositories and add contrib and non-free
echo "Updating package sources and upgrading to sid..."
sudo apt update
sudo apt install -y apt-transport-https
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
echo "deb http://deb.debian.org/debian/ unstable main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list
sudo apt update
sudo apt full-upgrade -y

# Install Hyprland and required packages
echo "Installing Hyprland and core components..."
sudo apt install -y hyprland hyprland-protocols hyprwayland-scanner xwayland waybar \
  fuzzel grim slurp swappy cliphist swayidle swaylock hyprpaper mako-notifier \
  libnotify-bin nwg-look libglib2.0-bin bibata-cursor-theme fonts-noto-color-emoji

# Install required applications
echo "Installing applications..."
sudo apt install -y zsh foot git firefox eza fzf duf sshfs btop nvtop \
  fastfetch pipewire alsa-utils playerctl pamixer imv mpv qalculate-gtk \
  cava thunar thunar-archive-plugin gvfs-backends webp-pixbuf-loader transmission libfuse2

# Clone dotfiles
echo "Cloning dotfiles..."
if git -C ~ status &>/dev/null; then
  echo "Git repository already exists in home directory, skipping clone"
else
  echo "Cloning dotfiles directly into home directory..."
  git clone https://github.com/sebday/debian-hyprdots.git ~
fi

# Install Oh My Zsh and plugins
echo "Installing Oh My Zsh and plugins..."
if [ -d ~/.oh-my-zsh ]; then
  echo "Oh My Zsh already installed, skipping installation"
else
  sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install ZSH plugins
if [ ! -d ~/.oh-my-zsh/plugins/zsh-autosuggestions ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/plugins/zsh-autosuggestions
fi

if [ ! -d ~/.oh-my-zsh/plugins/zsh-syntax-highlighting ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/plugins/zsh-syntax-highlighting
fi

if [ ! -d ~/powerlevel10k ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
fi

# Configure .zshrc if not already configured
if ! grep -q "zsh-autosuggestions" ~/.zshrc; then
  sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
fi

if ! grep -q "powerlevel10k" ~/.zshrc; then
  echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
fi

# Make ZSH the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Changing default shell to ZSH..."
  chsh -s $(which zsh)
fi

echo "Setup complete! You should reboot your system and then run 'hyprland' to start the desktop environment."
echo "After first login, run 'nwg-look' to set theme, icons and font." 