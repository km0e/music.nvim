local l = require("music.ui.list")
local u = require("music.util")
---@class music.ui.panel
---@field playlist music.backend.song[]
---@field playing_time number
---@field total_time number
local M = {
	playlist = {},
	offset = 0,
	playing_time = 0.00,
	total_time = 1.00,
	paused = false,
	mode = "pl",
}

local function transform_mode(mode)
	if mode == "loop" then
		return "🔂"
	elseif mode == "pl" then
		return "➡️"
	elseif mode == "pl_loop" then
		return "🔁"
	end
end

---@class music.ui.panel.sdw_cache
---@field [string] {title: number, artist: number, album: number}
local sdw_cache = {}

local function make_progress_bar(current, total, width)
	local ratio = math.min(current / total, 1)
	width = width - 2 -- 2 for the brackets
	local filled = math.floor(ratio * width)
	local empty = width - filled
	return string.format("[%s>%s]", string.rep("=", filled), string.rep(".", math.max(empty - 1, 0)))
end

local function make_progress_text(current, total)
	local function tfmt(seconds)
		seconds = seconds or 0.00
		local minutes = math.floor(seconds / 60)
		local sec = seconds - minutes * 60
		return string.format("%d:%.1f", minutes, sec)
	end
	return string.format("%s/%s", tfmt(current), tfmt(total))
end

---@param win snacks.win
---@param ns_id number
---@param playing string
function M:render(win, ns_id, playing)
	local width = vim.api.nvim_win_get_width(win.win) - 2 -- right border
	local start = vim.api.nvim_win_get_height(win.win) - 2 -- bottom status line
	l.render(win, ns_id, playing, vim.list_slice(self.playlist, self.offset, self.offset + start - 1))

	local text = make_progress_text(self.playing_time, self.total_time)
	local rest = width - vim.fn.strdisplaywidth(text) -- 2 for the brackets
	local bar = make_progress_bar(self.playing_time, self.total_time, rest)
	self.emt = vim.api.nvim_buf_set_extmark(win.buf, ns_id, start, 0, {
		virt_text = {
			{ bar, "Identifier" },
			{ " ", "Normal" },
			{ text, "String" },
		},
		virt_text_pos = "overlay", --
		hl_mode = "combine",
		id = self.emt,
	})

	local paused = "⏸️"
	if self.paused then
		paused = "▶️"
	end
	local mode = transform_mode(self.mode)
	local padding = width - vim.fn.strdisplaywidth(paused) - vim.fn.strdisplaywidth(mode)
	local lpadding = math.floor(padding / 2)
	local rpadding = padding - lpadding
	self.ems = vim.api.nvim_buf_set_extmark(win.buf, ns_id, start + 1, 0, {
		virt_text = {
			{ string.rep(" ", lpadding), "Normal" },
			{ paused, "Identifier" },
			{ string.rep(" ", rpadding), "Normal" },
			{ mode, "String" },
		},
		virt_text_pos = "overlay", --
		hl_mode = "combine",
		id = self.ems,
	})
end

function M:clear(win, ns_id)
	if self.emt then
		vim.api.nvim_buf_del_extmark(win.buf, ns_id, self.emt)
	end
	if self.ems then
		vim.api.nvim_buf_del_extmark(win.buf, ns_id, self.ems)
	end
end

return M
