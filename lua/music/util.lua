local M = {}
function M.notify(msg, level)
	---@param notif snacks.notp sifier.Notif
	local function keep(notif)
		notif.timeout = 20000 -- 5 seconds
		return false
	end
	vim.notify(msg, level or vim.log.levels.INFO, {
		--@type fun(notif: snacks.notifier.Notif): boolean
		keep = keep,
	})
end

return M
