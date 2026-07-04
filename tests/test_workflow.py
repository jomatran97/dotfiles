from __future__ import annotations

from io import StringIO
from pathlib import Path
import contextlib
import json
import os
import tempfile
import unittest
from unittest import mock

from arbiter.cli import main
from arbiter.paths import ArbiterPaths
from arbiter.workflow import (
    WorkflowOrchestrator,
    WorkflowPersistence,
    WorkflowQueue,
    WorkflowState,
    check_deployment_gate,
    load_workflow_state,
    read_workflow_checkpoint_evidence,
    state_rank,
    validate_transition,
    workflow_phase_artifact_manifest_path,
    workflow_phase_artifact_path,
    workflow_verify_result_path,
)
from tests.helpers import make_repo


def _write_executable(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body, encoding='utf-8')
    path.chmod(path.stat().st_mode | 0o111)


def _persist_state(paths: ArbiterPaths, current_state: WorkflowState) -> None:
    persistence = WorkflowPersistence(paths)
    snapshot = persistence.load()
    snapshot.current_state = current_state
    snapshot.updated_at = '2026-01-01T00:00:00+00:00'
    for state in WorkflowState:
        if state == WorkflowState.FAILED:
            continue
        lifecycle = snapshot.phases.get(state.value)
        if lifecycle is None:
            continue
        lifecycle.status = 'Completed' if state_rank(state) <= state_rank(current_state) else 'Pending'
    persistence.save(snapshot)


def _complete_checkpoint(root: Path, action: str, evidence: str) -> dict[str, str]:
    stdout = StringIO()
    with contextlib.redirect_stdout(stdout):
        code = main(['--root', str(root), 'workflow-checkpoint', 'complete', action, '--evidence', evidence, '--json'])
    payload = json.loads(stdout.getvalue())
    if code != 0:
        raise AssertionError(payload)
    return payload


