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
---@field reason? string

local uv = vim.uv
local a = require("plenary.async")
local u = require("music.util")

---@return music.mpv.config
local function default_config()
	return {
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
		refresh = 100, -- milliseconds
	}
end

---@class music.backend.mpv.state
---@field playing string
---@field playlist string[]
---@field loop_file boolean|number|string
---@field loop_playlist boolean|number|string

---@class music.backend.mpv.observer
---@field playlist fun(self: music.backend.mpv, playlist: music.backend.mpv.playlist_item[])
---@field pause fun(self: music.backend.mpv, pause: boolean)
---@field ["time-pos"] fun(self: music.backend.mpv, seconds: number)
---@field duration fun(self: music.backend.mpv, seconds: number)
---@field ["loop-file"] fun(self: music.backend.mpv, data: boolean|string|number)
---@field ["loop-playlist"] fun(self: music.backend.mpv, data: boolean|string|number)

---@class music.backend.mpv:music.backend
---@field job Job | nil | music.backend.mpv.state | {time-pos: number, pause: boolean}
---@field skt uv.uv_pipe_t | nil
---@field rid integer request ID counter, must starts from 1
---@field rcbs table<number, fun(response: { error: string, data: any, request_id: number })> callbacks for requests
---
---@field timers table<string, uv.uv_timer_t> timers
---
---@field raw music.backend.mpv.observer raw observer table
---@field s music.backend.mpv.state current state
---@field opts music.mpv.config
---@field api music.core.api
M = {}
M.__index = M

M.raw = {
	playlist = function(self, data)
		self.s.playing = ""
		self.s.playlist = {}
		for i, item in ipairs(data) do
			if item.playing then
				self.s.playing = item.filename
			end
			self.s.playlist[i] = item.filename
		end
		self.api.playlist = self.s.playlist
		self.api.playing = self.s.playing
	end,
	pause = function(self, pause)
		self.api.pause = pause or false
	end,
	["time-pos"] = function(self, seconds)
		self.api.playing_time = seconds or 0
	end,
	duration = function(self, seconds)
		self.api.total_time = seconds or 0
	end,
	["loop-file"] = function(self, data)
		if data == "inf" then
			self.api.mode = "loop"
		elseif data == false then
			if self.s.loop_playlist == "inf" then
				self.api.mode = "pl_loop"
			else
				self.api.mode = "pl"
			end
		elseif type(self.s.loop_file) ~= "number" then
			self.api.mode = "loop"
		end
		self.s.loop_file = data
	end,
	["loop-playlist"] = function(self, data)
		if self.s.loop_file ~= false then
			self.s.loop_playlist = data
			return
		elseif data == false then
			self.api.mode = "pl"
		elseif type(self.s.loop_playlist) == "boolean" then
			self.api.mode = "pl_loop"
		end
		self.s.loop_playlist = data
	end,
}

function M:_after_connect() end

---@return string|nil
function M:_try_connect()
	self.skt = uv.new_pipe(true)
	if not self.skt then
		return "Failed to create pipe"
	end
	local cerr = a.uv.pipe_connect(self.skt, self.opts.path)
	if cerr then
		return cerr
	end
	local buffer = ""
	---@param e music.backend.mpv.event | music.backend.mpv.response
	local function handle_event(e)
		if e.request_id then
			local cb = self.rcbs[e.request_id]
			if cb then
				cb(e)
				self.rcbs[e.request_id] = nil
			else
				vim.notify("Received response for unknown request ID: " .. e.request_id, vim.log.levels.WARN)
			end
		elseif e.id then
			local cb = self.raw[e.name]
			if not cb then
				vim.notify("Received response for unknown observe ID: " .. e.id, vim.log.levels.WARN)
			else
				cb(self, e.data)
			end
		elseif e.event == "end-file" and e.reason == "quit" and self.job == nil then
			self.job = vim.deepcopy(self.s)
			self.job["time-pos"] = self.api.playing_time
			self.job.pause = self.api.pause
		elseif e.event and self.raw[e.event] then
			self.raw[e.event](self, e.data)
		end
	end
	local function handle_response(err, chunk)
		if err then
			u.n("Error reading from MPV socket: " .. err, vim.log.levels.ERROR)
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
				handle_event(vim.json.decode(line)) ---TODO:restart server if server broken
			end
		end
	end

	self.skt:read_start(handle_response)

	local oid = 1
	for prop, _ in pairs(self.raw) do
		if prop ~= "time-pos" then
			self:req({ "observe_property", oid, prop })
			oid = oid + 1
		end
	end
end

function M:_start_new()
	local job = require("plenary.job"):new({
		command = "mpv",
		args = { "--idle", "--input-ipc-server=" .. self.opts.path, "--no-terminal", "--no-video" },
		on_exit = function(_, return_val)
			self.skt = nil
			if return_val ~= 0 then
				vim.notify("MPV server exited with code " .. return_val, vim.log.levels.ERROR)
				self:_start_new()
			end
			vim.notify("MPV server stopped", vim.log.levels.INFO)
		end,
	})
	job:start()
	self.job = job

	uv.sleep(500) -- Give MPV some time to start

	local err = self:_try_connect()
	if err then
		vim.notify("Failed to connect to MPV server: " .. err, vim.log.levels.ERROR)
		return
	end
	u.n("Started new MPV server", vim.log.levels.INFO)
end

