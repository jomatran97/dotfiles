local python_310 -- cached result of has_python_310()

-- Spawns python3 once, on first call; only invoked when mason-tool-installer loads.
local function has_python_310()
  if python_310 ~= nil then
    return python_310
  end
  python_310 = false
  if vim.fn.executable("python3") == 0 then
    return python_310
  end
  local version = vim.fn.system({
    "python3",
    "-c",
    "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')",
  })
  if vim.v.shell_error ~= 0 then
    return python_310
  end
  local major, minor = version:match("^(%d+)%.(%d+)")
  major, minor = tonumber(major), tonumber(minor)
  python_310 = (major and minor and (major > 3 or (major == 3 and minor >= 10))) and true or false
  return python_310
end

local function mason_tools()
  local tools = {
    "stylua",
    "prettier",
    "shfmt",
    "shellcheck",
    "eslint_d",
    "hadolint",
    "tflint",
    "cfn-lint",
  }
  if has_python_310() then
    vim.list_extend(tools, { "sqlfluff" })
  end
  return tools
end

local lsp_servers = {
  "lua_ls",
  "pyright",
  "ruff",
  "vtsls",
  "html",
  "cssls",
  "tailwindcss",
  "emmet_ls",
  "jsonls",
  "yamlls",
  "taplo",
  "marksman",
  "bashls",
  "dockerls",
  "terraformls",
  "jdtls",
}

