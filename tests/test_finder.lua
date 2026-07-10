local finder = require("fzf-lua-file-browser.finder")
local utils = require("fzf-lua-file-browser.utils")

local function assert_true(cond, msg)
  if not cond then
    error("ASSERT FAILED: " .. (msg or ""))
  end
end

print("=== Running test_finder.lua ===")

local tmpdir = vim.fn.tempname()
vim.fn.mkdir(tmpdir, "p")
utils.create_path(utils.join_paths(tmpdir, "b_folder/"), true)
utils.create_path(utils.join_paths(tmpdir, "a_folder/"), true)
utils.create_path(utils.join_paths(tmpdir, "z_file.txt"), false)
utils.create_path(utils.join_paths(tmpdir, "a_file.txt"), false)
utils.create_path(utils.join_paths(tmpdir, "b_folder/nested.txt"), false)

-- Test flat scan (depth = 1)
local results = {}
local done = false
finder.get_contents({ cwd = tmpdir, depth = 1 })(function(entry)
  if entry == nil then done = true else table.insert(results, entry) end
end)
vim.wait(1000, function() return done end, 10)
assert_true(#results >= 5, "flat scan should collect immediate items")

-- Test recursive scan (depth = false)
local rec_results = {}
local rec_done = false
finder.get_contents({ cwd = tmpdir, depth = false })(function(entry)
  if entry == nil then rec_done = true else table.insert(rec_results, entry) end
end)
vim.wait(1000, function() return rec_done end, 10)

local found_nested = false
for _, res in ipairs(rec_results) do
  if res:find("b_folder/nested%.txt") then
    found_nested = true
    break
  end
end
assert_true(found_nested, "recursive scan (depth = false) should find nested file b_folder/nested.txt")

-- Test previewer entry_to_file path extraction
local previewer = require("fzf-lua-file-browser.previewer")
local prev_obj = previewer.Previewer:new({}, { cwd = tmpdir })
local sample_entry = "  test.json"
local extracted = prev_obj:entry_to_file(sample_entry)
assert_true(extracted.path == utils.normalize_path(utils.join_paths(tmpdir, "test.json")), "previewer entry_to_file should extract clean path from formatted entry")

vim.fn.delete(tmpdir, "rf")

print("=== ALL test_finder.lua PASSED ===")
