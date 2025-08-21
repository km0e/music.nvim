---@class music.source.song
---@field id string
---@field title string
---@field artist? string
---@field album? string

---@class music._source
---@field setup fun(self, opts: table)
---@field search fun(self, name: string, offset: number, count: number): music.source.song[]|nil
---@field get fun(self, id: string): music.source.song|nil
---@field stream fun(self, song_id: string): string

---@class music.source
---@field cache table<string, music.backend.song>
---@field srcs table<string, music._source>
---@field setup fun(self, opts: table)
---@field search fun(self, name: string, offset: number, count: number, cb: fun(songs: music.backend.song[])): nil
---@field get fun(self, id: string): music.backend.song|nil
---@field stream fun(self, id: string): string
local M = {
	cache = {},
	srcs = {
		subsonic = require("music.source.subsonic"),
	},
}

local su = require("snacks.util")
local u = require("music.util")

---@param ssong music.source.song
---@return music.backend.song
local function song_comp(ssong)
	return {
		id = ssong.id,
		title = ssong.title,
		artist = ssong.artist or "Unknown Artist",
		album = ssong.album or "Unknown Album",
	}
end

---@class music.source.title_cache
---@field [string] music.backend.song[]
local tcache = {}

function M:search(name, offset, count, cb)
	local cached = tcache[name]
	if cached and #cached >= offset + count then
		cb(vim.list_slice(cached, offset + 1, offset + count))
		return
	end

	su.debounce(function()
		---@type music.backend.song[]
		cached = cached or {}
		local r = self.srcs.subsonic:search(name, offset, count)
		if r then
			for i, song in ipairs(r) do
				local s = song_comp(song)
				s.id = "subsonic:" .. song.id
				self.cache[s.id] = s
				cached[offset + i] = s
			end
		end
		tcache[name] = cached
		cb(vim.list_slice(cached, offset + 1, offset + count))
	end, { ms = 500 })()
end

function M:get(id)
	local song = self.cache[id]
	if song then
		return song
	end
	local source, sid = id:match("([^:]+):(.+)")
	local ssong = self.srcs[source]:get(sid)
	if not ssong then
		vim.notify("Song not found: " .. id, vim.log.levels.ERROR)
		return nil
	end
	song = song_comp(ssong)
	song.id = id
	self.cache[id] = song
	return song
end

function M:stream(id)
	local source, sid = id:match("([^:]+):(.+)")
	return self.srcs[source]:stream(sid)
end

---@class music.source.config
---@field subsonic music.source.subsonic.config

---@param opts music.source.config
function M:setup(opts)
	self.srcs.subsonic:setup(opts.subsonic)
end

return M
