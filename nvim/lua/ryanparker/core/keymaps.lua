local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })
map("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Close buffer" })

map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
-- [d / ]d are built in (Neovim 0.11+); float-on-jump is set in vim.diagnostic.config.
map("n", "<leader>cl", vim.diagnostic.setloclist, { desc = "Diagnostic loclist" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Window/pane navigation is <M-h/j/k/l> via smart-splits.nvim (plugins/init.lua),
-- which hands off to tmux at the edge of the Neovim layout.

-- Alacritty sends ^A / ^E for Cmd+Left / Cmd+Right; keep them useful in insert mode.
map("i", "<C-a>", "<C-o>^", { desc = "Start of line" })
map("i", "<C-e>", "<End>", { desc = "End of line" })
