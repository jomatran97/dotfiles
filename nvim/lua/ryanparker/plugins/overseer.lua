-- overseer.nvim: task runner for build/devops workflows.
return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerToggle", "OverseerQuickAction" },
  keys = {
    { "<leader>or", "<cmd>OverseerRun<CR>", desc = "Run task" },
    { "<leader>ot", "<cmd>OverseerToggle<CR>", desc = "Task list" },
  },
  opts = {},
}
