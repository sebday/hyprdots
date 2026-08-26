-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Prepend ~/.local/bin so hyprdots wrappers override stock Omarchy binaries
-- (e.g. filtered omarchy-theme-switcher for the bar theme picker).
-- Must move to front even when ~/.local/bin is already at the end of PATH.
local home = os.getenv("HOME")
local local_bin = home .. "/.local/bin"
local kept = {}
for entry in (os.getenv("PATH") or ""):gmatch("[^:]+") do
	if entry ~= local_bin then
		table.insert(kept, entry)
	end
end
table.insert(kept, 1, local_bin)
hl.env("PATH", table.concat(kept, ":"))
