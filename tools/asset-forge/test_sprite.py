"""Sprite kind tests. Run: python3 -m unittest discover -s tools/asset-forge -p 'test_*.py' -v
Validator cases build a version directory by hand (no Blender). The Blender case runs the real
harness through `forge run` (needs blender and bwrap) and is skipped without them.
Seeded defects must FAIL."""
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import forge  # noqa: E402
import forgecore as fc  # noqa: E402
import pngio  # noqa: E402

validate = fc.load_module(HERE / "kinds" / "sprite" / "validate.py", "sprite_validate")
sk = fc.load_module(HERE / "kinds" / "sprite" / "spritekit.py", "spritekit_under_test")
promote = fc.load_module(HERE / "kinds" / "sprite" / "promote.py", "sprite_promote")

HAVE_BLENDER = shutil.which("blender") is not None and shutil.which("bwrap") is not None
needs_blender = unittest.skipUnless(HAVE_BLENDER, "blender and bwrap required")

PACK = fc.load_pack("core-loop")
PALETTE = fc.pack_palette(PACK)
RAMP = sk.build_ramp(PALETTE)
BASE, LIGHT, DARK = RAMP["oxide.base"], RAMP["oxide.light"], RAMP["oxide.dark"]
CRATE_GLB = fc.REPO / "sketches" / "core-loop" / "assets" / "models" / "scrap_crate.glb"


def new_version(root, prompt="A 4-direction 32px icon of a thing"):
    os.environ["FORGE_HOME"] = str(root)
    return forge.prepare_version(PACK, fc.load_kind("sprite"), "test_sp", "prop", prompt, preview=False)


def blank(w, h):
    return [[(0, 0, 0, 0)] * w for _ in range(h)]


def good_frame(size=32):
    f = blank(size, size)
    for y in range(6, size - 4):
        for x in range(5, size - 5):
            f[y][x] = (*BASE, 255)
    f[8][8] = (*LIGHT, 255)
    f[size - 6][size - 8] = (*DARK, 255)
    return f


def write_sheet(vdir, frames, fw=32, fh=32, n=4, meta_extra=None, rows=None):
    rows = rows if rows is not None else [r for f in frames for r in f]
    (vdir / "out").mkdir(exist_ok=True)
    pngio.write(vdir / "out" / "test_sp_sheet.png", len(rows[0]), len(rows), rows)
    meta = {"frame_width": fw, "frame_height": fh, "directions": n, "pivot": [16.0, 26.0]}
    meta.update(meta_extra or {})
    (vdir / "out" / "test_sp.json").write_text(json.dumps(meta))
    return {"status": "ok", "warnings": [], "measure": {"size": [1.0, 1.0, 1.0]}}


def run_validate(vdir, params, result):
    return {c["id"]: c for c in validate.validate(vdir, params, result, PACK)}


