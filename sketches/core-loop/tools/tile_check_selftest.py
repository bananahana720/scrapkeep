#!/usr/bin/env python3
"""Synthetic, lossless WebP fixtures; no game, GPU, wall clock or user:// writes.

python3 tools/tile_check_selftest.py
Exit 0 = PASS; 1 = FAIL; 2 = dependencies missing (explicit SKIP).
A black/white hard edge must fail the checker; the self-test passes only when
that rejection occurs. --help on tile_check.py documents thresholds and metrics.
"""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import sys


CHECKER = Path(__file__).resolve().parent / "tile_check.py"
spec = importlib.util.spec_from_file_location("tile_check", CHECKER)
tile_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tile_check)


class TileCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tile-check-", dir=Path(__file__).resolve().parents[3] / "artifacts/local/sol")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "assets/textures/nested").mkdir(parents=True)
        (self.root / "tools").mkdir()
        (self.root / "assets/asset_budgets.json").write_text(json.dumps({"texture": {"max_side": 64}}))
        self.rows = []
        self.registry()

    def registry(self):
        (self.root / "assets/registry.json").write_text(json.dumps({"assets": self.rows}))

    def image(self, pixels, name="test.webp", registered=True):
        path = self.root / "assets/textures" / name
        Image.fromarray(pixels).save(path, format="WEBP", lossless=True, exact=True)
        if registered:
            self.rows.append({"path": "res://assets/textures/" + name, "class": "texture", "ships": True})
            self.registry()
        return path

    def check(self):
        return tile_check.run_check(self.root, np, Image, 64, 8.0, 32.0)

    def cli(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = tile_check.main(["--project-root", str(self.root), *args])
        return code, output.getvalue()

    def test_uniform_nested_passes(self):
        self.image(np.full((8, 12, 3), 120, dtype=np.uint8), "nested/test.webp")
        code, output = self.cli()
        self.assertEqual(code, 0, output)
        self.assertTrue(output.rstrip().endswith("tile_check: PASS"), output)
        self.assertEqual(self.check()["textures"][0]["edges"]["left_right"], {"mean": 0.0, "peak": 0.0})

    def test_hard_edges_fail_both_axes(self):
        for axis, edge_name in [(1, "left_right"), (0, "top_bottom")]:
            with self.subTest(axis=axis):
                pixels = np.zeros((8, 8, 3), dtype=np.uint8)
                if axis == 1:
                    pixels[:, 4:] = 255
                else:
                    pixels[4:, :] = 255
                self.rows = []
                path = self.image(pixels)
                result = tile_check.measure_image(path, np, Image, 64, 8.0, 32.0)
                self.assertTrue(result["errors"], result)
                self.assertEqual(result["edges"][edge_name], {"mean": 255.0, "peak": 255.0})
        code, output = self.cli("--json")
        self.assertEqual(code, 1, output)
        self.assertFalse(json.loads(output)["passed"])

    def test_peak_catches_local_seam(self):
        pixels = np.zeros((64, 64, 3), dtype=np.uint8)
        pixels[20, -1, :] = 255
        self.image(pixels)
        result = self.check()["textures"][0]
        self.assertLess(result["edges"]["left_right"]["mean"], 8.0)
        self.assertEqual(result["edges"]["left_right"]["peak"], 255.0)
        self.assertTrue(result["errors"], result)

    def test_mean_catches_broad_seam_below_peak_cap(self):
        pixels = np.zeros((8, 8, 3), dtype=np.uint8)
        pixels[:, -1] = 16
        self.image(pixels)
        result = self.check()["textures"][0]
        self.assertEqual(result["edges"]["left_right"], {"mean": 16.0, "peak": 16.0})
        self.assertTrue(result["errors"], result)

    def test_exact_limits_pass(self):
        pixels = np.zeros((8, 8, 3), dtype=np.uint8)
        pixels[2:4, -1] = 32
        self.image(pixels)
        self.assertTrue(self.check()["passed"])

    def test_alpha_seam_and_invisible_rgb(self):
        pixels = np.zeros((8, 8, 4), dtype=np.uint8)
        pixels[:, -1, :3] = 255
        path = self.image(pixels)
        result = tile_check.measure_image(path, np, Image, 64, 8.0, 32.0)
        self.assertFalse(result["errors"], result)
        pixels[:, -1, 3] = 255
        Image.fromarray(pixels).save(path, format="WEBP", lossless=True, exact=True)
        self.assertTrue(tile_check.measure_image(path, np, Image, 64, 8.0, 32.0)["errors"])

    def test_size_budget_and_override(self):
        self.image(np.zeros((8, 65, 3), dtype=np.uint8))
        code, output = self.cli()
        self.assertEqual(code, 1, output)
        self.assertIn("max side 65 exceeds 64", output)
        self.assertEqual(self.cli("--max-side", "65")[0], 0)

    def test_degenerate_and_corrupt_images_fail(self):
        self.image(np.zeros((1, 8, 3), dtype=np.uint8))
        self.assertFalse(self.check()["passed"])
        (self.root / "assets/textures/test.webp").write_bytes(b"not an image")
        code, output = self.cli()
        self.assertEqual(code, 1, output)
        self.assertIn("cannot decode", output)

    def test_registry_extra_missing_duplicate_and_class(self):
        resource = "res://assets/textures/test.webp"
        for row in [[], [{"path": resource, "class": "model"}],
                    [{"path": resource, "class": "texture"}] * 2]:
            self.assertTrue(tile_check.registry_errors({"assets": row}, [resource]))
        self.assertTrue(tile_check.registry_errors({"assets": [{"path": resource, "class": "texture"}]}, []))
        self.assertTrue(tile_check.registry_errors({"assets": []}, []))
        self.assertTrue(tile_check.registry_errors({"assets": [None]}, [resource]))
        self.assertTrue(tile_check.registry_errors([], [resource]))
        self.image(np.zeros((8, 8, 3), dtype=np.uint8), registered=False)
        self.assertEqual(self.cli()[0], 1)

    def test_bad_setup_and_limits_fail(self):
        (self.root / "assets/registry.json").write_text("{bad json")
        code, output = self.cli("--json")
        self.assertEqual(code, 2, output)
        self.assertIn("setup_error", json.loads(output))
        for value in ["nan", "inf", "-1", "256"]:
            with self.assertRaises(Exception):
                tile_check.channel_limit(value)


if __name__ == "__main__":
    try:
        np, Image = tile_check.dependencies()
    except RuntimeError as exc:
        print(f"tile_check_selftest: SKIP ({exc})")
        sys.exit(2)
    (Path(__file__).resolve().parents[3] / "artifacts/local/sol").mkdir(parents=True, exist_ok=True)
    names = unittest.defaultTestLoader.getTestCaseNames(TileCheckTests)
    failures = 0
    for name in names:
        case = TileCheckTests(name)
        try:
            case.setUp()
            getattr(case, name)()
            print(f"{name}: PASS")
        except Exception as exc:
            failures += 1
            print(f"{name}: FAIL ({type(exc).__name__}: {exc})")
        finally:
            case.doCleanups()
    print(f"tile_check_selftest: FAIL ({failures})" if failures else f"tile_check_selftest: PASS ({len(names)} cases)")
    sys.exit(1 if failures else 0)
