local M = {}

---@param hint string
---@param data table
---@param ... string|string[]
function M.field_check(hint, data, ...)
	local check_field = function(d, rfields)
		local td = d
		for _, field in ipairs(rfields) do
			if not td[field] then
				return false
			end
			td = td[field]
		end
		return true
	end
	for _, field in ipairs({ ... }) do
		if type(field) == "string" then
			field = { field }
		elseif type(field) ~= "table" then
			vim.notify(hint .. "Invalid field type: " .. type(field), vim.log.levels.ERROR)
			return false
		end
		if not check_field(data, field) then
			vim.notify(hint .. "Missing required field(s): " .. table.concat(field, ", "), vim.log.levels.ERROR)
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

---@param win integer
function M.fill_window(win, buf)
	local space = {}
	for _ = 0, vim.api.nvim_win_get_height(win) - 1 do
		table.insert(space, "")
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, space)
end

return M
