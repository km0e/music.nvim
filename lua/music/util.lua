local M = {}

---@param hint string
---@param data table
---@param ... string
function M.field_check(hint, data, ...)
	for _, field in ipairs({ ... }) do
		if not data[field] then
			vim.notify(hint .. "Missing field: " .. field, vim.log.levels.ERROR)
			return false
		end
	end
	return true
end

---@param kv table
function M.kv_to_str(kv)
	local F = require("plenary.functional")
	local function url_encode(str)
		if type(str) ~= "number" then
			str = str:gsub("\r?\n", "\r\n")
			str = str:gsub("([^%w%-%.%_%~ ])", function(c)
				return string.format("%%%02X", c:byte())
			end)
			str = str:gsub(" ", "+")
			return str
		else
			return str
		end
	end
	return F.join(
		F.kv_map(function(kvp)
			return kvp[1] .. "=" .. url_encode(kvp[2])
		end, kv),
		"&"
	)
end

---@param value string
---@return string
function M.hex_encode(value)
	local hex = ""
	for i = 1, #value do
		hex = hex .. string.format("%02x", value:byte(i))
	end
	return hex
end

function M.notify(msg, level)
	---@param notif snacks.notifier.Notif
	local function keep(notif)
		notif.timeout = 20000 -- 5 seconds
		return false
	end
	vim.notify(msg, level or vim.log.levels.INFO, {
		--@type fun(notif: snacks.notifier.Notif): boolean
		keep = keep,
	})
end

return M
