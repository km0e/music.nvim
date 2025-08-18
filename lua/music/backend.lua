---@class music.backend
---@field setup fun(opts: {url: string, u: string, p: string, v?: string}): nil
---@field lazy_setup fun(): nil
---@field play fun(song_id: string, append?: boolean): nil
---@field toggle fun(): nil
---@field search fun(name: string, offset: number, count: number): nil
---@field mode fun(mode: string): nil
---@field render fun(msg: music.backend.msg): nil
local M = {
	---@type fun(msg: music.backend.msg): nil
	render = nil,
}

---@class music.backend.song
---@field id string
---@field title string
---@field artist? string
---@field album? string

local function parse_song(song)
	return {
		id = song.id,
		title = song.title,
		artist = song.artist or "Unknown Artist",
		album = song.album or "Unknown Album",
	}
end

---
---@class music.backend.title_cache
---@field [string] music.backend.song[]
local tcache = {}

---@class music.backend.id_cache
---@field [string] music.backend.song
local icache = {}

local mpv = require("music.mpv")
local su = require("snacks.util")

local cfg = {
	url = nil,
	query = {
		c = "music.nvim",
		f = "json",
		v = nil,
		u = nil,
		p = "",
	},
}

---@class music.backend.msg:{}
---@field album? string
---@field artist? string
---@field title? string
---@field paused? boolean
---@field total_time? number
---@field playing_time? number
---@field playlist? table
---@field playing? number

local function field_check(data, ...)
	for _, field in ipairs({ ... }) do
		if not data[field] then
			vim.notify("Missing field: " .. field, vim.log.levels.ERROR)
			return false
		end
	end
	return true
end

---@param endpoint string
---@param q table
---@return table|nil
local function query(endpoint, q)
	local curl = require("plenary.curl")
	local url = cfg.url .. "/rest/" .. endpoint .. ".view"
	q = vim.tbl_deep_extend("force", cfg.query, q)
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
	if not field_check(data, "subsonic-response") then
		return nil
	end
	local resp = data["subsonic-response"]
	if not field_check(resp, "status") then
		return nil
	end
	if resp.status ~= "ok" then
		vim.notify("Query failed: " .. resp.status, vim.log.levels.ERROR)
		return nil
	end
	return resp
end

---@param id string
---@return music.backend.song|nil
local function get(id)
	local resp = query("getSong", { id = id })
	if not resp then
		return nil
	end
	if not field_check(resp, "song") then
		return nil
	end
	return parse_song(resp.song)
end

function M.setup(opts)
	opts = opts or {}
	if not field_check(opts, "url", "u", "p") then
		return
	end
	cfg.url = opts.url
	cfg.query.v = opts.v or "1.12.0"
	cfg.query.u = opts.u
	cfg.query.p = ""

	for i = 1, #opts.p do
		cfg.query.p = cfg.query.p .. string.format("%02x", opts.p:byte(i))
	end
	cfg.query.p = "enc:" .. cfg.query.p

	local augid = vim.api.nvim_create_augroup("PluginMusicBackend", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augid,
		callback = function()
			mpv.exec("quit")
		end,
	})

	mpv.setup()

	mpv.observe("metadata")
	mpv.observe("paused")
	mpv.observe("total_time")
	mpv.observe("playlist")

	vim.uv.new_timer():start(100, 100, function()
		mpv.exec("playing_time")
	end)

	mpv.update = function(msg)
		if msg.playlist then
			vim.schedule(function() -- NOTE: This is scheduled to avoid blocking the exec loop.
				for i, song in ipairs(msg.playlist) do
					local id = song.filename:match("[?&]id=([^&]+)")
					if not id then
						vim.notify("Song without id in playlist: " .. song.filename, vim.log.levels.WARN)
						return
					end
					if not icache[id] then
						icache[id] = get(id)
					end
					if song.playing then
						msg.playing = i
					end
					msg.playlist[i] = icache[id]
				end
				M.render(msg)
			end)
		end
		M.render(msg or {})
	end
end

function M.lazy_setup()
	mpv.start()
	mpv.exec("metadata")
	mpv.exec("paused")
	mpv.exec("total_time")
	mpv.exec("playlist")
end

---@param name string
---@param offset number
---@param count number
---@return music.backend.song[]|nil
local function search(name, offset, count)
	local resp = query("search3", {
		query = name,
		songOffset = offset,
		songCount = count,
		artistCount = 0,
		albumCount = 0,
	})
	if not resp then
		return nil
	end
	if not field_check(resp, "searchResult3") then
		return nil
	end
	local songs = {}
	for i, s in ipairs(resp.searchResult3.song or {}) do
		songs[i] = parse_song(s)
	end
	return songs
end

local function kv_to_str(kv)
	local F = require("plenary.functional")
	local function url_encode(str)
		if type(str) ~= "number" then
			str = str:gsub("\r?\n", "\r\n")
			str = str:gsub("([^%w%-%.%_%~ ])", function(c)
				return string.format("%%%02X", c:byte())
			end)
			str = str:gsub(" ", "+")
			return str
		else
			return str
		end
	end
	return F.join(
		F.kv_map(function(kvp)
			return kvp[1] .. "=" .. url_encode(kvp[2])
		end, kv),
		"&"
	)
end

function M.play(song_id, append)
	local url = cfg.url .. "/rest/stream.view"
	local q = vim.tbl_deep_extend("force", cfg.query, {
		id = song_id,
	})
	local full_url = url .. "?" .. kv_to_str(q)
	mpv.exec("play", full_url, append and "append" or "replace")
end

---@return nil
function M.toggle()
	mpv.exec("toggle")
end

---@type fun(name: string, offset: number,count: number): nil
function M.search(name, offset, count)
	local cache = tcache[name]
	if not cache or #cache < offset + count then
		su.debounce(function()
			local songs = search(name, offset, count)
			if not songs then
				return
			end
			tcache[name] = cache or {}
			for i = 1, #songs do
				tcache[name][offset + i] = songs[i]
				icache[songs[i].id] = songs[i]
			end
			M.render({
				search = vim.list_slice(tcache[name], offset + 1, offset + count),
				offset = offset,
			})
		end, { ms = 500 })()
		return
	end
	M.render({
		search = vim.list_slice(tcache[name], offset + 1, offset + count),
		offset = offset,
	})
end

-- NOTE: This function is used to change the playback mode in MPV.
-- It uses a timer to ensure that the mode change is applied after a short delay for debounce.
function M.mode(mode)
	su.debounce(function()
		mpv.exec("mode", mode)
	end, { ms = 500 })()
end

return M
