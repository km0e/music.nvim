local core = require("music.core")

local M = {
	---@type table<string, {title: number, artist: number, album: number}>
	sdw_cache = {},
	separator = "|",
	sdw = vim.fn.strdisplaywidth("|"),
	ml = { title = 0, artist = 0, album = 0 },
}

---@param songs music.song[]|snacks.picker.finder.Item[]
function M:cache(songs)
	self.ml = { title = 0, artist = 0, album = 0 }
	for _, song in ipairs(songs) do
		local sdw = self.sdw_cache[song.id]
		if not sdw then
			sdw = {
				title = vim.fn.strdisplaywidth(song.title),
				artist = vim.fn.strdisplaywidth(song.artist),
				album = vim.fn.strdisplaywidth(song.album),
			}
			self.sdw_cache[song.id] = sdw
			self.ml.title = math.max(self.ml.title, sdw.title)
			self.ml.artist = math.max(self.ml.artist, sdw.artist)
			self.ml.album = math.max(self.ml.album, sdw.album)
		end
	end
end

---@param song music.song|snacks.picker.Item
---@param width number
---@param opts? {idx?: boolean}
---@return snacks.picker.Highlight[]
function M:format(song, width, opts)
	opts = opts or {}
	local idx_dw = opts.idx and (self.sdw + 2) or 0 -- for the index
	local min_width = self.ml.title + self.ml.artist + self.ml.album + self.sdw * 2 + idx_dw
	if width < min_width then
		vim.notify(("Not enough space to render list: {} < {}"):format(width, min_width), vim.log.levels.WARN)
		return {}
	end
	local padding = width - min_width
	local extra_space = math.floor(padding / 3)
	self.ml.title = self.ml.title + extra_space
	self.ml.artist = self.ml.artist + extra_space
	self.ml.album = self.ml.album + extra_space
	local left_padding = padding - extra_space * 3
	if left_padding > 0 then
		local ml_list = { self.ml.title, self.ml.artist, self.ml.album }
		local index = { 1, 2, 3 }
		table.sort(index, function(a, b)
			return ml_list[a] > ml_list[b]
		end)
		for i = 1, left_padding do
			ml_list[index[i]] = ml_list[index[i]] + 1
		end
		self.ml.title, self.ml.artist, self.ml.album = ml_list[1], ml_list[2], ml_list[3]
	end

	local sdw = self.sdw_cache[song.id]
	padding = self.ml.title - sdw.title
	local tlp = math.floor(padding / 2)
	local trp = padding - tlp
	padding = self.ml.artist - sdw.artist
	local alp = math.floor(padding / 2)
	local arp = padding - alp
	padding = self.ml.album - sdw.album
	local alp2 = math.floor(padding / 2)
	local arp2 = padding - alp2

	local style = "Identifier"
	if core.state.playing and core.state.playing.id == song.id then
		style = "String"
	end

	local res = {}
	if opts.idx then
		res[#res + 1] = { string.format("%02d", song.idx), "Type" }
		res[#res + 1] = { self.separator, nil }
	end
	res[#res + 1] = { string.rep(" ", tlp), nil }
	res[#res + 1] = { song.title, style }
	res[#res + 1] = { string.rep(" ", trp) .. self.separator .. string.rep(" ", alp), nil }
	res[#res + 1] = { song.artist or "", style }
	res[#res + 1] = { string.rep(" ", arp) .. self.separator .. string.rep(" ", alp2), nil }
	res[#res + 1] = { song.album or "", style }
	res[#res + 1] = { string.rep(" ", arp2), nil }
	return res
end

return M
