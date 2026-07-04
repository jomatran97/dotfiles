-- General editor options.
-- See `:help option-list` for everything available.

local opt = vim.opt

-- Disable netrw at the very start so oil.nvim owns directory buffers.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation: 2 spaces, no tabs
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.breakindent = true

-- Search
opt.ignorecase = true -- case-insensitive...
opt.smartcase = true -- ...unless the query contains a capital
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split" -- preview :substitute changes in a split

-- Appearance
opt.termguicolors = true -- 24-bit colour (needed for Catppuccin)
opt.signcolumn = "yes" -- always show the sign column (no text shift)
opt.cursorline = true
opt.scrolloff = 8 -- keep 8 lines visible above/below the cursor
opt.sidescrolloff = 8
opt.wrap = false
opt.colorcolumn = "80"
opt.showmode = false -- mode is shown in the statusline instead
opt.laststatus = 3 -- a single global statusline
if vim.fn.has("nvim-0.11") == 1 then
	opt.winborder = "rounded" -- default rounded borders for floating windows
end
opt.fillchars = { eob = " " }
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Files, backups and undo
opt.swapfile = false
opt.backup = false
opt.undofile = true
local undodir = vim.fn.stdpath("data") .. "/undodir"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir

-- Behaviour
opt.mouse = "a"
opt.clipboard = "unnamedplus" -- use the system clipboard
opt.updatetime = 250 -- faster CursorHold / diagnostics
opt.timeoutlen = 300 -- which-key popup delay
opt.completeopt = "menu,menuone,noselect"
opt.confirm = true -- prompt instead of failing on :q with changes

-- Filetypes
-- Recognise .ejs files (Embedded JavaScript templates) as their own filetype
-- so Treesitter and Emmet can treat them as embedded HTML/JS.
vim.filetype.add({
	extension = { ejs = "ejs" },
})
