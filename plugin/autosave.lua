if vim.g.loaded_autosave_nvim then
	return
end
vim.g.loaded_autosave_nvim = true

require("autosave").setup()
