# git-open.nvim

🚀 **Open your current file in the browser on GitHub, GitLab, or Bitbucket from Neovim.**

**Features:**

- Open files on upstream main branch or current branch
- Support for GitHub, GitLab, Bitbucket, and custom Git hosts
- Zero configuration required
- Visual selection support with line anchors

## 🚀 Usage

**Keymaps:**

- `<leader>gou` - Open file on upstream main branch
- `<leader>goo` - Open file on current branch

**Commands:**

- `:GitOpenUpstreamMain` - Open file on upstream main branch
- `:GitOpenCurrentBranch` - Open file on current branch

## 📸 Examples

```bash
# Open on upstream main
<leader>gou → https://github.com/upstream/repo/blob/main/src/file.lua

# Open on current branch
<leader>goo → https://github.com/origin/repo/blob/feature-branch/src/file.lua

# With visual selection (lines 10-20)
<leader>goo → https://github.com/origin/repo/blob/feature-branch/src/file.lua#L10-L20
```

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'jcger/git-open.nvim',
  cmd = { 'GitOpenUpstreamMain', 'GitOpenCurrentBranch' },
  keys = {
    { '<leader>gou', desc = 'Open file on upstream main' },
    { '<leader>goo', desc = 'Open file on current branch' },
  },
  config = function()
    require('git-open').setup()
  end,
}
```
