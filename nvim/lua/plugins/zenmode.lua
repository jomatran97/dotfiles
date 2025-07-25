return -- Lua
{
	"folke/zen-mode.nvim",
	cmd = "ZenMode",
	opts = {
		window = {
			backdrop = 1, -- shade the backdrop of the Zen window. Set to 1 to keep the same as Normal
			-- height and width can be:
			-- * an absolute number of cells when > 1
			-- * a percentage of the width / height of the editor when <= 1
			-- * a function that returns the width or the height
			width = 0.50, -- width of the Zen window
			height = 0.9, -- height of the Zen window
			-- by default, no options are changed for the Zen window
			-- uncomment any of the options below, or add other vim.wo options you want to apply
			options = {
				signcolumn = "yes", -- disable signcolumn
				number = true, -- disable number column
				relativenumber = true, -- disable relative numbers
				cursorline = true, -- disable cursorline
				cursorcolumn = false, -- disable cursor column
				foldcolumn = "0", -- disable fold column
				list = true, -- disable whitespace characters
			},
		},
		plugins = {
			options = {
				enabled = true,
				ruler = true, -- disables the ruler text in the cmd line area
				showcmd = true, -- disables the command in the last line of the screen
				-- you may turn on/off statusline in zen mode by setting 'laststatus'
				-- statusline will be shown only if 'laststatus' == 3
				laststatus = 0, -- turn off the statusline in zen mode
			},
			gitsigns = true,
			tmux = true,
		},
	},
	keys = {
		{ "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen mode" },
	},
}
