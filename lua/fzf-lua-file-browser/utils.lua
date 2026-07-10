local M = {}

local uv = vim.uv or vim.loop
local lsp = require("fzf-lua-file-browser.lsp")

---Normalize path separators and remove trailing slash (unless root)
---@param path string
---@return string
function M.normalize_path(path)
  if not path or path == "" then
    return ""
  end
  -- Replace backslashes on non-windows if needed, or unify separators
  path = path:gsub("\\", "/")
  -- Remove duplicate slashes
  path = path:gsub("//+", "/")
  if #path > 1 and path:sub(-1) == "/" then
    path = path:sub(1, -2)
  end
  return path
end

---Join multiple path segments
---@param ... string
---@return string
function M.join_paths(...)
  local segments = { ... }
  local res = ""
  for i, seg in ipairs(segments) do
    if seg and seg ~= "" then
      if res == "" then
        res = seg
      else
        local clean_res = res:gsub("/$", "")
        local clean_seg = seg:gsub("^/", "")
        res = clean_res .. "/" .. clean_seg
      end
    end
  end
  return M.normalize_path(res)
end

---Check if path is a directory
---@param path string
---@return boolean
function M.is_dir(path)
  if not path or path == "" then
    return false
  end
  local stat = uv.fs_stat(M.normalize_path(path))
  return stat ~= nil and stat.type == "directory"
end

---Check if path exists
---@param path string
---@return boolean, string?
function M.path_exists(path)
  if not path or path == "" then
    return false
  end
  local stat = uv.fs_stat(M.normalize_path(path))
  if not stat then
    return false, nil
  end
  return true, stat.type
end

---Get parent directory of a path
---@param path string
---@return string
function M.parent_dir(path)
  local p = M.normalize_path(path)
  local parent = vim.fn.fnamemodify(p, ":h")
  return M.normalize_path(parent)
end

---Strip ANSI escape sequences from a string
---@param str string
---@return string
function M.strip_ansi(str)
  if not str then return "" end
  return str:gsub("\27%[[0-9;]*m", ""):gsub("\27%[[0-9;]*[a-zA-Z]", "")
end

---Parse an entry selected in fzf-lua into absolute path and type
---@param entry string
---@param cwd string
---@return table { path: string, relpath: string, is_dir: boolean, is_parent: boolean }
function M.parse_entry(entry, cwd)
  if not entry then
    return { path = cwd, relpath = ".", is_dir = true, is_parent = false }
  end

  local clean = M.strip_ansi(entry)
  clean = clean:match("^[^\t]+") or clean
  -- Remove fzf-lua icon prefix if present (usually icon + space/nbsp)
  clean = clean:gsub("^[^\32\9\194\160]+[\32\9\194\160]+", "")
  clean = vim.trim(clean)

  if clean == "../" or clean == ".." then
    local parent = M.parent_dir(cwd)
    return {
      path = parent,
      relpath = "..",
      is_dir = true,
      is_parent = true,
    }
  end

  local is_dir = clean:sub(-1) == "/"
  local relpath = clean
  local abspath = M.normalize_path(M.join_paths(cwd, relpath))
  if not is_dir then
    is_dir = M.is_dir(abspath)
  end

  return {
    path = abspath,
    relpath = relpath,
    is_dir = is_dir,
    is_parent = false,
  }
end

---Ensure directory exists (mkdir -p)
---@param dir string
---@return boolean, string?
function M.ensure_dir(dir)
  local p = M.normalize_path(dir)
  if M.is_dir(p) then
    return true
  end
  local ok, err = vim.fn.mkdir(p, "p")
  if ok == 0 then
    return false, "Failed to create directory: " .. p
  end
  return true
end

---Create a file or directory
---@param filepath string Absolute path
---@param is_dir boolean Whether creating a directory
---@return boolean success, string? err
function M.create_path(filepath, is_dir)
  local path = M.normalize_path(filepath)
  if is_dir or filepath:sub(-1) == "/" then
    local ok, err = M.ensure_dir(path)
    if ok then
      lsp.will_create_files({ path })
      lsp.did_create_files({ path })
    end
    return ok, err
  end

  -- Ensure parent directory exists
  local parent = M.parent_dir(path)
  local ok, err = M.ensure_dir(parent)
  if not ok then
    return false, err
  end

  lsp.will_create_files({ path })
  local fd = uv.fs_open(path, "w", 438) -- 0666
  if not fd then
    return false, "Failed to open file for creation: " .. path
  end
  uv.fs_close(fd)
  lsp.did_create_files({ path })
  return true
