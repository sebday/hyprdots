require("input")
require("looks")
require("theme")
require("layouts/dashboard")
require("monitors")
require("windows")
require("layout")

local evoshell_root = os.getenv("EVOSHELL_ROOT") or ((os.getenv("HOME") or "") .. "/projects/evoshell")
dofile(evoshell_root .. "/hypr/bootstrap.lua")
require("hypr.init")

require("autostart")
