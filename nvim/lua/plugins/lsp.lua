return {
	"neovim/nvim-lspconfig",
	dependencies = {
		-- Automatically install LSPs and related tools to stdpath for Neovim
		{ "mason-org/mason.nvim", config = true }, -- NOTE: Must be loaded before dependants
		-- mason-lspconfig:
		-- - Bridges the gap between LSP config names (e.g. "lua_ls") and actual Mason package names (e.g. "lua-language-server").
		-- - Used here only to allow specifying language servers by their LSP name (like "lua_ls") in `ensure_installed`.
		-- - It does not auto-configure servers — we use vim.lsp.config() + vim.lsp.enable() explicitly for full control.
		"mason-org/mason-lspconfig.nvim",
		-- mason-tool-installer:
		-- - Installs LSPs, linters, formatters, etc. by their Mason package name.
		-- - We use it to ensure all desired tools are present.
		-- - The `ensure_installed` list works with mason-lspconfig to resolve LSP names like "lua_ls".
		"WhoIsSethDaniel/mason-tool-installer.nvim",

		-- Useful status updates for LSP.
		{
			"j-hui/fidget.nvim",
			opts = {
				notification = {
					window = {
						winblend = 0, -- Background color opacity in the notification window
					},
				},
			},
		},

		-- Allows extra capabilities provided by nvim-cmp
		"hrsh7th/cmp-nvim-lsp",

		-- Which-key for keymaps
		"folke/which-key.nvim",
	},
	config = function()
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
			-- Create a function that lets us more easily define mappings specific LSP related items.
			-- It sets the mode, buffer and description for us each time.
			callback = function(event)
				local wk = require("which-key")

				-- Register LSP keymaps with which-key
				wk.add({
					-- Navigation mappings
					{
						"gd",
						require("telescope.builtin").lsp_definitions,
						desc = "LSP: [G]oto [D]efinition",
						buffer = event.buf,
					},
					{
						"gr",
						require("telescope.builtin").lsp_references,
						desc = "LSP: [G]oto [R]eferences",
						buffer = event.buf,
					},
					{
						"gI",
						require("telescope.builtin").lsp_implementations,
						desc = "LSP: [G]oto [I]mplementation",
						buffer = event.buf,
					},
					{ "gD", vim.lsp.buf.declaration, desc = "LSP: [G]oto [D]eclaration", buffer = event.buf },
					{ "K", vim.lsp.buf.hover, desc = "LSP: Hover Documentation", buffer = event.buf },

					-- Leader key mappings
					{ "<leader>l", group = "LSP common", buffer = event.buf },
					{
						"<leader>lD",
						require("telescope.builtin").lsp_type_definitions,
						desc = "LSP: Type [D]efinition",
						buffer = event.buf,
					},
					{
						"<leader>ld",
						require("telescope.builtin").lsp_document_symbols,
						desc = "LSP: [D]ocument [S]ymbols",
						buffer = event.buf,
					},
					{ "<leader>r", group = "Rename", buffer = event.buf },
					{ "<leader>rn", vim.lsp.buf.rename, desc = "LSP: [R]e[n]ame", buffer = event.buf },

					{ "<leader>c", group = "Code action", buffer = event.buf },
					{ "<leader>ca", vim.lsp.buf.code_action, desc = "LSP: [C]ode [A]ction", buffer = event.buf },

					-- Document/Workspace groups

					{ "<leader>w", group = "Workspace", buffer = event.buf },
					{
						"<leader>ws",
						require("telescope.builtin").lsp_dynamic_workspace_symbols,
						desc = "LSP: [W]orkspace [S]ymbols",
						buffer = event.buf,
					},
					{
						"<leader>wa",
						vim.lsp.buf.add_workspace_folder,
						desc = "LSP: [W]orkspace [A]dd Folder",
						buffer = event.buf,
					},
					{
						"<leader>wr",
						vim.lsp.buf.remove_workspace_folder,
						desc = "LSP: [W]orkspace [R]emove Folder",
						buffer = event.buf,
					},
					{
						"<leader>wl",
						function()
							print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
						end,
						desc = "LSP: [W]orkspace [L]ist Folders",
						buffer = event.buf,
					},
				})

				-- The following two autocommands are used to highlight references of the
				-- word under your cursor when your cursor rests there for a little while.
				--    See `:help CursorHold` for information about when this is executed
				-- When you move your cursor, the highlights will be cleared (the second autocommand).
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
					local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.document_highlight,
					})

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						buffer = event.buf,
						group = highlight_augroup,
						callback = vim.lsp.buf.clear_references,
					})

					vim.api.nvim_create_autocmd("LspDetach", {
						group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
						callback = function(event2)
							vim.lsp.buf.clear_references()
							vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
						end,
					})
				end

				-- The following code creates a keymap to toggle inlay hints in your
				-- code, if the language server you are using supports them
				if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
					wk.add({
						{
							"<leader>th",
							function()
								vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
							end,
							desc = "LSP: [T]oggle Inlay [H]ints",
							buffer = event.buf,
						},
					})
				end
			end,
		})

		-- LSP servers and clients are able to communicate to each other what features they support.
		-- By default, Neovim doesn't support everything that is in the LSP specification.
		-- When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
		-- So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

		-- Enable the following language servers
		--
		-- Add any additional override configuration in the following tables. Available keys are:
		-- - cmd (table): Override the default command used to start the server
		-- - filetypes (table): Override the default list of associated filetypes for the server
		-- - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
		-- - settings (table): Override the default settings passed when initializing the server.
		local servers = {
			lua_ls = {
				settings = {
					Lua = {
						completion = {
							callSnippet = "Replace",
						},
						runtime = { version = "LuaJIT" },
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
						},
						diagnostics = {
							globals = { "vim" },
							disable = { "missing-fields" },
						},
						format = {
							enable = false,
						},
					},
				},
			},
			pylsp = {
				settings = {
					pylsp = {
						plugins = {
							pyflakes = { enabled = true },
							pycodestyle = { enabled = true },
							autopep8 = { enabled = true },
							yapf = { enabled = true },
							mccabe = { enabled = true },
							pylsp_mypy = { enabled = true },
							pylsp_black = { enabled = true },
							pylsp_isort = { enabled = true },
						},
					},
				},
			},
			-- basedpyright = {
			--   -- Config options: https://github.com/DetachHead/basedpyright/blob/main/docs/settings.md
			--   settings = {
			--     basedpyright = {
			--       disableOrganizeImports = true, -- Using Ruff's import organizer
			--       disableLanguageServices = false,
			--       analysis = {
			--         ignore = { '*' },                 -- Ignore all files for analysis to exclusively use Ruff for linting
			--         typeCheckingMode = 'off',
			--         diagnosticMode = 'openFilesOnly', -- Only analyze open files
			--         useLibraryCodeForTypes = true,
			--         autoImportCompletions = true,     -- whether pyright offers auto-import completions
			--       },
			--     },
			--   },
			-- },
			jsonls = {},
			sqlls = {},
			terraformls = {},
			yamlls = {},
			bashls = {},
			dockerls = {},
		}

		-- Ensure the servers and tools above are installed
		local ensure_installed = vim.tbl_keys(servers or {})
		vim.list_extend(ensure_installed, {
			"stylua", -- Used to format Lua code
		})
		require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

		for server, cfg in pairs(servers) do
			-- For each LSP server (cfg), we merge:
			-- 1. A fresh empty table (to avoid mutating capabilities globally)
			-- 2. Your capabilities object with Neovim + cmp features
			-- 3. Any server-specific cfg.capabilities if defined in `servers`
			cfg.capabilities = vim.tbl_deep_extend("force", {}, capabilities, cfg.capabilities or {})

			vim.lsp.config(server, cfg)
			vim.lsp.enable(server)
		end
	end,
}
