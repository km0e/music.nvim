local M = {}

---@class music.config
---@field panel music.panel.config
---@field lyric snacks.win.Config
---@field source music.source.config

---@param opts music.config
function M.setup(opts)
	require("music.source"):setup(opts.source)
	require("music.panel"):setup(opts.panel)
	require("music.lyric"):setup(opts.lyric)
	require("music.core"):setup()
	require("music.backend"):setup()
end

return M
