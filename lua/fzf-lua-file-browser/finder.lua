local M = {}

local uv = vim.uv or vim.loop
local utils = require("fzf-lua-file-browser.utils")

local ansi = {
  blue = function(str) return "\27[34m" .. str .. "\27[0m" end,
  cyan = function(str) return "\27[36m" .. str .. "\27[0m" end,
  green = function(str) return "\27[32m" .. str .. "\27[0m" end,
  yellow = function(str) return "\27[33m" .. str .. "\27[0m" end,
  grey = function(str) return "\27[90m" .. str .. "\27[0m" end,
  reset = "\27[0m",
}

---Format file size into human readable string
---@param bytes number
---@return string
local function format_size(bytes)
  if not bytes or bytes < 0 then return "-" end
  local units = { "B", "KB", "MB", "GB", "TB" }
  local unit_idx = 1
  local size = bytes
  while size >= 1024 and unit_idx < #units do
    size = size / 1024
    unit_idx = unit_idx + 1
  end
  if unit_idx == 1 then
    return string.format("%dB", size)
  else
    return string.format("%.1f%s", size, units[unit_idx])
  end
end

---Format stat timestamp
---@param sec number
---@return string
local function format_date(sec)
  if not sec then return "" end
  return os.date("%Y-%m-%d %H:%M", sec) or ""
end

---Get icon and highlight function for entry
---@param name string
---@param is_dir boolean
---@param opts table
---@return string icon, function? color_fn
local function get_icon(name, is_dir, opts)
  local ok_fzf_dev, fzf_dev = pcall(require, "fzf-lua.devicons")
  local ok_fzf_utils, fzf_utils = pcall(require, "fzf-lua.utils")

  if is_dir then
    return "", ansi.blue
  end

  if ok_fzf_dev and fzf_dev.get_devicon then
    fzf_dev.load()
    local icon, hl = fzf_dev.get_devicon(name)
    if icon and #icon > 0 then
      if hl and ok_fzf_utils then
        local color_fn = function(s)
          return fzf_utils.ansi_from_rgb(hl, s)
        end
        return icon, color_fn
      end
      return icon, nil
    end
  end

  local devicons_ok, devicons = pcall(require, "nvim-web-devicons")
  if devicons_ok and devicons.get_icon then
    local ext = name:match("^.+%.([^.]+)$") or ""
    local icon, color = devicons.get_icon(name, ext, { default = true })
    if icon and color and ok_fzf_utils then
      local color_fn = function(s)
        return fzf_utils.ansi_from_rgb(color, s)
      end
      return icon, color_fn
    end
    return icon or "", nil
  end

  return "", nil
end

---Format single entry line
---@param name string
---@param is_dir boolean
---@param stat table?
---@param opts table
---@return string
local function format_entry(name, is_dir, stat, opts)
  local display_name = is_dir and (name .. "/") or name
  local icon, color_fn = get_icon(name, is_dir, opts)
  local colored_icon = color_fn and color_fn(icon) or icon
  local colored_name
  if is_dir then
    colored_name = ansi.blue(display_name)
  elseif opts.color_filenames and color_fn then
    colored_name = color_fn(display_name)
  else
    colored_name = display_name
  end

  local stat_str = ""
  if opts.display_stat then
    local parts = {}
    if stat then
      if type(opts.display_stat) == "table" and opts.display_stat.size ~= false then
        table.insert(parts, string.format("%8s", format_size(stat.size)))
      end
      if type(opts.display_stat) == "table" and opts.display_stat.date ~= false then
        table.insert(parts, format_date(stat.mtime and stat.mtime.sec))
      end
    end
    if #parts > 0 then
      stat_str = "\t  " .. ansi.grey(table.concat(parts, "  "))
    end
  end

  return string.format("%s  %s%s", colored_icon, colored_name, stat_str)
end

---Sort function for entries (case-insensitive natural sort)
local function sort_entries(a, b)
  return a.name:lower() < b.name:lower()
end

local function scan_dir_recursive(dir_path, rel_prefix, current_depth, max_depth, dirs, files, opts)
  local handle = uv.fs_scandir(dir_path)
  if not handle then return end

  while true do
    local name, ftype = uv.fs_scandir_next(handle)
    if not name then break end

    local is_hidden = name:sub(1, 1) == "."
    if opts.hidden or not is_hidden then
      if name ~= ".git" or opts.hidden then
        local full = utils.join_paths(dir_path, name)
        local rel_name = rel_prefix .. name
        local is_dir = ftype == "directory"
        if ftype ~= "directory" and ftype ~= "file" then
          local st = uv.fs_stat(full)
          if st and st.type == "directory" then
            is_dir = true
          end
        end

        if is_dir then
          if not opts.files_only then
            table.insert(dirs, { name = rel_name, is_dir = true })
          end
          local should_recurse = (max_depth == false) or (type(max_depth) == "number" and current_depth < max_depth)
          if should_recurse then
            scan_dir_recursive(full, rel_name .. "/", current_depth + 1, max_depth, dirs, files, opts)
          end
        else
          if not opts.dirs_only then
            table.insert(files, { name = rel_name, is_dir = false })
          end
        end
      end
    end
  end
end

---Get contents of a directory formatted as prompt items
---@param opts table
---@return function
function M.get_contents(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()

  return function(cb)
    coroutine.wrap(function()
      local co = coroutine.running()

      -- Parent directory entry
      if not opts.hide_parent_dir then
        cb(ansi.blue("  ../"))
      end

      local dirs = {}
      local files = {}
      local max_depth = 1
      if opts.depth ~= nil then
        max_depth = opts.depth
      end
      scan_dir_recursive(cwd, "", 1, max_depth, dirs, files, opts)

      if opts.grouped ~= false then
        table.sort(dirs, sort_entries)
        table.sort(files, sort_entries)

        for _, item in ipairs(dirs) do
          local stat = nil
          if opts.display_stat then
            stat = uv.fs_stat(utils.join_paths(cwd, item.name))
          end
          cb(format_entry(item.name, true, stat, opts))
        end

        for _, item in ipairs(files) do
          local stat = nil
          if opts.display_stat then
            stat = uv.fs_stat(utils.join_paths(cwd, item.name))
          end
          cb(format_entry(item.name, false, stat, opts))
        end
      else
        local all_items = {}
        for _, item in ipairs(dirs) do table.insert(all_items, item) end
        for _, item in ipairs(files) do table.insert(all_items, item) end
        table.sort(all_items, sort_entries)
        for _, item in ipairs(all_items) do
          local stat = nil
          if opts.display_stat then
            stat = uv.fs_stat(utils.join_paths(cwd, item.name))
          end
          cb(format_entry(item.name, item.is_dir, stat, opts))
        end
      end

      cb(nil)
    end)()
  end
end

return M
