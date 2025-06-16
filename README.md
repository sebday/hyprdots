# Hyprland on Debian Sid

*Tokyo Night with a dark blue background for Soundcloud, btop, fastfetch and vs code*
[![screenshot](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/tokyo/.config/hypr/hypr_tokyo_screenshot1.png)](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/tokyo/.config/hypr/hypr_tokyo_screenshot1.png)

## Install Hyprland
Install a base system with no desktop environment, add `contrib` and `non-free` and dist-update to sid.

`sudo apt install hyprland hyprland-protocols hyprwayland-scanner xwayland waybar fuzzel grim slurp swappy cliphist swayidle swaylock hyprpaper mako-notifier libnotify-bin nwg-look libglib2.0-bin bibata-cursor-theme fonts-noto-color-emoji`

- Fuzzel is a nice menu with icons
- Waybar is the taskbar
- Cliphist stores the clipboard to push into fuzzel
- Grim and slurp are for taking screenshots
- Hyprshot is not a package and is included in the repo
- Hyprpaper with scripts to set random or select using imv
- Swaylock is the lock screen - waiting for hyprlock in the repo
- Swayidle for auto locking the screen

## Install Apps
`sudo apt install zsh foot git firefox eza fzf sshfs btop nvtop fastfetch pipewire alsa-utils playerctl imv mpv calcurse qalculate-gtk cava thunar thunar-archive-plugin gvfs-backends webp-pixbuf-loader transmission libfuse2`

## Clone the dots and start hyprland
`git clone git@github.com:sebday/debian-hyprtokyo.git`

Copy the folder over home, reboot and run `hyprland`

## Oh my zsh
Install with auto suggestions and syntax highlighting.
```
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/plugins/zsh-syntax-highlighting
```

## GTK Theme
Set the theme, icons and font in nwg-look.

## Brave
Chromium disabled "custom stylesheets" in dev tools.

## Firefox
Copy ~/.firefox/userContent.css to the ~/.mozilla/firefox/profile/chrome directory \
In `about:config` set "toolkit.legacyUserProfileCustomizations.stylesheets" to `true` \

*Firefox and dev tools*
[![screenshot](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/tokyo/.config/hypr/hypr_tokyo_screenshot2.png)](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/tokyo/.config/hypr/hypr_tokyo_screenshot2.png)
