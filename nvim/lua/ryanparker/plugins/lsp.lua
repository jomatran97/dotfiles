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
    "ruff",
    "terraform",
    "markdownlint-cli2",
    "yamllint",
    "actionlint",
  }
  if has_python_310() then
    vim.list_extend(tools, { "sqlfluff" })
  end
  return tools
end

local lsp_servers = {
  "lua_ls",
  "basedpyright",
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
    init = function()
      -- Applied at startup so it is in place before any LSP client attaches.
      vim.diagnostic.config({
        underline = true,
        virtual_text = { current_line = true },
        severity_sort = true,
        jump = { float = true },
        float = { border = "rounded", source = true },
      })
    end,
    config = function()
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
      vim.lsp.config("basedpyright", {
        settings = {
          basedpyright = {
            disableOrganizeImports = true,
            analysis = { typeCheckingMode = "standard" },
          },
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

  { "b0o/schemastore.nvim", lazy = true },

  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
}
