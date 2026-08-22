-- Extend Lua module search so require("hypr.*") resolves from the evoshell repo.

local home = os.getenv("HOME") or ""
local root = os.getenv("EVOSHELL_ROOT") or (home .. "/projects/evoshell")

package.path = root .. "/?.lua;" .. package.path
