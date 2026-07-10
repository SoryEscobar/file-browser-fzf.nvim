-- LazyVim integration spec for fzf-lua-file-browser.nvim
-- Drop this file or import it inside your LazyVim lua/plugins/ directory.

return {
  "fzf-lua-file-browser.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  opts = {
    hijack_netrw = true,
    hidden = true,
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
}
