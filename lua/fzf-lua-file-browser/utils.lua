local M = {}

local uv = vim.uv or vim.loop
local lsp = require("fzf-lua-file-browser.lsp")

M.__IS_WINDOWS = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

-- fzf-lua separates icons from the path with its own `nbsp` (U+2002 EN SPACE in current
-- releases, U+00A0 in older ones). Read it from fzf-lua so we always match what it emits.
local NBSP = (function()
  local ok, fzf_utils = pcall(require, "fzf-lua.utils")
  return ok and fzf_utils.nbsp or "\226\128\130"
end)()

---Normalize path separators and remove trailing slash (unless root)
---@param path string
---@return string
function M.normalize_path(path)
  if not path or path == "" then
    return ""
  end
  -- Unify separators on Windows only: on unix "\\" is a legal filename character
  if M.__IS_WINDOWS then
    path = path:gsub("\\", "/")
  end
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
  -- lstat first so broken symlinks count as existing (they can still be deleted/renamed)
  local p = M.normalize_path(path)
  local stat = uv.fs_lstat(p) or uv.fs_stat(p)
  if not stat then
    return false, nil
  end
  return true, stat.type
end

---Make a path absolute: expands "~" and resolves relative paths against `base` (or :pwd)
---@param path string
---@param base string?
---@return string
function M.absolute(path, base)
  if not path or path == "" then
    return M.normalize_path(base or vim.fn.getcwd())
  end
  if path == "~" or path:sub(1, 2) == "~/" then
    path = vim.fn.expand("~") .. path:sub(2)
  end
  local is_abs = path:sub(1, 1) == "/" or (M.__IS_WINDOWS and path:match("^%a:[/\\]") ~= nil)
  if not is_abs then
    path = ((base and base ~= "") and base or vim.fn.getcwd()) .. "/" .. path
  end
  -- expand_env=false: "$" is a legal filename character ("~" was handled above)
  return M.normalize_path(vim.fs.normalize(vim.fn.fnamemodify(path, ":p"), { expand_env = false }))
end

---Get parent directory of a path
---@param path string
---@return string
function M.parent_dir(path)
  local p = M.absolute(path)
  local parent = vim.fn.fnamemodify(p, ":h")
  return M.normalize_path(parent)
end

