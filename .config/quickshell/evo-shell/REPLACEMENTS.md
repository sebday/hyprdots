# Desktop shell replacements

| Old tool | New plugin | Notes |
|----------|------------|-------|
| Waybar | `evo.bar` | `evo-bar-*.sh` scripts feed bar widgets and the stats panel |
| Walker | `evo.menu` | Apps, system commands, power, runner |
| Mako | `evo.notifications` | |
| hyprlock | `evo.lock` | |
| hyprpaper | `evo.background` | |
| hypridle | `evo.idle` | |

## Walker / elephant — what was actually used

Audited bindings and scripts. Only these walker surfaces were in active use:

| Former use | Replacement |
|------------|-------------|
| `SUPER+Escape` → `menus:power` | `evo.menu` mode `power` |
| `SUPER+R` → `runner` | `evo.menu` mode `runner` |
| `SUPER+Space` → `menus:system` (historical) | `evo.menu` default system menu |
| `SUPER+D` → apps | `evo.menu` mode `apps` |
| Clipboard | `evo.clipboard` service + `evo.panel` clipboard module |
| Theme/wallpaper pickers (scripts) | `evo.menu` submenus `themes`, `wallpaper` |

**Not migrated** (no keybind, hidden from provider list, or media submenus never bound):

- elephant providers: archlinuxpkgs, calc, files, todo, windows, wireplumber, bookmarks, snippets, unicode, websearch, playerctl
- IPTV / TV / Films media menus (elephant lua only; `walker-iptv-play.sh` exists but unbound)
- emoji picker and keybinds viewer
- `SUPER+ALT+D` provider list — binding removed

## Keybinds

| Binding | Action |
|---------|--------|
| `SUPER+Space` | System menu |
| `SUPER+D` | Apps only |
| `SUPER+Escape` | Power menu |
| `SUPER+R` | Runner |
| `SUPER+L` | Lock |
| `SUPER+V` | Clipboard panel |

No fallbacks to hyprlock, hyprpaper, or walker.
