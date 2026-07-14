# Vendored zsh plugins

This repo vendors its zsh plugins as plain tracked directories under `zsh/plugins/`. We intentionally do **not** keep their `.git/` metadata so the dotfiles repo remains self-contained and does not depend on nested Git repositories.

## Plugin inventory

| Directory | Upstream | Why it is here |
| --- | --- | --- |
| `zsh/plugins/zsh-autosuggestions` | <https://github.com/zsh-users/zsh-autosuggestions> | fish-style command suggestions from history |
| `zsh/plugins/zsh-history-substring-search` | <https://github.com/zsh-users/zsh-history-substring-search> | prefix-based up/down history search |
| `zsh/plugins/zsh-vi-mode` | <https://github.com/jeffreytse/zsh-vi-mode> | modal editing and cursor-shape hooks |
| `zsh/plugins/fast-syntax-highlighting` | <https://github.com/zdharma-continuum/fast-syntax-highlighting> | fast syntax highlighting without a framework |

## Refreshing one vendored plugin

Use a temporary clone, then copy the working tree back without `.git` metadata:

```sh
plugin='zsh-autosuggestions'
url='https://github.com/zsh-users/zsh-autosuggestions.git'
tmp=$(mktemp -d)
git clone --depth=1 "$url" "$tmp/$plugin"
rm -rf "zsh/plugins/$plugin"
mkdir -p zsh/plugins
cp -R "$tmp/$plugin" "zsh/plugins/$plugin"
rm -rf "zsh/plugins/$plugin/.git" "$tmp"
```

After updating, review the diff, run the zsh syntax checks, and commit the vendored changes with a note about the upstream version or date.
