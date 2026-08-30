#!/usr/bin/env bash
# Symlink hyprdots config into ~/.config and ~/.local/bin.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME="${HOME:-$(eval echo ~)}"

PACKAGES=0
for arg in "$@"; do
	case "$arg" in
	--packages) PACKAGES=1 ;;
	esac
done

link() {
	local src="$1" dest="$2"
	mkdir -p "$(dirname "$dest")"
	ln -sfn "$src" "$dest"
	printf '  %s -> %s\n' "$dest" "$src"
}

echo "hyprdots install (branch: omarchy, repo: $REPO)"
echo "symlinks:"

link "$REPO/.config/hypr/monitors.lua" "$HOME/.config/hypr/monitors.lua"
link "$REPO/.config/hypr/bindings.lua" "$HOME/.config/hypr/bindings.lua"
link "$REPO/.config/hypr/autostart.lua" "$HOME/.config/hypr/autostart.lua"
link "$REPO/.config/hypr/windows.lua" "$HOME/.config/hypr/windows.lua"
link "$REPO/.config/nvim" "$HOME/.config/nvim"
mkdir -p "$REPO/.config/nvim/lua/plugins"
ln -sfn "$HOME/.local/state/omarchy/current/theme/neovim.lua" "$REPO/.config/nvim/lua/plugins/theme.lua"
printf '  %s -> %s\n' "$REPO/.config/nvim/lua/plugins/theme.lua" "$HOME/.local/state/omarchy/current/theme/neovim.lua"
link "$REPO/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
link "$REPO/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
link "$REPO/.config/bash/aliases" "$HOME/.config/bash/aliases"
link "$REPO/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
link "$REPO/.config/omarchy/extensions/omarchy-menu.jsonc" "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
link "$REPO/.config/omarchy/shell.json" "$HOME/.config/omarchy/shell.json"

link_plugin() {
	local id="$1" src="$2"
	link "$src" "$HOME/.config/omarchy/plugins/$id"
	chmod +x "$src/bin/"* 2>/dev/null || true
}

link_plugin evo.bar "$HOME/projects/omarchy-bar"
link_plugin evo.tray "$HOME/projects/omarchy-tray"
link_plugin evo.cloudflare "$HOME/projects/omarchy-cloudflare"
link_plugin evo.cursor "$HOME/projects/omarchy-cursor"
link_plugin evo.github "$HOME/projects/omarchy-github"
link_plugin evo.homeassistant "$HOME/projects/omarchy-homeassistant"
link_plugin evo.insync "$HOME/projects/omarchy-insync"
link_plugin evo.media "$HOME/projects/omarchy-media"
link_plugin evo.monitor "$HOME/projects/omarchy-monitor"
link_plugin evo.notifications "$HOME/projects/omarchy-notifications"
link_plugin evo.shopify "$HOME/projects/omarchy-shopify"
link_plugin evo.steam "$HOME/projects/omarchy-steam"
link_plugin evo.stocks "$HOME/projects/omarchy-stocks"
link_plugin evo.shaders "$HOME/projects/omarchy-shaders"
link "$REPO/.config/imv/config" "$HOME/.config/imv/config"
link "$REPO/.local/bin/omasnap-edit" "$HOME/.local/bin/omasnap-edit"
chmod +x "$REPO/.local/bin/omasnap-edit"
link "$REPO/.local/bin/omarchy-capture-edit-last" "$HOME/.local/bin/omarchy-capture-edit-last"
link "$REPO/.local/bin/omarchy-capture-compositor" "$HOME/.local/bin/omarchy-capture-compositor"
link "$REPO/.config/omasnap/omasnap.conf" "$HOME/.config/omasnap/omasnap.conf"
link "$REPO/.local/bin/omarchy-capture-record-theme-switching" "$HOME/.local/bin/omarchy-capture-record-theme-switching"
chmod +x "$REPO/.local/bin/omarchy-capture-record-theme-switching"
link "$REPO/.local/bin/omarchy-layout" "$HOME/.local/bin/omarchy-layout"
link "$REPO/.local/bin/fastfetch-hyprdots" "$HOME/.local/bin/fastfetch-hyprdots"
link "$REPO/.local/bin/omarchy-package-list" "$HOME/.local/bin/omarchy-package-list"
link "$REPO/.local/bin/omarchy-theme-cycle" "$HOME/.local/bin/omarchy-theme-cycle"
link "$REPO/.local/bin/omarchy-theme-list" "$HOME/.local/bin/omarchy-theme-list"
link "$REPO/.local/bin/omarchy-theme-switcher" "$HOME/.local/bin/omarchy-theme-switcher"
link "$REPO/.local/bin/omarchy-theme-bg-prev" "$HOME/.local/bin/omarchy-theme-bg-prev"

