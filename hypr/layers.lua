-- Layer rules for evoshell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none", blur = true, ignore_alpha = 0.5 })
hl.layer_rule({
	match = {
		namespace = "^(evo-sys-menu|evo-sys-wallpaper(?:-scrim)?|evo-panels-[a-z0-9-]+|evo-sys-themes(?:-scrim)?|evo-side-clipboard|evo-notifications|evo-osd)$",
	},
	no_anim = true,
	animation = "none",
})
hl.layer_rule({ match = { namespace = "evo-notifications" }, blur = true, ignore_alpha = 0.5 })
