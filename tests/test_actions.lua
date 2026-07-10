local actions = require("fzf-lua-file-browser.actions")
local utils = require("fzf-lua-file-browser.utils")

local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("ASSERT FAILED [%s]: expected %s, got %s", msg or "", vim.inspect(expected), vim.inspect(actual)))
  end
end

print("=== Running test_actions.lua ===")

-- Mock browse reopen call to capture updated opts
local last_browse_opts = nil
package.loaded["fzf-lua-file-browser"] = {
  browse = function(opts)
    last_browse_opts = opts
  end,
}

local cwd = "/workspace/project/src"

-- Test toggle_hidden
local opts1 = { cwd = cwd, hidden = false }
actions.toggle_hidden({}, opts1)
assert_eq(true, opts1.hidden, "toggle_hidden turned on")

-- Test toggle_browser
local opts2 = { cwd = cwd, dirs_only = false }
actions.toggle_browser({}, opts2)
assert_eq(true, opts2.dirs_only, "toggle_browser turned on")

-- Test toggle_gitignore
local opts3 = { cwd = cwd, gitignore = true }
actions.toggle_gitignore({}, opts3)
assert_eq(false, opts3.gitignore, "toggle_gitignore toggled")

-- Test toggle_depth
local opts4 = { cwd = cwd, depth = 1 }
actions.toggle_depth({}, opts4)
assert_eq(false, opts4.depth, "toggle_depth toggled to recursive")

-- Test toggle_grouping
local opts5 = { cwd = cwd, grouped = true }
actions.toggle_grouping({}, opts5)
assert_eq(false, opts5.grouped, "toggle_grouping toggled to mixed")

-- Test backspace when query is empty -> should trigger goto_parent_dir
actions.backspace({ "  ../" }, { cwd = cwd, last_query = "" })
vim.wait(100, function() return last_browse_opts ~= nil end, 10)
assert_eq("/workspace/project", last_browse_opts and last_browse_opts.cwd, "backspace went to parent dir")

-- Test nested directory creation via utils.create_path
local tmp_nest = vim.fn.tempname()
local nested_target = utils.join_paths(tmp_nest, "custom_folder/subfolder/newfile.txt")
local ok_nest, err_nest = utils.create_path(nested_target, false)
assert_eq(true, ok_nest, "nested directory creation succeeded")
assert_eq(true, utils.path_exists(nested_target), "newfile.txt exists in created nested directory")
vim.fn.delete(tmp_nest, "rf")

-- Test keymaps_help action exists and runs
assert_eq("function", type(actions.keymaps_help), "keymaps_help action exists")

print("=== ALL test_actions.lua PASSED ===")
