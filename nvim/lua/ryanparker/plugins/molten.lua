-- molten-nvim: Jupyter-style notebook/repl execution inside Neovim.
return {
  "benlubas/molten-nvim",
  version = false,
  ft = { "python", "markdown", "quarto" },
  cmd = {
    "MoltenInit",
    "MoltenEvaluateLine",
    "MoltenReevaluateCell",
    "MoltenDelete",
    "MoltenOpenInBrowser",
  },
  init = function()
    vim.g.molten_auto_open_output = false
    vim.g.molten_virt_text_output = true
  end,
}
