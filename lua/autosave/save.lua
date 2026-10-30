---@class autosave.Saver
local M = {}

---@param message string
---@param level integer
local function notify(message, level)
	vim.notify(message, level, { title = "autosave.nvim" })
end

---@param buf integer
---@return boolean
function M.writable(buf)
	return vim.api.nvim_buf_is_valid(buf)
		and vim.api.nvim_buf_is_loaded(buf)
		and vim.bo[buf].modified
		and vim.bo[buf].modifiable
		and not vim.bo[buf].readonly
		and vim.bo[buf].buftype == ""
		and vim.api.nvim_buf_get_name(buf) ~= ""
end

---@param buf integer
---@param filter autosave.Filter
---@param should_notify boolean
---@return boolean saved
function M.save(buf, filter, should_notify)
	if not M.writable(buf) then
		return false
	end

	local ok, allowed = pcall(filter, buf)
	if not ok then
		notify(("filter failed: %s"):format(allowed), vim.log.levels.ERROR)
		return false
	end
	if not allowed then
		return false
	end

	local name = vim.api.nvim_buf_get_name(buf)
	local written, err = pcall(vim.api.nvim_buf_call, buf, function()
		vim.cmd("silent update")
	end)
	if not written then
		notify(("failed to save %s: %s"):format(name, err), vim.log.levels.ERROR)
		return false
	end
	if should_notify then
		notify(("saved %s"):format(vim.fn.fnamemodify(name, ":~:.")), vim.log.levels.INFO)
	end
	return true
end

return M
