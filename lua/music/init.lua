local M = {}

function M.setup(opts)
	require("music.ui").init()
	require("music.backend").setup(opts)
	vim.api.nvim_create_user_command("Music", require("music.ui").start, { desc = "Toggles the music search window" })
end

return M
