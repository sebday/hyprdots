local home = os.getenv("HOME") or ""
local evo = home .. "/.local/bin/evo"
local lib = os.getenv("EVOSHELL_BIN") or (home .. "/.local/lib/evoshell/bin")
local shell_ipc = evo .. " ipc"

bindd("SUPER + Space", "System menu", hl.dsp.global("evoshell:systemMenu"))
bindd("SUPER + W", "Close window", hl.dsp.window.close())
bindd(
    "SUPER + L",
    "Lock screen",
    hl.dsp.exec_cmd(shell_ipc .. " evo.sys.lock-screen.lock lock"),
    { locked = true, repeating = false }
)
bindd("SUPER + F", "Fullscreen", hl.dsp.window.fullscreen())
bindd("SUPER + left", "Focus left", hl.dsp.focus({ direction = "left" }))
