-- App window rules (loaded after Omarchy defaults).
o.window("^(Insync)$", { tag = "+floating-window" })

-- Omarchy defaults org.omarchy.btop to a centered floating popup.
-- Tile it so the workspace 10 autostart instance is a normal window.
-- Super+Ctrl+T (Activity) uses the same class, so that shortcut tiles too.
o.window("org.omarchy.btop", { tag = "-floating-window", tile = true })

-- Pop & pin (Super+O): Omarchy defaults to rounded corners for the pop tag.
o.window({ tag = "pop" }, { rounding = 0 })
