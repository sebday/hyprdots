#!/bin/bash
# Shared helpers for theme scripts (source from other scripts).

THEME_DIR="${THEME_DIR:-$HOME/.themes}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$THEME_DIR/shared/templates}"

toml_val() {
    local key="$1" toml="$2"
    grep "^$key " "$toml" 2>/dev/null | sed 's/.*= *"//;s/".*//' | tr -d '\n'
}

# First line of file, trimmed (e.g. icons.theme).
read_icons_theme_name() {
    local f="$1"
    [ -f "$f" ] || return 1
    tr -d '\n' < "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Path for GTK icon lookup: Adwaita or ~/.local/share/icons/<name>.
theme_icon_path_for_dir() {
    local theme_dir="$1"
    local icon_path="${HOME}/.local/share/icons/Adwaita"
    local icon_name
    if [ -f "$theme_dir/icons.theme" ] && icon_name=$(read_icons_theme_name "$theme_dir/icons.theme") && [ -n "$icon_name" ]; then
        icon_path="${HOME}/.local/share/icons/$icon_name"
    fi
    printf '%s' "$icon_path"
}

# e.g. tokyo-night -> Tokyo Night
theme_display_name() {
    local slug="$1" word display_name=""
    for word in $(echo "$slug" | tr '-' ' '); do
        display_name="${display_name}${word^} "
    done
    printf '%s' "${display_name% }"
}

paths_resolved_equal() {
    local a b
    a=$(cd "$1" 2>/dev/null && pwd -P) || return 1
    b=$(cd "$2" 2>/dev/null && pwd -P) || return 1
    [ "$a" = "$b" ]
}

# Expand shared/templates/*.tpl into theme_dir from colors.toml.
# Skips existing outputs except shoelace-hex.css (regenerated each apply for Violentmonkey).
process_theme_templates() {
    local theme_dir="$1"
    [ -n "$theme_dir" ] || return 1
    local toml="$theme_dir/colors.toml"
    [ -f "$toml" ] || return 0

    local sed_script key value hex icon_path filename tpl output
    sed_script=$(mktemp)
    while IFS='=' read -r key value; do
        key="${key//[\"\' ]/}"
        [[ $key && $key != \#* ]] || continue
        value="${value#*[\"\']}"
        value="${value%%[\"\']*}"
        printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$sed_script"
        printf 's|{{ %s_strip }}|%s|g\n' "$key" "${value#\#}" >> "$sed_script"
        if [[ $value =~ ^# ]]; then
            hex="${value#\#}"
            printf 's|{{ %s_rgb }}|%d,%d,%d|g\n' "$key" "$(( 0x${hex:0:2} ))" "$(( 0x${hex:2:2} ))" "$(( 0x${hex:4:2} ))" >> "$sed_script"
        fi
    done < "$toml"

    icon_path=$(theme_icon_path_for_dir "$theme_dir")
    printf 's|{{ icon_path }}|%s|g\n' "$icon_path" >> "$sed_script"

    for tpl in "$TEMPLATES_DIR"/*.tpl; do
        [ -f "$tpl" ] || continue
        filename=$(basename "$tpl" .tpl)
        output="$theme_dir/$filename"
        [ -f "$output" ] && [ "$filename" != "shoelace-hex.css" ] && continue
        sed -f "$sed_script" "$tpl" > "$output"
    done
    rm -f "$sed_script"
}

# Copy theme files from current/ into ~/.config (mako, hypr theme, btop).
install_theme_manifest() {
    local current="${CURRENT_PATH:-$THEME_DIR/current}"
    local config="${HOME}/.config"

    if [ -f "$current/mako.ini" ]; then
        mkdir -p "$config/mako"
        cp "$current/mako.ini" "$config/mako/config"
    fi
    if [ -f "$current/hyprland.conf" ]; then
        mkdir -p "$config/hypr"
        cp "$current/hyprland.conf" "$config/hypr/theme.conf"
    fi
    if [ -f "$current/btop.theme" ]; then
        mkdir -p "$config/btop/themes"
        cp "$current/btop.theme" "$config/btop/themes/current.theme"
        [ -f "$config/btop/btop.conf" ] && sed -i 's|^color_theme =.*|color_theme = "current"|' "$config/btop/btop.conf"
    fi
}

themes_sync_icon_theme_gsettings() {
    local f="${CURRENT_PATH:-$THEME_DIR/current}/icons.theme"
    local icon_theme
    icon_theme=$(read_icons_theme_name "$f") || return 0
    [ -n "$icon_theme" ] || return 0
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
}

# Override with OBSIDIAN_VAULT_DIR if your vault moves.
themes_sync_obsidian_modular() {
    local vault="${OBSIDIAN_VAULT_DIR:-$HOME/onedrive/notes}"
    local theme_css="${THEME_DIR}/current/obsidian.css"
    [ -f "$theme_css" ] || return 0

    local modular_dir="$vault/.obsidian/themes/Modular"
    local shared_css="${THEME_DIR}/shared/css/obsidian.css"
    local shared_manifest="${THEME_DIR}/shared/obsidian.conf"
    local appearance="$vault/.obsidian/appearance.json"
    local updated_json

    mkdir -p "$modular_dir"
    if [ ! -f "$modular_dir/manifest.json" ] && [ -f "$shared_manifest" ]; then
        cp "$shared_manifest" "$modular_dir/manifest.json"
    fi
    if [ -f "$shared_css" ] && [ -f "$theme_css" ]; then
        cat "$shared_css" "$theme_css" > "$modular_dir/theme.css"
    fi

    mkdir -p "$(dirname "$appearance")"
    if [ -f "$appearance" ]; then
        updated_json=$(cat "$appearance")
    else
        updated_json='{}'
    fi
    updated_json=$(echo "$updated_json" | jq --arg theme "obsidian" '.theme = $theme' | jq --arg cssTheme "Modular" '.cssTheme = $cssTheme')
    echo "$updated_json" > "$appearance"
}

themes_sync_walker_style_symlink() {
    local current="${CURRENT_PATH:-$THEME_DIR/current}"
    local dest_root="${XDG_CONFIG_HOME:-$HOME/.config}/walker/themes"
    local name="${WALKER_THEME_NAME:-current}"
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/walker/config.toml"
    local src=""

    if [ -f "$current/walker/style.css" ]; then
        src="$current/walker/style.css"
    elif [ -f "$current/walker.css" ]; then
        src="$current/walker.css"
    elif [ -f "$current/walker-style.css" ]; then
        src="$current/walker-style.css"
    else
        return 0
    fi
    [ -f "$cfg" ] || return 0

    mkdir -p "$dest_root/$name"
    ln -sfn "$(realpath "$src")" "$dest_root/$name/style.css"
    if grep -q '^theme = ' "$cfg"; then
        sed -i "s/^theme = .*/theme = \"$name\"/" "$cfg"
    fi
}

# Install ~/.themes/current/vscode-theme into editor extension dirs and set workbench.colorTheme.
themes_sync_vscode_generated_extension() {
    local SRC="${1:-$HOME/.themes/current/vscode-theme}"
    [ -f "$SRC/package.json" ] || return 0

    local publisher name version theme_label ext_id safe_label ext_dir settings
    publisher=$(jq -r '.publisher // "sebday"' "$SRC/package.json")
    name=$(jq -r '.name // empty' "$SRC/package.json")
    version=$(jq -r '.version // "1.0.0"' "$SRC/package.json")
    theme_label=$(jq -r '.contributes.themes[0].label // empty' "$SRC/package.json")
    [ -n "$name" ] && [ -n "$theme_label" ] || return 0
    ext_id="${publisher}.${name}-${version}"
    safe_label=$(printf '%s' "$theme_label" | sed 's/[&\]/\\&/g')

    for pair in \
        "$HOME/.cursor/extensions|$HOME/.config/Cursor/User/settings.json" \
        "$HOME/.vscode/extensions|$HOME/.config/Code/User/settings.json" \
        "$HOME/.vscode-oss/extensions|$HOME/.config/VSCodium/User/settings.json"
    do
        ext_dir="${pair%%|*}"
        settings="${pair#*|}"
        [ -n "$ext_dir" ] && [ -n "$settings" ] || continue
        [ -d "$(dirname "$settings")" ] || continue

        mkdir -p "$ext_dir"
        rm -rf "$ext_dir/$ext_id"
        cp -r "$SRC" "$ext_dir/$ext_id"

        [ -f "$settings" ] || echo '{}' > "$settings"
        if grep -q '"workbench.colorTheme"' "$settings"; then
            sed -i --follow-symlinks -E "s/(\"workbench\\.colorTheme\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\\1${safe_label}\\2/" "$settings"
        else
            sed -i --follow-symlinks -E '0,/\{/{s/\{/{\n    "workbench.colorTheme": "'"$safe_label"'",/}' "$settings"
        fi
    done
}
