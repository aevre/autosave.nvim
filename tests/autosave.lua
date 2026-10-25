local autosave = require("autosave")

local function eq(actual, expected, message)
	assert(
		vim.deep_equal(actual, expected),
		("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual))
	)
end

local function wait_for(predicate, message)
	assert(vim.wait(500, predicate, 5), message)
end

local paths = {}
local function file_buffer(contents)
	local path = vim.fn.tempname()
	vim.fn.writefile({ contents or "before" }, path)
	paths[#paths + 1] = path
	local buf = vim.fn.bufadd(path)
	vim.fn.bufload(buf)
	return buf, path
end

local function change(buf, text)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
	assert(vim.bo[buf].modified)
end

local function trigger(buf)
	vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
end

local notifications = {}
local original_notify = vim.notify
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(message, level, opts)
	notifications[#notifications + 1] = { message = message, level = level, opts = opts }
end

-- Default setup is enabled and direct saves use the target buffer.
autosave.setup({ delay = 10 })
assert(autosave.is_enabled())
local first, first_path = file_buffer()
change(first, "saved")
eq(autosave.save(first), true, "save should report success")
eq(vim.fn.readfile(first_path), { "saved" }, "save should write the requested buffer")
assert(not vim.bo[first].modified)
eq(#notifications, 0, "successful writes should be silent by default")

-- Successful write notifications are optional and only follow real writes.
notifications = {}
autosave.setup({ notify = true })
change(first, "notified")
eq(autosave.save(first), true, "save with notifications enabled should succeed")
eq(#notifications, 1, "a successful write should emit one notification")
assert(notifications[1].message:match("^saved "))
eq(notifications[1].level, vim.log.levels.INFO, "save notification should use info level")
eq(autosave.save(first), false, "an unchanged buffer should not be written")
eq(#notifications, 1, "a skipped write should not emit a notification")

-- Debounce is trailing: the second event replaces the first timer.
autosave.setup({ delay = 80 })
change(first, "one")
trigger(first)
vim.wait(50)
change(first, "two")
trigger(first)
vim.wait(50)
eq(vim.fn.readfile(first_path), { "notified" }, "the first timer must not write early")
wait_for(function()
	return vim.fn.readfile(first_path)[1] == "two"
end, "the latest change was not saved")

-- Buffers debounce independently and retain the triggering buffer identity.
local second, second_path = file_buffer()
autosave.setup({ delay = 20 })
change(first, "first buffer")
change(second, "second buffer")
trigger(first)
trigger(second)
vim.api.nvim_set_current_buf(second)
wait_for(function()
	return vim.fn.readfile(first_path)[1] == "first buffer" and vim.fn.readfile(second_path)[1] == "second buffer"
end, "independent buffer saves did not finish")

-- Disable cancels pending writes; toggle enables the plugin again.
autosave.setup({ delay = 40 })
change(first, "cancelled")
trigger(first)
autosave.disable()
vim.wait(80)
eq(vim.fn.readfile(first_path), { "first buffer" }, "disable must cancel pending saves")
assert(not autosave.is_enabled())
eq(autosave.toggle(), true, "toggle should re-enable autosave")

-- Repeated setup replaces configuration and autocmds.
autosave.setup({ delay = 0, events = { "TextChanged" } })
autosave.setup({ delay = 0, events = { "TextChanged" } })
local autocmds = vim.api.nvim_get_autocmds({ group = "autosave_nvim" })
eq(#autocmds, 3, "setup should leave one save autocmd and two cleanup autocmds")

-- Configuration errors fail before replacing the working setup.
local invalid = {
	function()
		autosave.setup("invalid")
	end,
	function()
		autosave.setup({ delay = 1.5 })
	end,
	function()
		autosave.setup({ notify = "yes" })
	end,
	function()
		autosave.setup({ events = { named = "TextChanged" } })
	end,
}
for _, configure in ipairs(invalid) do
	assert(not pcall(configure))
	assert(autosave.is_enabled())
end

-- User filters and built-in special-buffer checks prevent writes.
autosave.setup({
	delay = 0,
	filter = function(buf)
		return buf ~= first
	end,
})
change(first, "filtered")
eq(autosave.save(first), false, "filter should reject a buffer")
eq(vim.fn.readfile(first_path), { "first buffer" }, "filtered buffer must not be written")

local scratch = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "scratch" })
eq(autosave.save(scratch), false, "unnamed nofile buffers must be skipped")

-- Filter failures and write failures are visible and retain modified state.
notifications = {}
autosave.setup({
	filter = function()
		error("broken filter")
	end,
})
change(second, "filter error")
eq(autosave.save(second), false, "a failing filter must block the write")
assert(notifications[1] and notifications[1].message:match("filter failed"))
assert(vim.bo[second].modified)

notifications = {}
autosave.setup()
local bad = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(bad, vim.fn.tempname() .. "/missing/file")
vim.api.nvim_buf_set_lines(bad, 0, -1, false, { "cannot write" })
eq(autosave.save(bad), false, "write errors must be returned")
assert(vim.bo[bad].modified)
assert(notifications[1] and notifications[1].message:match("failed to save"))

-- Deleting a buffer invalidates its pending timer without an error.
autosave.setup({ delay = 30 })
local deleted = file_buffer()
change(deleted, "deleted")
trigger(deleted)
vim.api.nvim_buf_delete(deleted, { force = true })
vim.wait(60)

assert(vim.fn.exists(":AutosaveToggle") == 2)
autosave.disable()
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = original_notify
for _, path in ipairs(paths) do
	vim.fn.delete(path)
end

print("autosave.nvim tests passed")
