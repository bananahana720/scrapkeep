import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "report", Path(__file__).parents[1] / "report.py"
)
report_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report_module)


class ReportTests(unittest.TestCase):
    def test_pooled_fresh_frame_metrics_counts_and_original_loss(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            trial = root / "trial-001"
            trial.mkdir()
            result = {
                "trial": 1,
                "outcome": "infrastructure_error",
                "terminal_outcome": "lost",
                "started_at": 100,
                "ended_at": 145,
                "active_seconds": 20,
                "result_labels": ["One more spark?", "One more spark?", "RUN ENDED"],
                "pause_check": "passed",
                "restart_check": None,
            }
            (trial / "result.json").write_text(json.dumps(result))
            events = [
                {
                    "kind": "combat_segment",
                    "tick_gaps_ms": [10, 20, 30, 40],
                    "actions": [{}, {}],
                    "frames": [
                        {"frame_age_ms": 50, "capture_ms": 60, "observe_ms": 70}
                    ],
                },
                {
                    "kind": "combat_segment",
                    "tick_gaps_ms": [100],
                    "actions": [{}],
                    "frames": [
                        {"frame_age_ms": 150, "capture_ms": 160, "observe_ms": 170}
                    ],
                },
                {"kind": "observation", "milliseconds": 999},
                {"kind": "action", "reward_id": "echo"},
                {"kind": "restart_action"},
            ]
            (trial / "events.ndjson").write_text(
                "\n".join(json.dumps(event) for event in events)
            )
            record = {
                "trials": [result],
                "passed": False,
                "configuration": {
                    "trials": 1,
                    "pause_check": True,
                    "restart_check": True,
                },
                "source_hashes": {"a": "hash"},
            }
            text = report_module.write_report(root, record).read_text()
            self.assertIn("| Input tick gap | 5 | 30.00 | 100.00 | 100.00 |", text)
            self.assertIn("| Fresh-frame age | 2 | 50.00 | 150.00 | 150.00 |", text)
            self.assertIn(
                "| Semantic UI observation | 1 | 999.00 | 999.00 | 999.00 |", text
            )
            self.assertIn(
                "infrastructure_error | lost | 45.00s | 20.00s | 3 / 2 | 1", text
            )
            self.assertIn("restart: not established", text)
            self.assertIn("One more spark?; RUN ENDED", text)
            self.assertIn("echo × 1", text)
            self.assertIn("[report.json](report.json)", text)
            self.assertIn("No deterministic replay", text)

    def test_missing_and_malformed_evidence_is_visible_and_not_zero_latency(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            trial = root / "trial-001"
            trial.mkdir()
            (trial / "events.ndjson").write_text(
                'broken json\n{"kind":"observation","milliseconds":null}\n'
            )
            text = report_module.write_report(
                root,
                {
                    "trials": [{"trial": 1, "outcome": "timeout"}],
                    "configuration": {},
                    "cleanup_errors": ["release failed"],
                },
            ).read_text()
            self.assertIn(
                "| Semantic UI observation | 0 | unavailable | unavailable | unavailable |",
                text,
            )
            self.assertIn("Errors and evidence gaps", text)
            self.assertIn("events.ndjson line 1", text)
            self.assertIn("result.json:", text)
            self.assertIn("release failed", text)
            self.assertIn("pause/resume: not requested", text)

    def test_empty_startup_failure_still_generates_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            text = report_module.write_report(
                temporary, {"error": "build failed", "trials": [], "passed": False}
            ).read_text()
            self.assertIn("Recorded trials: 0 / unspecified", text)
            self.assertIn("build failed", text)

    def test_invalid_samples_are_omitted(self):
        self.assertEqual(
            report_module._distribution([None, -1, float("nan"), float("inf"), True]),
            "0 | unavailable | unavailable | unavailable",
        )


if __name__ == "__main__":
    unittest.main()
