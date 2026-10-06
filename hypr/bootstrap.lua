-- Extend Lua module search so require("hypr.*") resolves from the evoshell repo.
-- Hyprland does not inherit EVOSHELL_ROOT, so read the same environment file
-- that evoshell.service uses.

local home = os.getenv("HOME") or ""
local root = os.getenv("EVOSHELL_ROOT")
if not root or root == "" then
	local env_file = home .. "/.config/evoshell/environment"
	local f = io.open(env_file, "r")
	if f then
		for line in f:lines() do
			local value = line:match("^EVOSHELL_ROOT=(.+)$")
			if value and value ~= "" then
				root = value
				break
			end
		end
		f:close()
	end
end
if not root or root == "" then
	root = home .. "/projects/hyprdots"
end

package.path = root .. "/?.lua;" .. package.path
