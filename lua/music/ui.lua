---@class music.ui.state
---@field search? music.backend.song[] all search results
---@field soffset? number select search offset
---@field paused? boolean is the player paused
---@field mode? "once" | "loop" | "pl" | "pl_loop"
---@field title? string the current song title
---@field artist? string the current song artist
---@field album? string the current song album
---@field total_time? number the total time of the current song
---@field playing_time? number the current playing time of the song
---@field playlist? music.backend.song[]  the current playlist
---@field playing? number the index of the currently playing song in the playlist
---@field ploffset? number the offset of the playlist, used for pagination
---
---
---@class music.ui.key
---@field [1] string
---@field mode? string "i"|"n"

---@class music.ui.keys
---@field ["close"|"search"|"toggle"|"append"|"replace"|"panel"|"mode"]  music.ui.key|music.ui.key[]

local M = {
	layout = nil,
	search = nil,
	p = nil,
	last_win = nil,
	ns_id = nil,
	---@type "select"|"panel"
	mode = "panel",
	---@type music.ui.state
	state = {
		search = {},
		soffset = 0,
		paused = false,
		mode = "once",
		title = "Unknown Title",
		artist = "Unknown Artist",
		album = "Unknown Album",
		total_time = 0.00,
		playing_time = 0.00,
		playlist = {},
	},
	components = {
		select = require("music.ui.select"),
		panel = require("music.ui.panel"),
	},
}

local modes = {
	once = "loop",
	loop = "pl",
	pl = "pl_loop",
	pl_loop = "once",
}

local Snacks = require("snacks")
local b = require("music.backend")
local u = require("music.util")

function M:start()
	self.last_win = vim.api.nvim_get_current_win()
	b.lazy_setup()

	self.layout:unhide()
	self.search:focus()
	self.mode = "panel"

	b.mode(modes[M.state.mode]) -- NOTE: this is a workaround to set the mode initially
	self:render()
end

function M:render()
	self.components[self.mode]:render(self.p, self.ns_id, self.state)
end

---@param msg music.ui.state
function M:update(msg)
	-- u.notify("Updating music UI with message: " .. vim.inspect(msg), vim.log.levels.DEBUG)
	if msg.soffset and msg.soffset ~= self.state.soffset then --NOTE:outdated
		return
	end
	local map = {
		search = "select",
		album = "panel",
		artist = "panel",
		title = "panel",
		total_time = "panel",
		playing_time = "panel",
		paused = "panel",
		mode = "panel",
		playlist = "panel",
		playing = "panel",
	}
	local need_render = {}
	for key, value in pairs(msg) do
		if map[key] then
			need_render[map[key]] = true
			self.state[key] = value
		end
	end
	if self.last_win == nil then
		return
	end
	if need_render[self.mode] then
		self:render()
	end
end

---@param count? number
local function search(count)
	if type(count) ~= "number" then
		-- If count is not provided, use the current window height
		count = vim.api.nvim_win_get_height(M.p.win)
	end
	local line = vim.api.nvim_get_current_line()
	if line == "" then
		return
	end
	b.search(line, M.state.soffset, count)
end

local actions = {
	close = function()
		M.layout:hide()
		vim.api.nvim_set_current_win(M.last_win)
		M.last_win = nil
	end,
	search = search,
	toggle = b.toggle,
	append = function()
		local song = M.state.search[vim.v.count1]
		if song then
			b.play(song.id, #M.state.playlist > 0)
		end
	end,
	replace = function()
		local song = M.state.search[vim.v.count1]
		if song then
			b.play(song.id)
		end
	end,
	select = function()
		if M.mode == "select" then
			return
		end
		M.components.panel:clear(M.p, M.ns_id)
		M.mode = "select"
		M:render()
	end,
	panel = function()
		if M.mode == "panel" then
			return
		end
		M.components.select:clear(M.p, M.ns_id)
		M.mode = "panel"
		M:render()
	end,
	mode = function()
		M:update({
			mode = modes[M.state.mode],
		})
		b.mode(modes[M.state.mode])
	end,
	next_search = function()
		local height = vim.api.nvim_win_get_height(M.p.win)
		if #M.state.search < height then
			return
		end
		M.state.soffset = M.state.soffset + height
		search(height)
	end,
	prev_search = function()
		if M.state.soffset == 0 then
			return
		end
		local height = vim.api.nvim_win_get_height(M.p.win)
		M.state.soffset = math.max(0, M.state.soffset - height)
		search(height)
	end,
}

---@param keys music.ui.keys
function M:setup_keys(keys)
	local default = {
		["close"] = "<Esc>",
		["search"] = { "<CR>", mode = "i" },
		["toggle"] = "<Space>",
		["append"] = ",",
		["replace"] = ".",
		["panel"] = ";",
		["mode"] = "m",
		["next_search"] = "j",
		["prev_search"] = "k",
	}

	keys = vim.tbl_deep_extend("force", default, keys)
	local skeys = {}
	local function snack_keys(key, action, mode)
		if actions[action] then
			return {
				key,
				actions[action],
				mode = mode,
			}
		else
			u.notify("Unknown action: " .. action, vim.log.levels.WARN)
			return nil
		end
	end
	for action, key in pairs(keys) do
		if type(key) == "string" then
			skeys[action] = snack_keys(key, action, "n")
		elseif type(key) == "table" and key[1] then
			if type(key[1]) == "string" then
				skeys[action] = snack_keys(key[1], action, key.mode)
			elseif type(key[1]) == "table" then
				vim.notify("Invalid key format for action: " .. action, vim.log.levels.WARN)
				--TODO: support multiple keys
			end
		else
			u.notify("Invalid key type " .. type(key) .. " for action: " .. action, vim.log.levels.WARN)
		end
	end
	return skeys
end

function M.setup(opts)
	opts = opts or {}

	M.search = Snacks.win.new({
		show = false,
		keys = M:setup_keys(opts.keys or {}),
	})
	M.p = Snacks.win.new({
		show = false,
	})
	local lo = {
		backdrop = false,
		border = "rounded",
		title = "Music Panel",
		title_pos = "center",
		height = 0.8,
		width = 0.8,
		box = "vertical",
		[1] = {
			win = "search",
			height = 1,
		},
		[2] = {
			win = "panel",
			border = "top",
		},
	}
	lo = vim.tbl_deep_extend("force", lo, opts.win or {})

	M.layout = Snacks.layout.new({
		show = false,
		wins = {
			search = M.search,
			panel = M.p,
		},
		layout = lo,
	})
	M.last_win = vim.api.nvim_get_current_win()
	M.layout:show()
	actions["close"]()

	vim.api.nvim_create_autocmd("WinLeave", {
		group = M.search.augroup,
		buffer = M.search.buf,
		callback = actions["close"],
	})

	-- Clear the namespace when switching to search mode
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = M.search.augroup,
		buffer = M.search.buf,
		callback = actions["select"],
	})

	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = M.search.augroup,
		buffer = M.search.buf,
		callback = actions["search"],
	})

	-- Render function to update the panel buffer
	b.render = vim.schedule_wrap(function(us)
		M:update(us)
	end)

	-- Initialize the panel buffer with empty lines
	local space = {}
	for _ = 0, vim.api.nvim_win_get_height(M.p.win) - 1 do
		table.insert(space, "")
	end
	vim.api.nvim_buf_set_lines(M.p.buf, 0, -1, false, space)

	M.ns_id = vim.api.nvim_create_namespace("PluginMusicUI")

	vim.api.nvim_create_user_command("Music", function()
		M:start()
	end, { desc = "Open the music panel" })
end

return M
