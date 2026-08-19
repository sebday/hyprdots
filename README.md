# Hyprland on Arch
 
My Arch & Hyprland desktop with themes.
 
Created so I can easily reinstall Arch to my exact liking with a quad monitor setup and [software](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.install/packages.txt) for a full desktop.
 
Massive thanks to [Vaxry](https://blog.vaxry.net/) for reigniting my long-time love for [tinkering](https://sebday.dev/2025/07/18-desktop-appreciation/) with my desktop.
 
Thank you to [DHH](https://world.hey.com/dhh) for Omarchy with loads of cool ideas to copy.
 
Thank you to [Bjarne](https://github.com/bjarneo) for some gorgeous themes.

## Features
  
- Master `colors.toml`
- Generated themes for Obsidian and Neovim
- Generated icons based on Papirus
- Themed websites (Soundcloud, Grok, X etc)
  
## Quickshell
  
- Evoshell
	- Evobar
		- Icons
		- Popups
			- Weather
			- Github
			- Cursor usage
			- Stocks
			- Cloudflare
		- Network
			- Stats
			- Transmission
		- Evoplayer Mini (not built)
		- Media
			- Now playing
			- Library
		- Steam
	- Evopanel
		- Shopify
		- Evoplayer
	- Evoside
    - Settings
		- Calculator
		- Tasks
	- Evosys
		- Menu
		- Wallpaper
		- Themes
		- Notifications
		- Lock screen
  
### Design tokens
  
- fieldset
	- legend
- stat box
	- stat
	- label
  
All colours, fonts, spacing, opacity, radius via `Theme.*` — no hardcoded values in QML.
  
## Install
  
`wget -qO- sebday.dev/installer | bash`
  
### Brave
  
In `brave://flags/` search for "ozone" and set to *Wayland*  
In `brave://settings/` search for "fonts" and set the default to *Caskaydia*  
In `brave://settings/appearance` set the theme to *GTK*

#### Extensions
  
Auto loaded through my Brave sync but also needed on Firefox:
Replaced ViolentMonkey with [OrangeMonkey](https://chromewebstore.google.com/detail/orangemonkey/ekmeppjgajofkpiofbebgcbohbmfldaf) for theming websites and [PopupWindow](https://addons.mozilla.org/en-GB/firefox/addon/popup-window/) to pop Soundcloud or Youtube into a window with no titlebar.
  
Load the orangemonkey script from `.themes/shared/` and set it to auto-update.
  
## Apps
  
### Neovim
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/neovim.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/neovim.png)
  
### Media library
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/media-library.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/media-library.png)
  
### Screenshot editor
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/screenshot-editor.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/screenshot-editor.png)
  
### Theme switcher
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/theme-switcher.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/shared/screenshots/theme-switcher.png)
  
## Themes
  
### Catppuccin
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/catppuccin/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/catppuccin/preview.png)
  
### Dracula
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/dracula/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/dracula/preview.png)
  
### Everforest
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/everforest/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/everforest/preview.png)

### Gruvbox

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/gruvbox/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/gruvbox/preview.png)

### Hackerman

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/hackerman/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/hackerman/preview.png)

### Matte Black

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/matte-black/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/matte-black/preview.png)

### Miasma

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/miasma/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/miasma/preview.png)

### Nord

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/nord/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/nord/preview.png)

### Lumon

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/lumon/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/lumon/preview.png)

### Osaka Jade

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/osaka-jade/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/osaka-jade/preview.png)
  
### Tokyo Night
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/tokyo-night/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/tokyo-night/preview.png)
  
### Vanta Black
  
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.themes/vantablack/preview.png)](https://github.com/sebday/hyprdots/blob/master/.themes/vantablack/preview.png)
