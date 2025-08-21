local M = {
	em = {},
}

---@class music.ui.list.sdw_cache
---@field [string] {title: number, artist: number, album: number}
local sdw_cache = {}

---@param win snacks.win
---@param ns_id number
---@param playing string
---@param list music.backend.song[]
function M.render(win, ns_id, playing, list)
	local width = vim.api.nvim_win_get_width(win.win)
	local ml = { title = 0, artist = 0, album = 0 }
	for i = 1, #list do
		local song = list[i]
		local sdw = sdw_cache[song.id]
		if not sdw then
			sdw = {
				title = vim.fn.strdisplaywidth(song.title),
				artist = vim.fn.strdisplaywidth(song.artist),
				album = vim.fn.strdisplaywidth(song.album),
			}
			sdw_cache[song.id] = sdw
		end
		ml.title = math.max(ml.title, sdw.title)
		ml.artist = math.max(ml.artist, sdw.artist)
		ml.album = math.max(ml.album, sdw.album)
	end
	local padding = width - ml.title - ml.artist - ml.album - 3 -- 3 for the index
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
	for i = 1, #list do
		local song = list[i]
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
		if playing == song.id then
			style = "String"
		end
		M.em[i] = vim.api.nvim_buf_set_extmark(win.buf, ns_id, i - 1, 0, {
			virt_text = {
				{ string.format("%02d", i), "Type" },
				{ "|" .. string.rep(" ", tlp), "Normal" },
				{ song.title, style },
				{ string.rep(" ", trp), "Normal" },
				{ separator, "Normal" },
				{ string.rep(" ", alp), "Normal" },
				{ song.artist or "", style },
				{ string.rep(" ", arp), "Normal" },
				{ separator, "Normal" },
				{ string.rep(" ", alp2), "Normal" },
				{ song.album or "", style },
				{ string.rep(" ", arp2), "Normal" },
			},
			virt_text_pos = "overlay", --
			hl_mode = "combine",
			id = M.em[i],
		})
	end
	for i = #list + 1, vim.api.nvim_win_get_height(win.win) do
		if M.em[i] then
			vim.api.nvim_buf_del_extmark(win.buf, ns_id, M.em[i])
		end
	end
end

return M
