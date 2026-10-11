vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable netrw before plugins load. oil.nvim is the file browser.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("ryanparker.core.options")
require("ryanparker.core.keymaps")
require("ryanparker.core.autocmds")
