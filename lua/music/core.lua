---@class music.song.meta
---@field id string
---@field title string
---@field artist string
---@field album string
---
---@alias music.observer.playing fun(id: string)
---
---@alias music.core.observer.playlist fun(list: music.song.meta[])
---
---@alias music.observer.pause fun(pause: boolean)
---
---@alias music.observer.playing_time fun(seconds: number)
---
---@alias music.observer.total_time fun(seconds: number)
---
---@alias music.observer.mode fun(mode: string)
---
---@alias music.observer.field "playing"|"playlist"|"pause"|"playing_time"|"total_time"|"mode"
---
---@class music.core.observer
---@field playing? music.observer.playing
---@field playlist? music.core.observer.playlist
---@field pause? music.observer.pause
---@field playing_time? music.observer.playing_time
---@field total_time? music.observer.total_time
---@field mode? music.observer.mode
---
---@class music.lyric_item
---@field time number
---@field line string

---@alias music.lyric music.lyric_item[]

---
---@class music.core
---@field observe fun(self, name: music.observer.field, observer: music.core.observer)
---@field setup fun(self)
---@field lazy_setup fun(self)
---@field load fun(id: string, opts?: {append: boolean,play: boolean})
---@field toggle fun(self)
---@field mode fun(self, mode: string)
---@field next fun(self)
---@field prev fun(self)
local M = {}
---@type music.backend
local b = require("music.backend")
local u = require("music.util")
local su = require("snacks.util")
local uv = vim.uv

---@type music.source
local src = require("music.source")

local observers = {}
function M:observe(name, observer)
	local fn = observers[name]
	if not fn then
		observers[name] = observer[name]
	else
		observers[name] = function(...)
			observer[name](...)
			fn(...)
		end
	end
end

function M:setup()
	b:observe("playing", {
		playing = vim.schedule_wrap(function(id)
			observers.playing("subsonic:" .. id) --FIX: This assumes 'subsonic' as the source.
		end),
	})
	b:observe("playlist", {
		playlist = vim.schedule_wrap(function(list)
			---@type music.song.meta[]
			local pl = {}
			for i, song_id in ipairs(list) do
				pl[i] = src:get("subsonic:" .. song_id) --FIX: This assumes 'subsonic' as the source.
			end
			observers.playlist(pl)
		end),
	})
	local observe = function(name)
		b:observe(name, {
			[name] = vim.schedule_wrap(function(...)
				local fn = observers[name]
				if fn then
					fn(...)
				end
			end),
		})
	end
	observe("pause")
	observe("playing_time")
	observe("total_time")
	observe("mode")
	uv.new_timer():start(1000, 100, function()
		b:trigger("playing_time")
	end)

	local augid = vim.api.nvim_create_augroup("PluginMusic", { clear = false })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augid,
		callback = function()
			b:quit()
		end,
	})
end

function M:lazy_setup()
	b:lazy_setup()
	b:trigger("playing", "playlist", "pause", "playing_time", "total_time")
end

function M.load(id, opts)
	b:load(src:stream(id), opts)
end

function M:toggle()
	b:toggle()
end

function M:next()
	b:next()
end

function M:prev()
	b:prev()
end

function M:mode(mode)
	b:mode(mode)
end

return M
