"""Command-line interface for Arbiter."""

from __future__ import annotations

import argparse
from dataclasses import asdict, is_dataclass
from enum import Enum
import json
from pathlib import Path
import sys
from typing import Any, Optional, Sequence
from uuid import uuid4

from arbiter.agents import AgentRegistryError, agent_names, get_agent_spec, load_agent_registry
from arbiter.gates import check_pre_implementation_gates, assert_pre_implementation_gates
from arbiter.hcom import HCOMEnvelope, HCOMType, build_task_envelope, envelope
from arbiter.paths import ArbiterPaths
from arbiter.startup import StartupValidationError, assert_startup_valid, validate_startup
from arbiter.workflow import WorkflowOrchestrator, load_workflow_state, persist_workflow_checkpoint_evidence, read_workflow_phase_artifact_manifest, workflow_phase_artifact_manifest_path, workflow_state_choices, WorkflowState
from providers.base import ProviderError
from providers.registry import get_adapter, provider_names


def _json_default(value: Any) -> Any:
    if is_dataclass(value):
        return asdict(value)
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, tuple):
        return list(value)
    return str(value)


def print_json(value: Any) -> None:
    print(json.dumps(value, indent=2, sort_keys=True, default=_json_default))


def _paths(root: Optional[str]) -> ArbiterPaths:
    return ArbiterPaths.discover(Path(root).resolve() if root else None)


def _workflow_artifact_status_rank(status: Any) -> int:
    value = str(status or "").lower()
    return {"completed": 0, "skipped": 1, "failed": 2}.get(value, 3)


def _sort_workflow_artifact_items(items: Sequence[dict[str, Any]], *, sort_by: str, kind: str) -> list[dict[str, Any]]:
    rows = [dict(item) for item in items]
    if sort_by == "newest":
        if kind == "selection":
            return sorted(rows, key=lambda item: (str(item.get("selected_created_at") or ""), str(item.get("selected_artifact") or "")), reverse=True)
        return sorted(rows, key=lambda item: (str(item.get("created_at") or ""), str(item.get("artifact") or "")), reverse=True)
    if sort_by == "oldest":
        if kind == "selection":
            return sorted(rows, key=lambda item: (str(item.get("selected_created_at") or ""), str(item.get("selected_artifact") or "")))
        return sorted(rows, key=lambda item: (str(item.get("created_at") or ""), str(item.get("artifact") or "")))
    if sort_by == "status":
        if kind == "selection":
            return sorted(rows, key=lambda item: (_workflow_artifact_status_rank(item.get("selected_status")), str(item.get("selected_created_at") or ""), str(item.get("phase") or ""), str(item.get("selected_artifact") or "")))
        return sorted(rows, key=lambda item: (_workflow_artifact_status_rank(item.get("status")), str(item.get("created_at") or ""), str(item.get("phase") or ""), str(item.get("artifact") or "")))
    return sorted(rows, key=lambda item: (str(item.get("phase") or ""), str(item.get("artifact") or item.get("selected_artifact") or "")))


def _apply_workflow_artifact_limit(manifest: dict[str, Any], *, limit: Optional[int]) -> tuple[dict[str, Any], dict[str, Any]]:
    limited_manifest = dict(manifest)
    metadata: dict[str, Any] = {"requested": limit, "applied": limit is not None}
    for key in ("active_artifacts", "archived_artifacts", "selection"):
        rows = list(limited_manifest.get(key) or [])
        visible_rows = rows[:limit] if limit is not None else rows
        limited_manifest[key] = visible_rows
        metadata[key] = {
            "visible": len(visible_rows),
            "total": len(rows),
            "truncated": len(visible_rows) < len(rows),
        }
    return limited_manifest, metadata


def _workflow_artifact_count_text(limit_meta: dict[str, Any], key: str) -> str:
    info = dict(limit_meta.get(key) or {})
    visible = int(info.get("visible") or 0)
    total = int(info.get("total") or 0)
    return f"{visible}/{total}" if info.get("truncated") else str(visible)


