#!/usr/bin/env bash
# Apply the non-secret hcom settings. Idempotent: safe to re-run.
# Never writes secrets; never touches $HCOM_DIR/config.toml directly.
set -euo pipefail
SCRIPT_PATH=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_PATH" ]; do
  DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
  LINK=$(readlink "$SCRIPT_PATH")
  case "$LINK" in /*) SCRIPT_PATH=$LINK ;; *) SCRIPT_PATH="$DIR/$LINK" ;; esac
done
SCRIPT_DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
# shellcheck source=multiagent/bin/lib.sh
. "$(cd "$SCRIPT_DIR/.." && pwd)/multiagent/bin/lib.sh"

ma_hcom_config_set terminal tmux || true
ma_hcom_config_set auto_approve true || true
ma_hcom_config_set auto_subscribe "collision,stopped" || true

# Idle-reap timeout must be >= the longest phase timeout or headless workers get
# reaped mid-task. IMPLEMENTER_TIMEOUT is the largest, so derive from it (+25% slack).
ma_idle_timeout=$(( IMPLEMENTER_TIMEOUT + IMPLEMENTER_TIMEOUT / 4 ))
ma_hcom_config_set timeout "$ma_idle_timeout" || true
printf 'hcom defaults applied (idle timeout=%s, derived from IMPLEMENTER_TIMEOUT=%s)\n' \
  "$ma_idle_timeout" "$IMPLEMENTER_TIMEOUT"
