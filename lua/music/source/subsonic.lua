local u = require("music.util")
local su = require("snacks.util")
---@class music.source.subsonic.song.meta
---@field id string
---@field title string
---@field artist string
---@field album string
---
---@class music.source.subsonic.lyric_item
---@field start number
---@field value string

---@alias music.subsonic.lyric music.source.subsonic.lyric_item[]
---
---@class music.src:music.subsonic.config
---@diagnostic disable-next-line: missing-fields
local M = {}
M.__index = M

---@param opts music.subsonic.config
---@return (fun(opts: snacks.picker.Config, ctx: snacks.picker.finder.ctx): snacks.picker.finder.Item[])|nil
function M:new(opts)
	if not u.field_check("subsonic api", opts, "url", { "q", "u" }) then
		return nil
	end
	local src = vim.tbl_deep_extend("force", {
		url = nil, -- Base URL of the Subsonic server
		q = {
			f = "json", -- Response format
			c = "km0e/music.nvim", -- Client name
			v = "1.16.0", -- API version
		},
	}, opts)
	src = setmetatable(src, self)
	local q = src.q

	src.url = src.url .. "/rest/"
	if q.t and q.s then
		q.p = nil
	elseif q.p then
		q.p = "enc:" .. u.hex_encode(q.p)
		q.t = nil
		q.s = nil
	else
		vim.notify("No password or token provided, authentication failed", vim.log.levels.WARN)
		src.url = nil
	end
	return function(_, ctx)
		return src:search(ctx)
	end
end

---@param endpoint string
---@param q table
---@return table|nil
function M:query(endpoint, q)
	local curl = require("plenary.curl")
	local url = self.url .. endpoint .. ".view"
	q = vim.tbl_deep_extend("force", self.q, q)
	local response = curl.get(url, { query = q })
	if response.status ~= 200 then
		vim.notify("Failed to query " .. endpoint .. ": " .. response.status, vim.log.levels.ERROR)
		return nil
	end
	local data = vim.json.decode(response.body)
	if not data then
		vim.notify("Failed to parse response for " .. endpoint, vim.log.levels.ERROR)
		return nil
	end
	if not u.field_check("subsonic response", data, { "subsonic-response", "status" }) then
		return nil
	end
	local resp = data["subsonic-response"]
	if resp.status ~= "ok" then
		vim.notify("Query failed: " .. resp.status, vim.log.levels.ERROR)
		return nil
	end
	return resp
end

local function extract_song(song)
	return {
		id = song.id,
		title = song.title,
		artist = song.artist,
		album = song.album,
	}
end

function M:lyric(id)
	local resp = self:query("getLyricsBySongId", { id = id })
	if
		not resp
		or not u.field_check("subsonic getLyrics with " .. id, resp, "lyricsList")
		or not resp.lyricsList.structuredLyrics
	then
		return {}
	end
	local all_lyrics = resp.lyricsList.structuredLyrics
	if #all_lyrics == 0 then
		return {}
	end
	---@type music.subsonic.lyric
	local slyrics = all_lyrics[1].line or {}
	---@type music.lyric
	local lyrics = {}
	for i, line in ipairs(slyrics) do
		lyrics[i] = { time = line.start / 1000, line = line.value }
	end
	return lyrics
end

---@class music.src.title_cache
---@field [string] snacks.picker.finder.Item[]
local tcache = {}

---
---@param ctx snacks.picker.finder.ctx
---@return snacks.picker.finder.result
function M:_search(ctx)
	local input = ctx.picker.input:get()
	local resp = self:query("search3", {
		query = input,
		songOffset = 0,
		songCount = 1024,
		artistCount = 0,
		albumCount = 0,
	})
	if not resp or not u.field_check("subsonic search3", resp, "searchResult3") then
		return {}
	end
	---@type snacks.picker.finder.Item[]
	local songs = {}
	for i, s in ipairs(resp.searchResult3.song or {}) do
		songs[i] = extract_song(s)
		songs[i].stream_url = self:stream(s.id)
		songs[i].lyric = self:lyric(s.id)
	end
	return songs
end

---@param ctx snacks.picker.finder.ctx
---@return snacks.picker.finder.Item[]
function M:search(ctx)
	local input = ctx.picker.input:get()
	tcache[input] = tcache[input] or self:_search(ctx)
	return tcache[input]
end

---@param id string
---@return music.source.subsonic.song.meta|nil
function M:get(id)
	local resp = self:query("getSong", { id = id })
	if not resp or not u.field_check("subsonic getSong", resp, "song") then
		return nil
	end
	return extract_song(resp.song)
end

---@param id string
---@return string
function M:stream(id)
	local url = self.url .. "stream.view"
	local q = vim.tbl_deep_extend("force", self.q, {
		id = id,
	})
	return url .. "?" .. u.kv_to_str(q)
end

return M
