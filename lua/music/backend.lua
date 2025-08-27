---@class music.backend.mpv.playlist_item
---@field filename string
---@field current? boolean
---@field playing boolean
---@field title? string
---@field id integer
---
---@class music.backend.mpv.response
---@field error string
---@field data any
---@field request_id? integer
---
---@class music.backend.mpv.event
---@field event string
---@field data any
---@field id integer
---@field name string
---
---@class music.backend.observer
---@field playing fun(id: string)
---@field playlist fun(list: string[])
---@field pause fun(pause: boolean)
---@field playing_time fun(seconds: number)
---@field total_time fun(seconds: number)
---@field mode fun(mode: string)

local uv = vim.uv

_G.plugin_music = _G.plugin_music
	or {
		_mpv = {
			path = (function()
				local os = uv.os_uname()
				if os.sysname == "Linux" or os.sysname == "Darwin" then
					return "/tmp/neovim-plugin-music-mpv-socket"
				elseif os.sysname == "Windows" then
					return "\\\\.\\pipe\\neovim-plugin-music-mpv-socket"
				else
					error("Unsupported OS: " .. os.sysname)
				end
			end)(),
			---@type uv.uv_pipe_t |nil
			skt = nil,
			rid = 1, --- request ID counter, must starts from 1
			rcbs = {},
			---@class plenary.async.control.mpsc
			---@field send fun(data: any): nil
			tx = nil,
		},
	}

local mpv = _G.plugin_music._mpv

---@class music.backend
---@field observer music.backend.observer
---@field setup fun(self: music.backend, observer?: music.backend.observer)
---@field lazy_setup fun(self: music.backend)
---@field toggle fun(self: music.backend)
---@field load fun(self: music.backend, url: string, opts?: {append: boolean,play: boolean})
---@field trigger fun(self: music.backend, ...: "playing" | "pause" | "playlist" | "playing_time" | "total_time")
---@field next fun(self: music.backend)
---@field prev fun(self: music.backend)
---@field quit fun(self: music.backend)
local M = {
	---@diagnostic disable-next-line: missing-fields
	observer = {},
}

local a = require("plenary.async")
local u = require("music.util")

local playing = ""
local playlist = {}

local loop_file = false
local loop_playlist = false

---@type table<string, fun(data: any)>
local mpv_observer = {
	playlist = function(data)
		---@type music.backend.mpv.playlist_item[]
		data = data or {}
		local lp, chg = nil, false
		for i, item in ipairs(data) do
			local id = item.filename:match("[?&]id=([^&]+)")
			if item.playing then
				lp = id
			end
			if playlist[i] ~= id then
				playlist[i] = id
				chg = true
			end
		end
		if chg and M.observer.playlist then
			M.observer.playlist(playlist)
		end
		if M.observer.playing then
			playing = lp or ""
			M.observer.playing(playing)
		end
	end,
	pause = function(pause)
		if not M.observer.pause then
			return
		end
		M.observer.pause(pause or false)
	end,
	duration = function(seconds)
		if not M.observer.total_time then
			return
		end
		M.observer.total_time(seconds or 0)
	end,
	["loop-file"] = function(data)
		if data == "inf" then
			M.observer.mode("loop")
		elseif data == false then
			if loop_playlist == "inf" then
				M.observer.mode("pl_loop")
			else
				M.observer.mode("pl")
			end
		elseif type(loop_file) ~= "number" then
			M.observer.mode("pl")
		end
		loop_file = data
	end,
	["loop-playlist"] = function(data)
		if loop_file ~= false then
			loop_playlist = data
			return
		elseif data == false then
			M.observer.mode("pl")
		elseif type(loop_playlist) == "boolean" then
			M.observer.mode("pl_loop")
		end
		loop_playlist = data
	end,
}

