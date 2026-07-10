local utils = require("fzf-lua-file-browser.utils")

local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("ASSERT FAILED [%s]: expected %s, got %s", msg or "", vim.inspect(expected), vim.inspect(actual)))
  end
end

print("=== Running test_utils.lua ===")

-- Test normalize_path
assert_eq("foo/bar", utils.normalize_path("foo//bar/"), "normalize_path trailing slash")
assert_eq("/", utils.normalize_path("/"), "normalize_path root")

-- Test join_paths
assert_eq("/tmp/test/dir", utils.join_paths("/tmp", "test/", "/dir/"), "join_paths")

-- Test parse_entry
local cwd = "/workspace"
local p1 = utils.parse_entry("  ../", cwd)
assert_eq(true, p1.is_dir, "parse_entry ../ is_dir")
assert_eq(true, p1.is_parent, "parse_entry ../ is_parent")
assert_eq("..", p1.relpath, "parse_entry ../ relpath")

local p2 = utils.parse_entry("  src/", cwd)
assert_eq(true, p2.is_dir, "parse_entry src/ is_dir")
assert_eq("src/", p2.relpath, "parse_entry src/ relpath")
assert_eq("/workspace/src", p2.path, "parse_entry src/ path")

local p3 = utils.parse_entry("  init.lua", cwd)
assert_eq(false, p3.is_dir, "parse_entry init.lua is_dir")
assert_eq("init.lua", p3.relpath, "parse_entry init.lua relpath")
assert_eq("/workspace/init.lua", p3.path, "parse_entry init.lua path")

-- Test file system operations in temp directory
local tmpdir = vim.fn.tempname()
vim.fn.mkdir(tmpdir, "p")

local ok, err = utils.create_path(utils.join_paths(tmpdir, "nested/dir/file.txt"), false)
assert_eq(true, ok, "create_path nested file")
assert_eq(true, vim.fn.filereadable(utils.join_paths(tmpdir, "nested/dir/file.txt")) == 1, "nested file readable")

ok, err = utils.create_path(utils.join_paths(tmpdir, "folder/subfolder/"), true)
assert_eq(true, ok, "create_path nested folder")
assert_eq(true, vim.fn.isdirectory(utils.join_paths(tmpdir, "folder/subfolder")) == 1, "nested folder directory")

ok, err = utils.rename_path(utils.join_paths(tmpdir, "nested/dir/file.txt"), utils.join_paths(tmpdir, "nested/dir/renamed.txt"))
assert_eq(true, ok, "rename_path")
assert_eq(true, vim.fn.filereadable(utils.join_paths(tmpdir, "nested/dir/renamed.txt")) == 1, "renamed file readable")

ok, err = utils.copy_path(utils.join_paths(tmpdir, "nested/dir/renamed.txt"), utils.join_paths(tmpdir, "nested/dir/copy.txt"))
assert_eq(true, ok, "copy_path")
assert_eq(true, vim.fn.filereadable(utils.join_paths(tmpdir, "nested/dir/copy.txt")) == 1, "copy file readable")

ok, err = utils.delete_path(utils.join_paths(tmpdir, "nested"))
assert_eq(true, ok, "delete_path folder")
assert_eq(true, vim.fn.isdirectory(utils.join_paths(tmpdir, "nested")) == 0, "nested folder deleted")

vim.fn.delete(tmpdir, "rf")

print("=== ALL test_utils.lua PASSED ===")
