#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

space_json=$(yabai_query --spaces --space)
window_json=$(yabai_query --windows --window)

layout=$(json_string "$space_json" "type")
[ -n "$layout" ] || layout="bsp"

icon=$layout
mode="space"
background_color=$SURFACE1
foreground_color=$SUBTEXT1

if [ -n "$window_json" ]; then
  mode="tile"
  background_color=$SURFACE0
  foreground_color=$TEXT

  if [ "$(json_bool "$window_json" "is-floating")" = "true" ]; then
    mode="float"
    background_color=$PEACH
    foreground_color=$CRUST
  fi

  if [ "$(json_bool "$window_json" "is-sticky")" = "true" ]; then
    mode="sticky"
    background_color=$YELLOW
    foreground_color=$CRUST
  fi

  if [ "$(json_bool "$window_json" "is-minimized")" = "true" ]; then
    mode="min"
    background_color=$OVERLAY0
    foreground_color=$CRUST
  fi

  if [ "$(json_bool "$window_json" "has-parent-zoom")" = "true" ]; then
    mode="$mode + zoom"
  fi
fi

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon="$icon" \
  label="$(trim_label "$mode" 18)" \
  icon.color="$foreground_color" \
  label.color="$foreground_color" \
  background.drawing=on \
  background.color="$background_color" \
  background.border_color="$ITEM_BORDER"
