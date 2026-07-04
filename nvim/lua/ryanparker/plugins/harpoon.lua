-- harpoon: mark a few files and jump between them quickly.
return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    {
      "<leader>ha",
      function()
        require("harpoon"):list():add()
      end,
      desc = "Harpoon file",
    },
    {
      "<leader>hh",
      function()
        require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
      end,
      desc = "Harpoon menu",
    },
    {
      "<leader>hn",
      function()
        require("harpoon"):list():next({ ui_nav_wrap = true })
      end,
      desc = "Harpoon next",
    },
    {
      "<leader>hp",
      function()
        require("harpoon"):list():prev({ ui_nav_wrap = true })
      end,
      desc = "Harpoon prev",
    },
    {
      "<leader>h1",
      function()
        require("harpoon"):list():select(1)
      end,
      desc = "Harpoon 1",
    },
    {
      "<leader>h2",
      function()
        require("harpoon"):list():select(2)
      end,
      desc = "Harpoon 2",
    },
    {
      "<leader>h3",
      function()
        require("harpoon"):list():select(3)
      end,
      desc = "Harpoon 3",
    },
    {
      "<leader>h4",
      function()
        require("harpoon"):list():select(4)
      end,
      desc = "Harpoon 4",
    },
  },
  opts = {},
}
