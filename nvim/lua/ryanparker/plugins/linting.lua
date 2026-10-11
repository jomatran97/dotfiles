return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
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
        markdown = { "markdownlint-cli2" },
        yaml = { "yamllint" },
        ["yaml.cloudformation"] = { "cfn_lint" },
      }

      -- Slow linters: never run while typing (InsertLeave).
      local slow = { sqlfluff = true }

      -- Per-linter availability cache. Positive results are kept for the session;
      -- negative ones are dropped when mason finishes installing tools.
      local availability = {}

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
        local cached = availability[name]
        if cached ~= nil then
          return cached
        end
        local available = false
        local linter = resolve_linter(name)
        if linter then
          local cmd = linter.cmd
          if type(cmd) == "function" then
            local ok, resolved = pcall(cmd)
            cmd = ok and resolved or nil
          end
          available = type(cmd) == "string" and vim.fn.executable(cmd) == 1
        end
        availability[name] = available
        return available
      end

      local function linters_for(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "yaml" and vim.api.nvim_buf_get_name(bufnr):find("/%.github/workflows/") then
          return { "actionlint" }
        end
        return lint.linters_by_ft[ft]
      end

      local function try_lint(bufnr, opts)
        local names = linters_for(bufnr)
        if not names then
          return
        end
        local available = vim.tbl_filter(function(name)
          if opts and opts.skip_slow and slow[name] then
            return false
          end
          return linter_is_available(name)
        end, names)
        if vim.tbl_isempty(available) then
          return
        end
        lint.try_lint(available)
      end

      local group = vim.api.nvim_create_augroup("nvim_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
        group = group,
        callback = function(args)
          try_lint(args.buf)
        end,
      })
      vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        callback = function(args)
          try_lint(args.buf, { skip_slow = true })
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MasonToolsUpdateCompleted",
        callback = function()
          for name, ok in pairs(availability) do
            if not ok then
              availability[name] = nil
            end
          end
        end,
      })
    end,
  },
}
