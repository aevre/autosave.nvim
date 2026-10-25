# autosave.nvim

面向 Neovim 0.12+ 的小型、可靠、按 buffer 隔离的自动保存插件。

## 特性

- 默认启用，并可在运行时切换。
- 每个 buffer 独立执行 trailing debounce。
- 只保存具名、可写且已修改的普通文件 buffer。
- 保留原生写入 autocmd，并明确报告写入失败。
- 可通过 `vim.notify()` 显示可选的保存成功通知。
- 无依赖。

## 安装

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

## 配置

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

`events` 是用于调度保存的 Neovim autocmd 事件；`delay` 是以毫秒为单位的 trailing debounce。设置 `notify = true` 后，每次实际写入成功都会通知；跳过的 buffer 不通知，错误则始终报告。执行 `filter` 前，内建检查会跳过无效、未加载、未修改、不可修改、只读、无文件名和特殊 buffer。

## API

```lua
local autosave = require("autosave")

autosave.setup(opts)
autosave.enable()
autosave.disable()
autosave.toggle()
autosave.is_enabled()
autosave.save(buf) -- buf 可省略
```

使用 `:AutosaveToggle` 切换当前会话的自动保存状态。保存成功默认静默，可通过 `notify = true` 开启通知；过滤器和写入错误始终通过 `vim.notify()` 报告。
