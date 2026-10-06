hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_THEME", "current")

local function evoshell_looks()
	local home = os.getenv("HOME") or ""
	local path = (os.getenv("EVOSHELL_CONFIG") or (home .. "/.config/evoshell")) .. "/hypr-looks.json"
	local looks = {
		rounding = 0,
		gaps_in = 0,
		gaps_out = 0,
		animations = true,
		active_opacity = 0.97,
		inactive_opacity = 0.88,
	}
	local f = io.open(path, "r")
	if not f then
		return looks
	end
	local text = f:read("*a") or ""
	f:close()
	local function flag(key)
		local value = text:match('"' .. key .. '"%s*:%s*(%a+)')
		if value == "true" then
			return true
		end
		if value == "false" then
			return false
		end
		return nil
	end
	local function num(key)
		return tonumber(text:match('"' .. key .. '"%s*:%s*([%d%.]+)'))
	end
	if flag("roundingOn") then
		looks.rounding = num("rounding") or 7
		if looks.rounding <= 0 then
			looks.rounding = 7
		end
	end
	if flag("gapsOn") then
		looks.gaps_in = 10
		looks.gaps_out = 20
	end
	local animations = flag("animationsOn")
	if animations ~= nil then
		looks.animations = animations
	end
	looks.active_opacity = num("activeOpacity") or looks.active_opacity
	looks.inactive_opacity = num("inactiveOpacity") or looks.inactive_opacity
	return looks
end

local looks = evoshell_looks()

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },

    general = {
        gaps_in = looks.gaps_in,
        gaps_out = looks.gaps_out,
        border_size = 2,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = looks.rounding,
        active_opacity = looks.active_opacity,
        inactive_opacity = looks.inactive_opacity,
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
        enabled = looks.animations,
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
        disable_splash_rendering = true,
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
