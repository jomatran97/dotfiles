-- nvim-ts-autotag: auto-close and rename HTML / JSX / TSX tags.
return {
  "windwp/nvim-ts-autotag",
  event = { "BufReadPre", "BufNewFile" },
  opts = {},
}
