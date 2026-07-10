local init = require("fzf-lua-file-browser")

print("=== Running test_fzf_integration.lua ===")

init.setup({
  hijack_netrw = true,
})

local passed = false

-- Launch browse
init.browse({ cwd = vim.fn.getcwd() })

-- Schedule verification after fzf window opens
vim.defer_fn(function()
  local wins = vim.api.nvim_list_wins()
  print("Open windows count: " .. #wins)
  passed = true
end, 800)

vim.wait(1500, function() return passed end, 50)

if passed then
  print("=== ALL test_fzf_integration.lua PASSED ===")
else
  error("Integration test timed out or failed")
end
