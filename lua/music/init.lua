local M = {}

function M.setup(opts)
	require("music.backend").setup(opts)
	require("music.ui").setup()
end

return M
