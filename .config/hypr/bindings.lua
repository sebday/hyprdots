-- Personal keybinding overrides for Omarchy (loaded after defaults).

-- SUPER+L → lock (Omarchy default: toggle workspace layout; lock is SUPER+CTRL+L).
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

o.bind("SUPER + E", "Editor", { omarchy = "editor" })

-- Clipboard manager (replace Omarchy Super+V paste and Super+Ctrl+V clipboard).
hl.unbind("SUPER + V")
hl.unbind("SUPER + CTRL + V")
hl.unbind("SUPER + CTRL + Q")

o.bind("SUPER + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")

-- Number row: override Omarchy SUPER+1–0 workspace switching.
-- 1–3 → Brave; 4 → file manager; 5 → calculator; 6–0 unbound (use numpad). SUPER+SHIFT+F → file manager.
local function workspace_code(workspace)
	return "code:" .. tostring(workspace + 9)
end

for workspace = 1, 10 do
	hl.unbind("SUPER + " .. workspace_code(workspace))
end

o.bind("SUPER + code:10", "Brave", { launch = "brave" })
o.bind("SUPER + code:11", "Brave Incognito", "brave --incognito")
o.bind("SUPER + code:12", "Brave Tor", "brave --tor")
o.bind("SUPER + code:13", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + code:14", "Calculator", "omacalc")
o.bind("SUPER + code:15", "SoundCloud", { webapp = "https://soundcloud.com/", focus = true })

hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })

-- Numpad workspace switching (MX Keys).
o.bind("SUPER + KP_End", "Switch to workspace 1", hl.dsp.focus({ workspace = "1" }))
o.bind("SUPER + KP_Down", "Switch to workspace 2", hl.dsp.focus({ workspace = "2" }))
o.bind("SUPER + KP_Next", "Switch to workspace 3", hl.dsp.focus({ workspace = "3" }))
o.bind("SUPER + KP_Left", "Switch to workspace 4", hl.dsp.focus({ workspace = "4" }))
o.bind("SUPER + KP_Begin", "Switch to workspace 5", hl.dsp.focus({ workspace = "5" }))
o.bind("SUPER + KP_Right", "Switch to workspace 6", hl.dsp.focus({ workspace = "6" }))
o.bind("SUPER + KP_Home", "Switch to workspace 7", hl.dsp.focus({ workspace = "7" }))
o.bind("SUPER + KP_Up", "Switch to workspace 8", hl.dsp.focus({ workspace = "8" }))
o.bind("SUPER + KP_Prior", "Switch to workspace 9", hl.dsp.focus({ workspace = "9" }))
o.bind("SUPER + KP_Insert", "Switch to workspace 10", hl.dsp.focus({ workspace = "10" }))

o.bind("SUPER + KP_Add", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))
o.bind(
	"SUPER + SHIFT + KP_Add",
	"Move window to scratchpad",
	hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })
)

local numpad_workspace_keys = {
	[1] = "KP_End",
	[2] = "KP_Down",
	[3] = "KP_Next",
	[4] = "KP_Left",
	[5] = "KP_Begin",
	[6] = "KP_Right",
	[7] = "KP_Home",
	[8] = "KP_Up",
	[9] = "KP_Prior",
	[10] = "KP_Insert",
}

for workspace = 1, 10 do
	o.bind(
		"SUPER + SHIFT + " .. numpad_workspace_keys[workspace],
		"Move window to workspace " .. workspace,
		hl.dsp.window.move({ workspace = tostring(workspace), follow = false })
	)
end

-- Screenshot keys (omasnap overlay + custom edit-last / compositor shortcuts).
hl.unbind("PRINT")
hl.unbind("SUPER + PRINT")
hl.unbind("ALT + PRINT")

o.bind("PRINT", "Screenshot", "omasnap")
o.bind("ALT + PRINT", "Screenshot monitor", "omasnap fullscreen")
o.bind("SUPER + PRINT", "Annotate last screenshot", "omarchy-capture-edit-last")
o.bind("SUPER + ALT + PRINT", "Screenshot all monitors", "omarchy-capture-compositor")

hl.layer_rule({
	match = { namespace = "^omasnap$" },
	no_anim = true,
	animation = "none",
	no_screen_share = true,
})

-- Stock grim/slurp capture paths (omasnap hotkeys above replace these).
hl.unbind("SUPER + CTRL + C")
hl.unbind("SUPER + CTRL + PRINT")

o.bind("SUPER + F5", "Restart shell", "omarchy restart shell")

-- Apps on Super+D; theme picker on Super+Alt+Space (was Super+Alt+Space → apps).
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + D", "Apps menu", "omarchy-menu toggle apps")
o.bind(
	"SUPER + ALT + SPACE",
	"Theme picker",
	'theme=$("$HOME/.local/bin/omarchy-theme-switcher"); [[ -n $theme ]] && omarchy theme set "$theme"'
)

hl.unbind("SUPER + SHIFT + CTRL + SPACE")

-- Wallpaper prev/next on Super+Ctrl+=/- (Omarchy default on those keys is large window resize).
hl.unbind("SUPER + CTRL + code:20")
hl.unbind("SUPER + CTRL + code:21")
o.bind("SUPER + CTRL + code:21", "Next background", "omarchy theme bg next")
o.bind("SUPER + CTRL + code:20", "Previous background", "omarchy-theme-bg-prev")

hl.unbind("SUPER + ALT + code:20")
hl.unbind("SUPER + ALT + code:21")
o.bind("SUPER + ALT + code:21", "Next theme", "omarchy-theme-cycle next")
o.bind("SUPER + ALT + code:20", "Previous theme", "omarchy-theme-cycle prev")

o.bind("SUPER + CTRL + ALT + code:20", "Previous shader", "omarchy-shell shaders prev")
o.bind("SUPER + CTRL + ALT + code:21", "Next shader", "omarchy-shell shaders next")

-- Resize tiled windows (old hyprdots: Super+Ctrl+arrows, 100px, repeat).
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")

local resize_step = 100
o.bind(
	"SUPER + CTRL + RIGHT",
	"Resize window wider",
	hl.dsp.window.resize({ x = resize_step, y = 0, relative = true }),
	{ repeating = true }
)
o.bind(
	"SUPER + CTRL + LEFT",
	"Resize window narrower",
	hl.dsp.window.resize({ x = -resize_step, y = 0, relative = true }),
	{ repeating = true }
)
o.bind(
	"SUPER + CTRL + UP",
	"Resize window shorter",
	hl.dsp.window.resize({ x = 0, y = -resize_step, relative = true }),
	{ repeating = true }
)
o.bind(
	"SUPER + CTRL + DOWN",
	"Resize window taller",
	hl.dsp.window.resize({ x = 0, y = resize_step, relative = true }),
	{ repeating = true }
)
