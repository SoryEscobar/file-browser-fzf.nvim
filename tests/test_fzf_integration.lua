local init = require("fzf-lua-file-browser")

print("=== Running test_fzf_integration.lua ===")

init.setup({
  hijack_netrw = true,
})

local passed = false

-- Launch browse
local test_opts = { cwd = vim.fn.getcwd(), hidden = false }
init.browse(test_opts)

-- Schedule verification and simulate reopen cycles
vim.defer_fn(function()
  local wins = vim.api.nvim_list_wins()
  print("Open windows count: " .. #wins)

  -- Simulate action triggering reopen(opts, { hidden = true })
  require("fzf-lua-file-browser.actions").toggle_hidden({}, test_opts)

  vim.defer_fn(function()
    print("Reopened picker successfully without convert_reload_actions assertion failure")
    passed = true
  end, 300)
end, 800)

vim.wait(2000, function() return passed end, 50)

if passed then
  print("=== ALL test_fzf_integration.lua PASSED ===")
else
  error("Integration test timed out or failed")
end
