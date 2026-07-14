#!/usr/bin/env bash
# tests/test_config_validation.sh
# Phase 5 configuration validation harness.
#
# Verifies the audited structural invariants of the multi-agent runtime:
#   1. Flat directory topology (only claude/, codex/, antigravity/; no hidden dot-roots).
#   2. No local executable tool directories (claude/skills, codex/tools, antigravity/bin).
#   3. Required provider manifests/settings/research scopes/personas exist.
#   4. Tool-allocation boundaries in codex/config.yaml and all MCP manifests
#      (run-scoped tags, context markers, target_locks, ${AGENT_SKILLS} command
#       resolution, Reviewer denials, Idea-Analyzer no-fallback, Antigravity no-sweep).
#
# Exit code 0 = all checks passed; non-zero = at least one failure.
set -Euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TESTS_DIR/.." && pwd)}"
CONFIG_PATH="$PROJECT_ROOT/codex/config.yaml"
ROOT_MCP="$PROJECT_ROOT/codex/mcp/root.json"
PROVIDER_MCPS=("$PROJECT_ROOT/claude/mcp.json" "$PROJECT_ROOT/codex/mcp.json" "$PROJECT_ROOT/antigravity/mcp.json")

PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "== Directory flatness =="
for root in claude codex antigravity; do
  if [[ -d "$PROJECT_ROOT/$root" ]]; then
    pass "flat config root present: $root/"
  else
    fail "flat config root missing: $root/"
  fi
done

for hidden in .multi-agent .claude .codex .antigravity; do
  if [[ -d "$PROJECT_ROOT/$hidden" ]]; then
    fail "forbidden hidden repository root present: $hidden/"
  else
    pass "no hidden repository root: $hidden/"
  fi
done

echo "== Forbidden local tool directories =="
for tool_dir in claude/skills codex/tools antigravity/bin; do
  if [[ -d "$PROJECT_ROOT/$tool_dir" ]]; then
    fail "forbidden local tool path present: $tool_dir/ (tools must resolve under \$AGENT_SKILLS)"
  else
    pass "no local tool path: $tool_dir/"
  fi
done

echo "== Required flat provider topology =="
for rel in \
  claude/settings.local.json \
  claude/mcp.json \
  claude/agents/planner.md \
  claude/agents/coder.md \
  claude/agents/reviewer.md \
  codex/mcp.json \
  codex/agents/implementation.md \
  codex/agents/debugger.md \
  antigravity/research_scopes.json \
  antigravity/mcp.json \
  antigravity/agents/researcher.md \
  antigravity/agents/idea_analyzer.md \
  antigravity/agents/edge_case_explorer.md; do
  if [[ -f "$PROJECT_ROOT/$rel" ]]; then
    pass "required provider file present: $rel"
  else
    fail "required provider file missing: $rel"
  fi
done

echo "== Deployment defaults =="
if grep -Eq '^DEST_MODE="flat"' "$PROJECT_ROOT/install_global_config.sh"; then
  pass "install_global_config.sh defaults to flat home destinations"
else
  fail "install_global_config.sh does not default to flat home destinations"
fi
if grep -Eq '^DEST_MODE="flat"' "$PROJECT_ROOT/deploy_runtime.sh"; then
  pass "deploy_runtime.sh defaults to flat home destinations"
else
  fail "deploy_runtime.sh does not default to flat home destinations"
fi
if grep -q -- '--provider-native-home' "$PROJECT_ROOT/install_global_config.sh" && grep -q -- '--provider-native-home' "$PROJECT_ROOT/deploy_runtime.sh"; then
  pass "hidden provider-native home destinations require explicit opt-in flag"
else
  fail "missing explicit opt-in flag for hidden provider-native home destinations"
fi

echo "== Tool-allocation boundaries (config + root manifest) =="
if [[ ! -f "$CONFIG_PATH" ]]; then
  fail "config not found: $CONFIG_PATH"
elif [[ ! -f "$ROOT_MCP" ]]; then
  fail "root manifest not found: $ROOT_MCP"
