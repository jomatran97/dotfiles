return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    keys = {
      {
        "<leader>e",
        function()
          require("oil").toggle_float()
        end,
        desc = "File explorer",
      },
      {
        "-",
        function()
          require("oil").open()
        end,
        desc = "Open parent directory",
      },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      skip_confirm_for_simple_edits = true,
      view_options = { show_hidden = true },
      float = {
        padding = 2,
        max_width = 0.85,
        max_height = 0.85,
        border = "rounded",
        override = function(conf)
          local width = math.min(conf.width or 100, math.max(40, vim.o.columns - 4))
          local height = math.min(conf.height or 30, math.max(10, vim.o.lines - 6))
          conf.width = width
          conf.height = height
          conf.row = math.floor((vim.o.lines - height) / 2 - 1)
          conf.col = math.floor((vim.o.columns - width) / 2)
          return conf
        end,
      },
      keymaps = {
        ["<CR>"] = "actions.select",
        ["q"] = "actions.close",
        ["<C-s>"] = "actions.select_split",
        ["<C-v>"] = "actions.select_vsplit",
        ["<C-t>"] = "actions.select_tab",
        ["<C-h>"] = false,
        ["<C-l>"] = false,
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = vim.fn.executable("make") == 1,
      },
    },
    keys = {
      {
        "<leader>ff",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Live grep",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Buffers",
      },
      {
        "<leader>fh",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "Help",
      },
      {
        "<leader>fr",
        function()
          require("telescope.builtin").oldfiles()
        end,
        desc = "Recent files",
      },
      {
        "<leader>fd",
        function()
          require("telescope.builtin").diagnostics()
        end,
        desc = "Diagnostics",
      },
      {
        "<leader>fs",
        function()
          require("telescope.builtin").lsp_document_symbols()
        end,
        desc = "Document symbols",
      },
      {
        "<leader>fw",
        function()
          require("telescope.builtin").grep_string()
        end,
        desc = "Grep word under cursor",
      },
      {
        "<leader>/",
        function()
          require("telescope.builtin").current_buffer_fuzzy_find()
        end,
        desc = "Search in buffer",
      },
    },
    opts = function()
      local actions = require("telescope.actions")
      return {
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "➜ ",
          mappings = {
            i = {
              ["<Esc>"] = actions.close,
            },
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
    end,
  },

  {
    -- Same <M-h/j/k/l> keys as tmux; at the edge of the Neovim layout it moves to
    -- the neighbouring tmux pane (see the is_vim binds in tmux/tmux.conf).
    "mrjones2014/smart-splits.nvim",
    lazy = false, -- sets @pane-is-vim at startup for tmux
    keys = {
      {
        "<M-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        desc = "Go to left split/pane",
      },
      {
        "<M-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        desc = "Go to lower split/pane",
      },
      {
        "<M-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        desc = "Go to upper split/pane",
      },
      {
        "<M-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        desc = "Go to right split/pane",
      },
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>j",
        function()
          require("flash").jump()
        end,
        mode = { "n", "x", "o" },
        desc = "Easy jump",
      },
      {
        "<leader>J",
        function()
          require("flash").treesitter()
        end,
        mode = { "n", "x", "o" },
        desc = "Treesitter jump",
      },
    },
  },
}
