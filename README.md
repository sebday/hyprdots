# Hyprland on Arch

My Arch & Hyprland desktop with seven hot-swap themes. If you try this out you need to remove my quad monitor setup in hyprland.conf, and I doubt you want my gtk bookmarks.

Less than 630 [software packages](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/packages.txt) for a full dev desktop.

Massive thanks to [Vaxry](https://blog.vaxry.net/) for reigniting my long-time love for [tinkering](https://sebday.dev/desktop-appreciation/) with my desktop.

# Install 

`wget -qO- https://raw.githubusercontent.com/sebday/hyprdots/master/install.sh | bash`

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

Install and enable the darkttpd service `.config/systemd/`

Load the violentmonkey script from `.themes/shared/` and set it to auto-update.

# Themes

To add a new theme, download a GTK theme into the `.themes/` directory, icons into `.local/share/icons/` and wallpapers into `.themes/new/wallpapers/`

Install a VS Code and Obsidian theme, then edit create the theme files:

- `btop.conf` - system stats
- `cursor.conf` - editor
- `fuzzel.conf` - app launcher
- `ghostty.conf` - terminal
- `hyprlock.conf` - lock screen
- `mako.conf` - notifications
- `icons.conf` - icon pack
- `obsidian.conf` - notes
- `soundcloud.css` - music player
- `waybar.css` - taskbar

Violentmonkey and darkhttpd are used to theme GitHub, Soundcloud, GoogleHome Cameras, Youtube and X in Brave.

To style more websites add a new css in `.themes/shared` and edit `violentmonkey.js` to include the new site.

# Unixpr0n

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
