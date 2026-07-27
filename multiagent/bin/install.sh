#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_PATH" ]; do
  DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
  LINK=$(readlink "$SCRIPT_PATH")
  case "$LINK" in /*) SCRIPT_PATH=$LINK ;; *) SCRIPT_PATH="$DIR/$LINK" ;; esac
done
SCRIPT_DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
DOTFILES=$(cd "$SCRIPT_DIR/../.." >/dev/null 2>&1 && pwd)
export DOTFILES
# shellcheck source=multiagent/bin/lib.sh
. "$DOTFILES/multiagent/bin/lib.sh"

backup_path() {
  local path=$1 ts candidate n
  ts=$(date '+%Y%m%d-%H%M%S')
  candidate="$path.bak.$ts"
  n=0
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    n=$((n+1)); candidate="$path.bak.$ts.$n"
  done
  printf '%s\n' "$candidate"
}

link_one() {
  local src=$1 dst=$2
  [ -e "$src" ] || ma_die "source missing: $src"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    local cur
    cur=$(readlink "$dst")
    if [ "$cur" = "$src" ]; then
      printf 'OK symlink %s -> %s\n' "$dst" "$src"
      return 0
    fi
    local bak
    bak=$(backup_path "$dst")
    mv "$dst" "$bak"
    printf 'BACKUP symlink %s -> %s\n' "$dst" "$bak"
  elif [ -e "$dst" ]; then
    local bak
    bak=$(backup_path "$dst")
    mv "$dst" "$bak"
    printf 'BACKUP %s -> %s\n' "$dst" "$bak"
  fi
  ln -s "$src" "$dst"
  printf 'LINK %s -> %s\n' "$dst" "$src"
}

chmod +x "$DOTFILES"/multiagent/bin/*.sh
printf 'DOTFILES=%s\n' "$DOTFILES"
printf 'MULTIAGENT_RUNS=%s\n' "$MULTIAGENT_RUNS"
printf 'HCOM_DIR=%s\n' "$HCOM_DIR"

if [ -e "$HOME/.hcom" ] || [ -L "$HOME/.hcom" ]; then
  if [ "$HCOM_DIR" = "$HOME/.hcom" ]; then
    ma_die "HCOM_DIR must not point at legacy ~/.hcom"
  fi
  if [ -e "$HCOM_DIR" ] || [ -L "$HCOM_DIR" ]; then
    legacy_count=$(find "$HOME/.hcom" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
    if [ "$legacy_count" -gt 0 ]; then
      legacy_dst=$(backup_path "$HCOM_DIR/legacy-dot-hcom")
      mv "$HOME/.hcom" "$legacy_dst"
      printf 'MIGRATE %s -> %s (legacy default home preserved, not active)\n' "$HOME/.hcom" "$legacy_dst"
    else
      rmdir "$HOME/.hcom" 2>/dev/null || ma_die "legacy ~/.hcom exists but could not be removed"
      printf 'MIGRATE removed empty legacy %s\n' "$HOME/.hcom"
    fi
  else
    mkdir -p "$(dirname "$HCOM_DIR")"
    mv "$HOME/.hcom" "$HCOM_DIR"
    printf 'MIGRATE %s -> %s\n' "$HOME/.hcom" "$HCOM_DIR"
  fi
fi

mkdir -p "$MULTIAGENT_RUNS" "$HCOM_DIR"
printf 'MKDIR %s\n' "$MULTIAGENT_RUNS"
printf 'MKDIR %s\n' "$HCOM_DIR"
mkdir -p "$MA_BIN" "$CLAUDE_CONFIG_DIR/commands" "$CLAUDE_CONFIG_DIR/agents" "$CODEX_HOME/agents" "$GEMINI_CONFIG_DIR"

link_one "$DOTFILES/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
link_one "$DOTFILES/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
link_one "$DOTFILES/claude/commands/architect.md" "$CLAUDE_CONFIG_DIR/commands/architect.md"
link_one "$DOTFILES/claude/commands/next-task.md" "$CLAUDE_CONFIG_DIR/commands/next-task.md"
link_one "$DOTFILES/claude/agents/architect.md" "$CLAUDE_CONFIG_DIR/agents/architect.md"
link_one "$DOTFILES/claude/agents/reviewer.md" "$CLAUDE_CONFIG_DIR/agents/reviewer.md"
link_one "$DOTFILES/multiagent/AGENTS.md" "$CODEX_HOME/AGENTS.md"
link_one "$DOTFILES/codex/config.toml" "$CODEX_HOME/config.toml"
link_one "$DOTFILES/codex/agents/scout.md" "$CODEX_HOME/agents/scout.md"
link_one "$DOTFILES/codex/agents/implementer.md" "$CODEX_HOME/agents/implementer.md"
link_one "$DOTFILES/multiagent/AGENTS.md" "$GEMINI_CONFIG_DIR/AGENTS.md"
link_one "$DOTFILES/gemini/GEMINI.md" "$GEMINI_CONFIG_DIR/GEMINI.md"

if [ -L "$HCOM_DIR/config.toml" ]; then
  ma_die "refusing to continue: $HCOM_DIR/config.toml is a symlink; it may hold a relay PSK and must stay untracked"
fi
link_one "$DOTFILES/hcom/env" "$HCOM_DIR/env"
if [ -d "$DOTFILES/hcom/scripts" ]; then
  mkdir -p "$HCOM_DIR/scripts"
  for script_src in "$DOTFILES"/hcom/scripts/*; do
    [ -e "$script_src" ] || continue
    [ -f "$script_src" ] || [ -L "$script_src" ] || continue
    link_one "$script_src" "$HCOM_DIR/scripts/$(basename "$script_src")"
  done
fi

for name in architect new-run dispatch status selfcheck run; do
  link_one "$DOTFILES/multiagent/bin/$name.sh" "$MA_BIN/ma-$name"
done

expected_writable_roots="writable_roots = [\"$MULTIAGENT_RUNS\"]"
if grep -Fxq "$expected_writable_roots" "$DOTFILES/codex/config.toml"; then
  printf 'OK codex writable_roots matches %s\n' "$MULTIAGENT_RUNS"
else
  printf 'WARN codex/config.toml writable_roots drift: expected %s\n' "$expected_writable_roots" >&2
fi

if grep -q "$MULTIAGENT_RUNS" "$DOTFILES/claude/architect.settings.json"; then
  printf 'OK architect.settings.json covers %s\n' "$MULTIAGENT_RUNS"
else
  printf 'WARN claude/architect.settings.json paths do not cover MULTIAGENT_RUNS=%s (permission rules will not match)\n' "$MULTIAGENT_RUNS" >&2
fi

bash "$DOTFILES/hcom/config.defaults.sh"

printf 'Install complete. No hcom config file was symlinked; no per-tag notes were set.\n'
