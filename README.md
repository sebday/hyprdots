# Hyprland on Debian Sid

*Tokyo Night with a dark blue background for Soundcloud, btop, fastfetch and vs code*
[![screenshot](https://imghost.lol/screenshots/2024-10-18-014509_hyprshot.png)](https://imghost.lol/screenshots/2024-10-18-014509_hyprshot.png)
*Firefox and dev tools*
[![screenshot](https://imghost.lol/screenshots/2024-10-18-235027_hyprshot.png)](https://imghost.lol/screenshots/2024-10-18-235027_hyprshot.png)

## Install Hyprland
Install a base system with no desktop environment, add `contrib` and `non-free` and dist-update to sid. (I like to install the ssh-server from tasksel and then remote in to install the rest)

`sudo apt install hyprland hyprland-protocols hyprwayland-scanner xwayland waybar fuzzel grim slurp cliphist swayidle swaylock hyprpaper mako-notifier libnotify-bin nwg-look libglib2.0-bin bibata-cursor-theme`

- Fuzzel is a nice menu with icons
- Waybar is the taskbar
- Cliphist stores the clipboard to push into fuzzel
- Grim and slurp are for taking screenshots
- Hyprshot is not a package and is included in the repo
- Hyprpaper is enough but simple - I want waypaper as well
- Nwg-look is a gtk themer
- Swaylock is the lock screen
- Swayidle for auto locking the screen

## Install required apps
`sudo apt install zsh foot git firefox eza fzf duf sshfs btop fastfetch pipewire alsa-utils playerctl pamixer pavucontrol imv mpv qalc cava thunar thunar-archive-plugin thunar-media-tags-plugin gvfs-backends transmission libfuse2`

## Clone the dots and start hyprland
`git clone git@github.com:sebday/debian-hyprtokyo.git ~/`

Reboot and run `hyprland`

## Oh my zsh
Install with auto suggestions and syntax highlighting now.
```
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/plugins/zsh-syntax-highlighting
```

## GTK Theme
Set the theme, icons and font in nwg-look.

## Firefox
Copy ~/.firefox/userContent.css to the ~/.mozilla/firefox/profile/chrome directory \
In `about:config` set "toolkit.legacyUserProfileCustomizations.stylesheets" to `true` \
Install the Stylus extension and import ~/.mozilla/firefox/stylus-export.json

## Resources
 - Firefox [https://addons.mozilla.org/en-GB/firefox/addon/tokyonight_vim/](https://addons.mozilla.org/en-GB/firefox/addon/tokyonight_vim/)
 - VS Code [https://marketplace.visualstudio.com/items?itemName=sebday.tokyo-night](https://marketplace.visualstudio.com/items?itemName=sebday.tokyo-night)
 