---@param cmd string | table
function M.exec(cmd)
	if type(cmd) == "string" then
		cmd = { cmd }
	end
	mpv.tx.send({
		cmd = cmd,
		cb = function(response)
			if response.error ~= "success" then
				vim.notify(
					"MPV command " .. vim.inspect(cmd) .. " failed: " .. vim.inspect(response),
					vim.log.levels.ERROR
				)
			end
		end,
	})
end

local mpv_get = {
	playing_time = "time-pos",
}

---@param property string
function M:get(property)
	local ocb = mpv_observer[property]
	if not ocb and mpv_get[property] then
		ocb = self.observer[property]
		property = mpv_get[property]
	elseif not ocb then
		vim.notify("No observer for property: " .. property, vim.log.levels.WARN)
		return
	end
	local cmd = { "get_property", property }
	local cb = function(response)
		if response.error == "property unavailable" then
			return
		end
		if response.error ~= "success" then
			vim.notify("MPV command " .. vim.inspect(cmd) .. " failed: " .. vim.inspect(response), vim.log.levels.ERROR)
			return
		end
		ocb(response.data)
	end
	mpv.tx.send({
		cmd = cmd,
		cb = cb,
	})
end

---@param cmd table
---@param cb? fun(response: { error: string }): nil
---@return nil
function mpv.req(cmd, cb)
	mpv.rid = mpv.rid + 1
	local j = vim.json.encode({
		command = cmd,
		request_id = mpv.rid,
		async = true,
	})
	mpv.rcbs[mpv.rid] = cb
	mpv.skt:write(j .. "\n", function(err)
		if err then
			vim.notify("Error sending command to MPV: " .. err, vim.log.levels.ERROR)
			mpv.rcbs[mpv.rid] = nil
		end
	end)
end

local function after_connect()
	local buffer = ""
	local function handle_response(err, chunk)
		if err then
			vim.notify("Error reading from MPV socket: " .. err, vim.log.levels.ERROR)
			return
		end
		buffer = buffer .. (chunk or "")
		while true do
			local line, rest = buffer:match("([^\n]*)\n(.*)")
			if not line then
				break
			end
			buffer = rest
			if line ~= "" then
				local msg = vim.json.decode(line)
				mpv.tx.send(msg) ---TODO:restart server if server broken
			end
		end
	end

	mpv.skt:read_start(handle_response)
	local oid = 1 -- Observe IDs must start from 1
	for prop, _ in pairs(mpv_observer) do
		M.exec({ "observe_property", oid, prop })
		oid = oid + 1
	end
end

---@return nil
local function _start()
	local job = require("plenary.job"):new({
		command = "mpv",
		args = { "--idle", "--input-ipc-server=" .. mpv.path, "--no-terminal", "--no-video" },
		on_exit = function(_, return_val)
			mpv.skt = nil
			if return_val ~= 0 then
				vim.notify("MPV server exited with code " .. return_val, vim.log.levels.ERROR)
				_start()
			end
			vim.notify("MPV server stopped", vim.log.levels.INFO)
		end,
	})
	job:start()
	mpv.job = job

	uv.sleep(500) -- Give MPV some time to start

	local err = a.uv.pipe_connect(mpv.skt, mpv.path)
	if err then
		vim.notify("Failed to connect to MPV server: " .. err, vim.log.levels.ERROR)
		mpv.skt:close()
		mpv.skt = nil
		return
	end
	after_connect()
end

local function start()
	if mpv.skt then
		return
	end

	mpv.skt = uv.new_pipe(true)
	if not mpv.skt then
		vim.notify("Failed to create socket", vim.log.levels.ERROR)
		return
	end
	local err = a.uv.fs_stat(mpv.path)
	if err then
		if err:match("ENOENT") then
			vim.notify("Starting new MPV instance", vim.log.levels.INFO)
			_start()
		else
			vim.notify("Failed to stat MPV socket: " .. err, vim.log.levels.ERROR)
			mpv.skt:close()
			mpv.skt = nil
		end
		return
	end
	err = a.uv.pipe_connect(mpv.skt, mpv.path)
	if not err then
		vim.notify("Connected to existing MPV instance", vim.log.levels.INFO)
		after_connect()
		return
	end
	mpv.skt:close()
	err = a.uv.fs_unlink(mpv.path)
	if err then
		vim.notify("Failed to unlink existing MPV socket: " .. err, vim.log.levels.ERROR)
		mpv.skt = nil
		return
	end
	mpv.skt = uv.new_pipe(true)
	if not mpv.skt then
		vim.notify("Failed to create socket", vim.log.levels.ERROR)
		return
	end
	vim.notify("Unlinked stale MPV socket, starting new MPV instance", vim.log.levels.INFO)
	_start()
