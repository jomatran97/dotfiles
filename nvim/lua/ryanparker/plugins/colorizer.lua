-- nvim-colorizer.lua: inline color previews for CSS/Tailwind/hex/rgb.
return {
  "NvChad/nvim-colorizer.lua",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    user_default_options = {
      tailwind = true,
      mode = "virtualtext",
    },
  },
}
