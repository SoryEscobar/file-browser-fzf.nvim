-- Sample standalone configuration file for fzf-lua-file-browser.nvim
-- You can use this as a reference or require/copy it into your Neovim configuration.

local actions = require("fzf-lua-file-browser.actions")

return {
  -- Default working directory (nil defaults to vim.fn.getcwd())
  cwd = nil,

  -- Show hidden dotfiles by default
  hidden = false,

  -- Show only files or only directories
  files_only = false,
  dirs_only = false,

  -- Hide ../ parent directory entry
  hide_parent_dir = false,

  -- Automatically replace Netrw when opening directory buffers (e.g. nvim .)
  hijack_netrw = true,

  -- Display file size and modification timestamp columns
  display_stat = false,

  -- Configure custom keymaps & shortcuts.
  -- You can use either Telescope-style `mappings` tables (insert/normal mode notations)
  -- or direct `actions` / `keymaps` tables. Action names can be strings or functions.
  mappings = {
    ["i"] = {
      -- Open shortcuts & keybinds help list cheat sheet modal
      ["<C-k>"] = "keymaps_help",

      -- File & directory creation (supports nested directories e.g. "new_dir/sub/file.txt")
      -- Immediately opens newly created files in the current buffer.
      ["<C-a>"] = "create",
      ["<A-c>"] = "create",
      ["<S-CR>"] = "create_from_prompt",

      -- File operations
      ["<C-r>"] = "rename",
      ["<C-j>"] = "move",
      ["<C-y>"] = "copy",
      ["<C-x>"] = "remove",

      -- Directory navigation
      ["<C-g>"] = "goto_parent_dir",
      ["<C-e>"] = "goto_home_dir",
      ["<C-w>"] = "goto_cwd",
      ["<C-t>"] = "change_cwd",

      -- Filtering & toggles
      ["<C-h>"] = "toggle_hidden",
      ["<C-i>"] = "toggle_gitignore",
      ["<C-l>"] = "toggle_depth",
      ["<C-s>"] = "toggle_all",
    },
    ["n"] = {
      -- Normal mode mappings
      ["?"] = "keymaps_help",
      ["c"] = "create",
      ["r"] = "rename",
      ["m"] = "move",
      ["y"] = "copy",
      ["d"] = "remove",
    },
  },
}
