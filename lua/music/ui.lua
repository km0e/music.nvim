local b = require("music.backend")

local M = {
	layout = nil,
	---@type NuiPopup
	panel = nil,
	---@type NuiInput
	search = nil,
	---@type NuiPopup
	select = nil,
}
---@type NuiPopup
local panel = nil

local function transform_mode(mode)
	if mode == "once" then
		return "⏹️"
	elseif mode == "loop" then
		return "🔂"
	elseif mode == "pl" then
		return "➡️"
	elseif mode == "pl_loop" then
		return "🔁"
	end
end

function M.setup()
	local Layout = require("nui.layout")
	local Input = require("nui.input")
	local Popup = require("nui.popup")

	M.panel = Popup({
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
			text = {
				top = "[Music Panel]",
				top_align = "center",
			},
		},
		position = "50%",
		size = {
			width = "50%",
			height = 2,
		},
		buf_options = {
			modifiable = true,
			readonly = false,
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:Normal",
		},
	})
	panel = M.panel

	M.search = Input({
		position = "50%",
		size = {
			width = "100%",
			height = 1,
		},
		border = {
			style = "single",
			text = {
				top = "[title]",
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:Normal",
		},
	}, {
		prompt = "> ",
		default_value = "",
		on_close = function() end,
	})

	M.select = Popup({
		border = {
			style = "rounded",
		},
		position = "50%",
		size = {
			width = "80%",
			height = "60%",
		},
	})

	M.layout = Layout(
		{
			position = "50%",
			size = {
				width = 80,
				height = "60%",
			},
		},
		Layout.Box({
			Layout.Box(M.panel, { size = { height = 4 } }),
			Layout.Box(M.search, { size = { height = 1 } }),
			Layout.Box(M.select, { size = "60%" }),
		}, { dir = "col" })
	)

	vim.api.nvim_create_user_command("Music", M.start, { desc = "Opens the music panel" })
	b.render = M.try_render
end

function M.render()
	local state = b.state
	local ns_id = vim.api.nvim_create_namespace("PluginMusicUI")
	vim.api.nvim_buf_clear_namespace(panel.bufnr, ns_id, 0, -1)
	local width = vim.api.nvim_win_get_width(0) -- 当前窗口宽度

	local name = string.format("%s - %s - %s", state.title, state.artist, state.album)
	local time = string.format("%s/%s", state.playing_time, state.total_time)

	local padding = width - vim.fn.strdisplaywidth(name) - vim.fn.strdisplaywidth(time)
	vim.api.nvim_buf_set_lines(panel.bufnr, 0, -1, false, { "" }) -- 清空行
	vim.api.nvim_buf_set_extmark(panel.bufnr, ns_id, 0, 0, {
		virt_text = {
			{ name, "Identifier" },
			{ string.rep(" ", padding), "Normal" },
			{ time, "String" },
		},
		virt_text_pos = "overlay", -- 整行渲染
		hl_mode = "combine",
	})

	local paused = "⏸️"
	if state.paused then
		paused = "▶️"
	end
	local mode = transform_mode(state.mode)
	padding = width - vim.fn.strdisplaywidth(paused) - vim.fn.strdisplaywidth(mode)
	local lpadding = math.floor(padding / 2)
	local rpadding = padding - lpadding
	vim.api.nvim_buf_set_lines(panel.bufnr, 1, -1, false, { "" }) -- 清空行
	vim.api.nvim_buf_set_extmark(panel.bufnr, ns_id, 1, 0, {
		virt_text = {
			{ string.rep(" ", lpadding), "Normal" },
			{ paused, "Identifier" },
			{ string.rep(" ", rpadding), "Normal" },
			{ mode, "String" },
		},
		virt_text_pos = "overlay", -- 整行渲染
		hl_mode = "combine",
	})
end

function M.try_render()
	vim.schedule(function()
		if M.layout.winid and vim.api.nvim_win_is_valid(M.layout.winid) then
			M.render()
		end
	end)
end

function M.start()
	b.lazy_setup()

	M.last_win = vim.api.nvim_get_current_win()

	M.layout:mount()
	vim.api.nvim_set_current_win(M.search.winid)

	local function close()
		M.layout:unmount()
		if M.last_win and vim.api.nvim_win_is_valid(M.last_win) then
			vim.api.nvim_set_current_win(M.last_win)
			M.last_win = nil
		end
	end

	M.search:map("n", "<Esc>", close, { noremap = true, silent = true })
	panel:map("n", "<Esc>", close, { noremap = true, silent = true })
	M.select:map("n", "<Esc>", close, { noremap = true, silent = true })

	local function update(songs)
		if not songs or #songs == 0 then
			vim.api.nvim_buf_set_lines(M.select.bufnr, 0, -1, false, { "No songs found." })
			return
		end
		for i, song in ipairs(songs) do
			local title = song.title or "Unknown Title"
			local artist = song.artist or "Unknown Artist"
			vim.api.nvim_buf_set_lines(
				M.select.bufnr,
				i - 1,
				i,
				false,
				{ string.format("%d. %s - %s", i, title, artist) }
			)
			M.search:map("n", tostring(i), function()
				b.play(song.id)
			end, { noremap = true, silent = true })
		end
	end

	M.search:map("i", "<CR>", function()
		local text = vim.api.nvim_buf_get_lines(M.search.bufnr, 0, 1, false)[1]:sub(3) -- remove the prompt
		update(b.search(text) or {})
	end)

	M.search:map("n", "<Space>", function()
		b.toggle()
	end, { noremap = true, silent = true })

	M.search:map("n", "m", function()
		b.toggle_mode()
	end, { noremap = true, silent = true })

	M.render()
end

return M