def _print_workflow_artifacts_summary(payload: dict[str, Any]) -> None:
    manifest = dict(payload.get("manifest") or {})
    active = list(manifest.get("active_artifacts") or [])
    archived = list(manifest.get("archived_artifacts") or [])
    selection = list(manifest.get("selection") or [])
    limit_meta = dict(payload.get("limit") or {})
    lines = [
        f"goal: {payload.get('goal_id')}",
        f"manifest: {payload.get('manifest_path')}",
        f"view: {payload.get('view')}",
        f"phase: {payload.get('phase') or 'ALL'}",
        f"sort: {payload.get('sort_by') or 'phase'}",
        f"counts: active={_workflow_artifact_count_text(limit_meta, 'active_artifacts')} archived={_workflow_artifact_count_text(limit_meta, 'archived_artifacts')} selection={_workflow_artifact_count_text(limit_meta, 'selection')}",
    ]
    if limit_meta.get("applied"):
        lines.insert(5, f"limit: {limit_meta.get('requested')}")
    if active:
        lines.append("")
        lines.append("active artifacts:")
        for item in active:
            summary = str(item.get("summary") or "").strip()
            suffix = f" :: {summary}" if summary else ""
            lines.append(f"- {item.get('phase', 'UNKNOWN')} [{item.get('status', 'unknown')}] {item.get('artifact', '-')}{suffix}")
    if archived:
        lines.append("")
        lines.append("archived artifacts:")
        for item in archived:
            summary = str(item.get("summary") or "").strip()
            suffix = f" :: {summary}" if summary else ""
            lines.append(f"- {item.get('phase', 'UNKNOWN')} [{item.get('status', 'unknown')}] {item.get('artifact', '-')}{suffix}")
    if selection:
        lines.append("")
        lines.append("selection decisions:")
        for item in selection:
            reasons = ",".join(str(part) for part in list(item.get("selected_reasons") or [])) or "-"
            lines.append(
                f"- {item.get('phase', 'UNKNOWN')} -> {item.get('selected_artifact', '-')} "
                f"status={item.get('selected_status', 'unknown')} candidates={item.get('candidate_count', 0)} reasons={reasons}"
            )
    print("\n".join(lines))


