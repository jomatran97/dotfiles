-- nvim-lint: standalone linters that run alongside the language servers.
-- ruff already lints Python via LSP and clippy covers Rust, so this fills the
-- gaps: ESLint for JS/TS, shellcheck for shells, hadolint for Dockerfiles, and
-- sqlfluff for SQL/dbt when it is available.
-- https://github.com/mfussenegger/nvim-lint
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "mason-org/mason.nvim" },
  config = function()
    local lint = require("lint")
    local linters_by_ft = {
      javascript = { "eslint_d" },
      javascriptreact = { "eslint_d" },
      typescript = { "eslint_d" },
      typescriptreact = { "eslint_d" },
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      dockerfile = { "hadolint" },
    }

    if vim.fn.executable("sqlfluff") == 1 then
      linters_by_ft.sql = { "sqlfluff" }
      linters_by_ft.dbt = { "sqlfluff" }
    end

    lint.linters_by_ft = linters_by_ft

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

      return type(cmd) == "string" and cmd ~= "" and vim.fn.executable(cmd) == 1
    end

    local function try_lint(bufnr)
      local ft = vim.bo[bufnr].filetype
      local names = lint.linters_by_ft[ft]
      if not names then
        return
      end

      local available = vim.tbl_filter(linter_is_available, names)
      if vim.tbl_isempty(available) then
        return
      end

      vim.api.nvim_buf_call(bufnr, function()
        lint.try_lint(available)
      end)
    end

    -- Re-lint on common events, but only for filetypes with configured linters.
    local group = vim.api.nvim_create_augroup("nvim_lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = group,
      callback = function(args)
        try_lint(args.buf)
      end,
    })
  end,
}
