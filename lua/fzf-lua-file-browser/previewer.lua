local M = {}

local builtin = require("fzf-lua.previewer.builtin")
local utils = require("fzf-lua-file-browser.utils")

local Previewer = builtin.buffer_or_file:extend()

function Previewer:new(o, opts, fzf_win)
  local obj = self
  if obj == Previewer then
    obj = setmetatable({}, Previewer)
  end
  Previewer.super.new(obj, o, opts, fzf_win)
  obj.opts = opts or {}
  return obj
end

function Previewer:parse_entry(entry_str, _cb)
  local cwd = self.opts.cwd or vim.fn.getcwd()
  local parsed = utils.parse_entry(entry_str, cwd)

  local entry = Previewer.super.parse_entry(self, entry_str, _cb)
  entry.path = parsed.path

  local stat = vim.uv and vim.uv.fs_stat(parsed.path)
  if parsed.is_dir or (stat and stat.type == "directory") then
    -- Prefer richer directory listing tools if available
    if vim.fn.executable("eza") == 1 then
      entry.cmd = { "eza", "--icons", "-a", "-l", "--color=always", parsed.path }
    elseif vim.fn.executable("lsd") == 1 then
      entry.cmd = { "lsd", "-a", "-l", "--color=always", parsed.path }
    elseif vim.fn.executable("tree") == 1 then
      entry.cmd = { "tree", "-C", "-L", "2", parsed.path }
    else
      entry.cmd = { "sh", "-c", "CLICOLOR_FORCE=1 ls -laG " .. vim.fn.shellescape(parsed.path) }
    end
  end

  return entry
end

M.Previewer = Previewer

return M
