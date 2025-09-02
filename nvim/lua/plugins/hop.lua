-- return {
-- 	"phaazon/hop.nvim",
-- 	branch = "v2", -- optional but strongly recommended
-- 	config = function()
-- 		-- you can configure Hop the way you like here; see :h hop-config
-- 		require("hop").setup({})
-- 		local wk = require("which-key")
-- 		wk.add({
-- 			{ "<leader>h", group = "Hop" },
-- 			{ "<leader>hw", "<cmd>HopPattern<cr>", desc = "[H]op by word" },
-- 			{ "<leader>hl", "<cmd>HopChar1<cr>", desc = "[H]op by letter" },
-- 		})
-- 	end,
-- }
return {
	"folke/flash.nvim",
	event = "VeryLazy",
	opts = {},
  -- stylua: ignore
	config = function()
		-- you can configure Hop the way you like here; see :h hop-config
		local wk = require("which-key")
		wk.add({
    { "<leader>h", group = "Hop" },
    { "<leader>hs", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    -- { "<leader>hS", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "<leader>hr", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    -- { "<leader>hR", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
		})
	end,
}
