local M = {}

M.config = {
	keymaps = {
		upstream_main = "<leader>gou", -- git open upstream
		current_branch = "<leader>goo", -- git open origin
	},
	default_branch = "main",
	auto_setup = true,
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if M.config.auto_setup then
		require("git-open.commands").setup_commands()
		require("git-open.commands").setup_keymaps(M.config.keymaps)
	end
end

return M
