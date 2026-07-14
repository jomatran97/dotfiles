# skhd

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/skhd" ~/.config/skhd
```

Install and start the service:

```sh
brew tap asmvik/formulae
brew install asmvik/formulae/skhd
skhd --start-service
```

Grant `skhd` Accessibility access in System Settings → Privacy & Security → Accessibility.

## Notes

- The default bindings assume Raycast-style Hyper (`cmd + alt + ctrl + shift`). Primary actions live on Hyper, `Hyper+Return` launches Alacritty, and swap/display/send/resize/warp use small modes entered with `Hyper+s`, `Hyper+d`, `Hyper+m`, `Hyper+e`, and `Hyper+w`.
- `~/.config/skhd/bin/yabai-msg` prepends common Homebrew paths so LaunchAgent-driven keybindings can still find `yabai`.
- `~/.config/skhd/bin/set-mode` writes the active mode into `~/.local/state/skhd/mode` and triggers a SketchyBar refresh when that bar config is installed, so the current mode is visible without guessing.
- The space bindings now intentionally stop at `1..6` to match `yabai/yabairc` and `sketchybar/sketchybarrc`.
- Reload with `skhd --reload` after editing the config.
- Full Hyper binding reference: [`COMMANDS.md`](./COMMANDS.md).
