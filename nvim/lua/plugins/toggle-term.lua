local M = {
'akinsho/toggleterm.nvim'
}
M.enabled= true
M.config = true
vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm direction=float<CR>")
return M

