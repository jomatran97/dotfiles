#!/usr/bin/env python3
"""tests/test_hcom_bus.py

Phase 5 automation harness for the hcom message bus / SQLite state ledger.

It drives the real ``bootstrap_runners.sh`` against a hermetic temporary project
root and asserts the audited transactional behaviors:

  1. Delivered path  - a send under an uncontended target lock reaches
                       status='delivered' and the message body is persisted to
                       the outbox; the (fake) hcom binary is actually invoked.
  2. Lock-timeout    - a send whose target lock is already held is NOT dropped
                       and does NOT call ``hcom send``. The sends row is
                       preserved with status='lock-timeout', attempt_count
                       incremented, a retry_after timestamp set, and the body
                       intact in the outbox.
  3. Ledger schema   - launches/sends/children/cleanup/target_locks tables exist
                       and the launches table carries all 19 audited columns.
  4. Static guards   - the script records send intent with BEGIN IMMEDIATE and
                       never calls hcom send on the lock-timeout branch.

Exit code 0 = all assertions passed; non-zero = at least one failure.
Standard library only.
"""

from __future__ import annotations

import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import textwrap
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = REPO_ROOT / "bootstrap_runners.sh"
RUN_ID = "testrun"

AUDITED_COLUMNS = [
    "id", "run_id", "runner", "parent_runner", "child_key", "task_id",
    "attempt_id", "tag", "tag_target", "batch_id", "resolved_instance_name",
    "pid", "status", "attempt_count", "deadline_at", "created_at", "updated_at",
    "error_code", "error_message",
]

_PASS = 0
_FAIL = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global _PASS, _FAIL
    if ok:
        _PASS += 1
        print(f"  PASS  {name}")
    else:
        _FAIL += 1
        suffix = f"  ({detail})" if detail else ""
        print(f"  FAIL  {name}{suffix}")


def safe_filename(value: str) -> str:
    """Mirror of safe_filename() in bootstrap_runners.sh for lock-path prediction."""
    value = re.sub(r"[^A-Za-z0-9._-]+", "-", value)
    value = re.sub(r"^-+", "", value)
    value = re.sub(r"-+$", "", value)
    return value


def write_min_config(project_root: Path, skills_dir: Path) -> Path:
    cfg = textwrap.dedent(
        f"""\
        schema_version: "1.0"
        skill_registry:
          path: "{skills_dir}"
        hcom:
          executable: "hcom"
          hcom_dir: "${{PROJECT_ROOT}}/codex/state/hcom"
        sqlite:
          state_db: "${{PROJECT_ROOT}}/codex/state/orchestrator.sqlite3"
        directories:
          codex_state: "${{PROJECT_ROOT}}/codex/state"
          locks: "${{PROJECT_ROOT}}/codex/state/locks"
          runs: "${{PROJECT_ROOT}}/codex/state/runs"
          outbox: "${{PROJECT_ROOT}}/codex/state/outbox"
          cleanup: "${{PROJECT_ROOT}}/codex/state/cleanup"
          logs: "${{PROJECT_ROOT}}/codex/logs"
        timeouts:
          root_launch_seconds: 30
          child_launch_seconds: 30
          readiness_poll_seconds: 1
          hcom_send_seconds: 10
          hcom_kill_seconds: 10
          injection_lock_seconds: 20
          stale_lock_seconds: 300
          send_retry_backoff_seconds: 30
        """
    )
    config_dir = project_root / "codex"
    config_dir.mkdir(parents=True, exist_ok=True)
    config_path = config_dir / "config.yaml"
    config_path.write_text(cfg, encoding="utf-8")
    return config_path


def ensure_sqlite3(bin_dir: Path) -> bool:
    """Return True if a sqlite3 CLI is usable.

    If the host lacks the sqlite3 CLI, install a small Python-backed shim into
    ``bin_dir`` that implements exactly the invocation forms bootstrap uses
    (stdin scripts, inline SQL, and ``-separator`` SELECTs). This lets the
    runtime subtests exercise the real bootstrap logic against a real SQLite
    engine on hosts without the CLI. The shim is only used when no real sqlite3
    is present, so behavior on hosts that have the CLI is unchanged.
    """
    from shutil import which
    if which("sqlite3") is not None:
        return True
    bin_dir.mkdir(parents=True, exist_ok=True)
    shim = bin_dir / "sqlite3"
    shim.write_text(
        textwrap.dedent(
            '''\
            #!/usr/bin/env python3
            import sqlite3, sys
            args = sys.argv[1:]
            sep = "|"
            positional = []
            i = 0
            while i < len(args):
                a = args[i]
                if a == "-separator":
                    sep = args[i + 1]; i += 2; continue
                if a.startswith("-"):
                    i += 1; continue
                positional.append(a); i += 1
            db = positional[0]
            sql = positional[1] if len(positional) > 1 else sys.stdin.read()
            con = sqlite3.connect(db)
            con.isolation_level = None
            cur = con.cursor()
            stripped = sql.strip().rstrip(";").strip()
            try:
                if stripped[:6].upper() == "SELECT":
                    cur.execute(sql)
                    for row in cur.fetchall():
                        print(sep.join("" if v is None else str(v) for v in row))
                else:
                    cur.executescript(sql)
            except sqlite3.Error as exc:
                sys.stderr.write(str(exc) + "\\n"); sys.exit(1)
            finally:
                con.close()
            '''
        ),
        encoding="utf-8",
    )
    shim.chmod(0o755)
    return True


