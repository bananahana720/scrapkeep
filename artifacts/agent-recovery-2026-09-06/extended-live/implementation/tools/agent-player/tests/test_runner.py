import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import run as runner


class OutputOwnershipTests(unittest.TestCase):
    def test_concurrent_callers_cannot_share_an_output_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "shared"

            def attempt():
                try:
                    runner.prepare_output(output, "test")
                    return True
                except (ValueError, FileExistsError):
                    return False

            with ThreadPoolExecutor(max_workers=2) as workers:
                self.assertEqual(sum(workers.map(lambda _: attempt(), range(2))), 1)
            self.assertTrue((output / "run-owner.json").is_file())

    def test_parallel_defaults_are_distinct_even_in_the_same_second(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(runner, "ROOT", Path(directory)),
        ):
            first = runner.prepare_output(None, "test")
            second = runner.prepare_output(None, "test")
            self.assertNotEqual(first, second)


class FreshRunTests(unittest.TestCase):
    def test_unresponsive_restart_cannot_count_previous_terminal_result_again(self):
        ui = {
            "truncated": False,
            "nodes": [
                {
                    "role": 43,
                    "name": "Start a fresh run",
                    "control_id": "restart",
                    "visible": True,
                    "showing": True,
                    "enabled": True,
                    "sensitive": True,
                    "actions": ["press"],
                }
            ],
        }
        args = SimpleNamespace(
            profile="passive",
            max_seconds=5,
            smoke_seconds=0,
            pause_check=False,
            restart_check=False,
            rewards="ground-loop,echo",
        )
        for states in (
            ("won", "won"),
            ("lost", "lost"),
            ("won", "unknown", "won"),
            ("lost", "unknown", "lost"),
            ("won", "unknown", "lost"),
        ):
            with (
                self.subTest(states=states),
                tempfile.TemporaryDirectory() as directory,
            ):
                desktop = SimpleNamespace(activate=lambda observation, action: None)
                with (
                    patch.object(
                        runner, "observe", side_effect=[(ui, state) for state in states]
                    ),
                    patch.object(runner.time, "sleep"),
                ):
                    result = runner.trial(desktop, args, Path(directory), 1)
                self.assertEqual(result["outcome"], "infrastructure_error")
                self.assertNotIn("terminal_outcome", result)
                self.assertRegex(
                    result["error"], "previous terminal result|fresh play was confirmed"
                )
                self.assertEqual(result["active_seconds"], 0)
