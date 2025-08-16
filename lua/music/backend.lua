local mpv = require("music.mpv")
local u = require("snacks.util")

_G.plugin_music = _G.plugin_music or {}

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

local M = {
	mode = "once",
	state = {
		title = "Unknown",
		artist = "Unknown",
		album = "Unknown",
		playing_time = "0:00",
		total_time = "0:00",
		mode = "once",
		paused = false,
	},
	---@type fun(table): nil
	render = nil,
}

---@param data table
function M.update(data)
	M.state = vim.tbl_deep_extend("force", M.state, data)
	if M.render then
		M.render()
	else
		vim.notify("No render function set", vim.log.levels.WARN)
	end
end

local function field_check(data, ...)
	for _, field in ipairs({ ... }) do
		if not data[field] then
			vim.notify("Missing field: " .. field, vim.log.levels.ERROR)
			return false
		end
	end
	return true
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

	local augid = vim.api.nvim_create_augroup("PluginMusic", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augid,
		callback = function()
			mpv.exec("quit")
		end,
	})

	mpv.setup()

	mpv.observe("metadata", M.update)
	mpv.observe("pause", M.update)
	mpv.observe("total_time", M.update)

	vim.uv.new_timer():start(100, 100, function()
		mpv.exec("playing_time", M.update)
	end)
end

function M.lazy_setup()
	mpv.start()
	mpv.exec("metadata", M.update)
	mpv.exec("pause", M.update)
	mpv.exec("total_time", M.update)
end

function M.search(name, offset)
	if name == "" then
		vim.notify("Search name cannot be empty", vim.log.levels.WARN)
		return nil
	end
	local curl = require("plenary.curl")
	local url = cfg.url .. "/rest/search3.view"
	local query = {
		query = name,
		songOffset = offset,
		artistCount = 0,
		albumCount = 0,
	}
	query = vim.tbl_deep_extend("force", cfg.query, query)
	local response = curl.get(url, { query = query })
	if response.status ~= 200 then
		vim.notify("Failed to search for " .. name .. ": " .. response.status, vim.log.levels.ERROR)
		return nil
	end
	local data = vim.json.decode(response.body)
	if not data then
		vim.notify("Failed to parse response for " .. name, vim.log.levels.ERROR)
		return nil
	end
	if not field_check(data, "subsonic-response") then
		return nil
	end
	local resp = data["subsonic-response"]
	if not field_check(resp, "status", "searchResult3") then
		return nil
	end
	if resp.status ~= "ok" then
		vim.notify("Search failed: " .. resp.status, vim.log.levels.ERROR)
		return nil
	end
	return resp.searchResult3.song
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

function M.play(song_id)
	local url = cfg.url .. "/rest/stream.view"
	local query = vim.tbl_deep_extend("force", cfg.query, {
		id = song_id,
	})
	local full_url = url .. "?" .. kv_to_str(query)
	mpv.exec("play", nil, full_url)
end

---@return nil
function M.toggle()
	mpv.exec("toggle")
end

local modes = {
	once = "loop",
	loop = "pl",
	pl = "pl_loop",
	pl_loop = "once",
}

M.toggle_mode = u.debounce(function()
	local mode = modes[M.state.mode]
	mpv.exec("mode", nil, mode)
	M.update({ mode = mode })
end, {
	ms = 500,
})

return M
