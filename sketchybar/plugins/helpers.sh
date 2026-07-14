#!/bin/sh

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
CONFIG_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=../colors.sh
. "$CONFIG_DIR/colors.sh"

DEFAULT_ICON_FONT=${DEFAULT_ICON_FONT:-"SF Pro Text:Semibold:12.0"}
DEFAULT_LABEL_FONT=${DEFAULT_LABEL_FONT:-"SF Pro Text:Medium:12.0"}
APP_ICON_FONT=${APP_ICON_FONT:-"sketchybar-app-font:Regular:16.0"}

sketchybar_cmd() {
  if command -v sketchybar >/dev/null 2>&1; then
    sketchybar "$@"
  elif [ -x /opt/homebrew/bin/sketchybar ]; then
    /opt/homebrew/bin/sketchybar "$@"
  elif [ -x /usr/local/bin/sketchybar ]; then
    /usr/local/bin/sketchybar "$@"
  else
    return 127
  fi
}

yabai_query() {
  yabai -m query "$@" 2>/dev/null || printf ''
}

json_bool() {
  json=$1
  key=$2
  compact=$(printf '%s' "$json" | tr -d '\n ')

  case "$compact" in
    *"\"$key\":true"*) printf 'true\n' ;;
    *"\"$key\":false"*) printf 'false\n' ;;
    *) printf '\n' ;;
  esac
}

json_string() {
  json=$1
  key=$2
  printf '%s' "$json" | tr '\n' ' ' | sed -n "s/.*\"$key\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

json_number() {
  json=$1
  key=$2
  printf '%s' "$json" | tr '\n' ' ' | sed -n "s/.*\"$key\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" | head -n 1
}

json_array_count() {
  json=$1
  key=$2
  values=$(printf '%s' "$json" | tr -d '\n ' | sed -n "s/.*\"$key\":\[\([^]]*\)\].*/\1/p" | head -n 1)

  if [ -z "$values" ]; then
    printf '0\n'
    return
  fi

  printf '%s' "$values" | awk -F',' '{ print NF }'
}

json_array_strings() {
  json=$1
  key=$2

  printf '%s' "$json" \
    | tr '\n' ' ' \
    | sed 's/}[[:space:]]*,[[:space:]]*{/}\
{/g' \
    | sed -n "s/.*\"$key\":[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

trim_label() {
  value=$1
  max=${2:-32}

  printf '%s\n' "$value" | awk -v max="$max" '
    {
      if (length($0) > max) {
        print substr($0, 1, max - 1) "…"
      } else {
        print
      }
    }
  '
}

space_windows_label() {
  count=$1

  case "$count" in
    0) printf '—\n' ;;
    1) printf '•\n' ;;
    2) printf '••\n' ;;
    3) printf '•••\n' ;;
    4) printf '••••\n' ;;
    *) printf '%sw\n' "$count" ;;
  esac
}

app_icon_map_path() {
  if [ -x "$CONFIG_DIR/helpers/icon_map.sh" ]; then
    printf '%s\n' "$CONFIG_DIR/helpers/icon_map.sh"
    return 0
  fi

  if [ -x "$CONFIG_DIR/icon_map.sh" ]; then
    printf '%s\n' "$CONFIG_DIR/icon_map.sh"
    return 0
  fi

  return 1
}

has_app_icon_font() {
  [ -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ] || [ -f "/Library/Fonts/sketchybar-app-font.ttf" ]
}

builtin_app_icon_token() {
  app=$1

  case "$app" in
    Desktop) printf ':desktop:\n' ;;
    Ghostty) printf ':terminal:\n' ;;
    Terminal) printf ':terminal:\n' ;;
    iTerm2) printf ':iterm:\n' ;;
    kitty) printf ':kitty:\n' ;;
    WezTerm) printf ':wezterm:\n' ;;
    Warp) printf ':warp:\n' ;;
    Arc) printf ':arc:\n' ;;
    Brave|Brave\ Browser) printf ':brave_browser:\n' ;;
    Google\ Chrome|Chrome) printf ':google_chrome:\n' ;;
    Firefox|Firefox\ Developer\ Edition|Floorp) printf ':firefox:\n' ;;
    Safari) printf ':safari:\n' ;;
    Code|Code\ -\ Insiders|Visual\ Studio\ Code) printf ':code:\n' ;;
    VSCodium) printf ':vscodium:\n' ;;
    Cursor) printf ':cursor:\n' ;;
    Zed|Zed\ Preview) printf ':zed:\n' ;;
    Nova) printf ':nova:\n' ;;
    Sublime\ Text) printf ':sublime_text:\n' ;;
    Xcode) printf ':xcode:\n' ;;
    Android\ Studio) printf ':android_studio:\n' ;;
    PyCharm|PyCharm\ CE|PyCharm\ Professional) printf ':pycharm:\n' ;;
    GoLand) printf ':goland:\n' ;;
    CLion) printf ':clion:\n' ;;
    DataGrip) printf ':datagrip:\n' ;;
    Rider) printf ':rider:\n' ;;
    IntelliJ\ IDEA|IntelliJ\ IDEA\ CE|IntelliJ\ IDEA\ Ultimate|WebStorm|PhpStorm|RubyMine) printf ':code:\n' ;;
    Slack) printf ':slack:\n' ;;
    Microsoft\ Teams|Microsoft\ Teams\ classic|Teams) printf ':microsoft_teams:\n' ;;
    Messages|iMessage|Android\ Messages) printf ':messages:\n' ;;
    Telegram) printf ':telegram:\n' ;;
    Signal) printf ':signal:\n' ;;
    *WhatsApp) printf ':whats_app:\n' ;;
    Zalo) printf ':messages:\n' ;;
    Discord) printf ':discord:\n' ;;
    Notes) printf ':notes:\n' ;;
    Obsidian) printf ':obsidian:\n' ;;
    Notion) printf ':notion:\n' ;;
    Bear) printf ':bear:\n' ;;
    Craft) printf ':craft:\n' ;;
    Logseq) printf ':logseq:\n' ;;
    FSNotes) printf ':fsnotes:\n' ;;
    1Password) printf ':one_password:\n' ;;
    Bitwarden) printf ':bit_warden:\n' ;;
    Passwords|KeePassXC|Enpass) printf ':passwords:\n' ;;
    Finder) printf ':finder:\n' ;;
    Preview) printf ':preview:\n' ;;
    Mail) printf ':mail:\n' ;;
    Calendar) printf ':calendar:\n' ;;
    Spotify) printf ':spotify:\n' ;;
    Music) printf ':music:\n' ;;
    TV) printf ':apple_tv:\n' ;;
    Books) printf ':apple_books:\n' ;;
    Docker) printf ':docker:\n' ;;
    OrbStack) printf ':orbstack:\n' ;;
    Figma) printf ':figma:\n' ;;
    Claude) printf ':claude:\n' ;;
    Codex) printf ':codex:\n' ;;
    ChatGPT|ChatGPT\ Atlas) printf ':chatgpt_atlas:\n' ;;
    System\ Settings|System\ Preferences|Activity\ Monitor|Calculator|Disk\ Utility|Font\ Book|System\ Information) printf ':gear:\n' ;;
    *) printf ':default:\n' ;;
  esac
}

