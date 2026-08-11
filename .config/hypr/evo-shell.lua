-- Layer rules for evo-shell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none" })
hl.layer_rule({ match = { namespace = "^(evo-menu|evo-panel|evo-notifications|evo-bar-tooltip|evo-bar-tray-menu)$" }, no_anim = true, animation = "none" })
hl.layer_rule({ match = { namespace = "evo-panel" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "evo-notifications" }, blur = true, ignore_alpha = 0.5 })
