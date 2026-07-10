local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/.reference/fzf-lua")

-- Disable swap files during tests
vim.opt.swapfile = false

require("fzf-lua-file-browser").setup({
  hijack_netrw = true,
})
