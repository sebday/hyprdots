require("input")
require("looks")
require("theme")
require("layouts/dashboard")
require("monitors")
require("windows")
require("layout")

local function evoshell_root()
	local root = os.getenv("EVOSHELL_ROOT")
	if root and root ~= "" then
		return root
	end
	local home = os.getenv("HOME") or ""
	local env_file = home .. "/.config/evoshell/environment"
	local f = io.open(env_file, "r")
	if f then
		for line in f:lines() do
			local value = line:match("^EVOSHELL_ROOT=(.+)$")
			if value and value ~= "" then
				f:close()
				return value
			end
		end
		f:close()
	end
	return home .. "/projects/evoshell"
end

local bootstrap = evoshell_root() .. "/hypr/bootstrap.lua"
local bootstrap_file = io.open(bootstrap, "r")
if not bootstrap_file then
	error(
		"evoshell bootstrap missing at "
			.. bootstrap
			.. " (clone evoshell to ~/projects/evoshell or run scripts/install)"
	)
end
bootstrap_file:close()
dofile(bootstrap)
require("hypr.init")

require("autostart")
