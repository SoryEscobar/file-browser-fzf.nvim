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

-- Test parse_entry with entries exactly as fzf-lua emits them: plain "name" when icons are
-- off, "<ansi icon><fzf-lua nbsp>name" when on (nbsp is U+2002, not U+00A0)
local NBSP = require("fzf-lua.utils").nbsp
local function icon(name)
  return "\27[38;5;74m\238\152\160\27[0m" .. NBSP .. name
end
local cwd = "/workspace"
local p1 = utils.parse_entry("../", cwd)
assert_eq(true, p1.is_dir, "parse_entry ../ is_dir")
assert_eq(true, p1.is_parent, "parse_entry ../ is_parent")
assert_eq("..", p1.relpath, "parse_entry ../ relpath")

local p2 = utils.parse_entry(icon("src/"), cwd)
assert_eq(true, p2.is_dir, "parse_entry src/ is_dir")
assert_eq("src/", p2.relpath, "parse_entry src/ relpath")
assert_eq("/workspace/src", p2.path, "parse_entry src/ path")

local p3 = utils.parse_entry(icon("init.lua"), cwd)
assert_eq(false, p3.is_dir, "parse_entry init.lua is_dir")
assert_eq("init.lua", p3.relpath, "parse_entry init.lua relpath")
assert_eq("/workspace/init.lua", p3.path, "parse_entry init.lua path")

local p4 = utils.parse_entry("my file.txt", cwd)
assert_eq("my file.txt", p4.relpath, "parse_entry keeps spaces without icons")
local p5 = utils.parse_entry(icon("dir with space/"), cwd)
assert_eq("/workspace/dir with space", p5.path, "parse_entry keeps spaces with icons")
local p6 = utils.parse_entry("voil\195\160.txt", cwd)
assert_eq("voil\195\160.txt", p6.relpath, "parse_entry keeps UTF-8 names containing byte 0xA0")
assert_eq(true, utils.parse_entry(icon("../"), cwd).is_parent, "parse_entry ../ with icon")

-- Relative / "~" paths are made absolute so parent navigation can't get stuck
assert_eq(utils.parent_dir(vim.fn.getcwd()), utils.parent_dir("."), "parent_dir of relative path")
assert_eq(vim.fn.expand("~") .. "/x", utils.absolute("~/x"), "absolute expands ~")
assert_eq("/base/sub", utils.absolute("sub", "/base"), "absolute resolves against base")
assert_eq("/abs", utils.absolute("/abs", "/base"), "absolute keeps absolute paths")

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

-- Test relative_path formatting for prompt display
assert_eq("./", utils.relative_path("/workspace", "/workspace"), "relative_path same directory")
assert_eq("src/components/", utils.relative_path("/workspace/src/components", "/workspace"), "relative_path subdirectory")

-- Test get_root_cwd and get_browse_path separation
local test_opts = { root_cwd = "/workspace", path = "/workspace/src/components", cwd = "/workspace/src/components" }
assert_eq("/workspace", utils.get_root_cwd(test_opts), "get_root_cwd returns session root")
assert_eq("/workspace/src/components", utils.get_browse_path(test_opts), "get_browse_path returns browsed folder")

-- Test strip_icon_prefix and parse_entry handling EN SPACE (U+2002 \226\128\130) separator from fzf-lua
assert_eq("Applications/", utils.strip_icon_prefix("\226\128\130Applications/"), "strip_icon_prefix strips EN SPACE icon separator")
local parsed_enspace = utils.parse_entry("\226\128\130Applications/", "/Users/soryescobar")
assert_eq("/Users/soryescobar/Applications", parsed_enspace.path, "parse_entry handles EN SPACE icon separator correctly")

vim.fn.delete(tmpdir, "rf")

print("=== ALL test_utils.lua PASSED ===")
