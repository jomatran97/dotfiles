local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.termguicolors = true
opt.laststatus = 3
opt.winborder = "rounded"
opt.showmode = false

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"
opt.splitbelow = true
opt.splitright = true
opt.scrolloff = 8
opt.sidescrolloff = 8

opt.clipboard = "unnamedplus"
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }

opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Keep the theme dependency-free and minimalist.
pcall(vim.cmd.colorscheme, "habamax")
