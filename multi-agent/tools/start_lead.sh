#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HCOM_DIR="$PROJECT_ROOT/.multi-agent-runtime/hcom"
export PROJECT_ROOT HCOM_DIR
. "$MULTI_AGENT_HOME/tools/_runtime.sh"

runtime_require_command hcom || exit 1
runtime_require_command claude || exit 1
runtime_prepare || exit 1

initial_prompt=$*
cd "$PROJECT_ROOT" || exit 1
if [ -n "$initial_prompt" ]; then
  exec hcom claude --tag lead --dir "$PROJECT_ROOT" --run-here --hcom-prompt "$initial_prompt"
fi
exec hcom claude --tag lead --dir "$PROJECT_ROOT" --run-here
