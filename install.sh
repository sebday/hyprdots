#!/bin/bash
# To install, run: wget -qO- https://raw.githubusercontent.com/sebday/hyprdots/dracula/install.sh | bash

# Exit immediately if a command exits with a non-zero status.
set -e

log() {
    echo "--- $1 ---"
}

# Install packages from the official Arch repositories using pacman.
install_pacman_packages() {
    log "Updating system and installing pacman packages from packages.txt..."
    local packages
    packages=$(grep -vE '^#|^$' packages.txt | tr '\n' ' ')
    sudo pacman -Syu --noconfirm $packages
}

# Configure greetd for automatic login.
configure_greetd() {
    log "Configuring greetd for autologin..."
    local user
    user=$(whoami) || { echo "Failed to get username"; exit 1; }
    cat <<EOT | sudo tee /etc/greetd/config.toml > /dev/null
[terminal]
vt = 1

[default_session]
command = "hyprland"
user = "$user"

[initial_session]
command = "hyprland"
user = "$user"
EOT
}

# Configure the virtual console font for TTY.
configure_vconsole() {
    log "Configuring TTY font..."
    if [ -n "$(ls /etc/mkinitcpio.d/*.preset 2>/dev/null)" ]; then
        local vconsole_conf="/etc/vconsole.conf"
        local font="ter-u16n"
        if sudo grep -q "^FONT=" "$vconsole_conf" 2>/dev/null; then
            sudo sed -i "s/^FONT=.*/FONT=$font/" "$vconsole_conf"
        else
            echo "FONT=$font" | sudo tee -a "$vconsole_conf" > /dev/null
        fi
    else
        log "WARNING: No mkinitcpio presets found. Skipping TTY font setup."
        log "This is expected in a containerized environment like Docker."
    fi
}

# Clone the dotfiles repository and set it up.
clone_dotfiles() {
    log "Cloning and setting up dotfiles..."
    local temp_clone_dir
    temp_clone_dir=$(mktemp -d)
    git clone https://github.com/sebday/debian-hyprdots.git "$temp_clone_dir"
    rsync -av "$temp_clone_dir/" "$HOME/"
    rm -rf "$temp_clone_dir"
    (cd "$HOME" && git submodule update --init)
}

# Install yay, an AUR helper.
install_yay() {
    log "Installing AUR helper (yay)..."
    local original_dir=$PWD
    local temp_build_dir
    temp_build_dir=$(mktemp -d)
    cd "$temp_build_dir"
    git clone https://aur.archlinux.org/yay.git .
    makepkg -si --noconfirm
    cd "$original_dir"
    rm -rf "$temp_build_dir"
}

# Install packages from the AUR using yay.
install_aur_packages() {
    log "Installing AUR packages from packages-aur.txt..."
    local aur_packages
    aur_packages=$(grep -vE '^#|^$' packages-aur.txt | tr '\n' ' ')
    yay -Sy --noconfirm $aur_packages
}

# Set the Plymouth boot screen theme.
set_boot_screen() {
    log "Setting Plymouth boot screen theme..."
    if [ -n "$(ls /etc/mkinitcpio.d/*.preset 2>/dev/null)" ]; then
        sudo plymouth-set-default-theme -R spinner
    else
        log "WARNING: No mkinitcpio presets found. Skipping Plymouth theme setup."
        log "This is expected in a containerized environment like Docker."
    fi
}

main() {
    log "Starting Hyprland setup on Arch Linux"

    install_pacman_packages
    configure_greetd
    configure_vconsole
    clone_dotfiles
    install_yay
    install_aur_packages
    set_boot_screen

    log "Setup complete! Please reboot your system."
}

main 