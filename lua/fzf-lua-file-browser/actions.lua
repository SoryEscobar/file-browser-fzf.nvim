local M = {}

local utils = require("fzf-lua-file-browser.utils")

---Get prompt query string safely
---@param opts table
---@return string
local function get_query(opts)
  local fzf_ok, fzf = pcall(require, "fzf-lua")
  local q = (fzf_ok and fzf.get_last_query and fzf.get_last_query()) or (opts and (opts.last_query or opts.__query)) or ""
  return vim.trim(q)
end

local function reopen(opts, overrides)
  opts = opts or {}
  overrides = overrides or {}
  local clean_opts = {
    cwd = overrides.cwd or opts.cwd,
    hidden = overrides.hidden ~= nil and overrides.hidden or opts.hidden,
    gitignore = overrides.gitignore ~= nil and overrides.gitignore or opts.gitignore,
    depth = overrides.depth ~= nil and overrides.depth or opts.depth,
    grouped = overrides.grouped ~= nil and overrides.grouped or opts.grouped,
    hijack_netrw = opts.hijack_netrw,
    actions = opts.actions,
    winopts = vim.tbl_deep_extend("force", { reuse = true }, overrides.winopts or {}),
  }
  vim.schedule(function()
    require("fzf-lua-file-browser").browse(clean_opts)
  end)
end

---Get list of parsed items from selected array
---@param selected string[]
---@param cwd string
---@return table[]
local function parse_selected(selected, cwd)
  local items = {}
  for _, sel in ipairs(selected or {}) do
    table.insert(items, utils.parse_entry(sel, cwd))
  end
  return items
end

