-- oil.nvim: edit your filesystem like a normal Neovim buffer, and the file
-- explorer for this config. https://github.com/stevearc/oil.nvim
--
-- Press `-` to open the parent directory; edit it like text (create, rename,
-- move, delete files) then `:w` to apply. `<leader>e` opens a floating oil.
return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- Not lazy: oil needs to load before you open a directory (e.g. `nvim .`)
  -- so it can act as the default file explorer.
  lazy = false,
  keys = {
    { "-", "<cmd>Oil<CR>", desc = "Open parent directory (oil)" },
    { "<leader>e", function() require("oil").toggle_float() end, desc = "File explorer (oil)" },
  },
  opts = {
    default_file_explorer = true,
    columns = { "icon" },
    view_options = {
      show_hidden = true,
    },
    -- A few extra in-oil mappings on top of the defaults.
    keymaps = {
      ["q"] = "actions.close",
      ["<C-h>"] = false, -- keep window navigation (see keymaps.lua)
      ["<C-l>"] = false,
    },
  },
}
