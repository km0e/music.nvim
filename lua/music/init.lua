local M = {}

---@class music.config
---@field keys music.ui.keys
---@field win snacks.win.Config
---@field user music.backend.config

function M.setup(opts)
	require("music.backend").setup(opts.user)
	require("music.ui").setup(opts)
end

return M
