-- kubectl.nvim: Kubernetes workflow inside Neovim.
return {
  "ramilito/kubectl.nvim",
  cmd = { "Kubectl", "Kubectx", "Kubens" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    { "<leader>kk", "<cmd>Kubectl<CR>", desc = "Kubectl" },
  },
  opts = {},
}
