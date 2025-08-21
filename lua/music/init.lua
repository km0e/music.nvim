local M = {}

---@class music.config
---@field keys music.ui.keys
---@field win snacks.win.Config
---@field source music.source.config

---@param opts music.config
function M.setup(opts)
	require("music.source"):setup(opts.source)
	require("music.ui"):setup(opts)
end

return M
