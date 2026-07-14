#!/bin/sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/skhd/mode"
mode=$(cat "$state_file" 2>/dev/null || printf 'default')

case "$mode" in
  ''|default)
    sketchybar_cmd --set "$NAME" \
      drawing=off \
      icon="⌨" \
      icon.color="$PEACH" \
      label="MODE" \
      label.color="$TEXT"
    exit 0
    ;;
  swap)
    icon_color=$PEACH
    label='SWAP'
    ;;
  display)
    icon_color=$SKY
    label='DISPLAY'
    ;;
  send)
    icon_color=$MAUVE
    label='SEND'
    ;;
  resize)
    icon_color=$GREEN
    label='RESIZE'
    ;;
  warp)
    icon_color=$YELLOW
    label='WARP'
    ;;
  *)
    icon_color=$TEXT
    label=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    ;;
esac

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon.drawing=on \
  icon="⌨" \
  icon.color="$icon_color" \
  label="$label" \
  label.color="$TEXT" \
  background.drawing=on \
  background.color="$GROUP_BG" \
  background.border_color="$GROUP_BORDER"
