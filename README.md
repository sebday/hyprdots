# Hyprland on Arch

Opinionated Arch & Hyprland desktop seven themes.

Each theme styles the terminal (ghostty), browser (brave), music player (soundcloud), system stats (btop), editor (cursor), file manager (thunar), app launcher (fuzzel), taskbar (waybar), notifications (mako), lock screen (hyprlock), notes (obsidian), icons and matched wallpapers.

Less than 630 [software packages](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/packages.txt) for a full dev desktop.

## Install 

`wget -qO- https://raw.githubusercontent.com/sebday/hyprdots/master/install.sh | bash`

## Brave

In `brave://flags/` search for `ozone` and set to Wayland  
In settings search for "fonts" and set the default to `Caskaydia`  
In appearance set the theme to `GTK`

## Firefox

Install extensions [Stylus](https://addons.mozilla.org/en-GB/firefox/addon/styl-us/),
[ViolentMonkey](https://addons.mozilla.org/en-US/firefox/addon/violentmonkey/), 
[PopupWindow](https://addons.mozilla.org/en-GB/firefox/addon/popup-window/), 
[uBlock](https://github.com/gorhill/uBlock#ublock-origin).

Install violentmonkey scripts from `.themes/shared`

## Theming

To add a new theme, download a GTK theme into the `.themes` directory and add the following:

- `btop.conf`
- `cursor.conf`
- `fuzzel.conf`
- `ghostty.conf`
- `hyprlock.conf`
- `mako.conf`
- `icons.conf`
- `obsidian.conf`
- `soundcloud.css`
- `waybar.css`
- VS Code Theme
- Obsidian Theme


### Unixpr0n

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot1.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot1.png)
*fzf wallpaper selection, thunar and obsidian*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_catppuccin.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_catppuccin.png)
*Catppuccin theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_dracula.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_dracula.png)
*Dracula theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_gruvboxdark.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_gruvboxdark.png)
*Gruvbox Dark theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_gruvboxlight.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_gruvboxlight.png)
*Gruvbox Light theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_nord.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_nord.png)
*Nord theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_rosepine.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_rosepine.png)
*Rose Pine theme*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_tokyo.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/theme_tokyo.png)
*Tokyo theme*
