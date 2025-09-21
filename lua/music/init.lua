---@class music.subsonic.query
---@field v string api version
---@field u string username
---@field p string|nil password
---@field t string|nil token
---@field s string|nil salt
---
---@class music.subsonic.config
---@field id string
---@field url string
---@field q music.subsonic.query
---
---
---@class music.lyric_item
---@field time number -- in milliseconds
---@field line string
---
---@alias music.lyric music.lyric_item[]
---
---@class music.song
---@field id string
---@field title string
---@field artist? string
---@field album? string
---@field lyric? music.lyric
---@field stream_url? string

local M = {}

---@class music.config
---@field panel music.panel.config
---@field lyric snacks.win.Config
---@field source music.source.config
---@field backend music.core.config

---@param opts music.config
function M.setup(opts)
	require("music.source"):setup(opts.source)
	require("music.core"):setup(opts.backend)
	require("music.lyric"):setup(opts.lyric)
	require("music.panel"):setup(opts.panel)
end

return M