function M:_start()
	local err = a.uv.fs_stat(self.opts.path)
	if not err then
		err = self:_try_connect()
		if not err then
			u.n("Connected to existing MPV server", vim.log.levels.INFO)
			return
		end
		err = a.uv.fs_unlink(self.opts.path)
		if err then
			vim.notify("Failed to unlink existing MPV socket: " .. err, vim.log.levels.ERROR)
			return
		end
		u.n("Unlinked stale MPV socket", vim.log.levels.INFO)
	elseif not err:match("ENOENT") then
		vim.notify("Failed to stat MPV socket: " .. err, vim.log.levels.ERROR)
		return
	end
	self:_start_new()
end

function M:start()
	self:_start()
	if not self.skt then
		return false
	end
end

---@param cmd table|string
---@param cb? fun(response: music.backend.mpv.response)
---@return nil
function M:req(cmd, cb)
	if not self.skt then
		return
	end
	if type(cmd) == "string" then
		cmd = { cmd }
	end
	self.rid = self.rid + 1
	local j = vim.json.encode({
		command = cmd,
		request_id = self.rid,
		async = true,
	})
	self.rcbs[self.rid] = cb
		or function(response)
			if response.error == "property unavailable" then
				vim.notify("MPV property unavailable: " .. vim.inspect(cmd), vim.log.levels.WARN)
				return
			end
			if response.error ~= "success" then
				u.notify(
					"MPV command " .. vim.inspect(cmd) .. " failed: " .. vim.inspect(response),
					vim.log.levels.ERROR
				)
			end
		end
	self.skt:write(j .. "\n", function(err)
		if err then
			u.n("Error sending command to MPV: " .. err, vim.log.levels.ERROR)
			self.skt:close()
			self.skt = nil
			a.void(function()
				local r = self.job
				if not r then
					return
				end
				self:_start()
				for _, item in ipairs(r.playlist) do
					if item == r.playing then
						local cmd = {
							"loadfile",
							item,
							"append-play",
						}
						self.raw["playback-restart"] = function(self)
							self:req({ "set_property", "time-pos", r["time-pos"] })
							self:req({ "set_property", "pause", r.pause })
							self.raw["playback-restart"] = nil
						end
						self:req(cmd)
						-- u.n("Command sent to MPV: " .. vim.inspect(cmd), vim.log.levels.DEBUG)
						-- uv.sleep(100) -- Give MPV some time to load the file
						-- self:req({ "set_property", "time-pos", r["time-pos"] })
						-- self:req({ "set_property", "pause", r.pause })
					else
						self:req({ "loadfile", item, "append" })
					end
				end
			end)()
		end
	end)
end

---@class music.mpv.config
---@field path? string path to mpv ipc socket
---@field refresh? integer refresh interval in milliseconds, default 100ms

---@param api music.core.api
---@param opts? music.mpv.config
function M:new(api, opts)
	opts = vim.tbl_deep_extend("force", default_config(), opts or {})

	---@type music.backend.mpv
	---@diagnostic disable-next-line: missing-fields
	local o = {
		rid = 1,
		rcbs = {},
		s = {
			playing = "",
			playlist = {},
			loop_file = false,
			loop_playlist = false,
		},
		opts = opts,
		api = api,
		timers = {},
	}
	setmetatable(o, self)
	o:_start()

	local t = uv.new_timer()
	if not t then
		error("Failed to create timer")
	end
	t:start(1000, opts.refresh, function()
		o:req({ "get_property", "time-pos" }, function(response)
			if response.error == "success" then
				o.raw["time-pos"](o, response.data)
			end
		end)
	end)

	o.timers.time_pos = t
	vim.schedule(function()
		local augid = vim.api.nvim_create_augroup("PluginMusic", { clear = false })
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = augid,
			callback = function()
				vim.notify("Vim is exiting, quitting MPV backend", vim.log.levels.INFO)
				o:quit()
			end,
		})
	end)
	return o
end

function M:toggle()
	self:req({ "cycle", "pause" })
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
	self:req(cmd)
end

function M:setup() end

function M:refresh()
	for name, _ in pairs(self.raw) do
		self:req({ "get_property", name }, function(response)
			if response.error == "success" then
				self.raw[name](self, response.data)
			end
		end)
	end
end

function M:next()
	if #self.s.playlist == 0 then
		return
	end
	if self.s.playing == "" or self.s.playing == self.s.playlist[#self.s.playlist] then
		self:req({ "set_property", "playlist-pos", 0 })
	else
		self:req("playlist_next")
	end
end

function M:prev()
	if #self.s.playlist == 0 then
		return
	end
	if self.s.playing == self.s.playlist[1] then
		self:req({ "set_property", "playlist-pos", #self.s.playlist - 1 })
	else
		self:req("playlist_prev")
	end
end

function M:mode(mode)
	if mode == "pl" then
		self:req({ "set_property", "loop", false })
		self:req({ "set_property", "loop-playlist", false })
	elseif mode == "loop" then
		self:req({ "set_property", "loop", "inf" })
	elseif mode == "pl_loop" then
		self:req({ "set_property", "loop", false })
		self:req({ "set_property", "loop-playlist", "inf" })
	end
end

function M:quit()
	if not self.job then --- Just connected to an existing mpv instance, do not quit it.
		return
	end
	self:req("quit")
	self.job = {}
	if self.skt then
		self.skt:close()
		self.skt = nil
	end
	for _, t in pairs(self.timers) do
		t:stop()
		t:close()
	end
end

return M
