return {
  {
    "PedramNavid/dbtpal",
    enabled = function()
      return vim.fn.executable("dbt") == 1
    end,
    ft = { "sql", "sql.dbt", "dbt" },
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
  },

  {
    "tpope/vim-dadbod",
    cmd = { "DB" },
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    dependencies = { "tpope/vim-dadbod" },
    keys = { { "<leader>du", "<cmd>DBUIToggle<CR>", desc = "DB UI" } },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },

  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown" },
  },
}
