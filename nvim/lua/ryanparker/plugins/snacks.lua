-- snacks.nvim: folke's QoL suite. One plugin that consolidates several:
--   * picker     -> fuzzy finder (replaces Telescope; works with TS `main`)
--   * scroll     -> smooth scrolling (replaces neoscroll)
--   * indent     -> indent guides + scope (replaces indent-blankline)
--   * scope/words/notifier/input -> editor niceties
-- https://github.com/folke/snacks.nvim
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false, -- a few modules must be set up before other plugins load
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },  -- disable heavy features for huge files
    quickfile = { enabled = true }, -- render `nvim file` before plugins load
    dashboard = { enabled = false }, -- start without a dashboard
    picker = { enabled = true },
    scroll = {
      enabled = true,
      animate = { duration = { step = 12, total = 220 }, easing = "linear" },
      animate_repeat = { delay = 80, duration = { step = 8, total = 120 }, easing = "linear" },
    },
    indent = { enabled = true },
    scope = { enabled = true },
    words = { enabled = true },     -- highlight + jump between LSP references
    notifier = { enabled = true, timeout = 3000 },
    input = { enabled = true },
  },
  keys = {
    -- Search / pickers (<leader>s)
    { "<leader>sf", function() Snacks.picker.files() end, desc = "Find files" },
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Live grep" },
    { "<leader>sG", function() Snacks.picker.git_files() end, desc = "Find git files" },
    { "<leader>sb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>sr", function() Snacks.picker.recent() end, desc = "Recent files" },
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Grep word/selection", mode = { "n", "x" } },
    { "<leader>/", function() Snacks.picker.lines() end, desc = "Search current buffer" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help pages" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
    { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume last picker" },

    -- LSP navigation via the picker UI
    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto definition" },
    { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto declaration" },
    { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto implementation" },
    { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto type definition" },

    -- Git / buffers / misc
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete buffer" },

    -- Jump between references of the symbol under the cursor (snacks.words)
    { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next reference" },
    { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev reference" },
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Debug helpers: `dd(...)` to inspect, `bt()` for a backtrace.
        _G.dd = function(...) Snacks.debug.inspect(...) end
        _G.bt = function() Snacks.debug.backtrace() end

        -- Toggles under <leader>u (which-key shows the on/off state).
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.scroll():map("<leader>uS")
        Snacks.toggle.indent():map("<leader>ug")
        Snacks.toggle.inlay_hints():map("<leader>uh")
      end,
    })
  end,
}
