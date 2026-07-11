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
local cmd_flat = finder.get_cmd({ cwd = tmpdir, depth = 1 })
assert_true(type(cmd_flat) == "string" and #cmd_flat > 0, "finder.get_cmd should return a non-empty shell command string")
local output_flat = vim.fn.system(string.format("cd %s && %s", vim.fn.shellescape(tmpdir), cmd_flat))
local lines_flat = vim.split(vim.trim(output_flat), "\n", { trimempty = true })
assert_true(#lines_flat >= 5, "flat scan command should output immediate items including parent dir")

-- Test recursive scan (depth = false)
local cmd_rec = finder.get_cmd({ cwd = tmpdir, depth = false })
assert_true(type(cmd_rec) == "string" and not cmd_rec:find("max%-depth") and not cmd_rec:find("maxdepth"), "recursive scan command should not have depth limit flags")
local output_rec = vim.fn.system(string.format("cd %s && %s", vim.fn.shellescape(tmpdir), cmd_rec))

local found_nested = false
for _, res in ipairs(vim.split(output_rec, "\n")) do
  if res:find("b_folder/nested%.txt") or res:find("b_folder\\nested%.txt") then
    found_nested = true
    break
  end
end
assert_true(found_nested, "recursive scan (depth = false) should find nested file b_folder/nested.txt")

-- Verify get_contents returns same command string
assert_true(finder.get_contents({ cwd = tmpdir, depth = 1 }) == cmd_flat, "get_contents should return the command string")

-- Test previewer entry_to_file path extraction
local previewer = require("fzf-lua-file-browser.previewer")
local prev_obj = previewer.Previewer:new({}, { cwd = tmpdir })
local sample_entry = "  test.json"
local extracted = prev_obj:entry_to_file(sample_entry)
assert_true(extracted.path == utils.normalize_path(utils.join_paths(tmpdir, "test.json")), "previewer entry_to_file should extract clean path from formatted entry")

vim.fn.delete(tmpdir, "rf")

print("=== ALL test_finder.lua PASSED ===")