end

---Rename / Move a file or directory
---@param old_path string
---@param new_path string
---@return boolean success, string? err
function M.rename_path(old_path, new_path)
  local src = M.normalize_path(old_path)
  local dst = M.normalize_path(new_path)

  local parent = M.parent_dir(dst)
  M.ensure_dir(parent)

  lsp.will_rename_files({ [src] = dst })
  local ok, err = uv.fs_rename(src, dst)
  if not ok then
    return false, err
  end
  lsp.did_rename_files({ [src] = dst })
  return true
end

---Delete a file or directory recursively
---@param path string
---@return boolean success, string? err
function M.delete_path(path)
  local target = M.normalize_path(path)
  local exists, type = M.path_exists(target)
  if not exists then
    return false, "Path does not exist: " .. target
  end

  lsp.will_delete_files({ target })
  local ok = vim.fn.delete(target, "rf")
  if ok ~= 0 then
    return false, "Failed to delete: " .. target
  end
  lsp.did_delete_files({ target })
  return true
end

---Recursive copy file or directory
---@param src string
---@param dst string
---@return boolean success, string? err
function M.copy_path(src, dst)
  local source = M.normalize_path(src)
  local target = M.normalize_path(dst)

  local exists, st_type = M.path_exists(source)
  if not exists then
    return false, "Source does not exist: " .. source
  end

  if st_type == "directory" then
    M.ensure_dir(target)
    local handle = uv.fs_scandir(source)
    if handle then
      while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then break end
        local ok, err = M.copy_path(M.join_paths(source, name), M.join_paths(target, name))
        if not ok then
          return false, err
        end
      end
    end
    return true
  else
    local parent = M.parent_dir(target)
    M.ensure_dir(parent)
    local ok, err = uv.fs_copyfile(source, target)
    if not ok then
      return false, err
    end
    return true
  end
end

---Prompt confirmation dialog
---@param prompt_text string
---@param on_confirm fun()
---@param on_cancel? fun()
function M.confirm(prompt_text, on_confirm, on_cancel)
  vim.ui.select({ "Yes", "No" }, {
    prompt = prompt_text,
  }, function(choice)
    if choice == "Yes" then
      on_confirm()
    elseif on_cancel then
      on_cancel()
    end
  end)
end

---Prompt input using an fzf-lua picker matching the plugin style
---@param opts { prompt: string, default?: string, items?: string[] }
---@param on_submit fun(val: string?)
function M.picker_input(opts, on_submit)
  local has_ui = #vim.api.nvim_list_uis() > 0
  if not has_ui then
    vim.ui.input({
      prompt = opts.prompt,
      default = opts.default,
    }, on_submit)
    return
  end

  local fzf_ok, fzf = pcall(require, "fzf-lua")
  if not fzf_ok then
    vim.ui.input({ prompt = opts.prompt, default = opts.default }, on_submit)
    return
  end

  local items = opts.items or {}
  if #items == 0 and opts.default and opts.default ~= "" then
    items = { opts.default }
  end

  fzf.fzf_exec(items, {
    prompt = opts.prompt or "Input> ",
    query = opts.default or "",
    fzf_opts = {
      ["--print-query"] = true,
    },
    winopts = {
      title = " " .. (opts.prompt or "Input") .. " ",
      title_pos = "center",
      height = 0.45,
      width = 0.65,
    },
    actions = {
      ["default"] = function(selected, o)
        local val = o and o.last_query
        if (not val or val == "") and selected and selected[1] then
          val = selected[1]
        end
        on_submit(val)
      end,
      ["esc"] = function()
        on_submit(nil)
      end,
      ["ctrl-c"] = function()
        on_submit(nil)
      end,
    },
  })
end

return M
