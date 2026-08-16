hl.window_rule({
    name = "floating-window-float",
    match = { tag = "floating-window" },
    float = true,
})

hl.window_rule({
    name = "floating-window-center",
    match = { tag = "floating-window" },
    center = true,
})

hl.window_rule({
    name = "floating-window-size",
    match = { tag = "floating-window" },
    size = { 1600, 900 },
})

hl.window_rule({
    name = "tag-floating-window-class",
    match = { class = "(insync|brave-calendar.*|brave-mail.*|TUI.float)" },
    tag = "+floating-window",
})

hl.window_rule({
    name = "tag-floating-window-title-signin",
    match = { title = "^(.*Sign in.*|Untitled.*)" },
    tag = "+floating-window",
})

hl.window_rule({
    name = "tag-floating-window-title-dialogs",
    match = { title = "^(Rename.*|Open.*Files?|Save.*Files?|Save.*As|.*wants to save.*|.*wants to open.*|Export Image.*)" },
    tag = "+floating-window",
})

hl.window_rule({
    name = "tag-floating-window-title-dialogs",
    match = { class = "^(TUI.tiled)$" },
    tile = true,
    workspace = "10",
    monitor = "HDMI-A-1",
})

hl.window_rule({
    name = "tag-main-window",
    match = { class = "^(TUI.main)$" },
    tag = "+main-window",
})

hl.window_rule({
    name = "main-window-float",
    match = { tag = "main-window" },
    float = true,
})

hl.window_rule({
    name = "main-window-center",
    match = { tag = "main-window" },
    center = true,
})

hl.window_rule({
    name = "main-window-size",
    match = { tag = "main-window" },
    size = { 1600, 900 },
})

hl.window_rule({
    name = "main-window-monitor",
    match = { tag = "main-window" },
    monitor = "DP-1",
})

hl.window_rule({
    name = "satty-float",
    match = { class = "^satty$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "opacity-media-players",
    match = { class = "^(mpv|imv|imv-dir)$" },
    opacity = "1 override 1 override",
})

hl.window_rule({
    name = "opacity-streaming",
    match = { title = "^(.*Picture-in-Picture.*|.*www.channel4.com.*|.*My4.*|.*iplayer.*)" },
    opacity = "1 override 1 override",
})

hl.window_rule({
    name = "workspace-gimp",
    match = { initial_class = "^(gimp)" },
    workspace = "8",
})

hl.window_rule({
    name = "workspace-firefox",
    match = { initial_title = "^(Mozilla Firefox)" },
    workspace = "10",
})

hl.window_rule({
    name = "shopify-tile",
    match = { title = "^shopify$" },
    tile = true,
    workspace = "10",
    monitor = "HDMI-A-1",
})

hl.window_rule({
    name = "evo-music-tile",
    match = { title = "^evo%.music$" },
    tile = true,
    workspace = "10",
    monitor = "HDMI-A-1",
})

