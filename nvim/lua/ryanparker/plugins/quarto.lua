-- quarto-nvim: author/run Quarto documents with notebook-like workflows.
return {
  "quarto-dev/quarto-nvim",
  ft = { "quarto", "markdown" },
  dependencies = {
    "jmbuhr/otter.nvim",
    "nvim-treesitter/nvim-treesitter",
    "benlubas/molten-nvim",
  },
  opts = {
    lspFeatures = {
      enabled = true,
    },
    codeRunner = {
      enabled = true,
      default_method = "molten",
    },
  },
}
