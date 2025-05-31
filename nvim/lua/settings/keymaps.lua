
-- Keymaps and filetype mappings

-- ------------------
-- Utils for mappings
-- ------------------

-- Close floating windows
local function close_floating()
  for _, win in pairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == 'win' then
      vim.api.nvim_win_close(win, false)
    end
  end
end

-- Keymap shortcut
local function map(mode, l, r, opts)
  opts = opts or {}
  vim.keymap.set(mode, l, r, opts)
end

-- -------
-- Keymaps
-- -------

-- Move Between Splits
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Buffer Navigation
map("n", "<S-l>", ":bnext<CR>")
map("n", "<S-h>", ":bprev<CR>")

-- Window Management
map("n", "<leader>vs", ":vsp<CR>")
map("n", "<leader>hs", ":sp<CR>")

-- File Explorer
-- map("n", "<leader>e", ":NvimTreeToggle<CR>")

-- Search and Replace
map("n", "<leader>fr", ":%s//g<Left><Left>")

-- Indent in Visual Mode
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Quick Save and Quit
map("n", "<leader>w", ":w<CR>")
map("n", "<leader>q", ":q<CR>")

-- Clear highlights on search when pressing <Esc> in normal mode
map('n', '<Esc>', function()
  close_floating()
  vim.cmd ':nohlsearch'
end, {
  silent = true,
  desc = 'Remove search highlight and dismiss popups',
})
