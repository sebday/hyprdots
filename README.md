# Hyprland on Debian Sid

*Dracula with a dark blue background for Soundcloud, btop, fastfetch and vs code*
[![screenshot](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/dracula/.config/hypr/hypr_dracula_screenshot1.png)](https://raw.githubusercontent.com/sebday/debian-hyprdots/refs/heads/dracula/.config/hypr/hypr_dracula_screenshot1.png)

## Install 

### Debian Sid

Install a base system with no desktop environment, add `contrib` and `non-free` and dist-upgrade to sid.

### Hyprland

`sudo apt install hyprland hyprland-protocols hyprwayland-scanner xwayland waybar fuzzel grim slurp swappy cliphist greetd tuigreet gtklock hyprpaper mako-notifier libnotify-bin nwg-look libglib2.0-bin bibata-cursor-theme fonts-noto-color-emoji`

- Fuzzel is a nice menu with icons
- Waybar is the taskbar
- Cliphist stores the clipboard to push into fuzzel
- Grim and slurp are for taking screenshots
- Hyprshot is not a package and is included in the repo
- Hyprpaper with scripts to set random or select using imv
- Tuigreet is a nice frontend to greetd
- Gtklock while we wait for hyprlock to come into the repo

### Apps

`sudo apt install zsh foot git eza fzf bat sshfs btop nvtop fastfetch pipewire alsa-utils playerctl imv mpv calcurse qalculate-gtk cava thunar thunar-archive-plugin gvfs-backends webp-pixbuf-loader libfuse2 firefox gimp transmission`

Also useful:

`sudo apt install multitail tree trash-cli`

### Unused packages
`sudo apt purge tasksel apt-listchanges yt-dlp iamerican wamerican pocketsphinx-en-us laptop-detect mysql-common vim-common build-essential dpkg-dev cpp-14-x86-64-linux-gnu cpp-14 cpp-x86-64-linux-gnu cpp libcrypt-dev libexpat1-dev linux-libc-dev make zlib1g-dev fakeroot emacsen-common inetutils-telnet manpages-dev installation-report debian-faq doc-debian reportbug python3-reportbug gnuplot-x11 wsdd ifupdown libmailtools-perl firmware-ath9k-htc firmware-carl9170 util-linux-locales`

## Clone the dots

`git clone git@github.com:sebday/debian-hyprtokyo.git`

Copy the folder over home, reboot and run `hyprland`

## Setup console

`sudo nano /etc/default/console-setup`

```bash
FONTSIZE="16x32"
```

`sudo apt install grub-theme-breeze`  
`sudo cp -R /usr/share/grub/themes/breeze /boot/grub/themes/breeze`  
`sudo nano /etc/default/grub`

```bash
GRUB_THEME="/boot/grub/themes/breeze/theme.txt"
```

## Setup greetd login

Edit `/etc/greetd/config.toml`
`command = "tuigreet --cmd hyprland"`

## Notes

### ZSH

The modules are now included as git modules so nothing needs to be done

- Autocomplete
- Interative cd
- Syntax highlighting

### GTK Theme

Set the theme, icons and font in **nwg-look**

### Brave

Chromium disabled "custom stylesheets" in dev tools so unable to style that now :(  
[Chrome Dracula Theme](https://chromewebstore.google.com/detail/dracula-chrome-theme/gfapcejdoghpoidkfodoiiffaaibpaem?hl=en-GB)

### Firefox

Copy `~/.firefox/userContent.css` to the `~/.mozilla/firefox/profile/chrome` directory  
In `about:config` set "toolkit.legacyUserProfileCustomizations.stylesheets" to `true`  

### VS Code

`.config/Cursor/User/settings.json` has the overrides for the background color  
[VS Code Dracula Theme](https://draculatheme.com/visual-studio-code)
