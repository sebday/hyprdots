# Desktop shell replacements

| Old tool | New plugin | Notes |
|----------|------------|-------|
| Waybar | `evo.bar` | Waybar scripts reused as command widgets |
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
| `SUPER+Space` → `menus:system` (historical) | `evo.menu` mode `all` (apps + system commands) |
| `SUPER+D` → apps | `evo.menu` mode `apps` |
| Clipboard / emojis | `evo.clipboard`, `evo.emojis` |
| Theme/wallpaper pickers (scripts) | `evo.menu` submenus `themes`, `wallpaper` |
| Keybinds viewer | `evo-keybinds.sh` |

**Not migrated** (no keybind, hidden from provider list, or media submenus never bound):

- elephant providers: archlinuxpkgs, calc, files, todo, windows, wireplumber, bookmarks, snippets, unicode, websearch, playerctl
- IPTV / TV / Films media menus (elephant lua only; `walker-iptv-play.sh` exists but unbound)
- `SUPER+ALT+D` provider list — binding removed

Elephant/walker can be disabled when evo-shell is running.

## Keybinds

| Binding | Action |
|---------|--------|
| `SUPER+Space` | Unified menu (apps + system) |
| `SUPER+D` | Apps only |
| `SUPER+Escape` | Power menu |
| `SUPER+R` | Runner |
| `SUPER+L` | Lock |
| `SUPER+V` | Clipboard |
| `SUPER+ALT+V` | Emojis |

No fallbacks to hyprlock, hyprpaper, or walker.
