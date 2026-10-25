---@class autosave.Api
local M = {}

---@type autosave.ResolvedConfig
local defaults = {
	enabled = true,
	events = { "InsertLeave", "TextChanged" },
	delay = 1000,
	notify = false,
	filter = function(_)
		return true
	end,
}

---@type autosave.ResolvedConfig
local config = vim.deepcopy(defaults)
local enabled = false
local generation = 0
---@type table<integer, uv.uv_timer_t>
local timers = {}

local function notify(message, level)
	vim.notify(message, level, { title = "autosave.nvim" })
end

---@param timer uv.uv_timer_t
local function close_timer(timer)
	if not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

---@param buf integer
local function cancel(buf)
	local timer = timers[buf]
	if timer then
		timers[buf] = nil
		close_timer(timer)
	end
end

local function cancel_all()
	for buf in pairs(timers) do
		cancel(buf)
	end
end

---@param opts autosave.ResolvedConfig
local function validate(opts)
	if type(opts) ~= "table" then
		error("autosave.nvim: options must be a table")
	end
	if type(opts.enabled) ~= "boolean" then
		error("autosave.nvim: enabled must be a boolean")
	end
	if type(opts.delay) ~= "number" or opts.delay < 0 or opts.delay % 1 ~= 0 then
		error("autosave.nvim: delay must be a non-negative integer")
	end
	if not vim.islist(opts.events) or vim.tbl_isempty(opts.events) then
		error("autosave.nvim: events must be a non-empty list")
	end
	for _, event in ipairs(opts.events) do
		if type(event) ~= "string" then
			error("autosave.nvim: every event must be a string")
		end
	end
	if type(opts.notify) ~= "boolean" then
		error("autosave.nvim: notify must be a boolean")
	end
	if type(opts.filter) ~= "function" then
		error("autosave.nvim: filter must be a function")
	end
end

---@param buf integer
---@return boolean
local function writable(buf)
	return vim.api.nvim_buf_is_valid(buf)
		and vim.api.nvim_buf_is_loaded(buf)
		and vim.bo[buf].modified
		and vim.bo[buf].modifiable
		and not vim.bo[buf].readonly
		and vim.bo[buf].buftype == ""
		and vim.api.nvim_buf_get_name(buf) ~= ""
end

---@param buf? integer
---@return boolean saved
function M.save(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	cancel(buf)
	if not writable(buf) then
		return false
	end

	local ok, allowed = pcall(config.filter, buf)
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
	if config.notify then
		notify(("saved %s"):format(vim.fn.fnamemodify(name, ":~:.")), vim.log.levels.INFO)
	end
	return true
end

---@param buf integer
local function schedule(buf)
	cancel(buf)
	local timer = vim.uv.new_timer()
	if not timer then
		notify("failed to create save timer", vim.log.levels.ERROR)
		return
	end

	local current_generation = generation
	timers[buf] = timer
	timer:start(config.delay, 0, function()
		vim.schedule(function()
			if timers[buf] ~= timer then
				close_timer(timer)
				return
			end
			timers[buf] = nil
			close_timer(timer)
			if enabled and generation == current_generation then
				M.save(buf)
			end
		end)
	end)
end

function M.enable()
	if enabled then
		return M
	end
	enabled = true
	generation = generation + 1
	local group = vim.api.nvim_create_augroup("autosave_nvim", { clear = true })
	vim.api.nvim_create_autocmd(config.events, {
		group = group,
		callback = function(event)
			schedule(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(event)
			cancel(event.buf)
		end,
	})
	return M
end

function M.disable()
	enabled = false
	generation = generation + 1
	cancel_all()
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
function M.setup(opts)
	if opts ~= nil and type(opts) ~= "table" then
		error("autosave.nvim: options must be a table")
	end
	local next_config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	validate(next_config)
	M.disable()
	config = next_config
	vim.api.nvim_create_user_command("AutosaveToggle", function()
		local state = M.toggle() and "enabled" or "disabled"
		notify(state, vim.log.levels.INFO)
	end, { force = true })
	if config.enabled then
		M.enable()
	end
	return M
end

return M