def make_fake_hcom(bin_dir: Path, call_log: Path) -> None:
    bin_dir.mkdir(parents=True, exist_ok=True)
    fake = bin_dir / "hcom"
    fake.write_text(
        textwrap.dedent(
            f"""\
            #!/usr/bin/env bash
            printf '%s\\n' "$*" >> "{call_log}"
            case "$1" in
              send) exit 0 ;;
              list) shift; printf '%s\\n' "$*"; exit 0 ;;
              kill) exit 0 ;;
              *)    exit 0 ;;
            esac
            """
        ),
        encoding="utf-8",
    )
    fake.chmod(0o755)


def run_bootstrap(args, project_root: Path, config_path: Path, env_extra=None):
    env = dict(os.environ)
    env["PROJECT_ROOT"] = str(project_root)
    env["MULTI_AGENT_CONFIG"] = str(config_path)
    env["MULTI_AGENT_RUN_ID"] = RUN_ID
    env["MULTI_AGENT_SEND_SYNC"] = "1"
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["bash", str(BOOTSTRAP), *args],
        cwd=str(project_root),
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )


def query_send(state_db: Path, target: str):
    con = sqlite3.connect(str(state_db))
    con.row_factory = sqlite3.Row
    try:
        cur = con.execute(
            "SELECT * FROM sends WHERE tag_target=? ORDER BY created_at DESC LIMIT 1",
            (target,),
        )
        row = cur.fetchone()
        return dict(row) if row else None
    finally:
        con.close()


