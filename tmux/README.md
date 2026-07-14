# tmux

Minimal tmux configuration focused on Meta/Alt no-prefix navigation.

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/tmux" ~/.config/tmux
```

Reload from inside tmux with `Alt-r` or `Ctrl-a r`.

## Meta / Alt keys

The config uses tmux's `M-` key syntax for Meta/Alt bindings. On macOS, make
sure your terminal sends Option as Alt/Meta instead of inserting special
characters.

Suggested terminal-side settings:

- Ghostty: enable Option-as-Alt in your Ghostty config if needed.
- Alacritty: use `option_as_alt = "Both"` if Option does not reach tmux as Alt.

`escape-time` is set to `10` to make Alt/Meta recognition more reliable for
terminals that encode Meta as `Esc` + key. If Escape feels slow in editors, try
lowering it to `5` or `0`.

## Main bindings

No prefix:

| Key | Action |
| --- | --- |
| `Alt-h/j/k/l` | Select pane left/down/up/right |
| `Alt-,` / `Alt-.` | Resize pane left/right |
| `Alt--` / `Alt-=` | Resize pane down/up |
| `Alt-p` / `Alt-n` | Previous/next window |
| `Alt-H` / `Alt-L` | Previous/next window |
| `Alt-1` … `Alt-9` | Select window 1-9 |
| `Alt-s` | Split vertically |
| `Alt-v` | Split horizontally |
| `Alt-c` | New window |
| `Alt-z` | Zoom pane |
| `Alt-w` | Choose tree |
| `Alt-S` | Choose session |
| `Alt-[` | Copy mode |
| `Alt-r` | Reload config |

Prefix remains `Ctrl-a` for tmux defaults/fallbacks.
