# Hyprland on Arch

*Dracula with a dark blue background for Soundcloud, btop, fastfetch and vs code*
[![screenshot](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/dracula/.config/hypr/hypr_dracula_screenshot1.png)](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/dracula/.config/hypr/hypr_dracula_screenshot1.png)

## Install 

### Arch btw

Install a base system.

### Install
#### Hyprland
```
sudo pacman -S hyprland hyprland-protocols hyprwayland-scanner xorg-xwayland waybar fuzzel greetd-tuigreet hyprlock hypridle hyprpaper hyprshot swappy cliphist mako nwg-look 
```

#### Apps
```
sudo pacman -S zsh foot git neovim eza fzf bat sshfs btop nvtop fastfetch pipewire alsa-utils playerctl imv mpv qalculate-gtk cava thunar thunar-archive-plugin tumbler ffmpegthumbnailer xarchiver gvfs wzip ebp-pixbuf-loader firefox transmission-gtk noto-fonts-emoji
```

#### Dev
```
sudo pacman -S python python-pip python-virtual-env nvm ruby
```

### Setup greetd login

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

### ZSH

The modules are now included as git modules so nothing needs to be done

- Autocomplete
- Interative cd
- Syntax highlighting

### GTK Theme

Set the theme, icons and font in **nwg-look**

### Brave

In `brave://flags/` search for "ozone" and set to Wayland

In settings search for "fonts" and set the default to Caskaydia

Chromium disabled "custom stylesheets" in dev tools so unable to style  

[Chrome Dracula Theme](https://chromewebstore.google.com/detail/dracula-chrome-theme/gfapcejdoghpoidkfodoiiffaaibpaem?hl=en-GB)

### Firefox

Copy `~/.firefox/userContent.css` to the `~/.mozilla/firefox/profile/chrome` directory  
In `about:config` set "toolkit.legacyUserProfileCustomizations.stylesheets" to `true`  

### VS Code

`.config/Cursor/User/settings.json` has the overrides for the background color  

[VS Code Dracula Theme](https://draculatheme.com/visual-studio-code)
