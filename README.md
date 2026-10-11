# dotfiles

Personal configuration for zsh (Oh My Zsh + Starship), alacritty, tmux, nvim, yabai, skhd, and karabiner.

## Install

```sh
./install.sh
```

Symlinks each config into `$HOME` / `${XDG_CONFIG_HOME:-~/.config}`. It is idempotent: correct links are left alone, and anything else in the way is moved to `<path>.bak.<timestamp>`.

Prerequisites: [Oh My Zsh](https://ohmyz.sh/) at `~/.oh-my-zsh` (not installed automatically), plus starship, fzf, zoxide, tmux, and a Nerd Font (FiraCode).

Do not set `ZDOTDIR`; see `zsh/README.md`.
