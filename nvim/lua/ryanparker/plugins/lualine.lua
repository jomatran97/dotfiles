-- Statusline.
return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = function()
    local lsp_aliases = {
      lua_ls = "Lua",
      vtsls = "TS",
      tsserver = "TS",
      pyright = "Py",
      ruff = "Ruff",
      bashls = "Bash",
      html = "HTML",
      cssls = "CSS",
      jsonls = "JSON",
      yamlls = "YAML",
      taplo = "TOML",
      marksman = "MD",
      emmet_ls = "Emmet",
      dockerls = "Docker",
      gopls = "Go",
    }


    local filetype_labels = {
      lua = "lua",
      python = "python",
      javascript = "js",
      javascriptreact = "jsx",
      typescript = "ts",
      typescriptreact = "tsx",
      html = "html",
      css = "css",
      json = "json",
      yaml = "yaml",
      toml = "toml",
      markdown = "markdown",
      sh = "shell",
      bash = "bash",
      go = "go",
      rust = "rust",
      sql = "sql",
      dbt = "dbt",
      dockerfile = "docker",
      ejs = "ejs",
    }

    local function lsp_names()
      local bufnr = vim.api.nvim_get_current_buf()
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      if not clients or vim.tbl_isempty(clients) then
        return ""
      end

      local seen = {}
      local names = {}
      for _, client in ipairs(clients) do
        local name = client.name and (lsp_aliases[client.name] or client.name)
        if name and not seen[name] then
          seen[name] = true
          table.insert(names, name)
        end
      end

      if vim.tbl_isempty(names) then
        return ""
      end

      table.sort(names)

      local max_names = 3
      if #names > max_names then
        return table.concat(vim.list_slice(names, 1, max_names), ",") .. "+" .. (#names - max_names)
      end

      return table.concat(names, ",")
    end

    local function lazy_updates()
      local ok, lazy_status = pcall(require, "lazy.status")
      if ok and lazy_status.has_updates() then
        return lazy_status.updates()
      end
      return ""
    end

    local function scrollbar()
      local current = vim.fn.line(".")
      local total = vim.fn.line("$")
      if total == 0 then
        return ""
      end
      local chars = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
      local index = math.ceil(current / total * #chars)
      return chars[math.max(1, math.min(index, #chars))]
    end

    return {
      options = {
        theme = "catppuccin-mocha",
        globalstatus = true,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
          statusline = { "lazy", "mason" },
        },
      },
      sections = {
        lualine_a = { { "mode", icon = "" } },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
          {
            "filename",
            path = 1,
            symbols = {
              modified = " ●",
              readonly = " 󰌾",
              unnamed = "[No Name]",
              newfile = "[New]",
            },
          },
        },
        lualine_x = {
          {
            lazy_updates,
            cond = function()
              local ok, lazy_status = pcall(require, "lazy.status")
              return ok and lazy_status.has_updates()
            end,
            color = { fg = "#f9e2af" },
          },
          {
            lsp_names,
            icon = "",
            cond = function()
              return lsp_names() ~= ""
            end,
          },
          {
            "encoding",
            fmt = string.upper,
            cond = function()
              return (vim.bo.fenc or vim.go.enc):lower() ~= "utf-8"
            end,
          },
          {
            "fileformat",
            cond = function()
              return vim.bo.fileformat ~= "unix"
            end,
          },
          {
            "filetype",
            icon_only = false,
            icon = { align = "left" },
            fmt = function(str)
              return filetype_labels[vim.bo.filetype] or str
            end,
          },
        },
        lualine_y = { scrollbar },
        lualine_z = { "location" },
      },
    }
  end,
}
