# Omadots

Personal Omarchy overrides: quad-monitor layout, Brave/file-manager bindings, numpad workspaces, capture scripts, OrangeMonkey web CSS, and shell aliases.

## Install

```bash
cd ~/Projects/omadots
./install.sh
```

Web CSS needs `darkhttpd` (`pacman -S darkhttpd`). Install the OrangeMonkey userscript once from:

```
http://localhost:8008/shared/orangemonkey-theme-reloader.js
```

**Fonts (GTK apps):** `omarchy font set` only updates fontconfig (bar, terminals). Nautilus and other GTK apps use `gsettings font-name` — synced by `.config/omarchy/hooks/font-set.d/gtk-font.hook` into `~/.config/gtk-3.0/settings.ini` and `gtk-4.0/settings.ini`.

**Brave:** stock Omarchy `BrowserThemeColor` policy via `omarchy-theme-set-browser` (not GTK).

**Files (Nautilus):** `gtk-css-apply.sh` writes only the libadwaita palette (`libadwaita-gtk.css`, ~4KB) to `gtk.css`. The Nautilus extension reloads that palette from `current/theme` on `SIGUSR1` — no 250KB widget CSS. Restart Nautilus once after extension updates.

**Themes:** light themes (`mode = "light"` in `colors.toml`) are hidden from the bar theme picker and `omarchy-theme-cycle`. `omarchy theme list` still shows all stock themes. To show everything: `OMARCHY_HIDE_LIGHT_THEMES=0` or `touch ~/.config/omarchy/theme-filter-all`.

**Neovim:** `install.sh` links `.config/nvim`. `nvim` with no args opens the Snacks projects picker (`~/Projects/*`). After first install or plugin changes: `nvim --headless "+Lazy! sync" +qa`.

## Display layout

The Display bar popup (`SUPER + CTRL + D` or the monitor icon) includes a monitor graphic at the bottom. Click a top/bottom strip to toggle the bar or notifications on that monitor — click again to remove it. Defaults start with `DP-1` only.

```bash
hyprctl monitors
omarchy-layout bar get
omarchy-layout bar set DP-1 top    # toggle bar on DP-1 top edge
omarchy-layout notifications set HDMI-A-2 top
hyprctl layers
```

**About → Package List** in the Omarchy menu opens a floating terminal with a categorized breakdown of explicit pacman packages (AUR tagged inline), plus mise and orphans.

## Keybindings

- `SUPER + E` — editor (nvim)
- `SUPER + L` — lock screen
- `SUPER + 1/2/3` — Brave / incognito / Tor
- `SUPER + 4`, `SUPER + SHIFT + F` — file manager
- `SUPER + 5` — Obsidian
- `SUPER + 6–0` — unbound; use numpad or `SUPER + TAB` for workspaces
- `SUPER + PRINT` — annotate last screenshot; `ALT + PRINT` — monitor; `SUPER + ALT + PRINT` — all monitors

