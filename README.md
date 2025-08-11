# git-open.nvim

🚀 **A Neovim plugin to open your current file in the browser on GitHub, GitLab, or Bitbucket.**

Jump from your editor to your repository's web interface with a single keystroke. Perfect for code reviews, sharing links, or viewing files in context.

**git-open.nvim** focuses on solving a specific problem really well:

✅ What We Do Best

1. Dual Context Awareness - Distinguish between upstream main and current branch
2. Multi-Platform Support - GitHub, GitLab, Bitbucket, and custom Git hosts work out of the box
3. Minimal Setup - Zero configuration required to get started

🤔 Honest Comparison
While other plugins may have overlapping features, git-open.nvim is designed specifically for developers who:

- Need both upstream and current branch contexts regularly
- Work across multiple Git hosting platforms
- Want a lightweight solution without heavy dependencies
- Prefer simple keybinds over complex commands

## ✨ Why

I didn't manage to configure any other plugin to work how I would like it to.

## 🚀 Usage

### Keymaps

| Keymap        | Action                        | Description                                            |
| :------------ | :---------------------------- | :----------------------------------------------------- |
| `<leader>gou` | **G**it **O**pen **U**pstream | Open current file on upstream repository's main branch |
| `<leader>goo` | **G**it **O**pen **O**rigin   | Open current file on current branch                    |

### Commands

| Command                | Description                               |
| :--------------------- | :---------------------------------------- |
| `:GitOpenUpstreamMain` | Open current file on upstream main branch |

|Note: Both commands accept a Visual selection as a range and will include it in the URL anchor. `:GitOpenCurrentBranch` | Open current file on current branch |

## 📸 Examples

```bash
# Compare with upstream main
<leader>gou → https://github.com/upstream/repo/blob/main/src/file.lua

# Share your current work
<leader>goo → https://github.com/origin/repo/blob/feature-branch/src/file.lua

# Visual selection (e.g., lines 10–20), then open on current branch
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
