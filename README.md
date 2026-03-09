# Hyprland on Arch

My Arch & Hyprland desktop with themes. 

Created so I can easily reinstall Arch to my exact liking, with all [software](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/packages.txt) for a full dev desktop. 

Quad monitor setup in hyprland.conf, and I doubt you want my gtk bookmarks.

Massive thanks to [Vaxry](https://blog.vaxry.net/) for reigniting my long-time love for [tinkering](https://sebday.dev/desktop-appreciation/) with my desktop.

# Install 

`wget -qO- sebday.dev/install | bash`

## Brave

In `brave://flags/` search for `ozone` and set to Wayland  
In settings search for "fonts" and set the default to `Caskaydia`  
In appearance set the theme to `GTK`

## Firefox

Install extensions 
[ViolentMonkey](https://addons.mozilla.org/en-US/firefox/addon/violentmonkey/), 
[PopupWindow](https://addons.mozilla.org/en-GB/firefox/addon/popup-window/), 
[uBlock](https://github.com/gorhill/uBlock#ublock-origin).

## Violentmonkey

Load the violentmonkey script from `.themes/shared/` and set it to auto-update.

# Themes

Theme system with `colors.toml` as master. Templates in `~/.themes/shared/templates/` are processed at switch time; GTK theme is generated from a shared base.

**Switch theme:** `themes-switch.sh select` (fuzzel) or `themes-switch.sh refresh` (rebuild current)

**Add a new theme:**
1. Create `~/.themes/<name>/colors.toml` with 24 colors (accent, cursor, foreground, background, selection_*, color0–color15)
2. Add `backgrounds/`, `btop.theme`, `neovim.lua`, `vscode.json`, `icons.theme`, `preview.png`
3. Run `themes-switch.sh select` — templates generate configs on first switch
4. Optional: add custom `hyprland.conf` or `waybar.css` to skip template output

**Directory layout:** `~/.themes/current/` is the live theme (atomic swap from `next/`). Source theme dirs stay clean; generated files live in `current/` only.

Violentmonkey and darkhttpd theme GitHub, Soundcloud, GoogleHome Cameras, Youtube and X in Brave. Add CSS in `.themes/shared` and edit `violentmonkey.js` for more sites.

# Unixpr0n

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/hypr_dracula_screenshot1.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/hypr_dracula_screenshot1.png)
*fzf wallpaper selection, thunar and obsidian*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_catppuccin.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_catppuccin.png)
*Catppuccin theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_dracula.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_dracula.png)
*Dracula theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_gruvboxdark.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_gruvboxdark.png)
*Gruvbox Dark theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_gruvboxlight.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_gruvboxlight.png)
*Gruvbox Light theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_nord.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_nord.png)
*Nord theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_rosepine.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_rosepine.png)
*Rose Pine theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_tokyo.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screenshots/theme_tokyo.png)
*Tokyo theme*