class SpriteKit(unittest.TestCase):
    def test_ramp_has_four_steps_per_role_in_order(self):
        self.assertEqual(sk.STEPS, ("shadow", "dark", "base", "light"))
        self.assertEqual(len(RAMP), 4 * len(PALETTE))
        for role, hexcol in PALETTE.items():
            base = sk.hex_rgb(hexcol)
            self.assertEqual(RAMP[role + ".base"], base)
            lum = [sk.luma(RAMP["%s.%s" % (role, s)]) for s in sk.STEPS]
            self.assertEqual(lum, sorted(lum), role)
            self.assertEqual(RAMP[role + ".shadow"], tuple(round(c * 0.42) for c in base))
            self.assertEqual(RAMP[role + ".dark"], tuple(round(c * 0.68) for c in base))
            self.assertEqual(RAMP[role + ".light"], tuple(round(c + (255 - c) * 0.28) for c in base))

    def test_quantizer_snaps_to_ramp(self):
        rows = [[(201, 100, 50, 255), (10, 200, 10, 0)]]
        out = sk.quantize_rows(rows, RAMP)
        self.assertIn(out[0][0][:3], set(RAMP.values()))
        self.assertEqual(out[0][0][3], 255)
        self.assertEqual(out[0][1], (0, 0, 0, 0))
        exact = sk.quantize_rows([[(*DARK, 255)]], RAMP)[0][0]
        self.assertEqual(exact[:3], DARK)

    def test_downsample_alpha_cut(self):
        solid = (200, 100, 50, 255)
        none = (0, 0, 0, 0)
        # a 2x2 cell with 2 of 4 samples opaque is exactly 50%: opaque, colour is the opaque colour
        out = sk.downsample([[solid, none], [solid, none]], 2)
        self.assertEqual(out, [[(200, 100, 50, 255)]])
        out = sk.downsample([[solid, none], [none, none]], 2)
        self.assertEqual(out, [[(0, 0, 0, 0)]])

    def test_outline_and_sheet_helpers(self):
        rows = blank(5, 5)
        rows[2][2] = (*BASE, 255)
        out = sk.add_outline(rows, (1, 2, 3))
        self.assertEqual(out[2][1], (1, 2, 3, 255))
        self.assertEqual(out[1][1], (0, 0, 0, 0))
        self.assertEqual(len(sk.stack_rows([rows, rows, rows])), 15)
        w, h, canvas = sk.preview_rows([rows, rows], 4)
        self.assertEqual(len(canvas), h)
        self.assertEqual(len(canvas[0]), w)
        self.assertEqual(sk.opaque_count(rows), 1)


class SpriteValidate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.vdir, self.params = new_version(self.tmp.name)

    def check(self, frames, **kw):
        result = write_sheet(self.vdir, frames, **kw)
        return run_validate(self.vdir, self.params, result)

    def test_positive_control(self):
        checks = self.check([good_frame() for _ in range(4)])
        self.assertEqual({k: c["detail"] for k, c in checks.items() if c["state"] == "fail"}, {})
        for cid in ("frames", "frame_band", "requested_size", "requested_directions", "alpha", "ramp", "content", "pivot"):
            self.assertEqual(checks[cid]["state"], "pass", cid)
        self.assertTrue(fc.score(list(checks.values()))["passed"])

    def test_seeded_off_ramp_pixel(self):
        frames = [good_frame() for _ in range(4)]
        frames[1][10][10] = (255, 0, 255, 255)
        checks = self.check(frames)
        self.assertEqual(checks["ramp"]["state"], "fail")

    def test_seeded_semi_transparent_pixels(self):
        frames = [good_frame() for _ in range(4)]
        frames[3][10][10] = (*BASE, 140)
        self.assertEqual(self.check(frames)["alpha"]["state"], "fail")

    def test_seeded_sheet_does_not_divide_into_frames(self):
        frames = [good_frame() for _ in range(4)]
        rows = [r for f in frames for r in f][:-5]       # 123 rows: not a whole number of 32 px frames
        self.assertEqual(self.check(frames, rows=rows)["frames"]["state"], "fail")
        wide = [r + [(0, 0, 0, 0)] * 8 for f in frames for r in f]   # 40 px wide: not whole 32 px frames
        self.assertEqual(self.check(frames, rows=wide)["frames"]["state"], "fail")
        three = [r for f in frames[:3] for r in f]        # 3 frames of art, json says 4
        self.assertEqual(self.check(frames, rows=three)["frames"]["state"], "fail")

    def test_seeded_wrong_frame_count_and_size(self):
        frames = [good_frame() for _ in range(2)]
        checks = self.check(frames, n=2)
        self.assertEqual(checks["requested_directions"]["state"], "fail")
        frames = [good_frame(48) for _ in range(4)]
        checks = self.check(frames, fw=48, fh=48)
        self.assertEqual(checks["requested_size"]["state"], "fail")
        frames = [good_frame(128) for _ in range(4)]
        checks = self.check(frames, fw=128, fh=128)
        self.assertEqual(self.params["band"], [16, 96])
        self.assertEqual(checks["frame_band"]["state"], "fail")

    def test_seeded_empty_frame_and_missing_pivot(self):
        frames = [good_frame(), blank(32, 32), good_frame(), good_frame()]
        self.assertEqual(self.check(frames)["content"]["state"], "fail")
        frames = [good_frame() for _ in range(4)]
        result = write_sheet(self.vdir, frames)
        meta = json.loads((self.vdir / "out" / "test_sp.json").read_text())
        del meta["pivot"]
        (self.vdir / "out" / "test_sp.json").write_text(json.dumps(meta))
        self.assertEqual(run_validate(self.vdir, self.params, result)["pivot"]["state"], "fail")

    def test_failed_build_and_missing_outputs(self):
        self.assertEqual(run_validate(self.vdir, self.params, {"status": "recipe_error", "error": "x"})["build"]["state"], "fail")
        self.assertEqual(run_validate(self.vdir, self.params, {"status": "ok"})["outputs"]["state"], "fail")

    def test_requested_parsing(self):
        self.assertEqual(validate.requested("A 4-direction 64px icon"), {"size": 64, "directions": 4})
        self.assertEqual(validate.requested("an 8 direction 32 px sprite"), {"size": 32, "directions": 8})
        self.assertEqual(validate.requested("48x48 icon"), {"size": 48})
        self.assertEqual(validate.requested("a crate"), {})


