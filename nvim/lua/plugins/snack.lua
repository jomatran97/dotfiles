-- QoL plugins

local M = {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
}

M.keys = {
  {
    '<leader>ff',
    function()
      Snacks.picker.files()
    end,
    mode = 'n',
    desc = 'Find files',
  },
  {
    '<leader>fc',
    function()
      Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
    end,
    mode = 'n',
    desc = 'Find configs',
  },
  {
    '<leader>fg',
    function()
      Snacks.picker.grep()
    end,
    mode = 'n',
    desc = 'Grep in current project',
  },
  {
    '<leader>/',
    function()
      -- require('fzf-lua').lgrep_curbuf()
    end,
    mode = 'n',
    desc = 'Grep in current buffer',
  },
  {
    '<leader><leader>',
    function()
      Snacks.picker.buffers {
        sort_lastused = true,
      }
    end,
    mode = 'n',
    desc = 'Find in open buffers',
  },
  {
    '<C-n>',
    function()
      Snacks.picker.explorer()
    end,
    mode = 'n',
    desc = 'Toggle file explorer',
  },
  {
    '<leader>n',
    function()
      Snacks.scratch()
    end,
    mode = 'n',
    desc = 'Toggle scratch buffer',
  },
  {
    '<leader>s',
    function()
      Snacks.scratch.select()
    end,
    mode = 'n',
    desc = 'Select scratch buffer',
  },
}

M.opts = {
  bigfile = {
    enabled = true,
  },

  indent = {
    enabled = true,
    animate = {
      enabled = false,
    },
    indent = {
      only_scope = true,
      only_current = true,
    },
    scope = {
      hl = 'LineNr',
    },
  },

  input = {
    enabled = true,
    style = 'fancy',
  },

  quickfile = {
    enabled = true,
  },

  picker = {
    enabled = true,
    prompt = ' ',
    sources = {},
    focus = 'input',
    layout = {
      cycle = true,
      preset = function()
        return vim.o.columns >= 120 and 'default' or 'vertical'
      end,
    },
  },

  dashboard = {
    enabled = true,
    preset = {
      pick = 'fzf_lua',
      header = [[
⠀⠀⠀⠀⠀⢀⣀⣠⣤⣤⣄⣀⠀⠀⠀⠀⠀⠀⢀⣤⠶⠿⠿⠿⣷⣦⣄⠀⠀⠀
⠀⠀⠀⣠⣾⣿⠿⠛⠛⠛⠛⠛⠿⣦⣄⠀⠀⡴⠋⠀⠀⠀⠀⠀⠀⠉⢻⣷⡄⠀
⠀⢀⣾⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠈⠙⣦⢸⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⠀
⠀⣾⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣯⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠀
⠀⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⠏⠀
⠀⢿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡌⠈⠢⢀⠀⠀⠀⠀⢀⣠⠾⠋⠀⠀
⠀⠈⢿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣐⠄⠂⠈⠉⠉⠑⠲⢯⡉⠁⠀⠀⠀⠀
⠀⠀⠀⠛⢷⣄⡀⠀⠀⠀⠀⠀⢀⠠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠙⣦⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⠙⠛⠒⠒⠒⠉⠁⡜⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⡟⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⣦⣀⠀⠀⠀⠀⠀⣀⣴⣿⠟⠁⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠿⢿⣶⣿⡿⠿⠛⠁⠀⠀⠀⠀⠀
    ]],
    },
    sections = {
      { section = 'header' },
      { section = 'keys', indent = 2, padding = 1 },
      { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
      { icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
    },
  },
}

return M
