hl.on("hyprland.start", function()
    hl.exec_cmd("xrandr --output DP-1 --primary")
    hl.dispatch(hl.dsp.exec_cmd(
        "ghostty --class=TUI.tiled --window-padding-x=0 --window-padding-y=0 -e btop",
        { workspace = "10 silent" }
    ))
    hl.dispatch(hl.dsp.exec_cmd("ghostty --class=TUI.topright", { workspace = "10 silent" }))
    hl.exec_cmd("systemctl --user start evoshell.service")
    hl.dispatch(hl.dsp.exec_cmd("brave", { workspace = "2" }))
    hl.dispatch(hl.dsp.exec_cmd("obsidian", { workspace = "6 silent" }))
    hl.exec_cmd("bash -c 'sleep 20 && insync start --qt-qpa-platform=xcb'")
end)
