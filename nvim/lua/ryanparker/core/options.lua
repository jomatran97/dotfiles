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
opt.softtabstop = -1
opt.shiftround = true
opt.wrap = false
opt.linebreak = true
opt.breakindent = true

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"
opt.scrolloff = 8
opt.sidescrolloff = 8

vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)
opt.undofile = true
opt.confirm = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect", "fuzzy" }
opt.pumheight = 10
opt.mouse = "a"
opt.smoothscroll = true
opt.jumpoptions = "view"
opt.virtualedit = "block"
opt.foldlevelstart = 99
opt.fillchars = { eob = " ", fold = " ", foldsep = " " }
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" }

opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣", extends = "›", precedes = "‹" }

-- Built-in fallback; the real theme is catppuccin (plugins/ui.lua).
pcall(vim.cmd.colorscheme, "habamax")
