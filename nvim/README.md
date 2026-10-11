# Minimal Neovim setup

A small Lua config for a mix of **web development**, **data engineering**, and **SRE** work: Java, Python, dbt/SQL, Terraform/HCL, Bash, CloudFormation/YAML, JSON, Docker, and frontend files.

## Research choices

- Neovim 0.12 supports the modern native LSP path: `vim.lsp.config()` + `vim.lsp.enable()` via `mason-lspconfig`.
- Java works best through `nvim-jdtls`, so `jdtls` is installed by Mason but excluded from generic LSP auto-enable.
- `conform.nvim` keeps formatting lightweight; `nvim-lint` complements LSP diagnostics for CLIs like `shellcheck`, `sqlfluff`, `tflint`, and `cfn-lint`.
- Dedicated UX plugins provide the file explorer (`oil.nvim`), pickers (`telescope.nvim`), pairs (`nvim-autopairs`), surround operations (`nvim-surround`), icons (`nvim-web-devicons`), and statusline (`lualine.nvim`).

## Install host tools on macOS

```sh
brew install neovim git curl ripgrep fd tree-sitter node python pipx openjdk terraform shellcheck shfmt tflint cfn-lint
pipx install dbt-core
pipx install sqlfluff
```

Optional Java build tools:

```sh
brew install maven gradle
```


## Java prerequisites

jdtls needs a real JDK (the `/usr/bin/java` stub is not enough):

```sh
brew install openjdk
export JAVA_HOME="$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home"
sudo ln -sfn "$(brew --prefix openjdk)/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk
```

Then install the language server from Neovim:

```vim
:MasonInstall jdtls
```

## Plugin layout

Plugins live in `lua/ryanparker/plugins/*.lua`, one file per topic, imported by `lazy.lua`:

| File | Contents |
| --- | --- |
| `ui.lua` | statusline, icons, which-key |
| `navigation.lua` | oil, telescope, smart-splits |
| `editing.lua` | autopairs, surround, plenary |
| `git.lua` | gitsigns, diffview |
| `lsp.lua` | mason, lspconfig, nvim-jdtls, lazydev |
| `completion.lua` | blink.cmp, snippets, dadbod source |
| `formatting.lua` | conform.nvim |
| `linting.lua` | nvim-lint |
| `treesitter.lua` | treesitter parsers |
| `data.lua` | dbt and database tooling |

## Mason-managed tools

Open Neovim and run:

```vim
:Lazy sync
:Mason
```

Mason will install LSP servers and CLI tools such as `basedpyright`, `ruff`, `jdtls`, `terraformls`, `bashls`, `yamlls`, `jsonls`, `prettier`, `sqlfluff`, `shellcheck`, `shfmt`, `tflint`, and `cfn-lint` where available.

## Keymaps

| Key | Action |
| --- | --- |
| `<leader>e` | file explorer |
| `<leader>cf` | format buffer/range |
| `<leader>ff/fg/fb/fh` | find files / live grep / buffers / help |
| `<leader>fr/fd/fs/fw` | recent files / diagnostics / document symbols / grep word |
| `<leader>/` | fuzzy find in current buffer |
| `<leader>ca` | LSP code action |
| `gd`, `gD` | definition, declaration |
| `K`, `grr`, `gri`, `grn`, `gra`, `gO` | hover, references, implementation, rename, code action, symbols (Neovim built-ins) |
| `]d` / `[d` | next / previous diagnostic (built-in, opens float) |
| `]h` / `[h` | next / previous git hunk |
| `<leader>gs/gp/gb` | stage hunk / preview hunk / blame line |
| `<M-h/j/k/l>` | move between splits, then tmux panes (smart-splits) |
| `<leader>dr/dt/db/dc/dD` | dbt run/test/build/compile/debug when `dbt` exists |
| `<leader>du` | database UI |

## Language coverage

| Area | LSP | Format | Lint |
| --- | --- | --- | --- |
| Java | `jdtls` via `nvim-jdtls` | jdtls fallback | jdtls diagnostics |
| Python | `pyright` + `ruff` | `ruff` (organize imports + format) | `ruff` diagnostics |
| dbt/SQL | — | `sqlfluff` | `sqlfluff` |
| Terraform/HCL | `terraformls` | `terraform fmt` | `tflint` |
| Bash | `bashls` | `shfmt` | `shellcheck` |
| CloudFormation/YAML | `yamlls` + SchemaStore + CFN tags | `prettier` | `cfn-lint` |
| Web/JSON | `vtsls`, `html`, `cssls`, `tailwindcss`, `jsonls` | `prettier` | `eslint_d` |
