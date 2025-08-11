local M = {}

-- Configuration ----------------------------------------------------------------

local defaults = {
  default_branch = "main",
  -- line_mode:
  --   "auto"  -> Visual selection => range anchor, otherwise no anchor
  --   "none"  -> never add line anchors
  --   "cursor"-> always add current cursor line anchor
  line_mode = "auto",
}

M.config = vim.tbl_deep_extend("force", {}, defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  M.setup_commands()
  if opts and opts.keymaps then
    M.setup_keymaps(opts.keymaps)
  end
end

-- Utilities --------------------------------------------------------------------

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

  local _ = vim.fn.system(open_cmd .. ' "' .. url .. '"')
  if vim.v.shell_error == 0 then
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

-- New: helpers for host, blob/src segment and line anchors ---------------------

local function get_host(url)
  return url:match("^https?://([^/]+)/")
end

local function get_blob_segment_for_host(host)
  -- GitHub/GitLab use /blob/, Bitbucket uses /src/
  if host and host:find("bitbucket%.org") then
    return "/src/"
  end
  return "/blob/"
end

local function is_visual_mode()
  local m = vim.api.nvim_get_mode().mode
  return m == "v" or m == "V" or m == string.char(22) -- 22 is Ctrl-V (visual block)
end

local function get_selected_or_current_line_range()
  if is_visual_mode() then
    local s = vim.fn.line("'<")
    local e = vim.fn.line("'>")
    if s > e then
      s, e = e, s
    end
    return s, e
  else
    local l = vim.api.nvim_win_get_cursor(0)[1]
    return l, l
  end
end

local function get_current_line_only()
  return vim.api.nvim_win_get_cursor(0)[1]
end

local function build_line_anchor(url, start_line, end_line)
  local host = get_host(url)
  if not host or not start_line or start_line <= 0 then
    return ""
  end
  end_line = end_line or start_line

  -- GitHub/GitLab: #L{n} or #L{a}-L{b}
  -- Bitbucket: #lines-{n} or #lines-{a}:{b}
  if host:find("github%.com") or host:find("gitlab%.com") then
    if start_line == end_line then
      return "#L" .. start_line
    else
      return "#L" .. start_line .. "-L" .. end_line
    end
  elseif host:find("bitbucket%.org") then
    if start_line == end_line then
      return "#lines-" .. start_line
    else
      return "#lines-" .. start_line .. ":" .. end_line
    end
  else
    return ""
  end
end

-- Anchor decision logic --------------------------------------------------------

local function compute_anchor_lines(opts)
  -- Priority:
  -- 1) Explicit range from user command (:<,'>GitOpen...)
  -- 2) Bang forces current line
  -- 3) Config line_mode
  opts = opts or {}

  if opts.range and opts.range > 0 and opts.line1 and opts.line2 then
    local s, e = opts.line1, opts.line2
    if s > e then
      s, e = e, s
    end
    return s, e
  end

  if opts.bang then
    local l = vim.api.nvim_win_get_cursor(0)[1]
    return l, l
  end

  local mode = M.config.line_mode
  if mode == "cursor" then
    local l = vim.api.nvim_win_get_cursor(0)[1]
    return l, l
  elseif mode == "auto" then
    -- If invoked from a visual mapping that calls the Lua function directly,
    -- the visual mode may have ended; prefer command -range for accuracy.
    -- Fallback to live visual detection:
    if is_visual_mode() then
      local s = vim.fn.line("'<")
      local e = vim.fn.line("'>")
      if s > e then
        s, e = e, s
      end
      return s, e
    end
    return nil, nil
  else
    -- "none"
    return nil, nil
  end
end

-- Openers ----------------------------------------------------------------------

-- Open file on upstream main branch
function M.open_upstream_main(opts)
  opts = opts or {}

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

  local host = get_host(upstream_url)
  local segment = get_blob_segment_for_host(host)

  local s, e = compute_anchor_lines(opts)
  local anchor = ""
  if s and s > 0 then
    anchor = build_line_anchor(upstream_url, s, e or s)
  end

  local browser_url = upstream_url .. segment .. M.config.default_branch .. "/" .. file_path .. anchor

  open_in_browser(browser_url)
end

-- Open file on current branch
function M.open_current_branch(opts)
  opts = opts or {}

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

  local host = get_host(remote_url)
  local segment = get_blob_segment_for_host(host)

  local s, e = compute_anchor_lines(opts)
  local anchor = ""
  if s and s > 0 then
    anchor = build_line_anchor(remote_url, s, e or s)
  end

  local browser_url = remote_url .. segment .. current_branch .. "/" .. file_path .. anchor

  open_in_browser(browser_url)
end

-- Backward-compatible helpers: always open at current cursor line --------------

-- Open file on upstream main branch at current cursor line (single line)
function M.open_upstream_main_same_line()
  M.open_upstream_main({ bang = true })
end

-- Open file on current branch at current cursor line (single line)
function M.open_current_branch_same_line()
  M.open_current_branch({ bang = true })
end

-- Setup user commands ----------------------------------------------------------

function M.setup_commands()
  vim.api.nvim_create_user_command("GitOpenUpstreamMain", function(cmd_opts)
    M.open_upstream_main(cmd_opts)
  end, {
    desc = "Open current file on upstream main branch in browser",
    range = true,
    bang = true,
  })

  vim.api.nvim_create_user_command("GitOpenCurrentBranch", function(cmd_opts)
    M.open_current_branch(cmd_opts)
  end, {
    desc = "Open current file on current branch in browser",
    range = true,
    bang = true,
  })

  -- Legacy commands: route to forced 'cursor' behavior
  vim.api.nvim_create_user_command("GitOpenUpstreamMainLine", function()
    M.open_upstream_main({ bang = true })
  end, {
    desc = "Open current file on upstream main at current line in browser",
  })

  vim.api.nvim_create_user_command("GitOpenCurrentBranchLine", function()
    M.open_current_branch({ bang = true })
  end, {
    desc = "Open current file on current branch at current line in browser",
  })
end

-- Setup keymaps ----------------------------------------------------------------

function M.setup_keymaps(keymaps)
  if keymaps.upstream_main then
    -- Normal: no anchor (per config), Visual: range anchor via -range
    vim.keymap.set("n", keymaps.upstream_main, function()
      M.open_upstream_main({})
    end, {
      desc = "Open file on upstream main in browser (git open upstream)",
    })
    vim.keymap.set("v", keymaps.upstream_main, ":GitOpenUpstreamMain<CR>", {
      desc = "Open selection on upstream main in browser (git open upstream)",
    })
  end

  if keymaps.current_branch then
    vim.keymap.set("n", keymaps.current_branch, function()
      M.open_current_branch({})
    end, {
      desc = "Open file on current branch in browser (git open origin)",
    })
    vim.keymap.set("v", keymaps.current_branch, ":GitOpenCurrentBranch<CR>", {
      desc = "Open selection on current branch in browser (git open origin)",
    })
  end

  -- Force current line anchor regardless of config
  if keymaps.upstream_main_line then
    vim.keymap.set("n", keymaps.upstream_main_line, function()
      M.open_upstream_main({ bang = true })
    end, {
      desc = "Open current line on upstream main in browser",
    })
  end

  if keymaps.current_branch_line then
    vim.keymap.set("n", keymaps.current_branch_line, function()
      M.open_current_branch({ bang = true })
    end, {
      desc = "Open current line on current branch in browser",
    })
  end
end

return M
