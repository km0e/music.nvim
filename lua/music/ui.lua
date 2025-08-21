---@class music.ui.key
---@field [1] string
---@field mode? string "i"|"n"

---@class music.ui.keys
---@field ["close"|"search"|"toggle"|"append"|"replace"|"panel"|"mode"]  music.ui.key|music.ui.key[]

local M = {
	layout = nil,
	input = nil,
	p = nil,
	last_win = nil,
	ns_id = nil,
	---@type "select"|"panel"
	mode = "panel",
	playing = "",
}

---@type music.source
local src = require("music.source")
local core = require("music.core")
local select = require("music.ui.select")
local panel = require("music.ui.panel")

local modes = {
	pl = "loop",
	loop = "pl_loop",
	pl_loop = "pl",
}

local Snacks = require("snacks")
local u = require("music.util")

---@param mode? "select"|"panel"
local function render(mode)
	if mode and mode ~= M.mode then
		return
	end
	local map = {
		select = select,
		panel = panel,
	}
	map[M.mode]:render(M.p, M.ns_id, M.playing)
end

function M:start()
	self.last_win = vim.api.nvim_get_current_win()
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
	src:search(line, select.offset, count, function(songs)
		if not songs or #songs == 0 then
			if select.offset ~= 0 then
				select.offset = select.offset - vim.api.nvim_win_get_height(M.p.win)
			end
			return
		end
		for i, song in ipairs(songs) do
			select.search_list[select.offset + i] = song
		end
		render("select")
	end)
end

local actions = {
	close = function()
		M.layout:hide()
		vim.api.nvim_set_current_win(M.last_win)
		M.last_win = nil
	end,
	search = search,
	toggle = core.toggle,
	append = function()
		local song = select.search_list[vim.v.count1]
		if song then
			core.load(song.id, {
				append = #panel.playlist > 0,
				play = false,
			})
		end
	end,
	replace = function()
		local song = select.search_list[vim.v.count1]
		if song then
			core.load(song.id)
		end
	end,
	select = function()
		if M.mode == "select" then
			return
		end
		M.mode = "select"
		panel:clear(M.p, M.ns_id)
		render("select")
	end,
	switch = function()
		if M.mode == "panel" then
			M.mode = "select"
			panel:clear(M.p, M.ns_id)
			render("select")
		else
			M.mode = "panel"
			render("panel")
		end
	end,
	mode = function()
		core:mode(modes[panel.mode])
	end,
	next_search = function()
		local height = vim.api.nvim_win_get_height(M.p.win)
		if #select.search_list < height then
			return
		end
		select.offset = select.offset + height
		search(height)
	end,
	prev_search = function()
		if select.offset == 0 then
			return
		end
		local height = vim.api.nvim_win_get_height(M.p.win)
		select.offset = math.max(0, select.offset - height)
		search(height)
	end,
	next = function()
		core:next()
	end,
	prev = function()
		core:prev()
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
		["switch"] = ";",
		["mode"] = "m",
		["next_search"] = "j",
		["prev_search"] = "k",
		["next"] = ">",
		["prev"] = "<",
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

function M:setup(opts)
	opts = opts or {}

	self.input = Snacks.win.new({
		show = false,
		keys = self:setup_keys(opts.keys or {}),
		ft = "music_input",
	})
	self.p = Snacks.win.new({
		show = false,
	})
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
	lo = vim.tbl_deep_extend("force", lo, opts.win or {})

	self.layout = Snacks.layout.new({
		show = false,
		wins = {
			input = self.input,
			panel = self.p,
		},
		layout = lo,
	})
	self.last_win = vim.api.nvim_get_current_win()
	self.layout:show()
	actions["close"]()

	vim.api.nvim_create_autocmd("WinLeave", {
		group = self.input.augroup,
		buffer = self.input.buf,
		callback = actions["close"],
	})

	-- Clear the namespace when switching to search mode
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = self.input.augroup,
		buffer = self.input.buf,
		callback = actions.select,
	})

	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = self.input.augroup,
		buffer = self.input.buf,
		callback = actions.search,
	})

	-- Initialize the panel buffer with empty lines
	local space = {}
	for _ = 0, vim.api.nvim_win_get_height(self.p.win) - 1 do
		table.insert(space, "")
	end
	vim.api.nvim_buf_set_lines(self.p.buf, 0, -1, false, space)

	self.ns_id = vim.api.nvim_create_namespace("PluginMusicUI")

	vim.api.nvim_create_user_command("Music", function()
		self:start()
	end, { desc = "Open the music panel" })

	---@type music.core.observer
	---@diagnostic disable-next-line: missing-fields
	local observer = {}
	observer.playing = function(id)
		self.playing = id
		render()
	end
	observer.playlist = function(list)
		panel.playlist = list
		render("panel")
	end
	observer.pause = function(paused)
		panel.paused = paused
		render("panel")
	end
	observer.playing_time = function(time)
		panel.playing_time = time
		render("panel")
	end
	observer.total_time = function(time)
		panel.total_time = time
		render("panel")
	end
	observer.mode = function(mode)
		panel.mode = mode
		render("panel")
	end
	core:setup(observer)
end

return M