else
  BOUNDARY_REPORT="$(
    python3 - "$CONFIG_PATH" "$ROOT_MCP" "${PROVIDER_MCPS[@]}" <<'PY'
import json, sys
import subprocess
from pathlib import Path
try:
    import yaml
except ModuleNotFoundError:
    yaml = None

def load_yaml(path):
    if yaml is not None:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh) or {}
    try:
        out = subprocess.check_output(
            ["ruby", "-ryaml", "-rjson", "-e", "puts JSON.generate(YAML.load_file(ARGV[0]))", path],
            text=True,
        )
    except Exception as exc:
        print(f"FAIL\tPyYAML unavailable and Ruby YAML fallback failed: {exc}")
        sys.exit(0)
    return json.loads(out) or {}

config_path, root_mcp_path, *provider_mcp_paths = sys.argv[1:]
project_root = str(Path(config_path).resolve().parents[1])
cfg = load_yaml(config_path)
with open(root_mcp_path, encoding="utf-8") as fh:
    mcp = json.load(fh)

results = []
def check(name, ok):
    results.append((("PASS" if ok else "FAIL"), name))

AGENT_SKILLS = "/Users/ryanparker/Documents/personal/code/AI/agent_skills"

# --- Run-scoped root tag pattern ---
naming = cfg.get("naming", {})
check("root_tag_pattern is run-scoped (sdlc-root-{runner}-{run_id})",
      naming.get("root_tag_pattern") == "sdlc-root-{runner}-{run_id}")

# --- Full context-marker set ---
required_markers = {
    "MULTI_AGENT_RUNNER", "MULTI_AGENT_ROLE", "MULTI_AGENT_PARENT_RUNNER",
    "MULTI_AGENT_CHILD_KEY", "MULTI_AGENT_TASK_ID", "MULTI_AGENT_ATTEMPT_ID",
    "MULTI_AGENT_TAG", "MULTI_AGENT_TAG_TARGET", "MULTI_AGENT_BATCH_ID",
    "MULTI_AGENT_LAUNCH_ID", "MULTI_AGENT_SEND_ID",
}
markers = set((cfg.get("environment", {}) or {}).get("context_markers", []) or [])
missing = required_markers - markers
check("all 11 MULTI_AGENT_* context markers declared" + ("" if not missing else f" (missing: {sorted(missing)})"),
      not missing)

# --- SQLite: target_locks + full audited field schema ---
sqlite = cfg.get("sqlite", {})
check("sqlite.tables includes target_locks", bool(sqlite.get("tables", {}).get("target_locks")))
required_fields = {
    "id", "run_id", "runner", "parent_runner", "child_key", "task_id", "attempt_id",
    "tag", "tag_target", "batch_id", "resolved_instance_name", "pid", "status",
    "attempt_count", "deadline_at", "created_at", "updated_at", "error_code", "error_message",
}
fields = set(sqlite.get("required_fields", []) or [])
missing_fields = required_fields - fields
check("all 19 audited SQLite fields declared" + ("" if not missing_fields else f" (missing: {sorted(missing_fields)})"),
      not missing_fields)

# --- Validation flags ---
val = cfg.get("validation", {})
check("validation.forbid_local_skill_dirs is true", val.get("forbid_local_skill_dirs") is True)
check("validation.require_run_scoped_root_tags is true", val.get("require_run_scoped_root_tags") is True)
check("validation.forbid_idea_analyzer_file_fallback is true", val.get("forbid_idea_analyzer_file_fallback") is True)
check("validation.forbid_antigravity_raw_file_sweeps is true", val.get("forbid_antigravity_raw_file_sweeps") is True)
check("validation.deny_reviewer_snapshot_and_golden_and_shell is true", val.get("deny_reviewer_snapshot_and_golden_and_shell") is True)