class WorkflowTests(unittest.TestCase):
    def test_invalid_transition_is_blocked(self) -> None:
        with self.assertRaises(ValueError):
            validate_transition(WorkflowState.RESEARCH, WorkflowState.DEPLOY)

    def test_queue_keeps_only_one_active_goal(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            queue = WorkflowQueue(ArbiterPaths(root))
            first = queue.enqueue(WorkflowState.VERIFY, 'run verify')
            second = queue.enqueue(WorkflowState.DEPLOY, 'deploy')
            snapshot = queue.snapshot()
            self.assertEqual(snapshot.active.goal_id, first.goal_id)
            self.assertEqual([goal.goal_id for goal in snapshot.pending], [second.goal_id])

    def test_cli_workflow_artifacts_reads_explicit_goal_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-cli'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [{'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T11:00:00+00:00', 'summary': 'Artifacts CLI summary', 'evidence': ['research/antigravity.md'], 'deliverables': ['verified findings'], 'next_handoff': 'Hand off to requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True}],
                'archived_artifacts': [],
                'selection': [{'phase': 'RESEARCH', 'candidate_count': 1, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'], 'archived_artifacts': []}],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--json'])
            self.assertEqual(code, 0)
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload['goal_id'], goal_id)
            self.assertEqual(payload['manifest']['goal_id'], goal_id)
            self.assertEqual(payload['manifest']['active_artifacts'][0]['summary'], 'Artifacts CLI summary')
            self.assertEqual(payload['manifest_path'], f'state/arbiter/workflow/phase-artifacts/{goal_id}/index.json')

    def test_cli_workflow_artifacts_can_filter_active_entries_by_phase(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-filter'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T11:00:00+00:00', 'summary': 'Research active summary', 'evidence': ['research/antigravity.md'], 'deliverables': ['verified findings'], 'next_handoff': 'Hand off to requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                    {'phase': 'PLAN', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T10:00:00+00:00', 'summary': 'Plan active summary', 'evidence': ['TODO.md'], 'deliverables': ['ordered plan'], 'next_handoff': 'Use for requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'archived_artifacts': [
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-old.json', 'archived': True, 'status': 'failed', 'created_at': '2026-07-01T09:00:00+00:00', 'summary': 'Old research summary', 'evidence': ['old.md'], 'deliverables': ['old'], 'next_handoff': 'Old handoff.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'selection': [
                    {'phase': 'RESEARCH', 'candidate_count': 2, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'], 'archived_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-old.json']},
                    {'phase': 'PLAN', 'candidate_count': 1, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json'], 'archived_artifacts': []},
                ],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--active-only', '--phase', 'RESEARCH', '--json'])
            self.assertEqual(code, 0)
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload['view'], 'active')
            self.assertEqual(payload['phase'], 'RESEARCH')
            self.assertEqual(len(payload['manifest']['active_artifacts']), 1)
            self.assertEqual(payload['manifest']['active_artifacts'][0]['phase'], 'RESEARCH')
            self.assertEqual(payload['manifest']['archived_artifacts'], [])
            self.assertEqual(payload['manifest']['selection'], [])

    def test_cli_workflow_artifacts_selection_sort_by_newest_uses_selected_created_at(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-selection-sort'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [],
                'archived_artifacts': [],
                'selection': [
                    {'phase': 'PLAN', 'candidate_count': 1, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'selected_status': 'completed', 'selected_created_at': '2026-07-01T10:00:00+00:00', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json'], 'archived_artifacts': []},
                    {'phase': 'RESEARCH', 'candidate_count': 1, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'selected_status': 'completed', 'selected_created_at': '2026-07-01T11:00:00+00:00', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'], 'archived_artifacts': []},
                ],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--selection-only', '--summary', '--sort-by', 'newest'])
            self.assertEqual(code, 0)
            rendered = stdout.getvalue()
            self.assertLess(rendered.index('RESEARCH ->'), rendered.index('PLAN ->'))

    def test_cli_workflow_artifacts_summary_mode_can_sort_by_status(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-status-sort'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [
                    {'phase': 'VERIFY', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/VERIFY.json', 'archived': False, 'status': 'failed', 'created_at': '2026-07-01T11:00:00+00:00', 'summary': 'Failed verify summary', 'evidence': ['tests/harness.sh'], 'deliverables': ['fix verify'], 'next_handoff': 'Repair verify.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T10:00:00+00:00', 'summary': 'Completed research summary', 'evidence': ['research/antigravity.md'], 'deliverables': ['verified findings'], 'next_handoff': 'Hand off to requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                    {'phase': 'PLAN', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'archived': False, 'status': 'skipped', 'created_at': '2026-07-01T09:00:00+00:00', 'summary': 'Skipped plan summary', 'evidence': ['TODO.md'], 'deliverables': ['ordered plan'], 'next_handoff': 'Review plan.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'archived_artifacts': [],
                'selection': [],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--summary', '--sort-by', 'status'])
            self.assertEqual(code, 0)
            rendered = stdout.getvalue()
            self.assertLess(rendered.index('Completed research summary'), rendered.index('Skipped plan summary'))
            self.assertLess(rendered.index('Skipped plan summary'), rendered.index('Failed verify summary'))

    def test_cli_workflow_artifacts_rejects_negative_limit(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-negative-limit'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [],
                'archived_artifacts': [],
                'selection': [],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--limit', '-1', '--json'])
            self.assertEqual(code, 1)
            payload = json.loads(stdout.getvalue())
            self.assertIn('must be >= 0', payload['message'])

    def test_cli_workflow_artifacts_summary_mode_can_sort_by_newest(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-sort'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [
                    {'phase': 'PLAN', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T10:00:00+00:00', 'summary': 'Older plan summary', 'evidence': ['TODO.md'], 'deliverables': ['ordered plan'], 'next_handoff': 'Use for requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T11:00:00+00:00', 'summary': 'Newer research summary', 'evidence': ['research/antigravity.md'], 'deliverables': ['verified findings'], 'next_handoff': 'Hand off to requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'archived_artifacts': [],
                'selection': [],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--summary', '--sort-by', 'newest'])
            self.assertEqual(code, 0)
            rendered = stdout.getvalue()
            self.assertIn('sort: newest', rendered)
            self.assertLess(rendered.index('Newer research summary'), rendered.index('Older plan summary'))

    def test_cli_workflow_artifacts_summary_mode_is_human_readable(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-summary'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T11:00:00+00:00', 'summary': 'Summary mode research', 'evidence': ['research/antigravity.md'], 'deliverables': ['verified findings'], 'next_handoff': 'Hand off to requirements.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'archived_artifacts': [
                    {'phase': 'PLAN', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/PLAN-old.json', 'archived': True, 'status': 'failed', 'created_at': '2026-07-01T09:00:00+00:00', 'summary': 'Summary mode archived', 'evidence': ['TODO.md'], 'deliverables': ['old plan'], 'next_handoff': 'Discard old handoff.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'selection': [
                    {'phase': 'RESEARCH', 'candidate_count': 2, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'], 'archived_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-old.json']},
                ],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--summary'])
            self.assertEqual(code, 0)
            rendered = stdout.getvalue()
            self.assertIn(f'goal: {goal_id}', rendered)
            self.assertIn('view: full', rendered)
            self.assertIn('phase: ALL', rendered)
            self.assertIn('active artifacts:', rendered)
            self.assertIn('archived artifacts:', rendered)
            self.assertIn('selection decisions:', rendered)
            self.assertIn('Summary mode research', rendered)
            self.assertIn('Summary mode archived', rendered)
            self.assertNotIn('{', rendered)

    def test_cli_workflow_artifacts_can_show_selection_only_for_phase(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-selection'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [],
                'archived_artifacts': [],
                'selection': [
                    {'phase': 'RESEARCH', 'candidate_count': 2, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'], 'archived_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-old.json']},
                    {'phase': 'PLAN', 'candidate_count': 1, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json'], 'archived_artifacts': []},
                ],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--selection-only', '--phase', 'PLAN', '--json'])
            self.assertEqual(code, 0)
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload['view'], 'selection')
            self.assertEqual(payload['phase'], 'PLAN')
            self.assertEqual(payload['manifest']['active_artifacts'], [])
            self.assertEqual(payload['manifest']['archived_artifacts'], [])
            self.assertEqual(len(payload['manifest']['selection']), 1)
            self.assertEqual(payload['manifest']['selection'][0]['phase'], 'PLAN')

    def test_cli_workflow_artifacts_applies_limit_after_filter_and_sort(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-limit-json'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH-newest.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T11:00:00+00:00', 'summary': 'Newest research summary', 'evidence': ['research/new.md'], 'deliverables': ['new'], 'next_handoff': 'Newest handoff.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                    {'phase': 'PLAN', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', 'archived': False, 'status': 'completed', 'created_at': '2026-07-01T10:30:00+00:00', 'summary': 'Plan summary', 'evidence': ['TODO.md'], 'deliverables': ['plan'], 'next_handoff': 'Plan handoff.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                    {'phase': 'RESEARCH', 'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH-older.json', 'archived': False, 'status': 'skipped', 'created_at': '2026-07-01T10:00:00+00:00', 'summary': 'Older research summary', 'evidence': ['research/old.md'], 'deliverables': ['old'], 'next_handoff': 'Older handoff.', 'evidence_count': 1, 'deliverable_count': 1, 'has_summary': True},
                ],
                'archived_artifacts': [],
                'selection': [],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--active-only', '--phase', 'RESEARCH', '--sort-by', 'newest', '--limit', '1', '--json'])
            self.assertEqual(code, 0)
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload['limit']['requested'], 1)
            self.assertTrue(payload['limit']['active_artifacts']['truncated'])
            self.assertEqual(payload['limit']['active_artifacts']['total'], 2)
            self.assertEqual(payload['limit']['active_artifacts']['visible'], 1)
            self.assertEqual(len(payload['manifest']['active_artifacts']), 1)
            self.assertEqual(payload['manifest']['active_artifacts'][0]['artifact'], f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH-newest.json')
            self.assertEqual(payload['manifest']['archived_artifacts'], [])
            self.assertEqual(payload['manifest']['selection'], [])

    def test_cli_workflow_artifacts_summary_mode_reflects_limit_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            goal_id = 'goal-artifacts-limit-summary'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [],
                'archived_artifacts': [],
                'selection': [
                    {'phase': 'VERIFY', 'candidate_count': 2, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/VERIFY.json', 'selected_status': 'completed', 'selected_reasons': ['verified'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/VERIFY.json'], 'archived_artifacts': []},
                    {'phase': 'RESEARCH', 'candidate_count': 3, 'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json', 'selected_status': 'completed', 'selected_reasons': ['best-ranked'], 'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'], 'archived_artifacts': []},
                ],
            }, indent=2) + '\n', encoding='utf-8')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', goal_id, '--selection-only', '--summary', '--sort-by', 'oldest', '--limit', '1'])
            self.assertEqual(code, 0)
            rendered = stdout.getvalue()
            self.assertIn('limit: 1', rendered)
            self.assertIn('counts: active=0 archived=0 selection=1/2', rendered)
            self.assertIn('RESEARCH ->', rendered)
            self.assertNotIn('VERIFY ->', rendered)

    def test_cli_workflow_artifacts_requires_goal_or_active_goal(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-artifacts', '--json'])
            self.assertEqual(code, 1)
            payload = json.loads(stdout.getvalue())
            self.assertIn('requires a goal_id or an active workflow goal', payload['message'])

    def test_cli_workflow_state_can_include_goal_artifact_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-cli-manifest'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': 'REQUIREMENTS',
                'retention': {'archived_this_run': [], 'ranking_policy': {'status_order': ['completed', 'skipped', 'failed', 'unknown'], 'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path']}},
                'active_artifacts': [
                    {
                        'phase': 'RESEARCH',
                        'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json',
                        'archived': False,
                        'status': 'completed',
                        'created_at': '2026-07-01T11:00:00+00:00',
                        'summary': 'CLI manifest summary',
                        'evidence': ['research/antigravity.md'],
                        'deliverables': ['verified findings'],
                        'next_handoff': 'Hand off to requirements.',
                        'evidence_count': 1,
                        'deliverable_count': 1,
                        'has_summary': True,
                    },
                ],
                'archived_artifacts': [],
                'selection': [
                    {
                        'phase': 'RESEARCH',
                        'candidate_count': 1,
                        'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json',
                        'selected_status': 'completed',
                        'selected_reasons': ['best-ranked'],
                        'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'],
                        'archived_artifacts': [],
                    },
                ],
            }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-state', '--include-artifacts', '--json'])
            self.assertEqual(code, 0)
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload['artifact_manifest_goal_id'], goal_id)
            self.assertEqual(payload['artifact_manifest']['goal_id'], goal_id)
            self.assertEqual(payload['artifact_manifest']['active_artifacts'][0]['summary'], 'CLI manifest summary')

    def test_phase_dispatch_artifact_is_written_when_provider_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.PLAN)
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.RESEARCH, 'research workspace')
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            artifact_path = workflow_phase_artifact_path(paths, goal.goal_id, WorkflowState.RESEARCH.value)
            payload = json.loads(artifact_path.read_text(encoding='utf-8'))
            self.assertEqual(payload['agent'], 'research')
            self.assertEqual(payload['status'], 'skipped')
            self.assertIn('cli_not_found', ' '.join(payload['readiness']['errors']))
            self.assertEqual(payload['structured_output']['status'], 'skipped')
            self.assertIn('Provider dispatch skipped', payload['structured_output']['next_handoff'])

    def test_phase_dispatch_prompt_includes_phase_specific_sections(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.PLAN)
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.RESEARCH, 'research workspace')
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            payload = json.loads(workflow_phase_artifact_path(paths, goal.goal_id, WorkflowState.RESEARCH.value).read_text(encoding='utf-8'))
            prompt = payload['prompt']
            self.assertIn('Focus paths:', prompt)
            self.assertIn('research/antigravity.md', prompt)
            self.assertIn('Command hints:', prompt)
            self.assertIn('Expected output schema (use these exact headings):', prompt)
            self.assertIn('Deliverables:\n- verified findings\n- unknowns\n- next handoff', prompt)

    def test_phase_dispatch_prompt_filters_to_relevant_prior_handoffs(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-filter'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            fixtures = {
                'PLAN': {'summary': 'Plan summary', 'deliverables': ['ordered plan']},
                'RESEARCH': {'summary': 'Research summary', 'deliverables': ['verified findings']},
                'AUDIT': {'summary': 'Audit summary', 'deliverables': ['findings with severity']},
                'DEPLOY': {'summary': 'Deploy summary', 'deliverables': ['deployment readiness summary']},
            }
            for phase_name, structured in fixtures.items():
                (artifact_root / f'{phase_name}.json').write_text(json.dumps({
                    'phase': phase_name,
                    'status': 'completed',
                    'structured_output': {
                        'status': 'completed',
                        'summary': structured['summary'],
                        'evidence': [f'{phase_name.lower()}.md'],
                        'deliverables': structured['deliverables'],
                        'next_handoff': f'{phase_name} handoff',
                    },
                }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            payload = json.loads(workflow_phase_artifact_path(paths, goal_id, WorkflowState.REQUIREMENTS.value).read_text(encoding='utf-8'))
            prompt = payload['prompt']
            self.assertIn('summary: Research summary', prompt)
            self.assertIn('summary: Plan summary', prompt)
            self.assertNotIn('summary: Audit summary', prompt)
            self.assertNotIn('summary: Deploy summary', prompt)

    def test_phase_dispatch_prompt_prefers_strongest_newest_successful_handoff(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-ranked'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            ranked_fixtures = [
                ('RESEARCH-failed.json', 'RESEARCH', 'failed', 'Newest failed research', '2026-07-01T10:00:00+00:00'),
                ('RESEARCH-old.json', 'RESEARCH', 'completed', 'Older completed research', '2026-07-01T09:00:00+00:00'),
                ('RESEARCH-new.json', 'RESEARCH', 'completed', 'Newest completed research', '2026-07-01T11:00:00+00:00'),
                ('PLAN.json', 'PLAN', 'completed', 'Plan summary', '2026-07-01T08:00:00+00:00'),
            ]
            for filename, phase_name, status, summary, created_at in ranked_fixtures:
                (artifact_root / filename).write_text(json.dumps({
                    'phase': phase_name,
                    'status': status,
                    'created_at': created_at,
                    'structured_output': {
                        'status': status,
                        'summary': summary,
                        'evidence': [summary.lower().replace(' ', '-')],
                        'deliverables': ['next handoff'],
                        'next_handoff': f'{summary} handoff',
                    },
                }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            payload = json.loads(workflow_phase_artifact_path(paths, goal_id, WorkflowState.REQUIREMENTS.value).read_text(encoding='utf-8'))
            prompt = payload['prompt']
            self.assertIn('summary: Newest completed research', prompt)
            self.assertNotIn('summary: Older completed research', prompt)
            self.assertNotIn('summary: Newest failed research', prompt)

    def test_phase_dispatch_compacts_duplicate_handoffs_into_archive(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-compact'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            fixtures = [
                ('RESEARCH-stale.json', 'RESEARCH', 'completed', 'Stale research summary', '2026-07-01T09:00:00+00:00'),
                ('RESEARCH-failed.json', 'RESEARCH', 'failed', 'Failed research summary', '2026-07-01T10:00:00+00:00'),
                ('RESEARCH-best.json', 'RESEARCH', 'completed', 'Best research summary', '2026-07-01T11:00:00+00:00'),
                ('PLAN.json', 'PLAN', 'completed', 'Plan summary', '2026-07-01T08:00:00+00:00'),
            ]
            for filename, phase_name, status, summary, created_at in fixtures:
                (artifact_root / filename).write_text(json.dumps({
                    'phase': phase_name,
                    'status': status,
                    'created_at': created_at,
                    'structured_output': {
                        'status': status,
                        'summary': summary,
                        'evidence': [summary.lower().replace(' ', '-')],
                        'deliverables': ['next handoff'],
                        'next_handoff': f'{summary} handoff',
                    },
                }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            archive_dir = artifact_root / 'archive'
            self.assertTrue((archive_dir / 'RESEARCH-stale.json').exists())
            self.assertTrue((archive_dir / 'RESEARCH-failed.json').exists())
            self.assertFalse((artifact_root / 'RESEARCH-stale.json').exists())
            self.assertFalse((artifact_root / 'RESEARCH-failed.json').exists())
            self.assertTrue((artifact_root / 'RESEARCH-best.json').exists())
            payload = json.loads(workflow_phase_artifact_path(paths, goal_id, WorkflowState.REQUIREMENTS.value).read_text(encoding='utf-8'))
            self.assertEqual(sorted(payload['retention']['archived']), sorted([
                f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-failed.json',
                f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-stale.json',
            ]))
            self.assertIn('summary: Best research summary', payload['prompt'])
            self.assertNotIn('summary: Stale research summary', payload['prompt'])

    def test_phase_dispatch_prompt_can_load_prior_handoffs_from_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-manifest-handoff'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            workflow_phase_artifact_manifest_path(paths, goal_id).write_text(json.dumps({
                'schema_version': '1.0',
                'goal_id': goal_id,
                'updated_at': '2026-07-01T12:00:00+00:00',
                'preserve_phase': None,
                'retention': {
                    'archived_this_run': [],
                    'ranking_policy': {
                        'status_order': ['completed', 'skipped', 'failed', 'unknown'],
                        'tie_breakers': ['has_summary', 'evidence_count', 'deliverable_count', 'created_at', 'artifact_path'],
                    },
                },
                'active_artifacts': [
                    {
                        'phase': 'RESEARCH',
                        'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json',
                        'archived': False,
                        'status': 'completed',
                        'created_at': '2026-07-01T11:00:00+00:00',
                        'summary': 'Manifest-backed research summary',
                        'evidence': ['research/antigravity.md'],
                        'deliverables': ['verified findings', 'unknowns'],
                        'next_handoff': 'Hand research output to requirements.',
                        'evidence_count': 1,
                        'deliverable_count': 2,
                        'has_summary': True,
                    },
                    {
                        'phase': 'PLAN',
                        'artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json',
                        'archived': False,
                        'status': 'completed',
                        'created_at': '2026-07-01T10:00:00+00:00',
                        'summary': 'Manifest-backed plan summary',
                        'evidence': ['TODO.md'],
                        'deliverables': ['ordered plan'],
                        'next_handoff': 'Use plan for requirements.',
                        'evidence_count': 1,
                        'deliverable_count': 1,
                        'has_summary': True,
                    },
                ],
                'archived_artifacts': [],
                'selection': [
                    {
                        'phase': 'PLAN',
                        'candidate_count': 1,
                        'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json',
                        'selected_status': 'completed',
                        'selected_reasons': ['best-ranked'],
                        'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json'],
                        'archived_artifacts': [],
                    },
                    {
                        'phase': 'RESEARCH',
                        'candidate_count': 1,
                        'selected_artifact': f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json',
                        'selected_status': 'completed',
                        'selected_reasons': ['best-ranked'],
                        'retained_active_artifacts': [f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH.json'],
                        'archived_artifacts': [],
                    },
                ],
            }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            payload = json.loads(workflow_phase_artifact_path(paths, goal_id, WorkflowState.REQUIREMENTS.value).read_text(encoding='utf-8'))
            prompt = payload['prompt']
            self.assertIn('summary: Manifest-backed research summary', prompt)
            self.assertIn('summary: Manifest-backed plan summary', prompt)
            self.assertIn('next handoff: Hand research output to requirements.', prompt)
            self.assertIn('deliverables:', prompt)

    def test_phase_dispatch_writes_goal_artifact_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-manifest'
            artifact_root = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value).parent
            artifact_root.mkdir(parents=True, exist_ok=True)
            fixtures = [
                ('RESEARCH-stale.json', 'RESEARCH', 'completed', 'Stale research summary', '2026-07-01T09:00:00+00:00'),
                ('RESEARCH-best.json', 'RESEARCH', 'completed', 'Best research summary', '2026-07-01T11:00:00+00:00'),
                ('PLAN.json', 'PLAN', 'completed', 'Plan summary', '2026-07-01T08:00:00+00:00'),
            ]
            for filename, phase_name, status, summary, created_at in fixtures:
                (artifact_root / filename).write_text(json.dumps({
                    'phase': phase_name,
                    'status': status,
                    'created_at': created_at,
                    'structured_output': {
                        'status': status,
                        'summary': summary,
                        'evidence': [summary.lower().replace(' ', '-')],
                        'deliverables': ['next handoff'],
                        'next_handoff': f'{summary} handoff',
                    },
                }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            manifest = json.loads(workflow_phase_artifact_manifest_path(paths, goal_id).read_text(encoding='utf-8'))
            self.assertEqual(manifest['goal_id'], goal_id)
            self.assertEqual(manifest['preserve_phase'], 'REQUIREMENTS')
            self.assertIn('active_artifacts', manifest)
            self.assertIn('archived_artifacts', manifest)
            self.assertIn('selection', manifest)
            active_paths = {item['artifact'] for item in manifest['active_artifacts']}
            archived_paths = {item['artifact'] for item in manifest['archived_artifacts']}
            self.assertIn(f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH-best.json', active_paths)
            self.assertIn(f'state/arbiter/workflow/phase-artifacts/{goal_id}/PLAN.json', active_paths)
            self.assertIn(f'state/arbiter/workflow/phase-artifacts/{goal_id}/REQUIREMENTS.json', active_paths)
            self.assertIn(f'state/arbiter/workflow/phase-artifacts/{goal_id}/archive/RESEARCH-stale.json', archived_paths)
            research_selection = next(item for item in manifest['selection'] if item['phase'] == 'RESEARCH')
            self.assertEqual(research_selection['candidate_count'], 2)
            self.assertEqual(research_selection['selected_artifact'], f'state/arbiter/workflow/phase-artifacts/{goal_id}/RESEARCH-best.json')
            self.assertIn('best-ranked', research_selection['selected_reasons'])

    def test_phase_dispatch_prompt_includes_prior_structured_handoff_context(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.RESEARCH)
            goal_id = 'goal-1234'
            artifact_path = workflow_phase_artifact_path(paths, goal_id, WorkflowState.RESEARCH.value)
            artifact_path.parent.mkdir(parents=True, exist_ok=True)
            artifact_path.write_text(json.dumps({
                'phase': 'RESEARCH',
                'status': 'completed',
                'structured_output': {
                    'status': 'completed',
                    'summary': 'Research completed with verified provider notes.',
                    'evidence': ['research/antigravity.md', './scripts/arbiter startup-validate --json'],
                    'deliverables': ['verified findings', 'unknowns'],
                    'next_handoff': 'Hand research output to requirements.',
                },
            }, indent=2) + '\n', encoding='utf-8')
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.REQUIREMENTS, 'requirements workspace')
            goal.goal_id = goal_id
            orchestrator.queue.update_active(goal)
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            payload = json.loads(workflow_phase_artifact_path(paths, goal_id, WorkflowState.REQUIREMENTS.value).read_text(encoding='utf-8'))
            prompt = payload['prompt']
            self.assertIn('Prior structured handoffs:', prompt)
            self.assertIn('summary: Research completed with verified provider notes.', prompt)
            self.assertIn('deliverables:', prompt)
            self.assertIn('next handoff: Hand research output to requirements.', prompt)

    def test_phase_dispatch_structured_output_falls_back_to_raw_stdout(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.PLAN)
            _write_executable(root / 'agy', """if [[ "${1:-}" == "--version" ]]; then echo "agy fake 1.0"; exit 0; fi
if [[ "${1:-}" == "--help" ]]; then echo "--print --project --sandbox"; exit 0; fi
echo 'raw output without schema'
""")
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.RESEARCH, 'research workspace')
            with mock.patch.dict(os.environ, {'AGY_BIN': str(root / 'agy')}):
                result = orchestrator.run_active()
            self.assertTrue(result.passed)
            payload = json.loads(workflow_phase_artifact_path(paths, goal.goal_id, WorkflowState.RESEARCH.value).read_text(encoding='utf-8'))
            structured = payload['structured_output']
            self.assertEqual(structured['summary'], 'raw output without schema')
            self.assertEqual(structured['evidence'], [])
            self.assertEqual(structured['deliverables'], [])

    def test_phase_dispatch_executes_with_fake_provider(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.PLAN)
            _write_executable(root / 'agy', """if [[ "${1:-}" == "--version" ]]; then echo "agy fake 1.0"; exit 0; fi
if [[ "${1:-}" == "--help" ]]; then echo "--print --project --sandbox"; exit 0; fi
cat <<'OUT'
Summary:
The research phase completed with verified CLI evidence.
Evidence:
- research/antigravity.md
- ./scripts/arbiter startup-validate --json
Deliverables:
- verified findings
- unknowns
- next handoff
Next handoff:
Hand the updated research findings to requirements.
OUT
""")
            orchestrator = WorkflowOrchestrator(paths)
            goal = orchestrator.queue.enqueue(WorkflowState.RESEARCH, 'research workspace')
            with mock.patch.dict(os.environ, {'AGY_BIN': str(root / 'agy')}):
                result = orchestrator.run_active()
            self.assertTrue(result.passed)
            artifact_path = workflow_phase_artifact_path(paths, goal.goal_id, WorkflowState.RESEARCH.value)
            payload = json.loads(artifact_path.read_text(encoding='utf-8'))
            self.assertEqual(payload['status'], 'completed')
            self.assertEqual(payload['provider'], 'antigravity')
            structured = payload['structured_output']
            self.assertEqual(structured['status'], 'completed')
            self.assertEqual(structured['summary'], 'The research phase completed with verified CLI evidence.')
            self.assertIn('research/antigravity.md', structured['evidence'])
            self.assertEqual(structured['deliverables'], ['verified findings', 'unknowns', 'next handoff'])
            self.assertEqual(structured['next_handoff'], 'Hand the updated research findings to requirements.')

    def test_verify_persists_artifact_and_todo_sections(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.IMPLEMENT)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo ok\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo ok\n')
            orchestrator = WorkflowOrchestrator(paths)
            orchestrator.queue.enqueue(WorkflowState.VERIFY, 'verify workspace')
            result = orchestrator.run_active()
            self.assertTrue(result.passed)
            state = load_workflow_state(paths)
            self.assertEqual(state.current_state, WorkflowState.VERIFY)
            self.assertTrue(workflow_verify_result_path(paths).exists())
            todo = (root / 'TODO.md').read_text(encoding='utf-8')
            self.assertIn('### Pending', todo)
            self.assertIn('### Completed', todo)

    def test_audit_failure_reflection_requires_persisted_checkpoints(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.VERIFY)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo ok\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo ok\n')
            orchestrator = WorkflowOrchestrator(paths)
            orchestrator.queue.enqueue(WorkflowState.AUDIT, 'audit workspace', max_attempts=3)
            first = orchestrator.run_active()
            self.assertFalse(first.passed)
            self.assertEqual(first.branch, 'reflection')
            self.assertEqual(first.next_actions, ['debug', 'build', 'verify', 'audit'])
            blocked = orchestrator.run_active()
            self.assertFalse(blocked.passed)
            self.assertIn('workflow checkpoint blocked: debug requires explicit persisted evidence', blocked.message)
            state = load_workflow_state(paths)
            self.assertEqual(state.current_state, WorkflowState.IMPLEMENT)
            self.assertEqual(state.next_actions, ['debug', 'build', 'verify', 'audit'])
            self.assertEqual([action.status for action in state.required_actions], ['pending', 'pending', 'pending', 'pending'])
            payload = _complete_checkpoint(root, 'debug', 'reproduced audit failure in local run')
            self.assertEqual(payload['action'], 'debug')
            self.assertEqual(read_workflow_checkpoint_evidence(paths, state.active_goal.goal_id, 'debug').evidence, 'reproduced audit failure in local run')
            completed = orchestrator.run_active()
            self.assertFalse(completed.passed)
            self.assertEqual(completed.message, 'workflow checkpoint completed: debug')
            blocked_build = orchestrator.run_active()
            self.assertFalse(blocked_build.passed)
            self.assertIn('workflow checkpoint blocked: build requires explicit persisted evidence', blocked_build.message)
            state = load_workflow_state(paths)
            self.assertEqual(state.next_actions, ['build', 'verify', 'audit'])

    def test_audit_failure_escalation_requires_trace_craft_plan_build(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.VERIFY)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo ok\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo ok\n')
            orchestrator = WorkflowOrchestrator(paths)
            orchestrator.queue.enqueue(WorkflowState.AUDIT, 'audit workspace', max_attempts=3)
            orchestrator.run_active()
            self.assertIn('blocked: debug', orchestrator.run_active().message)
            _complete_checkpoint(root, 'debug', 'captured failing audit evidence')
            self.assertEqual(orchestrator.run_active().message, 'workflow checkpoint completed: debug')
            self.assertIn('blocked: build', orchestrator.run_active().message)
            _complete_checkpoint(root, 'build', 'documented rebuild plan and command set')
            self.assertEqual(orchestrator.run_active().message, 'workflow checkpoint completed: build')
            self.assertEqual(orchestrator.run_active().message, 'workflow checkpoint completed: verify')
            workflow_verify_result_path(paths).unlink()
            second = orchestrator.run_active()
            self.assertEqual(second.branch, 'escalation')
            self.assertEqual(second.next_actions, ['trace', 'craft', 'plan', 'build'])
            state = load_workflow_state(paths)
            self.assertEqual(state.current_state, WorkflowState.PLAN)
            self.assertEqual([action.name for action in state.required_actions], ['trace', 'craft', 'plan', 'build'])
            followup = orchestrator.run_active()
            self.assertIn('workflow checkpoint blocked: trace requires explicit persisted evidence', followup.message)
            state = load_workflow_state(paths)
            self.assertEqual(state.current_state, WorkflowState.PLAN)
            self.assertEqual(state.next_actions, ['trace', 'craft', 'plan', 'build'])

    def test_deployment_gate_requires_audit_and_checks(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo tests\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo harness\n')
            checks = {check.name: check for check in check_deployment_gate(paths)}
            self.assertFalse(checks['audit'].passed)
            self.assertIn('audit result', checks['audit'].detail)

    def test_cli_workflow_run_cannot_bypass_manual_checkpoint_without_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.VERIFY)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo ok\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo ok\n')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-run', 'AUDIT', '--json'])
            self.assertEqual(code, 1, stdout.getvalue())
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-run', '--json'])
            self.assertEqual(code, 1, stdout.getvalue())
            first_blocked = json.loads(stdout.getvalue())
            self.assertIn('workflow checkpoint blocked: debug requires explicit persisted evidence', first_blocked['message'])
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-run', '--json'])
            self.assertEqual(code, 1, stdout.getvalue())
            second_blocked = json.loads(stdout.getvalue())
            self.assertEqual(first_blocked['message'], second_blocked['message'])
            state = load_workflow_state(paths)
            self.assertEqual(state.next_actions, ['debug', 'build', 'verify', 'audit'])
            self.assertEqual([action.status for action in state.required_actions], ['pending', 'pending', 'pending', 'pending'])

    def test_cli_workflow_checkpoint_rejects_out_of_order_manual_completion(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.VERIFY)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo ok\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo ok\n')
            orchestrator = WorkflowOrchestrator(paths)
            orchestrator.queue.enqueue(WorkflowState.AUDIT, 'audit workspace', max_attempts=3)
            orchestrator.run_active()
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-checkpoint', 'complete', 'build', '--evidence', 'skipped ahead', '--json'])
            self.assertEqual(code, 1, stdout.getvalue())
            payload = json.loads(stdout.getvalue())
            self.assertIn("'build' is not the next pending manual workflow checkpoint", payload['message'])
            self.assertIsNone(read_workflow_checkpoint_evidence(paths, load_workflow_state(paths).active_goal.goal_id, 'build'))

    def test_cli_can_run_and_inspect_uppercase_workflow_state(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            _persist_state(paths, WorkflowState.IMPLEMENT)
            _write_executable(root / 'scripts' / 'test-arbiter', 'echo tests\n')
            _write_executable(root / 'tests' / 'harness.sh', 'echo harness\n')
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-run', 'VERIFY', '--json'])
            self.assertEqual(code, 0, stdout.getvalue())
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-state', '--json'])
            self.assertEqual(code, 0)
            self.assertIn('"current_state": "VERIFY"', stdout.getvalue())

    def test_workflow_reset_clears_failed_state(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            state = load_workflow_state(paths)
            state.current_state = WorkflowState.FAILED
            state.required_actions = []
            WorkflowPersistence(paths).save(state)
            stdout = StringIO()
            with contextlib.redirect_stdout(stdout):
                code = main(['--root', str(root), 'workflow-reset', '--json'])
            self.assertEqual(code, 0, stdout.getvalue())
            state = load_workflow_state(paths)
            self.assertNotEqual(state.current_state, WorkflowState.FAILED)


if __name__ == '__main__':
    unittest.main()
