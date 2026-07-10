local init = require("fzf-lua-file-browser")

local function assert_true(cond, msg)
  if not cond then
    error("ASSERT FAILED: " .. (msg or ""))
  end
end

print("=== Running test_netrw.lua ===")

local browse_called = false
local browse_cwd = nil
package.loaded["fzf-lua-file-browser"] = vim.tbl_extend("force", init, {
  browse = function(opts)
    browse_called = true
    browse_cwd = opts and opts.cwd
  end,
})

init.setup({ hijack_netrw = true })

-- Create temp directory and edit it
local tmpdir = vim.fn.tempname()
vim.fn.mkdir(tmpdir, "p")

vim.cmd("edit " .. vim.fn.fnameescape(tmpdir))

-- Wait for BufEnter schedule callback
vim.wait(500, function() return browse_called end, 10)

assert_true(browse_called, "hijack_netrw should invoke browse when editing a directory")

vim.fn.delete(tmpdir, "rf")

print("=== ALL test_netrw.lua PASSED ===")
