#!/bin/bash
# To install, run: wget -qO- https://raw.githubusercontent.com/sebday/hyprdots/dracula/install.sh | bash
# To test without making changes, run: ./install.sh --test
#

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration & Test Mode ---
TEST_MODE=false
if [[ "$1" == "--test" ]]; then
    TEST_MODE=true
fi

# --- Helper Functions ---

# Print a formatted message.
# Arguments:
#   $1: Message to print.
log() {
    echo "--- $1 ---"
}

# In test mode, redefine commands that would alter the system.
if [ "$TEST_MODE" = true ]; then
    log "RUNNING IN TEST MODE - NO SYSTEM CHANGES WILL BE MADE"
    sudo() {
        echo "[TEST] sudo" "$@"
    }
    git() {
        # Only echo modifying git commands
        if [[ "$1" == "clone" || "$1" == "submodule" ]]; then
            echo "[TEST] git" "$@"
        else
            # Allow non-modifying git commands to run, e.g. `git --version`
             /usr/bin/git "$@"
        fi
    }
    rsync() {
        echo "[TEST] rsync" "$@"
    }
    makepkg() {
        echo "[TEST] makepkg" "$@"
    }
    yay() {
        echo "[TEST] yay" "$@"
    }
    rm() {
        echo "[TEST] rm" "$@"
    }
fi

# --- Main Setup Functions ---

# Install packages from the official Arch repositories using pacman.
install_pacman_packages() {
    log "Updating system and installing pacman packages from packages.txt..."
    # Read packages from packages.txt, filter out comments and empty lines
    local packages
    packages=$(grep -v '^#' packages.txt | grep -v '^$' | tr '\n' ' ')
    sudo pacman -Syu --noconfirm $packages
}

# Configure greetd for automatic login.
configure_greetd() {
    log "Configuring greetd for autologin..."
    # Get the current username to set up the session.
    local user
    user=$(whoami) || { echo "Failed to get username"; exit 1; }

    # Create the greetd configuration file.
    # This will overwrite any existing configuration.
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
    # Check if mkinitcpio presets exist. This avoids errors in environments
    # without a kernel installed (e.g., Docker containers).
    if [ -n "$(ls /etc/mkinitcpio.d/*.preset 2>/dev/null)" ]; then
        local vconsole_conf="/etc/vconsole.conf"
        local font="ter-u16n"

        # This ensures that p10k glyphs render correctly in the TTY.
        # We check if the FONT is already set and update it, otherwise add it.
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
    # Using a temporary directory for cloning to avoid conflicts.
    local temp_clone_dir
    temp_clone_dir=$(mktemp -d)
    
    # Using HTTPS for public access on a new machine.
    git clone https://github.com/sebday/debian-hyprdots.git "$temp_clone_dir"
    
    # rsync is used to copy all files, including hidden ones, to the home directory.
    # This turns the home directory into a git repository for dotfiles management.
    rsync -av "$temp_clone_dir/" "$HOME/"
    
    # Clean up the temporary directory.
    rm -rf "$temp_clone_dir"
    
    # Initialize git submodules from the dotfiles.
    # We need to change to the home directory as it is now the git work tree.
    (cd "$HOME" && git submodule update --init)
}

# Install yay, an AUR helper.
install_yay() {
    log "Installing AUR helper (yay)..."
    # We need to ensure we're not in a directory that will be deleted.
    local original_dir=$PWD
    local temp_build_dir
    temp_build_dir=$(mktemp -d)
    
    cd "$temp_build_dir"
    git clone https://aur.archlinux.org/yay.git .
    # makepkg requires running as a non-root user.
    # -s installs dependencies, -i installs the package.
    makepkg -si --noconfirm
    
    # Return to the original directory and clean up.
    cd "$original_dir"
    rm -rf "$temp_build_dir"
}

# Install packages from the AUR using yay.
install_aur_packages() {
    log "Installing AUR packages from packages-aur.txt..."
    # Read packages from packages-aur.txt
    local aur_packages
    aur_packages=$(grep -v '^#' packages-aur.txt | grep -v '^$' | tr '\n' ' ')
    yay -Sy --noconfirm $aur_packages
}

# Set the Plymouth boot screen theme.
set_boot_screen() {
    log "Setting Plymouth boot screen theme..."
    # Check if mkinitcpio presets exist. This avoids errors in environments
    # without a kernel installed (e.g., Docker containers).
    if [ -n "$(ls /etc/mkinitcpio.d/*.preset 2>/dev/null)" ]; then
        sudo plymouth-set-default-theme -R spinner
    else
        log "WARNING: No mkinitcpio presets found. Skipping Plymouth theme setup."
        log "This is expected in a containerized environment like Docker."
    fi
}

# --- Main Execution ---

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

# Run the main function
main 