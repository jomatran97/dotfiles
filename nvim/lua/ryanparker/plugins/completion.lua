-- Autocompletion with blink.cmp (the current meta — fast, batteries-included).
-- Uses Neovim's native vim.snippet engine with friendly-snippets, so no
-- LuaSnip/nvim-cmp machinery is needed. https://cmp.saghen.dev
return {
  "saghen/blink.cmp",
  dependencies = { "rafamadriz/friendly-snippets" },
  -- Pin the stable v1 line (downloads a prebuilt fuzzy-matcher binary).
  -- v2 is still landing breaking changes as of mid-2026.
  version = "1.*",
  event = "InsertEnter",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      -- 'default': C-y accept, C-n/C-p select, C-space menu, C-e hide.
      preset = "default",
      -- Add familiar Enter-to-accept and Tab cycling on top of the preset.
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
    },
    appearance = {
      nerd_font_variant = "mono",
    },
    completion = {
      menu = { border = "rounded" },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 250,
        window = { border = "rounded" },
      },
    },
    signature = {
      enabled = true,
      window = { border = "rounded" },
    },
    sources = {
      default = { "lazydev", "lsp", "path", "snippets", "buffer" },
      providers = {
        -- Completion for `require("…")` and `---@module` in your config.
        lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
      },
    },
    -- Rust matcher when available, Lua fallback otherwise.
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
