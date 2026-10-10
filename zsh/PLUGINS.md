# Oh My Zsh plugins

Oh My Zsh is required. Plugins are declared as one static list in `zshrc`; startup does not discover, filter, install, or update them.

## Static list

The configuration enables:

```text
command-not-found dotenv docker gitignore colorize thefuck tldr tmux fast-syntax-highlighting
```

The fzf plugin is deliberately absent because modern `fzf --zsh` integration is initialized directly. `zsh-autosuggestions` remains deliberately absent to avoid inline duplicated suggestions. `fast-syntax-highlighting` is enabled again for command coloring and must remain last so it can wrap widgets installed by earlier plugins.

Oh My Zsh supplies built-in plugins under `$ZSH/plugins`. The third-party `fast-syntax-highlighting` plugin must be installed manually under `${ZSH_CUSTOM:-$ZSH/custom}/plugins`. Missing static plugins may cause an Oh My Zsh warning; missing tool dependencies may disable or degrade the corresponding feature. This is an intentional tradeoff for a simple, visible configuration.

## Install external plugins

Run this manual setup command after installing Oh My Zsh:

```sh
custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting \
  "$custom/plugins/fast-syntax-highlighting"
```

Do not install or enable `zsh-autosuggestions`; inline duplicated suggestions are intentionally disabled.

## Update

Review upstream changes, then update each checkout explicitly:

```sh
git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting" pull --ff-only
git -C "${ZSH:-$HOME/.oh-my-zsh}" pull --ff-only
```

Oh My Zsh automatic updates are disabled, so startup does no plugin network work. Older fzf integration-file discovery and no-Oh-My-Zsh completion/plugin fallbacks are intentionally unsupported.
