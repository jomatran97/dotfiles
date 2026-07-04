-- Autocommands.

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Briefly highlight text when it is yanked.
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    -- vim.hl is the new name in 0.11+, vim.highlight on older versions.
    local hl = vim.hl or vim.highlight
    hl.on_yank({ timeout = 200 })
  end,
})

-- Strip trailing whitespace on save, but only for normal editable buffers.
-- Some filetypes intentionally use trailing spaces (for example Markdown).
local trim_whitespace_excluded = {
  gitcommit = true,
  markdown = true,
}

autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = "*",
  callback = function(args)
    if vim.b[args.buf].disable_trim_whitespace then
      return
    end

    local bo = vim.bo[args.buf]
    if bo.binary or not bo.modifiable or bo.buftype ~= "" or trim_whitespace_excluded[bo.filetype] then
      return
    end

    local view = vim.fn.winsaveview()
    vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Restore the cursor to its last position when reopening a file.
autocmd("BufReadPost", {
  group = augroup("last_position", { clear = true }),
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close throwaway/utility buffers with a single `q`.
autocmd("FileType", {
  group = augroup("quick_close", { clear = true }),
  pattern = { "help", "qf", "man", "lspinfo", "checkhealth", "startuptime" },
  callback = function(args)
    vim.bo[args.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = args.buf, silent = true })
  end,
})

-- Keep wrapping focused on prose-style buffers instead of code by default.
autocmd("FileType", {
  group = augroup("prose_wrap", { clear = true }),
  pattern = { "gitcommit", "markdown", "quarto", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end,
})

-- Language-specific indentation overrides.
autocmd("FileType", {
  group = augroup("filetype_indentation", { clear = true }),
  pattern = { "python" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})

autocmd("FileType", {
  group = augroup("filetype_indentation", { clear = false }),
  pattern = { "go", "gomod", "gowork", "gotmpl" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = false
  end,
})
