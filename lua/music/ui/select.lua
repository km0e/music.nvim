local l = require("music.ui.list")
local u = require("music.util")

---@class music.ui.select
---@field search_list music.backend.song[]
---@field offset number
local M = {
	search_list = {},
	offset = 0,
}

---@param win snacks.win
---@param ns_id number
---@param playing string
function M:render(win, ns_id, playing)
	local height = vim.api.nvim_win_get_height(win.win)
	l.render(win, ns_id, playing, vim.list_slice(self.search_list, self.offset + 1, self.offset + height))
end

return M
