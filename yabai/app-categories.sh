# shellcheck shell=sh
# Shared newline-separated yabai app names.
# Names must match the running process name (what yabai reports as app), which
# can differ from the bundle name (e.g. VS Code is "Code"; see installed()).
# Keep values as newline lists because app names can contain spaces.

export YABAI_CHAT_APPS='Zalo
WhatsApp
Telegram
Messages
Signal
Slack
Discord
Microsoft Teams'

export YABAI_TERMINAL_APPS='Terminal
iTerm2
Warp
Ghostty
WezTerm
kitty
Alacritty
Code
Cursor
DataGrip
DBeaver
TablePlus
Docker Desktop
Postman
Insomnia'

export YABAI_WEB_APPS='Safari
Safari Technology Preview
Google Chrome
Chromium
Arc
Firefox
Microsoft Edge
Brave Browser
Orion'

export YABAI_NOTES_APPS='Notes'

export YABAI_ALL_APPS="${YABAI_CHAT_APPS}
${YABAI_TERMINAL_APPS}
${YABAI_WEB_APPS}
${YABAI_NOTES_APPS}"
