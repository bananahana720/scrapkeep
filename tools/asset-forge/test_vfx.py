"""VFX kind tests. Run: python3 -m unittest discover -s tools/asset-forge -p 'test_*.py' -v
Cases marked Godot need `godot`; cases marked Blender need `blender` and `bwrap` (the runner)."""
import copy
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
KIND = HERE / "kinds" / "vfx"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(KIND))
import forge  # noqa: E402
import forgecore as fc  # noqa: E402
import vfxsim  # noqa: E402
import vfxspec  # noqa: E402
import vfxtscn  # noqa: E402

vfx_validate = fc.load_module(KIND / "validate.py", "forge_test_vfx_validate")
vfx_promote = fc.load_module(KIND / "promote.py", "forge_test_vfx_promote")

HAVE_GODOT = shutil.which("godot") is not None
HAVE_BLENDER = shutil.which("blender") is not None and shutil.which("bwrap") is not None
needs_godot = unittest.skipUnless(HAVE_GODOT, "godot required")
needs_blender = unittest.skipUnless(HAVE_BLENDER, "blender and bwrap required")

GOOD = {"seed": 7, "emitters": [
    {"name": "shards", "amount": 16, "lifetime": 0.3, "spread": 80, "velocity": [4, 9], "mesh": "prism",
     "mesh_size": [0.08, 0.08, 0.2], "align_y": True,
     "color_ramp": [{"t": 0, "role": "bone"}, {"t": 0.3, "role": "amber"}, {"t": 1, "role": "oxide", "alpha": 0}]},
    {"name": "flash", "amount": 3, "lifetime": 0.12, "mesh": "quad", "blend": "add", "emissive": 1.5, "velocity": [0, 0.2],
     "mesh_size": [0.4, 0.4, 0.1], "scale": [1, 1.6], "shape": "sphere", "extents": [0.1, 0, 0],
     "color_ramp": [{"t": 0, "role": "bone"}, {"t": 1, "role": "amber", "alpha": 0}]}]}

RECIPE = "def build(params):\n    return %r\n" % (GOOD,)


def pack():
    return fc.load_pack("core-loop")


def palette():
    return fc.pack_palette(pack())


def good():
    return vfxspec.normalize(copy.deepcopy(GOOD))


def errors(spec):
    return vfxspec.validate(spec, set(palette()), budget=48, max_emitters=4)


def codes(spec):
    return {c for c, _ in errors(spec)}


class SpecChecks(unittest.TestCase):
    def test_good_spec_has_no_errors(self):
        self.assertEqual(errors(good()), [])

    def test_seeded_hex_colour_fails_palette(self):
        s = good()
        s["emitters"][0]["color_ramp"][0]["role"] = "#ff00ff"
        self.assertIn("palette", codes(s))

    def test_seeded_unknown_role_fails_palette(self):
        s = good()
        s["emitters"][0]["color_ramp"][1]["role"] = "magenta"
        self.assertIn("palette", codes(s))

    def test_seeded_over_budget_fails(self):
        s = good()
        s["emitters"][0]["amount"] = 49
        self.assertIn("budget", codes(s))
        s["emitters"][0]["amount"] = 45     # 45 + 3 = 48: exactly the budget passes
        self.assertEqual(codes(s), set())

    def test_seeded_too_many_emitters_fails(self):
        s = good()
        s["emitters"] = [dict(copy.deepcopy(s["emitters"][1]), name="e%d" % i, amount=1) for i in range(5)]
        self.assertIn("budget", codes(s))

    def test_seeded_invalid_field_and_type_fail(self):
        s = good()
        s["emitters"][0]["color"] = "red"
        self.assertIn("schema", codes(s))
        s = good()
        s["emitters"][0]["amount"] = "16"
        self.assertIn("schema", codes(s))
        s = good()
        s["emitters"][0]["one_shot"] = 1
        self.assertIn("schema", codes(s))
        s = good()
        s["emitters"][0]["mesh"] = "teapot"
        self.assertIn("schema", codes(s))
        s = good()
        s["gdscript"] = "OS.execute()"
        self.assertIn("schema", codes(s))

    def test_seeded_negative_lifetime_fails(self):
        s = good()
        s["emitters"][0]["lifetime"] = -0.3
        self.assertIn("lifetime", codes(s))
        s["emitters"][0]["lifetime"] = 2.5
        self.assertIn("lifetime", codes(s))

    def test_seeded_range_errors_fail(self):
        for field, value in (("spread", 200), ("velocity", [9, 4]), ("direction", [0, 0, 0]),
                             ("scale_curve", [[0, 1], [0, 0]]), ("gravity", [0, -90, 0]), ("explosiveness", 1.5)):
            s = good()
            s["emitters"][0][field] = value
            self.assertIn("range", codes(s), field)

    def test_missing_required_field_fails(self):
        s = good()
        del s["emitters"][0]["color_ramp"]
        self.assertIn("schema", codes(s))

    def test_nan_is_not_a_number(self):
        s = good()
        s["emitters"][0]["spread"] = float("nan")
        self.assertIn("schema", codes(s))

    def test_budget_matches_the_largest_vfx_burst(self):
        text = (fc.REPO / "sketches/core-loop/src/presentation/vfx.gd").read_text()
        import re
        biggest = max(int(m) for m in re.findall(r'"max": (\d+)', text))
        self.assertEqual(vfxspec.BUDGET, 2 * biggest)
        self.assertEqual(pack()["bands"]["vfx"]["prop"][1], vfxspec.BUDGET)


