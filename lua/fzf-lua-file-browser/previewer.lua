local M = {}

local builtin = require("fzf-lua.previewer.builtin")
local utils = require("fzf-lua-file-browser.utils")

local Previewer = builtin.buffer_or_file:extend()

function Previewer:new(o, opts, fzf_win)
  local obj = self
  if obj == Previewer then
    obj = setmetatable({}, Previewer)
  end
  o = vim.tbl_deep_extend("force", {
    syntax = true,
    syntax_limit_l = 0,
    syntax_limit_b = 1024 * 1024 * 10,
    treesitter = { enabled = true },
  }, o or {})
  Previewer.super.new(obj, o, opts, fzf_win)
  obj.opts = opts or {}
  return obj
end

function Previewer:entry_to_file(entry_str)
  local cwd = self.opts.path or self.opts.cwd or vim.fn.getcwd()
  local parsed = utils.parse_entry(entry_str, cwd, self.opts)
  return {
    path = parsed.path,
  }
end

function Previewer:parse_entry(entry_str, _cb)
  local cwd = self.opts.path or self.opts.cwd or vim.fn.getcwd()
  local parsed = utils.parse_entry(entry_str, cwd, self.opts)

  local entry = Previewer.super.parse_entry(self, entry_str, _cb)
  entry.path = parsed.path

  local stat = vim.uv and vim.uv.fs_stat(parsed.path)
  if parsed.is_dir or (stat and stat.type == "directory") then
    -- Prefer richer directory listing tools if available
    -- trailing "/" so a symlinked dir previews its contents, not the link itself
    local dir = parsed.path == "/" and "/" or (parsed.path .. "/")
    if vim.fn.executable("eza") == 1 then
      entry.cmd = { "eza", "--icons", "-a", "-l", "--color=always", dir }
    elseif vim.fn.executable("lsd") == 1 then
      entry.cmd = { "lsd", "-a", "-l", "--color=always", dir }
    elseif vim.fn.executable("tree") == 1 then
      entry.cmd = { "tree", "-C", "-L", "2", dir }
    elseif vim.fn.has("mac") == 1 or vim.fn.has("bsd") == 1 then
      -- BSD ls: -G is colour
      entry.cmd = { "sh", "-c", "CLICOLOR_FORCE=1 ls -laG " .. vim.fn.shellescape(dir) }
    else
      -- GNU ls: -G means --no-group, colour is --color
      entry.cmd = { "ls", "-la", "--color=always", dir }
    end
  end

  return entry
end

-- Directory previews run an external job into a fresh temp buffer. If the picker closes before
-- the first output arrives (common here: every navigation reopens the picker), fzf-lua never
-- attaches that buffer to the preview window and never deletes it. Track and reap them.
function Previewer:get_tmp_buffer()
  local b = Previewer.super.get_tmp_buffer(self)
  self._fb_tmpbufs = self._fb_tmpbufs or {}
  self._fb_tmpbufs[b] = true
  return b
end

function Previewer:close(do_not_clear_cache)
  if self._stop_preview_job then
    pcall(self._stop_preview_job, self)
  end
  Previewer.super.close(self, do_not_clear_cache)
  if do_not_clear_cache then
    return
  end
  for b in pairs(self._fb_tmpbufs or {}) do
    if vim.api.nvim_buf_is_valid(b) and #vim.fn.win_findbuf(b) == 0 then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  self._fb_tmpbufs = {}
end

M.Previewer = Previewer

return M
