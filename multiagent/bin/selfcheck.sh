#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_PATH" ]; do
  DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
  LINK=$(readlink "$SCRIPT_PATH")
  case "$LINK" in /*) SCRIPT_PATH=$LINK ;; *) SCRIPT_PATH="$DIR/$LINK" ;; esac
done
SCRIPT_DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
# shellcheck source=multiagent/bin/lib.sh
. "$SCRIPT_DIR/lib.sh"

fail=0
ok() { printf 'OK %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*"; fail=1; }
skip() { printf 'SKIP %s\n' "$*"; }

run_limited() {
  local seconds=$1 outfile=$2; shift 2
  : > "$outfile"
  ( "$@" >"$outfile" 2>&1 ) &
  local pid=$! start now
  start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    now=$(date +%s)
    if [ $((now-start)) -ge "$seconds" ]; then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
      wait "$pid" 2>/dev/null || true
      printf '\n[TIMED OUT after %ss]\n' "$seconds" >> "$outfile"
      return 124
    fi
    sleep 1
  done
  wait "$pid"
}

sentinel='MULTIAGENT_CHARTER_SENTINEL_RP_20260716_HCOM_ASYNC'
printf 'DOTFILES=%s\nMULTIAGENT_RUNS=%s\nHCOM_DIR=%s\n' "$DOTFILES" "$MULTIAGENT_RUNS" "$HCOM_DIR"
for c in hcom claude agy codex tmux git; do
  if ma_have "$c"; then ok "command $c -> $(command -v "$c")"; else bad "command missing: $c"; fi
done

check_link() {
  local dst=$1 src=$2 actual
  if [ ! -L "$dst" ]; then bad "not symlink: $dst"; return; fi
  actual=$(readlink "$dst")
  case "$actual" in "$src") ok "symlink $dst -> $actual" ;; *) bad "symlink $dst -> $actual (expected $src)" ;; esac
}
check_link "$HOME/config/claude/CLAUDE.md" "$DOTFILES/claude/CLAUDE.md"
check_link "$HOME/config/claude/settings.json" "$DOTFILES/claude/settings.json"
check_link "$HOME/config/claude/commands/architect.md" "$DOTFILES/claude/commands/architect.md"
check_link "$HOME/config/claude/commands/next-task.md" "$DOTFILES/claude/commands/next-task.md"
check_link "$HOME/config/claude/agents/architect.md" "$DOTFILES/claude/agents/architect.md"
check_link "$HOME/config/claude/agents/reviewer.md" "$DOTFILES/claude/agents/reviewer.md"
check_link "$HOME/config/codex/AGENTS.md" "$DOTFILES/multiagent/AGENTS.md"
check_link "$HOME/config/codex/config.toml" "$DOTFILES/codex/config.toml"
check_link "$HOME/config/codex/agents/scout.md" "$DOTFILES/codex/agents/scout.md"
check_link "$HOME/config/codex/agents/implementer.md" "$DOTFILES/codex/agents/implementer.md"
check_link "$HOME/config/gemini/AGENTS.md" "$DOTFILES/multiagent/AGENTS.md"
check_link "$HOME/config/gemini/GEMINI.md" "$DOTFILES/gemini/GEMINI.md"
for name in architect new-run dispatch status selfcheck run; do check_link "$MA_BIN/ma-$name" "$DOTFILES/multiagent/bin/$name.sh"; done
check_link "$HCOM_DIR/env" "$DOTFILES/hcom/env"

check_not_dotfiles_symlink() {
  local dst=$1 actual target
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then ok "not present: $dst"; return; fi
  if [ ! -L "$dst" ]; then ok "not symlink into dotfiles: $dst"; return; fi
  actual=$(readlink "$dst")
  case "$actual" in
    /*) target=$actual ;;
    *) target=$(cd -P "$(dirname "$dst")" >/dev/null 2>&1 && cd -P "$(dirname "$actual")" >/dev/null 2>&1 && printf '%s/%s' "$(pwd)" "$(basename "$actual")") ;;
  esac
  case "$target" in
    "$DOTFILES"|"$DOTFILES"/*) bad "secret/runtime symlink into dotfiles: $dst -> $actual" ;;
    *) ok "not symlink into dotfiles: $dst -> $actual" ;;
  esac
}
check_not_dotfiles_symlink "$HCOM_DIR/config.toml"

case ":$PATH:" in
  *":$MA_BIN:"*) ok "PATH includes $MA_BIN" ;;
  *) bad "PATH missing $MA_BIN" ;;
esac

check_env_file_value() {
  local key=$1 expected=$2 actual
  actual=$(awk -F= -v k="$key" '$1 == k {print substr($0, length(k) + 2); found=1} END {if (!found) exit 1}' "$HCOM_DIR/env" 2>/dev/null || true)
  if [ "$actual" = "$expected" ]; then ok "hcom env $key=$actual"; else bad "hcom env $key=$actual (expected $expected)"; fi
}
check_env_file_value CLAUDE_CONFIG_DIR "$CLAUDE_CONFIG_DIR"
check_env_file_value CODEX_HOME "$CODEX_HOME"
check_env_file_value GEMINI_CONFIG_DIR "$GEMINI_CONFIG_DIR"

grep -q "$sentinel" "$DOTFILES/multiagent/AGENTS.md" && ok "sentinel present in charter" || bad "sentinel missing"

run_provider_sentinel() {
  local provider=$1 out rc tmp
  tmp=$(mktemp)
  case "$provider" in
    claude)
      ma_have claude || { skip "claude sentinel load (missing)"; rm -f "$tmp"; return; }
      set +e; run_limited 45 "$tmp" env CLAUDE_CONFIG_DIR="$HOME/config/claude" claude -p "Print the exact multiagent charter sentinel string."; rc=$?; set -e ;;
    codex)
      ma_have codex || { skip "codex sentinel load (missing)"; rm -f "$tmp"; return; }
      set +e; run_limited 45 "$tmp" env CODEX_HOME="$HOME/config/codex" codex exec --cd "$PWD" "Print the exact multiagent charter sentinel string."; rc=$?; set -e ;;
    agy)
      ma_have agy || { skip "agy sentinel load (missing)"; rm -f "$tmp"; return; }
      set +e; run_limited 45 "$tmp" agy --print "Print the exact multiagent charter sentinel string."; rc=$?; set -e ;;
    *) rm -f "$tmp"; return ;;
  esac
  out=$(cat "$tmp"); rm -f "$tmp"
  if printf '%s\n' "$out" | grep -q "$sentinel"; then ok "$provider charter sentinel observed"; else bad "$provider charter sentinel not observed (rc=$rc)"; printf '%s\n' "$out" | sed -n '1,40p'; fi
}

if [ "${MA_LIVE_CHECKS:-1}" = "1" ]; then
  run_provider_sentinel claude
  run_provider_sentinel codex
  run_provider_sentinel agy
else
  skip "provider sentinel live checks disabled (MA_LIVE_CHECKS=0)"
fi

if [ "${MA_LIVE_CHECKS:-1}" = "1" ] && ma_have hcom; then
  for p in claude codex agy; do
    tag="selfcheck-$p-$$"
    case "$p" in
      claude) hcom claude --headless --tag "$tag" --hcom-prompt "Reply ready then wait." >/dev/null 2>&1 || bad "hcom spawn $p" ;;
      codex) hcom codex --headless --dir "$PWD" --tag "$tag" --hcom-prompt "Reply ready then wait." >/dev/null 2>&1 || bad "hcom spawn $p" ;;
      agy) hcom agy --terminal tmux --dir "$PWD" --tag "$tag" --hcom-prompt "Reply ready then wait." >/dev/null 2>&1 || bad "hcom spawn $p" ;;
    esac
    hcom send -b "@$tag" -- "PING" >/dev/null 2>&1 || bad "hcom send $p"
    hcom kill "tag:$tag" >/dev/null 2>&1 || bad "hcom kill $p"
  done
elif [ "${MA_LIVE_CHECKS:-1}" != "1" ]; then
  skip "minimal hcom round-trip disabled (MA_LIVE_CHECKS=0)"
else
  bad "minimal hcom round-trip skipped because hcom is missing"
fi

# Worker DONE tokens ride hcom auto_approve; if it is off, every `hcom send` prompts and
# headless workers stall silently (runs degrade to slow polling at best).
if ma_have hcom; then
  aa=$(hcom config auto_approve 2>/dev/null || true)
  case "$aa" in
    *true*) ok "hcom auto_approve enabled" ;;
    *) bad "hcom auto_approve not enabled — worker DONE sends may prompt/stall (run hcom/config.defaults.sh)" ;;
  esac
else
  skip "hcom auto_approve check (hcom missing)"
fi

if [ "$fail" -eq 0 ]; then printf 'SELFCHECK PASS\n'; else printf 'SELFCHECK FAIL\n'; fi
exit "$fail"