end

local function start_exec_queue()
	if mpv.tx then
		return
	end

	local tx, rx = a.control.channel.mpsc()
	local function handle()
		while true do
			local e = rx.recv()
			if e.request_id then
				local cb = mpv.rcbs[e.request_id]
				if cb then
					cb(e)
					mpv.rcbs[e.request_id] = nil
				else
					vim.notify("Received response for unknown request ID: " .. e.request_id, vim.log.levels.WARN)
				end
			elseif e.id then
				local cb = mpv_observer[e.name]
				if not cb then
					vim.notify("Received response for unknown observe ID: " .. e.id, vim.log.levels.WARN)
				elseif e.data ~= nil then
					cb(e.data)
				end
			elseif e.cmd then
				if e.cmd == "start" then
					start()
				elseif mpv.skt then
					mpv.req(e.cmd, e.cb)
				end
			end
		end
	end
	a.run(handle)
	mpv.tx = tx
end

function M:lazy_setup()
	mpv.tx.send({
		cmd = "start",
	})
end

function M:toggle()
	self.exec({ "cycle", "pause" })
end

function M:load(url, opts)
	if not url or url == "" then
		u.notify("No URL provided to load", vim.log.levels.WARN)
		return
	end
	opts = opts or {}
	local flags = "replace"
	if opts.append then
		flags = opts.play and "append-play" or "append"
	end
	local cmd = {
		"loadfile",
		url,
		flags,
	}
	self.exec(cmd)
end

function M:setup(observer)
	self.observer = observer or {}

	start_exec_queue()
end

function M:trigger(...)
	local args = { ... }
	local map = {
		playing = "playlist",
		pause = "pause",
		playlist = "playlist",
		playing_time = "playing_time",
		total_time = "duration",
		mode = { "loop-file", "loop-playlist" },
	}
	---@type table<string, boolean>
	local gets = {}
	for _, arg in ipairs(args) do
		local hint = map[arg]
		if type(hint) == "string" then
			gets[hint] = true
		elseif type(hint) == "table" then
			for _, h in ipairs(hint) do
				gets[h] = true
			end
		else
			vim.notify("Unknown trigger: " .. arg, vim.log.levels.WARN)
		end
	end
	for prop, _ in pairs(gets) do
		self:get(prop)
	end
end

function M:next()
	if #playlist == 0 then
		return
	end
	if playing == "" or playing == playlist[#playlist] then
		self.exec({ "set_property", "playlist-pos", 0 })
	else
		self.exec("playlist_next")
	end
end

function M:prev()
	if #playlist == 0 then
		return
	end
	if playing == playlist[1] then
		self.exec({ "set_property", "playlist-pos", #playlist - 1 })
	else
		self.exec("playlist_prev")
	end
end

function M:mode(mode)
	-- vim.notify("Setting loop mode to: " .. mode, vim.log.levels.INFO)
	if mode == "pl" then
		self.exec({ "set_property", "loop", false })
		self.exec({ "set_property", "loop-playlist", false })
	elseif mode == "loop" then
		self.exec({ "set_property", "loop", "inf" })
	elseif mode == "pl_loop" then
		self.exec({ "set_property", "loop", false })
		self.exec({ "set_property", "loop-playlist", "inf" })
	end
end

function M:quit()
	if not mpv.job then --- Just connected to an existing mpv instance, do not quit it.
		return
	end
	self.exec("quit")
end

return M
