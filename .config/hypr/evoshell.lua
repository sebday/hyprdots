-- Layer rules for evoshell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none", blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(evo-menu|evo-panel|evo-panel-scrim|evo-wallpaper|evo-wallpaper-picker|evo-calendar|evo-stats|evo-cursor|evo-weather|evo-network|evo-sound|evo-library|evo-theme|evo-screenshot|evo-clipboard|evo-notifications|evo-bar-tray-menu)$" }, no_anim = true, animation = "none" })
hl.layer_rule({ match = { namespace = "evo-panel" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "evo-notifications" }, blur = true, ignore_alpha = 0.5 })
