# skhd commands

## Hyper key

This config assumes your Raycast Hyper key is:

- `cmd + alt + ctrl + shift`

In the tables below, that combo is written as **Hyper**.

## Primary bindings

| Key | Action |
| --- | --- |
| `Hyper + Return` | Open Ghostty |
| `Hyper + h` | Focus window west |
| `Hyper + j` | Focus window south |
| `Hyper + k` | Focus window north |
| `Hyper + l` | Focus window east |
| `Hyper + 1..6` | Focus space `1..6` |
| `Hyper + f` | Toggle float |
| `Hyper + z` | Toggle zoom-parent |
| `Hyper + x` | Toggle zoom-fullscreen |
| `Hyper + b` | Balance current space |
| `Hyper + r` | Rotate current space `90°` |
| `Hyper + p` | Toggle split orientation |
| `Hyper + s` | Enter **swap** mode |
| `Hyper + d` | Enter **display** mode |
| `Hyper + m` | Enter **send** mode |
| `Hyper + e` | Enter **resize** mode |
| `Hyper + w` | Enter **warp** mode |

If SketchyBar is running with this repo's config, the left-side `skhd_mode` item shows the active mode until you return to `default`.

## Swap mode

Enter with:

- `Hyper + s`

Exit with:

- `Escape`
- `s`

Bindings:

| Key | Action |
| --- | --- |
| `h` | Swap window west |
| `j` | Swap window south |
| `k` | Swap window north |
| `l` | Swap window east |

## Display mode

Enter with:

- `Hyper + d`

Exit with:

- `Escape`
- `d`

Bindings:

| Key | Action |
| --- | --- |
| `h` | Focus previous display |
| `l` | Focus next display |

## Send mode

Enter with:

- `Hyper + m`

Exit with:

- `Escape`
- `m`

Bindings:

| Key | Action |
| --- | --- |
| `h` | Move focused window to previous display and follow it |
| `l` | Move focused window to next display and follow it |
| `1..6` | Move focused window to space `1..6` and follow it |

## Resize mode

Enter with:

- `Hyper + e`

Exit with:

- `Escape`
- `e`

Bindings:

| Key | Action |
| --- | --- |
| `h` | Grow the managed split west |
| `j` | Grow the managed split south |
| `k` | Grow the managed split north |
| `l` | Grow the managed split east |

## Warp mode

Enter with:

- `Hyper + w`

Exit with:

- `Escape`
- `w`

Bindings:

| Key | Action |
| --- | --- |
| `h` | Warp window west |
| `j` | Warp window south |
| `k` | Warp window north |
| `l` | Warp window east |
| `x` | Mirror current space on the X axis |
| `y` | Mirror current space on the Y axis |
| `r` | Rotate current space `90°` |
| `b` | Balance current space |

## Source file

These bindings are defined in:

- `skhd/skhdrc`
