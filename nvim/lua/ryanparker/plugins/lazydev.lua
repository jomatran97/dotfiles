-- lazydev.nvim: configures LuaLS for editing this Neovim config — real
-- completion and types for the vim API, loaded lazily as you `require` modules.
-- (Replaced neodev.nvim as the meta; Neovim types are built in on 0.10+.)
-- https://github.com/folke/lazydev.nvim
return {
  "folke/lazydev.nvim",
  ft = "lua", -- only load in Lua files
  opts = {
    library = {
      -- Load luvit (vim.uv) types when the `vim.uv` word is found.
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
  },
}
