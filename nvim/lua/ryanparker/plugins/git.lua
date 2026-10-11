return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
        end
        map("]h", function()
          gs.nav_hunk("next")
        end, "Next hunk")
        map("[h", function()
          gs.nav_hunk("prev")
        end, "Previous hunk")
        map("<leader>gs", gs.stage_hunk, "Stage/unstage hunk")
        map("<leader>gr", gs.reset_hunk, "Reset hunk")
        map("<leader>gS", gs.stage_buffer, "Stage buffer")
        map("<leader>gp", gs.preview_hunk, "Preview hunk")
        map("<leader>gb", gs.blame_line, "Blame line")
        map("<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Git: Diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Git: File history" },
    },
  },
}
