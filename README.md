# fzf-lua-file-browser.nvim

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-blueviolet.svg?style=flat-square&logo=Neovim)](https://neovim.io)
[![fzf-lua](https://img.shields.io/badge/Powered%20by-fzf--lua-00A98F.svg?style=flat-square)](https://github.com/ibhagwan/fzf-lua)
[![CI](https://github.com/SoryEscobar/file-browser-fzf.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/SoryEscobar/file-browser-fzf.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

`fzf-lua-file-browser.nvim` is a blazing fast, feature-rich file system explorer and manager for Neovim built **entirely on `fzf-lua`** — with zero dependency on Telescope or Plenary.

It provides a 100% equivalent workflow to [`telescope-file-browser.nvim`](https://github.com/nvim-telescope/telescope-file-browser.nvim), including directory navigation, file/folder operations, Netrw hijacking, multi-selection batch actions, and **Neovim 0.10+ LSP rename integration (`workspace/didRenameFiles`)**.

---

## ✨ Features

- **🚀 100% Pure `fzf-lua`**: No Telescope or Plenary dependencies.
- **📂 Interactive Directory Navigator**:
  - Enter folders (`<CR>` on a directory navigates into it).
  - Go up to parent directory (`<Left>` arrow key).
  - Jump to home (`<C-e>`) or current Neovim working directory (`<C-w>`).
  - Synchronize Neovim's `:cd` working directory (`<C-t>`).
- **🛠️ Synchronized File System Operations**:
  - **Create** (`<C-a>` / `<A-c>` or `<S-CR>`): Interactive file & directory creation.
    - **Direct Buffer Opening**: Creating a new file immediately opens it in your Neovim buffer ready for editing.
    - **Nested Directory Creation**: Supporting full path creation on the fly (e.g. typing `custom_folder/sub/newfile.txt` automatically creates `custom_folder/sub/` if missing, creates `newfile.txt`, and opens it immediately).
  - **Rename** (`<C-r>` / `<A-r>`): Rename single or multi-selected items with automatic Neovim 0.10+ LSP rename notification (`workspace/didRenameFiles`).
  - **Move** (`<C-j>` / `<A-m>`): Move selected items to any target directory.
  - **Copy** (`<C-y>` / `<A-y>`): Recursive copy of selected files or directories.
  - **Delete** (`<C-x>` / `<A-d>`): Confirm and delete single or multi-selected items.
  - **Open** (`<C-o>`): Open files or folders with system default applications (`xdg-open` / macOS `open`).
- **🎮 Built-in Shortcuts Cheat Sheet Modal**:
  - Press `<C-k>` inside the browser to open an interactive floating cheat sheet listing all available keybinds with short descriptions.
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
    "SoryEscobar/file-browser-fzf.nvim", -- Or local path
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
  "SoryEscobar/file-browser-fzf.nvim",
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

A complete sample configuration file is available at [`examples/config.lua`](./examples/config.lua).

```lua
require("fzf-lua-file-browser").setup({
  cwd = nil,               -- Default working directory (defaults to vim.fn.getcwd())
  hidden = false,          -- Show hidden dotfiles
  files_only = false,      -- Show only files
  dirs_only = false,       -- Show only directories
  hide_parent_dir = false, -- Hide ../ parent directory entry
  hijack_netrw = true,     -- Replace Netrw when editing directories
  display_stat = false,    -- Show file size and modification time

  -- Configure keymaps either Telescope-style (mappings) or fzf-lua style (actions/keymaps):
  mappings = {
    ["i"] = {
      ["<C-k>"] = "keymaps_help",
      ["<C-a>"] = "create",
      ["<C-r>"] = "rename",
    },
    ["n"] = {
      ["c"] = "create",
      ["?"] = "keymaps_help",
    },
  },
})
```

---

## 🎮 Keymaps & Actions

| Keybind | Action | Description |
|---|---|---|
| `<C-k>` | `keymaps_help` | **Open shortcuts & keybinds cheat sheet modal** |
| `<C-d>` / `<C-u>` | `preview-page-down` / `preview-page-up` | **Scroll right preview panel down / up (Page)** |
| `<C-f>` / `<A-b>` | `page-down` / `page-up` | **Scroll left listings panel down / up (Page)** |
| `<CR>` / `<Right>` | `enter` | Enter directory (`cwd = dir`) or edit file |
| `<Left>` | `goto_parent_dir` | Navigate to parent directory (`../`) |
| `<BS>` | `native backspace` | Delete backward character from prompt without UI re-render |
| `<C-a>` / `<A-c>` | `create` | Create file/dir (supports nested path creation `dir/sub/file.txt` & opens immediately in buffer) |
| `<S-CR>` / `<C-n>` | `create_from_prompt` | Create file/folder from typed prompt text & open buffer |
| `<C-r>` / `<A-r>` | `rename` | Rename single or multi-selected files/folders (+ LSP hook) |
| `<C-j>` / `<A-m>` | `move` | Move selected item(s) to target directory |
| `<C-y>` / `<A-y>` | `copy` | Copy selected item(s) to target directory |
| `<C-x>` / `<A-d>` | `remove` | Delete selected item(s) with confirmation dialog |
| `<C-w>` | `change_cwd` | Change Neovim's working directory (`:cd`) |
| `<C-b>` | `goto_cwd` | Navigate to Neovim current working directory |
| `<C-e>` | `goto_home_dir` | Navigate to home directory (`~`) |
| `<C-h>` | `toggle_hidden` | Toggle hidden dotfiles display |
| `<C-i>` | `toggle_gitignore` | Toggle gitignore filtering |
| `<C-l>` | `toggle_depth` | Toggle recursive directory scanning |
| `<C-g>` | `toggle_grouping` | Toggle grouping directories first |
| `<C-s>` | `toggle_all` | Toggle all filters (show all hidden/ignored) |
| `<C-o>` | `open` | Open selected item with system default application |

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
