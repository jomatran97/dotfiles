-- yaml-companion.nvim: YAML schema detection and selection helpers.
return {
  "someone-stole-my-name/yaml-companion.nvim",
  ft = { "yaml" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "neovim/nvim-lspconfig",
  },
  opts = {},
}
