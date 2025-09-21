local subsonic = require("music.source.subsonic")

---@class music.source:music._source[]
local M = {
	---@type table<string, music.source>
	srcs = {},
	su2s = {},
}

M.__index = M

---@class music.source.config
---@field subsonic music.subsonic.config[]

---@param opts music.source.config
function M:setup(opts)
	subsonic:setup(self)
	for _, conf in ipairs(opts.subsonic) do
		local src = subsonic:new(conf)
		if not src then
			vim.notify("Failed to create subsonic source", vim.log.levels.ERROR)
			return
		end
		---@diagnostic disable-next-line: assign-type-mismatch
		self.srcs[conf.id] = src
	end
end

function M:find(name)
	local items = self:search(name)
	for _, item in ipairs(items) do
		self.su2s[item["stream_url"]] = item
	end
	return items
end

---@param url string
---@param cb fun(music.song?)
function M:parse(url, cb)
	local sid = url:match("[?&]sid=([^&]+)")
	if not sid or not self.srcs[sid] then
		return nil
	end
	vim.schedule(function()
		cb(self.srcs[sid]:get(url))
	end)
end

return M
