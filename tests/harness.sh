#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"
python3 -m compileall -q "$ROOT/arbiter" "$ROOT/providers" "$ROOT/tests"
"$ROOT/scripts/arbiter" --root "$ROOT" check-gates >/dev/null
"$ROOT/scripts/arbiter" --root "$ROOT" startup-validate >/dev/null
"$ROOT/scripts/arbiter" --root "$ROOT" workflow-state --json >/dev/null
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cat >"$TMP_DIR/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
if [[ "${1:-}" == "exec" ]]; then echo "$*"; exit 0; fi
printf '%s\n' "$*"
EOF
chmod +x "$TMP_DIR/codex"
export CODEX_BIN="$TMP_DIR/codex"
"$ROOT/scripts/arbiter" --root "$ROOT" hcom send build --prompt "harness smoke" --json >/dev/null
