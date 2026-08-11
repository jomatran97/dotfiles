#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HCOM_DIR="$PROJECT_ROOT/.multi-agent-runtime/hcom"
export PROJECT_ROOT HCOM_DIR
. "$MULTI_AGENT_HOME/tools/_runtime.sh"

if [ "$#" -lt 2 ]; then
  printf 'Usage: agent-send TARGET MESSAGE...\n' >&2
  exit 2
fi
target=$1
shift
case "$target" in
  @*) bare_target=${target#@} ;;
  *) bare_target=$target ;;
esac
case "$bare_target" in
  ''|*[!A-Za-z0-9_.:-]*)
    runtime_error "invalid target: $target"
    exit 2
    ;;
esac
message=$*
runtime_require_command hcom || exit 1
runtime_prepare || exit 1
cd "$PROJECT_ROOT" || exit 1
exec hcom send -b "@$bare_target" -- "$message"
