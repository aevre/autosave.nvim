local config = require("autosave.config")
local saver = require("autosave.save")
local timer = require("autosave.timer")

---@class autosave.Api
---@type autosave.Api
---@diagnostic disable-next-line: missing-fields
local M = {}

---@type autosave.ResolvedConfig
local current = config.resolve()
local enabled = false
local generation = 0

---@param message string
---@param level integer
local function notify(message, level)
	vim.notify(message, level, { title = "autosave.nvim" })
end

---@param buf integer
local function schedule(buf)
	local current_generation = generation
	local ok = timer.schedule(buf, current.delay, function(target)
		if enabled and generation == current_generation then
			M.save(target)
		end
	end)
	if not ok then
		notify("failed to create save timer", vim.log.levels.ERROR)
	end
end

---@param buf? integer
---@return boolean saved
function M.save(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	timer.cancel(buf)
	return saver.save(buf, current.filter, current.notify)
end

---@return autosave.Api
function M.enable()
	if enabled then
		return M
	end
	enabled = true
	generation = generation + 1
	local group = vim.api.nvim_create_augroup("autosave_nvim", { clear = true })
	vim.api.nvim_create_autocmd(current.events, {
		group = group,
		callback = function(event)
			schedule(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(event)
			timer.cancel(event.buf)
		end,
	})
	return M
end

---@return autosave.Api
function M.disable()
	enabled = false
	generation = generation + 1
	timer.cancel_all()
	pcall(vim.api.nvim_del_augroup_by_name, "autosave_nvim")
	return M
end

---@return boolean enabled
function M.toggle()
	if enabled then
		M.disable()
	else
		M.enable()
	end
	return enabled
end

---@return boolean enabled
function M.is_enabled()
	return enabled
end

---@param opts? autosave.Config
---@return autosave.Api
function M.setup(opts)
	local next_config = config.resolve(opts)
	M.disable()
	current = next_config
	vim.api.nvim_create_user_command("AutosaveToggle", function()
		local state = M.toggle() and "enabled" or "disabled"
		notify(state, vim.log.levels.INFO)
	end, { force = true })
	if current.enabled then
		M.enable()
	end
	return M
end

return M
