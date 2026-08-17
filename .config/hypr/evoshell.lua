-- Layer rules for evoshell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none", blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(evo-menu|evo-panel|evo-panel-scrim|evo-wallpaper|evo-wallpaper-picker|evo-calendar|evo-shopify-diy|evo-shopify-tgs|evo-cursor|evo-weather|evo-network|bar-volume|bar-media|evo-github|evo-system|evo-stocks|evo-cloudflare|evo-transmission|evo-transmission-add|evo-insync|evo-steam|evo-library|evo-theme|evo-clipboard|evo-notifications|evo-bar-tray-menu)$" }, no_anim = true, animation = "none" })
hl.layer_rule({ match = { namespace = "evo-panel" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "evo-notifications" }, blur = true, ignore_alpha = 0.5 })
