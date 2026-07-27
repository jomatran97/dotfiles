-- LSP configuration using Neovim 0.11's native vim.lsp API.
--   * mason-lspconfig installs + auto-enables the servers listed below
--   * nvim-lspconfig ships each server's base config (cmd / root_markers)
--   * blink.cmp provides completion capabilities
-- (mason.nvim itself and the formatter/linter tools live in mason.lua.)
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    vim.diagnostic.config({
      underline = true,
      virtual_text = true,
      severity_sort = true,
      float = { border = "rounded", source = true },
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.name == "ruff" then
          client.server_capabilities.hoverProvider = false
        end

        local function map(mode, keys, fn, desc)
          vim.keymap.set(mode, keys, fn, { buffer = event.buf, desc = "LSP: " .. desc })
        end
        map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
      end,
    })

    local ok, blink = pcall(require, "blink.cmp")
    if ok then
      vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities() })
    end

    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          workspace = { checkThirdParty = false },
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
      filetypes = { "html", "css", "ejs", "javascriptreact", "typescriptreact" },
    })

    local ensure_installed = {
      "lua_ls",
      "pyright",
      "ruff",
      "vtsls",
      "tailwindcss",
      "html",
      "cssls",
      "jsonls",
      "yamlls",
      "taplo",
      "marksman",
      "bashls",
      "emmet_ls",
      "dockerls",
      "terraformls",
      "helm_ls",
    }
    if vim.fn.executable("go") == 1 then
      table.insert(ensure_installed, "gopls")
    end

    require("mason-lspconfig").setup({
      ensure_installed = ensure_installed,
    })
  end,
}
