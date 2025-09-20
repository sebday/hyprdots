#!/bin/bash
# To install, run: wget -qO- sebday.dev/install | bash

# Exit immediately if a command exits with a non-zero status.
set -e

log() {
    echo "--- $1 ---"
}

# Install script dependencies
install_dependencies() {
    log "Installing script dependencies..."
    sudo pacman -Syu --noconfirm git base-devel rsync
}

# Clone the dotfiles repository and set it up.
clone_dotfiles() {
    log "Cloning and setting up dotfiles..."
    local temp_clone_dir
    temp_clone_dir=$(mktemp -d)
    git clone https://github.com/sebday/hyprdots.git "$temp_clone_dir"
    rsync -av "$temp_clone_dir/" "$HOME/"
    rm -rf "$temp_clone_dir"
    (cd "$HOME" && git submodule update --init --recursive)
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
    sudo systemctl enable greetd
}

# Install packages from the AUR using yay
install_aur_packages() {
    log "Installing AUR packages from packages-aur.txt..."
    local aur_packages
    aur_packages=$(grep -vE '^#|^$' packages-aur.txt | tr '\n' ' ')
    yay -Sy --noconfirm $aur_packages
}

# Set the Plymouth boot screen theme.
set_boot_screen() {
    log "Setting Plymouth boot screen theme..."
    # Add plymouth to mkinitcpio hooks
    if grep -q '^HOOKS=' /etc/mkinitcpio.conf && ! grep -q 'plymouth' /etc/mkinitcpio.conf; then
        sudo sed -i '/^HOOKS=/s/\b\(udev\b\)/\1 plymouth/' /etc/mkinitcpio.conf
    fi
    sudo plymouth-set-default-theme -R spinner
}

# Configure darkhttpd for stylus theme hot-reloading
configure_darkhttpd() {
    # Enable lingering for the user to run services at boot without login.
    log "Enabling user lingering for $user..."
    sudo loginctl enable-linger "$user"

    # Enable the user service.
    log "Enabling darkhttpd user service..."
    systemctl --user daemon-reload
    systemctl --user enable --now darkhttpd
}

# Configure networking with systemd-networkd.
configure_networking() {
    log "Enabling systemd-networkd..."
    sudo systemctl enable systemd-networkd
}

# Configure network time synchronization.
configure_timesync() {
    log "Enabling systemd-timesyncd..."
    sudo systemctl enable systemd-timesyncd
}

# Install and configure mise for managing dev tools.
install_mise_tools() {
    log "Installing mise and setting up global dev tools..."
    
    # Check if mise was installed successfully
    if command -v mise &> /dev/null; then
        log "Installing Node.js with mise..."
        mise use --global node@latest
    else
        log "ERROR: mise installation failed. Skipping dev tool setup."
    fi
}

main() {
    log "Starting Hyprland setup on Arch Linux"

    install_dependencies
    clone_dotfiles
    cd "$HOME"
    install_pacman_packages
    install_yay
    install_aur_packages
    configure_greetd
    install_mise_tools
    set_boot_screen
    configure_darkhttpd
    configure_networking
    configure_timesync

    log "Setup complete! Please reboot your system."
}

main 