# --- Profiles: Reviewer denials ---
profiles = cfg.get("mcp_profiles", {})
rev = profiles.get("claude_reviewer", {})
rev_denies = set(rev.get("denies", []) or [])
check("Reviewer denies file-write", "file-write" in rev_denies)
check("Reviewer denies snapshot-update", "snapshot-update" in rev_denies)
check("Reviewer denies golden-file-rewrite", "golden-file-rewrite" in rev_denies)
check("Reviewer denies arbitrary-shell-string", "arbitrary-shell-string" in rev_denies)
check("Reviewer shell.mode == none", (rev.get("shell", {}) or {}).get("mode") == "none")

# --- Profiles: Idea Analyzer sovereignty ---
idea = profiles.get("antigravity_idea_analyzer", {})
check("Idea Analyzer raw_file_read_fallback == false", idea.get("raw_file_read_fallback") is False)
check("Idea Analyzer on_graph_miss requests refresh/export",
      idea.get("on_graph_miss") == "request-idea-context-refresh-export")
check("Idea Analyzer raw_file_sweeps forbidden", idea.get("raw_file_sweeps") == "forbidden")

# --- Profiles: Antigravity researcher no raw sweeps ---
res = profiles.get("antigravity_researcher", {})
check("Antigravity researcher raw_file_sweeps forbidden", res.get("raw_file_sweeps") == "forbidden")
check("Antigravity researcher structural_source == idea_context_only",
      res.get("structural_source") == "idea_context_only")

# --- Every profile has a complete shell control block ---
shell_keys = {"mode", "allowedCommands", "timeoutSeconds", "workingDirectoryPolicy"}
for pname, prof in profiles.items():
    shell = prof.get("shell", {}) or {}
    check(f"profile '{pname}' has complete shell block", shell_keys.issubset(shell.keys()))

# --- Root manifest: mandatory shell control block ---
mshell = mcp.get("shell", {})
check("root.json shell block has all 4 keys", shell_keys.issubset(mshell.keys()))
check("root.json shell.workingDirectoryPolicy is project-root-or-generated-state-only",
      mshell.get("workingDirectoryPolicy") == "project-root-or-generated-state-only")

# --- Root manifest: every server command resolves under ${AGENT_SKILLS} (no local wrappers) ---
def resolves_under_skills(cmd: str) -> bool:
    if not isinstance(cmd, str) or not cmd:
        return False
    # Prefix siblings like ${AGENT_SKILLS}_evil are outside the trusted registry.
    # Valid placeholders are expanded and canonicalized below, so traversal such
    # as ${AGENT_SKILLS}/../evil is rejected by containment.
    if cmd.startswith("${AGENT_SKILLS}") and not cmd.startswith("${AGENT_SKILLS}/"):
        return False
    cmd = cmd.replace("${AGENT_SKILLS}", AGENT_SKILLS)
    candidate = Path(cmd).expanduser()
    if not candidate.is_absolute():
        return False
    try:
        root = Path(AGENT_SKILLS).expanduser().resolve(strict=False)
        resolved = candidate.resolve(strict=False)
        resolved.relative_to(root)
        return True
    except Exception:
        return False

check("AGENT_SKILLS containment accepts literal placeholder child", resolves_under_skills("${AGENT_SKILLS}/mcp/provider_server"))
check("AGENT_SKILLS containment accepts absolute child", resolves_under_skills(f"{AGENT_SKILLS}/mcp/provider_server"))
check("AGENT_SKILLS containment rejects placeholder sibling", not resolves_under_skills("${AGENT_SKILLS}_evil/mcp/provider_server"))
check("AGENT_SKILLS containment rejects absolute sibling", not resolves_under_skills(f"{AGENT_SKILLS}_evil/mcp/provider_server"))
check("AGENT_SKILLS containment rejects placeholder traversal", not resolves_under_skills("${AGENT_SKILLS}/../agent_skills_evil/mcp/provider_server"))

servers = mcp.get("mcpServers", {})
bad_cmds = [name for name, s in servers.items() if not resolves_under_skills(str(s.get("command", "")))]
check("all MCP server commands resolve under ${AGENT_SKILLS}" + ("" if not bad_cmds else f" (offenders: {bad_cmds})"),
      not bad_cmds)

