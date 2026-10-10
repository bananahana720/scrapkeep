"""Tests for the terrain kind: positive controls and seeded defects. Builds real tile sets by
running the kind's entry.py in Blender (the only Python with numpy), then validates the PNGs.
Run: python3 -m unittest discover -s tools/asset-forge -p 'test_terrain.py'"""
import json
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import forge  # noqa: E402
import forgecore as fc  # noqa: E402

KIND_DIR = HERE / "kinds" / "terrain"
V = fc.load_module(KIND_DIR / "validate.py", "terrain_validate")
BLENDER = shutil.which("blender")

PRELUDE = '''
import numpy as np
import texlib as tl

def base(params, n=256, steps=5):
    h = tl.normalize(0.7 * tl.warp(tl.fbm(n, 3, 5, 11), 12, 3, 5) + 0.3 * tl.worley(n, 6, 2, "edge"))
    return n, h
'''

RECIPES = {
    "good_fbm": PRELUDE + '''
def build(params):
    n, h = base(params)
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "oxide", "sandstone", "bone"], params["palette"], steps=6),
            "roughness": 0.8 + 0.2 * (1 - h)}
''',
    "good_worley": PRELUDE + '''
def build(params):
    n = 256
    h = tl.normalize(tl.blur(tl.worley(n, 7, 4, "f1"), 2) * 0.8 + 0.2 * tl.fbm(n, 4, 4, 9))
    return {"height": h, "albedo": tl.ramp(h, ["charcoal", "sandstone", "bone"], params["palette"], steps=5), "normal_strength": 2.0}
''',
    # seeded defects
    "bad_ramp": PRELUDE + '''
def build(params):
    n = 256
    h = np.tile(np.linspace(0, 1, n, dtype=np.float32)[None, :], (n, 1))
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "bone"], params["palette"])}
''',
    "bad_hard_edge": PRELUDE + '''
def build(params):
    n, h = base(params)
    h = h.copy()
    h[:8, :] = 1.0
    h[:, :8] = 1.0
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "oxide", "sandstone", "bone"], params["palette"], steps=6)}
''',
    "bad_cropped_noise": PRELUDE + '''
def build(params):
    n = 256
    h = tl.fbm(2 * n, 4, 5, 3)[:n, :n]
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "bone"], params["palette"], steps=6)}
''',
    "bad_magenta": PRELUDE + '''
def build(params):
    n, h = base(params)
    albedo = np.zeros((n, n, 3), dtype=np.float32)
    albedo[..., 0] = 1.0
    albedo[..., 2] = 1.0
    return {"height": h, "albedo": albedo}
''',
    "bad_npot": PRELUDE + '''
def build(params):
    n = 300
    h = tl.normalize(tl.fbm(n, 3, 4, 2))
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "bone"], params["palette"], steps=5)}
''',
    "bad_white_noise": PRELUDE + '''
def build(params):
    n = 256
    h = np.random.default_rng(1).random((n, n)).astype(np.float32)
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "bone"], params["palette"], steps=5)}
''',
    "bad_flat": PRELUDE + '''
def build(params):
    n = 256
    h = np.full((n, n), 0.5, dtype=np.float32)
    return {"height": h, "albedo": tl.ramp(h, ["petrol", "bone"], params["palette"])}
''',
}


def write_rgb_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(k, b):
        return struct.pack(">I", len(b)) + k + b + struct.pack(">I", zlib.crc32(k + b))
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


