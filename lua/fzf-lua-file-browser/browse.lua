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

-- Actions that re-render the browser in place. They must run with noclose+reuse, whether
-- they come from the defaults or from user config: otherwise fzf-lua tears the window down
-- and rebuilds it on every step (visible flicker, leaked preview buffers).
local INPLACE = {
  [actions.enter] = true,
  [actions.file_split] = true,
  [actions.file_vsplit] = true,
  [actions.file_tabedit] = true,
  [actions.goto_parent_dir] = true,
  [actions.goto_home_dir] = true,
  [actions.goto_cwd] = true,
  [actions.change_cwd] = true,
  [actions.toggle_hidden] = true,
  [actions.toggle_gitignore] = true,
  [actions.toggle_depth] = true,
  [actions.toggle_grouping] = true,
  [actions.toggle_all] = true,
  [actions.toggle_browser] = true,
  [actions.keymaps_help] = true,
  [actions.backspace] = true,
}

local function resolve_action_val(v)
  if type(v) == "string" and actions[v] then
    v = actions[v]
  end
  if type(v) == "function" and INPLACE[v] then
    return wrap_action(v)
  end
  return v
end

---fzf >= 0.59 is needed for `trigger()` (empty-query backspace => parent dir)
local fzf_has_trigger
local function has_fzf_trigger()
  if fzf_has_trigger == nil then
    fzf_has_trigger = false
    local ok, out = pcall(vim.fn.system, { "fzf", "--version" })
    local maj, min = (ok and out or ""):match("^(%d+)%.(%d+)")
    if maj then
      maj, min = tonumber(maj), tonumber(min)
      fzf_has_trigger = maj > 0 or min >= 59
    end
  end
  return fzf_has_trigger
end

