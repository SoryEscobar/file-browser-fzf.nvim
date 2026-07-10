local M = {}

M.actions = require("fzf-lua-file-browser.actions")
M.browse = require("fzf-lua-file-browser.browse").browse

local default_config = {
  cwd = nil,
  hidden = false,
  files_only = false,
  dirs_only = false,
  hide_parent_dir = false,
  hijack_netrw = false,
  display_stat = false,
  actions = {},
}

M.config = vim.deepcopy(default_config)

---Register file_browser into fzf-lua
local function register_with_fzf_lua()
  local ok, fzf = pcall(require, "fzf-lua")
  if ok and fzf then
    fzf.file_browser = function(opts)
      opts = vim.tbl_deep_extend("force", M.config, opts or {})
      return M.browse(opts)
    end
  end
end

---Setup plugin configuration
---@param opts table?
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.hijack_netrw then
    require("fzf-lua-file-browser.netrw").hijack()
  end

  register_with_fzf_lua()

  vim.api.nvim_create_user_command("FzfLuaFileBrowser", function(cmd_args)
    local target_cwd = cmd_args.args ~= "" and cmd_args.args or M.config.cwd
    M.browse(vim.tbl_extend("force", M.config, { cwd = target_cwd }))
  end, {
    nargs = "?",
    complete = "dir",
    desc = "Open fzf-lua file browser",
  })
end

return M
