---@class autosave.Configuration
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

---@param opts? autosave.Config
---@return autosave.ResolvedConfig
function M.resolve(opts)
	if opts ~= nil and type(opts) ~= "table" then
		error("autosave.nvim: options must be a table")
	end
	local resolved = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.deepcopy(opts or {}))
	---@cast resolved autosave.ResolvedConfig
	validate(resolved)
	return resolved
end

return M
