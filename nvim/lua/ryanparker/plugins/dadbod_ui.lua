-- vim-dadbod-ui: database browser/UI on top of vim-dadbod.
return {
  "kristijanhusak/vim-dadbod-ui",
  dependencies = { "tpope/vim-dadbod" },
  cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
  keys = {
    { "<leader>du", "<cmd>DBUIToggle<CR>", desc = "Database UI" },
  },
  init = function()
    vim.g.db_ui_use_nerd_fonts = 1
  end,
}