class Simulation(unittest.TestCase):
    def test_hash_known_values(self):
        """Pinned so a GDScript port can be checked against the same numbers."""
        self.assertEqual([vfxsim.mix32(v) for v in (0, 1, 2, 0xFFFFFFFF)], [0, 1753845952, 3507691905, 1734902346])
        self.assertAlmostEqual(vfxsim.rand(7, 0, 0, 0), 0.5493176183663309, places=12)
        self.assertAlmostEqual(vfxsim.rand(7, 1, 5, 3), 0.12135558715090156, places=12)

    def test_rand_in_unit_interval_and_stable(self):
        vals = [vfxsim.rand(7, 0, s, c) for s in range(50) for c in range(9)]
        self.assertTrue(all(0.0 <= v < 1.0 for v in vals))
        self.assertEqual(vals, [vfxsim.rand(7, 0, s, c) for s in range(50) for c in range(9)])
        self.assertNotEqual(vfxsim.rand(7, 0, 1, 0), vfxsim.rand(8, 0, 1, 0))
        self.assertAlmostEqual(sum(vals) / len(vals), 0.5, delta=0.05)

    def test_same_spec_same_seed_same_output(self):
        pal = palette()
        a = [vfxsim.frame(good(), pal, t / 20) for t in range(8)]
        b = [vfxsim.frame(copy.deepcopy(good()), pal, t / 20) for t in range(8)]
        self.assertEqual(a, b)
        self.assertGreater(sum(len(f) for f in a), 10)

    def test_seed_changes_output(self):
        pal = palette()
        other = good()
        other["seed"] = 8
        self.assertNotEqual(vfxsim.frame(good(), pal, 0.1), vfxsim.frame(other, pal, 0.1))

    def test_preview_bytes_identical(self):
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, True)
        digests = []
        for i in range(2):
            p = tmp / ("s%d.png" % i)
            vfxsim.write_strip(p, good(), palette())
            digests.append(hashlib.sha256(p.read_bytes()).hexdigest())
        self.assertEqual(digests[0], digests[1])
        w, h, rows = vfxsim.render_strip(good(), palette())
        self.assertEqual((w, h), (960, 160))
        painted = sum(1 for row in rows for px in row if px[:3] != vfxsim.BG)
        self.assertGreater(painted, 1500)       # particles and the ground ring are drawn

    def test_cloud_radius_tracks_physics(self):
        s = good()
        s["emitters"] = [s["emitters"][0]]
        s["emitters"][0].update(velocity=[10, 10], spread=0, gravity=[0, 0, 0], lifetime=1.0)
        self.assertAlmostEqual(vfxsim.cloud_radius(s, palette()), 10.0, delta=0.5)
        s["emitters"][0]["damping"] = [20, 20]          # stops after 0.5 s at 2.5 m
        self.assertAlmostEqual(vfxsim.cloud_radius(s, palette()), 2.5, delta=0.1)

    def test_one_shot_dies_and_loop_continues(self):
        pal = palette()
        s = good()
        self.assertEqual(vfxsim.frame(s, pal, 1.0), [])
        s["emitters"][0]["one_shot"] = False
        self.assertGreater(len(vfxsim.frame(s, pal, 1.0)), 0)


