-- Extend Lua module search so require("hypr.*") resolves from the evoshell repo.

local home = os.getenv("HOME") or ""
local root = os.getenv("EVOSHELL_ROOT")
if not root or root == "" then
	root = home .. "/projects/evoshell"
end

package.path = root .. "/?.lua;" .. package.path
