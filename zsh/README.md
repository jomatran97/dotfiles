# zsh

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/zsh" ~/.config/zsh
export ZDOTDIR="$HOME/.config/zsh"
```

## Tooling

This shell config expects the following tools when available: `atuin`, `bat`, `eza`, `fd`, `fzf`, `mise`, `starship`, and `zoxide`.

On macOS, a good baseline install is:

```sh
brew install atuin bat eza fd fzf mise starship zoxide
```

If you install Atuin via its official script, `.zshenv` already adds `~/.atuin/bin` to `PATH`.

## Plugins

This repo currently vendors the plugin checkouts under `zsh/plugins/`, so a normal symlinked install works out of the box.

If you intentionally remove the repo-managed plugin directories or start from a sparse checkout, restore any missing plugins with:

```sh
zsh -ic 'source ~/.config/zsh/plugins.zsh && zplugin-install'
```

The shell never clones plugins during startup. If a plugin is missing, zsh warns and keeps going.

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+R` | Atuin history search |
| `Ctrl+T` | Fuzzy file search including hidden files (fzf + fd, excluding `.git`) |
| `Ctrl+F` | Fuzzy file search excluding hidden files (fzf + fd) |
| `Ctrl+→` | Move forward one word |
| `Ctrl+←` | Move backward one word |
| `↑` / `↓` | History search by prefix |
| `Ctrl+\` | Toggle autosuggestions |

## Starship Config

Included in the repo at [`starship.toml`](./starship.toml) and loaded automatically via `STARSHIP_CONFIG` in `.zshenv`. Requires a [Nerd Font](https://www.nerdfonts.com) in your terminal.
