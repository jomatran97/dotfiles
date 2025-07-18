return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons"
    -- "folke/snacks.nvim",
  },
  lazy = false, -- neo-tree will lazily load itself
  opts = {
    popup_border_style = ""
    -- add options here
  },
    keys ={
    {
			"<leader>e",
      "<cmd>Neotree toggle<cr>"
      ,
			desc = "File Explorer",
		},
  }
}
