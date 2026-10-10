"""Asset forge tests. Run: python3 -m unittest discover -s tools/asset-forge -p 'test_*.py' -v
(or python3 tools/asset-forge/test_forge.py). unittest exits 5 when it selects no tests.
Cases marked Blender run recipes through `forge run` (needs blender and bwrap)."""
import json
import os
import shutil
import struct
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "kinds" / "model"))
import forge  # noqa: E402
import forgecore as fc  # noqa: E402
import pngio  # noqa: E402
import validate as model_validate  # noqa: E402

HAVE_BLENDER = shutil.which("blender") is not None and shutil.which("bwrap") is not None
needs_blender = unittest.skipUnless(HAVE_BLENDER, "blender and bwrap required")

HEADER = "import bpy\nimport common\nfrom common import Part\n\n"
GOOD = HEADER + '''
def build(params):
    root = common.empty("Crate")
    p = Part("Body")
    p.box("paint", (1.0, 0.8, 0.5), loc=(0, 0, 0.25), color="oxide")
    p.box("bare_metal", (1.04, 0.84, 0.06), loc=(0, 0, 0.03))
    p.ico("paint", 0.25, 3, loc=(0, 0, 0.5), color=common.mix("petrol", "sandstone", 0.35))
    p.to_object((0, 0, 0), root)
    return root
'''


def recipe(**swap):
    """GOOD with textual substitutions to seed one defect."""
    s = GOOD
    for a, b in swap.items():
        key = {"magenta": 'color="oxide")', "sunk": "loc=(0, 0, 0.25)", "big": "0.25, 3,", "sphere_loc": "loc=(0, 0, 0.5)"}[a]
        assert key in s, a
        s = s.replace(key, b, 1)
    return s


def pack():
    return fc.load_pack("core-loop")


def make_version(root, recipe_src, asset="test_asset", category="prop"):
    os.environ["FORGE_HOME"] = str(root)
    p = pack()
    kind = fc.load_kind("model")
    vdir, params = forge.prepare_version(p, kind, asset, category, "test prompt", preview=False)
    (vdir / "recipe.py").write_text(recipe_src)
    return vdir, params


def tiny_glb(path, tris=1, names=("paint",)):
    """A valid GLB with `tris` triangles in one primitive per material name."""
    pos = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
    prims, accessors, views, blob = [], [], [], b""
    for i, _ in enumerate(names):
        idx = struct.pack("<%dH" % (tris * 3), *([0, 1, 2] * tris))
        views += [{"buffer": 0, "byteOffset": len(blob), "byteLength": len(pos)}]
        blob += pos
        accessors.append({"bufferView": len(views) - 1, "componentType": 5126, "count": 3, "type": "VEC3", "max": [1, 1, 0], "min": [0, 0, 0]})
        pa = len(accessors) - 1
        pad = (-len(blob)) % 4
        blob += b"\0" * pad
        views += [{"buffer": 0, "byteOffset": len(blob), "byteLength": len(idx)}]
        blob += idx
        blob += b"\0" * ((-len(blob)) % 4)
        accessors.append({"bufferView": len(views) - 1, "componentType": 5123, "count": tris * 3, "type": "SCALAR"})
        prims.append({"attributes": {"POSITION": pa}, "indices": len(accessors) - 1, "material": i})
    g = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
         "meshes": [{"primitives": prims}], "accessors": accessors, "bufferViews": views,
         "buffers": [{"byteLength": len(blob)}], "materials": [{"name": n} for n in names]}
    j = json.dumps(g).encode()
    j += b" " * ((-len(j)) % 4)
    total = 12 + 8 + len(j) + 8 + len(blob)
    Path(path).write_bytes(b"glTF" + struct.pack("<II", 2, total) + struct.pack("<I", len(j)) + b"JSON" + j
                           + struct.pack("<I", len(blob)) + b"BIN\0" + blob)


