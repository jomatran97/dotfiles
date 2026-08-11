#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HCOM_DIR="$PROJECT_ROOT/.multi-agent-runtime/hcom"
export PROJECT_ROOT HCOM_DIR
. "$MULTI_AGENT_HOME/tools/_runtime.sh"

if [ "$#" -eq 0 ]; then
  set -- lead craft audit build debug scout trace ideas
fi
for role in "$@"; do
  if ! runtime_role_is_known "$role"; then
    runtime_error "unknown framework role: $role"
    exit 2
  fi
done
runtime_require_command hcom || exit 1
runtime_prepare || exit 1
cd "$PROJECT_ROOT" || exit 1
for role in "$@"; do
  if ! hcom kill "tag:$role"; then
    printf 'WARN: role %s was not active or could not be stopped\n' "$role" >&2
  fi
done
exit 0
