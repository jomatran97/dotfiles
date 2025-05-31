-- Highlight, edit, and navigate code

local M = {
  'nvim-treesitter/nvim-treesitter',
}

M.build = ':TSUpdate'

M.main = 'nvim-treesitter.configs'

M.opts = {

  -- Keep alphabetical order when managing this list
  ensure_installed = {
    'bash',
    'dockerfile',
    'lua',
    'python',
    'query',
    'regex',
    'sql',
    'toml',
    'vim',
    'vimdoc',
    'xml',
    'yaml',
  },

  auto_install = true,

  -- Enable highlighting
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },

  -- Enable indentation
  indent = {
    enable = true,
    disable = { 'ruby' },
  },

  -- Incrementally select objects by pressing Enter to expand and Backspace to collapse the selection
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<Enter>',
      node_incremental = '<Enter>',
      scope_incremental = false,
      node_decremental = '<Backspace>',
    },
  },
}

return M
