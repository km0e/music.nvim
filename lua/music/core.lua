local a = require("plenary.async")
local src = require("music.source")

---@class music.core.state
---@field playing? music.song -- currently playing song
---@field pause boolean -- is paused
---@field playing_time number -- current playing time in seconds
---@field total_time number -- total time of the current song in seconds
---@field mode string -- playback mode: "pl" (playlist), "loop" (single loop), "pl_loop" (playlist loop)
---@field playlist music.song[] -- current playlist
---
---@class music.core.api:music.core.state
---@field playing string -- currently playing song id
---@field playlist string[] -- current playlist
---
---@class music.backend
---@field toggle fun(self: music.backend)
---@field load fun(self: music.backend, url: string, opts?: {append: boolean,play: boolean})
---@field refresh fun(self: music.backend)
---@field next fun(self: music.backend)
---@field prev fun(self: music.backend)
---@field quit fun(self: music.backend)
---@field mode fun(self: music.backend, mode: "pl"|"loop"|"pl_loop")
---
---
---@class music.core.config
---@field backends table<string, music.mpv.config>
---@field default_backend string
---
---@class music.core:music.backend
---@field setup fun(self: music.core, opts: music.core.config)
---@field opts music.core.config
---@field backends table<string, music.backend>
---@field current_backend? music.backend
---@field state music.core.state
---@field setter table -- used to get state changes by __newindex metamethod, recommended to wrap with setmetatable
---@field subscribe fun(self: music.core, callback: fun(key: string))
local M = {
	backends = {},
	current_backend = nil,
	state = {
		playing = nil,
		playlist = {},
		playing_time = 0.00,
		total_time = 1.00,
		pause = false,
		mode = "pl",
	},
	setter = {},
}

---@param opts music.core.config
function M:setup(opts)
	setmetatable(self.setter, {
		__index = self.state,
		__newindex = function(_, k, v)
			if k == "playing" then
				v = src.su2s[v]
			elseif k == "playlist" then
				for i, url in ipairs(v) do
					v[i] = src.su2s[url]
				end
			end
			if not v then
				return
			end
			self.state[k] = v
		end,
	})

	self.opts = opts or {
		backends = {
			mpv = {},
		},
		default_backend = "mpv",
	}
end

M.refresh = a.void(function(self)
	if not self.current_backend then
		self.current_backend = self.backends[self.opts.default_backend]
		if not self.current_backend then
			local b = require("music.backend.mpv"):new(self.setter, self.opts.backends[self.opts.default_backend])
			self.current_backend = b
			self.backends[self.opts.default_backend] = b
		end
		setmetatable(self, { __index = self.current_backend })
	end
	self.current_backend:refresh()
end)

function M:subscribe(callback)
	local old = getmetatable(self.setter).__newindex
	setmetatable(self.setter, {
		__newindex = function(_, k, v)
			old(_, k, v)
			callback(k)
		end,
	})
end

return M
