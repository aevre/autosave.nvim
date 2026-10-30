# autosave.nvim

Small, reliable per-buffer autosave for Neovim 0.12+.

[简体中文](README.zh-CN.md)

## Features

- Enabled by default and toggleable at runtime.
- Trailing debounce tracked independently for every buffer.
- Saves only named, writable, modified file buffers.
- Preserves native write autocmds and reports write failures.
- Optional successful-write notifications through `vim.notify()`.
- No dependencies.

## Installation

```lua
{
    name = "autosave.nvim",
    dir = vim.fn.expand("~/Projects/lib/autosave.nvim"),
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },
    opts = {
        delay = 1000,
        notify = true,
        filter = function(buf)
            return vim.bo[buf].filetype ~= "oil"
        end,
    },
}
```

## Configuration

```lua
require("autosave").setup({
    enabled = true,
    events = { "InsertLeave", "TextChanged" },
    delay = 1000,
    notify = false,
    filter = function(_)
        return true
    end,
})
```

`events` are Neovim autocmd events that schedule a save. `delay` is a trailing debounce in milliseconds. Set `notify = true` to report each successful write; skipped buffers never notify, while errors are always reported. Built-in checks always skip invalid, unloaded, unmodified, unmodifiable, readonly, unnamed, and special buffers before `filter` runs.

## API

```lua
local autosave = require("autosave")

autosave.setup(opts)
autosave.enable()
autosave.disable()
autosave.toggle()
autosave.is_enabled()
autosave.save(buf) -- buf is optional
```

Use `:AutosaveToggle` to toggle autosave for the current session. Successful writes are silent by default and optionally reported with `notify = true`; filter and write errors are always reported through `vim.notify()`.

## Development

Run `make check` from the repository root. Configuration, saving, timer debounce, and public API behavior live in focused modules under `lua/autosave/`; the guarded `plugin/autosave.lua` entrypoint only applies defaults. `make test` runs the headless regression suite.
