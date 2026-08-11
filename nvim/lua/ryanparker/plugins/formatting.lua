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
      sh = { "shfmt" },
      -- .ejs templates and Dockerfiles have no reliable CLI formatter;
      -- they fall back to the language server (lsp_format below).
    }

    if vim.fn.executable("go") == 1 then
      formatters_by_ft.go = { "goimports" } -- gofmt + import organisation
    end

    if vim.fn.executable("rustfmt") == 1 then
      formatters_by_ft.rust = { "rustfmt" } -- ships with the Rust toolchain (rustup)
    end

    if vim.fn.executable("terraform") == 1 then
      formatters_by_ft.terraform = { "terraform_fmt" }
      formatters_by_ft.hcl = { "terraform_fmt" }
    end

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
