local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Close buffer" })

map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
-- [d / ]d are built in (Neovim 0.11+); float-on-jump is set in vim.diagnostic.config.
map("n", "<leader>cl", vim.diagnostic.setloclist, { desc = "Diagnostic loclist" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Window/pane navigation is <M-h/j/k/l> via smart-splits.nvim (plugins/navigation.lua),
-- which hands off to tmux at the edge of the Neovim layout.

-- Alacritty sends ^A / ^E for Cmd+Left / Cmd+Right; keep them useful in insert mode.
map("i", "<C-a>", "<C-o>^", { desc = "Start of line" })
map("i", "<C-e>", "<End>", { desc = "End of line" })

-- Editing quality-of-life
map("x", "<", "<gv", { desc = "Outdent and keep selection" })
map("x", ">", ">gv", { desc = "Indent and keep selection" })
map("x", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })
map("x", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next match (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev match (centered)" })
map("x", "<leader>p", [["_dP]], { desc = "Paste without clobbering register" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bo", "<cmd>%bdelete|edit #|bdelete #<CR>", { desc = "Close other buffers" })
map("n", "<leader>ur", "<cmd>nohlsearch|diffupdate|redraw!<CR>", { desc = "Redraw / clear highlights" })
