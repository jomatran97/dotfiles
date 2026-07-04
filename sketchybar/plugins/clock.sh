#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon.color="$ROSEWATER" \
  label.color="$TEXT" \
  label="$(date '+%a %H:%M')"
