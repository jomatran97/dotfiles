# nvim

A modular Neovim config in Lua built around current ecosystem conventions: [lazy.nvim](https://github.com/folke/lazy.nvim), Catppuccin Mocha (matching the Ghostty setup), [snacks.nvim](https://github.com/folke/snacks.nvim) for pickers / scroll / indent / QoL, native (0.11) `vim.lsp`, [blink.cmp](https://cmp.saghen.dev) completion, Treesitter on the `main` branch, and format-on-save via conform.nvim.

## Requirements

- **Neovim 0.11+** — required for the native `vim.lsp` config API and `winborder`
- **git** + **curl** — bootstrap lazy.nvim and clone plugins
- **make** + a C compiler — build Treesitter parsers
- **tree-sitter CLI** — required for automatic parser install / update in `treesitter.lua`
- **ripgrep** (`rg`) — grep in the snacks picker (`fd` optional, for faster file finding)
- A **Nerd Font** — icons in the statusline / picker
- **Node.js** — `vtsls`, `tailwindcss`, `html`, `cssls`, `emmet_ls`, `dockerls`, and `prettier`
- **Python 3.10+** *(optional but recommended)* — enables Mason-managed `black`, `isort`, and `sqlfluff`
- **Go toolchain** *(optional)* — enables `gopls` and `goimports` when `go` is available
- **Rust toolchain** *(optional)* — enables `rustfmt` if you want Rust formatting
- **lazygit** *(optional)* — for `<leader>gg`

Language servers and most formatters / linters install through Mason. A few tools stay conditional on the host environment: `gopls` / `goimports` only install when `go` is available, `black` / `isort` / `sqlfluff` only install when `python3` is at least 3.10, and `rustfmt` comes from your Rust toolchain instead of Mason.

On macOS: `brew install neovim ripgrep fd make tree-sitter node lazygit`, install Python / Go / Rust as needed, and add a Nerd Font, e.g. `brew install --cask font-jetbrains-mono-nerd-font`.

## Install

Symlink this folder to `~/.config/nvim` (same pattern as the other tools in this repo):

```sh
ln -s "$(pwd)/nvim" ~/.config/nvim
```

Launch `nvim`: lazy.nvim bootstraps itself, Mason downloads the configured servers / formatters / linters, and Treesitter installs parsers when the `tree-sitter` CLI is available. Give it a minute, then restart. Verify with `:checkhealth`, `:Lazy`, and `:Mason`.

## Languages

Configured out of the box for the languages below. Servers and most tools are installed on first launch by Mason (`:Mason` to inspect).

| Language | LSP | Format / lint |
| ---------- | ---------------------------- | --------------------------- |
| Python | pyright + ruff | isort + black · ruff via LSP |
| JavaScript / TypeScript | vtsls + tailwindcss | prettier · eslint_d lint |
| HTML / CSS / EJS | html + emmet_ls + tailwindcss | prettier for HTML / CSS |
| JSON / YAML / TOML / Markdown | jsonls / yamlls / taplo / marksman | prettier |
| Shell | bashls | shfmt · shellcheck lint |
| Go* | gopls | goimports |
| Dockerfile | dockerls | hadolint lint |
| Terraform / HCL | terraformls | terraform_fmt |
| Helm | helm_ls | — |
| SQL / dbt | — | sqlfluff |
| Lua | lua_ls + lazydev | stylua |

`*` Go tooling is only added when the `go` executable is available. SQL / dbt linting and formatting are enabled when the `sqlfluff` executable is available; Mason auto-installs it only when `python3` is at least 3.10.

Additional filetype support:

- `.ejs` files are detected as their own filetype and highlighted with the Treesitter `embedded_template` parser.
- If a plugin marks dbt models as `dbt`, Treesitter reuses the SQL parser for that filetype.
- Rust syntax highlighting and `rustfmt` formatting work when those tools are installed, but there is no dedicated Rust LSP plugin checked in right now.

To add or drop a language, edit the `ensure_installed` servers in `lua/ryanparker/plugins/lsp/lspconfig.lua`, the Mason tool list in `lua/ryanparker/plugins/lsp/mason.lua`, and `formatters_by_ft` / `linters_by_ft` in `lua/ryanparker/plugins/formatting.lua` and `lua/ryanparker/plugins/linting.lua`.

## Layout

Organized in a personal namespace (`lua/ryanparker/`):

```text
nvim/
├── init.lua                     # requires ryanparker.core + ryanparker.lazy
└── lua/ryanparker/
    ├── core/
    │   ├── init.lua             # requires options + keymaps + autocmds
    │   ├── options.lua          # vim.opt settings (sets leader/netrw too)
    │   ├── keymaps.lua          # global key mappings
    │   └── autocmds.lua         # autocommands
    ├── lazy.lua                 # lazy.nvim bootstrap + plugin imports
    └── plugins/
        ├── init.lua             # misc small specs
        ├── colorscheme.lua      # Catppuccin
        ├── snacks.lua           # picker, scroll, indent, dashboard, QoL
        ├── lualine.lua          # statusline
        ├── oil.lua              # file explorer (edit dirs as buffers)
        ├── treesitter.lua       # syntax / indentation
        ├── gitsigns.lua         # git gutter + hunk actions
        ├── which-key.lua        # keybinding popup
        ├── trouble.lua          # diagnostics / quickfix list
        ├── todo-comments.lua    # TODO/FIXME highlighting + nav
        ├── completion.lua       # blink.cmp
        ├── formatting.lua       # conform.nvim
        ├── linting.lua          # nvim-lint
        └── lsp/
            ├── mason.lua        # mason + tool installer
            └── lspconfig.lua    # native vim.lsp + mason-lspconfig
```

The `plugins/` directory also contains additional per-plugin files for AI helpers, database tools, Kubernetes tooling, testing, and other language-specific extras; any file that returns a lazy spec is auto-imported.

## Key mappings

Leader is `<Space>`.

| Key | Action |
| -------------------- | ---------------------------------------- |
| `-` | Open parent dir in oil (edit as a buffer) |
| `<leader>e` | File explorer (floating oil) |
| `<leader>sf` | Find files |
| `<leader>sg` | Live grep |
| `<leader>sr` | Recent files |
| `<leader>sb` | Buffers |
| `<leader>/` | Search in current buffer |
| `<leader>sw` | Grep word / selection |
| `<leader>sd` | Diagnostics |
| `<leader>ss` | Document symbols |
| `<leader>sk` | Keymaps |
| `gd` / `gr` | Goto definition / references (picker) |
| `gI` / `gy` | Goto implementation / type definition |
| `<leader>rn` / `<leader>ca` | Rename symbol / code action |
| `K` | Hover docs (0.11 default) |
| `]d` / `[d` | Next / previous diagnostic (0.11 default) |
| `]]` / `[[` | Next / previous reference |
| `<leader>xx` | Diagnostics list (Trouble) |
| `]t` / `[t` | Next / previous TODO comment |
| `<leader>st` | Find TODOs (Trouble) |
| `gcc` / `gc` | Comment line / selection |
| `<leader>cf` | Format buffer (also on save) |
| `]h` / `[h` | Next / previous git hunk |
| `<leader>gg` | Lazygit |
| `<leader>bd` | Delete buffer |
| `<C-h/j/k/l>` | Move between windows |
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<leader>u…` | Toggles (spell, wrap, diagnostics, …) |

**Completion (blink.cmp):** `C-y` or `Enter` accepts, `C-n` / `C-p` or `Tab` / `S-Tab` cycle, `C-Space` opens the menu, and `C-k` toggles signature help.

**Scrolling** is animated by snacks. Press `<Space>` and wait — which-key lists everything available.

## Customizing

- **Language servers**: edit `ensure_installed` in `lua/ryanparker/plugins/lsp/lspconfig.lua`.
- **Formatters / linters**: edit `formatters_by_ft` in `lua/ryanparker/plugins/formatting.lua`, `linters_by_ft` in `lua/ryanparker/plugins/linting.lua`, and the Mason tool list in `lua/ryanparker/plugins/lsp/mason.lua`.
- **Completion keys**: change `keymap.preset` in `lua/ryanparker/plugins/completion.lua` (`default`, `super-tab`, or `enter`).
- **snacks modules**: toggle features in the `opts` table of `lua/ryanparker/plugins/snacks.lua`.
- **Theme flavour**: change `flavour` in `lua/ryanparker/plugins/colorscheme.lua` (`latte`, `frappe`, `macchiato`, `mocha`).
