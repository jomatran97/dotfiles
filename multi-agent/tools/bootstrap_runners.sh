#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HCOM_DIR="$PROJECT_ROOT/.multi-agent-runtime/hcom"
export PROJECT_ROOT HCOM_DIR
. "$MULTI_AGENT_HOME/tools/_runtime.sh"

runtime_prepare || exit 1
printf 'OK: project runtime prepared: %s\n' "$HCOM_DIR"
printf 'OK: config authority: %s\n' "$MULTI_AGENT_HOME/hcom/config.toml"
for runner in hcom claude codex agy; do
  if command -v "$runner" >/dev/null 2>&1; then
    printf 'OK: runner available: %s (%s)\n' "$runner" "$(command -v "$runner")"
  else
    printf 'WARN: runner unavailable: %s\n' "$runner"
  fi
done
printf '%s\n' 'No packages installed and no Conductor state changed.'
