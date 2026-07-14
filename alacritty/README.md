# Alacritty

Managed Alacritty config for macOS.

## Install

```sh
ln -s "$(pwd)/alacritty" ~/.config/alacritty
```

Install Alacritty and the configured Nerd Font if needed:

```sh
brew install --cask alacritty font-fira-code-nerd-font
```

The config uses current Alacritty TOML syntax (`alacritty.toml`) and the installed `FiraCode Nerd Font Mono` family.

## Validate

```sh
alacritty migrate --dry-run --config-file ~/.config/alacritty/alacritty.toml >/dev/null
```
