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
    ["bspace"]      = wrap_action(actions.backspace_or_parent),
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
      normalized[normalize_key(k)] = resolve_action_val(v)
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

  -- Use fzf-lua core executor
  return fzf.fzf_exec(finder.get_contents(opts), opts)
end

return M
