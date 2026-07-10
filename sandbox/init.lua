local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/.reference/fzf-lua")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.termguicolors = true
vim.opt.number = true

-- Setup fzf-lua
local ok, fzf = pcall(require, "fzf-lua")
if ok then
  fzf.setup({})
end

-- Setup fzf-lua-file-browser
require("fzf-lua-file-browser").setup({
  hijack_netrw = true,
  hidden = true,
  display_stat = true,
})

-- Keymaps for sandbox testing
vim.keymap.set("n", "<space>fb", function()
  require("fzf-lua-file-browser").browse({ cwd = vim.fn.getcwd() })
end, { desc = "FzfLua File Browser (Root)" })

vim.keymap.set("n", "<space>fe", function()
  require("fzf-lua-file-browser").browse({ cwd = vim.fn.expand("%:p:h") })
end, { desc = "FzfLua File Browser (Buffer Dir)" })

vim.notify("Sandbox loaded! Press <space>fb to open fzf-lua-file-browser", vim.log.levels.INFO)
