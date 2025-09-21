local snacks = require("snacks")
local core = require("music.core")
local fmt = require("music.panel.format")
local preview = require("music.panel.preview")
local src = require("music.source")

local M = {
	p = nil,
	---@type snacks.picker.Config
	opts = {},
	list_em = {},
}

function M:start()
	self.p = snacks.picker.pick(self.opts)
	core:refresh()
end

---@type table<string, snacks.picker.Action.spec>
local actions = {
	toggle = {
		desc = "Play/Pause",
		action = function()
			core.current_backend:toggle()
		end,
	},
	append = {
		desc = "Append the selected song to the playlist",
		action = function(self)
			local song = self:items()[vim.v.count1]
			self.list:_move(vim.v.count1, true)
			if song then
				core.current_backend:load(song.stream_url, {
					append = #core.state.playlist > 0,
					play = false,
				})
			end
		end,
	},
	replace = {
		desc = "Replace the playlist with the selected song",
		action = function(self)
			local song = self:items()[vim.v.count1]
			self.list:_move(vim.v.count1, true)
			if song then
				core.current_backend:load(song.stream_url)
			end
		end,
	},
	mode = {
		desc = "Switch playback mode",
		action = function()
			local modes = {
				pl = "loop",
				loop = "pl_loop",
				pl_loop = "pl",
			}
			core.current_backend:mode(modes[core.state.mode])
		end,
	},
	next = {
		desc = "Next song",
		action = function()
			core.current_backend:next()
		end,
	},
	prev = {
		desc = "Previous song",
		action = function()
			core.current_backend:prev()
		end,
	},
}
---@class music.panel.config
---@field keys? table<string, snacks.win.Keys>
--
--
---@param opts music.panel.config
function M:setup(opts)
	core:subscribe(vim.schedule_wrap(function()
		if self.p and self.p.preview then
			self.p.preview:refresh(self.p)
		end
	end))
	setmetatable(preview, { __index = core.state })

	local default_keys = {
		["<CR>"] = { "search", mode = "i" }, -- search in insert mode
		["<Space>"] = "toggle", -- play/pause
		[","] = "append", -- append to current playlist
		["."] = "replace", -- replace current playlist
		["m"] = "mode", -- switch mode between search, playlist
		[">"] = "next", -- next song
		["<"] = "prev", -- previous song
	}

	local finder = {}
	for _, s in pairs(src.srcs) do
		finder[#finder + 1] = function(_, ctx)
			local items = s:find(ctx)
			fmt:cache(items)
			return items
		end
	end
	self.opts = {
		title = "Search Music",
		label = "Enter search query:",
		win = {
			input = {
				keys = default_keys,
			},
			preview = {
				wo = { number = false, relativenumber = false, signcolumn = "no", foldcolumn = "0" },
			},
		},
		live = true,
		finder = finder,
		format = function(item, picker)
			return fmt:format(item, vim.api.nvim_win_get_width(picker.list.win.win), { idx = true })
		end,
		preview = function(ctx)
			return preview:render(ctx)
		end,
		show_empty = true,
		actions = actions,
	}
	self.opts = vim.tbl_deep_extend("force", self.opts, opts or {})
	vim.api.nvim_create_user_command("Music", function()
		self:start()
	end, { desc = "Open the music panel" })
	preview:setup()
end

return M
