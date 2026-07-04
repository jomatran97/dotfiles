-- dbtpal: dbt-aware editing, navigation, and dbt commands.
return {
  "PedramNavid/dbtpal",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    path_to_dbt = "dbt",
    protect_compiled_files = true,
    custom_dbt_syntax_enabled = true,
  },
  keys = {
    { "<leader>dr", "<cmd>DbtRun<CR>", desc = "dbt run model" },
    { "<leader>dt", "<cmd>DbtTest<CR>", desc = "dbt test model" },
    { "<leader>db", "<cmd>DbtBuild<CR>", desc = "dbt build" },
    { "<leader>dc", "<cmd>DbtCompile<CR>", desc = "dbt compile" },
    { "<leader>dD", "<cmd>DbtDebug<CR>", desc = "dbt debug" },
  },
}
