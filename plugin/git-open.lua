-- Auto-setup if the plugin is loaded
if vim.g.loaded_git_open then
	return
end
vim.g.loaded_git_open = 1

-- Setup the plugin with default configuration
require("git-open").setup()