---Get default actions table for fzf-lua picker
---@param custom_actions table?
---@param opts table?
---@return table
local function get_actions(custom_actions, opts)
  opts = opts or {}
  local defaults = {
    ["default"]     = wrap_action(actions.enter),
    ["right"]       = wrap_action(actions.enter),
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
    ["ctrl-x"]      = wrap_action(actions.file_split),
    ["ctrl-v"]      = wrap_action(actions.file_vsplit),
    ["ctrl-t"]      = wrap_action(actions.file_tabedit),
    ["alt-d"]       = actions.remove,
    ["ctrl-w"]      = wrap_action(actions.change_cwd),
    ["ctrl-b"]      = wrap_action(actions.goto_cwd),
    ["ctrl-e"]      = wrap_action(actions.goto_home_dir),
    ["ctrl-h"]      = wrap_action(actions.toggle_hidden),
    -- not ctrl-i: terminals send ctrl-i as Tab, which would kill multi-select toggling
    ["alt-i"]       = wrap_action(actions.toggle_gitignore),
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

  -- shallow: a user's `{ fn = f }` must replace a wrapped default, not inherit its noclose/reuse
  return vim.tbl_extend("force", defaults, normalized)
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
    -- keep per-call actions so they survive reopen (toggles, navigation); the resolved
    -- `actions` table itself holds wrapped functions and is rebuilt every time
    pristine.__user_actions = vim.tbl_extend("force", opts.__user_actions or {}, opts.actions or {})
    pristine.actions = nil
    pristine.fzf_opts = nil
    pristine.previewer = nil
    pristine.keymap = nil
    pristine.cmd = nil
    opts.__browse_opts = pristine
  end

  local default_cwd = vim.fn.getcwd()
  if not opts.cwd and not opts.root_cwd and not opts.path and vim.fn.expand("%:p") ~= "" then
    local buf_dir = vim.fn.expand("%:p:h")
    if vim.fn.isdirectory(buf_dir) == 1 then
      default_cwd = buf_dir
    end
  end

  -- Always work with an absolute, existing directory: relative/"~" paths break parent
  -- navigation and make create/move resolve against :pwd, and fzf-lua silently falls back
  -- to :pwd for a bad cwd while header/actions would keep the bogus one.
  local raw_session = opts.root_cwd or opts._root_cwd or opts.cwd
  if type(raw_session) ~= "string" or raw_session == "" or raw_session:match("^%a[%w+.-]+://") then
    raw_session = vim.fn.getcwd()
  end
  local session_cwd = utils.absolute(raw_session)
  if not utils.is_dir(session_cwd) then
    session_cwd = utils.normalize_path(vim.fn.getcwd())
  end

  local raw_browse = opts.path or opts.cwd
  if type(raw_browse) ~= "string" or raw_browse == "" or raw_browse:match("^%a[%w+.-]+://") then
    raw_browse = default_cwd
  end
  local browse_path = utils.absolute(raw_browse)
  if not utils.is_dir(browse_path) then
    vim.notify("fzf-lua-file-browser: not a directory: " .. browse_path, vim.log.levels.WARN)
    browse_path = session_cwd
  end

  opts.root_cwd = session_cwd
  opts._root_cwd = session_cwd
  opts.path = browse_path
  opts.cwd = browse_path

  local rel_path = utils.relative_path(browse_path, session_cwd)
  opts.prompt = rel_path .. "> "

  local display_cwd = vim.fn.fnamemodify(session_cwd, ":~")
  opts.fzf_opts = vim.tbl_deep_extend("force", {
    ["--header"] = string.format("   CWD: %s  │  Folder: %s ", display_cwd, rel_path),
    -- batch rename/copy/move/remove all rely on Tab multi-select
    ["--multi"] = true,
  }, opts.fzf_opts or {})

  local base_user_actions = opts.__browse_opts and opts.__browse_opts.__user_actions or opts.__user_actions or {}
  opts.actions = get_actions(vim.tbl_extend("force", opts.actions or {}, base_user_actions), opts)
  if not opts.previewer or opts.previewer == previewer.Previewer then
    opts.previewer = {
      _ctor = function()
        return previewer.Previewer
      end,
    }
  end
  opts.winopts = vim.tbl_deep_extend("force", {
    title = string.format(" File Browser [%s] ", rel_path),
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
  opts.keymap = opts.keymap or {}
  opts.keymap.fzf = opts.keymap.fzf or {}
  opts.keymap.builtin = opts.keymap.builtin or {}
  opts.keymap.fzf["bspace"] = nil
  opts.keymap.fzf["<bs>"] = nil
  opts.keymap.fzf["<BS>"] = nil
  opts.keymap.builtin["bspace"] = nil
  opts.keymap.builtin["<bs>"] = nil
  opts.keymap.builtin["<BS>"] = nil

  if type(opts.actions) == "table" then
    for k, _ in pairs(opts.actions) do
      if k ~= "default" and k ~= "right" and k ~= "left" then
        if opts.keymap.fzf[k] == nil then
          opts.keymap.fzf[k] = false
        end
        if opts.keymap.builtin[k] == nil then
          opts.keymap.builtin[k] = false
        end
      end
    end
  end

  -- Backspace: delete a char while the prompt has text, go to the parent dir when it is empty.
  -- Done inside fzf (transform + trigger) so typing never re-renders the picker; `left` is
  -- the parent-dir key. Skipped if the user unbound `left` or fzf is too old for trigger().
  -- The transform is sh syntax, so not on Windows (fzf runs it through cmd.exe there).
  if opts.actions and opts.actions["left"] and not utils.__IS_WINDOWS and has_fzf_trigger() then
    opts.keymap.fzf["bspace"] = [[transform:[ -n "$FZF_QUERY" ] && echo backward-delete-char || echo "trigger(left)"]]
  end

  -- Configure fzf-lua entry transformation for fast asynchronous external command output matching fzf-lua files
  opts._type = "file"
  -- leave fzf-lua's own defaults alone: forcing `true` makes it warn on every open when
  -- nvim-web-devicons isn't installed (its default `1` silently falls back)
  if opts.file_icons == nil then
    opts.file_icons = 1
  end
  if opts.color_icons == nil then
    opts.color_icons = true
  end
  opts.strip_cwd_prefix = true

  -- Opt out of fzf-lua's "hide" profile: it turns every closing action into hide-then-run,
  -- and when a sub-picker (create/rename/confirm) then replaces the hidden browser, fzf-lua
  -- drops its preview buffers without deleting them. Trade-off: Esc closes rather than hides.
  if opts.no_hide == nil then
    opts.no_hide = true
  end

  local cmd = finder.get_cmd(opts)
  return fzf.fzf_exec(cmd, opts)
end

M.get_actions = get_actions

return M
