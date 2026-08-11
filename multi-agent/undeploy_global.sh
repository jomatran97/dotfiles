#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME

dry_run=false
if [ "$#" -gt 1 ]; then printf 'Usage: undeploy_global.sh [--dry-run]\n' >&2; exit 2; fi
if [ "${1-}" = "--dry-run" ]; then dry_run=true
elif [ "$#" -ne 0 ]; then printf 'Usage: undeploy_global.sh [--dry-run]\n' >&2; exit 2
fi

resolved_link_target() {
  link_path=$1
  raw_target=$(readlink "$link_path" 2>/dev/null) || return 1
  case "$raw_target" in
    /*) candidate=$raw_target ;;
    *) candidate=$(dirname "$link_path")/$raw_target ;;
  esac
  candidate_dir=$(dirname "$candidate")
  candidate_base=$(basename "$candidate")
  if [ ! -d "$candidate_dir" ]; then return 1; fi
  canonical_dir=$(cd -P "$candidate_dir" 2>/dev/null && pwd) || return 1
  printf '%s/%s\n' "$canonical_dir" "$candidate_base"
}

owned_link() {
  target=$1
  expected=$2
  [ -L "$target" ] || return 1
  resolved=$(resolved_link_target "$target" 2>/dev/null || printf '')
  [ "$resolved" = "$expected" ]
}

manifest() {
  cat <<EOF
$HOME/.claude/CLAUDE.md|$MULTI_AGENT_HOME/claude/CLAUDE.md
$HOME/.hcom/config.toml|$MULTI_AGENT_HOME/hcom/config.toml
$HOME/.local/bin/agent-lead|$DOTFILES_ROOT/bin/agent-lead
$HOME/.local/bin/agent-launch|$DOTFILES_ROOT/bin/agent-launch
$HOME/.local/bin/agent-send|$DOTFILES_ROOT/bin/agent-send
$HOME/.local/bin/agent-stop|$DOTFILES_ROOT/bin/agent-stop
$HOME/.local/bin/agent-health|$DOTFILES_ROOT/bin/agent-health
$HOME/.local/bin/agent-bootstrap|$DOTFILES_ROOT/bin/agent-bootstrap
EOF
}

failures=0
while IFS='|' read target expected; do
  if owned_link "$target" "$expected"; then
    if $dry_run; then
      printf 'DRY-RUN: would remove owned link: %s\n' "$target"
    elif rm "$target"; then
      printf 'OK: removed owned link: %s\n' "$target"
    else
      printf 'FAIL: could not remove owned link: %s\n' "$target" >&2
      failures=$((failures + 1))
    fi
  elif [ -e "$target" ] || [ -L "$target" ]; then
    printf 'OK: preserved unowned target: %s\n' "$target"
  else
    printf 'OK: already absent: %s\n' "$target"
  fi
done <<EOF
$(manifest)
EOF

if [ "$failures" -ne 0 ]; then exit 1; fi
printf '%s\n' 'OK: undeploy complete; directories, backups, projects, and source were preserved.'
