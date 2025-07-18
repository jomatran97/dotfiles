return {
	"stevearc/aerial.nvim",
	lazy_load = true,
	opts = {},
	-- Optional dependencies
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
		"folke/which-key.nvim",
	},
	config = function()
		require("aerial").setup({
			-- optionally use on_attach to set keymaps when aerial has attached to a buffer
			on_attach = function(bufnr)
				vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
				vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
			end,
			layout = {
				min_width = 30,
			},
		})

		-- Global aerial keymaps
		local wk = require("which-key")
		wk.add({
			{ "<leader>o", group = "Outline/Aerial" },
			{ "<leader>o", "<cmd>AerialToggle!<CR>", desc = "Toggle Aerial" },
			{ "<leader>on", "<cmd>AerialNavToggle<CR>", desc = "Toggle Aerial Navigation" },
		})
	end,
}
