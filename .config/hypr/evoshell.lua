-- Layer rules for evoshell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none", blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(evo-menu|evo-panel|evo-panel-scrim|evo-wallpaper|evo-wallpaper-picker|evo-calendar|evo-stats-diy|evo-stats-tgs|evo-cursor|evo-weather|evo-network|evo-sound|evo-github|evo-stocks|evo-transmission|evo-transmission-add|evo-library|evo-theme|evo-clipboard|evo-notifications|evo-bar-tray-menu)$" }, no_anim = true, animation = "none" })
hl.layer_rule({ match = { namespace = "evo-panel" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "evo-notifications" }, blur = true, ignore_alpha = 0.5 })