# --- Provider manifests: every server command resolves under ${AGENT_SKILLS} ---
for manifest_path in provider_mcp_paths:
    try:
        with open(manifest_path, encoding="utf-8") as fh:
            provider_mcp = json.load(fh)
    except FileNotFoundError:
        check(f"provider MCP manifest exists: {manifest_path}", False)
        continue
    servers = provider_mcp.get("mcpServers", {})
    bad = [name for name, s in servers.items() if not resolves_under_skills(str(s.get("command", "")))]
    check(f"provider MCP commands resolve under ${{AGENT_SKILLS}}: {manifest_path}" + ("" if not bad else f" (offenders: {bad})"), not bad)

# --- Config references: manifests, settings, research scopes, prompts/personas exist ---
def expand(value: str) -> str:
    return value.replace("${PROJECT_ROOT}", project_root).replace("${AGENT_SKILLS}", AGENT_SKILLS).replace("${RUN_ID}", "validation")

missing_refs = []
for provider, pdata in (cfg.get("providers") or {}).items():
    for key in ("settings", "mcp_manifest", "root_mcp_manifest", "research_scopes"):
        value = (pdata or {}).get(key)
        if value and not Path(expand(value)).is_file():
            missing_refs.append(f"providers.{provider}.{key}={expand(value)}")
for profile, pdata in (cfg.get("mcp_profiles") or {}).items():
    value = (pdata or {}).get("manifest")
    if value and not Path(expand(value)).is_file():
        missing_refs.append(f"mcp_profiles.{profile}.manifest={expand(value)}")
for runner_name, runner in (cfg.get("runners") or {}).items():
    for key in ("prompt", "mcp_manifest"):
        value = (runner or {}).get(key)
        if value and not Path(expand(value)).is_file():
            missing_refs.append(f"runners.{runner_name}.{key}={expand(value)}")
    for child_name, child in ((runner or {}).get("children") or {}).items():
        for key in ("prompt", "mcp_manifest"):
            value = (child or {}).get(key)
            if value and not Path(expand(value)).is_file():
                missing_refs.append(f"runners.{runner_name}.children.{child_name}.{key}={expand(value)}")
        for value in (child or {}).get("required_inputs") or []:
            if not Path(expand(value)).exists():
                missing_refs.append(f"runners.{runner_name}.children.{child_name}.required_input={expand(value)}")
check("config-referenced manifests/settings/research scopes/prompts exist" + ("" if not missing_refs else f" (missing: {missing_refs})"), not missing_refs)

# --- Root manifest: every tool source resolves under ${AGENT_SKILLS} ---
bad_srcs = [t.get("name") for t in mcp.get("toolDefinitions", []) if not resolves_under_skills(str(t.get("source", "")))]
check("all tool sources resolve under ${AGENT_SKILLS}" + ("" if not bad_srcs else f" (offenders: {bad_srcs})"),
      not bad_srcs)

# --- Root manifest: denied-by-default + key denials present ---
sec = mcp.get("security", {})
check("root.json defaultPolicy == deny", sec.get("defaultPolicy") == "deny")
denied = set(mcp.get("deniedCapabilities", []) or [])
for cap in ("local-stdio-wrapper-command", "command-outside-agent-skills",
            "idea-analyzer-raw-file-fallback", "antigravity-raw-file-sweep",
            "reviewer-snapshot-update", "reviewer-golden-file-rewrite",
            "reviewer-arbitrary-shell", "cleanup-outside-current-run-id"):
    check(f"root.json denies '{cap}'", cap in denied)

for status, name in results:
    print(f"{status}\t{name}")
PY
  )"
  while IFS=$'\t' read -r status name; do
    [[ -n "$status" ]] || continue
    if [[ "$status" == "PASS" ]]; then pass "$name"; else fail "$name"; fi
  done <<< "$BOUNDARY_REPORT"
fi

echo
echo "== Summary =="
printf 'passed: %d   failed: %d\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
