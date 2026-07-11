local M = {}

local utils = require("fzf-lua-file-browser.utils")
local finder = require("fzf-lua-file-browser.finder")
local actions = require("fzf-lua-file-browser.actions")
local previewer = require("fzf-lua-file-browser.previewer")

---Get default actions table for fzf-lua picker
---@param custom_actions table?
---@return table
local function wrap_action(fn)
  if type(fn) == "function" then
    return { fn = fn, noclose = true, reuse = true }
  elseif type(fn) == "table" and fn.fn then
    fn.noclose = true
    fn.reuse = true
    return fn
  end
  return fn
end

local function normalize_key(k)
  if type(k) ~= "string" then return k end
  local s = k:lower()
  s = s:gsub("^<c%-(.)>$", "ctrl-%1")
  s = s:gsub("^<a%-(.)>$", "alt-%1")
  s = s:gsub("^<m%-(.)>$", "alt-%1")
  s = s:gsub("^<bs>$", "bspace")
  s = s:gsub("^<cr>$", "default")
  s = s:gsub("^<esc>$", "esc")
  return s
end

local function resolve_action_val(v)
  if type(v) == "string" and actions[v] then
    return actions[v]
  end
  return v
end

---Get default actions table for fzf-lua picker
---@param custom_actions table?
---@param opts table?
---@return table
local function get_actions(custom_actions, opts)
  opts = opts or {}
  local defaults = {
    ["default"]     = actions.enter,
    ["right"]       = actions.enter,
    ["left"]        = wrap_action(actions.goto_parent_dir),
    ["ctrl-a"]      = actions.create,
    ["alt-c"]       = actions.create,
    ["alt-enter"]   = actions.create_from_prompt,
    ["ctrl-n"]      = actions.create_from_prompt,
    ["ctrl-r"]      = actions.rename,
    ["alt-r"]       = actions.rename,
    ["ctrl-y"]      = actions.copy,
    ["alt-y"]       = actions.copy,
    ["ctrl-j"]      = actions.move,
    ["alt-m"]       = actions.move,
    ["ctrl-x"]      = actions.remove,
    ["alt-d"]       = actions.remove,
    ["ctrl-w"]      = wrap_action(actions.change_cwd),
    ["ctrl-b"]      = wrap_action(actions.goto_cwd),
    ["ctrl-e"]      = wrap_action(actions.goto_home_dir),
    ["ctrl-h"]      = wrap_action(actions.toggle_hidden),
    ["ctrl-i"]      = wrap_action(actions.toggle_gitignore),
    ["ctrl-l"]      = wrap_action(actions.toggle_depth),
    ["ctrl-g"]      = wrap_action(actions.toggle_grouping),
    ["ctrl-s"]      = wrap_action(actions.toggle_all),
    ["ctrl-o"]      = actions.open,
    ["ctrl-k"]      = wrap_action(actions.keymaps_help),
  }

  local normalized = {}

  -- Support Telescope style mappings table (e.g., mappings = { i = { ["<C-a>"] = "create" } })
  if type(opts.mappings) == "table" then
    for k, v in pairs(opts.mappings) do
      if type(v) == "table" then
        for subk, subv in pairs(v) do
          normalized[normalize_key(subk)] = resolve_action_val(subv)
        end
      else
        normalized[normalize_key(k)] = resolve_action_val(v)
      end
    end
  end

  -- Support keymap / keymaps
  local km = opts.keymaps or opts.keymap
  if type(km) == "table" then
    for k, v in pairs(km) do
      if k ~= "fzf" and k ~= "builtin" then
        normalized[normalize_key(k)] = resolve_action_val(v)
      end
    end
  end

  if type(custom_actions) == "table" then
    for k, v in pairs(custom_actions) do
      normalized[normalize_key(k)] = resolve_action_val(v)
    end
  end

  return vim.tbl_deep_extend("force", defaults, normalized)
end

---Format prompt string
---@param cwd string
---@return string
local function format_prompt(cwd)
  local display = vim.fn.fnamemodify(cwd, ":~")
  if #display > 35 then
    display = "..." .. display:sub(-32)
  end
  return string.format("File Browser (%s)> ", display)
end

