local uv = vim.uv
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

local M = {}

local function field_check(data, ...)
	for _, field in ipairs({ ... }) do
		if not data[field] then
			vim.notify("Missing field: " .. field, vim.log.levels.ERROR)
			return false
		end
	end
	return true
end

function M.try_start_server()
	if _G.plugin_music then
		return true
	end

	local job = require("plenary.job"):new({
		command = "mpv",
		args = { "--idle", "--input-ipc-server=/tmp/neovim-mpv-socket", "--no-terminal", "--no-video" },
	})
	job:start()
	vim.defer_fn(function()
		local skt = uv.new_pipe(false)
		if not skt then
			vim.notify("Failed to create socket", vim.log.levels.ERROR)
			return
		end
		skt:connect("/tmp/neovim-mpv-socket", function(err)
			if err then
				vim.notify("Failed to connect to MPV server: " .. err, vim.log.levels.ERROR)
				skt:close()
				return
			end
			_G.plugin_music = {
				job = job,
				skt = skt,
			}
		end)
	end, 500)
	return true
end

function M.search(name, offset)
	if not _G.plugin_music then
		vim.notify("MPV server is not running", vim.log.levels.ERROR)
		return nil
	end
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
			if not _G.plugin_music then
				return
			end
			if _G.plugin_music.skt then
				_G.plugin_music.skt:write("quit\n")
				_G.plugin_music.skt:close()
			end
		end,
	})
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
	local query = {
		id = song_id,
	}
	query = vim.tbl_deep_extend("force", cfg.query, query)
	local full_url = url .. "?" .. kv_to_str(query)
	local w = _G.plugin_music.skt:write("loadfile " .. full_url .. "\n")
	if not w then
		vim.notify("Failed to write to MPV socket", vim.log.levels.ERROR)
		return
	end
end

return M
