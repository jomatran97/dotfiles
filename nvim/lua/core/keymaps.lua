-- For conciseness
local opts = { noremap = true, silent = true }

-- Allow moving the cursor through wrapped lines with j, k
vim.keymap.set("n", "k", "'gk'", { expr = true, silent = true })
vim.keymap.set("n", "j", "'gj'", { expr = true, silent = true })

vim.keymap.set("n", "<Esc>", ":noh<CR>", opts)

-- Resize with arrows
vim.keymap.set("n", "<Up>", ":resize -2<CR>", opts)
vim.keymap.set("n", "<Down>", ":resize +2<CR>", opts)
vim.keymap.set("n", "<Left>", ":vertical resize -2<CR>", opts)
vim.keymap.set("n", "<Right>", ":vertical resize +2<CR>", opts)

-- Stay in indent mode
vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

-- Keep last yanked when pasting
vim.keymap.set("v", "p", '"_dP', opts)

-- save file
vim.keymap.set("n", "<C-s>", "<cmd> w <CR>", opts)