link "$REPO/.config/omarchy/themed/colors.css.tpl" "$HOME/.config/omarchy/themed/colors.css.tpl"
link "$REPO/.config/omarchy/themed/shoelace-hex.css.tpl" "$HOME/.config/omarchy/themed/shoelace-hex.css.tpl"
link "$REPO/.config/omarchy/themed/libadwaita-gtk.css.tpl" "$HOME/.config/omarchy/themed/libadwaita-gtk.css.tpl"
link "$REPO/.config/omarchy/themed/gtk-4.0-gtk.css.tpl" "$HOME/.config/omarchy/themed/gtk-4.0-gtk.css.tpl"
link "$REPO/.config/omarchy/themed/gtk-4.0-gtk-dark.css.tpl" "$HOME/.config/omarchy/themed/gtk-4.0-gtk-dark.css.tpl"
link "$REPO/.config/omarchy/gtk" "$HOME/.config/omarchy/gtk"
link "$REPO/.config/omarchy/bin/theme-filter.sh" "$HOME/.config/omarchy/bin/theme-filter.sh"
link "$REPO/.config/omarchy/bin/gtk-css-apply.sh" "$HOME/.config/omarchy/bin/gtk-css-apply.sh"
link "$REPO/.config/omarchy/hooks/theme-set.d/gtk-activate.hook" "$HOME/.config/omarchy/hooks/theme-set.d/gtk-activate.hook"
chmod +x "$REPO/.config/omarchy/hooks/theme-set.d/gtk-activate.hook"
chmod +x "$REPO/.config/omarchy/bin/theme-filter.sh"
chmod +x "$REPO/.config/omarchy/bin/gtk-css-apply.sh"
chmod +x "$REPO/.local/bin/omarchy-theme-list"
chmod +x "$REPO/.local/bin/omarchy-theme-switcher"
link "$REPO/.config/omarchy/web/shared/css" "$HOME/.config/omarchy/web/shared/css"
link "$REPO/.config/omarchy/web/shared/orangemonkey-theme-reloader.js" "$HOME/.config/omarchy/web/shared/orangemonkey-theme-reloader.js"
link "$REPO/.config/omarchy/hooks/theme-set.d/web-css-symlink.hook" "$HOME/.config/omarchy/hooks/theme-set.d/web-css-symlink.hook"
link "$REPO/.config/omarchy/hooks/font-set.d/gtk-font.hook" "$HOME/.config/omarchy/hooks/font-set.d/gtk-font.hook"
chmod +x "$REPO/.config/omarchy/hooks/font-set.d/gtk-font.hook"
link "$REPO/.config/omarchy/hooks/font-set.d/foot-font.hook" "$HOME/.config/omarchy/hooks/font-set.d/foot-font.hook"
chmod +x "$REPO/.config/omarchy/hooks/font-set.d/foot-font.hook"
mkdir -p "$HOME/.local/share/nautilus-python/extensions"
link "$REPO/.local/share/nautilus-python/extensions/omarchy-gtk-reload.py" "$HOME/.local/share/nautilus-python/extensions/omarchy-gtk-reload.py"
link "$REPO/.config/omarchy/backgrounds" "$HOME/.config/omarchy/backgrounds"
link "$HOME/projects/omarchy-darkula-theme" "$HOME/.config/omarchy/themes/darkula"
link "$REPO/.config/systemd/user/darkhttpd.service" "$HOME/.config/systemd/user/darkhttpd.service"
link "$HOME/.local/state/omarchy/current/theme" "$HOME/.config/omarchy/web/current"

if command -v darkhttpd >/dev/null 2>&1; then
	systemctl --user daemon-reload
	systemctl --user enable --now darkhttpd.service
	echo "darkhttpd: $(systemctl --user is-active darkhttpd.service)"
else
	echo "darkhttpd not installed — skip: pacman -S darkhttpd && $0"
fi

if command -v omarchy >/dev/null 2>&1; then
	omarchy theme refresh
	if font="$(omarchy font current 2>/dev/null)" && [[ -n "$font" ]]; then
		omarchy font set "$font"
	fi
	omarchy restart shell 2>/dev/null || true
else
	echo "omarchy not on PATH — run 'omarchy theme refresh' after install"
fi

link "$REPO/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"

if (( PACKAGES )); then
	echo "packages:"
	bash "$REPO/.install/packages.sh" apply
fi

echo "done"
