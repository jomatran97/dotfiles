# ghostty

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/ghostty" ~/.config/ghostty
```

Install Ghostty separately from [ghostty.org/download](https://ghostty.org/download), then launch it normally.

## Notes

- The live config file is [`config.ghostty`](./config.ghostty), which uses the XDG path documented by Ghostty.
- The setup keeps a Catppuccin Mocha look, FiraCode Nerd Font, soft transparency, and modest window padding while staying intentionally minimal.
- `background-opacity-cells = true` keeps tmux/Neovim backgrounds visually consistent when they draw explicit cell backgrounds.
- Ghostty shell integration stays on the default auto-detect path, but the config enables the extra `ssh-env` / `ssh-terminfo` helpers for smoother remote sessions.
- Reload the config with `Cmd+Shift+,` on macOS after editing.
