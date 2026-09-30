-- App window rules (loaded after Omarchy defaults).
o.window("^(Insync)$", { tag = "+floating-window" })

-- Omarchy defaults org.omarchy.btop to a centered floating popup.
-- Tile it so the workspace 10 autostart instance is a normal window.
-- Super+Ctrl+T (Activity) uses the same class, so that shortcut tiles too.
o.window("org.omarchy.btop", { tag = "-floating-window", tile = true })

-- Shopify Quickshell panel. Title keeps this off other org.quickshell windows.
-- silent matches the old workspace 10 TUI launch: open there, don't switch to it.
o.window({ class = "^org\\.quickshell$", title = "^Shopify$" }, { workspace = "10 silent" })

-- Pop & pin (Super+O): Omarchy defaults to rounded corners for the pop tag.
o.window({ tag = "pop" }, { rounding = 0 })

-- The cameras window is one tile. Title keeps this off other qml windows.
o.window({ class = "^org\\.qt-project\\.qml$", title = "^Cameras$" }, { tile = true })

-- Google Home camera pop-outs. Title match only, so no camera id is stored.
o.window({
  class = "^brave",
  title = "^Cameras . Google Home$",
}, {
  border_size = 0,
  rounding = 0,
  render_unfocused = true,
})

-- Camera list webapps. The class prefix is the site, not a camera id.
o.window({
  class = "^brave-home\\.google\\.com__.*_cameras_list_",
}, {
  border_size = 0,
  rounding = 0,
  render_unfocused = true,
})
