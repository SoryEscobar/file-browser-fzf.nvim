# fzf-lua-file-browser.nvim

`fzf-lua-file-browser.nvim` is a blazing fast, feature-rich file system explorer and manager for Neovim built **entirely on `fzf-lua`** — with zero dependency on Telescope or Plenary.

It provides a 100% equivalent workflow to [`telescope-file-browser.nvim`](https://github.com/nvim-telescope/telescope-file-browser.nvim), including directory navigation, file/folder operations, Netrw hijacking, multi-selection batch actions, and **Neovim 0.10+ LSP rename integration (`workspace/didRenameFiles`)**.

---

## ✨ Features

- **🚀 100% Pure `fzf-lua`**: No Telescope or Plenary dependencies.
- **📂 Interactive Directory Navigator**:
  - Enter folders (`<CR>` on a directory navigates into it).
  - Go up to parent directory (`<C-g>` or `<BS>` when prompt query is empty).
  - Jump to home (`<C-e>`) or current Neovim working directory (`<C-w>`).
  - Synchronize Neovim's `:cd` working directory (`<C-t>`).
- **🛠️ Synchronized File System Operations**:
  - **Create** (`<A-c>` or `<S-CR>`): Synchronously create files or directories (supports nested directories like `foo/bar/baz.lua`).
  - **Rename** (`<A-r>`): Rename single or multi-selected items with automatic Neovim 0.10+ LSP rename notification (`workspace/didRenameFiles`).
  - **Move** (`<A-m>`): Move selected items to any target directory.
  - **Copy** (`<A-y>`): Recursive copy of selected files or directories.
  - **Delete** (`<A-d>`): Confirm and delete single or multi-selected items.
  - **Open** (`<C-o>`): Open files or folders with system default applications (`xdg-open` / macOS `open`).
- **⚡ High-Performance Previewer**:
  - Syntax highlighted file previews via `fzf-lua`.
  - Smart folder previews (`eza`, `lsd`, `tree`, or fallback `ls -la`) when hovering over directories or `../`.
- **🔌 Seamless Netrw Hijacking**: Set `hijack_netrw = true` to automatically open `fzf-lua-file-browser` when opening directory buffers (`nvim .`).
- **💎 First-Class LazyVim Integration**: Drop-in spec ready for LazyVim configs.

---

## 📋 Requirements

- **Neovim** >= 0.9.0 (0.10+ recommended for LSP file rename notifications)
- **[`fzf-lua`](https://github.com/ibhagwan/fzf-lua)**
- **[`nvim-web-devicons`](https://github.com/nvim-tree/nvim-web-devicons)** (optional, for icons)

---

## 📦 Installation

### [LazyVim](https://lazyvim.github.io/) Integration

Drop this spec into `lua/plugins/fzf-file-browser.lua`:

```lua
return {
  {
    "soryescobar/fzf-lua-file-browser.nvim", -- Or local path
    dependencies = { "ibhagwan/fzf-lua" },
    opts = {
      hijack_netrw = true,
      hidden = true,
      display_stat = true,
    },
    keys = {
      {
        "<leader>fB",
        function()
          require("fzf-lua-file-browser").browse({ cwd = vim.fn.getcwd() })
        end,
        desc = "File Browser (Root Dir)",
      },
      {
        "<leader>fb",
        function()
          require("fzf-lua-file-browser").browse({ cwd = vim.fn.expand("%:p:h") })
        end,
        desc = "File Browser (Buffer Dir)",
      },
      {
        "<space>fb",
        function()
          require("fzf-lua-file-browser").browse()
        end,
        desc = "FzfLua File Browser",
      },
    },
  },
}
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "soryescobar/fzf-lua-file-browser.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("fzf-lua-file-browser").setup({
      hijack_netrw = true,
      hidden = false,
    })
  end,
}
```

---

## ⚙️ Configuration

```lua
require("fzf-lua-file-browser").setup({
  cwd = nil,               -- Default working directory (defaults to vim.fn.getcwd())
  hidden = false,          -- Show hidden dotfiles
  files_only = false,      -- Show only files
  dirs_only = false,       -- Show only directories
  hide_parent_dir = false, -- Hide ../ parent directory entry
  hijack_netrw = true,     -- Replace Netrw when editing directories
  display_stat = false,    -- Show file size and modification time
  actions = {              -- Custom keybind overrides
    -- ["ctrl-x"] = function(selected, opts) ... end
  },
})
```

---

## 🎮 Keymaps & Actions

| Keybind | Action | Description |
|---|---|---|
| `<CR>` | `enter` | Enter directory (`cwd = dir`) or edit file |
| `<C-g>` | `goto_parent_dir` | Navigate to parent directory (`../`) |
| `<C-e>` | `goto_home_dir` | Navigate to home directory (`~`) |
| `<C-w>` | `goto_cwd` | Navigate to Neovim current working directory |
| `<C-t>` | `change_cwd` | Change Neovim's working directory (`:cd`) |
| `<A-c>` | `create` | Interactive prompt to create file or directory (`/` suffix for dir) |
| `<S-CR>` | `create_from_prompt` | Create file/folder from typed prompt text |
| `<A-r>` | `rename` | Rename single or multi-selected files/folders (+ LSP hook) |
| `<A-m>` | `move` | Move selected item(s) to target directory |
| `<A-y>` | `copy` | Copy selected item(s) to target directory |
| `<A-d>` | `remove` | Delete selected item(s) with confirmation dialog |
| `<C-o>` | `open` | Open selected item with system default application |
| `<C-h>` | `toggle_hidden` | Toggle hidden dotfiles display |
| `<C-f>` | `toggle_browser` | Toggle between showing folders only vs all entries |
| `<BS>` | `backspace` | If prompt query is empty, navigate to parent directory |

---

## 🧪 Testing & Interactive Sandbox

### Run Automated Unit Tests

A comprehensive headless Neovim test harness is included:

```bash
./tests/run_all.sh
```

### Interactive Testing Sandbox

Launch Neovim with the isolated interactive sandbox:

```bash
./sandbox/run.sh
```

Press `<space>fb` inside the sandbox to open the browser immediately!

---

## 📄 License

MIT License