def main() -> int:
    if not BOOTSTRAP.exists():
        print(f"  FAIL  bootstrap script missing: {BOOTSTRAP}")
        return 1

    # --- Static guards on the shipped script source ---
    print("== Static transactional guards ==")
    src = BOOTSTRAP.read_text(encoding="utf-8")
    check("script uses BEGIN IMMEDIATE for state writes", "BEGIN IMMEDIATE" in src)
    lock_timeout_fn = src.split("record_send_lock_timeout()", 1)[-1].split("\n}", 1)[0] if "record_send_lock_timeout()" in src else ""
    check("record_send_lock_timeout sets status='lock-timeout'", "status='lock-timeout'" in lock_timeout_fn)
    check("record_send_lock_timeout increments attempt_count", "attempt_count = attempt_count + 1" in lock_timeout_fn)
    check("record_send_lock_timeout sets retry_after", "retry_after=" in lock_timeout_fn)
    # An actual invocation would reference the hcom binary or the bounded runner;
    # the descriptive error text ("hcom send not called") is not an invocation.
    check("lock-timeout branch does not invoke hcom",
          ("$HCOM_BIN" not in lock_timeout_fn) and ("run_with_timeout" not in lock_timeout_fn))

    with tempfile.TemporaryDirectory(prefix="hcom-bus-") as tmp:
        project_root = Path(tmp) / "proj"
        project_root.mkdir(parents=True, exist_ok=True)
        skills_dir = Path(tmp) / "agent_skills"
        skills_dir.mkdir(parents=True, exist_ok=True)
        bin_dir = Path(tmp) / "bin"
        call_log = Path(tmp) / "hcom_calls.log"
        make_fake_hcom(bin_dir, call_log)
        sqlite_ok = ensure_sqlite3(bin_dir)
        check("sqlite3 available (CLI or portable shim)", sqlite_ok)
        config_path = write_min_config(project_root, skills_dir)
        state_db = project_root / "codex" / "state" / "orchestrator.sqlite3"
        path_env = {"PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}"}

        # Initialize the ledger up front so we can inspect schema deterministically.
        init = run_bootstrap(["init-db"], project_root, config_path, path_env)
        check("init-db succeeds", init.returncode == 0, init.stderr.strip()[-200:])

        # --- Test 1: delivered path (uncontended lock) ---
        print("\n== Test 1: send transaction reaches 'delivered' ==")
        target1 = "@sdlc-root-codex-testrun-"
        msg1 = "impl-ready: build green on task-101"
        r1 = run_bootstrap(["send", target1, msg1], project_root, config_path, path_env)
        check("send command exits 0", r1.returncode == 0, r1.stderr.strip()[-200:])
        row1 = query_send(state_db, target1)
        check("delivered: sends row exists", row1 is not None)
        if row1:
            check("delivered: status == delivered", row1["status"] == "delivered", f"got {row1['status']}")
            check("delivered: message_body preserved", row1["message_body"] == msg1)
            check("delivered: outbox file exists",
                  bool(row1["outbox_path"]) and Path(row1["outbox_path"]).exists())
        calls = call_log.read_text(encoding="utf-8") if call_log.exists() else ""
        check("delivered: hcom send WAS invoked for target1", "send " + target1 in calls or f"send {target1}" in calls)

        # --- Test 2: lock-timeout path (target lock pre-held) ---
        print("\n== Test 2: contended lock is preserved as 'lock-timeout' (not dropped) ==")
        target2 = "@sdlc-root-claude-testrun-"
        msg2 = "review-request: please review task-101"
        lock_dir = project_root / "codex" / "state" / "locks" / f"send-{safe_filename(target2)}.lock"
        lock_dir.mkdir(parents=True, exist_ok=True)
        (lock_dir / "acquired_epoch").write_text(str(int(time.time())), encoding="utf-8")
        (lock_dir / "pid").write_text("999999", encoding="utf-8")
        calls_before = call_log.read_text(encoding="utf-8") if call_log.exists() else ""

        r2 = run_bootstrap(
            ["send", target2, msg2],
            project_root,
            config_path,
            {**path_env, "MULTI_AGENT_LOCK_TIMEOUT": "1"},
        )
        check("send command still exits 0 (soft, retryable)", r2.returncode == 0, r2.stderr.strip()[-200:])
        row2 = query_send(state_db, target2)
        check("lock-timeout: sends row preserved (not dropped)", row2 is not None)
        if row2:
            check("lock-timeout: status == lock-timeout", row2["status"] == "lock-timeout", f"got {row2['status']}")
            check("lock-timeout: attempt_count incremented to 1", int(row2["attempt_count"]) == 1, f"got {row2['attempt_count']}")
            check("lock-timeout: retry_after is set", bool(row2["retry_after"]))
            check("lock-timeout: message body preserved in row", row2["message_body"] == msg2)
            check("lock-timeout: outbox body intact",
                  bool(row2["outbox_path"]) and Path(row2["outbox_path"]).exists()
                  and Path(row2["outbox_path"]).read_text(encoding="utf-8") == msg2)
            check("lock-timeout: error_code == LOCK_TIMEOUT", row2["error_code"] == "LOCK_TIMEOUT")
        calls_after = call_log.read_text(encoding="utf-8") if call_log.exists() else ""
        new_calls = calls_after[len(calls_before):]
        check("lock-timeout: hcom send NOT called for target2", ("send " + target2) not in new_calls)

        # --- Test 3: ledger schema monitoring ---
        print("\n== Test 3: SQLite state ledger schema ==")
        con = sqlite3.connect(str(state_db))
        try:
            tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            for t in ("launches", "sends", "children", "cleanup", "target_locks"):
                check(f"ledger table present: {t}", t in tables)
            cols = {r[1] for r in con.execute("PRAGMA table_info(launches)")}
            missing = [c for c in AUDITED_COLUMNS if c not in cols]
            check("launches carries all 19 audited columns", not missing, f"missing: {missing}")
            send_cols = {r[1] for r in con.execute("PRAGMA table_info(sends)")}
            for extra in ("message_body", "outbox_path", "retry_after"):
                check(f"sends carries '{extra}'", extra in send_cols)
            lock_cols = {r[1] for r in con.execute("PRAGMA table_info(target_locks)")}
            for lc in ("lock_key", "run_id", "lease_expires_at"):
                check(f"target_locks carries '{lc}'", lc in lock_cols)
        finally:
            con.close()

    return _summary()


def _tool_available(name: str) -> bool:
    from shutil import which
    return which(name) is not None


def _summary() -> int:
    print("\n== Summary ==")
    print(f"passed: {_PASS}   failed: {_FAIL}")
    if _FAIL:
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
