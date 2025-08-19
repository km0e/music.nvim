local u = require("music.util")
local M = {
	em = {},
}

---@param win snacks.win
---@param ns_id number
---@param state music.ui.state
function M:render(win, ns_id, state)
	local height = vim.api.nvim_win_get_height(win.win)
	for i = 1, math.min(#state.search, height) do
		local song = state.search[i]
		self.em[i] = vim.api.nvim_buf_set_extmark(win.buf, ns_id, i - 1, 0, {
			virt_text = {
				{ string.format("%d. ", i + state.soffset), "Identifier" },
				{ song.title,                               "Identifier" },
				{ " - ",                                    "Normal" },
				{ song.artist or "Unknown Artist",          "String" },
				{ " - ",                                    "Normal" },
				{ song.album or "Unknown Album",            "String" },
			},
			virt_text_pos = "overlay", --
			hl_mode = "combine",
			id = self.em[i],
		})
	end
	for i = #state.search + 1, height do
		if self.em[i] then
			vim.api.nvim_buf_del_extmark(win.buf, ns_id, self.em[i])
			self.em[i] = nil
		end
	end
end

function M:clear(win, ns_id)
	for _, em in pairs(self.em) do
		vim.api.nvim_buf_del_extmark(win.buf, ns_id, em)
	end
end

return M
