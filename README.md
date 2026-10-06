# Hyprland on Arch

My Arch & Hyprland desktop with themes.

Created so I can easily reinstall Arch to my exact liking with a quad monitor setup and [software](https://raw.githubusercontent.com/sebday/hyprdots/refs/heads/master/.install/packages.txt) for a full desktop.

Massive thanks to [Vaxry](https://blog.vaxry.net/) for reigniting my long-time love for [tinkering](https://sebday.dev/2025/07/18-desktop-appreciation/) with my desktop.

Thank you to [DHH](https://world.hey.com/dhh) for Omarchy with loads of cool ideas to copy.

Thank you to [Bjarne](https://github.com/bjarneo) for some gorgeous themes.

## What's here

- Hyprland config (`hypr/`)
- Evoshell, the Quickshell desktop shell, at the repo root
- App dotfiles (Ghostty, Brave flags, and related configs)

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

In `brave://settings/` search for "fonts" and set the default to *Caskaydia*.
In `brave://settings/appearance` set the theme to *GTK*.

The [webtheme](modules/webtheme/README.md) extension themes websites in Brave.

## Configuration

`EVOSHELL_ROOT` is this checkout, recorded in `~/.config/evoshell/environment`.

| Layer | Path | Contents |
|-------|------|----------|
| Shell | `config/shell.json` | Bar layout and per-monitor placement, notifications, idle, dashboards, Shopify, wallpaper |
| Settings | `$EVOSHELL_CONFIG/` (`~/.config/evoshell`) | `ui.json`, `font.json`, `hypr-looks.json` |
| State | `$EVOSHELL_STATE/` (`~/.local/state/evoshell`) | Session, `theme.json`, wallpaper, notification history, weather location |
| Cache | `$EVOSHELL_CACHE/` (`~/.cache/evoshell`) | Bar poller cache, menu thumbnails, chart history |
| Secrets | `pass` | API tokens under `evoshell/` |

`evo-config` writes `config/shell.json`. `evo-layout` writes bar and notification placement there, and UI scale into `ui.json`. Settings in the system menu edits the same files. Do not put tokens in JSON.

## Dev

```bash
EVOSHELL_BIN=$PWD/bin
evo system restart
journalctl --user -t evoshell -f
```

Plugin ids, IPC, and reload rules are in [AGENTS.md](AGENTS.md).

## Themes

### Catppuccin
[![screenshot](themes/catppuccin/preview.png)](themes/catppuccin/preview.png)

### Dracula
[![screenshot](themes/dracula/preview.png)](themes/dracula/preview.png)

### Everforest
[![screenshot](themes/everforest/preview.png)](themes/everforest/preview.png)

### Gruvbox
[![screenshot](themes/gruvbox/preview.png)](themes/gruvbox/preview.png)

### Hackerman
[![screenshot](themes/hackerman/preview.png)](themes/hackerman/preview.png)

### Matte Black
[![screenshot](themes/matte-black/preview.png)](themes/matte-black/preview.png)

### Miasma
[![screenshot](themes/miasma/preview.png)](themes/miasma/preview.png)

### Nord
[![screenshot](themes/nord/preview.png)](themes/nord/preview.png)

### Lumon
[![screenshot](themes/lumon/preview.png)](themes/lumon/preview.png)

### Osaka Jade
[![screenshot](themes/osaka-jade/preview.png)](themes/osaka-jade/preview.png)

### Tokyo Night
[![screenshot](themes/tokyo-night/preview.png)](themes/tokyo-night/preview.png)

### Vanta Black
[![screenshot](themes/vantablack/preview.png)](themes/vantablack/preview.png)
