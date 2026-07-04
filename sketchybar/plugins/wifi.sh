#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '
  /Hardware Port: Wi-Fi|Hardware Port: AirPort/ {
    getline
    if ($1 == "Device:") {
      print $2
      exit
    }
  }
')

[ -n "$wifi_device" ] || wifi_device=en0

ssid=$(ipconfig getsummary "$wifi_device" 2>/dev/null | sed -n 's/^[[:space:]]*SSID[[:space:]]*:[[:space:]]*//p' | head -n 1)

if [ -z "$ssid" ]; then
  raw=$(networksetup -getairportnetwork "$wifi_device" 2>/dev/null || true)
  case "$raw" in
    *"Current Wi-Fi Network: "*)
      ssid=${raw#*: }
      ;;
  esac
fi

if [ -n "$ssid" ]; then
  icon_color=$SAPPHIRE
  label_color=$TEXT
else
  ssid="offline"
  icon_color=$OVERLAY0
  label_color=$SUBTEXT0
fi

sketchybar_cmd --set "$NAME" \
  drawing=on \
  icon.color="$icon_color" \
  label.color="$label_color" \
  label="$(trim_label "$ssid" 18)"
