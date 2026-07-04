-- tailwind-tools.nvim: Tailwind CSS utilities, colors, and sorting helpers.
return {
  "luckasRanarison/tailwind-tools.nvim",
  ft = {
    "html",
    "css",
    "javascriptreact",
    "typescriptreact",
    "svelte",
    "vue",
    "astro",
    "templ",
    "heex",
  },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {},
}
