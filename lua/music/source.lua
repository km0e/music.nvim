local M = {
	srcs = {},
	su2s = {},
}

---@class music.source.config
---@field subsonic music.subsonic.config[]

---@param opts music.source.config
function M:setup(opts)
	for i, conf in ipairs(opts.subsonic) do
		local src = require("music.source.subsonic"):new(conf)
		if not src then
			vim.notify("Failed to create subsonic source", vim.log.levels.ERROR)
			return
		end
		self.srcs[i] = function(...)
			local items = src(...)
			for _, item in ipairs(items) do
				self.su2s[item.stream_url] = item
			end
			return items
		end
	end
end

return M
