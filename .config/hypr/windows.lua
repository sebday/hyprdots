-- App window rules (loaded after Omarchy defaults).
o.window("^(Insync)$", { tag = "+floating-window" })

-- Omarchy defaults org.omarchy.btop to a centered floating popup.
-- Tile it so the workspace 10 autostart instance is a normal window.
-- Super+Ctrl+T (Activity) uses the same class, so that shortcut tiles too.
o.window("org.omarchy.btop", { tag = "-floating-window", tile = true })

-- Pop & pin (Super+O): Omarchy defaults to rounded corners for the pop tag.
o.window({ tag = "pop" }, { rounding = 0 })

-- Brave/Chromium web notifications on Wayland are real xdg-toplevels with the
-- browser class (or empty class/title). Omarchy then tiles every
-- chromium-based-browser window, so those balloons become layout tiles.
-- Loaded after the stock tile rule so float wins. Static title matching uses
-- initialTitle: normal tabs end with " - Brave"; Message Center balloons do not.
o.window({
  class = "^brave-browser$",
  title = "negative: - Brave$",
}, {
  float = true,
  no_initial_focus = true,
  decorate = false,
  animation = "popin 80%",
})

o.window({
  class = "^$",
  title = "^$",
  xwayland = false,
}, {
  float = true,
  no_initial_focus = true,
})

local function window_wh(w)
  local s = w and w.size
  if type(s) ~= "table" then return 0, 0 end
  return tonumber(s[1] or s.x or s.width) or 0, tonumber(s[2] or s.y or s.height) or 0
end

local function is_brave_message_center(w)
  if w == nil then return false end
  local class = w.initial_class or w.class or ""
  local title = w.initial_title or ""
  if class ~= "brave-browser" then return false end
  if title:find(" %- Brave$") then return false end
  if title:find("DevTools", 1, true) then return false end
  return true
end

local function float_brave_notification(w)
  if w == nil or not w.mapped then return end
  if not is_brave_message_center(w) then return end
  hl.dispatch(hl.dsp.window.float({ window = w, action = "enable" }))
  local width, height = window_wh(w)
  if width > 520 or height > 280 then
    hl.dispatch(hl.dsp.window.resize({
      window = w,
      x = 380,
      y = 140,
      relative = false,
    }))
  end
end

-- Tile is static and already applied by the time window.open fires; dispatch
-- float here so the balloon does not stay as a dwindle split.
hl.on("window.open", function(w)
  if not is_brave_message_center(w) then return end
  hl.timer(function()
    float_brave_notification(w)
  end, { timeout = 1, type = "oneshot" })
end)
