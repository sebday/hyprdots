-- Hyprland keybindings for evoshell and desktop.

local home = os.getenv("HOME") or ""
local evo = home .. "/.local/bin/evo"
local lib = os.getenv("EVOSHELL_BIN") or (home .. "/.local/lib/evoshell/bin")
local shell_ipc = evo .. " ipc"

local browser = "brave"
local terminal = "ghostty"
local editor = terminal .. " -e nano"

local function bindd(keys, description, dispatcher, flags)
	flags = flags or {}
	flags.description = description
	hl.bind(keys, dispatcher, flags)
end

-- Evoshell panels and system
bindd("SUPER + Space", "System menu", hl.dsp.global("evoshell:systemMenu"))
bindd(
	"SUPER + Escape",
	"Shutdown menu",
	hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.sys.menu \'{"mode":"power","submenu":"session"}\'')
)
bindd("SUPER + Insert", "Wallpaper switcher", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.sys.wallpaper"))
bindd("SUPER + minus", "Previous wallpaper", hl.dsp.exec_cmd(lib .. "/evo-wallpaper prev"))
bindd("SUPER + equal", "Next wallpaper", hl.dsp.exec_cmd(lib .. "/evo-wallpaper next"))
bindd("SUPER + ALT + minus", "Previous theme", hl.dsp.exec_cmd(lib .. "/evo-theme prev"))
bindd("SUPER + ALT + equal", "Next theme", hl.dsp.exec_cmd(lib .. "/evo-theme next"))
bindd("SUPER + Home", "Theme picker", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.sys.themes"))
bindd("SUPER + L", "Lock Screen", hl.dsp.exec_cmd(evo .. " system lock"))
bindd("SUPER + F5", "Restart evoshell", hl.dsp.exec_cmd(evo .. " system restart"))
bindd("SUPER + S", "Looks", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.sys.menu '{\"mode\":\"power\",\"tab\":\"looks\"}'"))
bindd("SUPER + I", "Colour Picker", hl.dsp.exec_cmd("hyprpicker -al"))
bindd("SUPER + P", "Packages", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.sys.menu '{\"mode\":\"power\",\"tab\":\"packages\"}'"))
bindd("SUPER + V", "Clipboard history", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.side.clipboard"))
bindd("SUPER + ALT + S", "Shopify", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.shopify"))
bindd("SUPER + ALT + E", "Evoplayer", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.panels.player"))

bindd(
	"XF86AudioRaiseVolume",
	"Volume up",
	hl.dsp.exec_cmd(shell_ipc .. " evo.sys.media.audio stepUp"),
	{ locked = true, repeating = true }
)
bindd(
	"XF86AudioLowerVolume",
	"Volume down",
	hl.dsp.exec_cmd(shell_ipc .. " evo.sys.media.audio stepDown"),
	{ locked = true, repeating = true }
)
bindd(
	"XF86AudioMute",
	"Mute volume",
	hl.dsp.exec_cmd(shell_ipc .. " evo.sys.media.audio toggleMute"),
	{ locked = true, repeating = true }
)
bindd("XF86AudioPlay", "Play/Pause media", hl.dsp.exec_cmd(lib .. "/evo-media-keys play-pause"), { locked = true })
bindd("XF86AudioPause", "Pause media", hl.dsp.exec_cmd(lib .. "/evo-media-keys play-pause"), { locked = true })
bindd("XF86AudioNext", "Next media track", hl.dsp.exec_cmd(lib .. "/evo-media-keys next"), { locked = true })
bindd("XF86AudioPrev", "Previous media track", hl.dsp.exec_cmd(lib .. "/evo-media-keys prev"), { locked = true })

bindd("PRINT", "Screenshot", hl.dsp.exec_cmd("omasnap"))

-- Desktop: programs and window management
bindd("SUPER + Return", "Terminal", hl.dsp.exec_cmd(terminal))
bindd("SUPER + grave", "Toggle quake console", function()
	require("hypr.qconsole").toggle()
end)
bindd("SUPER + ALT + Return", "GUI File Manager", hl.dsp.exec_cmd("thunar"))
bindd("SUPER + W", "Close Active Window", hl.dsp.window.close())
bindd("SUPER + E", "Editor", hl.dsp.exec_cmd(editor))
bindd("SUPER + T", "Toggle Floating Window", hl.dsp.window.float({ action = "toggle" }))
bindd("SUPER + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" }))
bindd("SUPER + J", "Toggle Split Direction", hl.dsp.layout("togglesplit"))
bindd("SUPER + BackSpace", "Toggle window transparency", function()
	local window = hl.get_active_window()
	if window then
		hl.dispatch(hl.dsp.window.set_prop({ prop = "opaque", value = "toggle", window = window }))
	end
end)

bindd("SUPER + 1", "Brave Browser", hl.dsp.exec_cmd(browser))
bindd("SUPER + 2", "Brave Incognito", hl.dsp.exec_cmd(browser .. " --incognito"))
bindd("SUPER + 3", "Brave Tor", hl.dsp.exec_cmd(browser .. " --tor"))

bindd("SUPER + KP_End", "Workspace 1", hl.dsp.focus({ workspace = 1 }))
bindd("SUPER + KP_Down", "Workspace 2", hl.dsp.focus({ workspace = 2 }))
bindd("SUPER + KP_Next", "Workspace 3", hl.dsp.focus({ workspace = 3 }))
bindd("SUPER + KP_Left", "Workspace 4", hl.dsp.focus({ workspace = 4 }))
bindd("SUPER + KP_Begin", "Workspace 5", hl.dsp.focus({ workspace = 5 }))
bindd("SUPER + KP_Right", "Workspace 6", hl.dsp.focus({ workspace = 6 }))
bindd("SUPER + KP_Home", "Workspace 7", hl.dsp.focus({ workspace = 7 }))
bindd("SUPER + KP_Up", "Workspace 8", hl.dsp.focus({ workspace = 8 }))
bindd("SUPER + KP_Prior", "Workspace 9", hl.dsp.focus({ workspace = 9 }))
bindd("SUPER + KP_Insert", "Workspace 10", hl.dsp.focus({ workspace = 10 }))
bindd("SUPER + KP_Add", "Toggle Scratchpad", hl.dsp.workspace.toggle_special("magic"))
bindd("SUPER + SHIFT + KP_Add", "Move Window to Scratchpad", hl.dsp.window.move({ workspace = "special:magic" }))

bindd("SUPER + left", "Move Focus Left", hl.dsp.focus({ direction = "left" }))
bindd("SUPER + right", "Move Focus Right", hl.dsp.focus({ direction = "right" }))
bindd("SUPER + up", "Move Focus Up", hl.dsp.focus({ direction = "up" }))
bindd("SUPER + down", "Move Focus Down", hl.dsp.focus({ direction = "down" }))

bindd("SUPER + Tab", "Cycle to Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
bindd("SUPER + mouse_down", "Cycle to Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
bindd("SUPER + mouse_up", "Cycle to Previous Workspace", hl.dsp.focus({ workspace = "e-1" }))

for i = 1, 10 do
	local keys = {
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
	bindd(
		"SUPER + SHIFT + " .. keys[i],
		"Move Active Window to Workspace " .. i,
		hl.dsp.window.move({ workspace = i, follow = false })
	)
end

bindd("SUPER + mouse:272", "Move window with mouse", hl.dsp.window.drag(), { mouse = true })
bindd("SUPER + mouse:273", "Resize window with mouse", hl.dsp.window.resize(), { mouse = true })
bindd("SUPER + SHIFT + left", "Move Window Left", hl.dsp.window.move({ direction = "left" }))
bindd("SUPER + SHIFT + right", "Move Window Right", hl.dsp.window.move({ direction = "right" }))
bindd("SUPER + SHIFT + up", "Move Window Up", hl.dsp.window.move({ direction = "up" }))
bindd("SUPER + SHIFT + down", "Move Window Down", hl.dsp.window.move({ direction = "down" }))

bindd(
	"SUPER + CTRL + right",
	"Resize window wider",
	hl.dsp.window.resize({ x = 20, y = 0, relative = true }),
	{ repeating = true }
)
bindd(
	"SUPER + CTRL + left",
	"Resize window narrower",
	hl.dsp.window.resize({ x = -20, y = 0, relative = true }),
	{ repeating = true }
)
bindd(
	"SUPER + CTRL + up",
	"Resize window shorter",
	hl.dsp.window.resize({ x = 0, y = -20, relative = true }),
	{ repeating = true }
)
bindd(
	"SUPER + CTRL + down",
	"Resize window taller",
	hl.dsp.window.resize({ x = 0, y = 20, relative = true }),
	{ repeating = true }
)
