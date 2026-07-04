-- codecompanion.nvim: AI chat/edit/generate workflows.
return {
  "olimorris/codecompanion.nvim",
  cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "zbirenbaum/copilot.lua",
  },
  keys = {
    { "<leader>ac", "<cmd>CodeCompanionChat<CR>", desc = "AI chat" },
    { "<leader>aa", "<cmd>CodeCompanionActions<CR>", desc = "AI actions" },
  },
  opts = {
    strategies = {
      chat = { adapter = "copilot" },
      inline = { adapter = "copilot" },
      cmd = { adapter = "copilot" },
    },
  },
}