---Enter action (<CR>): Navigate into directory or edit file
---@param selected string[]
---@param opts table
function M.enter(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  if not selected or #selected == 0 then return end

  local parsed = utils.parse_entry(selected[1], cwd)
  if parsed.is_dir then
    reopen(opts, { cwd = parsed.path })
  else
    vim.cmd("edit " .. vim.fn.fnameescape(parsed.path))
  end
end

---Go to parent directory
---@param _ string[]
---@param opts table
function M.goto_parent_dir(_, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local parent = utils.parent_dir(cwd)
  reopen(opts, { cwd = parent })
end

---Go to home directory (~)
---@param _ string[]
---@param opts table
function M.goto_home_dir(_, opts)
  local home = vim.fn.expand("~")
  reopen(opts, { cwd = home })
end

---Go to current working directory (vim.fn.getcwd())
---@param _ string[]
---@param opts table
function M.goto_cwd(_, opts)
  local cwd = vim.fn.getcwd()
  reopen(opts, { cwd = cwd })
end

---Change Neovim's working directory (:cd)
---@param selected string[]
---@param opts table
function M.change_cwd(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local target = cwd
  if selected and #selected > 0 then
    local parsed = utils.parse_entry(selected[1], cwd)
    target = parsed.is_dir and parsed.path or utils.parent_dir(parsed.path)
  end
  local ok, err = pcall(vim.cmd.cd, target)
  if ok then
    vim.notify("Changed Neovim working directory to: " .. target, vim.log.levels.INFO)
    reopen(opts, { cwd = target })
  else
    vim.notify("Failed to change working directory: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function get_dir_suggestions(cwd)
  local suggestions = { cwd .. "/", "../" }
  local uv = vim.uv or vim.loop
  local handle = uv.fs_scandir(cwd)
  if handle then
    while true do
      local name, ftype = uv.fs_scandir_next(handle)
      if not name then break end
      if ftype == "directory" and name:sub(1, 1) ~= "." then
        table.insert(suggestions, utils.join_paths(cwd, name) .. "/")
      end
    end
  end
  return suggestions
end

---Create file/folder at current path
---@param _ string[]
---@param opts table
function M.create(_, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  utils.picker_input({
    prompt = "Create file/dir> ",
    default = "",
    items = { "new_file.lua", "new_folder/" },
  }, function(input)
    if not input or input == "" then return end
    local is_dir = input:sub(-1) == "/"
    local target = utils.normalize_path(utils.join_paths(cwd, input))
    local ok, err = utils.create_path(target, is_dir)
    if not ok then
      vim.notify("Create failed: " .. tostring(err), vim.log.levels.ERROR)
    else
      vim.notify("Created: " .. input, vim.log.levels.INFO)
    end
    reopen(opts)
  end)
end

---Create file/folder from prompt text (<S-CR>)
---@param _ string[]
---@param opts table
function M.create_from_prompt(_, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local query = get_query(opts)
  if not query or query == "" then
    vim.notify("Prompt is empty. Type filename in prompt first.", vim.log.levels.WARN)
    return
  end
  local is_dir = query:sub(-1) == "/"
  local target = utils.normalize_path(utils.join_paths(cwd, query))
  local ok, err = utils.create_path(target, is_dir)
  if not ok then
    vim.notify("Create failed: " .. tostring(err), vim.log.levels.ERROR)
  else
    vim.notify("Created: " .. query, vim.log.levels.INFO)
  end
  reopen(opts)
end

---Rename selected file(s) or directory(ies)
---@param selected string[]
---@param opts table
function M.rename(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local items = parse_selected(selected, cwd)
  if #items == 0 then return end

  local function rename_next(i)
    if i > #items then
      reopen(opts)
      return
    end
    local item = items[i]
    if item.is_parent then
      rename_next(i + 1)
      return
    end
    utils.picker_input({
      prompt = "Rename " .. item.relpath .. " -> ",
      default = item.relpath,
      items = { item.relpath },
    }, function(new_name)
      if new_name and new_name ~= "" and new_name ~= item.relpath then
        local new_path = utils.normalize_path(utils.join_paths(cwd, new_name))
        local ok, err = utils.rename_path(item.path, new_path)
        if not ok then
          vim.notify("Rename failed: " .. tostring(err), vim.log.levels.ERROR)
        else
          vim.notify("Renamed to: " .. new_name, vim.log.levels.INFO)
        end
      end
      rename_next(i + 1)
    end)
  end

  rename_next(1)
end

---Move selected item(s) to destination directory
---@param selected string[]
---@param opts table
function M.move(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local items = parse_selected(selected, cwd)
  if #items == 0 then return end

  utils.picker_input({
    prompt = string.format("Move %d item(s) to dir> ", #items),
    default = cwd .. "/",
    items = get_dir_suggestions(cwd),
  }, function(dest_dir)
    if not dest_dir or dest_dir == "" then
      reopen(opts)
      return
    end
    local dest = utils.normalize_path(dest_dir)
    utils.ensure_dir(dest)

    for _, item in ipairs(items) do
      if not item.is_parent then
        local name = vim.fn.fnamemodify(item.path, ":t")
        local new_path = utils.join_paths(dest, name)
        local ok, err = utils.rename_path(item.path, new_path)
        if not ok then
          vim.notify("Move failed for " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
    vim.notify(string.format("Moved %d item(s) to %s", #items, dest), vim.log.levels.INFO)
    reopen(opts)
  end)
end

---Copy selected item(s) to destination directory
---@param selected string[]
---@param opts table
function M.copy(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local items = parse_selected(selected, cwd)
  if #items == 0 then return end

  utils.picker_input({
    prompt = string.format("Copy %d item(s) to dir> ", #items),
    default = cwd .. "/",
    items = get_dir_suggestions(cwd),
  }, function(dest_dir)
    if not dest_dir or dest_dir == "" then
      reopen(opts)
      return
    end
    local dest = utils.normalize_path(dest_dir)
    utils.ensure_dir(dest)

    for _, item in ipairs(items) do
      if not item.is_parent then
        local name = vim.fn.fnamemodify(item.path, ":t")
        local new_path = utils.join_paths(dest, name)
        local ok, err = utils.copy_path(item.path, new_path)
        if not ok then
          vim.notify("Copy failed for " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
    vim.notify(string.format("Copied %d item(s) to %s", #items, dest), vim.log.levels.INFO)
    reopen(opts)
  end)
end

---Remove selected item(s)
---@param selected string[]
---@param opts table
function M.remove(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local items = parse_selected(selected, cwd)
  if #items == 0 then return end

  local prompt_msg = #items == 1
      and ("Delete " .. items[1].relpath .. "?")
      or (string.format("Delete %d selected item(s)?", #items))

  utils.confirm(prompt_msg, function()
    local count = 0
    for _, item in ipairs(items) do
      if not item.is_parent then
        local ok, err = utils.delete_path(item.path)
        if ok then
          count = count + 1
        else
          vim.notify("Delete failed: " .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
    if count > 0 then
      vim.notify(string.format("Deleted %d item(s)", count), vim.log.levels.INFO)
    end
    reopen(opts)
  end)
end

---Open file/folder with system default application
---@param selected string[]
---@param opts table
function M.open(selected, opts)
  local cwd = opts.cwd or vim.fn.getcwd()
  local items = parse_selected(selected, cwd)
  for _, item in ipairs(items) do
    if vim.ui.open then
      vim.ui.open(item.path)
    else
      local cmd = vim.fn.has("mac") == 1 and "open"
          or (vim.fn.has("win32") == 1 and "start" or "xdg-open")
      vim.fn.jobstart({ cmd, item.path }, { detach = true })
    end
  end
end

---Toggle showing hidden dotfiles
---@param _ string[]
---@param opts table
function M.toggle_hidden(_, opts)
  opts.hidden = not (opts.hidden or false)
  reopen(opts, { hidden = opts.hidden })
end

---Toggle gitignore filtering
---@param _ string[]
---@param opts table
function M.toggle_gitignore(_, opts)
  opts.gitignore = not (opts.gitignore ~= false)
  reopen(opts, { gitignore = opts.gitignore })
end

---Toggle depth between flat (1) and recursive (false)
---@param _ string[]
---@param opts table
function M.toggle_depth(_, opts)
  local current = opts.depth
  opts.depth = (current == false) and 1 or false
  reopen(opts, { depth = opts.depth })
end

---Toggle grouping folders first vs mixed sorting
---@param _ string[]
---@param opts table
function M.toggle_grouping(_, opts)
  opts.grouped = not (opts.grouped ~= false)
  reopen(opts, { grouped = opts.grouped })
end

---Toggle between showing folders only and showing all files
---@param _ string[]
---@param opts table
function M.toggle_browser(_, opts)
  opts.dirs_only = not opts.dirs_only
  reopen(opts)
end

---Toggle all files/folders ignoring gitignore (if supported)
---@param _ string[]
---@param opts table
function M.toggle_all(_, opts)
  reopen(opts, { hidden = not (opts.hidden or false), gitignore = false })
end

---Backspace action: if prompt is empty, go to parent dir
---@param selected string[]
---@param opts table
function M.backspace(selected, opts)
  local query = get_query(opts)
  if not query or query == "" then
    M.goto_parent_dir(selected, opts)
  end
end

M.backspace_or_parent = M.backspace

return M
