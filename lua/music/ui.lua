local M = {}

function M.init()
	local Layout = require("nui.layout")
	local Input = require("nui.input")
	local Popup = require("nui.popup")

	M.input = Input({
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

	M.popup = Popup({
		focusable = false,
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
			Layout.Box(M.input, { size = { height = 1 } }),
			Layout.Box(M.popup, { size = "60%" }),
		}, { dir = "col" })
	)
end

function M.start()
	if not require("music.backend").try_start_server() then
		return
	end
	M.last_win = vim.api.nvim_get_current_win()

	M.layout:mount()

	vim.api.nvim_set_current_win(M.input.winid)

	local function close()
		M.layout:unmount()
		if M.last_win and vim.api.nvim_win_is_valid(M.last_win) then
			vim.api.nvim_set_current_win(M.last_win)
		end
	end

	M.input:map("n", "<Esc>", close, { noremap = true, silent = true })
	M.input:map("i", "<CR>", function()
		local text = vim.api.nvim_buf_get_lines(M.input.bufnr, 0, 1, false)[1]:sub(3) -- remove the prompt
		M.update(require("music.backend").search(text) or {})
	end)                                                                          -- NOTE: Overwrite the input on_submit
end

function M.update(songs)
	if not songs or #songs == 0 then
		vim.api.nvim_buf_set_lines(M.popup.bufnr, 0, -1, false, { "No songs found." })
		return
	end
	for i, song in ipairs(songs) do
		local title = song.title or "Unknown Title"
		local artist = song.artist or "Unknown Artist"
		vim.api.nvim_buf_set_lines(M.popup.bufnr, i - 1, i, false, { string.format("%d. %s - %s", i, title, artist) })
		M.input:map("n", tostring(i), function()
			require("music.backend").play(song.id)
		end, { noremap = true, silent = true })
	end
end

return M
