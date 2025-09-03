local M = {
	layout = nil,
	input = nil,
	p = nil,
	ns_id = nil,
	---@type "slist"|"spanel"
	mode = "spanel",
	playing = "",
}

---@type music.source
local src = require("music.source")
local core = require("music.core")
local slist = require("music.panel.slist")
local spanel = require("music.panel.spanel")

local modes = {
	pl = "loop",
	loop = "pl_loop",
	pl_loop = "pl",
}

local Snacks = require("snacks")
local u = require("music.util")

---@param mode? "slist"|"spanel"
local function render(mode)
	if not M.p.win then
		return
	end
	if mode and mode ~= M.mode then
		return
	end
	local map = {
		slist = slist,
		spanel = spanel,
	}
	map[M.mode]:render(M.p, M.ns_id, M.playing)
end

function M:start()
	core:lazy_setup()

	self.layout:unhide()
	self.input:focus()

	render()
end

---@param count? number
local function search(count)
	if type(count) ~= "number" then --NOTE:may be called by `Key`
		-- If count is not provided, use the current window height
		count = vim.api.nvim_win_get_height(M.p.win)
	end
	local line = vim.api.nvim_get_current_line()
	if line == "" then
		return
	end
	src:search(line, slist.offset, count, function(songs)
		if not songs or #songs == 0 then
			if slist.offset ~= 0 then
				slist.offset = slist.offset - vim.api.nvim_win_get_height(M.p.win)
			end
			return
		end
		for i, song in ipairs(songs) do
			slist.search_list[slist.offset + i] = song
		end
		render("slist")
	end)
end

---@type table<string, snacks.win.Action>
local actions = {
	close = {
		desc = "Close the music panel",
		action = function()
			M.layout:hide()
			vim.cmd("wincmd p")
		end,
	},
	search = {
		desc = "Search for songs",
		action = function()
			slist.offset = 0
			search(vim.api.nvim_win_get_height(M.p.win))
		end,
	},
	toggle = {
		desc = "Play/Pause",
		action = function()
			core:toggle()
		end,
	},
	append = {
		desc = "Append the selected song to the playlist",
		action = function()
			local song = slist.search_list[vim.v.count1]
			if song then
				core.load(song.id, {
					append = #spanel.playlist > 0,
					play = false,
				})
			end
		end,
	},
	replace = {
		desc = "Replace the playlist with the selected song",
		action = function()
			local song = slist.search_list[vim.v.count1]
			if song then
				core.load(song.id)
			end
		end,
	},
	switch = {
		desc = "Switch between search and playlist panel",
		action = function()
			if M.mode == "spanel" then
				M.mode = "slist"
				spanel:clear(M.p, M.ns_id)
				render("slist")
			else
				M.mode = "spanel"
				render("spanel")
			end
		end,
	},
	mode = {
		desc = "Switch playback mode",
		action = function()
			core:mode(modes[spanel.mode])
		end,
	},
	next_search = {
		desc = "Next page of search results",
		action = function()
			local height = vim.api.nvim_win_get_height(M.p.win)
			if #slist.search_list < height then
				return
			end
			slist.offset = slist.offset + height
			search(height)
		end,
	},
	prev_search = {
		desc = "Previous page of search results",
		action = function()
			if slist.offset == 0 then
				return
			end
			local height = vim.api.nvim_win_get_height(M.p.win)
			slist.offset = math.max(0, slist.offset - height)
			search(height)
		end,
	},
	next = {
		desc = "Next song",
		action = function()
			core:next()
		end,
	},
	prev = {
		desc = "Previous song",
		action = function()
			core:prev()
		end,
	},
}

---@class music.panel.config
---@field lo? snacks.layout.Box
---@field keys? snacks.win.Keys

---@param opts? music.panel.config
function M:setup(opts)
	opts = opts or {}
	local default_keys = {
		["<Esc>"] = "close",               -- close the panel
		["<CR>"] = { "search", mode = "i" }, -- search in insert mode
		["<Space>"] = "toggle",            -- play/pause
		[","] = "append",                  -- append to current playlist
		["."] = "replace",                 -- replace current playlist
		[";"] = "switch",                  -- switch between panel and lyric window
		["m"] = "mode",                    -- switch mode between search, playlist
		["j"] = "next_search",             -- next search result
		["k"] = "prev_search",             -- previous search result
		[">"] = "next",                    -- next song
		["<"] = "prev",                    -- previous song
	}
	self.input = Snacks.win.new({
		ft = "music_input",
		keys = vim.tbl_deep_extend("force", default_keys, opts.keys or {}),
		actions = actions,
	})
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = self.input.augroup,
		buffer = self.input.buf,
		callback = function()
			if M.mode == "slist" then
				return
			end
			M.mode = "slist"
			spanel:clear(M.p, M.ns_id)
			render("slist")
		end,
	})

	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = self.input.augroup,
		buffer = self.input.buf,
		callback = actions.search.action,
	})

	self.p = Snacks.win.new({})

	u.fill_window(self.p.win, self.p.buf)

	---@type snacks.layout.Box
	local lo = {
		backdrop = false,
		border = "rounded",
		title = "Music Panel",
		title_pos = "center",
		height = 0.8,
		width = 0.6,
		box = "vertical",
		[1] = {
			win = "input",
			height = 1,
		},
		[2] = {
			win = "panel",
			border = "top",
		},
	}

	self.layout = Snacks.layout.new({
		wins = {
			input = self.input,
			panel = self.p,
		},
		layout = vim.tbl_deep_extend("force", lo, opts.lo or {}),
	})
	self.layout:show()
	self.layout:hide()
	-- Clear the namespace when switching to search mode
	self.ns_id = vim.api.nvim_create_namespace("PluginMusicUI")

	vim.api.nvim_create_user_command("Music", function()
		self:start()
	end, { desc = "Open the music panel" })

	core:observe("playing", {
		playing = function(id)
			self.playing = id
			render()
		end,
	})

	local observe =
	---@param name music.observer.field
			function(name)
				core:observe(name, {
					[name] = function(v)
						spanel[name] = v
						render("spanel")
					end,
				})
			end
	observe("playlist")
	observe("pause")
	observe("playing_time")
	observe("total_time")
	observe("mode")
end

return M
