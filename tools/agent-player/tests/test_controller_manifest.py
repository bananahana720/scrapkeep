import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run as runner

COMMITTED = Path(runner.__file__).resolve().parent / "controller-manifest.json"


def write_controller(root, files):
    for name, text in files.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    (root / "__pycache__").mkdir(exist_ok=True)
    (root / "__pycache__" / "stale.py").write_text("ignored")


class ControllerManifestTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name) / "controller"
        write_controller(
            self.root, {"seat.py": "seat", "nested/probe.py": "probe", "notes.md": "x"}
        )
        self.manifest = Path(self.directory.name) / "manifest.json"
        runner.write_controller_manifest(self.root, self.manifest)

    def tearDown(self):
        self.directory.cleanup()

    def test_manifest_lists_every_python_file_with_hash_and_size(self):
        data = json.loads(self.manifest.read_text())
        self.assertEqual(sorted(data["files"]), ["nested/probe.py", "seat.py"])
        self.assertEqual(data["files"]["seat.py"]["size"], 4)
        self.assertEqual(len(data["files"]["seat.py"]["sha256"]), 64)
        self.assertEqual(data["controller_root"], runner.portable_label(self.root))

    def test_matching_controller_passes_and_is_recorded(self):
        result = runner.check_controller(self.root, self.manifest, False)
        self.assertTrue(result["matched"])
        self.assertIsNone(result["first_mismatch"])
        self.assertFalse(result["drift_allowed"])
        self.assertEqual(result["hashes"], runner.controller_entries(self.root))

    def test_changed_file_is_refused_by_name(self):
        (self.root / "seat.py").write_text("seat with drift")
        with self.assertRaises(SystemExit) as stop:
            runner.check_controller(self.root, self.manifest, False)
        self.assertIn("seat.py", str(stop.exception))
        self.assertNotEqual(stop.exception.code, 0)

    def test_missing_and_unexpected_files_are_refused(self):
        (self.root / "nested/probe.py").unlink()
        with self.assertRaises(SystemExit) as stop:
            runner.check_controller(self.root, self.manifest, False)
        self.assertIn("nested/probe.py", str(stop.exception))
        (self.root / "nested/probe.py").write_text("probe")
        (self.root / "extra.py").write_text("new")
        with self.assertRaises(SystemExit) as stop:
            runner.check_controller(self.root, self.manifest, False)
        self.assertIn("extra.py", str(stop.exception))

    def test_drift_flag_bypasses_and_records_the_mismatch(self):
        (self.root / "seat.py").write_text("seat with drift")
        result = runner.check_controller(self.root, self.manifest, True)
        self.assertFalse(result["matched"])
        self.assertEqual(result["first_mismatch"], "seat.py")
        self.assertTrue(result["drift_allowed"])

    def test_main_refuses_drift_before_creating_output(self):
        (self.root / "seat.py").write_text("seat with drift")
        output = Path(self.directory.name) / "output"
        argv = [
            "run.py",
            "--controller-root",
            str(self.root),
            "--controller-manifest",
            str(self.manifest),
            "--output",
            str(output),
        ]
        with patch.object(sys, "argv", argv), self.assertRaises(SystemExit) as stop:
            runner.main()
        self.assertIn("seat.py", str(stop.exception))
        self.assertFalse(output.exists())

    def test_committed_manifest_is_complete_and_well_formed(self):
        data = json.loads(COMMITTED.read_text())
        self.assertTrue(data["controller_root"].startswith("~/"))
        self.assertTrue(data["files"])
        for name, entry in data["files"].items():
            self.assertTrue(name.endswith(".py"), name)
            self.assertEqual(sorted(entry), ["sha256", "size"], name)
            self.assertEqual(len(entry["sha256"]), 64, name)
            self.assertGreaterEqual(entry["size"], 0, name)


if __name__ == "__main__":
    unittest.main()
