-- Extra autostart processes.
-- o.launch_on_start("my-service")

local function launch_on_workspace(workspace, command)
  o.exec_on_start("[workspace " .. workspace .. " silent] " .. command)
end

local google_home_cameras =
"https://home.google.com/u/1/home/1-cb9859514d100077a7514292e70d3ce0c2419bd91e574642c34b63737d643b87/cameras/list/1-e6e317616dac9c683493bfc2faf697647c943b1b6316126c972ff4f62456926e?da=true"

launch_on_workspace("2", o.launch("brave"))
launch_on_workspace("10", o.launch_webapp(google_home_cameras))
launch_on_workspace("10", "omarchy-launch-tui btop")
launch_on_workspace("10", "omarchy-launch-tui evoplayer")
launch_on_workspace("10", "omarchy-launch-tui evoshopify")
o.launch_on_start("insync")

-- Prepend ~/.local/bin so hyprdots wrappers override stock Omarchy binaries
-- (e.g. filtered omarchy-theme-switcher for the theme picker).
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
hl.env("OMARCHY_SCREENSHOT_EDITOR", "omasnap-edit")
