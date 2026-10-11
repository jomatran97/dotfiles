-- Filetype hints for SRE/data files that Neovim cannot always infer.
vim.filetype.add({
  extension = {
    -- Built-in detection returns "tf" for empty or comment-only files, so new
    -- Terraform buffers would miss the terraform formatters/LSP until reopened.
    tf = "terraform",
  },
  pattern = {
    [".*%.ya?ml"] = {
      function(path, bufnr)
        local lines
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
          lines = vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)
        elseif path and vim.fn.filereadable(path) == 1 then
          lines = vim.fn.readfile(path, "", 50)
        end
        for _, line in ipairs(lines or {}) do
          if line:find("AWSTemplateFormatVersion", 1, true) or line:find("AWS::", 1, true) then
            return "yaml.cloudformation"
          end
        end
      end,
    },
    [".*%.sql"] = {
      function(path)
        if not path then
          return nil
        end
        for _, dir in ipairs({ "models", "macros", "analyses", "seeds", "snapshots", "tests" }) do
          if path:find("/" .. dir .. "/", 1, true) then
            if vim.fs.root(path, "dbt_project.yml") then
              return "sql.dbt"
            end
            return nil
          end
        end
      end,
    },
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

-- Restore the last cursor position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" or vim.bo[ev.buf].filetype:match("^git") then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Reload files changed outside Neovim (git checkout, formatters, other panes).
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup,
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Keep splits equal when the terminal is resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})

-- Create missing parent directories on save.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
  end,
})

-- Close throwaway buffers with just `q`.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo", "notify" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true, desc = "Close window" })
  end,
})
