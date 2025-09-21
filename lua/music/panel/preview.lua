local fmt = require("music.panel.format")
local core = require("music.core")
local u = require("music.util")
---@class music.preview:music.core.api
---@field offset number
local M = {
	offset = 0,
	ns_id = nil,
	em = {},
	emt = nil,
	ems = nil,
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

local function make_progress_bar(current, total, width)
	local ratio = math.min(current / total, 1)
	width = width - 2 -- 2 for the brackets
	local filled = math.floor(ratio * width)
	local empty = width - filled
	return ("[%s>%s]"):format(string.rep("=", filled), string.rep(".", math.max(empty - 1, 0)))
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

function M:setup()
	self.ns_id = vim.api.nvim_create_namespace("PluginMusicPreview")
end

---@param ctx snacks.picker.preview.ctx
function M:render(ctx)
	local height = vim.api.nvim_win_get_height(ctx.win)
	vim.bo[ctx.buf].modifiable = true
	local space = {}
	for _ = 0, height - 1 do
		table.insert(space, "")
	end
	vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, space)
	vim.bo[ctx.buf].modifiable = false

	local width = vim.api.nvim_win_get_width(ctx.win) - 2 -- right border
	local start = height - 2                             -- bottom status line

	-- l.render(win, ns_id, self.playing, vim.list_slice(self.playlist, self.offset, self.offset + start - 1))

	local text = make_progress_text(self.playing_time, self.total_time)
	local rest = width - vim.fn.strdisplaywidth(text) -- 2 for the brackets
	local bar = make_progress_bar(self.playing_time, self.total_time, rest)
	self.emt = vim.api.nvim_buf_set_extmark(ctx.buf, self.ns_id, start, 0, {
		virt_text = {
			{ bar,  "Identifier" },
			{ " ",  "Normal" },
			{ text, "String" },
		},
		virt_text_pos = "overlay", --
		hl_mode = "combine",
		id = self.emt,
	})

	local paused = "⏸️"
	if self.pause then
		paused = "▶️"
	end
	local mode = transform_mode(self.mode)
	local padding = width - vim.fn.strdisplaywidth(paused) - vim.fn.strdisplaywidth(mode)
	local lpadding = math.floor(padding / 2)
	local rpadding = padding - lpadding
	self.ems = vim.api.nvim_buf_set_extmark(ctx.buf, self.ns_id, start + 1, 0, {
		virt_text = {
			{ string.rep(" ", lpadding), nil },
			{ paused,                    "Identifier" },
			{ string.rep(" ", rpadding), nil },
			{ mode,                      "String" },
		},
		virt_text_pos = "overlay", --
		hl_mode = "combine",
		id = self.ems,
	})

	local playlist = vim.list_slice(core.state.playlist, self.offset, self.offset + start - 1)
	fmt:cache(playlist)

	for i, song in ipairs(playlist) do
		self.em[i] = vim.api.nvim_buf_set_extmark(ctx.buf, self.ns_id, i - 1, 0, {
			virt_text = fmt:format(song, width),
			virt_text_pos = "overlay",
			hl_mode = "combine",
			id = self.em[i],
		})
	end
	return true
end

return M
