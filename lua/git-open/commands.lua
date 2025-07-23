local M = {}

-- Utility function to get the appropriate open command for the OS
local function get_open_command()
	if vim.fn.has("mac") == 1 then
		return "open"
	elseif vim.fn.has("unix") == 1 then
		return "xdg-open"
	elseif vim.fn.has("win32") == 1 then
		return "start"
	else
		return nil
	end
end

-- Utility function to convert SSH URLs to HTTPS
local function normalize_git_url(url)
	if not url or url == "" then
		return nil
	end

	-- Convert SSH to HTTPS for GitHub
	url = url:gsub("git@github%.com:", "https://github.com/")
	-- Convert SSH to HTTPS for GitLab
	url = url:gsub("git@gitlab%.com:", "https://gitlab.com/")
	-- Convert SSH to HTTPS for Bitbucket
	url = url:gsub("git@bitbucket%.org:", "https://bitbucket.org/")

	-- Remove .git suffix
	url = url:gsub("%.git$", "")

	return url
end

-- Function to open URL in browser
local function open_in_browser(url)
	local open_cmd = get_open_command()
	if not open_cmd then
		vim.notify("Unsupported operating system", vim.log.levels.ERROR)
		return false
	end

	local success = vim.fn.system(open_cmd .. ' "' .. url .. '"')
	if vim.v.shell_error == 0 then
		vim.notify("Opened: " .. url, vim.log.levels.INFO)
		return true
	else
		vim.notify("Failed to open URL in browser", vim.log.levels.ERROR)
		return false
	end
end

-- Check if we're in a git repository
local function is_git_repo()
	local result = vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null")
	return vim.trim(result) == "true"
end

-- Get the relative path of the current file from git root
local function get_relative_path()
	local file_path = vim.fn.expand("%:.")
	if file_path == "" then
		return nil
	end

	-- Get path relative to git root
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
	git_root = vim.trim(git_root)

	if git_root == "" then
		return file_path
	end

	local full_path = vim.fn.expand("%:p")
	local relative_path = full_path:gsub("^" .. vim.pesc(git_root) .. "/", "")

	return relative_path
end

-- Open file on upstream main branch
function M.open_upstream_main()
	if not is_git_repo() then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return
	end

	local file_path = get_relative_path()
	if not file_path then
		vim.notify("No file open", vim.log.levels.ERROR)
		return
	end

	-- Get upstream URL, fallback to origin
	local upstream_url = vim.fn.system("git config --get remote.upstream.url 2>/dev/null")
	upstream_url = vim.trim(upstream_url)

	if upstream_url == "" then
		upstream_url = vim.fn.system("git config --get remote.origin.url 2>/dev/null")
		upstream_url = vim.trim(upstream_url)
	end

	if upstream_url == "" then
		vim.notify("No upstream or origin remote found", vim.log.levels.ERROR)
		return
	end

	upstream_url = normalize_git_url(upstream_url)
	if not upstream_url then
		vim.notify("Failed to normalize git URL", vim.log.levels.ERROR)
		return
	end

	local config = require("git-open").config
	local browser_url = upstream_url .. "/blob/" .. config.default_branch .. "/" .. file_path

	open_in_browser(browser_url)
end

-- Open file on current branch
function M.open_current_branch()
	if not is_git_repo() then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return
	end

	local file_path = get_relative_path()
	if not file_path then
		vim.notify("No file open", vim.log.levels.ERROR)
		return
	end

	-- Get current branch name
	local current_branch = vim.fn.system("git branch --show-current 2>/dev/null")
	current_branch = vim.trim(current_branch)

	if current_branch == "" then
		vim.notify("Not on a branch (detached HEAD?)", vim.log.levels.ERROR)
		return
	end

	-- Get the remote for current branch, fallback to origin
	local remote_name = vim.fn.system("git config --get branch." .. current_branch .. ".remote 2>/dev/null")
	remote_name = vim.trim(remote_name)

	if remote_name == "" then
		remote_name = "origin"
	end

	-- Get remote URL
	local remote_url = vim.fn.system("git config --get remote." .. remote_name .. ".url 2>/dev/null")
	remote_url = vim.trim(remote_url)

	if remote_url == "" then
		vim.notify("No remote URL found for branch: " .. current_branch, vim.log.levels.ERROR)
		return
	end

	remote_url = normalize_git_url(remote_url)
	if not remote_url then
		vim.notify("Failed to normalize git URL", vim.log.levels.ERROR)
		return
	end

	local browser_url = remote_url .. "/blob/" .. current_branch .. "/" .. file_path

	open_in_browser(browser_url)
end

-- Setup user commands
function M.setup_commands()
	vim.api.nvim_create_user_command("GitOpenUpstreamMain", M.open_upstream_main, {
		desc = "Open current file on upstream main branch in browser",
	})

	vim.api.nvim_create_user_command("GitOpenCurrentBranch", M.open_current_branch, {
		desc = "Open current file on current branch in browser",
	})
end

-- Setup keymaps
function M.setup_keymaps(keymaps)
	if keymaps.upstream_main then
		vim.keymap.set("n", keymaps.upstream_main, M.open_upstream_main, {
			desc = "Open file on upstream main in browser (git open upstream)",
		})
	end

	if keymaps.current_branch then
		vim.keymap.set("n", keymaps.current_branch, M.open_current_branch, {
			desc = "Open file on current branch in browser (git open origin)",
		})
	end
end

return M
