local u = require("music.util")
local M = {
	em = {},
}

local function transform_mode(mode)
	if mode == "once" then
		return "⏹️"
	elseif mode == "loop" then
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

local function render_playlist(win, ns_id, state, row_end, width)
	local song_count = math.min(#state.playlist - state.soffset, row_end)
	local ml = { title = 0, artist = 0, album = 0 }
	for i = 1, song_count do
		local song = state.playlist[state.soffset + i]
		local sdw = sdw_cache[song.id]
		if not sdw then
			sdw = {
				title = vim.fn.strdisplaywidth(song.title or ""),
				artist = vim.fn.strdisplaywidth(song.artist or ""),
				album = vim.fn.strdisplaywidth(song.album or ""),
			}
			sdw_cache[song.id] = sdw
		end
		ml.title = math.max(ml.title, sdw.title)
		ml.artist = math.max(ml.artist, sdw.artist)
		ml.album = math.max(ml.album, sdw.album)
	end
	local padding = width - ml.title - ml.artist - ml.album --
	local separator = " | "
	if padding < 2 then
		vim.notify("Not enough space to render panel", vim.log.levels.WARN)
		return
	elseif padding < 6 then
		separator = "|"
		padding = padding - 2
	else
		padding = padding - 6
	end
	local extra_space = math.floor(padding / 3)
	ml.title = ml.title + extra_space
	ml.artist = ml.artist + extra_space
	ml.album = ml.album + extra_space
	local left_padding = padding - extra_space * 3
	if left_padding > 0 then
		local ml_list = { ml.title, ml.artist, ml.album }
		local index = { 1, 2, 3 }
		table.sort(index, function(a, b)
			return ml_list[a] > ml_list[b]
		end)
		for i = 1, left_padding do
			ml_list[index[i]] = ml_list[index[i]] + 1
		end
		ml.title, ml.artist, ml.album = ml_list[1], ml_list[2], ml_list[3]
	end
	for i = 1, song_count do
		local song = state.playlist[state.soffset + i]
		local sdw = sdw_cache[song.id]
		padding = ml.title - sdw.title
		local tlp = math.floor(padding / 2)
		local trp = padding - tlp
		padding = ml.artist - sdw.artist
		local alp = math.floor(padding / 2)
		local arp = padding - alp
		padding = ml.album - sdw.album
		local alp2 = math.floor(padding / 2)
		local arp2 = padding - alp2
		local style = "Identifier"
		if state.playing == state.soffset + i then
			style = "String"
		end
		M.em[i] = vim.api.nvim_buf_set_extmark(win.buf, ns_id, i - 1, 0, {
			virt_text = {
				{ string.rep(" ", tlp),  "Normal" },
				{ song.title,            style },
				{ string.rep(" ", trp),  "Normal" },
				{ separator,             "Normal" },
				{ string.rep(" ", alp),  "Normal" },
				{ song.artist or "",     style },
				{ string.rep(" ", arp),  "Normal" },
				{ separator,             "Normal" },
				{ string.rep(" ", alp2), "Normal" },
				{ song.album or "",      style },
				{ string.rep(" ", arp2), "Normal" },
			},
			virt_text_pos = "overlay", --
			hl_mode = "combine",
			id = M.em[i],
		})
	end
	for i = song_count + 1, row_end do
		if M.em[i] then
			vim.api.nvim_buf_del_extmark(win.buf, ns_id, M.em[i])
		end
	end
end

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
---@param state music.ui.state
function M:render(win, ns_id, state)
	local width = vim.api.nvim_win_get_width(win.win) - 1 -- right border
	local start = vim.api.nvim_win_get_height(win.win) - 2 -- bottom status line
	render_playlist(win, ns_id, state, start, width)

	local text = make_progress_text(state.playing_time, state.total_time)
	local rest = width - vim.fn.strdisplaywidth(text) -- 2 for the brackets
	local bar = make_progress_bar(state.playing_time, state.total_time, rest)
	self.emt = vim.api.nvim_buf_set_extmark(win.buf, ns_id, start, 0, {
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
	if state.paused then
		paused = "▶️"
	end
	local mode = transform_mode(state.mode)
	local padding = width - vim.fn.strdisplaywidth(paused) - vim.fn.strdisplaywidth(mode)
	local lpadding = math.floor(padding / 2)
	local rpadding = padding - lpadding
	self.ems = vim.api.nvim_buf_set_extmark(win.buf, ns_id, start + 1, 0, {
		virt_text = {
			{ string.rep(" ", lpadding), "Normal" },
			{ paused,                    "Identifier" },
			{ string.rep(" ", rpadding), "Normal" },
			{ mode,                      "String" },
		},
		virt_text_pos = "overlay", --
		hl_mode = "combine",
		id = self.ems,
	})
end

function M:clear(win, ns_id)
	for _, em in pairs(self.em) do
		vim.api.nvim_buf_del_extmark(win.buf, ns_id, em)
	end
	if self.emt then
		vim.api.nvim_buf_del_extmark(win.buf, ns_id, self.emt)
	end
	if self.ems then
		vim.api.nvim_buf_del_extmark(win.buf, ns_id, self.ems)
	end
end

return M
