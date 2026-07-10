-- Example LazyVim configuration for fzf-lua-file-browser.nvim
-- Save this file as `lua/plugins/fzf-file-browser.lua` in your LazyVim configuration directory.

return {
  {
    "soryescobar/fzf-lua-file-browser.nvim", -- Or your local path / repo
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
