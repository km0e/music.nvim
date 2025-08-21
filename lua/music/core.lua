---@class music.backend.song
---@field id string
---@field title string
---@field artist string
---@field album string
---
---@class music.core.observer
---@field playing fun(id: string)
---@field playlist fun(list: music.backend.song[])
---@field pause fun(paused: boolean)
---@field playing_time fun(seconds: number)
---@field total_time fun(seconds: number)
---@field mode fun(mode: string)

---@class music.core
---@field setup fun(self, observer:music.core.observer)
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

function M:setup(observer)
	---@type music.backend.observer
	---@diagnostic disable-next-line: missing-fields
	local bobserver = {}
	if observer.playing then
		bobserver.playing = vim.schedule_wrap(function(id)
			observer.playing("subsonic:" .. id) --FIX: This assumes 'subsonic' as the source.
		end)
	end
	if observer.playlist then
		bobserver.playlist = vim.schedule_wrap(function(list)
			---@type music.backend.song[]
			local pl = {}
			for i, song_id in ipairs(list) do
				pl[i] = src:get("subsonic:" .. song_id) --FIX: This assumes 'subsonic' as the source.
			end
			observer.playlist(pl)
		end)
	end
	bobserver.pause = vim.schedule_wrap(observer.pause)
	bobserver.playing_time = vim.schedule_wrap(observer.playing_time)
	bobserver.total_time = vim.schedule_wrap(observer.total_time)
	bobserver.mode = vim.schedule_wrap(observer.mode)
	b:setup(bobserver)

	uv.new_timer():start(100, 100, function()
		b:trigger("playing_time")
	end)

	local augid = vim.api.nvim_create_augroup("PluginMusicBackend", { clear = true })
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

-- NOTE: This function is used to change the playback mode in MPV.
-- It uses a timer to ensure that the mode change is applied after a short delay for debounce.
function M:mode(mode)
	su.debounce(function()
		b:mode(mode)
	end, { ms = 100 })()
end

return M
