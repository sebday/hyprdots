-- Use --class="TUI.float" to set a window to float (Thank you to dhh for the inspiration)
-- Use ALT for the alternative to a program
-- Use CTRL to control movement or resize
-- Use SHIFT to move windows

local browser = "brave"
local terminal = "ghostty"
local editor = terminal .. " -e nvim"
local bin = (os.getenv("HOME") or "") .. "/.local/bin"
local shell_ipc = bin .. "/evo-ipc"

local function bindd(keys, description, dispatcher, flags)
	flags = flags or {}
	flags.description = description
	hl.bind(keys, dispatcher, flags)
end

bindd("SUPER + Return", "Terminal", hl.dsp.exec_cmd(terminal))
bindd("SUPER + Space", "System menu", hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.menu \'{"mode":"power"}\''))
bindd("SUPER + W", "Close Active Window", hl.dsp.window.close())
bindd("SUPER + E", "Editor", hl.dsp.exec_cmd(editor))
bindd("SUPER + T", "GUI File Manager", hl.dsp.exec_cmd("thunar"))
bindd("SUPER + D", "App launcher", hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.menu \'{"mode":"apps"}\''))
bindd("SUPER + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" }))
bindd("SUPER + H", "Toggle window transparency", function()
	local window = hl.get_active_window()
	if window then
		hl.dispatch(hl.dsp.window.set_prop({ prop = "opaque", value = "toggle", window = window }))
	end
end)
bindd("SUPER + J", "Toggle Split Direction", hl.dsp.layout("togglesplit"))
bindd("SUPER + K", "Toggle Floating Window", hl.dsp.window.float({ action = "toggle" }))
bindd("SUPER + L", "Lock Screen", hl.dsp.exec_cmd(bin .. "/evo-system lock"))
bindd("SUPER + C", "Calc panel", hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.panel \'{"module":"calc"}\''))
bindd(
	"SUPER + N",
	"Tasks panel",
	hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.panel \'{"module":"calc","focus":"tasks"}\'')
)
bindd("SUPER + B", "Settings panel", hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.panel \'{"module":"settings"}\''))
bindd("SUPER + M", "Library", hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.library"))
bindd(
	"SUPER + V",
	"Clipboard history",
	hl.dsp.exec_cmd(shell_ipc .. " shell toggle evo.clipboard")
)
bindd("SUPER + P", "Colour Picker", hl.dsp.exec_cmd("hyprpicker -al"))

-- Programs
bindd("SUPER + 1", "Brave Browser", hl.dsp.exec_cmd(browser))
bindd("SUPER + 2", "Brave Incognito", hl.dsp.exec_cmd(browser .. " --incognito"))
bindd("SUPER + 3", "Brave Tor", hl.dsp.exec_cmd(browser .. " --tor"))

-- Switch workspaces with numpad keys
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

-- Move focus with arrow keys
bindd("SUPER + left", "Move Focus Left", hl.dsp.focus({ direction = "left" }))
bindd("SUPER + right", "Move Focus Right", hl.dsp.focus({ direction = "right" }))
bindd("SUPER + up", "Move Focus Up", hl.dsp.focus({ direction = "up" }))
bindd("SUPER + down", "Move Focus Down", hl.dsp.focus({ direction = "down" }))

-- Cycle workspaces with SUPER + Tab
bindd("SUPER + Tab", "Cycle to Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
bindd("SUPER + mouse_down", "Cycle to Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
bindd("SUPER + mouse_up", "Cycle to Previous Workspace", hl.dsp.focus({ workspace = "e-1" }))

-- Move active window to a workspace with numpad (follow = false = silent move)
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

-- Move/resize windows with mainMod + LMB/RMB and dragging
bindd("SUPER + mouse:272", "Move window with mouse", hl.dsp.window.drag(), { mouse = true })
bindd("SUPER + mouse:273", "Resize window with mouse", hl.dsp.window.resize(), { mouse = true })
bindd("SUPER + SHIFT + left", "Move Window Left", hl.dsp.window.move({ direction = "left" }))
bindd("SUPER + SHIFT + right", "Move Window Right", hl.dsp.window.move({ direction = "right" }))
bindd("SUPER + SHIFT + up", "Move Window Up", hl.dsp.window.move({ direction = "up" }))
bindd("SUPER + SHIFT + down", "Move Window Down", hl.dsp.window.move({ direction = "down" }))

-- Repeatable binds for resizing the active window
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

-- Volume controls (Pipewire via evoshell)
bindd(
	"XF86AudioRaiseVolume",
	"Volume up",
	hl.dsp.exec_cmd(shell_ipc .. " evo.audio stepUp"),
	{ locked = true, repeating = true }
)
bindd(
	"XF86AudioLowerVolume",
	"Volume down",
	hl.dsp.exec_cmd(shell_ipc .. " evo.audio stepDown"),
	{ locked = true, repeating = true }
)
bindd(
	"XF86AudioMute",
	"Mute volume",
	hl.dsp.exec_cmd(shell_ipc .. " evo.audio toggleMute"),
	{ locked = true, repeating = true }
)
bindd("XF86AudioPlay", "Play/Pause media", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bindd("XF86AudioNext", "Next media track", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bindd("XF86AudioPrev", "Previous media track", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Wallpaper
bindd("SUPER + comma", "Previous Wallpaper", hl.dsp.exec_cmd(shell_ipc .. " evo.background prev"))
bindd("SUPER + period", "Next Wallpaper", hl.dsp.exec_cmd(shell_ipc .. " evo.background next"))

-- Zoom level (evo panel settings)
bindd("SUPER + minus", "Zoom out", hl.dsp.exec_cmd(bin .. "/evo-font step-zoom down"))
bindd("SUPER + equal", "Zoom in", hl.dsp.exec_cmd(bin .. "/evo-font step-zoom up"))

-- Screenshot
bindd("PRINT", "Screenshot Region", hl.dsp.exec_cmd('bash -c "hyprshot -m region -o /tmp/ -f hyprshot.png;"'))
bindd(
	"ALT + PRINT",
	"Screenshot Active Monitor",
	hl.dsp.exec_cmd('bash -c "hyprshot -m output -m active -o /tmp/ -f hyprshot.png;"')
)
bindd(
	"SUPER + PRINT",
	"Annotate screenshot",
	hl.dsp.exec_cmd(shell_ipc .. ' shell toggle evo.screenshot \'{"path":"/tmp/hyprshot.png"}\'')
)