class SpriteBlender(unittest.TestCase):
    """The real harness: the scrap crate GLB as the source model, through the sandbox."""

    def run_recipe(self, root, recipe, name="test_sp", prompt="A 4-direction 32px icon of the crate"):
        os.environ["FORGE_HOME"] = str(root)
        vdir, params = forge.prepare_version(PACK, fc.load_kind("sprite"), name, "prop", prompt, reference=CRATE_GLB, preview=True)
        (vdir / "recipe.py").write_text(recipe)
        return vdir, forge.do_run(vdir, timeout=300, quiet=True)

    @needs_blender
    def test_crate_sheet_end_to_end(self):
        with tempfile.TemporaryDirectory() as root:
            vdir, rc = self.run_recipe(root, 'SPRITE = {"size": 32, "directions": 4, "fit": "tight"}\n')
            val = json.loads((vdir / "validate.json").read_text())
            self.assertEqual(rc, 0, [c for c in val["checks"] if c["state"] == "fail"])
            self.assertGreaterEqual(len(val["checks"]), 10)
            w, h, rows = pngio.read(vdir / "out" / "test_sp_sheet.png")
            self.assertEqual((w, h), (32, 128))
            self.assertEqual(sum(1 for r in rows for p in r if p[3] not in (0, 255)), 0)
            self.assertTrue((vdir / "preview" / "sheet.png").is_file())

    @needs_blender
    def test_bad_config_is_a_recipe_fault(self):
        with tempfile.TemporaryDirectory() as root:
            vdir, rc = self.run_recipe(root, 'SPRITE = {"size": 64, "directions": 5}\n')
            self.assertEqual(rc, 1)
            self.assertEqual(json.loads((vdir / "result.json").read_text())["status"], "recipe_error")

    @needs_blender
    def test_promote_writes_png_json_and_sidecar(self):
        with tempfile.TemporaryDirectory() as root:
            vdir, rc = self.run_recipe(root, 'SPRITE = {"size": 32, "directions": 4, "fit": "tight"}\n')
            self.assertEqual(rc, 0)
            os.environ["FORGE_REPO"] = root
            try:
                pack = fc.load_pack("core-loop")
                params = fc.read_json(vdir / "params.json")
                written = promote.promote(vdir, params, pack, fc.read_json(vdir / "manifest.json", {}), False)
                self.assertEqual(sorted(p.name for p in written), ["test_sp.forge.json", "test_sp.json", "test_sp_sheet.png"])
                side = fc.read_json(written[-1])
                self.assertIn("reference_glb_sha256", side)
                with self.assertRaises(SystemExit):
                    promote.promote(vdir, params, pack, {}, False)
            finally:
                del os.environ["FORGE_REPO"]


if __name__ == "__main__":
    unittest.main()
