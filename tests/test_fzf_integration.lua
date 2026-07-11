local init = require("fzf-lua-file-browser")

print("=== Running test_fzf_integration.lua ===")

init.setup({
  hijack_netrw = true,
})

local passed = false

-- Verify backspace is not bound to custom actions so it natively deletes characters without UI re-render
local browse_mod = require("fzf-lua-file-browser.browse")
local default_actions = browse_mod.get_actions({})
assert(default_actions["bspace"] == nil and default_actions["_bspace"] == nil, "bspace should not be overridden in actions")

-- Verify browse() sanitizes bspace/is_live from user opts before passing to fzf_exec
local fzf = require("fzf-lua")
local orig_fzf_exec = fzf.fzf_exec
local intercepted_opts = nil
fzf.fzf_exec = function(contents, o)
  intercepted_opts = o
  return orig_fzf_exec(contents, o)
end

-- Launch browse with dummy bspace and is_live to verify cleanup
local test_opts = {
  cwd = vim.fn.getcwd(),
  hidden = false,
  is_live = true,
  actions = { ["bspace"] = function() end },
  keymap = { fzf = { ["bspace"] = "dummy" } }
}
init.browse(test_opts)
fzf.fzf_exec = orig_fzf_exec

assert(intercepted_opts.is_live == nil, "is_live should be stripped so typing does not re-render UI")
assert(intercepted_opts.actions["bspace"] == nil, "actions.bspace should be stripped so Backspace uses native fzf backward-delete-char")
assert(intercepted_opts.keymap.fzf["bspace"] == nil, "keymap.fzf.bspace should be stripped")

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
