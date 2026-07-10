local M = {}

---Hijack Netrw so opening directory buffers opens fzf-lua-file-browser
function M.hijack()
  local netrw_bufname

  pcall(vim.api.nvim_clear_autocmds, { group = "FileExplorer" })
  vim.api.nvim_create_autocmd("VimEnter", {
    pattern = "*",
    once = true,
    callback = function()
      pcall(vim.api.nvim_clear_autocmds, { group = "FileExplorer" })
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("fzf-lua-file-browser-netrw", { clear = true }),
    pattern = "*",
    callback = function(args)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(args.buf) then return end
        if vim.bo[args.buf].filetype == "netrw" then return end

        local bufname = vim.api.nvim_buf_get_name(args.buf)
        if vim.fn.isdirectory(bufname) == 0 then
          _, netrw_bufname = pcall(vim.fn.expand, "#:p:h")
          return
        end

        if netrw_bufname == bufname then
          netrw_bufname = nil
          return
        else
          netrw_bufname = bufname
        end

        -- Ensure directory buffer is wiped when closed/replaced
        vim.bo[args.buf].bufhidden = "wipe"

        require("fzf-lua-file-browser").browse({
          cwd = vim.fn.expand("%:p:h"),
        })
      end)
    end,
    desc = "fzf-lua-file-browser replacement for netrw",
  })
end

return M
