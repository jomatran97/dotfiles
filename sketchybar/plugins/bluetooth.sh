#!/bin/sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
# shellcheck source=./helpers.sh
. "$SCRIPT_DIR/helpers.sh"

MAIN_ITEM=${BT_MAIN_ITEM:-bluetooth}
STATUS_ITEM=${BT_STATUS_ITEM:-bluetooth.status}
TOGGLE_ITEM=${BT_TOGGLE_ITEM:-bluetooth.toggle}
NOTE_ITEM=${BT_NOTE_ITEM:-bluetooth.note}
SETTINGS_ITEM=${BT_SETTINGS_ITEM:-bluetooth.action}
MAX_DEVICES=${BT_DEVICE_SLOTS:-10}

have_blueutil() {
  command -v blueutil >/dev/null 2>&1
}

open_bluetooth_settings() {
  sketchybar_cmd --set "$MAIN_ITEM" popup.drawing=off >/dev/null 2>&1 || true

  open "x-apple.systempreferences:com.apple.BluetoothSettings" >/dev/null 2>&1 \
    || open "x-apple.systempreferences:com.apple.preference.bluetooth" >/dev/null 2>&1 \
    || open "/System/Library/PreferencePanes/Bluetooth.prefPane" >/dev/null 2>&1 \
    || true
}

open_blueutil_home() {
  open "https://github.com/toy/blueutil" >/dev/null 2>&1 || true
}

collect_state_files() {
  STATE_FILE=$(mktemp -t sketchybar-bluetooth-state)
  SUMMARY_FILE=$(mktemp -t sketchybar-bluetooth-summary)
  DEVICES_FILE=$(mktemp -t sketchybar-bluetooth-devices)
  export SUMMARY_FILE DEVICES_FILE

  if ! system_profiler SPBluetoothDataType -json >"$STATE_FILE" 2>/dev/null; then
    printf '{}\n' >"$STATE_FILE"
  fi

  /usr/bin/python3 - "$STATE_FILE" "$SUMMARY_FILE" "$DEVICES_FILE" "$MAX_DEVICES" <<'PY'
import json
import sys

source_path, summary_path, devices_path, max_devices = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])


def clean(value):
    if value is None:
        return ""
    value = str(value).replace("\t", " ").replace("\n", " ").strip()
    return " ".join(value.split())


try:
    with open(source_path, "r", encoding="utf-8") as fh:
        payload = json.load(fh)
except Exception:
    payload = {}

sections = payload.get("SPBluetoothDataType") or []
section = sections[0] if sections else {}
controller = section.get("controller_properties") or {}
state_raw = clean(controller.get("controller_state", "")).lower()
if "on" in state_raw:
    power = "on"
elif "off" in state_raw:
    power = "off"
else:
    power = "unknown"

by_address = {}


def add_devices(entries, connected):
    if not isinstance(entries, list):
        return
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        for name, props in entry.items():
            if not isinstance(props, dict):
                props = {}
            address = clean(props.get("device_address") or props.get("address"))
            if not address:
                continue
            battery = clean(props.get("device_batteryLevelMain"))
            if not battery:
                left = clean(props.get("device_batteryLevelLeft"))
                right = clean(props.get("device_batteryLevelRight"))
                case = clean(props.get("device_batteryLevelCase") or props.get("device_caseBatteryLevel"))
                battery_parts = []
                if left:
                    battery_parts.append(f"L {left}")
                if right:
                    battery_parts.append(f"R {right}")
                if case:
                    battery_parts.append(f"Case {case}")
                battery = " · ".join(battery_parts)
            device = {
                "name": clean(name),
                "address": address,
                "connected": bool(connected),
                "type": clean(props.get("device_minorType") or props.get("device_type")),
                "battery": battery,
            }
            previous = by_address.get(address)
            if previous is None or (connected and not previous.get("connected")):
                by_address[address] = device


add_devices(section.get("device_connected"), True)
add_devices(section.get("device_not_connected"), False)

ordered = sorted(by_address.values(), key=lambda device: (not device["connected"], device["name"].lower()))
connected = [device for device in ordered if device["connected"]]

if power == "off":
    label = "Off"
    status = "Bluetooth off"
elif power == "unknown":
    label = "Unavailable"
    status = "Bluetooth unavailable"
elif not connected:
    label = "On"
    status = "Bluetooth on · no active devices"
elif len(connected) == 1:
    label = connected[0]["name"]
    status = f"Bluetooth on · {connected[0]['name']} connected"
else:
    label = f"{connected[0]['name']} +{len(connected) - 1}"
    status = f"Bluetooth on · {len(connected)} devices connected"

with open(summary_path, "w", encoding="utf-8") as fh:
    fh.write("\t".join([power, str(len(connected)), clean(label), clean(status)]) + "\n")

with open(devices_path, "w", encoding="utf-8") as fh:
    for device in ordered[:max_devices]:
        fh.write(
            "\t".join(
                [
                    "1" if device["connected"] else "0",
                    clean(device["name"]),
                    clean(device["address"]),
                    clean(device["type"]),
                    clean(device["battery"]),
                ]
            )
            + "\n"
        )
PY
}

cleanup_state_files() {
  rm -f "$STATE_FILE" "$SUMMARY_FILE" "$DEVICES_FILE"
}

apply_main_item() {
  power=$1
  connected_count=$2
  summary_label=$3

  case "$power" in
    on)
      if [ "$connected_count" -gt 0 ]; then
        icon_color=$BLUE
        label_color=$TEXT
      else
        icon_color=$SKY
        label_color=$SUBTEXT1
      fi
      ;;
    off)
      icon_color=$OVERLAY0
      label_color=$SUBTEXT0
      ;;
    *)
      icon_color=$OVERLAY0
      label_color=$SUBTEXT0
      ;;
  esac

  [ -n "$summary_label" ] || summary_label="Unavailable"

  sketchybar_cmd --set "$MAIN_ITEM" \
    drawing=on \
    icon="BT" \
    icon.color="$icon_color" \
    label.color="$label_color" \
    label="$(trim_label "$summary_label" 14)"
}