return {
  "nvim-lua/plenary.nvim",
  { "b0o/schemastore.nvim", lazy = true },

  { "nvim-tree/nvim-web-devicons", lazy = true },

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
          require("oil").toggle_float()
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
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
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
  },

  {
    -- Same <M-h/j/k/l> keys as tmux; at the edge of the Neovim layout it moves to
    -- the neighbouring tmux pane (see the is_vim binds in tmux/tmux.conf).
    "mrjones2014/smart-splits.nvim",
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
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    keys = {
      { "sa", "<Plug>(nvim-surround-normal)", mode = "n", desc = "Add surround" },
      { "saa", "<Plug>(nvim-surround-normal-cur)", mode = "n", desc = "Add surround line" },
      { "sA", "<Plug>(nvim-surround-normal-line)", mode = "n", desc = "Add surround linewise" },
      { "sAA", "<Plug>(nvim-surround-normal-cur-line)", mode = "n", desc = "Add surround current linewise" },
      { "sa", "<Plug>(nvim-surround-visual)", mode = "x", desc = "Add surround" },
      { "sA", "<Plug>(nvim-surround-visual-line)", mode = "x", desc = "Add surround linewise" },
      { "sd", "<Plug>(nvim-surround-delete)", mode = "n", desc = "Delete surround" },
      { "sr", "<Plug>(nvim-surround-change)", mode = "n", desc = "Replace surround" },
      { "sR", "<Plug>(nvim-surround-change-line)", mode = "n", desc = "Replace surround linewise" },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        component_separators = "",
        section_separators = "",
      },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
        end
        map("]h", function()
          gs.nav_hunk("next")
        end, "Next hunk")
        map("[h", function()
          gs.nav_hunk("prev")
        end, "Previous hunk")
        map("<leader>gs", gs.stage_hunk, "Stage/unstage hunk")
        map("<leader>gp", gs.preview_hunk, "Preview hunk")
        map("<leader>gb", gs.blame_line, "Blame line")
      end,
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        char = { enabled = true }, -- enhance f/F/t/T without stealing `s` from surround
      },
    },
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

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 0,
      triggers = {
        { "<leader>", mode = { "n", "v" } },
        { "<localleader>", mode = { "n", "v" } },
      },
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "data / db" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>u", group = "ui" },
        { "<leader>W", proxy = "<C-w>", group = "window" },
        { "<leader>q", desc = "Quit window" },
        { "<leader>w", desc = "Save file" },
        { "<leader>x", desc = "Close buffer" },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local parsers = {
        "lua",
        "luadoc",
        "vim",
        "vimdoc",
        "bash",
        "python",
        "sql",
        "java",
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "json",
        "yaml",
        "toml",
        "dockerfile",
        "terraform",
        "hcl",
        "markdown",
        "markdown_inline",
      }
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(parsers)
      else
        vim.schedule(function()
          vim.notify("Install tree-sitter CLI for parser install/update: brew install tree-sitter", vim.log.levels.WARN)
        end)
      end
      pcall(vim.treesitter.language.register, "sql", "sql.dbt")
      pcall(vim.treesitter.language.register, "yaml", "yaml.cloudformation")
      pcall(vim.treesitter.language.register, "terraform", "terraform-vars")

      local function start(buf)
        local ft = vim.bo[buf].filetype
        if ft == "" then
          return
        end
        local lang = vim.treesitter.language.get_lang(ft) or ft
        if pcall(vim.treesitter.start, buf, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(args)
          start(args.buf)
        end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          start(buf)
        end
      end
    end,
  },

  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "enter" },
      signature = { enabled = true },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = true, auto_show_delay_ms = 500 } },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
    },
  },

  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = { ui = { border = "rounded" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim" },
    opts = function()
      return { ensure_installed = mason_tools(), run_on_start = true }
    end,
    config = function(_, opts)
      local installer = require("mason-tool-installer")
      installer.setup(opts)
      -- The plugin's own start hook listens for VimEnter, which has already fired
      -- by the time a VeryLazy load happens.
      installer.run_on_start()
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
      "b0o/schemastore.nvim",
    },
    config = function()
      vim.diagnostic.config({
        underline = true,
        virtual_text = { current_line = true },
        severity_sort = true,
        jump = { float = true },
        float = { border = "rounded", source = true },
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      vim.lsp.config("*", { capabilities = capabilities })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = "LSP: " .. desc })
          end
          -- Built-ins (0.11+): K hover, grr references, gri implementation,
          -- grn rename, gra code action, gO document symbols.
          map("n", "gd", vim.lsp.buf.definition, "Definition")
          map("n", "gD", vim.lsp.buf.declaration, "Declaration")
          map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
        end,
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library = { vim.env.VIMRUNTIME, "${3rd}/luv/library" },
            },
            telemetry = { enable = false },
          },
        },
      })
      vim.lsp.config("pyright", {
        settings = {
          pyright = { disableOrganizeImports = true },
          python = { analysis = { typeCheckingMode = "basic" } },
        },
      })
      vim.lsp.config("emmet_ls", {
        filetypes = { "html", "css", "javascriptreact", "typescriptreact" },
      })
      vim.lsp.config("terraformls", {
        filetypes = { "terraform", "terraform-vars", "hcl" },
      })

      local ok_schema, schemastore = pcall(require, "schemastore")
      vim.lsp.config("jsonls", {
        settings = {
          json = {
            schemas = ok_schema and schemastore.json.schemas() or nil,
            validate = { enable = true },
          },
        },
      })
      vim.lsp.config("yamlls", {
        filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values", "yaml.cloudformation" },
        settings = {
          yaml = {
            schemaStore = { enable = false, url = "" },
            schemas = ok_schema and schemastore.yaml.schemas() or {},
            validate = true,
            completion = true,
            hover = true,
            customTags = {
              "!And sequence",
              "!If sequence",
              "!Not sequence",
              "!Equals sequence",
              "!Or sequence",
              "!FindInMap sequence",
              "!Base64 scalar",
              "!Cidr sequence",
              "!Ref scalar",
              "!Sub scalar",
              "!Sub sequence",
              "!GetAtt scalar",
              "!GetAtt sequence",
              "!GetAZs scalar",
              "!ImportValue scalar",
              "!ImportValue sequence",
              "!Select sequence",
              "!Split sequence",
              "!Join sequence",
            },
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = lsp_servers,
        automatic_enable = { exclude = { "jdtls" } },
      })
    end,
  },

  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },

  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format",
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        ["yaml.cloudformation"] = { "prettier" },
        markdown = { "prettier" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        sql = { "sqlfluff" },
        ["sql.dbt"] = { "sqlfluff" },
        dbt = { "sqlfluff" },
        terraform = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
        hcl = { "terraform_fmt" },
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescript = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        dockerfile = { "hadolint" },
        sql = { "sqlfluff" },
        ["sql.dbt"] = { "sqlfluff" },
        dbt = { "sqlfluff" },
        terraform = { "tflint" },
        ["terraform-vars"] = { "tflint" },
        hcl = { "tflint" },
        ["yaml.cloudformation"] = { "cfn_lint" },
      }

      local function resolve_linter(name)
        local linter = lint.linters[name]
        if type(linter) == "function" then
          local ok, resolved = pcall(linter)
          if not ok then
            return nil
          end
          linter = resolved
        end
        return linter
      end

      local function linter_is_available(name)
        local linter = resolve_linter(name)
        if not linter then
          return false
        end
        local cmd = linter.cmd
        if type(cmd) == "function" then
          local ok, resolved = pcall(cmd)
          if not ok then
            return false
          end
          cmd = resolved
        end
        return type(cmd) == "string" and vim.fn.executable(cmd) == 1
      end

      local function try_lint(bufnr)
        local names = lint.linters_by_ft[vim.bo[bufnr].filetype]
        if not names then
          return
        end
        local available = vim.tbl_filter(linter_is_available, names)
        if vim.tbl_isempty(available) then
          return
        end
        lint.try_lint(available)
      end

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
        callback = function(args)
          try_lint(args.buf)
        end,
      })
    end,
  },

  {
    "PedramNavid/dbtpal",
    enabled = function()
      return vim.fn.executable("dbt") == 1
    end,
    ft = { "sql", "sql.dbt", "dbt" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      path_to_dbt = "dbt",
      protect_compiled_files = true,
      custom_dbt_syntax_enabled = true,
    },
    keys = {
      { "<leader>dr", "<cmd>DbtRun<CR>", desc = "dbt run model" },
      { "<leader>dt", "<cmd>DbtTest<CR>", desc = "dbt test model" },
      { "<leader>db", "<cmd>DbtBuild<CR>", desc = "dbt build" },
      { "<leader>dc", "<cmd>DbtCompile<CR>", desc = "dbt compile" },
      { "<leader>dD", "<cmd>DbtDebug<CR>", desc = "dbt debug" },
    },
  },

  {
    "tpope/vim-dadbod",
    cmd = { "DB" },
  },
  {
    "kristijanhusak/vim-dadbod-ui",
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    dependencies = { "tpope/vim-dadbod" },
    keys = { { "<leader>du", "<cmd>DBUIToggle<CR>", desc = "DB UI" } },
  },
  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown" },
  },
}