@unittest.skipUnless(BLENDER, "blender not installed")
class TerrainKind(unittest.TestCase):
    pack = None
    kind = None
    tmp = None
    built = {}

    @classmethod
    def setUpClass(cls):
        cls.pack = fc.load_pack("core-loop")
        cls.kind = fc.load_kind("terrain")
        cls.tmp = Path(tempfile.mkdtemp(prefix="terrain-test-"))
        for name, src in RECIPES.items():
            cls.built[name] = cls.make(name, src)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    @classmethod
    def make(cls, name, src):
        vdir = cls.tmp / name
        vdir.mkdir()
        params = forge.build_params(cls.pack, cls.kind, name, "prop")
        fc.write_json(vdir / "params.json", params)
        (vdir / "recipe.py").write_text(src)
        r = subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "1", "-P", str(KIND_DIR / "entry.py"), "--", str(vdir)],
                           capture_output=True, text=True, timeout=300, cwd=vdir)
        result = json.loads((vdir / "result.json").read_text())
        assert result["status"] == "ok", "%s: %s\n%s" % (name, result.get("error"), r.stdout[-800:])
        return vdir

    def validate(self, name, vdir=None):
        vdir = vdir or self.built[name]
        params = fc.read_json(vdir / "params.json")
        result = fc.read_json(vdir / "result.json")
        return V.validate(vdir, params, result, self.pack)

    def state(self, checks, cid):
        found = [c for c in checks if c["id"] == cid]
        self.assertTrue(found, "no check %s in %s" % (cid, [c["id"] for c in checks]))
        return found[0]["state"]

    def clone(self, name, label):
        dst = self.tmp / label
        shutil.copytree(self.built[name], dst)
        return dst

    # --- positive controls ---------------------------------------------------------
    def test_positive_controls_pass(self):
        for name in ("good_fbm", "good_worley"):
            checks = self.validate(name)
            sc = fc.score(checks)
            self.assertTrue(sc["passed"], "%s failed: %s" % (name, [c for c in checks if c["state"] == "fail"]))
            self.assertEqual(sc["state"], "pass", [c for c in checks if c["state"] != "pass" and c["state"] != "info"])
            seam = [c for c in checks if c["id"] == "seam"][0]["value"]
            print("seam %s = %.3f" % (name, seam))
            self.assertLess(seam, 1.6)
            self.assertGreaterEqual(len(checks), 12)

    def test_outputs_exist_and_tres_names_all_maps(self):
        vdir = self.built["good_fbm"]
        for m in V.MAPS:
            self.assertTrue((vdir / "out" / ("good_fbm_%s.png" % m)).is_file())
        text = (vdir / "out" / "good_fbm.tres").read_text()
        self.assertIn("StandardMaterial3D", text)
        self.assertIn("__FORGE_TEXTURES__", text)
        self.assertTrue((vdir / "preview" / "sheet.png").is_file())
        self.assertTrue((vdir / "reference" / "texlib.py").is_file())
        w, h, ch, depth, _ = V.read_png(vdir / "out" / "good_fbm_height.png")
        self.assertEqual((w, h, ch, depth), (256, 256, 1, 16))

    def test_validator_seam_matches_texlib_seam(self):
        vdir = self.built["good_fbm"]
        seams = fc.read_json(vdir / "result.json")["measure"]["seam"]
        for m, expect in seams.items():
            w, h, ch, depth, rows = V.read_png(vdir / "out" / ("good_fbm_%s.png" % m))
            got = V.seam_metric(rows, ch, 65535 if depth == 16 else 255)
            self.assertAlmostEqual(got, expect, delta=0.15 * max(expect, 1.0) + 0.05, msg=m)

    # --- seeded defects (each must FAIL) --------------------------------------------
    def assert_fails(self, name, cid):
        checks = self.validate(name)
        self.assertEqual(self.state(checks, cid), "fail", [c for c in checks if c["id"] == cid])
        self.assertFalse(fc.score(checks)["passed"])
        return [c for c in checks if c["id"] == cid][0]["value"]

    def test_linear_ramp_fails_seam(self):
        print("seam bad_ramp = %.1f" % self.assert_fails("bad_ramp", "seam"))

    def test_hard_edged_tile_fails_seam(self):
        print("seam bad_hard_edge = %.1f" % self.assert_fails("bad_hard_edge", "seam"))

    def test_cropped_noise_fails_seam(self):
        print("seam bad_cropped_noise = %.1f" % self.assert_fails("bad_cropped_noise", "seam"))

    def test_off_palette_magenta_fails(self):
        self.assert_fails("bad_magenta", "palette")

    def test_non_power_of_two_fails(self):
        self.assert_fails("bad_npot", "size_pot")

    def test_white_noise_height_fails(self):
        self.assert_fails("bad_white_noise", "smoothness")

    def test_flat_height_fails(self):
        self.assert_fails("bad_flat", "relief")

    def test_missing_map_fails(self):
        vdir = self.clone("good_fbm", "missing_ao")
        (vdir / "out" / "good_fbm_ao.png").unlink()
        params = fc.read_json(vdir / "params.json")
        params["asset"] = "good_fbm"
        checks = V.validate(vdir, params, fc.read_json(vdir / "result.json"), self.pack)
        self.assertEqual(self.state(checks, "maps_present"), "fail")
        self.assertFalse(fc.score(checks)["passed"])

    def test_mismatched_map_size_fails(self):
        vdir = self.clone("good_fbm", "size_mismatch")
        params = fc.read_json(vdir / "params.json")
        params["asset"] = "good_fbm"
        write_rgb_png(vdir / "out" / "good_fbm_albedo.png", 128, 128, [[(210, 197, 165)] * 128] * 128)
        checks = V.validate(vdir, params, fc.read_json(vdir / "result.json"), self.pack)
        self.assertEqual(self.state(checks, "size_equal"), "fail")

    def test_directx_normal_fails_y_plus(self):
        vdir = self.clone("good_fbm", "flipped_green")
        params = fc.read_json(vdir / "params.json")
        params["asset"] = "good_fbm"
        w, h, ch, depth, rows = V.read_png(vdir / "out" / "good_fbm_normal.png")
        flipped = [[(r[3 * x], 255 - r[3 * x + 1], r[3 * x + 2]) for x in range(w)] for r in rows]
        write_rgb_png(vdir / "out" / "good_fbm_normal.png", w, h, flipped)
        checks = V.validate(vdir, params, fc.read_json(vdir / "result.json"), self.pack)
        self.assertEqual(self.state(checks, "normal_y_plus"), "fail", [c for c in checks if c["id"] == "normal_y_plus"])

    def test_recipe_fault_is_reported(self):
        vdir = self.tmp / "broken"
        vdir.mkdir()
        fc.write_json(vdir / "params.json", forge.build_params(self.pack, self.kind, "broken", "prop"))
        (vdir / "recipe.py").write_text("def build(params):\n    return {'height': 1}\n")
        r = subprocess.run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "1", "-P", str(KIND_DIR / "entry.py"), "--", str(vdir)],
                           capture_output=True, text=True, timeout=300, cwd=vdir)
        self.assertEqual(r.returncode, 1)
        result = fc.read_json(vdir / "result.json")
        self.assertEqual(result["status"], "recipe_error")
        checks = V.validate(vdir, fc.read_json(vdir / "params.json"), result, self.pack)
        self.assertEqual(self.state(checks, "build"), "fail")