---Run file browser picker
---@param opts table?
function M.browse(opts)
  local fzf_ok, fzf = pcall(require, "fzf-lua")
  if not fzf_ok then
    vim.notify("fzf-lua is required for fzf-lua-file-browser.nvim", vim.log.levels.ERROR)
    return
  end

  local global_config = package.loaded["fzf-lua-file-browser"] and package.loaded["fzf-lua-file-browser"].config or {}
  opts = vim.tbl_deep_extend("force", vim.deepcopy(global_config), opts or {})
  if not opts.__browse_opts then
    local pristine = vim.deepcopy(opts)
    pristine.__browse_opts = nil
    pristine.actions = nil
    pristine.fzf_opts = nil
    pristine.previewer = nil
    pristine.keymap = nil
    pristine.cmd = nil
    opts.__browse_opts = pristine
  end

  local default_cwd = vim.fn.getcwd()
  if vim.fn.expand("%:p") ~= "" then
    local buf_dir = vim.fn.expand("%:p:h")
    if vim.fn.isdirectory(buf_dir) == 1 then
      default_cwd = buf_dir
    end
  end
  opts.cwd = utils.normalize_path(opts.cwd or default_cwd)
  opts.prompt = opts.prompt or "File Browser> "

  local rel_cwd = vim.fn.fnamemodify(opts.cwd, ":~")
  opts.fzf_opts = vim.tbl_deep_extend("force", {
    ["--header"] = string.format("   CWD: %s ", rel_cwd),
  }, opts.fzf_opts or {})

  opts.actions = get_actions(opts.actions, opts)
  if not opts.previewer or opts.previewer == previewer.Previewer then
    opts.previewer = {
      _ctor = function()
        return previewer.Previewer
      end,
    }
  end
  opts.winopts = vim.tbl_deep_extend("force", {
    title = string.format(" File Browser [%s] ", rel_cwd),
    title_pos = "center",
  }, opts.winopts or {})

  opts.keymap = vim.tbl_deep_extend("force", {
    fzf = {
      ["ctrl-d"]     = "preview-page-down",
      ["ctrl-u"]     = "preview-page-up",
      ["shift-down"] = "preview-page-down",
      ["shift-up"]   = "preview-page-up",
      ["alt-J"]      = "preview-down",
      ["alt-K"]      = "preview-up",
      ["ctrl-f"]     = "page-down",
      ["alt-f"]      = "page-down",
      ["alt-b"]      = "page-up",
      ["page-down"]  = "page-down",
      ["page-up"]    = "page-up",
    },
    builtin = {
      ["<C-d>"]      = "preview-page-down",
      ["<C-u>"]      = "preview-page-up",
      ["<S-Down>"]   = "preview-page-down",
      ["<S-Up>"]     = "preview-page-up",
      ["<M-J>"]      = "preview-down",
      ["<M-K>"]      = "preview-up",
      ["<C-f>"]      = "page-down",
      ["<M-f>"]      = "page-down",
      ["<M-b>"]      = "page-up",
      ["<PageDown>"] = "page-down",
      ["<PageUp>"]   = "page-up",
    },
  }, opts.keymap or {})

  -- Explicitly strip any bspace / <BS> action or keymap overrides passed from user/global configs
  -- and ensure is_live is unset so character additions and removals never re-render the UI
  opts.is_live = nil
  if type(opts.actions) == "table" then
    opts.actions["bspace"] = nil
    opts.actions["_bspace"] = nil
    opts.actions["<bs>"] = nil
    opts.actions["<BS>"] = nil
  end
  if type(opts.keymap) == "table" then
    if type(opts.keymap.fzf) == "table" then
      opts.keymap.fzf["bspace"] = nil
      opts.keymap.fzf["<bs>"] = nil
      opts.keymap.fzf["<BS>"] = nil
    end
    if type(opts.keymap.builtin) == "table" then
      opts.keymap.builtin["bspace"] = nil
      opts.keymap.builtin["<bs>"] = nil
      opts.keymap.builtin["<BS>"] = nil
    end
  end

  -- Configure fzf-lua entry transformation for fast asynchronous external command output matching fzf-lua files
  opts._type = "file"
  opts.file_icons = opts.file_icons ~= false
  opts.color_icons = opts.color_icons ~= false
  opts.strip_cwd_prefix = true

  local cmd = finder.get_cmd(opts)
  return fzf.fzf_exec(cmd, opts)
end

M.get_actions = get_actions

return M
