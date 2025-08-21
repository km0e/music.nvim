local M = {
	url = nil,
	q = {
		f = "json",
		c = "km0e/music.nvim",
		v = "1.12.0",
	},
}

local u = require("music.util")

---@class music.source.subsonic.config
---@field url string
---@field u string
---@field v string
---@field p string|nil
---@field t string|nil
---@field s string|nil

---@param opts table<string, music.source.subsonic.config>|music.source.subsonic.config
function M:setup(opts)
	opts = opts or {}
	if not u.field_check("subsonic api", opts, "url", "u") then
		return
	end
	M.q = vim.tbl_deep_extend("force", M.q, opts)
	local q = M.q

	M.url = q.url .. "/rest/"
	q.url = nil
	if q.t and q.s then
		q.p = nil
	elseif q.p then
		q.p = "enc:" .. u.hex_encode(q.p)
		q.t = nil
		q.s = nil
	else
		vim.notify("No password or token provided, authentication failed", vim.log.levels.WARN)
		M.url = nil
	end
end

---@param endpoint string
---@param q table
---@return table|nil
local function query(endpoint, q)
	local curl = require("plenary.curl")
	local url = M.url .. endpoint .. ".view"
	q = vim.tbl_deep_extend("force", M.q, q)
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
	if not u.field_check("subsonic response", data, "subsonic-response") then
		return nil
	end
	local resp = data["subsonic-response"]
	if not u.field_check("subsonic response", resp, "status") then
		return nil
	end
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

---@param name string
---@param offset number
---@param count number
---@return music.backend.song[]|nil
function M:search(name, offset, count)
	local resp = query("search3", {
		query = name,
		songOffset = offset,
		songCount = count,
		artistCount = 0,
		albumCount = 0,
	})
	if not resp or not u.field_check("subsonic search3", resp, "searchResult3") then
		return nil
	end
	local songs = {}
	for i, s in ipairs(resp.searchResult3.song or {}) do
		songs[i] = extract_song(s)
	end
	return songs
end

---@param id string
---@return music.backend.song|nil
function M:get(id)
	local resp = query("getSong", { id = id })
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
