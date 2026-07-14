# yabai

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/yabai" ~/.config/yabai
```

Install and start the service:

```sh
brew tap asmvik/formulae
brew install asmvik/formulae/yabai
yabai --start-service
```

Grant `yabai` Accessibility access in System Settings → Privacy & Security → Accessibility.

## Notes

- This starter keeps to tiling, focus, swap, and space management that do not require the optional scripting addition.
- `external_bar all:36:0` plus a little extra top padding reserve room for the floating Hyprland-style SketchyBar without overlapping windows.
- The default app rules register the catch-all desktop 6 rule first, then layer the more specific matches over it because yabai lets later matching rules override earlier values: Zalo, WhatsApp, Messages/iMessage, Signal, and Telegram go to desktop 1; terminal apps (including Alacritty, Ghostty, WezTerm, kitty, Warp, Terminal, and iTerm2) go to desktop 2; Code, Visual Studio Code, Arc, Brave, Brave Browser, Firefox, and Postman to desktop 3; notes and password apps to desktop 4; Slack and Microsoft Teams to desktop 5; and everything else to desktop 6. The regex lists near the top of `yabairc` now match substrings so minor app-name variants still land on the intended desktop.
- On restart, `yabairc` makes sure desktops 1..6 exist on the current display so routing rules always have a target; that count now matches the space bindings in `skhd/skhdrc` and the workspace items in `sketchybar/sketchybarrc`.
- SketchyBar refreshes are now split into a batched space update event and a focused-app update event, which avoids rerendering every workspace item on resize/title-only changes.
- Obvious utility/system apps still float instead of tile, and `Digital Color Meter` / `Picture-in-Picture` stay sticky.
- New windows follow their assigned desktop automatically. Floating windows (including `manage=off` utilities) are centered on that desktop instead of being left wherever macOS placed them.
- Reload with `yabai --restart-service` after editing the config.
