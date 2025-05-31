-- Key suggestions

local M = {
  'folke/which-key.nvim',
}

M.event = 'VeryLazy'

M.opts = {
  preset = 'helix',

  icons = {
    mappings = vim.g.have_nerd_font,
  },

  spec = {
  },
}

return M
