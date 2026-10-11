return {
  { "nvim-lua/plenary.nvim", lazy = true },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  {
    "kylechui/nvim-surround",
    version = "*",
    opts = { keymaps = false }, -- only the sa/sd/sr scheme from `keys` below
    keys = {
      { "sa", "<Plug>(nvim-surround-normal)", mode = "n", desc = "Add surround" },
      { "saa", "<Plug>(nvim-surround-normal-cur)", mode = "n", desc = "Add surround line" },
      { "sA", "<Plug>(nvim-surround-normal-line)", mode = "n", desc = "Add surround linewise" },
      { "sAA", "<Plug>(nvim-surround-normal-cur-line)", mode = "n", desc = "Add surround current linewise" },
      { "sa", "<Plug>(nvim-surround-visual)", mode = "x", desc = "Add surround" },
      { "sA", "<Plug>(nvim-surround-visual-line)", mode = "x", desc = "Add surround linewise" },
      { "sd", "<Plug>(nvim-surround-delete)", mode = "n", desc = "Delete surround" },
      { "sr", "<Plug>(nvim-surround-change)", mode = "n", desc = "Replace surround" },
      { "sR", "<Plug>(nvim-surround-change-line)", mode = "n", desc = "Replace surround linewise" },
    },
  },
}
