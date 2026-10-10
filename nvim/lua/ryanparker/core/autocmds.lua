-- Filetype hints for SRE/data files that Neovim cannot always infer.
vim.filetype.add({
  extension = {
    -- Built-in detection returns "tf" for empty or comment-only files, so new
    -- Terraform buffers would miss the terraform formatters/LSP until reopened.
    tf = "terraform",
  },
  pattern = {
    [".*[Cc]loud[Ff]ormation.*%.ya?ml"] = "yaml.cloudformation",
    [".*[Tt]emplate%.ya?ml"] = "yaml.cloudformation",
    [".*/models/.*%.sql"] = "sql.dbt",
  },
})

local augroup = vim.api.nvim_create_augroup("ryanparker_core", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.hl.on_yank({ timeout = 180 })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "java" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})
