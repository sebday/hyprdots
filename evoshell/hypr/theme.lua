-- evoshell: hypr-border-accent
-- Reads accent from $EVOSHELL_STATE/hypr-border-accent at Hyprland startup.
-- Live theme switches update borders via hyprctl eval (do not rewrite this file).

local home = os.getenv("HOME") or ""
local state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
local accent_path = state_home .. "/evoshell/hypr-border-accent"

local function read_accent()
    local f = io.open(accent_path, "r")
    if not f then
        return "89b4fa"
    end
    local line = f:read("*l")
    f:close()
    if line and line:match("^%x%x%x%x%x%x$") then
        return line
    end
    return "89b4fa"
end

local accent = read_accent()

hl.config({
    general = {
        col = {
            active_border = "rgb(" .. accent .. ")",
        },
    },
    group = {
        col = {
            border_active = "rgb(" .. accent .. ")",
        },
    },
})
