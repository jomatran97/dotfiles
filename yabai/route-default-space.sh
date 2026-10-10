#!/usr/bin/env sh
# Guarded default Space router for yabai.
# Routes normal manageable windows not covered by category app rules to the
# Space labeled "default" without forcing focus to another Space.

set -eu

script_dir="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)" || exit 1
YABAI_DIR="${YABAI_DIR:-$script_dir}"
. "$YABAI_DIR/app-categories.sh"

wid="${1:-}"
[ -n "$wid" ] || exit 0

# Give yabai a moment to finish populating properties for newly-created windows.
sleep 0.2

json="$(yabai -m query --windows --window "$wid" 2>/dev/null || true)"
[ -n "$json" ] || exit 0

# Strip U+200E/U+200F: some apps (WhatsApp) prefix their name with a left-to-right
# mark, which would otherwise defeat the exact-match category lookup below.
value() {
  printf '%s' "$json" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); v=d.get(sys.argv[1], ""); print(v.replace("‎","").replace("‏","") if isinstance(v,str) else v)' "$1" 2>/dev/null || true
}

app="$(value app)"
title="$(value title)"
role="$(value role)"
subrole="$(value subrole)"
can_move="$(value can-move)"
can_resize="$(value can-resize)"
has_ax="$(value has-ax-reference)"
is_floating="$(value is-floating)"

# Category apps are handled by explicit yabai rules and must never be caught by
# the default router.
printf '%s\n' "$YABAI_ALL_APPS" | grep -Fxq "$app" && exit 0

case "$app" in
  System\ Settings|System\ Preferences) exit 0 ;;
esac

# Do not move preference/settings panels even if an app exposes them as a
# standard window.
case "$title" in
  Preferences|Settings|*\ Preferences|*\ Settings) exit 0 ;;
esac

# Only route normal, safe, manageable application windows.
[ "$role" = "AXWindow" ] || exit 0
[ "$subrole" = "AXStandardWindow" ] || exit 0
[ "$can_move" = "True" ] || exit 0
[ "$can_resize" = "True" ] || exit 0
[ "$has_ax" = "True" ] || exit 0
[ "$is_floating" = "False" ] || exit 0

yabai -m window "$wid" --space default 2>/dev/null || true
