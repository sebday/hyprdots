# Hyprland on Arch

Hightly opinionated Arch & Hyprland desktop with a custom theme system and Stylus & ViolentMonkey scripts to extend themes to the web.

Less than 650 [software packages](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/packages.txt) for a full dev desktop.

## Install 

`wget -qO- https://raw.githubusercontent.com/sebday/hyprdots/master/install.sh | bash`

## Brave

In `brave://flags/` search for "ozone" and set to Wayland  
In settings search for "fonts" and set the default to Caskaydia  
Extensions [Stylus](https://chromewebstore.google.com/detail/stylus/clngdbkpkpeebahjckkjfobafhncgmne), 
[PopupWindow](https://chromewebstore.google.com/detail/popup-window/nnlippelgfbglbhiccffmnmlnhmbjjpe) need installing if not in sync profile

## Firefox

Extensions [Stylus](https://addons.mozilla.org/en-GB/firefox/addon/styl-us/),
[ViolentMonkey](https://addons.mozilla.org/en-US/firefox/addon/violentmonkey/), 
[PopupWindow](https://addons.mozilla.org/en-GB/firefox/addon/popup-window/), 
[uBlock](https://github.com/gorhill/uBlock#ublock-origin).

## Theming

**Catppuccin**
[VSCode](https://marketplace.visualstudio.com/items?itemName=Catppuccin.catppuccin-vsc)
[Chrome](https://chromewebstore.google.com/detail/catppuccin-chrome-theme-m/bkkmolkhemgaeaeggcmfbghljjjoofoh)  
**Dracula**
[VSCode](https://draculatheme.com/visual-studio-code)
[Chrome](https://chromewebstore.google.com/detail/dracula-chrome-theme/gfapcejdoghpoidkfodoiiffaaibpaem)  
**Gruvbox**
[VSCode](https://github.com/sainnhe/gruvbox-material-vscode)  
**Nord**
[VSCode](https://marketplace.visualstudio.com/items?itemName=arcticicestudio.nord-visual-studio-code)  
**Tokyo Night**
[VSCode](https://marketplace.visualstudio.com/items?itemName=enkia.tokyo-night)  

To add a new theme, download a GTK theme into the `.themes` directory and add the following files:

- `btop.conf`
- `cursor.conf`
- `fuzzel.conf`
- `ghostty.conf`
- `hyprlock.conf`
- `mako.conf`
- `obsidian.conf`
- `soundcloud.css`
- `waybar.css`
- Brave Theme
- VS Code Theme


### Unixpr0n

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot1.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot1.png)
*fzf wallpaper selection, thunar and obsidian*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot2.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot2.png)
*btop, neovim and fastfetch*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot3.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot3.png)
*soundcloud*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot4.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot4.png)
*fuzzel menu*

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot5.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.config/hypr/screens/hypr_dracula_screenshot5.png)
*fuzzel keybinds*
