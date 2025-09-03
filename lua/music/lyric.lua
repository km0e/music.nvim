local M = {
	p = nil,
	ns_id = nil,
	times = {},
	next_line = 2,
	em = nil,
}

---@type music.source
local src = require("music.source")
local core = require("music.core")

local Snacks = require("snacks")
local u = require("music.util")

function M:start()
	core:lazy_setup()

	if not self.p.win then
		self.p:show()
	end
	self.p:focus()
end

---@param self snacks.win
---@param fn fun(cfg:table):table
local function move_win(self, fn)
	local cfg = vim.api.nvim_win_get_config(self.win)
	local new_cfg = vim.tbl_deep_extend("force", {
		row = cfg.row,
		col = cfg.col,
		relative = "editor",
	}, fn(cfg))
	vim.api.nvim_win_set_config(self.win, new_cfg)
end

---@type table<string, snacks.win.Action>
local actions = {
	leave = {
		desc = "Leave the lyric panel",
		action = function()
			vim.cmd("wincmd p")
		end,
	},
	mleft = {
		desc = "Move left",
		action = function(self)
			move_win(self, function(cfg)
				return { col = cfg.col - 1 }
			end)
		end,
	},
	mright = {
		desc = "Move right",
		action = function(self)
			move_win(self, function(cfg)
				return { col = cfg.col + 1 }
			end)
		end,
	},
	mup = {
		desc = "Move up",
		action = function(self)
			move_win(self, function(cfg)
				return { row = cfg.row - 1 }
			end)
		end,
	},
	mdown = {
		desc = "Move down",
		action = function(self)
			move_win(self, function(cfg)
				return { row = cfg.row + 1 }
			end)
		end,
	},
	inc_h = {
		desc = "Increase height",
		action = function(self)
			vim.api.nvim_win_set_height(self.win, vim.api.nvim_win_get_height(self.win) + 1)
		end,
	},
	inc_w = {
		desc = "Increase width",
		action = function(self)
			vim.api.nvim_win_set_width(self.win, vim.api.nvim_win_get_width(self.win) + 1)
		end,
	},
	dec_h = {
		desc = "Decrease height",
		action = function(self)
			local h = vim.api.nvim_win_get_height(self.win)
			if h > 1 then
				vim.api.nvim_win_set_height(self.win, h - 1)
			end
		end,
	},
	dec_w = {
		desc = "Decrease width",
		action = function(self)
			local w = vim.api.nvim_win_get_width(self.win)
			if w > 1 then
				vim.api.nvim_win_set_width(self.win, w - 1)
			end
		end,
	},
}

---@param opts? snacks.win.Config
function M:setup(opts)
	---@type snacks.win.Config
	local win_opts = {
		keys = {
			[";"] = "leave",
			["<Left>"] = "mleft",
			["<Right>"] = "mright",
			["<Up>"] = "mup",
			["<Down>"] = "mdown",
			["<C-Up>"] = "inc_h",
			["<C-Down>"] = "dec_h",
			["<C-Right>"] = "inc_w",
			["<C-Left>"] = "dec_w",
		},
		actions = actions,
		backdrop = false,
		border = "none",
		height = 1,
		width = 30,
	}

	self.p = Snacks.win.new(vim.tbl_deep_extend("force", win_opts, opts or {}))

	u.fill_window(self.p.win, self.p.buf)
	self.p:hide()

	self.ns_id = vim.api.nvim_create_namespace("PluginMusicUI")

	vim.api.nvim_create_user_command("MusicLyric", function()
		self:start()
	end, { desc = "Show Music Lyric Panel" })

	core:observe("playing", {
		playing = function(id)
			self.times = {}
			vim.api.nvim_buf_set_lines(self.p.buf, 0, -1, false, {})
			for i, item in pairs(src:lyric(id)) do
				table.insert(self.times, #self.times + 1, item.time)
				vim.api.nvim_buf_set_lines(self.p.buf, i - 1, i - 1, false, { item.line })
			end
			if self.p.win then
				vim.api.nvim_win_set_cursor(self.p.win, { 1, 0 })
			end
			self.next_line = 2
		end,
	})

	core:observe("playing_time", {
		playing_time = function(time)
			if #self.times <= self.next_line then
				return
			end
			local win = nil
			while time >= self.times[self.next_line] and self.next_line < #self.times do
				self.next_line = self.next_line + 1
				win = self.p.win
			end
			if win then
				vim.api.nvim_win_call(win, function()
					local h = vim.api.nvim_win_get_height(0)
					local dist = math.floor(h / 2)
					self.em = vim.api.nvim_buf_set_extmark(self.p.buf, self.ns_id, self.next_line - 2, 0, {
						hl_group = "Visual",
						end_line = self.next_line - 1,
						end_col = 0,
						priority = 100,
						id = self.em,
					})
					local view = vim.fn.winsaveview()
					view.topline = math.max(1, self.next_line - dist - 1)
					vim.fn.winrestview(view)
				end)
			end
		end,
	})
end

return M
