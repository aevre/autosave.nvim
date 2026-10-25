---@alias autosave.Filter fun(buf: integer): boolean

---@class autosave.Config
---@field enabled? boolean Enable autosave after setup. Defaults to `true`.
---@field events? string[] Neovim autocmd events that schedule saves.
---@field delay? integer Trailing debounce delay in milliseconds.
---@field notify? boolean Notify after successful writes. Defaults to `false`.
---@field filter? autosave.Filter Additional buffer filter evaluated after built-in safety checks.

---@class autosave.ResolvedConfig
---@field enabled boolean
---@field events string[]
---@field delay integer
---@field notify boolean
---@field filter autosave.Filter

---@class autosave.Api
---@field setup fun(opts?: autosave.Config): autosave.Api
---@field enable fun(): autosave.Api
---@field disable fun(): autosave.Api
---@field toggle fun(): boolean enabled
---@field is_enabled fun(): boolean enabled
---@field save fun(buf?: integer): boolean saved

return {}