---Strip ANSI escape sequences from a string
---@param str string
---@return string
function M.strip_ansi(str)
  if not str then return "" end
  -- CSI sequences incl. colon-separated SGR (\27[38:5:113m) and private modes (\27[?25h)
  return (str:gsub("\27%[[%d;:?]*%a", ""))
end

---Strip fzf-lua icon prefix and ANSI coloring from an entry string without corrupting spaces or UTF-8
---@param entry string
---@param opts table?
---@return string
function M.strip_icon_prefix(entry, opts)
  if not entry or entry == "" then return "" end
  local clean = M.strip_ansi(entry)
  -- Remove fzf-lua's "[git_icon NBSP][file_icon NBSP]" prefix. An icon is short and never
  -- contains "/", which keeps a filename that happens to contain NBSP from being eaten.
  -- Do NOT trim or split on whitespace: spaces/tabs are legal in filenames.
  -- fzf-lua resets file_icons to nil when no icon provider loads, so the picker opts tell us
  -- exactly how many prefixes there are; without opts assume up to two (git + file icon)
  local n_prefix = 2
  if type(opts) == "table" and (opts._type ~= nil or opts.file_icons ~= nil or opts.git_icons ~= nil) then
    n_prefix = (opts.git_icons and 1 or 0) + (opts.file_icons and 1 or 0)
  end
  local stripped_nbsp = false
  for _ = 1, n_prefix do
    local s, e = clean:find(NBSP, 1, true)
    if not s or s > 17 or clean:sub(1, s - 1):find("/", 1, true) then
      break
    end
    clean = clean:sub(e + 1)
    stripped_nbsp = true
  end
  if not stripped_nbsp and n_prefix > 0 then
    clean = clean:gsub("^[\238\239][\128-\191][\128-\191]+ +", "")
  end
  return clean
end

---Parse an entry selected in fzf-lua into absolute path and type
---@param entry string
---@param cwd string
---@param opts table? picker opts: used to know how many icon prefixes fzf-lua added
---@return table { path: string, relpath: string, is_dir: boolean, is_parent: boolean }
function M.parse_entry(entry, cwd, opts)
  if not entry then
    return { path = cwd, relpath = ".", is_dir = true, is_parent = false }
  end

  local clean = M.strip_icon_prefix(entry, opts)

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
  -- vim.fn.mkdir throws (E739) rather than returning 0 on most failures
  local ok, res = pcall(vim.fn.mkdir, p, "p")
  if not ok or res == 0 then
    return false, "Failed to create directory: " .. p .. (ok and "" or (": " .. tostring(res)))
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
    local exists, st_type = M.path_exists(path)
    if exists then
      if st_type ~= "directory" then
        return false, "A file already exists at: " .. path
      end
      return true -- already there: nothing created, so no LSP create events
    end
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

  if M.path_exists(path) then
    return false, "Already exists: " .. path
  end

  lsp.will_create_files({ path })
  -- "wx" = O_CREAT|O_EXCL: never truncate an existing file, even if it appeared after the check
  local fd, ferr = uv.fs_open(path, "wx", 438) -- 0666
  if not fd then
    return false, "Failed to create file " .. path .. ": " .. tostring(ferr)
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

  if src == dst then
    return true
  end
  if not M.path_exists(src) then
    return false, "Source does not exist: " .. src
  end
  -- fs_rename silently replaces an existing file / empty dir: refuse instead. Exception: a
  -- case-only rename on a case-insensitive FS (macOS default), where dst *is* src
  if M.path_exists(dst) then
    local a, b = uv.fs_lstat(src), uv.fs_lstat(dst)
    local same_file = a and b and a.ino == b.ino and a.dev == b.dev
    if not (same_file and src:lower() == dst:lower()) then
      return false, "Destination already exists: " .. dst
    end
  end
  if vim.startswith(dst, src .. "/") then
    return false, "Cannot move a directory into itself: " .. src
  end

  local ok_dir, dir_err = M.ensure_dir(M.parent_dir(dst))
  if not ok_dir then
    return false, dir_err
  end

  lsp.will_rename_files({ [src] = dst })
  local ok, err = uv.fs_rename(src, dst)
  if not ok then
    return false, err
  end
  M.rename_buffers(src, dst)
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
  -- "rf" on a symlink removes the link only; plain delete() is enough for files and links
  local ok = vim.fn.delete(target, type == "directory" and "rf" or "")
  if ok ~= 0 then
    return false, "Failed to delete: " .. target
  end
  M.delete_buffers(target)
  lsp.did_delete_files({ target })
  return true
end

---Buffers whose file is `path` or lives under it
---@param path string
---@return integer[]
local function buffers_under(path)
  local res = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    -- only real file buffers: nofile/terminal/prompt buffers merely share a name
    if vim.bo[b].buftype == "" and name ~= "" and (name == path or vim.startswith(name, path .. "/")) then
      table.insert(res, b)
    end
  end
  return res
end

---Point open buffers at their new location after a rename/move, so `:w` doesn't
---resurrect the old path
---@param src string
---@param dst string
function M.rename_buffers(src, dst)
  for _, b in ipairs(buffers_under(src)) do
    local name = vim.api.nvim_buf_get_name(b)
    local new = dst .. name:sub(#src + 1)
    -- `keepalt file` instead of nvim_buf_set_name: the latter leaves an alternate buffer named
    -- after the old (now missing) path, which <C-^> / :e # would bring back
    vim.api.nvim_buf_call(b, function()
      local renamed = pcall(vim.cmd, "keepalt file " .. vim.fn.fnameescape(new))
      -- only reload when the rename took: otherwise edit! would reload the now-missing old path.
      -- The reload clears the "file name changed" (E13) state; modified buffers are left for
      -- the user to :w!
      if renamed and vim.api.nvim_buf_is_loaded(b) and not vim.bo[b].modified then
        vim.cmd("silent! keepalt edit!")
      end
    end)
    local old = vim.fn.bufnr("^" .. vim.fn.escape(name, "\\[]*?~.^$") .. "$")
    if old > 0 and old ~= b and not vim.api.nvim_buf_is_loaded(old) then
      pcall(vim.api.nvim_buf_delete, old, { force = true })
    end
  end
end

---Wipe unmodified buffers of deleted files; modified ones are kept so no edits are lost
---@param path string
function M.delete_buffers(path)
  for _, b in ipairs(buffers_under(path)) do
    if not vim.bo[b].modified then
      -- keep the window layout: show another buffer in windows displaying b before wiping it
      for _, w in ipairs(vim.fn.win_findbuf(b)) do
        vim.api.nvim_win_call(w, function()
          local alt = vim.fn.bufnr("#")
          if not (alt > 0 and alt ~= b and vim.fn.buflisted(alt) == 1) then
            -- fall back to the most recently used listed buffer outside the deleted path
            alt = nil
            local infos = vim.fn.getbufinfo({ buflisted = 1 })
            table.sort(infos, function(x, y)
              return x.lastused > y.lastused
            end)
            for _, info in ipairs(infos) do
              if info.bufnr ~= b and info.name ~= path and not vim.startswith(info.name, path .. "/") then
                alt = info.bufnr
                break
              end
            end
          end
          if alt then
            vim.cmd("buffer " .. alt)
          else
            vim.cmd("enew")
          end
        end)
      end
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
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
  if source == target then
    return false, "Source and destination are the same: " .. source
  end
  if M.path_exists(target) then
    return false, "Destination already exists: " .. target
  end
  if vim.startswith(target, source .. "/") then
    return false, "Cannot copy a directory into itself: " .. source
  end

  local ok_dir, dir_err = M.ensure_dir(M.parent_dir(target))
  if not ok_dir then
    return false, dir_err
  end

  if st_type == "link" then
    -- copy the link itself: following it can recurse forever (dir -> .) or copy a whole tree
    local link_target, rerr = uv.fs_readlink(source)
    if not link_target then
      return false, rerr
    end
    local ok, err = uv.fs_symlink(link_target, target)
    if not ok then
      return false, err
    end
    return true
  elseif st_type == "directory" then
    local ok_mk, mk_err = M.ensure_dir(target)
    if not ok_mk then
      return false, mk_err
    end
    -- list entries before writing anything so the copy can't observe itself
    local names = {}
    local handle = uv.fs_scandir(source)
    if handle then
      while true do
        local name = uv.fs_scandir_next(handle)
        if not name then break end
        table.insert(names, name)
      end
    end
    for _, name in ipairs(names) do
      local ok, err = M.copy_path(M.join_paths(source, name), M.join_paths(target, name))
      if not ok then
        -- target did not exist before this call: drop the partial tree so a retry isn't refused
        vim.fn.delete(target, "rf")
        return false, err
      end
    end
    return true
  else
    local ok, err = uv.fs_copyfile(source, target, { excl = true })
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
    -- the "hide" profile replaces esc with its own action, which would skip on_submit(nil)
    no_hide = true,
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
        -- an untouched (or cleared) prompt means the user picked a suggestion with the cursor
        if (not val or val == "" or val == opts.default) and selected and selected[1] then
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

---Get fixed session root working directory
---@param opts table?
---@return string
function M.get_root_cwd(opts)
  opts = opts or {}
  return M.normalize_path(opts.root_cwd or opts._root_cwd or vim.fn.getcwd())
end

---Get current directory path being browsed
---@param opts table?
---@return string
function M.get_browse_path(opts)
  opts = opts or {}
  return M.normalize_path(opts.path or opts.cwd or vim.fn.getcwd())
end

---Get clean relative path of target path relative to base cwd matching telescope file-browser prompt format
---@param path string
---@param cwd string
---@return string
function M.relative_path(path, cwd)
  path = M.normalize_path(path)
  cwd = M.normalize_path(cwd)
  if path == cwd then
    return "./"
  end
  local prefix = cwd .. "/"
  if path:sub(1, #prefix) == prefix then
    local sub = path:sub(#prefix + 1)
    if sub:sub(-1) ~= "/" then
      sub = sub .. "/"
    end
    return sub
  end
  local rel = vim.fn.fnamemodify(path, ":~")
  if rel:sub(-1) ~= "/" then
    rel = rel .. "/"
  end
  return rel
end

return M
