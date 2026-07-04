# sketchybar

## Install

Symlink this directory into place:

```sh
ln -s "$(pwd)/sketchybar" ~/.config/sketchybar
```

Install and start the service:

```sh
brew tap FelixKratz/formulae
brew install FelixKratz/formulae/sketchybar
brew services start sketchybar
```

Optional Bluetooth connect/disconnect support from the bar:

```sh
brew install blueutil
```

Reload after editing the config:

```sh
sketchybar --reload
```

## Optional app icon font

The left-side workspace labels and `focused_app` item work without extra dependencies, but they can also use real per-app glyphs from `sketchybar-app-font` when it is installed.

```sh
git clone https://github.com/kvndrsslr/sketchybar-app-font /tmp/sketchybar-app-font
cd /tmp/sketchybar-app-font
pnpm install
pnpm run build:install
```

That installs `sketchybar-app-font.ttf` into `~/Library/Fonts` plus `icon_map.sh` into `~/.config/sketchybar/helpers/`. The bundled scripts auto-detect both on the next reload.

## Notes

- The bar uses a floating, rounded, blurred grouped layout for a more Hyprland-like look.
- The layout keeps `workspaces`, a small `skhd_mode` indicator, and `focused_app` on the left, plus a right-side status cluster with `bluetooth`, `power`, and `time`.
- The Bluetooth item shows the current Bluetooth state, left-click opens a popup list of remembered devices, and right-click opens Bluetooth settings.
- Popup device rows use `blueutil` for one-click connect/disconnect when it is installed; without it, the widget still shows status and opens Bluetooth settings as a fallback.
- Workspace items keep their numeric space index and now show per-space app icons for the windows in that space, capped with an ellipsis when a space gets crowded.
- Workspace refreshes are batched through `plugins/spaces.sh`, so one `yabai_spaces_change` trigger updates all visible spaces from a single spaces query plus a single windows query instead of re-querying yabai once per item.
- `focused_app` now listens only for `yabai_front_app_change`, which keeps app changes responsive without rerendering every space for resize/title-only events.
- `skhd_mode` reads `~/.local/state/skhd/mode`, which `skhd/bin/set-mode` updates whenever you enter or leave one of the skhd modes.
- Without `sketchybar-app-font`, the same widgets fall back to built-in Unicode symbols so the config still works out of the box.
- `sketchybarrc` predeclares spaces `1..6` to stay aligned with `yabai/yabairc` and `skhd/skhdrc`, while still hiding any space that does not currently exist so it can recover if SketchyBar starts before `yabai`.
- If you expand beyond 6 spaces, update the matching counts and bindings in `yabai`, `skhd`, and `sketchybar` together.
