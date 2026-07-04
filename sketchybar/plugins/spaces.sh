#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

space_list=${SPACE_LIST:-${SPACES:-"1 2 3 4 5 6"}}
icon_limit=${SPACE_ICON_LIMIT:-4}
spaces_json=$(yabai_query --spaces)
windows_json=$(yabai_query --windows)

if [ -z "$spaces_json" ] || [ -z "$windows_json" ]; then
  for sid in $space_list; do
    sketchybar_cmd --set "space.$sid" drawing=off
  done
  exit 0
fi

state=$(SPACE_LIST="$space_list" SPACES_JSON="$spaces_json" WINDOWS_JSON="$windows_json" python3 - <<'PY'
import collections
import json
import os

space_list = [int(part) for part in os.environ.get('SPACE_LIST', '').split() if part]
spaces = json.loads(os.environ.get('SPACES_JSON') or '[]')
windows = json.loads(os.environ.get('WINDOWS_JSON') or '[]')

space_indexes = set()
space_focus = {}
for item in spaces:
    if not isinstance(item, dict):
        continue
    index = item.get('index')
    if isinstance(index, int):
        space_indexes.add(index)
        space_focus[index] = bool(item.get('has-focus'))

space_apps = collections.defaultdict(list)
for item in windows:
    if not isinstance(item, dict):
        continue
    index = item.get('space')
    app = item.get('app')
    if isinstance(index, int) and isinstance(app, str) and app:
        space_apps[index].append(app)

for sid in space_list:
    exists = '1' if sid in space_indexes else '0'
    focused = '1' if space_focus.get(sid) else '0'
    apps = '\x1f'.join(space_apps.get(sid, []))
    print(f'{sid}\t{exists}\t{focused}\t{apps}')
PY
)

printf '%s\n' "$state" | while IFS="$(printf '\t')" read -r sid exists focused apps_raw; do
  [ -n "$sid" ] || continue

  if [ "$exists" != "1" ]; then
    sketchybar_cmd --set "space.$sid" drawing=off
    continue
  fi

  window_label=$(space_app_icons_from_list "$apps_raw" "$icon_limit")

  if has_app_icon_font; then
    label_font=$APP_ICON_FONT
  else
    label_font=$DEFAULT_LABEL_FONT
  fi

  if [ "$focused" = "1" ]; then
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

  sketchybar_cmd --set "space.$sid" \
    drawing=on \
    icon="$sid" \
    label="$window_label" \
    label.font="$label_font" \
    icon.color="$icon_color" \
    label.color="$label_color" \
    background.drawing="$background_drawing" \
    background.color="$background_color" \
    background.border_color="$background_border"
done
