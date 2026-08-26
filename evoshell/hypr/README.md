# Hyprland integration

Evoshell hypr modules live in this directory. Hyprland loads them via `package.path`, not symlinks.

Add to `hyprland.lua`:

```lua
local evoshell_root = os.getenv("EVOSHELL_ROOT") or (os.getenv("HOME") .. "/projects/evoshell")
dofile(evoshell_root .. "/hypr/bootstrap.lua")
require("hypr.init")
```

`EVOSHELL_ROOT` defaults to `~/projects/evoshell`.

All Hyprland keybindings (evoshell panels, volume/media keys, window management, app launchers) live in [`bindings.lua`](bindings.lua). You do not need a separate `~/.config/hypr/bindings.lua` unless you want extra machine-specific binds on top.

Evoshell overlays dismiss with **Esc** (menu and library keep contextual back/clear before close).