def good_result(**over):
    m = {"triangles": 344, "triangles_by_object": {}, "objects": ["Crate"], "bounds_min": [-0.5, -0.4, 0.0],
         "bounds_max": [0.5, 0.4, 0.75], "size": [1.0, 0.8, 0.75], "center_xy": [0.0, 0.0], "lowest_z": 0.0,
         "root_origin": [0, 0, 0], "islands": 2, "floating": [], "nonmanifold_edges": 0, "edges": 100,
         "area_by_slot": {"paint": 3.0, "bare_metal": 1.0}, "vertex_colour_area": {"paint": {"9b513a": 3.0}},
         "unslotted_area": 0.0, "unknown_materials": []}
    m.update(over)
    return {"schema_version": 1, "status": "ok", "warnings": [], "measure": m, "blender": "test"}


class Synthetic(unittest.TestCase):
    """Validator cases on synthetic measurements and a hand-built GLB: no Blender."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        os.environ["FORGE_HOME"] = str(self.tmp)
        self.pack = pack()
        self.params = forge.build_params(self.pack, fc.load_kind("model"), "test_asset", "prop", preview=False)
        self.params["inspect_script"] = ""
        (self.tmp / "out").mkdir()
        tiny_glb(self.tmp / "out" / "test_asset.glb", tris=344)

    def run_validate(self, result):
        return {c["id"]: c for c in model_validate.validate(self.tmp, self.params, result, self.pack)}

    def test_good_passes(self):
        checks = self.run_validate(good_result())
        self.assertFalse([c for c in checks.values() if c["state"] == "fail"], checks)
        v = fc.score(list(checks.values()))
        self.assertEqual((v["score"], v["passed"]), (10, True))

    def test_seeded_off_palette_fails(self):
        r = good_result(vertex_colour_area={"paint": {"ff00ff": 1.0, "9b513a": 2.0}})
        self.assertEqual(self.run_validate(r)["palette_colours"]["state"], "fail")

    def test_palette_mix_passes_and_tiny_stray_warns(self):
        mix = fc.palette_distance("7a7e66", pack_hexes := self.params["palette"].values())
        self.assertLess(mix, 0.05)  # a midpoint of petrol and sandstone-ish stays on palette
        r = good_result(vertex_colour_area={"paint": {"9b513a": 999.0, "ff00ff": 1.0}})
        self.assertEqual(self.run_validate(r)["palette_colours"]["state"], "warn")

    def test_seeded_over_band_fails(self):
        tiny_glb(self.tmp / "out" / "test_asset.glb", tris=2000)
        self.assertEqual(self.run_validate(good_result(triangles=2000))["triangle_band"]["state"], "fail")

    def test_under_band_fails(self):
        tiny_glb(self.tmp / "out" / "test_asset.glb", tris=10)
        self.assertEqual(self.run_validate(good_result(triangles=10))["triangle_band"]["state"], "fail")

    def test_seeded_floating_fails(self):
        r = good_result(floating=[{"object": "Orb", "min": [0, 0, 2.0], "max": [1, 1, 2.5]}])
        self.assertEqual(self.run_validate(r)["floating_parts"]["state"], "fail")

    def test_seeded_sunk_fails_and_raised_fails(self):
        self.assertEqual(self.run_validate(good_result(lowest_z=-0.15))["grounding"]["state"], "fail")
        self.assertEqual(self.run_validate(good_result(lowest_z=0.2))["grounding"]["state"], "fail")
        self.assertEqual(self.run_validate(good_result(lowest_z=0.004))["grounding"]["state"], "pass")

    def test_off_centre_states(self):
        self.assertEqual(self.run_validate(good_result(center_xy=[0.15, 0.0]))["centred"]["state"], "warn")
        self.assertEqual(self.run_validate(good_result(center_xy=[1.0, 0.0]))["centred"]["state"], "fail")

    def test_unknown_material_and_unslotted_fail(self):
        self.assertEqual(self.run_validate(good_result(unknown_materials=["Material"]))["palette_slots"]["state"], "fail")
        self.assertEqual(self.run_validate(good_result(unslotted_area=2.0))["palette_slots"]["state"], "fail")

    def test_non_manifold_and_size_and_draw_calls(self):
        self.assertEqual(self.run_validate(good_result(nonmanifold_edges=3))["non_manifold"]["state"], "warn")
        self.assertEqual(self.run_validate(good_result(size=[100.0, 1, 1]))["size"]["state"], "fail")
        self.assertEqual(self.run_validate(good_result(size=[12.0, 1, 1]))["size"]["state"], "warn")
        tiny_glb(self.tmp / "out" / "test_asset.glb", tris=344, names=("paint",) * 13)
        self.assertEqual(self.run_validate(good_result())["draw_calls"]["state"], "warn")

    def test_build_error_short_circuits(self):
        r = {"status": "recipe_error", "error": "Traceback...\nNameError: x"}
        checks = self.run_validate(r)
        self.assertEqual(list(checks), ["build"])
        self.assertEqual(checks["build"]["state"], "fail")

    def test_score_capped_by_worst_state(self):
        c = lambda s: fc.check("x", s, None, "")  # noqa: E731
        self.assertEqual(fc.score([c("pass")] * 5)["score"], 10)
        self.assertEqual(fc.score([c("warn")])["score"], 8)  # capped at 8 even if arithmetic says 9
        self.assertLessEqual(fc.score([c("fail")])["score"], 4)
        self.assertFalse(fc.score([c("fail")])["passed"])
        self.assertEqual(fc.score([c("fail")] * 5)["score"], 0)
        self.assertTrue(fc.score([c("warn"), c("info")])["passed"])

    def test_glb_readback(self):
        info = fc.glb_info(self.tmp / "out" / "test_asset.glb")
        self.assertEqual((info["triangles"], info["draw_calls"], info["nodes"]), (344, 1, 1))


class Setup(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        os.environ["FORGE_HOME"] = str(self.tmp)

    def test_version_allocation(self):
        a = fc.alloc_version("core-loop", "thing")
        b = fc.alloc_version("core-loop", "thing")
        c = fc.alloc_version("core-loop", "other")
        self.assertEqual((a.name, b.name, c.name), ("v001", "v002", "v001"))
        self.assertEqual(fc.versions("core-loop", "thing"), [1, 2])
        self.assertEqual(fc.version_dir("core-loop", "thing", "2").name, "v002")
        (a.parent / "v010").mkdir()
        self.assertEqual(fc.alloc_version("core-loop", "thing").name, "v011")

    def test_pack_parsing(self):
        p = pack()
        self.assertEqual(p["bands"]["model"]["prop"], [150, 1500])
        self.assertTrue(p["sketch_path"].is_dir())
        self.assertTrue(p["palette_source_path"].is_file())
        self.assertTrue((p["helper_dir_path"] / "common.py").is_file())
        self.assertIn("promote", p)

    def test_unknown_pack_exits(self):
        with self.assertRaises(SystemExit):
            fc.load_pack("nope")

    def test_palette_parsing(self):
        gd = fc.parse_palette(pack()["palette_source_path"])
        self.assertEqual(gd["SAND"], "d2c5a5")
        self.assertEqual(gd["VERDIGRIS"], "365754")
        self.assertGreaterEqual(len(gd), 11)
        roles = fc.pack_palette(pack())
        self.assertEqual(roles["bone"], "d2c5a5")
        self.assertEqual(roles["petrol"], "365754")
        self.assertIn("ice", roles)  # extension from the helper's HEX

    def test_palette_matches_helper_mirror(self):
        self.assertEqual(fc.palette_drift(pack()), {})

    def test_palette_regex_on_synthetic_text(self):
        f = self.tmp / "p.gd"
        f.write_text('const A := Color("#AABBCC")\nconst B = Color("112233")\nvar x := Color("ffffff")\n')
        self.assertEqual(fc.parse_palette(f), {"A": "aabbcc", "B": "112233"})

    def test_slots_parse_without_importing_bpy(self):
        slots = fc.pack_slots(pack())
        self.assertIn("paint", slots)
        self.assertIn("bare_metal", slots)
        self.assertEqual(len(slots), 12)

    def test_kind_discovery(self):
        self.assertIn("model", fc.kind_names())
        k = fc.load_kind("model")
        for key in ("entry", "brief", "validator", "promoter", "runner", "bands_key"):
            self.assertIn(key, k)
        with self.assertRaises(SystemExit):
            fc.load_kind("nonexistent")

    def test_new_kind_dir_is_discovered(self):
        kd = self.tmp / "kinds"
        (kd / "terrain").mkdir(parents=True)
        (kd / "terrain" / "kind.toml").write_text('name = "terrain"\n')
        self.assertEqual(fc.kind_names(kd), ["terrain"])

    def test_system_prompt_has_all_parts(self):
        sp = forge.system_prompt(pack(), fc.load_kind("model"))
        self.assertIn("python3 %s run ." % forge.FORGE_PY, sp)
        self.assertIn("front faces -Y", sp.replace("The front faces -Y", "front faces -Y"))
        self.assertIn("## 2. Palette roles", sp)
        self.assertIn("## 9. Hero asset briefs", sp)
        self.assertIn("## 10. Reviewer checklist", sp)

    def test_agent_command_is_locked_down(self):
        cmd = forge.agent_command(self.tmp, "sonnet", 40, 3.0)
        self.assertIn("--restricted", cmd)
        self.assertIn("--strict-mcp-config", cmd)
        self.assertEqual(cmd[cmd.index("--setting-sources") + 1], "")
        allowed = cmd[cmd.index("--allowedTools") + 1:cmd.index("--disallowedTools")]
        self.assertEqual(allowed, ["Read", "Write", "Edit", "Bash(python3 %s run .)" % forge.FORGE_PY])
        self.assertEqual(cmd[cmd.index("--permission-mode") + 1], "dontAsk")
        self.assertEqual(cmd[cmd.index("--model") + 1], "sonnet")
        self.assertIn("--max-turns", cmd)

    def test_bash_gate_allows_only_the_exact_run(self):
        import subprocess
        allowed = "python3 %s run ." % forge.FORGE_PY

        def decide(command):
            event = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
            out = subprocess.run([sys.executable, str(fc.FORGE_DIR / "bash_gate.py"), allowed], input=event,
                                 capture_output=True, text=True, check=True).stdout
            return json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else "pass"

        self.assertEqual(decide(allowed), "pass")
        background = json.dumps({"tool_name": "Bash", "tool_input": {"command": allowed, "run_in_background": True}})
        out = subprocess.run([sys.executable, str(fc.FORGE_DIR / "bash_gate.py"), allowed], input=background,
                             capture_output=True, text=True, check=True).stdout
        self.assertEqual(json.loads(out)["hookSpecificOutput"]["permissionDecision"], "deny")
        for evil in ("ls /", allowed + " && ls /", allowed + "; ls", allowed + "\nls /", "FOO=1 " + allowed,
                     allowed.replace("python3", "./python3"), allowed + " --x", "cat recipe.py", allowed + " | sh"):
            self.assertEqual(decide(evil), "deny", evil)

    def test_sweep_removes_links_and_special_files(self):
        d = self.tmp / "v"
        (d / "out").mkdir(parents=True)
        (d / "out" / "ok.glb").write_text("x")
        (d / "run.log").symlink_to("/etc/hostname")
        (d / "linkdir").symlink_to("/etc")
        os.mkfifo(d / "out" / "pipe")
        self.assertEqual(sorted(fc.sweep(d)), ["linkdir", "out/pipe", "run.log"])
        self.assertTrue((d / "out" / "ok.glb").is_file())
        self.assertIsNone(fc.read_json(d / "missing.json"))

    def test_sweep_sees_inside_dirs_the_recipe_made_unreadable(self):
        d = self.tmp / "v"
        (d / "out").mkdir(parents=True)
        (d / "out" / "effect.tscn").symlink_to(self.tmp / "victim")
        os.chmod(d / "out", 0o300)
        os.chmod(d, 0o300)
        self.assertEqual(fc.sweep(d), ["out/effect.tscn"])
        self.assertFalse((d / "out" / "effect.tscn").is_symlink())

    def test_sweep_clears_dirs_planted_at_forge_output_names(self):
        d = self.tmp / "v"
        (d / "result.json" / "x").mkdir(parents=True)
        (d / "out" / "result.json").mkdir(parents=True)
        self.assertEqual(fc.sweep(d), ["result.json"])
        self.assertTrue((d / "out" / "result.json").is_dir())  # only top-level names are reserved

    def test_inflate_refuses_bombs_and_huge_headers(self):
        import zlib
        bomb = zlib.compress(bytes(10_000_000))
        with self.assertRaises(ValueError):
            pngio.inflate(bomb, 16, 16, 4)
        with self.assertRaises(ValueError):
            pngio.inflate(b"", 100_000, 1, 4)
        ok = zlib.compress(bytes(4 * (1 + 4 * 3)))
        self.assertEqual(len(pngio.inflate(ok, 4, 4, 3)), 4 * (1 + 4 * 3))

    def test_write_json_replaces_a_link_instead_of_following_it(self):
        victim = self.tmp / "victim.txt"
        victim.write_text("precious")
        link = self.tmp / "result.json"
        link.symlink_to(victim)
        fc.write_json(link, {"a": 1})
        self.assertEqual(victim.read_text(), "precious")
        self.assertFalse(link.is_symlink())

    def test_refuses_to_run_without_bwrap(self):
        real = shutil.which
        try:
            shutil.which = lambda name: None if name == "bwrap" else real(name)
            prefix, notes = forge.sandbox_prefix(self.tmp, [], "forge-test.scope")
        finally:
            shutil.which = real
        self.assertIsNone(prefix)
        self.assertIn("refuses", notes[0])

    def test_prepare_version_files_and_revision(self):
        p, k = pack(), fc.load_kind("model")
        ref = self.tmp / "c.png"
        ref.write_bytes(b"png")
        v1, params = forge.prepare_version(p, k, "thing", "prop", "make a thing", reference=ref)
        for f in ("prompt.md", "params.json", "system_prompt.md", "reference/common.py", "reference/concept.png"):
            self.assertTrue((v1 / f).is_file(), f)
        (v1 / "recipe.py").write_text("# v1\n")
        (v1 / "preview").mkdir()
        (v1 / "preview" / "sheet.png").write_bytes(b"sheet")
        v2, params2 = forge.prepare_version(p, k, "thing", "prop", "add a lid", parent=v1)
        self.assertEqual((v2 / "recipe.py").read_text(), "# v1\n")
        self.assertEqual((v2 / "reference" / "previous.png").read_bytes(), b"sheet")
        self.assertEqual(params2["parent_version"], "v001")
        self.assertEqual(params["band"], [150, 1500])
        self.assertIn("ancient_light", params["slots"])

    def test_manifest_fields(self):
        p, k = pack(), fc.load_kind("model")
        ref = self.tmp / "c.png"
        ref.write_bytes(b"png")
        v1, params = forge.prepare_version(p, k, "thing", "prop", "make a thing", reference=ref)
        (v1 / "recipe.py").write_text("# r\n")
        forge.merge_manifest(v1, model_requested="sonnet", claude_cli_version="2.1.296 (Claude Code)")
        fc.write_json(v1 / "agent.json", {"modelUsage": {"claude-sonnet-5-5": {}}})
        fc.write_json(v1 / "validate.json", {"score": 9, "state": "warn"})
        m = forge.write_manifest(v1, params, p, k)
        for key in ("schema_version", "kind", "pack", "asset", "version", "prompt_sha256", "concept_sha256", "model_requested",
                    "model_used", "claude_cli_version", "parent_version", "validate_score", "sources", "files", "agent_command"):
            self.assertIn(key, m)
        self.assertEqual(m["schema_version"], 1)
        self.assertEqual(m["prompt_sha256"], fc.sha256_text("make a thing\n"))
        self.assertEqual(m["concept_sha256"], fc.sha256_text("png"))
        self.assertEqual(m["model_used"], ["claude-sonnet-5-5"])
        self.assertEqual(m["validate_score"], 9)
        self.assertEqual(len(m["sources"]["recipe.py"]), 64)

    def test_list_runs_on_empty_and_populated(self):
        self.assertEqual(forge.main(["list"]), 0)
        forge.prepare_version(pack(), fc.load_kind("model"), "thing", "prop", "p")
        self.assertEqual(forge.main(["list"]), 0)

    def test_bad_asset_name_rejected(self):
        with self.assertRaises(SystemExit):
            forge.main(["make", "model", "--name", "Bad Name", "--dry-agent", "x"])

    def test_promote_refuses_unvalidated(self):
        v1, _ = forge.prepare_version(pack(), fc.load_kind("model"), "thing", "prop", "p")
        with self.assertRaises(SystemExit):
            forge.main(["promote", "thing", "v001"])


@needs_blender
class BlenderRuns(unittest.TestCase):
    """Real builds through `forge run`, one Blender at a time."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def run_recipe(self, src, **kw):
        vdir, params = make_version(self.tmp, src, **kw)
        rc = forge.do_run(vdir, timeout=120, quiet=True)
        return rc, vdir, {c["id"]: c for c in fc.read_json(vdir / "validate.json")["checks"]}

    def test_good_recipe_passes(self):
        rc, vdir, checks = self.run_recipe(GOOD)
        self.assertEqual(rc, 0, checks)
        self.assertEqual(fc.read_json(vdir / "validate.json")["score"], 10)
        self.assertTrue((vdir / "out" / "test_asset.glb").is_file())
        self.assertTrue((vdir / "out" / "test_asset.blend").is_file())
        self.assertEqual(fc.read_json(vdir / "manifest.json")["schema_version"], 1)

    def test_seeded_off_palette_colour_fails(self):
        rc, _, checks = self.run_recipe(recipe(magenta='color=(1.0, 0.0, 1.0))'))
        self.assertEqual(rc, 1)
        self.assertEqual(checks["palette_colours"]["state"], "fail", checks)

    def test_seeded_over_band_mesh_fails(self):
        rc, _, checks = self.run_recipe(recipe(big="0.25, 5,"))
        self.assertEqual(rc, 1)
        self.assertEqual(checks["triangle_band"]["state"], "fail", checks)

    def test_seeded_floating_part_fails(self):
        rc, _, checks = self.run_recipe(recipe(sphere_loc="loc=(0, 0, 2.5)"))
        self.assertEqual(rc, 1)
        self.assertEqual(checks["floating_parts"]["state"], "fail", checks)

    def test_seeded_sunk_model_fails(self):
        src = GOOD.replace("loc=(0, 0, 0.25)", "loc=(0, 0, 0.1)").replace("loc=(0, 0, 0.03)", "loc=(0, 0, -0.12)")
        rc, _, checks = self.run_recipe(src)
        self.assertEqual(rc, 1)
        self.assertEqual(checks["grounding"]["state"], "fail", checks)

    def test_recipe_exception_is_exit_1_with_traceback(self):
        rc, vdir, checks = self.run_recipe(HEADER + "def build(params):\n    raise ValueError('boom')\n")
        self.assertEqual(rc, 1)
        self.assertIn("boom", fc.read_json(vdir / "result.json")["error"])

    def test_timeout_is_recipe_fault_and_result_written(self):
        vdir, _ = make_version(self.tmp, HEADER + "def build(params):\n    while True:\n        pass\n")
        rc = forge.do_run(vdir, timeout=20, quiet=True)
        self.assertEqual(rc, 1)
        self.assertIn("timed out", fc.read_json(vdir / "result.json")["error"])

    def test_same_recipe_same_glb_sha256(self):
        vdir, _ = make_version(self.tmp, GOOD)
        shas = []
        for _ in range(2):
            self.assertEqual(forge.do_run(vdir, timeout=120, quiet=True), 0)
            shas.append(fc.sha256_file(vdir / "out" / "test_asset.glb"))
        print("determinism sha256 pair:", shas)
        self.assertEqual(shas[0], shas[1])

    def test_sandbox_blocks_network_and_stray_writes(self):
        probe = self.tmp / "outside.txt"
        src = HEADER + '''
import json, os, socket

def build(params):
    out = {}
    try:
        socket.create_connection(("1.1.1.1", 80), timeout=5)
        out["network"] = "CONNECTED"
    except OSError as e:
        out["network"] = "blocked: %r" % e
    for name, path in (("sibling_of_version_dir", os.path.join(os.path.dirname(os.getcwd()), "escape.txt")), ("outside_tmp", PROBE_PATH), ("home", os.path.expanduser("~/forge_probe.txt"))):
        try:
            open(path, "w").write("x")
            out[name] = "WROTE"
        except OSError as e:
            out[name] = "blocked: %r" % e
    try:
        out["home_listing"] = len(os.listdir(os.path.expanduser("~")))
    except OSError as e:
        out["home_listing"] = repr(e)
    out["run_dir"] = os.path.exists("/run/user")
    out["env"] = sorted(os.environ)
    try:
        s = socket.socket(socket.AF_UNIX)
        s.connect("/run/user/%d/bus" % os.getuid())
        out["user_bus"] = "CONNECTED"
    except OSError as e:
        out["user_bus"] = "blocked: %r" % e
    # Plant links the unsandboxed forge would otherwise write or read through.
    for name, target in (("run.log", LOG_TARGET), ("notes.md", LOG_TARGET), ("out/leak.glb", "/etc/hostname")):
        os.makedirs(os.path.dirname(name) or ".", exist_ok=True)
        if os.path.lexists(name):
            os.unlink(name)
        os.symlink(target, name)
    open("probe.json", "w").write(json.dumps(out))
    root = common.empty("Probe")
    p = Part("P")
    p.box("paint", (1, 1, 1), loc=(0, 0, 0.5), color="oxide")
    p.to_object((0, 0, 0), root)
    return root
'''.replace("PROBE_PATH", repr(str(probe)))
        victim = self.tmp / "andrews_file.txt"
        victim.write_text("precious\n")
        src = src.replace("LOG_TARGET", repr(str(victim)))
        vdir, _ = make_version(self.tmp, src)
        os.environ["FORGE_SECRET_PROBE"] = "must-not-leak"
        try:
            rc = forge.do_run(vdir, timeout=120, quiet=True)
        finally:
            del os.environ["FORGE_SECRET_PROBE"]
        got = fc.read_json(vdir / "probe.json")
        print("sandbox probe:", got)
        self.assertTrue(got["network"].startswith("blocked"), got)
        self.assertTrue(got["user_bus"].startswith("blocked"), got)
        self.assertFalse(got["run_dir"], got)
        # Blender adds its own variables (OCIO, PWD, ...); nothing from the caller may pass.
        self.assertNotIn("FORGE_SECRET_PROBE", got["env"])
        self.assertFalse([k for k in got["env"] if k.startswith(("ANTHROPIC", "CLAUDE", "XDG_RUNTIME", "DBUS", "SSH"))], got)
        # The planted links are swept, the run is a recipe fault, and nothing outside changed.
        self.assertEqual(rc, 1)
        self.assertEqual(victim.read_text(), "precious\n")
        res = fc.read_json(vdir / "result.json")
        self.assertEqual(res["status"], "recipe_error")
        self.assertIn("run.log", res["error"])
        for name in ("run.log", "notes.md", "out/leak.glb"):
            self.assertFalse((vdir / name).is_symlink(), name)
        forge.do_run(vdir, timeout=120, quiet=True)  # the next outer run writes run.log afresh
        self.assertEqual(victim.read_text(), "precious\n")
        # Writes outside the version dir may succeed inside the sandbox's private tmpfs but
        # must never reach the real filesystem.
        self.assertFalse(Path(vdir.parent / "escape.txt").exists())
        self.assertFalse(probe.exists())  # the write landed in the sandbox's private /tmp
        self.assertFalse(Path.home().joinpath("forge_probe.txt").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
