#!/bin/sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

media_info=$(osascript 2>/dev/null <<'APPLESCRIPT'
set output to ""
try
  if application "Spotify" is running then
    tell application "Spotify"
      set output to "Spotify|" & (player state as text) & "|" & artist of current track & "|" & name of current track
    end tell
  end if
end try
if output is "" then
  try
    if application "Music" is running then
      tell application "Music"
        set output to "Music|" & (player state as text) & "|" & artist of current track & "|" & name of current track
      end tell
    end if
  end try
end if
return output
APPLESCRIPT
)
media_info=$(printf '%s' "$media_info" | tr -d '\r')

if [ -z "$media_info" ]; then
  sketchybar_cmd --set "$NAME" drawing=off
  exit 0
fi

old_ifs=$IFS
IFS='|'
read -r player state artist track <<EOF_MEDIA_INFO
$media_info
EOF_MEDIA_INFO
IFS=$old_ifs

player=${player:-}
state=${state:-}
artist=${artist:-}
track=${track:-}

case "$state" in
  playing)
    icon_color=$GREEN
    label_color=$TEXT
    ;;
  paused)
    icon_color=$OVERLAY1
    label_color=$SUBTEXT0
    ;;
  *)
    sketchybar_cmd --set "$NAME" drawing=off
    exit 0
    ;;
esac

label=$player
if [ -n "$artist" ] || [ -n "$track" ]; then
  label="$player • $artist — $track"
fi

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon.color="$icon_color" \
  label.color="$label_color" \
  label="$(trim_label "$label" 34)"
