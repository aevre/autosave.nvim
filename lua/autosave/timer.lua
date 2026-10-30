---@class autosave.Timer
local M = {}

---@type table<integer, uv.uv_timer_t>
local timers = {}

---@param timer uv.uv_timer_t
local function close(timer)
	if not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

---@param buf integer
function M.cancel(buf)
	local timer = timers[buf]
	if timer then
		timers[buf] = nil
		close(timer)
	end
end

function M.cancel_all()
	for buf in pairs(timers) do
		M.cancel(buf)
	end
end

---@param buf integer
---@param delay integer
---@param callback fun(buf: integer)
function M.schedule(buf, delay, callback)
	M.cancel(buf)
	local timer = vim.uv.new_timer()
	if not timer then
		return false
	end

	timers[buf] = timer
	timer:start(delay, 0, function()
		vim.schedule(function()
			if timers[buf] ~= timer then
				close(timer)
				return
			end
			timers[buf] = nil
			close(timer)
			callback(buf)
		end)
	end)
	return true
end

return M
