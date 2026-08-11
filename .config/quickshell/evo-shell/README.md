# Evo shell

Omarchy Quattro-style consolidated desktop shell for Hyprland. One `quickshell` process replaces Waybar, Walker (launcher/clipboard), Mako, hyprlock, hyprpaper, and hypridle.

## Install

```bash
sudo pacman -S quickshell
```

## Start

Hyprland autostart runs `evo-launch-shell`, which supervises:

```bash
quickshell -n -c evo-shell
```

Manual start:

```bash
evo-launch-shell
```

Restart:

```bash
evo-restart-shell.sh
```

## Config

Everything lives in [`~/.config/quickshell/evo-shell/`](~/.config/quickshell/evo-shell/):

- [`shell.json`](shell.json) — bar layout, idle timings, notifications, panel settings
- [`theme.json`](theme.json) — colors (written by `themes-apply.sh`, watched by `Theme.qml`)
- QML shell + plugins (`shell.qml`, `plugins/`, …)
- [`AGENTS.md`](AGENTS.md) — notes for agents

API tokens: `~/.local/share/evo-shell/secrets.env` (`chmod 600`). Not in git.

See [REPLACEMENTS.md](REPLACEMENTS.md) and [IPC.md](IPC.md).

## Legacy stack (removed from autostart)

These are no longer started by Hyprland when using evo-shell:

- `waybar`, `mako`, `hyprpaper`, `hypridle`, `walker --prewarm`

## Wallpaper state

Current wallpaper path: `~/.local/state/evo-shell/wallpaper`

## Logs

```bash
journalctl -t evo-shell -f
```
