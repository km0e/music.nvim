---@class music.source.song.meta
---@field id string
---@field title string
---@field artist? string
---@field album? string

---@class music._source
---@field setup fun(self, opts: table)
---@field search fun(self, name: string, offset: number, count: number): music.source.song.meta[]|nil
---@field get fun(self, id: string): music.source.song.meta|nil
---@field stream fun(self, song_id: string): string
---@field lyric fun(self, song_id: string): music.lyric

---@class music.source.lyric_item
---@field start number
---@field value string

---@alias music.source.lyric music.source.lyric_item[]

---@class music.source.song
---@field meta music.song.meta?
---@field lyric music.lyric?

---@class music.source
---@field cache table<string, music.source.song>
---@field srcs table<string, music._source>
---@field setup fun(self, opts: table)
---@field search fun(self, name: string, offset: number, count: number, cb: fun(songs: music.song.meta[])): nil
---@field get fun(self, id: string): music.song.meta|nil
---@field stream fun(self, id: string): string
---@field lyric fun(self, id: string): music.lyric
local M = {
	cache = {},
	srcs = {
		subsonic = require("music.source.subsonic"),
	},
}

local su = require("snacks.util")
local u = require("music.util")

---@param ssong music.source.song.meta
---@return music.song.meta
local function song_comp(ssong)
	return {
		id = ssong.id,
		title = ssong.title,
		artist = ssong.artist or "Unknown Artist",
		album = ssong.album or "Unknown Album",
	}
end

---@class music.source.title_cache
---@field [string] music.song.meta[]
local tcache = {}

function M:search(name, offset, count, cb)
	local cached = tcache[name]
	if cached and #cached >= offset + count then
		cb(vim.list_slice(cached, offset + 1, offset + count))
		return
	end

	su.debounce(function()
		---@type music.song.meta[]
		cached = cached or {}
		local metas = self.srcs.subsonic:search(name, offset, count)
		if metas then
			for i, smeta in ipairs(metas) do
				local meta = song_comp(smeta)
				meta.id = "subsonic:" .. smeta.id
				local song = self.cache[meta.id]
				if not song then
					song = { meta = meta }
					self.cache[meta.id] = song
				else
					song.meta = meta
				end
				cached[offset + i] = meta
			end
		end
		tcache[name] = cached
		cb(vim.list_slice(cached, offset + 1, offset + count))
	end, { ms = 500 })()
end

function M:get(id)
	local song = self.cache[id]
	if song and song.meta then
		return song.meta
	end
	local source, sid = id:match("([^:]+):(.+)")
	local ssong = self.srcs[source]:get(sid)
	if not ssong then
		vim.notify("Song not found: " .. id, vim.log.levels.ERROR)
		return nil
	end
	song = song or {}
	song.meta = song_comp(ssong)
	song.meta.id = id
	self.cache[id] = song
	return song.meta
end

function M:stream(id)
	local source, sid = id:match("([^:]+):(.+)")
	return self.srcs[source]:stream(sid)
end

function M:lyric(id)
	local song = self.cache[id]
	if song and song.lyric then
		return song.lyric
	end
	local source, sid = id:match("([^:]+):(.+)")
	if not sid or sid == "" then
		return {}
	end
	local lyric = self.srcs[source]:lyric(sid)
	if not song then
		song = { lyric = lyric }
		self.cache[id] = song
	else
		song.lyric = lyric
	end
	return lyric
end

---@class music.source.config
---@field subsonic music.source.subsonic.config

---@param opts music.source.config
function M:setup(opts)
	self.srcs.subsonic:setup(opts.subsonic)
end

return M
