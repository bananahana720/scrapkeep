"""Pixel kind tests. Run: python3 -m unittest discover -s tools/asset-forge -p 'test_*.py' -v
Validator cases build a version directory by hand (no Blender); the entry runs under plain
python3 here, which is the same code Blender's interpreter runs. Seeded defects must FAIL."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import forge  # noqa: E402
import forgecore as fc  # noqa: E402
import pngio  # noqa: E402

validate = fc.load_module(HERE / "kinds" / "pixel" / "validate.py", "pixel_validate")
pixkit = fc.load_module(HERE / "kinds" / "pixel" / "pixkit.py", "pixkit_under_test")
promote = fc.load_module(HERE / "kinds" / "pixel" / "promote.py", "pixel_promote")

PACK = fc.load_pack("core-loop")
PALETTE = fc.pack_palette(PACK)
pixkit.set_palette(PALETTE)
RAMP = pixkit.sk.build_ramp(PALETTE)
BASE = RAMP["oxide.base"]
LIGHT = RAMP["oxide.light"]
DARK = RAMP["oxide.dark"]

COIN = '''import pixkit as px


def build(params):
    frames = []
    for rx in (6, 4, 2, 4):
        c = px.Canvas(16, 16)
        c.ellipse(7.5, 7.5, rx, 6.5, "amber")
        c.ellipse(7.5 - 1, 7.5 - 1, max(rx - 2, 1), 4.5, "amber.light")
        c.outline()
        frames.append(c)
    return frames
'''


def new_version(root, prompt="A 16x16 coin, 4-frame spin", category="prop"):
    os.environ["FORGE_HOME"] = str(root)
    vdir, params = forge.prepare_version(PACK, fc.load_kind("pixel"), "test_px", category, prompt, preview=False)
    return vdir, params


def write_out(vdir, rows, fw, fh, n, meta_extra=None, status="ok"):
    (vdir / "out").mkdir(exist_ok=True)
    pngio.write(vdir / "out" / "test_px.png", len(rows[0]), len(rows), rows)
    meta = {"frame_width": fw, "frame_height": fh, "frames": n}
    meta.update(meta_extra or {})
    (vdir / "out" / "test_px.json").write_text(json.dumps(meta))
    return {"status": status, "warnings": []}


def strip(frames):
    """Frames (rows lists) side by side."""
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


def blank(w, h):
    return [[(0, 0, 0, 0)] * w for _ in range(h)]


def good_frame(w=16, h=16):
    f = blank(w, h)
    for y in range(3, h - 4):
        for x in range(3, w - 4):
            f[y][x] = (*BASE, 255)
    for x, y, col in ((4, 4, LIGHT), (10, 10, DARK), (7, 2, BASE)):  # the last one breaks every block alignment
        if x < w and y < h:
            f[y][x] = (*col, 255)
    return f


def run_validate(vdir, params, result):
    return {c["id"]: c for c in validate.validate(vdir, params, result, PACK)}


class PixKit(unittest.TestCase):
    def test_colour_specs(self):
        self.assertEqual(pixkit.key("oxide"), "oxide.base")
        self.assertEqual(pixkit.key(("oxide", 3)), "oxide.light")
        self.assertEqual(pixkit.key("oxide.dark"), "oxide.dark")
        self.assertIsNone(pixkit.key(None))
        self.assertEqual(pixkit.shift_step("oxide", -1), "oxide.dark")
        self.assertEqual(pixkit.shift_step("oxide.shadow", -1), "oxide.shadow")
        for bad in ("nope", "oxide.pink", ("oxide", 4), ("oxide", -1)):
            with self.assertRaises(ValueError):
                pixkit.key(bad)

    def test_ramp_steps_and_order(self):
        sk = pixkit.sk
        r = sk.hex_rgb(PALETTE["oxide"])
        self.assertEqual(sk.shade(r, "base"), r)
        self.assertEqual(sk.shade(r, "shadow"), tuple(round(c * 0.42) for c in r))
        lum = [sk.luma(sk.shade(r, s)) for s in sk.STEPS]
        self.assertEqual(lum, sorted(lum), "steps must go dark to light")
        self.assertEqual(len(RAMP), 4 * len(PALETTE))

    def test_shapes(self):
        c = pixkit.Canvas(8, 8)
        c.rect(1, 1, 3, 2, "oxide")
        self.assertEqual(sum(v is not None for r in c.px for v in r), 6)
        c.rect(-5, -5, 3, 3, "oxide")  # fully off canvas: clipped, no error
        c = pixkit.Canvas(8, 8).line(0, 0, 7, 7, "oxide")
        self.assertTrue(all(c.px[i][i] == "oxide.base" for i in range(8)))
        d = pixkit.Canvas(16, 16).circle(7.5, 7.5, 5, "amber")
        self.assertEqual(d.px[8][8], "amber.base")
        self.assertEqual(d.px[0][0], None)
        self.assertEqual([d.px[y][x] for y in range(16) for x in range(16)].count("amber.base") % 4, 0, "even disc stays symmetric")
        f = pixkit.Canvas(5, 5).rect(0, 0, 5, 5, "oxide", filled=False).fill(2, 2, "amber")
        self.assertEqual(f.px[2][2], "amber.base")
        self.assertEqual(f.px[0][0], "oxide.base")

    def test_mirror_flip_shift(self):
        c = pixkit.Canvas(4, 2)
        c.put(0, 0, "oxide").put(1, 1, "amber")
        c.mirror_x()
        self.assertEqual(c.px[0], ["oxide.base", None, None, "oxide.base"])
        self.assertEqual(c.px[1], [None, "amber.base", "amber.base", None])
        c.flip_y()
        self.assertEqual(c.px[0][1], "amber.base")
        s = pixkit.Canvas(3, 1).put(2, 0, "oxide").shift(1, 0)
        self.assertEqual(s.px[0], [None, None, None])
        s = pixkit.Canvas(3, 1).put(2, 0, "oxide").shift(1, 0, wrap=True)
        self.assertEqual(s.px[0][0], "oxide.base")

    def test_outline_is_selective(self):
        c = pixkit.Canvas(5, 5).put(2, 2, "amber")
        c.outline()
        self.assertEqual(c.px[2][1], "amber.shadow")
        self.assertEqual(c.px[1][1], None, "no diagonal ring by default")
        c = pixkit.Canvas(5, 5).put(2, 2, "amber").outline("charcoal.shadow", diagonals=True)
        self.assertEqual(c.px[1][1], "charcoal.shadow")

    def test_dither(self):
        c = pixkit.Canvas(4, 4).rect(0, 0, 4, 4, "oxide.base")
        c.put(0, 0, None)
        c.dither(0, 0, 4, 4, "oxide.base", "oxide.light", level=0.5)
        self.assertIsNone(c.px[0][0], "transparency is kept")
        light = sum(v == "oxide.light" for r in c.px for v in r)
        self.assertTrue(7 <= light <= 8, light)
        c = pixkit.Canvas(4, 4).rect(0, 0, 4, 4, "oxide").dither(0, 0, 4, 4, "oxide", "amber", level=0)
        self.assertEqual(c.colours(), ["oxide.base"])

    def test_frames_contract(self):
        a, b = pixkit.Canvas(4, 4), pixkit.Canvas(4, 5)
        self.assertEqual(len(pixkit.as_frames(a)), 1)
        for bad in ([], [a, b], "x", [a, 3]):
            with self.assertRaises(ValueError):
                pixkit.as_frames(bad)
        with self.assertRaises(ValueError):
            pixkit.Canvas(0, 4)


class PixelValidate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.vdir, self.params = new_version(self.tmp.name)

    def check(self, rows, fw=16, fh=16, n=4, **kw):
        result = write_out(self.vdir, rows, fw, fh, n, **kw)
        return run_validate(self.vdir, self.params, result)

    def test_positive_control(self):
        frames = [good_frame() for _ in range(4)]
        for i, f in enumerate(frames):
            f[13][i + 2] = (*LIGHT, 255)
        checks = self.check(strip(frames))
        failing = {k: c["detail"] for k, c in checks.items() if c["state"] == "fail"}
        self.assertEqual(failing, {})
        for cid in ("frames", "alpha", "ramp", "content", "native_grid", "requested_size", "requested_frames", "canvas_band"):
            self.assertEqual(checks[cid]["state"], "pass", cid)
        self.assertTrue(fc.score(list(checks.values()))["passed"])

    def test_seeded_off_ramp_pixel(self):
        frames = [good_frame() for _ in range(4)]
        frames[2][5][5] = (200, 13, 99, 255)
        checks = self.check(strip(frames))
        self.assertEqual(checks["ramp"]["state"], "fail")
        self.assertEqual(checks["ramp"]["value"], 1)

    def test_seeded_semi_transparent(self):
        frames = [good_frame() for _ in range(4)]
        frames[0][5][5] = (*BASE, 128)
        self.assertEqual(self.check(strip(frames))["alpha"]["state"], "fail")

    def test_seeded_uniform_2x_upscale(self):
        small = [[(*BASE, 255) if (x + y) % 3 == 0 else (0, 0, 0, 0) for x in range(8)] for y in range(8)]
        small[0][1] = (*LIGHT, 255)
        big = [[small[y // 2][x // 2] for x in range(16)] for y in range(16)]
        checks = self.check(strip([big] * 4))
        self.assertEqual(checks["native_grid"]["state"], "fail")
        self.assertEqual(checks["native_grid"]["value"][0], (0, 2))
        self.assertFalse(fc.score(list(checks.values()))["passed"])
        # the same art authored natively at 1 px per cell passes
        native = [good_frame() for _ in range(4)]
        self.assertEqual(self.check(strip(native))["native_grid"]["state"], "pass")

    def test_seeded_wrong_canvas_size(self):
        frames = [good_frame(8, 8) for _ in range(4)]
        checks = self.check(strip(frames), fw=8, fh=8)
        self.assertEqual(checks["requested_size"]["state"], "fail")
        frames = [good_frame(16, 16) for _ in range(4)]
        checks = self.check(strip(frames), fw=16, fh=16, n=3)  # json claims 3 frames: strip is 64 wide
        self.assertEqual(checks["frames"]["state"], "fail")

    def test_seeded_wrong_frame_count_and_band(self):
        checks = self.check(strip([good_frame()] * 2), n=2)
        self.assertEqual(checks["requested_frames"]["state"], "fail")
        checks = self.check(strip([good_frame(200, 200)]), fw=200, fh=200, n=1)
        self.assertEqual(checks["canvas_band"]["state"], "fail")

    def test_seeded_unequal_strip(self):
        a, b = good_frame(), good_frame(16, 12)
        rows = [r + (b[y] if y < 12 else [(0, 0, 0, 0)] * 16) for y, r in enumerate(a)]
        # a 16x12 frame padded would be silently equal; instead make the strip too narrow
        checks = self.check([r[:-3] for r in rows], n=2)
        self.assertEqual(checks["frames"]["state"], "fail")

    def test_seeded_empty_frame(self):
        frames = [good_frame(), blank(16, 16), good_frame(), good_frame()]
        checks = self.check(strip(frames))
        self.assertEqual(checks["content"]["state"], "fail")
        self.assertEqual(checks["content"]["value"], [1])

    def test_colour_budget_warns(self):
        f = good_frame()
        keys = sorted(RAMP)[: self.params["max_draw_calls"] + 3]
        for i, k in enumerate(keys):
            f[12][i % 14 + 1] = (*RAMP[k], 255)
        frames = [f, good_frame(), good_frame(), good_frame()]
        states = self.check(strip(frames))["colour_budget"]["state"]
        self.assertEqual(states, "warn")

    def test_failed_build_and_missing_outputs(self):
        checks = run_validate(self.vdir, self.params, {"status": "recipe_error", "error": "boom"})
        self.assertEqual(checks["build"]["state"], "fail")
        checks = run_validate(self.vdir, self.params, {"status": "ok"})
        self.assertEqual(checks["outputs"]["state"], "fail")

    def test_upscale_detector_unit(self):
        flat = [[1] * 16 for _ in range(16)]
        self.assertGreater(validate.upscale_factor(flat), 1)
        noisy = [[(x * 7 + y * 3) % 5 for x in range(16)] for y in range(16)]
        self.assertEqual(validate.upscale_factor(noisy), 1)
        three = [[((x // 3) + (y // 3)) % 2 for x in range(12)] for y in range(12)]
        self.assertEqual(validate.upscale_factor(three), 3)


class PixelEntry(unittest.TestCase):
    """Runs the real entry.py under plain python3 on a real version directory."""

    def run_entry(self, root, recipe, prompt="A 16x16 coin, 4-frame spin"):
        vdir, params = new_version(root, prompt)
        (vdir / "recipe.py").write_text(recipe)
        proc = subprocess.run([sys.executable, "-I", str(HERE / "kinds" / "pixel" / "entry.py"), "--", str(vdir)],
                              capture_output=True, text=True, timeout=60)
        return vdir, params, proc

    def test_coin_end_to_end(self):
        with tempfile.TemporaryDirectory() as root:
            vdir, params, proc = self.run_entry(root, COIN)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            res = json.loads((vdir / "result.json").read_text())
            self.assertEqual(res["status"], "ok")
            w, h, _ = pngio.read(vdir / "out" / "test_px.png")
            self.assertEqual((w, h), (64, 16))
            pw, ph, _ = pngio.read(vdir / "preview" / "sheet.png")
            self.assertGreater(pw, 4 * 16 * 8)
            checks = run_validate(vdir, params, res)
            self.assertEqual([c for c in checks.values() if c["state"] == "fail"], [])
            self.assertGreaterEqual(len(checks), 10)
            # promote lands PNG + JSON + sidecar and refuses to overwrite
            os.environ["FORGE_REPO"] = root
            try:
                pack = fc.load_pack("core-loop")
                written = promote.promote(vdir, params, pack, {"model_requested": "sonnet"}, False)
                names = sorted(p.name for p in written)
                self.assertEqual(names, ["test_px.forge.json", "test_px.json", "test_px.png"])
                self.assertTrue(all(p.is_file() and str(p).startswith(root) for p in written))
                with self.assertRaises(SystemExit):
                    promote.promote(vdir, params, pack, {}, False)
                self.assertEqual(len(promote.promote(vdir, params, pack, {}, True)), 3)
            finally:
                del os.environ["FORGE_REPO"]

    def test_recipe_faults_exit_1(self):
        bad = {
            "no build": "x = 1\n",
            "off ramp colour": "import pixkit as px\ndef build(p):\n    return px.Canvas(4, 4).put(0, 0, 'ff00ff')\n",
            "unequal frames": "import pixkit as px\ndef build(p):\n    return [px.Canvas(4, 4), px.Canvas(5, 4)]\n",
            "syntax": "def build(:\n",
        }
        with tempfile.TemporaryDirectory() as root:
            for name, src in bad.items():
                vdir, _, proc = self.run_entry(root, src)
                self.assertEqual(proc.returncode, 1, name)
                self.assertEqual(json.loads((vdir / "result.json").read_text())["status"], "recipe_error", name)


if __name__ == "__main__":
    unittest.main()
