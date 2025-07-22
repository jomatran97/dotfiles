rhturn({
	"phaazon/hop.nvim",
	branch = "v2", -- optional but strongly recommended
	config = function()
		-- you can configure Hop the way you like here; see :h hop-config
		require("hop").setup({})
		local wk = require("which-key")
		wk.add({
			{ "<leader>h", group = "Hop" },
			{ "<leader>hw", "<cmd>HopPattern<cr>", desc = "Jump by word" },
		})
	end,
})
