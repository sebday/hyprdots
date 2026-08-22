#!/bin/bash
# To install, run: wget -qO- sebday.dev/installer | bash

# Exit immediately if a command exits with a non-zero status.
set -e

INSTALL_DIR="${HOME}/.install"

log() {
    echo "--- $1 ---"
}

# Install script dependencies
install_dependencies() {
    log "Installing script dependencies..."
    sudo pacman -Syu --noconfirm git base-devel rsync curl jq fuse2
}

# Clone the dotfiles repository and set it up.
clone_dotfiles() {
    log "Cloning and setting up dotfiles..."
    local temp_clone_dir
    temp_clone_dir=$(mktemp -d)
    git clone https://github.com/sebday/hyprdots.git "$temp_clone_dir"
    rsync -av "$temp_clone_dir/" "$HOME/"
    rm -rf "$temp_clone_dir"
}

clone_companion_repo() {
    local name="$1"
    local url="$2"
    local dest="${3:-${HOME}/projects/${name}}"
    if [[ -d "${dest}/.git" ]]; then
        log "${name} already present at ${dest}"
        return 0
    fi
    log "Cloning ${name} into ${dest}..."
    mkdir -p "$(dirname "$dest")"
    git clone "$url" "$dest"
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
# Lines in packages.txt that are not in the official repos (e.g. AUR-only brave-bin) are skipped.
install_pacman_packages() {
    log "Updating system and installing pacman packages from packages.txt..."
    local sync_packages=()
    local pkg
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        pkg="${pkg%%[[:space:]]*}"
        if pacman -Si "$pkg" &>/dev/null; then
            sync_packages+=("$pkg")
        fi
    done < <(grep -vE '^#|^$' "${INSTALL_DIR}/packages.txt" | awk '{print $1}')
    sudo pacman -Syu --noconfirm "${sync_packages[@]}"
}

# Configure greetd for automatic login (wrapper waits for network then starts Hyprland).
configure_greetd() {
    log "Configuring greetd for autologin..."
    local user greet_cmd
    user=$(whoami) || { echo "Failed to get username"; exit 1; }
    greet_cmd="$HOME/.local/bin/hypr-greetd"
    cat <<EOT | sudo tee /etc/greetd/config.toml > /dev/null
[terminal]
vt = 1

[default_session]
command = "$greet_cmd"
user = "$user"

[initial_session]
command = "$greet_cmd"
user = "$user"
EOT
    sudo systemctl enable greetd
}

# Install packages from the AUR using yay
install_aur_packages() {
    log "Installing AUR packages from packages-aur.txt..."
    local aur_packages
    aur_packages=$(grep -vE '^#|^$' "${INSTALL_DIR}/packages-aur.txt" | tr '\n' ' ')
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
    local user
    user=$(whoami)
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

install_hypr_bin() {
    log "Installing hypr bin scripts..."
    local local_bin="${HOME}/.local/bin"
    mkdir -p "$local_bin"
    for script in hypr-greetd hypr-launch; do
        if [[ -x "${INSTALL_DIR}/bin/${script}" ]]; then
            install -m 755 "${INSTALL_DIR}/bin/${script}" "${local_bin}/${script}"
        fi
    done
}

link_evoshell() {
    log "Linking evoshell..."
    local evoshell_root="${EVOSHELL_ROOT:-${HOME}/projects/evoshell}"
    clone_companion_repo evoshell https://github.com/sebday/evoshell.git "$evoshell_root"
    bash "${evoshell_root}/scripts/install"
}

link_evoplayer() {
    log "Linking evoplayer into evoshell..."
    local evoplayer_root="${EVOPLAYER_ROOT:-${HOME}/projects/evoplayer}"
    clone_companion_repo evoplayer https://github.com/sebday/evoplayer.git "$evoplayer_root"
    bash "${evoplayer_root}/scripts/install"
}

# Limit journal size and trim old logs (audit: journald was ~4 GB before vacuum).
configure_journald() {
    log "Configuring journald..."
    sudo mkdir -p /etc/systemd/journald.conf.d
    if [[ ! -f /etc/systemd/journald.conf.d/size-limit.conf ]]; then
        sudo tee /etc/systemd/journald.conf.d/size-limit.conf > /dev/null <<'EOF'
[Journal]
SystemMaxUse=500M
EOF
        sudo systemctl restart systemd-journald
    fi
    log "Trimming journals older than 1 day..."
    sudo journalctl --vacuum-time=1d
}

# Enable UFW with a default-deny incoming policy (desktop: allow outbound only).
configure_ufw() {
    log "Configuring UFW firewall..."
    if ! command -v ufw >/dev/null 2>&1; then
        log "ufw not installed; skip"
        return 0
    fi

    sudo systemctl enable ufw

    if ! sudo ufw status 2>/dev/null | grep -q 'Status: active'; then
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
    else
        log "UFW already active"
    fi

    sudo ufw status verbose | head -20 || true
}

# Google Ads Editor via Wine under /opt/google-ads-editor (no native Linux build).
configure_google_ads_editor() {
    log "Configuring Google Ads Editor (Wine)..."
    if ! command -v wine >/dev/null 2>&1; then
        log "wine not installed; skip"
        return 0
    fi

    local opt_root=/opt/google-ads-editor
    local prefix="${opt_root}/prefix"
    local msi_url=https://dl.google.com/adwords_editor/google_ads_editor.msi
    local msi_path="${opt_root}/install/google_ads_editor.msi"
    local launcher="${opt_root}/bin/google-ads-editor"
    local desktop="${HOME}/.local/share/applications/google-ads-editor.desktop"
    local user
    user=$(whoami)

    sudo mkdir -p "${opt_root}"/{prefix,install,bin}
    sudo chown -R "${user}:${user}" "${opt_root}"

    export WINEPREFIX="${prefix}"
    export WINEARCH=win64
    export WINEDEBUG=-all

    if [[ ! -d "${prefix}/drive_c" ]]; then
        log "Initializing Wine prefix..."
        wineboot --init
        winetricks -q win10
        winetricks -q vcrun2019 || winetricks -q vcrun2017 || true
    fi

    if ! find "${prefix}/drive_c" -iname 'google_ads_editor.exe' -print -quit 2>/dev/null | grep -q .; then
        log "Downloading Google Ads Editor MSI (~200 MB)..."
        curl -fL --retry 3 -o "${msi_path}" "${msi_url}"
        log "Installing Google Ads Editor..."
        wine msiexec /i "${msi_path}"
    else
        log "Google Ads Editor already installed in prefix"
    fi

    local exe_path
    exe_path=$(find "${prefix}/drive_c" -iname 'google_ads_editor.exe' 2>/dev/null | head -1)
    if [[ -z "${exe_path}" ]]; then
        log "WARNING: google_ads_editor.exe not found after install"
        return 0
    fi

    cat >"${launcher}" <<EOF
#!/usr/bin/env bash
export WINEPREFIX="${prefix}"
export WINEARCH=win64
export WINEDEBUG=-all
exec wine '${exe_path}' "\$@"
EOF
    chmod +x "${launcher}"

    local icon_path
    icon_path=$(find "${prefix}/drive_c/users/${user}/AppData/Local/Google/Google Ads Editor" \
        -path '*/assets/adslogo.png' 2>/dev/null | head -1)
    [[ -z "${icon_path}" ]] && icon_path=wine

    mkdir -p "${HOME}/.local/share/applications"
    cat >"${desktop}" <<EOF
[Desktop Entry]
Type=Application
Name=Google Ads Editor
Comment=Google Ads Editor (Wine)
Exec=${launcher}
Icon=${icon_path}
Categories=Office;
StartupNotify=true
EOF

    log "Google Ads Editor: ${launcher}"
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
    install_hypr_bin
    link_evoshell
    link_evoplayer
    install_pacman_packages
    install_yay
    install_aur_packages
    configure_greetd
    install_mise_tools
    set_boot_screen
    configure_darkhttpd
    configure_networking
    configure_timesync
    configure_journald
    configure_ufw
    configure_google_ads_editor

    log "Setup complete! Please reboot your system."
}

main 