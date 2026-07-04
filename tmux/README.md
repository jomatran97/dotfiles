# tmux

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/tmux" ~/.config/tmux
```

## Plugins

This repo vendors its tmux plugin checkouts under `tmux/plugins/`, including TPM, so a normal XDG symlink install does not require a separate `~/.tmux/plugins/tpm` clone.

If you prefer a legacy non-XDG TPM install, cloning TPM into `~/.tmux/plugins/tpm` still works because `tmux.conf` falls back to that path when the repo-managed checkout is absent.

## Notes

- tmux now prefers `tmux-256color` when that terminfo entry exists, advertises RGB / underscore styling for `xterm-ghostty` and `xterm-256color` clients, and falls back to `screen-256color` otherwise.
- SessionX dotfile paths now derive from the symlinked `~/.config/tmux/..` install path instead of a machine-specific absolute path.
- `tmux.reset.conf` removes the shadowed duplicate bindings that were previously overridden later in the file, so the effective keymap is unchanged but easier to audit. The left-side Catppuccin session module now also doubles as a small prefix / copy-mode indicator.
