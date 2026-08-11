#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME

dry_run=false
force=false
for option in "$@"; do
  case "$option" in
    --dry-run) dry_run=true ;;
    --force) force=true ;;
    *) printf 'Usage: deploy_global.sh [--dry-run] [--force]\n' >&2; exit 2 ;;
  esac
done

failures=0
ok() { printf 'OK: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }

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

is_expected_link() {
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

if [ ! -d "$DOTFILES_ROOT" ] || [ ! -d "$MULTI_AGENT_HOME" ]; then
  fail "fixed source roots are unavailable: $DOTFILES_ROOT"
fi
for source in \
  "$MULTI_AGENT_HOME/claude/CLAUDE.md" \
  "$MULTI_AGENT_HOME/hcom/config.toml" \
  "$DOTFILES_ROOT/bin/agent-lead" \
  "$DOTFILES_ROOT/bin/agent-launch" \
  "$DOTFILES_ROOT/bin/agent-send" \
  "$DOTFILES_ROOT/bin/agent-stop" \
  "$DOTFILES_ROOT/bin/agent-health" \
  "$DOTFILES_ROOT/bin/agent-bootstrap"; do
  if [ ! -f "$source" ]; then fail "source missing: $source"; fi
done
if [ "$failures" -ne 0 ]; then exit 1; fi

if $dry_run; then
  printf 'DRY-RUN: would ensure %s, %s, and %s\n' "$HOME/.claude" "$HOME/.hcom" "$HOME/.local/bin"
  while IFS='|' read target source; do
    if is_expected_link "$target" "$source"; then
      ok "already linked: $target -> $source"
    elif [ -e "$target" ] || [ -L "$target" ]; then
      if $force; then printf 'DRY-RUN: would move %s to %s.backup-YYYYMMDD-HHMMSS and link %s\n' "$target" "$target" "$source"
      else warn "would preserve conflict: $target"; fi
    else
      printf 'DRY-RUN: would link %s -> %s\n' "$target" "$source"
    fi
  done <<EOF
$(manifest)
EOF
  exec "$MULTI_AGENT_HOME/tools/healthcheck.sh" --source-only
fi

mkdir -p "$HOME/.claude" "$HOME/.hcom" "$HOME/.local/bin" || {
  fail 'could not create managed HOME directories'
  exit 1
}

while IFS='|' read target source; do
  if is_expected_link "$target" "$source"; then
    ok "already linked: $target -> $source"
    continue
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    if ! $force; then
      warn "preserving conflict: $target"
      failures=$((failures + 1))
      continue
    fi
    backup="$target.backup-$(date +%Y%m%d-%H%M%S)"
    if [ -e "$backup" ] || [ -L "$backup" ]; then
      fail "backup already exists; refusing overwrite: $backup"
      continue
    fi
    if mv "$target" "$backup"; then ok "backed up conflict: $backup"; else fail "could not back up conflict: $target"; continue; fi
  fi
  if ln -s "$source" "$target"; then ok "linked: $target -> $source"; else fail "could not link: $target"; fi
done <<EOF
$(manifest)
EOF

while IFS='|' read target source; do
  if ! is_expected_link "$target" "$source"; then fail "resulting link invalid: $target"; fi
done <<EOF
$(manifest)
EOF

for name in lead launch send stop health bootstrap; do
  located=$(command -v "agent-$name" 2>/dev/null || printf '')
  if [ "$located" = "$HOME/.local/bin/agent-$name" ]; then ok "PATH resolves agent-$name"; else warn "PATH does not resolve managed agent-$name link"; fi
done

if ! "$MULTI_AGENT_HOME/tools/healthcheck.sh"; then failures=$((failures + 1)); fi
if [ "$failures" -ne 0 ]; then exit 1; fi
ok 'global multi-agent links deployed'
