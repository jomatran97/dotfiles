return {
  'stevearc/oil.nvim',
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
     delete_to_trash = true,
      float = {
    -- Padding around the floating window
    padding = 2,
    -- max_width and max_height can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    max_width = 0.7,  -- 80% of screen width
    max_height = 0.7, -- 80% of screen height
    border = "rounded",
    win_options = {
      winblend = 0,
    },
    -- preview_split: Split direction: "auto", "left", "right", "above", "below".
    preview_split = "auto",
  },
     win_options = {
    wrap = true,
    signcolumn = "no",
    cursorcolumn = false,
    foldcolumn = "0",
    spell = false,
    list = false,
    conceallevel = 3,
    concealcursor = "nvic",
  },
 view_options = {
    show_hidden = true,
  }
  },
  dependencies = { { "echasnovski/mini.icons", opts = { } }},
  lazy = false,
  keys ={
    {
			"-",
      "<cmd>Oil --float<cr>"
      ,
			desc = "Toggle float file explorer",
		},
  }
}