apply_popup_items() {
  power=$1
  connected_count=$2
  status_label=$3

  case "$power" in
    on)
      status_color=$BLUE
      ;;
    off)
      status_color=$OVERLAY0
      ;;
    *)
      status_color=$OVERLAY0
      ;;
  esac

  sketchybar_cmd --set "$STATUS_ITEM" \
    drawing=on \
    icon="BT" \
    icon.color="$status_color" \
    label.color="$TEXT" \
    label="$(trim_label "$status_label" 32)"

  if have_blueutil; then
    note_drawing=off
    if [ "$power" = "off" ]; then
      toggle_label="Turn Bluetooth On"
      toggle_color=$PEACH
    else
      toggle_label="Turn Bluetooth Off"
      toggle_color=$YELLOW
    fi
  else
    note_drawing=on
    toggle_label="Install blueutil to toggle"
    toggle_color=$SUBTEXT0
  fi

  sketchybar_cmd --set "$TOGGLE_ITEM" \
    drawing=on \
    icon="PWR" \
    icon.color="$toggle_color" \
    label.color="$TEXT" \
    label="$(trim_label "$toggle_label" 32)"

  sketchybar_cmd --set "$NOTE_ITEM" \
    drawing="$note_drawing" \
    icon="PKG" \
    icon.color="$PEACH" \
    label.color="$SUBTEXT1" \
    label="brew install blueutil"

  sketchybar_cmd --set "$SETTINGS_ITEM" \
    drawing=on \
    icon="SET" \
    icon.color="$LAVENDER" \
    label.color="$TEXT" \
    label="Open Bluetooth Settings"

  slot=1
  while IFS=$(printf '\t') read -r connected name address type battery; do
    [ -n "$name" ] || continue

    item="bluetooth.device.$slot"
    details=$name
    if [ -n "$battery" ]; then
      details="$details · $battery"
    elif [ -n "$type" ]; then
      details="$details · $type"
    fi

    if [ "$connected" = "1" ]; then
      device_icon="●"
      device_icon_color=$GREEN
      device_label_color=$TEXT
    else
      device_icon="○"
      device_icon_color=$OVERLAY0
      device_label_color=$SUBTEXT0
    fi

    device_click_script="BT_DEVICE_ADDR='$address' BT_DEVICE_CONNECTED='$connected' \"$SCRIPT_DIR/bluetooth.sh\" --device"

    sketchybar_cmd --set "$item" \
      drawing=on \
      icon="$device_icon" \
      icon.color="$device_icon_color" \
      label.color="$device_label_color" \
      label="$(trim_label "$details" 32)" \
      click_script="$device_click_script"

    slot=$((slot + 1))
    [ "$slot" -le "$MAX_DEVICES" ] || break
  done <"$DEVICES_FILE"

  while [ "$slot" -le "$MAX_DEVICES" ]; do
    sketchybar_cmd --set "bluetooth.device.$slot" \
      drawing=off \
      label="—" \
      click_script="$SCRIPT_DIR/bluetooth.sh --open-settings"
    slot=$((slot + 1))
  done

  if [ "$connected_count" -eq 0 ] && [ ! -s "$DEVICES_FILE" ]; then
    sketchybar_cmd --set "bluetooth.device.1" \
      drawing=on \
      icon="○" \
      icon.color="$OVERLAY0" \
      label.color="$SUBTEXT0" \
      label="No remembered devices"
  fi
}

sync_widget() {
  collect_state_files
  if ! IFS=$(printf '\t') read -r power connected_count summary_label status_label <"$SUMMARY_FILE"; then
    power=unknown
    connected_count=0
    summary_label="Unavailable"
    status_label="Bluetooth unavailable"
  fi

  apply_main_item "$power" "$connected_count" "$summary_label"
  apply_popup_items "$power" "$connected_count" "$status_label"
  cleanup_state_files
}

toggle_popup() {
  sync_widget
  sketchybar_cmd --set "$MAIN_ITEM" popup.drawing=toggle
}

toggle_power() {
  if have_blueutil; then
    blueutil --power toggle >/dev/null 2>&1 || true
    sleep 1
    sync_widget
    sketchybar_cmd --set "$MAIN_ITEM" popup.drawing=on
  else
    open_bluetooth_settings
  fi
}

toggle_device() {
  address=${BT_DEVICE_ADDR:-}
  connected=${BT_DEVICE_CONNECTED:-0}

  [ -n "$address" ] || exit 0

  if ! have_blueutil; then
    open_bluetooth_settings
    exit 0
  fi

  if [ "$connected" = "1" ]; then
    blueutil --disconnect "$address" >/dev/null 2>&1 || true
  else
    blueutil --connect "$address" >/dev/null 2>&1 || true
  fi

  sleep 1
  sync_widget
  sketchybar_cmd --set "$MAIN_ITEM" popup.drawing=on
}

case "${1:-}" in
  --click)
    case "${BUTTON:-left}" in
      right)
        open_bluetooth_settings
        ;;
      *)
        toggle_popup
        ;;
    esac
    ;;
  --toggle-power)
    toggle_power
    ;;
  --device)
    toggle_device
    ;;
  --open-settings)
    open_bluetooth_settings
    ;;
  --install-help)
    open_blueutil_home
    ;;
  *)
    sync_widget
    ;;
esac