class TerrainStatic(unittest.TestCase):
    def test_kind_and_pack_wiring(self):
        pack = fc.load_pack("core-loop")
        kind = fc.load_kind("terrain")
        self.assertIn("terrain", fc.kind_names())
        params = forge.build_params(pack, kind, "x_tile", "prop")
        self.assertEqual(params["band"], [256, 1024])
        self.assertEqual(params["max_draw_calls"], 1)
        self.assertIn("textures", pack["promote"]["terrain"])
        self.assertIn("sandstone", params["palette"])
        for f in ("kind.toml", "brief.md", "entry.py", "validate.py", "promote.py", "README.md", "texlib.py"):
            self.assertTrue((KIND_DIR / f).is_file(), f)

    def test_pure_python_seam_metric(self):
        n = 64
        ramp = [[round(255 * x / (n - 1)) for x in range(n)] for _ in range(n)]
        flat = [[128] * n for _ in range(n)]
        smooth = [[round(127.5 + 127.5 * __import__("math").sin(2 * 3.14159265 * x / n)) for x in range(n)] for _ in range(n)]
        self.assertGreater(V.seam_metric(ramp, 1, 255), 20)
        self.assertLess(V.seam_metric(flat, 1, 255), 0.01)
        self.assertLess(V.seam_metric(smooth, 1, 255), V.SEAM_WARN)  # a sine wraps at its steepest point, so ~1.6

    def test_promote_rewrites_res_path(self):
        import importlib.util  # noqa: F401
        P = fc.load_module(KIND_DIR / "promote.py", "terrain_promote")
        pack = fc.load_pack("core-loop")
        textures = Path(pack["repo_root"]) / pack["promote"]["terrain"]["textures"]
        self.assertEqual(P.res_folder(pack, textures), "res://assets/textures")


    def test_promote_regenerates_the_material_instead_of_copying_it(self):
        P = fc.load_module(KIND_DIR / "promote.py", "terrain_promote_regen")
        root = Path(tempfile.mkdtemp())
        try:
            v = root / "v001"
            (v / "out").mkdir(parents=True)
            for m in P.MAPS:
                (v / "out" / ("tile_%s.png" % m)).write_bytes(b"png")
            (v / "out" / "tile.tres").write_text('[gd_resource type="StandardMaterial3D"]\n[sub_resource type="GDScript" id="evil"]\n')
            (v / "recipe.py").write_text("def build(p): pass\n")
            fc.write_json(v / "result.json", {"uv_scale": 3.0})
            pack = {"repo_root": str(root), "sketch": "sk", "promote": {"terrain": {"textures": "sk/assets/textures"}}}
            P.promote(v, {"asset": "tile", "pack": "test"}, pack, {})
            text = (root / "sk/assets/textures/tile/tile.tres").read_text()
            self.assertNotIn("GDScript", text)
            self.assertIn("uv1_scale = Vector3(3, 3, 3)", text)
            self.assertIn("res://assets/textures/tile/tile_albedo.png", text)
        finally:
            shutil.rmtree(root)

if __name__ == "__main__":
    unittest.main()
