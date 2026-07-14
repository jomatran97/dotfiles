# goku

Caps Lock is configured as a Hyper key for the existing `skhd` bindings:

- hold `Caps Lock` = `cmd + ctrl + option + shift`
- tap `Caps Lock` = `Escape`

## Install

```sh
brew install yqrashawn/goku/goku
brew install --cask karabiner-elements
```

Open Karabiner-Elements once and grant the permissions macOS requests.

## Link and apply

From this repo:

```sh
ln -sf "$(pwd)/goku/karabiner.edn" ~/.config/karabiner.edn
goku
```

Goku writes the generated Karabiner config to:

```text
~/.config/karabiner/karabiner.json
```

After running `goku`, hold Caps Lock and press any key documented as `Hyper` in
`../skhd/COMMANDS.md`.

## Reload after edits

```sh
goku
```
