return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	config = function()
		local wk = require("which-key")

		wk.setup({

			preset = "helix",
			plugins = {
				marks = true,
				registers = true,
				spelling = {
					enabled = true,
					suggestions = 20,
				},
				presets = {
					operators = true,
					motions = true,
					text_objects = true,
					windows = true,
					nav = true,
					z = true,
					g = true,
				},
			},
			win = {
				border = "rounded",
				no_overlap = true,
				padding = { 0, 2 }, -- extra window padding [top/bottom, right/left]
				title = true,
				title_pos = "center",
				zindex = 1000,
			},
			show_help = false,
			show_keys = false,
			disable = {
				buftypes = {},
			},
		})

		wk.add({
			-- NOTE: Windows config
			{ "<leader>w", group = "Windows" },
			{ "<leader>wv", "<C-w>v", desc = "Split window vertically" },
			{ "<leader>wh", "<C-w>s", desc = "Split window horizontally" },
			{ "<leader>we", "<C-w>=", desc = "Make splits equal size" },
			{ "<leader>wx", "<cmd>close<CR>", desc = "Close current split" },
		})
	end,
}
