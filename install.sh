#!/usr/bin/env bash
# Idempotent installer: symlinks dotfiles into $HOME / $XDG_CONFIG_HOME.
# Existing non-matching targets are moved to <target>.bak.<timestamp>.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
stamp="$(date +%Y%m%d%H%M%S)"

link() {
  local src=$1 dst=$2
  [[ -e $src ]] || { echo "skip (missing source): $src"; return 0; }
  mkdir -p "$(dirname "$dst")"
  if [[ -L $dst && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok: $dst"
    return 0
  fi
  if [[ -e $dst || -L $dst ]]; then
    mv "$dst" "$dst.bak.$stamp"
    echo "backed up: $dst -> $dst.bak.$stamp"
  fi
  ln -s "$src" "$dst"
  echo "linked: $dst -> $src"
}

link "$repo/zsh"                  "$config/zsh"
link "$repo/zsh/core/zshenv"      "$HOME/.zshenv"
link "$repo/zsh/core/zprofile"    "$HOME/.zprofile"
link "$repo/zsh/zshrc"            "$HOME/.zshrc"
link "$repo/starship"             "$config/starship"
link "$repo/alacritty"            "$config/alacritty"
link "$repo/tmux"                 "$config/tmux"
link "$repo/nvim"                 "$config/nvim"
link "$repo/lf"                   "$config/lf"
link "$repo/yabai"                "$config/yabai"
link "$repo/skhd"                 "$config/skhd"
link "$repo/karabiner"            "$config/karabiner"
