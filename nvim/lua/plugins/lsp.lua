-- LSP configs

local M = {
  'neovim/nvim-lspconfig',
}

M.dependencies = { 'saghen/blink.cmp', 'ibhagwan/fzf-lua' }

function M.config()
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
    callback = function(event)
      local bufmap = require('settings.utils').bufmap
      -- local fzf = require 'fzf-lua'

      bufmap('<leader>dq', vim.diagnostic.setloclist, 'Open diagnostic quickfix list', event.buf)
      bufmap('<leader>df', vim.diagnostic.open_float, 'Open diagnostic in floating window', event.buf)
      bufmap('K', vim.lsp.buf.hover, 'Show info under cursor', event.buf)

      bufmap('<leader>ds', function()
        Snacks.picker.lsp_type_definitions()
      end, 'Show type definitions', event.buf)

      bufmap('gr', function()
        Snacks.picker.lsp_references()
      end, 'Show references', event.buf)

      bufmap('gd', function()
        Snacks.picker.lsp_definitions()
      end, 'Go to definition', event.buf)

      bufmap('gI', function()
        Snacks.picker.lsp_implementations()
      end, 'Show implementations', event.buf)
      -- bufmap('ca', function() Snacks.picker.() end,, 'Show code actions', event.buf)

      -- Diagnostic setup
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        },
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }
    end,
  })

  vim.api.nvim_create_autocmd('LspDetach', {
    group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
    callback = function(event2)
      vim.lsp.buf.clear_references()
    end,
  })

  -- Wire up the LSPs
  -- Make sure to install LSP servers with brew or npm

  -- true in the args will merge with vim.lsp.make_client_capabilities() table
  local caps = require('blink.cmp').get_lsp_capabilities(nil, true)

  vim.lsp.config('*', {
    capabilities = caps,
  })

  vim.lsp.enable {
    'lua_ls',
    'jsonls',
    'dockerls',
    'sqls',
    'pyright',

  }
end

return M
