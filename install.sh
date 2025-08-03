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

# Configure darkhttpd for stylus theme hot-reloading.
configure_stylus_theming() {
    log "Configuring darkhttpd for Stylus theming..."
    local user
    user=$(whoami) || { echo "Failed to get username"; exit 1; }

    # Enable lingering for the user to run services at boot without login.
    log "Enabling user lingering for $user..."
    sudo loginctl enable-linger "$user"

    # Create the systemd user service file.
    log "Creating systemd user service for darkhttpd..."
    local user_systemd_dir="$HOME/.config/systemd/user"
    mkdir -p "$user_systemd_dir"
    cat <<EOT > "$user_systemd_dir/darkhttpd.service"
[Unit]
Description=darkhttpd user web server for stylus themes

[Service]
ExecStart=/usr/bin/darkhttpd %h/.themes --port 8008 --no-listing

[Install]
WantedBy=default.target
EOT

    # Enable the user service.
    log "Enabling darkhttpd user service..."
    systemctl --user daemon-reload
    systemctl --user enable --now darkhttpd
}


main() {
    log "Starting Hyprland setup on Arch Linux"

    install_pacman_packages
    configure_greetd
    clone_dotfiles
    install_yay
    install_aur_packages
    set_boot_screen
    configure_stylus_theming

    log "Setup complete! Please reboot your system."
}

main 