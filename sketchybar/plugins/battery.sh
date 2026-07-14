#!/bin/sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

battery_info=$(pmset -g batt 2>/dev/null | awk 'NR==2 {print; exit}')
percent=$(printf '%s' "$battery_info" | grep -Eo '[0-9]+%' | head -n 1 | tr -d '%')

if [ -z "$percent" ]; then
  sketchybar_cmd --set "$NAME" drawing=off
  exit 0
fi

if [ "$percent" -ge 80 ]; then
  color=$GREEN
elif [ "$percent" -ge 30 ]; then
  color=$YELLOW
else
  color=$RED
fi

icon="BAT"
label="${percent}%"

case "$battery_info" in
  *"charging"*)
    icon="AC"
    label="${label}+"
    color=$GREEN
    ;;
  *"charged"*)
    icon="AC"
    label="${label}="
    color=$GREEN
    ;;
esac

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon="$icon" \
  label="$label" \
  icon.color="$color" \
  label.color="$TEXT"
