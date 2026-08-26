-- Apply evoshell hypr-looks overrides from hypr-looks.json.

local function evoshell_config_dir()
	local config = os.getenv("EVOSHELL_CONFIG")
	if config and config ~= "" then
		return config
	end
	local xdg = os.getenv("XDG_CONFIG_HOME")
	if xdg and xdg ~= "" then
		return xdg .. "/evoshell"
	end
	return (os.getenv("HOME") or "") .. "/.config/evoshell"
end

local function shell_quote(value)
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function evoshell_bin()
	local bin = os.getenv("EVOSHELL_BIN")
	if bin and bin ~= "" then
		return bin
	end
	return (os.getenv("HOME") or "") .. "/.local/lib/evoshell/bin"
end

local function apply_saved_looks()
	local json_path = evoshell_config_dir() .. "/hypr-looks.json"
	local f = io.open(json_path, "r")
	if not f then
		return
	end
	f:close()

	local cmd = shell_quote(evoshell_bin()) .. "/evo-hyprland apply-saved >/dev/null 2>&1"
	-- Defer until after config load: calling hyprctl during reload deadlocks IPC.
	hl.timer(function()
		os.execute(cmd)
	end, { timeout = 1, type = "oneshot" })
end

apply_saved_looks()