def cmd_bootstrap(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    paths.ensure_standard_layout()
    print(f"workspace layout ensured: {paths.root}")
    return 0


def cmd_check_gates(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    results = check_pre_implementation_gates(paths)
    if args.json:
        print_json([asdict(result) for result in results])
    else:
        for result in results:
            print(("PASS" if result.passed else "FAIL") + f" {result.name}")
            for missing in result.missing:
                print(f"  missing: {missing}")
    return 0 if all(result.passed for result in results) else 1


def cmd_startup_validate(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    checks = validate_startup(paths)
    if args.json:
        print_json(checks)
    else:
        for check in checks:
            print(("PASS" if check.passed else "FAIL") + f" {check.name}: {check.detail}")
    return 0 if all(check.passed for check in checks) else 1


def cmd_agents(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    rows = [spec.to_dict() for spec in load_agent_registry(paths)]
    if args.json:
        print_json(rows)
    else:
        for row in rows:
            print(f"{row['name']}: provider={row['provider']} model={row['model']} markdown={row['markdown']}")
    return 0


def cmd_providers(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    rows = []
    for name in provider_names():
        adapter = get_adapter(name, paths)
        rows.append({"provider": name, "identity": adapter.identify()})
    if args.json:
        print_json(rows)
    else:
        for row in rows:
            ident = row["identity"]
            found = "found" if ident.found else "missing"
            print(f"{row['provider']}: {found} executable={ident.executable or '-'} version={ident.version or '-'}")
    return 0


def cmd_doctor(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    names = [args.provider] if args.provider else list(provider_names())
    reports = []
    exit_code = 0
    for name in names:
        readiness = get_adapter(name, paths).check_readiness()
        reports.append(readiness)
        if not readiness.ready:
            exit_code = 1
    if args.json:
        print_json(reports)
    else:
        for report in reports:
            print(f"provider: {report.provider}")
            print(f"  ready: {report.ready}")
            print(f"  executable: {report.identity.executable or '-'}")
            print(f"  version: {report.identity.version or '-'}")
    return exit_code


def cmd_materialize(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_pre_implementation_gates(paths)
    assert_startup_valid(paths)
    adapter = get_adapter(args.provider, paths)
    context = adapter.prepare_context(run_id=args.run_id, dry_run=not args.write)
    manifest = adapter.materialize_config(context)
    if args.json:
        print_json(manifest)
    else:
        mode = "dry-run" if manifest.dry_run else "write"
        print(f"materialization {mode}: provider={manifest.provider} run_id={manifest.run_id}")
    return 0


def _context_for_command(args: argparse.Namespace):
    paths = _paths(args.root)
    assert_pre_implementation_gates(paths)
    assert_startup_valid(paths)
    adapter = get_adapter(args.provider, paths)
    context = adapter.prepare_context(run_id=args.run_id, dry_run=args.dry_run)
    if not args.no_materialize:
        adapter.materialize_config(context)
    return paths, adapter, context


def cmd_plan(args: argparse.Namespace) -> int:
    args.dry_run = True
    _, adapter, context = _context_for_command(args)
    plan = adapter.build_command(context, prompt=args.prompt, non_interactive=not args.interactive, model=args.model)
    if args.json:
        print_json(plan.redacted())
    else:
        print_json(plan.redacted())
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    if args.dry_run:
        return cmd_plan(args)
    paths, adapter, context = _context_for_command(args)
    run_id = context.workspace.run_id
    if not args.agent:
        raise ValueError("run requires --agent so Arbiter can enforce an exact registry mapping")
    spec = get_agent_spec(paths, args.agent)
    if spec.provider != args.provider:
        raise ValueError(f"agent {spec.name!r} is mapped to provider {spec.provider!r}, not {args.provider!r}")
    if args.model and args.model != spec.model:
        raise ValueError(f"agent {spec.name!r} is pinned to model {spec.model!r}; override via --model is blocked")
    task = build_task_envelope(paths, agent=spec.name, prompt=args.prompt, goal=args.goal or "manual-run", run_id=run_id, metadata={"source": "run"})
    message = envelope(message_type=HCOMType.TASK_SUBMIT, source="arbiter", target=args.provider, payload={"task": task.to_dict()}, run_id=run_id)
    response = adapter.send_hcom(context, message, detached=False, timeout_seconds=args.timeout)
    if args.json:
        print_json(response.to_dict())
    else:
        payload = response.payload
        if payload.get("stdout"):
            print(payload["stdout"], end="")
        if payload.get("stderr"):
            print(payload["stderr"], end="", file=sys.stderr)
    return 0 if response.type != HCOMType.ERROR.value else 1


def cmd_hcom_send(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    spec = get_agent_spec(paths, args.agent)
    adapter = get_adapter(spec.provider, paths)
    context = adapter.prepare_context(run_id=args.run_id, dry_run=False)
    adapter.materialize_config(context)
    task = build_task_envelope(paths, agent=spec.name, prompt=args.prompt, goal=args.goal or spec.name, run_id=context.workspace.run_id, metadata={"source": "hcom.send"})
    message = envelope(message_type=HCOMType.TASK_SUBMIT, source="arbiter", target=spec.provider, payload={"task": task.to_dict()}, run_id=context.workspace.run_id, session_id=args.session_id or f"{spec.provider}-{uuid4().hex[:10]}")
    response = adapter.send_hcom(context, message, detached=args.detach, timeout_seconds=args.timeout)
    if args.json:
        print_json(response.to_dict())
    else:
        print_json(response.to_dict())
    return 0 if response.type != HCOMType.ERROR.value else 1


def cmd_hcom_kill(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    if args.provider:
        providers = [args.provider]
    else:
        providers = list(provider_names())
    last_error: Optional[ProviderError] = None
    for name in providers:
        adapter = get_adapter(name, paths)
        try:
            response = adapter.kill_hcom(args.session_id)
            if args.json:
                print_json(response.to_dict())
            else:
                print_json(response.to_dict())
            return 0
        except ProviderError as exc:
            last_error = exc
    if last_error is None:
        raise ProviderError("session_not_found", f"unknown active session {args.session_id!r}")
    raise last_error


def cmd_workflow_state(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    snapshot = load_workflow_state(paths)
    payload = snapshot.to_dict()
    if args.include_artifacts:
        goal_id = args.goal_id or (snapshot.active_goal.goal_id if snapshot.active_goal is not None else None)
        payload["artifact_manifest_goal_id"] = goal_id
        payload["artifact_manifest"] = read_workflow_phase_artifact_manifest(paths, goal_id) if goal_id else None
    if args.json:
        print_json(payload)
    else:
        print_json(payload)
    return 0


def cmd_workflow_artifacts(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    snapshot = load_workflow_state(paths)
    goal_id = args.goal_id or (snapshot.active_goal.goal_id if snapshot.active_goal is not None else None)
    if not goal_id:
        raise ValueError("workflow-artifacts requires a goal_id or an active workflow goal")
    manifest = read_workflow_phase_artifact_manifest(paths, goal_id)
    if manifest is None:
        raise ValueError(f"no phase-artifact manifest found for goal {goal_id!r}")
    limit = args.limit
    if limit is not None and limit < 0:
        raise ValueError("workflow-artifacts --limit must be >= 0")
    phase = str(args.phase).upper() if getattr(args, 'phase', None) else None
    filtered_manifest = dict(manifest)
    if phase:
        filtered_manifest["active_artifacts"] = [item for item in list(manifest.get("active_artifacts") or []) if str(item.get("phase") or "").upper() == phase]
        filtered_manifest["archived_artifacts"] = [item for item in list(manifest.get("archived_artifacts") or []) if str(item.get("phase") or "").upper() == phase]
        filtered_manifest["selection"] = [item for item in list(manifest.get("selection") or []) if str(item.get("phase") or "").upper() == phase]
    if args.active_only:
        filtered_manifest["archived_artifacts"] = []
        filtered_manifest["selection"] = []
    elif args.archived_only:
        filtered_manifest["active_artifacts"] = []
        filtered_manifest["selection"] = []
    elif args.selection_only:
        filtered_manifest["active_artifacts"] = []
        filtered_manifest["archived_artifacts"] = []
    sort_by = str(args.sort_by or "phase")
    filtered_manifest["active_artifacts"] = _sort_workflow_artifact_items(list(filtered_manifest.get("active_artifacts") or []), sort_by=sort_by, kind="active")
    filtered_manifest["archived_artifacts"] = _sort_workflow_artifact_items(list(filtered_manifest.get("archived_artifacts") or []), sort_by=sort_by, kind="archived")
    filtered_manifest["selection"] = _sort_workflow_artifact_items(list(filtered_manifest.get("selection") or []), sort_by=sort_by, kind="selection")
    filtered_manifest, limit_meta = _apply_workflow_artifact_limit(filtered_manifest, limit=limit)
    payload = {
        "goal_id": goal_id,
        "manifest_path": str(workflow_phase_artifact_manifest_path(paths, goal_id).relative_to(paths.root)),
        "view": "selection" if args.selection_only else "archived" if args.archived_only else "active" if args.active_only else "full",
        "phase": phase,
        "sort_by": sort_by,
        "limit": limit_meta,
        "manifest": filtered_manifest,
    }
    if args.json:
        print_json(payload)
    elif args.summary:
        _print_workflow_artifacts_summary(payload)
    else:
        print_json(payload)
    return 0


def cmd_workflow_run(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    orchestrator = WorkflowOrchestrator(paths)
    if args.state:
        target = WorkflowState(args.state)
        title = args.title or ("Advance to %s" % target.value)
        orchestrator.queue.enqueue(target, title, max_attempts=args.max_attempts)
    result = orchestrator.run_active()
    if args.json:
        print_json(result.to_dict())
    else:
        print_json(result.to_dict())
    return 0 if result.passed else 1


def cmd_workflow_reset(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    snapshot = WorkflowOrchestrator(paths).reset()
    if args.json:
        print_json(snapshot.to_dict())
    else:
        print_json(snapshot.to_dict())
    return 0


def cmd_workflow_checkpoint_complete(args: argparse.Namespace) -> int:
    paths = _paths(args.root)
    assert_startup_valid(paths)
    snapshot = load_workflow_state(paths)
    if snapshot.active_goal is None:
        raise ValueError("no active workflow goal to checkpoint")
    if args.goal_id and args.goal_id != snapshot.active_goal.goal_id:
        raise ValueError("checkpoint goal_id does not match the active workflow goal")
    action = next((item for item in snapshot.required_actions if item.status != "completed"), None)
    if action is None or action.kind != "manual" or action.name != args.action:
        raise ValueError(f"{args.action!r} is not the next pending manual workflow checkpoint")
    artifact = persist_workflow_checkpoint_evidence(
        paths,
        goal_id=snapshot.active_goal.goal_id,
        action=args.action,
        evidence=args.evidence,
        source=args.source,
    )
    if args.json:
        print_json(artifact.to_dict())
    else:
        print_json(artifact.to_dict())
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="arbiter", description="Arbiter provider coordinator")
    parser.add_argument("--root", help="repository root override")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("bootstrap", help="ensure required workspace directories exist")
    p.set_defaults(func=cmd_bootstrap)

    p = sub.add_parser("check-gates", help="check research/requirements/design gates")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_check_gates)

    p = sub.add_parser("startup-validate", help="validate mandatory startup architecture")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_startup_validate)

    p = sub.add_parser("agents", help="list mandatory agent registry mappings")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_agents)

    p = sub.add_parser("providers", help="list providers and discovery status")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_providers)

    p = sub.add_parser("doctor", help="run provider readiness checks")
    p.add_argument("provider", nargs="?", choices=provider_names())
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_doctor)

    p = sub.add_parser("materialize", help="materialize provider config")
    p.add_argument("provider", choices=provider_names())
    p.add_argument("--run-id")
    p.add_argument("--write", action="store_true")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_materialize)

    p = sub.add_parser("workflow-state", help="inspect persisted workflow state")
    p.add_argument("--goal-id", help="include the phase-artifact manifest for a specific goal")
    p.add_argument("--include-artifacts", action="store_true", help="include the selected goal's phase-artifact manifest")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_workflow_state)

    p = sub.add_parser("workflow-run", help="run the active workflow goal, or enqueue and run a new goal")
    p.add_argument("state", nargs="?", choices=workflow_state_choices())
    p.add_argument("--title")
    p.add_argument("--max-attempts", type=int, default=3)
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_workflow_run)

    p = sub.add_parser("workflow-reset", help="clear a FAILED workflow state so execution can resume")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_workflow_reset)

    p = sub.add_parser("workflow-artifacts", help="inspect the phase-artifact manifest for a workflow goal")
    p.add_argument("goal_id", nargs="?", help="goal id to inspect; defaults to the active goal")
    group = p.add_mutually_exclusive_group()
    group.add_argument("--active-only", action="store_true", help="show active artifacts only")
    group.add_argument("--archived-only", action="store_true", help="show archived artifacts only")
    group.add_argument("--selection-only", action="store_true", help="show phase selection decisions only")
    p.add_argument("--phase", choices=workflow_state_choices(), help="filter artifact view to a single workflow phase")
    p.add_argument("--sort-by", choices=("phase", "status", "newest", "oldest"), default="phase", help="sort artifact rows before rendering")
    p.add_argument("--limit", type=int, help="show only the first N rows per artifact section after filtering and sorting")
    p.add_argument("--summary", action="store_true", help="print a compact human-readable summary instead of JSON")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_workflow_artifacts)

    workflow_checkpoint = sub.add_parser("workflow-checkpoint", help="persist explicit evidence for a pending manual workflow checkpoint")
    workflow_checkpoint_sub = workflow_checkpoint.add_subparsers(dest="workflow_checkpoint_command", required=True)
    p = workflow_checkpoint_sub.add_parser("complete", help="persist evidence for the next pending manual workflow checkpoint")
    p.add_argument("action")
    p.add_argument("--evidence", required=True)
    p.add_argument("--source", default="CLI")
    p.add_argument("--goal-id")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_workflow_checkpoint_complete)

    hcom = sub.add_parser("hcom", help="send or kill provider sessions through HCOM")
    hcom_sub = hcom.add_subparsers(dest="hcom_command", required=True)
    p = hcom_sub.add_parser("send", help="send a structured task envelope through the registered agent mapping")
    p.add_argument("agent", choices=None)
    p.add_argument("--prompt", required=True)
    p.add_argument("--goal")
    p.add_argument("--run-id")
    p.add_argument("--session-id")
    p.add_argument("--detach", action="store_true")
    p.add_argument("--timeout", type=float, default=None)
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_hcom_send)
    p = hcom_sub.add_parser("kill", help="kill a detached HCOM provider session")
    p.add_argument("session_id")
    p.add_argument("--provider", choices=provider_names())
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_hcom_kill)

    for name, help_text, handler in (("plan", "build a provider command plan without executing", cmd_plan), ("run", "run a provider non-interactive task", cmd_run)):
        p = sub.add_parser(name, help=help_text)
        p.add_argument("provider", choices=provider_names())
        p.add_argument("--agent")
        p.add_argument("--prompt", required=True)
        p.add_argument("--goal")
        p.add_argument("--model")
        p.add_argument("--run-id")
        p.add_argument("--interactive", action="store_true")
        p.add_argument("--dry-run", action="store_true")
        p.add_argument("--no-materialize", action="store_true")
        p.add_argument("--timeout", type=float, default=None)
        p.add_argument("--json", action="store_true")
        p.set_defaults(func=handler)

    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    if getattr(args, "command", None) == "hcom" and getattr(args, "hcom_command", None) == "send":
        try:
            choices = agent_names(_paths(getattr(args, "root", None)))
            action = next(item for item in parser._subparsers._group_actions if item.dest == "command")
            hcom_parser = action.choices["hcom"]
            send_parser = next(item for item in hcom_parser._subparsers._group_actions if item.dest == "hcom_command").choices["send"]
            send_parser._actions[1].choices = choices
        except Exception:
            pass
    try:
        return int(args.func(args))
    except (ProviderError, StartupValidationError, AgentRegistryError) as exc:
        if getattr(args, "json", False):
            code = exc.code if isinstance(exc, ProviderError) else exc.__class__.__name__
            print_json({"error": code, "message": str(exc)})
        else:
            print(f"error: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        if getattr(args, "json", False):
            print_json({"error": exc.__class__.__name__, "message": str(exc)})
        else:
            print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
