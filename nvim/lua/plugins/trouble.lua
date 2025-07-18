return {
	"folke/trouble.nvim",
	dependencies = {
		"folke/which-key.nvim",
	},
	opts = {}, -- for default options, refer to the configuration section for custom setup.
	config = function()
		require("trouble").setup({})

		local wk = require("which-key")
		wk.add({
			-- Code/Diagnostics group
			{ "<leader>d", group = "Diagnostics" },
			{ "<leader>ds", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols (Trouble)" },
			{
				"<leader>dl",
				"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{ "<leader>dd", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
			{ "<leader>dD", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
			{ "<leader>dL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List (Trouble)" },
			{ "<leader>dQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List (Trouble)" },
		})
	end,
}
