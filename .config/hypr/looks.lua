hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_THEME", "current")

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },

    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 2,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 0,
        active_opacity = 0.97,
        inactive_opacity = 0.88,
        fullscreen_opacity = 1,
        shadow = {
            enabled = false,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            passes = 2,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        background_color = 0x0a0e19,
    },

    binds = {
        workspace_back_and_forth = false,
        allow_workspace_cycles = false,
    },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 7, bezier = "myBezier", style = "slide top" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "myBezier", style = "slidevert" })

do
    local path = (os.getenv("HOME") or "") .. "/.local/state/evo-shell/hypr-looks-overrides.lua"
    local chunk = loadfile(path)
    if chunk then
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
            local updates = {}
            local decoration = {}
            local general = {}

            if data.roundingOn == true then
                decoration.rounding = 7
            elseif data.roundingOn == false then
                decoration.rounding = 0
            elseif data.rounding ~= nil then
                decoration.rounding = data.rounding
            end

            if data.gapsOn == true then
                general.gaps_in = 10
                general.gaps_out = 20
            elseif data.gapsOn == false then
                general.gaps_in = 0
                general.gaps_out = 0
            elseif data.gaps_in ~= nil or data.gaps_out ~= nil or data.gap ~= nil then
                local gap_in = data.gaps_in or data.gap or 0
                local gap_out = data.gaps_out or data.gap or 0
                general.gaps_in = gap_in
                general.gaps_out = gap_out
            end

            local animations = nil
            if data.animationsOn == true then
                animations = { enabled = true }
            elseif data.animationsOn == false then
                animations = { enabled = false }
            end

            if data.activeOpacity ~= nil then
                decoration.active_opacity = data.activeOpacity
            end
            if data.inactiveOpacity ~= nil then
                decoration.inactive_opacity = data.inactiveOpacity
            end

            if next(decoration) then
                updates.decoration = decoration
            end
            if next(general) then
                updates.general = general
            end
            if animations then
                updates.animations = animations
            end
            if next(updates) then
                hl.config(updates)
            end
        end
    end
end
