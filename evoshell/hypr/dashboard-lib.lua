local M = {}

function M.is_dashboard_title(title)
	title = title or ""
	return title:match("^evo%.panels%.[^%.]+$") ~= nil
		or title:match("^evo%.panels%.shopify") ~= nil
end

function M.is_pinned_dashboard_title(title)
	title = title or ""
	if title:match("^evo%.panels%.shopify") then
		return true
	end
	return title == "evo.panels.player"
end

function M.is_dashboard_window(win)
	if not win or win.class ~= "org.quickshell" then
		return false
	end
	return M.is_dashboard_title(win.title)
end

function M.is_pinned_dashboard_window(win)
	return M.is_dashboard_window(win) and M.is_pinned_dashboard_title(win.title)
end

function M.foreach_dashboard_window(callback)
	local wins = hl.get_windows({ class = "org.quickshell" })
	for _, win in ipairs(wins) do
		if M.is_dashboard_window(win) then
			callback(win)
		end
	end
end

return M
