-- which-key: a popup that shows the keybindings available after you start
-- a sequence (e.g. press <Space> and wait). Also labels the leader groups.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    -- Group labels shown for leader prefixes.
    spec = {
      { "<leader>a", group = "ai" },
      { "<leader>b", group = "buffer" },
      { "<leader>c", group = "code" },
      { "<leader>d", group = "data / db / dbt" },
      { "<leader>g", group = "git" },
      { "<leader>h", group = "harpoon" },
      { "<leader>k", group = "kubernetes" },
      { "<leader>o", group = "ops / tasks" },
      { "<leader>q", group = "quit / session" },
      { "<leader>r", group = "refactor / requests" },
      { "<leader>s", group = "search / split" },
      { "<leader>t", group = "tests" },
      { "<leader>u", group = "ui / toggle" },
      { "<leader>x", group = "trouble" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer-local keymaps (which-key)",
    },
  },
}
