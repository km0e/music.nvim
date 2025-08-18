local uv = vim.uv
local a = require("plenary.async")

local M = {
	tx = nil,
	---@type fun(msg: music.backend.msg): nil
	update = nil,
}
_G.plugin_music = _G.plugin_music
	or {
		_mpv = {
			skt = nil,
			rid = 0,
			rcbs = {},
			oid = 0,
			ocbs = {},
			obed = {},
			tx = nil,
		},
	}

local mpv = _G.plugin_music._mpv

local function check_response(response)
	if response.error ~= "success" then
		vim.notify("MPV error: " .. response.error, vim.log.levels.ERROR)
		return false
	end
	return true
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

function mpv.observe(cmd, cb)
	if mpv.obed[cmd[2]] then
		mpv.ocbs[mpv.obed[cmd[2]]] = cb
	else
		mpv.oid = mpv.oid + 1
		if not mpv.skt then
			mpv.obed[cmd[2]] = mpv.oid
			mpv.ocbs[mpv.oid] = cb
		else
			table.insert(cmd, 2, mpv.oid)
			cmd[1] = "observe_property"
			mpv.req(cmd, function(response)
				if not check_response(response) then
					return
				end
				mpv.obed[cmd[2]] = mpv.oid
				mpv.ocbs[mpv.oid] = cb
			end)
		end
	end
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
				mpv.tx.send(msg)
			end
		end
	end

	mpv.skt:read_start(handle_response)
	for prop, oid in pairs(mpv.obed) do
		mpv.req({ "observe_property", oid, prop }, function(response)
			if not check_response(response) then
				mpv.ocbs[oid] = nil -- TODO: handle this better
			end
		end)
	end
end

---@return nil
local function _start()
	local job = require("plenary.job"):new({
		command = "mpv",
		args = { "--idle", "--input-ipc-server=/tmp/neovim-plugin-music-mpv-socket", "--no-terminal", "--no-video" },
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

	mpv.skt:connect("/tmp/neovim-plugin-music-mpv-socket", function(err)
		if err then
			vim.notify("Failed to connect to MPV server: " .. err, vim.log.levels.ERROR)
			mpv.skt:close()
			return
		end
		after_connect()
	end)
end

local function start()
	if mpv.skt then
		return
	end

	mpv.skt = uv.new_pipe(false)
	if not mpv.skt then
		vim.notify("Failed to create socket", vim.log.levels.ERROR)
		return
	end
	if uv.fs_stat("/tmp/neovim-plugin-music-mpv-socket") then
		mpv.skt:connect("/tmp/neovim-plugin-music-mpv-socket", function(err)
			if err then
				uv.fs_unlink("/tmp/neovim-plugin-music-mpv-socket", function(unlink_err)
					if unlink_err then
						vim.notify("Failed to unlink existing MPV socket: " .. unlink_err, vim.log.levels.ERROR)
					else
						vim.notify("Unlinked existing MPV socket, starting new instance", vim.log.levels.INFO)
						mpv.skt:close()
						mpv.skt = uv.new_pipe(false)
						if not mpv.skt then
							vim.notify("Failed to create socket", vim.log.levels.ERROR)
							return
						end
						_start()
					end
				end)
				return
			end
			vim.notify("Connected to existing MPV socket", vim.log.levels.INFO)
			after_connect()
		end)
	else
		_start()
	end
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
				local cb = mpv.ocbs[e.id]
				if cb then
					cb(e.data)
				else
					vim.notify("Received response for unknown observe ID: " .. e.id, vim.log.levels.WARN)
				end
			elseif e.cmd then
				if e.cmd == "start" then
					start()
				elseif e.cmd[1] == "observe" then
					mpv.observe(e.cmd, e.cb)
				elseif mpv.skt then
					mpv.req(e.cmd, e.cb)
				end
			end
		end
	end
	a.run(handle)
	mpv.tx = tx
end

function M.setup()
	start_exec_queue()
	M.tx = function(cmd, cb)
		mpv.tx.send({
			cmd = cmd,
			cb = cb,
		})
	end
end

---@return nil
function M.start()
	M.tx("start")
end

---@param name string
---@param m fun(data: any): music.backend.msg
local function o_api(name, m)
	return function()
		return M.tx({ "observe", name }, function(data)
			M.update(m(data))
		end)
	end
end

local opps = {
	paused = o_api("pause", function(paused)
		return { paused = paused }
	end),
	metadata = o_api("metadata", function(data)
		return data or {}
	end),
	total_time = o_api("duration", function(seconds)
		return {
			total_time = seconds,
		}
	end),
	playlist = o_api("playlist", function(data)
		return {
			playlist = data,
		}
	end),
}

---@param property string
function M.observe(property)
	local o = opps[property]
	if not o then
		vim.notify("Unknown property: " .. property, vim.log.levels.ERROR)
		return false
	end
	M.tx(o())
end

---@param cmd string|table
---@param m? fun(data: any):music.backend.msg
local function e_api(cmd, m)
	local function f(cb, c, ...)
		if ... then
			c = vim.list_extend(vim.deepcopy(c), { ... })
		end
		M.tx(c, cb)
	end
	if m then
		cmd = { "get_property", cmd }
		return function(...)
			f(function(e)
				if e.error == "property unavailable" then
					return
				elseif not check_response(e) then
					return
				end
				M.update(m(e.data))
			end, cmd, ...)
		end
	elseif type(cmd) == "string" then
		cmd = { cmd }
	end
	return function(...)
		f(check_response, cmd, ...)
	end
end

local epps = {
	metadata = e_api("metadata", function(data)
		return data or {}
	end),
	playing_time = e_api("time-pos", function(seconds)
		return {
			playing_time = seconds,
		}
	end),
	total_time = e_api("duration", function(seconds)
		return {
			total_time = seconds,
		}
	end),
	paused = e_api("pause", function(paused)
		return { paused = paused }
	end),
	playlist = e_api("playlist", function(data)
		return {
			playlist = data,
		}
	end),
	toggle = e_api({ "cycle", "pause" }),
	play = e_api("loadfile"),
	quit = e_api("quit"),
	set = e_api("set_property"),
}

local modes = {
	once = { 1, "no" },
	loop = { "inf", "no" },
	pl = { "no", "no" },
	pl_loop = { "no", "inf" },
}

---@param cmd string
function M.exec(cmd, ...)
	if cmd == "quit" and not mpv.job then
		return
	end
	if cmd == "mode" then
		local m = modes[(...)]
		epps.set("loop-file", m[1])
		epps.set("loop-playlist", m[2])
		return
	end
	local e = epps[cmd]
	if not e then
		vim.notify("Unknown command: " .. cmd, vim.log.levels.ERROR)
	end
	e(...)
end

return M
