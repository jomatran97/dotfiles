-- Treesitter (nvim-treesitter `main` branch) — syntax highlighting + indentation.
--
-- The `main` branch is now the default and REMOVED the old
-- `require("nvim-treesitter.configs").setup({...})` API. Instead we install the
-- parsers we want and start highlighting ourselves via a FileType autocmd.
local has_tree_sitter_cli = vim.fn.executable("tree-sitter") == 1

local function warn_missing_tree_sitter_cli()
  if vim.g.ryanparker_treesitter_cli_warned then
    return
  end
  vim.g.ryanparker_treesitter_cli_warned = true

  vim.schedule(function()
    vim.notify(
      "nvim-treesitter needs the `tree-sitter` CLI in PATH to install/update parsers. Install it with your package manager (for example: `brew install tree-sitter`).",
      vim.log.levels.WARN,
      { title = "nvim-treesitter" }
    )
  end)
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = function()
    if has_tree_sitter_cli then
      vim.cmd("TSUpdate")
    else
      warn_missing_tree_sitter_cli()
    end
  end,
  lazy = false, -- register the FileType autocmd before any file opens
  config = function()
    local parsers = {
      "lua",
      "luadoc",
      "vim",
      "vimdoc",
      "bash",
      "python",
      "sql",
      "javascript",
      "typescript",
      "tsx",
      "html",
      "css",
      "json",
      "yaml",
      "toml",
      "go",
      "gomod",
      "gosum",
      "rust",
      "dockerfile",
      "terraform",
      "hcl",
      "csv",
      "embedded_template", -- EJS / ERB templates
      "markdown",
      "markdown_inline",
    }

    -- Install any missing parsers when the tree-sitter CLI is available.
    if has_tree_sitter_cli then
      require("nvim-treesitter").install(parsers)
    else
      warn_missing_tree_sitter_cli()
    end

    -- Treat .ejs files as embedded templates (HTML + embedded JS).
    pcall(vim.treesitter.language.register, "embedded_template", "ejs")
    -- If a plugin marks dbt models with a dedicated `dbt` filetype, use SQL
    -- Treesitter highlighting/indentation for them.
    pcall(vim.treesitter.language.register, "sql", "dbt")

    -- Start Treesitter highlighting + indentation for a buffer, if its parser
    -- is installed. pcall guards the case where the parser isn't ready yet.
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

    -- Apply to any buffers already open when this runs.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        start(buf)
      end
    end
  end,
}
