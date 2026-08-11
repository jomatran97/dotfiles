#!/bin/bash
set -u
DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HCOM_DIR="$PROJECT_ROOT/.multi-agent-runtime/hcom"
export PROJECT_ROOT HCOM_DIR

failures=0
source_only=false
if [ "${1-}" = "--source-only" ]; then
  source_only=true
  shift
fi
if [ "$#" -ne 0 ]; then
  printf 'Usage: healthcheck.sh [--source-only]\n' >&2
  exit 2
fi

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

check_link() {
  target=$1
  expected=$2
  if [ ! -L "$target" ]; then
    if [ -e "$target" ]; then fail "managed target is not a symlink: $target"; else fail "managed link is missing: $target"; fi
    return
  fi
  resolved=$(resolved_link_target "$target" 2>/dev/null || printf '')
  if [ "$resolved" = "$expected" ]; then ok "$target -> $expected"; else fail "managed link mismatch: $target -> $(readlink "$target" 2>/dev/null || printf '?')"; fi
}

source_files='claude/CLAUDE.md
claude/roles/craft.md
claude/roles/audit.md
codex/roles/build.md
codex/roles/debug.md
antigravity/roles/scout.md
antigravity/roles/trace.md
antigravity/roles/ideas.md
hcom/config.toml'
old_ifs=$IFS
IFS='
'
for relative in $source_files; do
  if [ -f "$MULTI_AGENT_HOME/$relative" ]; then ok "source exists: $relative"; else fail "source missing: $relative"; fi
done
IFS=$old_ifs

for script in "$DOTFILES_ROOT"/bin/agent-* "$MULTI_AGENT_HOME"/tools/*.sh "$MULTI_AGENT_HOME"/deploy_global.sh "$MULTI_AGENT_HOME"/undeploy_global.sh "$MULTI_AGENT_HOME"/tests/test_runtime.sh; do
  if [ -f "$script" ] && [ -x "$script" ]; then ok "executable source: $script"; else fail "missing or non-executable source: $script"; fi
done

config_source="$MULTI_AGENT_HOME/hcom/config.toml"
for section in '[terminal]' '[relay]' '[launch]' '[launch.claude]' '[launch.codex]' '[preferences]'; do
  if grep -F "$section" "$config_source" >/dev/null 2>&1; then :; else fail "hcom config missing section: $section"; fi
done

if $source_only; then
  if [ "$failures" -eq 0 ]; then ok 'source-only health validation passed'; fi
  exit "$failures"
fi

prohibited="$HOME/.multi-agent"
if [ -e "$prohibited" ] || [ -L "$prohibited" ]; then fail "prohibited HOME framework exists: $prohibited"; else ok "prohibited HOME framework absent: $prohibited"; fi

check_link "$HOME/.claude/CLAUDE.md" "$MULTI_AGENT_HOME/claude/CLAUDE.md"
check_link "$HOME/.hcom/config.toml" "$MULTI_AGENT_HOME/hcom/config.toml"
for name in lead launch send stop health bootstrap; do
  check_link "$HOME/.local/bin/agent-$name" "$DOTFILES_ROOT/bin/agent-$name"
  located=$(command -v "agent-$name" 2>/dev/null || printf '')
  if [ -z "$located" ]; then warn "agent-$name is not on PATH"
  elif [ "$located" = "$HOME/.local/bin/agent-$name" ]; then ok "PATH resolves agent-$name to managed link"
  else warn "PATH resolves agent-$name elsewhere: $located"
  fi
done

expected_hcom_dir="$PROJECT_ROOT/.multi-agent-runtime/hcom"
if [ "$HCOM_DIR" != "$expected_hcom_dir" ]; then fail "HCOM_DIR is not project-local: $HCOM_DIR"; else ok "project-local HCOM_DIR: $HCOM_DIR"; fi
if [ "$HCOM_DIR" = "$MULTI_AGENT_HOME/hcom" ]; then fail 'runtime state overlaps global source'; fi
if [ -d "$HCOM_DIR" ]; then
  runtime_config="$HCOM_DIR/config.toml"
  if [ -L "$runtime_config" ]; then
    resolved=$(resolved_link_target "$runtime_config" 2>/dev/null || printf '')
    if [ "$resolved" = "$config_source" ]; then ok 'project config links to global authority'; else fail "project config link mismatch: $runtime_config"; fi
  elif [ -e "$runtime_config" ]; then fail "project config is unmanaged: $runtime_config"
  else warn 'project runtime exists without config link'; fi
else
  warn "project runtime is not prepared: $HCOM_DIR"
fi

for command_name in hcom claude codex agy; do
  if command -v "$command_name" >/dev/null 2>&1; then ok "external command available: $command_name"; else warn "optional external command unavailable: $command_name"; fi
done

if [ "$failures" -eq 0 ]; then ok 'multi-agent architecture is healthy'; fi
exit "$failures"
