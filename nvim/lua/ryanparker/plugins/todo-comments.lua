-- todo-comments.nvim: highlight and navigate TODO / FIXME / HACK / NOTE etc.
-- https://github.com/folke/todo-comments.nvim
return {
  "folke/todo-comments.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    highlight = {
      keyword = "fg",
      after = "fg",
    },
  },
  keys = {
    { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
    { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo comment" },
    { "<leader>st", "<cmd>TodoTrouble<cr>", desc = "Find todos (Trouble)" },
  },
}
