#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

window_json=$(yabai_query --windows --window)
app=$(json_string "$window_json" "app")

if [ -z "$app" ]; then
  app="Desktop"
fi

if has_app_icon_font; then
  icon_font=$APP_ICON_FONT
else
  icon_font=$DEFAULT_ICON_FONT
fi

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon.drawing=on \
  icon.font="$icon_font" \
  icon.color="$MAUVE" \
  icon="$(app_icon "$app")" \
  label.color="$TEXT" \
  label="$(trim_label "$app" 28)"
