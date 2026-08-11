#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HCOM_DIR="$PROJECT_ROOT/.multi-agent-runtime/hcom"
export PROJECT_ROOT HCOM_DIR
. "$MULTI_AGENT_HOME/tools/_runtime.sh"

if [ "$#" -lt 1 ]; then
  printf 'Usage: agent-launch {craft|audit|build|debug|scout|trace|ideas} [--headless] [task...]\n' >&2
  exit 2
fi
role=$1
shift
provider=$(runtime_role_provider "$role") || {
  runtime_error "unknown role: $role"
  exit 2
}
prompt_file=$(runtime_role_prompt "$role") || exit 2
headless=false
if [ "${1-}" = "--headless" ]; then
  headless=true
  shift
fi
if [ ! -f "$prompt_file" ]; then
  runtime_error "role prompt is missing: $prompt_file"
  exit 1
fi
runtime_require_command hcom || exit 1
runtime_require_command "$provider" || exit 1
runtime_prepare || exit 1
system_prompt=$(cat "$prompt_file")
initial_task=$*
cd "$PROJECT_ROOT" || exit 1

if $headless; then
  if [ -n "$initial_task" ]; then
    exec hcom "$provider" --tag "$role" --dir "$PROJECT_ROOT" --headless --hcom-system-prompt "$system_prompt" --hcom-prompt "$initial_task"
  fi
  exec hcom "$provider" --tag "$role" --dir "$PROJECT_ROOT" --headless --hcom-system-prompt "$system_prompt"
fi
if [ -n "$initial_task" ]; then
  exec hcom "$provider" --tag "$role" --dir "$PROJECT_ROOT" --hcom-system-prompt "$system_prompt" --hcom-prompt "$initial_task"
fi
exec hcom "$provider" --tag "$role" --dir "$PROJECT_ROOT" --hcom-system-prompt "$system_prompt"
