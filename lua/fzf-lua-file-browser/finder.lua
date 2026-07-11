local M = {}

local utils = require("fzf-lua-file-browser.utils")

---Get shell command string to stream filesystem entries matching fzf-lua files strategy
---@param opts table
---@return string
function M.get_cmd(opts)
  opts = opts or {}
  if opts.raw_cmd and #opts.raw_cmd > 0 then
    return opts.raw_cmd
  end
  if opts.cmd and #opts.cmd > 0 then
    return opts.cmd
  end

  local parent_prefix = ""
  if not opts.hide_parent_dir then
    if utils.__IS_WINDOWS then
      parent_prefix = "echo ../ && "
    else
      parent_prefix = 'printf "../\\n" && '
    end
  end

  if vim.fn.executable("fdfind") == 1 or vim.fn.executable("fd") == 1 then
    local bin = vim.fn.executable("fdfind") == 1 and "fdfind" or "fd"
    local flags = { "--color=never" }

    if opts.hidden then
      table.insert(flags, "--hidden")
    end
    if opts.gitignore == false then
      table.insert(flags, "--no-ignore")
    end

    if not opts.hidden then
      table.insert(flags, "--exclude .git --exclude .jj")
    end

    -- Depth handling: false means recursive (no max-depth limit)
    if opts.depth ~= false then
      local d = tonumber(opts.depth) or 1
      table.insert(flags, "--max-depth " .. d)
    end

    local base_cmd = bin .. " " .. table.concat(flags, " ")

    if opts.dirs_only then
      return parent_prefix .. base_cmd .. " --type d"
    elseif opts.files_only then
      return parent_prefix .. base_cmd .. " --type f --type l"
    elseif opts.grouped ~= false then
      return string.format("%s( %s --type d && %s --type f --type l )", parent_prefix, base_cmd, base_cmd)
    else
      return parent_prefix .. base_cmd
    end
  end

  -- Fallback to POSIX find
  local flags = {}
  if opts.depth ~= false then
    local d = tonumber(opts.depth) or 1
    table.insert(flags, "-maxdepth " .. d)
  end
  if not opts.hidden then
    table.insert(flags, "-not -path '*/.*'")
  end
  table.insert(flags, "-not -path '*/.git/*'")

  local flag_str = table.concat(flags, " ")
  if flag_str ~= "" then
    flag_str = " " .. flag_str
  end

  if opts.dirs_only then
    return string.format("%sfind . -mindepth 1%s -type d -exec printf '%%s/\\n' {} +", parent_prefix, flag_str)
  elseif opts.files_only then
    return string.format("%sfind . -mindepth 1%s \\( -type f -o -type l \\) -print", parent_prefix, flag_str)
  elseif opts.grouped ~= false then
    return string.format(
      "%s( find . -mindepth 1%s -type d -exec printf '%%s/\\n' {} + && find . -mindepth 1%s \\( -type f -o -type l \\) -print )",
      parent_prefix,
      flag_str,
      flag_str
    )
  else
    return string.format("%sfind . -mindepth 1%s \\( -type d -exec printf '%%s/\\n' {} + -o -print \\)", parent_prefix, flag_str)
  end
end

---Get contents command string for fzf-lua executor
---@param opts table
---@return string
function M.get_contents(opts)
  return M.get_cmd(opts)
end

return M
