-- Catppuccin colour scheme (Mocha flavour, to match your Ghostty theme).
return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000, -- load before everything else
  lazy = false,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = false,
      lsp_styles = {
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
          ok = { "undercurl" },
        },
      },
      custom_highlights = function(colors)
        local todo = function(fg, style)
          return { fg = fg, style = { "bold", style } }
        end

        return {
          Normal = { fg = colors.text, bg = colors.mantle },
          NormalNC = { fg = colors.text, bg = colors.mantle },
          SignColumn = { fg = colors.overlay0, bg = colors.mantle },
          FoldColumn = { fg = colors.overlay0, bg = colors.mantle },
          EndOfBuffer = { fg = colors.mantle, bg = colors.mantle },
          CursorLine = { bg = colors.surface0 },
          LineNr = { fg = colors.surface2, bg = colors.mantle },
          CursorLineNr = { fg = colors.lavender, bg = colors.mantle, style = { "bold" } },
          Comment = { fg = colors.subtext0, style = {} },
          Visual = { bg = colors.surface1, style = { "bold" } },
          WinSeparator = { fg = colors.surface2 },
          NormalFloat = { fg = colors.text, bg = colors.crust },
          FloatBorder = { fg = colors.lavender, bg = colors.crust },
          Pmenu = { fg = colors.text, bg = colors.crust },
          PmenuSel = { fg = colors.text, bg = colors.surface1, style = { "bold" } },
          DiagnosticVirtualTextError = { fg = colors.red, bg = colors.base, style = {} },
          DiagnosticVirtualTextWarn = { fg = colors.yellow, bg = colors.base, style = {} },
          DiagnosticVirtualTextInfo = { fg = colors.sky, bg = colors.base, style = {} },
          DiagnosticVirtualTextHint = { fg = colors.teal, bg = colors.base, style = {} },

          SpellBad = { sp = colors.red, style = { "undercurl" } },
          SpellCap = { sp = colors.yellow, style = { "underdotted" } },
          SpellLocal = { sp = colors.sky, style = { "underdashed" } },
          SpellRare = { sp = colors.teal, style = { "underdouble" } },

          TodoFgFIX = todo(colors.red, "undercurl"),
          TodoFgTODO = todo(colors.sky, "underdouble"),
          TodoFgHACK = todo(colors.peach, "underdotted"),
          TodoFgWARN = todo(colors.yellow, "underdashed"),
          TodoFgPERF = todo(colors.mauve, "underdashed"),
          TodoFgNOTE = todo(colors.teal, "underdotted"),
          TodoFgTEST = todo(colors.pink, "underdotted"),
        }
      end,
      integrations = {
        blink_cmp = true,
        gitsigns = true,
        treesitter = true,
        snacks = true,
        mason = true,
        which_key = true,
        native_lsp = { enabled = true },
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
