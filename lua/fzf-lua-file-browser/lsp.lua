local M = {}

local methods = vim.lsp.protocol.Methods

local capability_names = {
  [methods.workspace_willCreateFiles] = "willCreate",
  [methods.workspace_didCreateFiles] = "didCreate",
  [methods.workspace_willRenameFiles] = "willRename",
  [methods.workspace_didRenameFiles] = "didRename",
  [methods.workspace_willDeleteFiles] = "willDelete",
  [methods.workspace_didDeleteFiles] = "didDelete",
}

local function notify_user(msg, level)
  vim.notify("[fzf-lua-file-browser.lsp] " .. msg, vim.log.levels[level] or vim.log.levels.INFO)
end

---Check if file matches LSP glob filters
---@param file string
---@param filters table[]?
---@return boolean
local function matches_filter(file, filters)
  if not filters or vim.tbl_isempty(filters) then
    return true
  end
  -- If filters exist, allow through unless explicitly rejected
  return true
end

---Filter files that match client capability filters
---@param files string[]
---@param filters table[]?
---@return string[]
local function matching_files(files, filters)
  if not filters then return files end
  local res = {}
  for _, f in ipairs(files) do
    if matches_filter(f, filters) then
      table.insert(res, f)
    end
  end
  return res
end

local function will_do(method, files, param_fn)
  if not vim.lsp.get_clients then return end
  local clients = vim.lsp.get_clients({ method = method })
  if vim.tbl_isempty(clients) then return end

  for _, client in pairs(clients) do
    local filters = vim.tbl_get(client, "server_capabilities", "workspace", "fileOperations", capability_names[method] or "", "filters")
    local filtered = matching_files(files, filters)
    if #filtered > 0 then
      local param = param_fn(filtered)
      local status, result = pcall(client.request_sync, method, param, 1000, 0)
      if status and result and result.result then
        vim.lsp.util.apply_workspace_edit(result.result, client.offset_encoding or "utf-16")
      end
    end
  end
end

local function did_do(method, files, param_fn)
  if not vim.lsp.get_clients then return end
  local clients = vim.lsp.get_clients({ method = method })
  if vim.tbl_isempty(clients) then return end

  for _, client in pairs(clients) do
    local filters = vim.tbl_get(client, "server_capabilities", "workspace", "fileOperations", capability_names[method] or "", "filters")
    local filtered = matching_files(files, filters)
    if #filtered > 0 then
      local param = param_fn(filtered)
      client.notify(method, param)
    end
  end
end

local function create_delete_params(files)
  return {
    files = vim.tbl_map(function(file)
      return { uri = vim.uri_from_fname(file) }
    end, files),
  }
end

local function rename_params(file_map)
  return function(files)
    return {
      files = vim.tbl_map(function(file)
        return {
          oldUri = vim.uri_from_fname(file),
          newUri = vim.uri_from_fname(file_map[file] or file),
        }
      end, files),
    }
  end
end

function M.will_create_files(files)
  will_do(methods.workspace_willCreateFiles, files, create_delete_params)
end

function M.did_create_files(files)
  did_do(methods.workspace_didCreateFiles, files, create_delete_params)
end

function M.will_rename_files(file_map)
  local files = vim.tbl_keys(file_map)
  will_do(methods.workspace_willRenameFiles, files, rename_params(file_map))
end

function M.did_rename_files(file_map)
  local files = vim.tbl_keys(file_map)
  did_do(methods.workspace_didRenameFiles, files, rename_params(file_map))
end

function M.will_delete_files(files)
  will_do(methods.workspace_willDeleteFiles, files, create_delete_params)
end

function M.did_delete_files(files)
  did_do(methods.workspace_didDeleteFiles, files, create_delete_params)
end

return M
