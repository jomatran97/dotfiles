from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from arbiter.gates import check_pre_implementation_gates, check_research_gate
from arbiter.paths import ArbiterPaths
from tests.helpers import make_repo


class GateTests(unittest.TestCase):
    def test_research_gate_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / 'arbiter').mkdir()
            (root / 'research').mkdir()
            paths = ArbiterPaths(root)
            result = check_research_gate(paths)
            self.assertFalse(result.passed)
            self.assertIn('research/claude.md', result.missing)

    def test_all_pre_implementation_gates_pass(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            results = check_pre_implementation_gates(ArbiterPaths(root))
            self.assertTrue(all(result.passed for result in results))


if __name__ == '__main__':
    unittest.main()