fallback_app_icon() {
  app=$1

  case "$app" in
    Desktop) printf '⌂\n' ;;
    Ghostty|Terminal|iTerm2|kitty|WezTerm|Warp) printf '⌘\n' ;;
    Arc|Brave|Brave\ Browser|Google\ Chrome|Chrome|Firefox|Firefox\ Developer\ Edition|Floorp|Safari) printf '🌐\n' ;;
    Code|Code\ -\ Insiders|Visual\ Studio\ Code|VSCodium|Cursor|Zed|Zed\ Preview|Nova|Sublime\ Text|Xcode|Android\ Studio|PyCharm|PyCharm\ CE|PyCharm\ Professional|GoLand|CLion|DataGrip|Rider|IntelliJ\ IDEA|IntelliJ\ IDEA\ CE|IntelliJ\ IDEA\ Ultimate|WebStorm|PhpStorm|RubyMine) printf '⌨\n' ;;
    Slack|Microsoft\ Teams|Microsoft\ Teams\ classic|Teams|Messages|iMessage|Android\ Messages|Telegram|Signal|*WhatsApp|Zalo|Discord) printf '💬\n' ;;
    Notes|Obsidian|Notion|Bear|Craft|Logseq|FSNotes) printf '✎\n' ;;
    1Password|Bitwarden|Passwords|KeePassXC|Enpass) printf '🔐\n' ;;
    Finder) printf '📁\n' ;;
    Preview) printf '📄\n' ;;
    Mail) printf '✉︎\n' ;;
    Calendar) printf '📆\n' ;;
    Spotify|Music) printf '♪\n' ;;
    TV|Books) printf '▶\n' ;;
    Docker|OrbStack) printf '🐳\n' ;;
    Figma) printf '🎨\n' ;;
    Claude|Codex|ChatGPT|ChatGPT\ Atlas) printf '✦\n' ;;
    System\ Settings|System\ Preferences|Activity\ Monitor|Calculator|Disk\ Utility|Font\ Book|System\ Information) printf '⚙\n' ;;
    *) printf '•\n' ;;
  esac
}

app_icon() {
  app=$1

  if has_app_icon_font; then
    if map_path=$(app_icon_map_path 2>/dev/null); then
      icon=$("$map_path" "$app" 2>/dev/null | awk '{$1=$1; print}')
      if [ -n "$icon" ]; then
        printf '%s\n' "$icon"
        return
      fi
    fi

    builtin_app_icon_token "$app"
    return
  fi

  fallback_app_icon "$app"
}

space_app_icons() {
  json=$1
  max=${2:-4}
  apps=$(json_array_strings "$json" "app")

  if [ -z "$apps" ]; then
    printf '—\n'
    return
  fi

  count=0
  extra=0
  icons=""

  while IFS= read -r app; do
    [ -n "$app" ] || continue

    count=$((count + 1))
    if [ "$count" -le "$max" ]; then
      icon=$(app_icon "$app")
      if [ -z "$icons" ]; then
        icons=$icon
      else
        icons="$icons $icon"
      fi
    else
      extra=$((extra + 1))
    fi
  done <<EOF_APPS
$apps
EOF_APPS

  if [ -z "$icons" ]; then
    icons="—"
  fi

  if [ "$extra" -gt 0 ]; then
    icons="$icons …"
  fi

  printf '%s\n' "$icons"
}

space_app_icons_from_list() {
  apps_raw=$1
  max=${2:-4}

  if [ -z "$apps_raw" ]; then
    printf '—\n'
    return
  fi

  apps=$(printf '%s' "$apps_raw" | tr "$(printf '\037')" '\n')
  count=0
  extra=0
  icons=""

  while IFS= read -r app; do
    [ -n "$app" ] || continue

    count=$((count + 1))
    if [ "$count" -le "$max" ]; then
      icon=$(app_icon "$app")
      if [ -z "$icons" ]; then
        icons=$icon
      else
        icons="$icons $icon"
      fi
    else
      extra=$((extra + 1))
    fi
  done <<EOF_APPS
$apps
EOF_APPS

  if [ -z "$icons" ]; then
    icons="—"
  fi

  if [ "$extra" -gt 0 ]; then
    icons="$icons …"
  fi

  printf '%s\n' "$icons"
}
