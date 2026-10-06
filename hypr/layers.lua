-- Layer rules for evoshell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none", blur = true, ignore_alpha = 0.5 })
hl.layer_rule({
	match = {
		namespace = "^(evo-sys-menu|evo-side|evo-side-scrim|evo-sys-settings|evo-sys-wallpaper(?:-scrim)?|evo-panels-[a-z0-9-]+|evo-sys-themes(?:-scrim)?|evo-side-clipboard|evo-sys-notifications|evo-bar-tray-menu)$",
	},
	no_anim = true,
	animation = "none",
})
hl.layer_rule({ match = { namespace = "evo-side" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "evo-sys-notifications" }, blur = true, ignore_alpha = 0.5 })
