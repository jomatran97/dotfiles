-- csvview.nvim: better CSV/TSV viewing and editing.
return {
  "hat0uma/csvview.nvim",
  ft = { "csv", "tsv" },
  opts = {
    view = {
      display_mode = "border",
    },
  },
}
