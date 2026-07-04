-- Formatting via conform.nvim. Runs the right CLI formatter per filetype,
-- falling back to the language server when no formatter is configured.
return {
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
      desc = "Format buffer",
    },
  },
  opts = function()
    local formatters_by_ft = {
      lua = { "stylua" },
      python = { "isort", "black" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      json = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
      go = { "goimports" }, -- gofmt + import organisation
      rust = { "rustfmt" }, -- ships with the Rust toolchain (rustup)
      sh = { "shfmt" },
      terraform = { "terraform_fmt" },
      hcl = { "terraform_fmt" },
      -- .ejs templates and Dockerfiles have no reliable CLI formatter;
      -- they fall back to the language server (lsp_format below).
    }

    if vim.fn.executable("sqlfluff") == 1 then
      formatters_by_ft.sql = { "sqlfluff" }
      formatters_by_ft.dbt = { "sqlfluff" }
    end

    return {
      formatters_by_ft = formatters_by_ft,
      -- Format on save, with an LSP fallback and a safety timeout.
      format_on_save = function(bufnr)
        return { timeout_ms = 1000, lsp_format = "fallback" }
      end,
    }
  end,
}
