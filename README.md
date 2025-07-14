# Hyprland on Arch

[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/dracula/.config/hypr/hypr_dracula_screenshot2.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/dracula/.config/hypr/hypr_dracula_screenshot2.png)
*Dracula with a dark blue background for Soundcloud, btop, fastfetch and neovim*

## Install Arch

Install a base system

### Hyprland
```
sudo pacman -S hyprland hyprland-protocols hyprwayland-scanner xorg-xwayland waybar fuzzel greetd-tuigreet hyprlock hypridle hyprpaper hyprshot swappy cliphist mako nwg-look 
```

### Apps
```
sudo pacman -S zsh foot foot-terminfo git lazygit neovim ripgrep fd eza fzf bat sshfs btop nvtop fastfetch pipewire alsa-utils playerctl imv mpv cava thunar thunar-archive-plugin tumbler ffmpegthumbnailer xarchiver gvfs zip ebp-pixbuf-loader firefox transmission-gtk qalculate-gtk  noto-fonts-emoji
```

### Dev
```
sudo pacman -S python python-pip python-virtual-env nvm ruby luarocks ast-grep
```

## Setup greetd login

Edit `/etc/greetd/config.toml`
`command = "tuigreet --cmd hyprland"`

### Clone the dots
```
git clone git@github.com:sebday/debian-hyprdots.git
mv debian-hyprdots/* ~/ && cp -R debian-hyprdots/.* ~/
git submodule update --init
```

### AUR
```
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Other Software
`yay -Sy brave-bin cursor-bin insync obsidian`

## Notes

### GTK Theme

Set the theme, icons and font in **nwg-look**

### Brave

In `brave://flags/` search for "ozone" and set to Wayland

In settings search for "fonts" and set the default to Caskaydia

[Chrome Dracula Theme](https://chromewebstore.google.com/detail/dracula-chrome-theme/gfapcejdoghpoidkfodoiiffaaibpaem?hl=en-GB)

### Firefox

Install [Stylus](https://addons.mozilla.org/en-GB/firefox/addon/styl-us/), [PopupWindow](https://addons.mozilla.org/en-GB/firefox/addon/popup-window/) and [uBlock](https://github.com/gorhill/uBlock#ublock-origin)

### VS Code

`.config/Cursor/User/settings.json` has the overrides for the background color  

[VS Code Dracula Theme](https://draculatheme.com/visual-studio-code)
