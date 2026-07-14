#!/bin/sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

space_index=${SPACE_INDEX:-${NAME##*.}}
icon_limit=${SPACE_ICON_LIMIT:-4}
space_json=$(yabai_query --spaces --space "$space_index")

if [ -z "$space_json" ]; then
  sketchybar_cmd --set "$NAME" drawing=off
  exit 0
fi

windows_json=$(yabai_query --windows --space "$space_index")
focused=$(json_bool "$space_json" "has-focus")
window_label=$(space_app_icons "$windows_json" "$icon_limit")

if has_app_icon_font; then
  label_font=$APP_ICON_FONT
else
  label_font=$DEFAULT_LABEL_FONT
fi

if [ "$focused" = "true" ]; then
  icon_color=$CRUST
  label_color=$CRUST
  background_drawing=on
  background_color=$ACTIVE_BG
  background_border=$ACTIVE_BORDER
else
  icon_color=$TEXT
  label_color=$SUBTEXT0
  background_drawing=off
  background_color=$ITEM_BG
  background_border=$ITEM_BORDER
fi

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon="$space_index" \
  label="$window_label" \
  label.font="$label_font" \
  icon.color="$icon_color" \
  label.color="$label_color" \
  background.drawing="$background_drawing" \
  background.color="$background_color" \
  background.border_color="$background_border"