class Validator(unittest.TestCase):
    """validate.py on a hand-built version dir: no Blender, Godot only where noted."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        os.environ["FORGE_HOME"] = str(self.tmp)
        self.pack = pack()
        self.params = forge.build_params(self.pack, fc.load_kind("vfx"), "test_fx", "prop", preview=False)
        (self.tmp / "out").mkdir()
        (self.tmp / "preview").mkdir()
        vfxsim.write_strip(self.tmp / "preview" / "sheet.png", good(), palette())

    def run_validate(self, spec):
        (self.tmp / "out" / "effect.json").write_text(json.dumps(spec))
        res = {"status": "ok", "warnings": []}
        return {c["id"]: c for c in vfx_validate.validate(self.tmp, self.params, res, self.pack)}

    @needs_godot
    def test_good_passes_including_godot(self):
        checks = self.run_validate(good())
        self.assertFalse([c for c in checks.values() if c["state"] == "fail"], checks)
        self.assertEqual(checks["godot_load"]["state"], "pass", checks["godot_load"])
        self.assertIn("VFX_OK", checks["godot_load"]["detail"])

    def test_seeded_defects_fail_through_the_validator(self):
        def mutate(fn):
            s = good()
            fn(s)
            return s
        cases = {
            "palette_roles": mutate(lambda s: s["emitters"][0]["color_ramp"][0].update(role="#ff00ff")),
            "budget": mutate(lambda s: s["emitters"][0].update(amount=60)),
            "spec_schema": mutate(lambda s: s["emitters"][0].update(bogus=1)),
            "lifetime": mutate(lambda s: s["emitters"][0].update(lifetime=-1.0)),
        }
        for cid, spec in cases.items():
            checks = self.run_validate(spec)
            self.assertEqual(checks[cid]["state"], "fail", (cid, checks))
            self.assertFalse(fc.score(list(checks.values()))["passed"], cid)
            self.assertNotIn("godot_load", checks, cid)     # nothing is converted from a failed spec

    def test_cloud_too_wide_fails(self):
        s = good()
        s["emitters"][0].update(velocity=[20, 20], lifetime=1.0, gravity=[0, 0, 0])
        self.assertEqual(self.run_validate(s)["bounds"]["state"], "fail")

    def test_fine_sparkle_warns(self):
        s = good()
        for e in s["emitters"]:
            e["mesh_size"] = [0.02, 0.02, 0.02]
        self.assertEqual(self.run_validate(s)["chunkiness"]["state"], "warn")

    def test_failed_build_fails(self):
        res = {"status": "recipe_error", "error": "boom", "warnings": []}
        checks = vfx_validate.validate(self.tmp, self.params, res, self.pack)
        self.assertEqual(checks[0]["state"], "fail")

    def test_missing_spec_fails(self):
        res = {"status": "ok", "warnings": []}
        checks = {c["id"]: c for c in vfx_validate.validate(self.tmp, self.params, res, self.pack)}
        self.assertEqual(checks["spec_schema"]["state"], "fail")


class Converter(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.pal = palette()
        self.sketch = Path(pack()["sketch_path"])

    def convert(self, spec, edit=None):
        text = vfxtscn.to_tscn(spec, self.pal, "test_fx")
        if edit:
            a, b = edit
            self.assertIn(a, text)
            text = text.replace(a, b, 1)
        (self.tmp / "e.tscn").write_text(text)
        (self.tmp / "x.json").write_text(json.dumps(vfxtscn.expectations(spec, self.pal)))
        return vfx_validate.godot_check(self.tmp / "e.tscn", self.tmp / "x.json", self.sketch)

    def test_scene_text_is_deterministic_and_has_no_script(self):
        a = vfxtscn.to_tscn(good(), self.pal, "test_fx")
        self.assertEqual(a, vfxtscn.to_tscn(good(), self.pal, "test_fx"))
        self.assertNotIn("script", a.lower().replace("transparency", ""))
        self.assertNotIn("ext_resource", a)
        self.assertEqual(a.count("type=\"CPUParticles3D\""), 2)

    def test_expectations_resolve_palette_roles(self):
        exp = vfxtscn.expectations(good(), self.pal)["emitters"][0]
        self.assertEqual(exp["gradient_colors"][4:7], [0xe5 / 255, 0xa0 / 255, 0x44 / 255])   # amber, from palette.gd

    @needs_godot
    def test_spec_to_tscn_loads_in_godot_with_matching_properties(self):
        ok, text = self.convert(good())
        self.assertTrue(ok, text)
        self.assertIn("VFX_OK", text)
        self.assertIn("emitters=2 particles=19", text)

    @needs_godot
    def test_check_catches_a_tampered_scene(self):       # positive control: the check can fail
        for a, b in (("amount = 16", "amount = 17"), ("lifetime = 0.3", "lifetime = 0.9"),
                     ("0.898039, 0.627451, 0.266667", "1, 0, 1")):
            ok, text = self.convert(good(), (a, b))
            self.assertFalse(ok, (a, text))
            self.assertIn("VFX_FAIL", text)

    @needs_godot
    def test_every_mesh_shape_and_looping_emitter_load(self):
        for mesh in vfxspec.MESHES:
            for shape in vfxspec.SHAPES:
                s = good()
                s["emitters"][0].update(mesh=mesh, shape=shape, one_shot=False, damping=[1, 2],
                                        scale_curve=[[0, 0.5], [0.4, 1.5], [1, 0]])
                ok, text = self.convert(s)
                self.assertTrue(ok, (mesh, shape, text))


@needs_blender
class RunnerIntegration(unittest.TestCase):
    """The real `forge run` path: sandboxed entry, validator, Godot."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        os.environ["FORGE_HOME"] = str(self.tmp)

    def version(self, recipe_src):
        p = pack()
        vdir, params = forge.prepare_version(p, fc.load_kind("vfx"), "test_fx", "prop", "test prompt")
        (vdir / "recipe.py").write_text(recipe_src)
        return vdir

    def test_good_recipe_runs_and_validates(self):
        vdir = self.version(RECIPE)
        self.assertEqual(forge.do_run(vdir, 120, quiet=True), 0)
        val = fc.read_json(vdir / "validate.json")
        self.assertTrue(val["passed"], val)
        self.assertTrue((vdir / "preview" / "sheet.png").is_file())
        self.assertEqual(fc.read_json(vdir / "result.json")["measure"]["particles"], 19)
        first = fc.sha256_file(vdir / "preview" / "sheet.png")
        self.assertEqual(forge.do_run(vdir, 120, quiet=True), 0)
        self.assertEqual(first, fc.sha256_file(vdir / "preview" / "sheet.png"))

    def test_seeded_bad_recipes_fail_with_a_message(self):
        bad = {
            "hex": RECIPE.replace("'role': 'amber'", "'role': '#ffaa00'"),
            "budget": RECIPE.replace("'amount': 16", "'amount': 90"),
            "negative": RECIPE.replace("'lifetime': 0.3", "'lifetime': -0.3"),
            "raises": "def build(params):\n    raise ValueError('nope')\n",
            "not_json": "def build(params):\n    return {'seed': object()}\n",
        }
        for name, src in bad.items():
            vdir = self.version(src)
            self.assertEqual(forge.do_run(vdir, 120, quiet=True), 1, name)
            res = fc.read_json(vdir / "result.json")
            self.assertEqual(res["status"], "recipe_error", name)
            self.assertFalse((vdir / "out" / "effect.tscn").exists(), name)

    def test_promote_writes_scene_spec_preview_and_sidecar(self):
        vdir = self.version(RECIPE)
        self.assertEqual(forge.do_run(vdir, 120, quiet=True), 0)
        dest_root = self.tmp / "repo"
        p = dict(pack(), repo_root=str(dest_root))
        params = fc.read_json(vdir / "params.json")
        written = vfx_promote.promote(vdir, params, p, fc.read_json(vdir / "manifest.json", {}), False)
        names = sorted(Path(w).name for w in written)
        self.assertEqual(names, ["effect.json", "effect.tscn", "preview.png", "recipe.py", "test_fx.forge.json"])
        with self.assertRaises(SystemExit):
            vfx_promote.promote(vdir, params, p, {}, False)
        vfx_promote.promote(vdir, params, p, {}, True)


class Registration(unittest.TestCase):
    def test_kind_and_pack_tables(self):
        self.assertIn("vfx", fc.kind_names())
        k, p = fc.load_kind("vfx"), pack()
        for table in ("bands", "sizes", "draw_calls"):
            self.assertIn(k["bands_key"], p[table])
            self.assertIn(p["default_category"], p[table][k["bands_key"]])
        self.assertIn("vfx", p["promote"])
        for f in (k["entry"], k["brief"], k["validator"], k["promoter"]):
            self.assertTrue((k["dir"] / f).is_file(), f)


if __name__ == "__main__":
    unittest.main()
