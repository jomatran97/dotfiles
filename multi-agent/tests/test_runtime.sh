#!/bin/bash
set -u

DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles
MULTI_AGENT_HOME="$DOTFILES_ROOT/multi-agent"
export DOTFILES_ROOT MULTI_AGENT_HOME

failures=0
checks=0
TMP_ROOT=""
ORIGINAL_HOME=${HOME-}
ORIGINAL_PATH=$PATH

pass() {
  checks=$((checks + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  checks=$((checks + 1))
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

assert_true() {
  description=$1
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

assert_false() {
  description=$1
  shift
  if "$@"; then fail "$description"; else pass "$description"; fi
}

assert_file_text() {
  description=$1
  expected=$2
  path=$3
  actual=$(cat "$path" 2>/dev/null || printf '__MISSING__')
  if [ "$actual" = "$expected" ]; then pass "$description"; else fail "$description"; fi
}

assert_grep() {
  description=$1
  pattern=$2
  path=$3
  if grep -E "$pattern" "$path" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}

cleanup() {
  HOME=$ORIGINAL_HOME
  PATH=$ORIGINAL_PATH
  export HOME PATH
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
}
trap cleanup EXIT HUP INT TERM

expected_manifest() {
  cat <<'EOF'
bin/agent-bootstrap
bin/agent-health
bin/agent-launch
bin/agent-lead
bin/agent-send
bin/agent-stop
multi-agent/antigravity/roles/ideas.md
multi-agent/antigravity/roles/scout.md
multi-agent/antigravity/roles/trace.md
multi-agent/claude/CLAUDE.md
multi-agent/claude/roles/audit.md
multi-agent/claude/roles/craft.md
multi-agent/codex/roles/build.md
multi-agent/codex/roles/debug.md
multi-agent/deploy_global.sh
multi-agent/hcom/config.toml
multi-agent/tests/test_runtime.sh
multi-agent/tools/_runtime.sh
multi-agent/tools/bootstrap_runners.sh
multi-agent/tools/healthcheck.sh
multi-agent/tools/launch_agent.sh
multi-agent/tools/send_task.sh
multi-agent/tools/start_lead.sh
multi-agent/tools/stop_agents.sh
multi-agent/undeploy_global.sh
EOF
}

setup_fake_commands() {
  fake_bin=$1
  log=$2
  mkdir -p "$fake_bin"
  cat > "$fake_bin/hcom" <<EOF
#!/bin/bash
{
  printf 'CALL HCOM_DIR=%s PWD=%s\\n' "\${HCOM_DIR-}" "\$PWD"
  for arg in "\$@"; do printf 'ARG=%s\\n' "\$arg"; done
  printf 'END\\n'
} >> "$log"
exit 0
EOF
  chmod +x "$fake_bin/hcom"
  for command_name in claude codex agy; do
    cat > "$fake_bin/$command_name" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$fake_bin/$command_name"
  done
}

run_in() {
  directory=$1
  shift
  (cd "$directory" && "$@")
}

printf '%s\n' '== source and syntax =='
actual_manifest=$(cd "$DOTFILES_ROOT" && find bin multi-agent -type f 2>/dev/null | LC_ALL=C sort)
expected=$(expected_manifest)
if [ "$actual_manifest" = "$expected" ]; then pass 'source manifest is exact'; else
  fail 'source manifest is exact'
  printf '%s\n' '--- expected ---' "$expected" '--- actual ---' "$actual_manifest" >&2
fi

syntax_ok=true
for script in "$DOTFILES_ROOT"/bin/agent-* "$MULTI_AGENT_HOME"/tools/*.sh "$MULTI_AGENT_HOME"/deploy_global.sh "$MULTI_AGENT_HOME"/undeploy_global.sh "$MULTI_AGENT_HOME"/tests/test_runtime.sh; do
  if [ ! -f "$script" ] || ! bash -n "$script"; then syntax_ok=false; fi
done
if $syntax_ok; then pass 'all shell entrypoints pass bash -n'; else fail 'all shell entrypoints pass bash -n'; fi

executable_ok=true
for script in "$DOTFILES_ROOT"/bin/agent-* "$MULTI_AGENT_HOME"/tools/*.sh "$MULTI_AGENT_HOME"/deploy_global.sh "$MULTI_AGENT_HOME"/undeploy_global.sh "$MULTI_AGENT_HOME"/tests/test_runtime.sh; do
  if [ ! -x "$script" ]; then executable_ok=false; fi
done
if $executable_ok; then pass 'all shell entrypoints are executable'; else fail 'all shell entrypoints are executable'; fi

for pair in 'agent-lead:start_lead.sh' 'agent-launch:launch_agent.sh' 'agent-send:send_task.sh' 'agent-stop:stop_agents.sh' 'agent-health:healthcheck.sh' 'agent-bootstrap:bootstrap_runners.sh'; do
  wrapper=${pair%%:*}
  target=${pair#*:}
  assert_grep "$wrapper has fixed root" '^DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles$' "$DOTFILES_ROOT/bin/$wrapper"
  assert_grep "$wrapper directly execs $target" "^exec /Users/ryanparker/Documents/personal/code/dotfiles/multi-agent/tools/$target" "$DOTFILES_ROOT/bin/$wrapper"
done
assert_grep 'runtime ignore is present' '^\.multi-agent-runtime/$' "$DOTFILES_ROOT/.gitignore"
for runtime_script in start_lead.sh launch_agent.sh send_task.sh stop_agents.sh healthcheck.sh bootstrap_runners.sh; do
  assert_grep "$runtime_script has fixed root" '^DOTFILES_ROOT=/Users/ryanparker/Documents/personal/code/dotfiles$' "$MULTI_AGENT_HOME/tools/$runtime_script"
  assert_grep "$runtime_script uses exact project detection" '^PROJECT_ROOT=\$\(git rev-parse --show-toplevel 2>/dev/null \|\| pwd\)$' "$MULTI_AGENT_HOME/tools/$runtime_script"
  assert_grep "$runtime_script exports project HCOM_DIR" '^HCOM_DIR="\$PROJECT_ROOT/\.multi-agent-runtime/hcom"$' "$MULTI_AGENT_HOME/tools/$runtime_script"
done
assert_false 'runtime never resolves through HOME/.multi-agent' grep -R -E 'HOME/\.multi-agent|~/\.multi-agent' "$DOTFILES_ROOT/bin" "$MULTI_AGENT_HOME/tools/_runtime.sh" "$MULTI_AGENT_HOME/tools/start_lead.sh" "$MULTI_AGENT_HOME/tools/launch_agent.sh" "$MULTI_AGENT_HOME/tools/send_task.sh" "$MULTI_AGENT_HOME/tools/stop_agents.sh" "$MULTI_AGENT_HOME/tools/bootstrap_runners.sh"
assert_false 'runtime never invokes hcom config' grep -R -E '(^|[;&|])[[:space:]]*(exec[[:space:]]+)?hcom[[:space:]]+config([[:space:]]|$)' "$DOTFILES_ROOT/bin" "$MULTI_AGENT_HOME/tools"

printf '%s\n' '== isolated runtime behavior =='
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/multi-agent-test.XXXXXX")
TMP_ROOT=$(cd -P "$TMP_ROOT" && pwd)
HOME="$TMP_ROOT/home"
FAKE_BIN="$TMP_ROOT/fake-bin"
HCOM_LOG="$TMP_ROOT/hcom.log"
PROJECT_ONE="$TMP_ROOT/project-one"
PROJECT_TWO="$TMP_ROOT/project-two"
mkdir -p "$HOME" "$PROJECT_ONE" "$PROJECT_TWO"
git -C "$PROJECT_ONE" init -q
git -C "$PROJECT_TWO" init -q
setup_fake_commands "$FAKE_BIN" "$HCOM_LOG"
PATH="$FAKE_BIN:$HOME/.local/bin:/usr/bin:/bin"
export HOME PATH HCOM_TEST_LOG="$HCOM_LOG"

assert_true 'bootstrap prepares project one' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-bootstrap"
assert_true 'bootstrap prepares project two' run_in "$PROJECT_TWO" "$DOTFILES_ROOT/bin/agent-bootstrap"
assert_true 'project one config is a symlink' test -L "$PROJECT_ONE/.multi-agent-runtime/hcom/config.toml"
assert_true 'project two config is a symlink' test -L "$PROJECT_TWO/.multi-agent-runtime/hcom/config.toml"
assert_file_text 'project one config links directly to global source' "$MULTI_AGENT_HOME/hcom/config.toml" <(readlink "$PROJECT_ONE/.multi-agent-runtime/hcom/config.toml")
assert_file_text 'project two config links directly to global source' "$MULTI_AGENT_HOME/hcom/config.toml" <(readlink "$PROJECT_TWO/.multi-agent-runtime/hcom/config.toml")
assert_file_text 'project one config has global authority' "$(cat "$MULTI_AGENT_HOME/hcom/config.toml")" "$PROJECT_ONE/.multi-agent-runtime/hcom/config.toml"
assert_file_text 'project two config has global authority' "$(cat "$MULTI_AGENT_HOME/hcom/config.toml")" "$PROJECT_TWO/.multi-agent-runtime/hcom/config.toml"

: > "$HCOM_LOG"
assert_true 'send succeeds in project one' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-send" craft 'one message'
assert_true 'send succeeds in project two' run_in "$PROJECT_TWO" "$DOTFILES_ROOT/bin/agent-send" build 'two message'
assert_grep 'project one uses isolated HCOM_DIR' "CALL HCOM_DIR=$PROJECT_ONE/.multi-agent-runtime/hcom PWD=$PROJECT_ONE" "$HCOM_LOG"
assert_grep 'project two uses isolated HCOM_DIR' "CALL HCOM_DIR=$PROJECT_TWO/.multi-agent-runtime/hcom PWD=$PROJECT_TWO" "$HCOM_LOG"
assert_grep 'send targets a validated hcom address' '^ARG=@craft$' "$HCOM_LOG"
assert_grep 'send uses bigboss sender mode' '^ARG=-b$' "$HCOM_LOG"

: > "$HCOM_LOG"
assert_true 'lead launch succeeds' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-lead" 'initial lead task'
assert_grep 'lead maps to claude' '^ARG=claude$' "$HCOM_LOG"
assert_grep 'lead is tagged lead' '^ARG=lead$' "$HCOM_LOG"
assert_grep 'lead runs here' '^ARG=--run-here$' "$HCOM_LOG"
assert_grep 'lead gets initial prompt' '^ARG=initial lead task$' "$HCOM_LOG"

for mapping in 'craft:claude' 'audit:claude' 'build:codex' 'debug:codex' 'scout:agy' 'trace:agy' 'ideas:agy'; do
  role=${mapping%%:*}
  provider=${mapping#*:}
  : > "$HCOM_LOG"
  assert_true "$role launch succeeds" run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-launch" "$role" --headless "task for $role"
  assert_grep "$role maps to $provider" "^ARG=$provider$" "$HCOM_LOG"
  assert_grep "$role gets its tag" "^ARG=$role$" "$HCOM_LOG"
  assert_grep "$role supports headless" '^ARG=--headless$' "$HCOM_LOG"
  assert_grep "$role gets a system prompt" '^ARG=--hcom-system-prompt$' "$HCOM_LOG"
  assert_grep "$role gets initial task" "^ARG=task for $role$" "$HCOM_LOG"
done
assert_false 'unknown role is rejected' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-launch" unknown nope

: > "$HCOM_LOG"
assert_true 'default stop is idempotent' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-stop"
for role in lead craft audit build debug scout trace ideas; do
  assert_grep "stop scopes $role explicitly" "^ARG=tag:$role$" "$HCOM_LOG"
done
assert_false 'stop never uses kill all' grep -E '^ARG=all$' "$HCOM_LOG"
assert_false 'unknown stop scope is rejected' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-stop" stranger

CONFLICT_PROJECT="$TMP_ROOT/conflict-project"
mkdir -p "$CONFLICT_PROJECT/.multi-agent-runtime/hcom"
git -C "$CONFLICT_PROJECT" init -q
printf 'preserve me\n' > "$CONFLICT_PROJECT/.multi-agent-runtime/hcom/config.toml"
assert_false 'runtime config conflict is refused' run_in "$CONFLICT_PROJECT" "$DOTFILES_ROOT/bin/agent-bootstrap"
assert_file_text 'runtime config conflict is preserved' 'preserve me' "$CONFLICT_PROJECT/.multi-agent-runtime/hcom/config.toml"

printf '%s\n' '== deployment safety =='
HOME="$TMP_ROOT/deploy-home"
mkdir -p "$HOME"
PATH="$FAKE_BIN:$HOME/.local/bin:/usr/bin:/bin"
export HOME PATH
assert_true 'deploy dry-run succeeds source-only' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/deploy_global.sh" --dry-run
assert_false 'deploy dry-run creates no HOME directories' test -e "$HOME/.local"
assert_false 'deploy dry-run creates no claude directory' test -e "$HOME/.claude"

assert_true 'deploy creates managed links' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/deploy_global.sh"
assert_true 'deploy is idempotent' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/deploy_global.sh"
for item in \
  "$HOME/.claude/CLAUDE.md:$MULTI_AGENT_HOME/claude/CLAUDE.md" \
  "$HOME/.hcom/config.toml:$MULTI_AGENT_HOME/hcom/config.toml" \
  "$HOME/.local/bin/agent-lead:$DOTFILES_ROOT/bin/agent-lead" \
  "$HOME/.local/bin/agent-launch:$DOTFILES_ROOT/bin/agent-launch" \
  "$HOME/.local/bin/agent-send:$DOTFILES_ROOT/bin/agent-send" \
  "$HOME/.local/bin/agent-stop:$DOTFILES_ROOT/bin/agent-stop" \
  "$HOME/.local/bin/agent-health:$DOTFILES_ROOT/bin/agent-health" \
  "$HOME/.local/bin/agent-bootstrap:$DOTFILES_ROOT/bin/agent-bootstrap"; do
  target=${item%%:*}
  source=${item#*:}
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then pass "managed link $target"; else fail "managed link $target"; fi
done
assert_false 'deploy never creates prohibited HOME framework' test -e "$HOME/.multi-agent"
if find "$HOME" -type f -name '*.md' -print | grep . >/dev/null 2>&1; then fail 'deploy adds no HOME role files'; else pass 'deploy adds no HOME role files'; fi
link_count=$(find "$HOME" -type l | wc -l | tr -d ' ')
if [ "$link_count" = 8 ]; then pass 'deploy creates exactly eight manifest links'; else fail 'deploy creates exactly eight manifest links'; fi
assert_true 'health passes with links and PATH' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-health"
rm "$HOME/.local/bin/agent-send"
assert_false 'health fails a missing managed link' run_in "$PROJECT_ONE" "$DOTFILES_ROOT/bin/agent-health"
assert_true 'deploy repairs a missing managed link' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/deploy_global.sh"

HOME="$TMP_ROOT/conflict-home"
mkdir -p "$HOME/.claude"
printf 'user policy\n' > "$HOME/.claude/CLAUDE.md"
PATH="$FAKE_BIN:$HOME/.local/bin:/usr/bin:/bin"
export HOME PATH
assert_false 'default deploy reports conflict' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/deploy_global.sh"
assert_file_text 'default deploy preserves conflict' 'user policy' "$HOME/.claude/CLAUDE.md"
assert_true 'force deploy backs up conflict' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/deploy_global.sh" --force
backup_count=$(find "$HOME/.claude" -type f -name 'CLAUDE.md.backup-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]' | wc -l | tr -d ' ')
if [ "$backup_count" = 1 ]; then pass 'force backup uses exact timestamp naming'; else fail 'force backup uses exact timestamp naming'; fi
assert_file_text 'force backup preserves original bytes' 'user policy' "$(find "$HOME/.claude" -type f -name 'CLAUDE.md.backup-*' | head -1)"

printf 'keep regular\n' > "$TMP_ROOT/regular"
rm "$HOME/.local/bin/agent-launch"
cp "$TMP_ROOT/regular" "$HOME/.local/bin/agent-launch"
rm "$HOME/.local/bin/agent-send"
ln -s "$TMP_ROOT/does-not-exist" "$HOME/.local/bin/agent-send"
assert_true 'undeploy dry-run succeeds' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/undeploy_global.sh" --dry-run
assert_true 'undeploy removes only owned links' run_in "$PROJECT_ONE" "$MULTI_AGENT_HOME/undeploy_global.sh"
assert_file_text 'undeploy preserves regular conflict' 'keep regular' "$HOME/.local/bin/agent-launch"
assert_true 'undeploy preserves unrelated broken symlink' test -L "$HOME/.local/bin/agent-send"
assert_false 'undeploy removes owned claude link' test -L "$HOME/.claude/CLAUDE.md"
assert_true 'undeploy preserves force backup' test -f "$(find "$HOME/.claude" -type f -name 'CLAUDE.md.backup-*' | head -1)"
assert_false 'undeploy never creates prohibited HOME framework' test -e "$HOME/.multi-agent"

printf '\nChecks: %s, failures: %s\n' "$checks" "$failures"
if [ "$failures" -ne 0 ]; then exit 1; fi
printf '%s\n' 'All multi-agent runtime tests passed.'
