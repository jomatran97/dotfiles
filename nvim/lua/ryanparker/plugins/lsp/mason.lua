-- Mason: installs and manages LSP servers, formatters, linters, and DAP adapters.
local has_go = vim.fn.executable("go") == 1

local function has_python_310()
  if vim.fn.executable("python3") == 0 then
    return false
  end

  local version = vim.fn.system({
    "python3",
    "-c",
    "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')",
  })
  if vim.v.shell_error ~= 0 then
    return false
  end

  local major, minor = version:match("^(%d+)%.(%d+)")
  major = tonumber(major)
  minor = tonumber(minor)
  return major and minor and (major > 3 or (major == 3 and minor >= 10))
end

local ensure_installed = {
  "stylua", -- lua
  "prettier", -- js / html / css / json / yaml / markdown
  "shfmt", -- shell formatter
  "shellcheck", -- shell linter
  "eslint_d", -- js/ts linter (nvim-lint)
  "hadolint", -- dockerfile linter (nvim-lint)
}

if has_python_310() then
  vim.list_extend(ensure_installed, {
    "black", -- python
    "isort", -- python imports
    "sqlfluff", -- sql / dbt formatter + linter
  })
end

if has_go then
  table.insert(ensure_installed, "goimports") -- go
end

return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    keys = {
      { "<leader>cm", "<cmd>Mason<CR>", desc = "Mason" },
    },
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },
  {
    -- Auto-installs the CLI formatters/linters used by conform.nvim & nvim-lint.
    -- This must load on startup so mason-tool-installer can attach its VimEnter
    -- hook and run `run_on_start` reliably.
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = ensure_installed,
      run_on_start = true,
    },
  },
}
