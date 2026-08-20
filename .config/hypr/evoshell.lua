-- Layer rules for evoshell Quickshell surfaces.

hl.layer_rule({ match = { namespace = "evo-bar" }, no_anim = true, animation = "none", blur = true, ignore_alpha = 0.5 })
hl.layer_rule({
	match = {
		namespace = "^(evo-sys-menu|evo-side|evo-side-scrim|evo-sys-settings|evo-sys-wallpaper|evo-sys-wallpaper-picker|evo-bar-popups-calendar|evo-panel-shopify-diy|evo-panel-shopify-tgs|evo-bar-popups-cursor-usage|evo-bar-popups-weather|evo-bar-network-stats|evo-bar-media-volume|evo-bar-media-now-playing|evo-bar-popups-github|evo-bar-popups-system-stats|evo-bar-popups-stocks|evo-bar-popups-cloudflare|evo-bar-network-transmission|evo-bar-network-transmission-add|evo-bar-popups-insync|evo-bar-steam|evo-bar-media-library|evo-sys-themes|evo-side-clipboard|evo-sys-notifications|evo-bar-tray-menu)$",
	},
	no_anim = true,
	animation = "none",
})
hl.layer_rule({ match = { namespace = "evo-side" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "evo-sys-notifications" }, blur = true, ignore_alpha = 0.5 })
