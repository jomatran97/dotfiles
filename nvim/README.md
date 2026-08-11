# nvim

A modular, non-assistant Neovim 0.12 config in Lua built around [lazy.nvim](https://github.com/folke/lazy.nvim), Catppuccin Mocha, [snacks.nvim](https://github.com/folke/snacks.nvim) for pickers / scroll / indent / QoL, native `vim.lsp`, [blink.cmp](https://cmp.saghen.dev) completion, Treesitter on the `main` branch, and format-on-save via conform.nvim.

## Requirements and tool installation guide

This config does **not** require you to preinstall every language tool. Install the system tools first, then let Mason install the configured LSP servers, formatters, and linters on first `nvim` launch. Optional tools below only matter if you use that feature or language.

### Core tools to install yourself

| Tool | Why it is needed | macOS install |
| --- | --- | --- |
| Neovim 0.12+ | Required by the current Treesitter `main` branch and native `vim.lsp` APIs | `brew install neovim` |
| git + curl | Bootstrap lazy.nvim and clone plugins | `brew install git curl` |
| make + C compiler | Build native parser / plugin components | `xcode-select --install` and/or `brew install make` |
| tree-sitter CLI 0.26.1+ | Install / update Treesitter parsers on the `main` branch | `brew install tree-sitter` |
| ripgrep (`rg`) | Live grep in snacks picker and TODO search | `brew install ripgrep` |
| fd | Faster file finding for picker integrations | `brew install fd` |
| Node.js + npm | Node-based LSPs, formatters, package-info, and Vitest projects | `brew install node` |
| Python 3.10+ | Mason Python tools (`black`, `isort`, `sqlfluff`) and Python provider/notebook features | `brew install python@3.12` |
| Nerd Font | Icons in statusline, picker, oil, and DB UI | `brew install --cask font-jetbrains-mono-nerd-font` |

Recommended one-shot core install on macOS:

```sh
brew install neovim git curl make tree-sitter ripgrep fd node python@3.12
brew install --cask font-jetbrains-mono-nerd-font
```

### Mason-managed tools

Mason installs these automatically from `lua/ryanparker/plugins/lsp/lspconfig.lua` and `lua/ryanparker/plugins/lsp/mason.lua` after startup. Inspect status with `:Mason`.

**Language servers:**

- Always: `lua_ls`, `pyright`, `ruff`, `vtsls`, `tailwindcss`, `html`, `cssls`, `jsonls`, `yamlls`, `taplo`, `marksman`, `bashls`, `emmet_ls`, `dockerls`
- Conditional: `gopls` only when `go` is available in `PATH`; `terraformls` only when `terraform` is available; `helm_ls` only when `helm` is available

**Formatters / linters:**

- Always: `stylua`, `prettier`, `shfmt`, `shellcheck`, `eslint_d`, `hadolint`
- Conditional on Python 3.10+: `black`, `isort`, `sqlfluff`
- Conditional on Go: `goimports`

### Optional feature and language tools

Install these only for the languages or plugins you use:

| Feature | External tools | Install examples |
| --- | --- | --- |
| Go LSP / formatting / tests | `go` (enables Mason `gopls` + `goimports`) | `brew install go` |
| Rust formatting / highlighting | Rust toolchain with `rustfmt` | `brew install rustup-init && rustup-init` |
| Dockerfile lint/runtime | Mason installs `hadolint`; Docker CLI/daemon only for Docker workflows | `brew install --cask docker` |
| SQL database UI | SQLite CLI for local SQLite URLs; `psql`/PostgreSQL or `mysql` clients only for those connection types | `brew install sqlite libpq mysql-client` |
| Kubernetes | `kubectl` (the Neovim integration is disabled when it is absent) | `brew install kubectl` |
| Helm | `helm` (Helm LSP installation is skipped when it is absent) | `brew install helm` |
| Terraform | `terraform` (Terraform LSP/formatting are skipped when it is absent) | `brew install terraform` |
| dbt | `dbt` (dbtpal is disabled when it is absent) | `python3 -m pip install --user dbt-core` |
| Quarto / notebooks | `quarto`, Jupyter, Python `pynvim`/kernel packages | `brew install quarto jupyterlab && python3 -m pip install --user pynvim jupyter_client` |
| Python tests | `pytest` in each project environment | `python3 -m pip install --user pytest` |
| Vitest tests | `vitest` in the project | `npm install -D vitest` |
| Lazygit integration | `lazygit` for `<leader>gg` | `brew install lazygit` |
| REST client | No required CLI for basic Kulala HTTP files | optional project-specific auth/tools |

Language servers and most formatters / linters install through Mason. A few tools stay conditional on the host environment: `gopls` / `goimports` only install when `go` is available, `terraformls` / Terraform formatting only when `terraform` is available, `helm_ls` only when `helm` is available, `black` / `isort` / `sqlfluff` only install when `python3` is at least 3.10, and `rustfmt` comes from your Rust toolchain instead of Mason.

### Verify installation

```sh
command -v nvim git curl make tree-sitter rg fd node npm python3
nvim --version | head -1
nvim --headless '+checkhealth' '+qa'
```

Inside Neovim, run `:Lazy`, `:Mason`, `:checkhealth`, and `:ConformInfo`.

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
| Terraform / HCL* | terraformls | terraform_fmt |
| Helm* | helm_ls | — |
| SQL / dbt | — | sqlfluff |
| Lua | lua_ls + lazydev | stylua |

`*` Go, Terraform, and Helm tooling is only added when the corresponding host executable is available. SQL / dbt linting and formatting are enabled when `sqlfluff` is available; Mason auto-installs it only when `python3` is at least 3.10.

Additional filetype support:

- `.ejs` files are detected as their own filetype and highlighted with the Treesitter `embedded_template` parser.
- If a plugin marks dbt models as `dbt`, Treesitter reuses the SQL parser for that filetype.
- Rust syntax highlighting and `rustfmt` formatting work when those tools are installed, but there is no dedicated Rust LSP plugin checked in right now.

To add or drop a language, edit the `ensure_installed` servers in `lua/ryanparker/plugins/lsp/lspconfig.lua`, the Mason tool list in `lua/ryanparker/plugins/lsp/mason.lua`, and `formatters_by_ft` / `linters_by_ft` in `lua/ryanparker/plugins/formatting.lua` and `lua/ryanparker/plugins/linting.lua`. Keep optional external-tool integrations guarded with `vim.fn.executable()` so missing CLIs do not raise startup or file-open warnings.

## Layout

Organized in a personal namespace (`lua/ryanparker/`):

```text
nvim/
├── init.lua                     # requires ryanparker.core + ryanparker.lazy
└── lua/ryanparker/
    ├── core/
    │   ├── init.lua             # requires options + keymaps + autocmds
    │   ├── options.lua          # vim.opt settings and netrw disable
    │   ├── keymaps.lua          # leader keys and global mappings
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

The `plugins/` directory also contains additional per-plugin files for database tools, Kubernetes tooling, testing, text objects, and other language-specific extras; any file that returns a lazy spec is auto-imported. `mini.ai` is a text-object plugin (its name means “around/inside”), not an assistant integration.

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
| `<leader>sH` | Help pages |
| `<leader>sk` | Keymaps |
| `gd` / `gr` | Goto definition / references (picker) |
| `gI` / `gy` | Goto implementation / type definition |
| `<leader>rn` / `<leader>ca` | Rename symbol / code action |
| `K` | Hover docs (native Neovim mapping) |
| `]d` / `[d` | Next / previous diagnostic (native Neovim mappings) |
| `]]` / `[[` | Next / previous reference |
| `<leader>xx` | Diagnostics list (Trouble) |
| `]t` / `[t` | Next / previous TODO comment |
| `<leader>st` | Find TODOs (Trouble) |
| `gcc` / `gc` | Comment line / selection (native Neovim mappings) |
| `dd` | Delete line (`dd` on a blank line preserves the unnamed register) |
| `<leader>cf` | Format buffer (also on save) |
| `]h` / `[h` | Next / previous git hunk |
| `<leader>gg` | Lazygit |
| `<leader>bd` | Delete buffer |
| `<C-h/j/k/l>` | Move between windows |
| `<leader>sv` / `<leader>sh` | Split vertically / horizontally |
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<leader>u…` | Toggles (spell, wrap, diagnostics, …) |

**Completion (blink.cmp):** `C-y` or `Enter` accepts, `C-n` / `C-p` or `Tab` / `S-Tab` cycle, `C-Space` opens the menu, and `C-k` toggles signature help.

**Scrolling** is animated by snacks. Press `<Space>` and wait — which-key lists everything available.

## Customizing

- **Language servers**: edit `ensure_installed` in `lua/ryanparker/plugins/lsp/lspconfig.lua`.
- **Formatters / linters**: edit `formatters_by_ft` in `lua/ryanparker/plugins/formatting.lua`, `linters_by_ft` in `lua/ryanparker/plugins/linting.lua`, and the Mason tool list in `lua/ryanparker/plugins/lsp/mason.lua`.
- **Completion keys**: edit the `keymap` table in `lua/ryanparker/plugins/completion.lua`; it extends blink.cmp's `default` preset with Enter acceptance and Tab cycling.
- **snacks modules**: toggle features in the `opts` table of `lua/ryanparker/plugins/snacks.lua`.
- **Theme flavour**: change `flavour` in `lua/ryanparker/plugins/colorscheme.lua` (`latte`, `frappe`, `macchiato`, `mocha`).
