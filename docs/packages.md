# Packages

Arch Linux package names are used below. On other distros, install the equivalent packages for your package manager.

For a full desktop install (boot, greetd, apps, dev tools), see [hyprdots `.install/packages.txt`](https://github.com/sebday/hyprdots/blob/master/.install/packages.txt). This list covers what Evoshell itself needs when installed standalone.

## Required

Shell runtime and core CLIs. Evoshell will not work correctly without these.

| Package | Purpose |
|---------|---------|
| `hyprland` | Compositor; `hyprctl` for layout, screenshots, and looks |
| `quickshell` | Shell runtime (`evo ipc` fails without it) |
| `jq` | Bar pollers, config CLIs, and JSON helpers |
| `pass` | Secrets under `evoshell/` (GitHub, Home Assistant, Cloudflare, …) |
| `libnotify` | Screenshot toasts and browser native notifications |
| `pipewire` | Audio backend |
| `pipewire-pulse` | PulseAudio compatibility for volume control |
| `darkhttpd` | User service serving `~/.themes` for Stylus injection |
| `wl-clipboard` | Clipboard watch and screenshot copy |
| `cliphist` | Clipboard history (`evo-clipboard`) |

## Recommended

Default features and integrations work out of the box with these installed.

| Package | Purpose |
|---------|---------|
| `imagemagick` | Stacked screenshots and menu preview thumbnails |
| `grim` | Wayland screen capture |
| `slurp` | Region selection for screenshots |
| `hyprshot` | Alternate capture path (depends on grim + slurp) |
| `satty` | Screenshot annotation (`evo-screenshot edit`) |
| `papirus-icon-theme` | Base icon set for recoloured theme icons |
| `curl` | GitHub, Home Assistant, Cursor usage, BTC/SPCX pollers |
| `playerctl` | Media keys when Evoplayer is not running |
| `glib2` | `gsettings` for GTK theme activation |
| `noto-fonts` | UI text |
| `noto-fonts-emoji` | Emoji in UI |

## Optional

Panels and default Hyprland bindings degrade gracefully or can be swapped for other apps.

### Default Hyprland bindings

Configured in [`hypr/bindings.lua`](../hypr/bindings.lua). Change the launcher variables if you prefer different apps.

| Package | Purpose |
|---------|---------|
| `ghostty` | Default terminal (Super+Return) |
| `neovim` | Default editor (Super+E) and `evo nvim-open` |
| `thunar` | File manager (Super+T) |
| `hyprpicker` | Colour picker (Super+P) |
| `brave-bin` (AUR) | Default browser (Super+1–3) |

### Bar and panel integrations

| Package | Purpose |
|---------|---------|
| `transmission-cli` | Transmission download panel |
| `btop` | System panel theme files |
| `cava` | Audio visualiser (Evoplayer panel) |
| `steam` | Steam library panel |
| `insync` (AUR) | Insync sync status panel |
| `mpv` | Film/TV playback (`evo-bar-library`) |

Evoplayer is a separate repo — see [evoplayer](https://github.com/sebday/evoplayer) for player-specific dependencies.

## Install

Install required and recommended packages:

```bash
sudo pacman -S --needed $(grep -vE '^#|^$' packages.txt)
```

Or install manually:

```bash
sudo pacman -S hyprland quickshell jq pass libnotify pipewire pipewire-pulse \
  darkhttpd wl-clipboard cliphist imagemagick grim slurp hyprshot satty \
  papirus-icon-theme curl playerctl glib2 noto-fonts noto-fonts-emoji
```

Then set up secrets and link Evoshell:

```bash
pass init <gpg-id>   # once per machine
git clone https://github.com/sebday/evoshell.git ~/projects/evoshell
cd ~/projects/evoshell
bash scripts/install
systemctl --user enable --now evoshell.service darkhttpd.service
```

Load the Hyprland module — see [`hypr/README.md`](../hypr/README.md).
