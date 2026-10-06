# Hyprland on Arch

My Arch & Hyprland desktop with themes.

Created so I can easily reinstall Arch to my exact liking with a quad monitor setup and [software](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.install/packages.txt) for a full desktop.

Massive thanks to [Vaxry](https://blog.vaxry.net/) for reigniting my long-time love for [tinkering](https://sebday.dev/2025/07/18-desktop-appreciation/) with my desktop.

Thank you to [DHH](https://world.hey.com/dhh) for Omarchy with loads of cool ideas to copy.

Thank you to [Bjarne](https://github.com/bjarneo) for some gorgeous themes.

## What's here

- Hyprland config (`hypr/`)
- Evoshell, the Quickshell desktop shell, at the repo root
- [Evoplayer](https://github.com/sebday/evoplayer), linked from `vendor/evoplayer`
- App dotfiles (Neovim, Ghostty, Brave flags, and related configs)

## Install

```bash
wget -qO- sebday.dev/installer | bash
```

That rsyncs this repo to `$HOME` and runs `scripts/install`. From a checkout:

```bash
bash scripts/install
```

Evoshell needs Hyprland, quickshell, jq, and pass. Desktop packages are in [`.install/packages.txt`](.install/packages.txt).

## Brave

In `brave://flags/` search for "ozone" and set to *Wayland*.
In `brave://settings/` search for "fonts" and set the default to *Caskaydia*.
In `brave://settings/appearance` set the theme to *GTK*.

Auto loaded through my Brave sync [OrangeMonkey](https://chromewebstore.google.com/detail/orangemonkey/ekmeppjgajofkpiofbebgcbohbmfldaf) for theming websites. Load the orangemonkey script from `themes/shared/` and set it to auto-update.

## Configuration

| Layer | Path | Contents |
|-------|------|----------|
| Shell | `config/shell.json` | Bar layout, monitors, idle, dashboards, integrations |
| Settings | `$EVOSHELL_CONFIG/` | `ui.json`, `media.json`, `font.json`, `hypr-looks.json` |
| State | `$EVOSHELL_STATE/` | Session, `theme.json`, wallpaper, library index, notification history, weather location |
| Cache | `$EVOSHELL_CACHE/` | Bar poller cache, menu previews, chart history |
| Secrets | `pass` | API tokens under `evoshell/` |

`evo-config` and `evo-layout` write `config/shell.json`. Most of it is also editable from Settings in the system menu. Do not put tokens in JSON.

## Dev

```bash
EVOSHELL_BIN=$PWD/bin
evo system restart
journalctl --user -t evoshell -f
```

Plugin ids, IPC, and reload rules are in [AGENTS.md](AGENTS.md).

## Apps

### Neovim
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/neovim.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/neovim.png)

### Media library
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/media-library.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/media-library.png)

### Evoplayer
[![screenshot](https://raw.githubusercontent.com/sebday/evoplayer/refs/heads/master/docs/screenshots/player.png)](https://raw.githubusercontent.com/sebday/evoplayer/refs/heads/master/docs/screenshots/player.png)

### Screenshot editor
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/screenshot-editor.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/screenshot-editor.png)

### Theme switcher
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/theme-switcher.png)](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/shared/screenshots/theme-switcher.png)

## Themes

### Catppuccin
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/catppuccin/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/catppuccin/preview.png)

### Dracula
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/dracula/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/dracula/preview.png)

### Everforest
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/everforest/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/everforest/preview.png)

### Gruvbox
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/gruvbox/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/gruvbox/preview.png)

### Hackerman
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/hackerman/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/hackerman/preview.png)

### Matte Black
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/matte-black/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/matte-black/preview.png)

### Miasma
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/miasma/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/miasma/preview.png)

### Nord
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/nord/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/nord/preview.png)

### Lumon
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/lumon/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/lumon/preview.png)

### Osaka Jade
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/osaka-jade/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/osaka-jade/preview.png)

### Tokyo Night
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/tokyo-night/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/tokyo-night/preview.png)

### Vanta Black
[![screenshot](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/evoshell/themes/vantablack/preview.png)](https://github.com/sebday/hyprdots/blob/evoshell/themes/vantablack/preview.png)
