"""Headless probes and validation of an existing kit output. Never regenerates it."""
import argparse
from dataclasses import replace
import json
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy
import kit
import generate


def verify(output):
    limits = generate.memory_scope()
    checks = []
    fit = kit.Fit(**kit.FIXTURES["broad"])
    kit.clear()
    invalid = [("width", 0), ("depth", -1), ("height", float("nan")), ("neck", float("inf")), ("width", True), ("width", 5), ("eye_fraction", -0.1), ("eye_fraction", float("nan")), ("tuft_count", 4), ("tuft_count", 14), ("tuft_count", 7.5), ("seed", -1), ("seed", True), ("neck", 1.5), ("neck", 0.1)]
    for field, value in invalid:
        try:
            kit.build(fit=replace(fit, **{field: value}))
        except ValueError:
            assert not bpy.data.objects, "Invalid input mutated the scene"
        else:
            raise AssertionError(f"Accepted invalid {field}: {value}")
    for fixture, lod in (("unknown", "detailed"), ("broad", "unknown")):
        try:
            kit.build(fixture, lod)
        except ValueError:
            assert not bpy.data.objects
        else:
            raise AssertionError("Accepted unknown fixture/LOD")
    checks.append("17 invalid parameter/enum cases reject before scene mutation")
    probe = bpy.data.collections.new("BoundaryProbe")
    bpy.context.scene.collection.children.link(probe)
    for radii in ((0.05, 0.1, 0.05), (0.1, 0.05, 0.06)):
        try:
            kit.band(probe, "InvalidBand", (0, 0, 0), radii[0], radii[1], 0.1, radii[2], 12, "metal")
        except ValueError:
            assert not probe.objects
        else:
            raise AssertionError("Band accepted a zero or negative inner radius")
    kit.clear()
    boundary, _ = kit.build(fit=replace(fit, neck=0.12))
    body = boundary.objects["Collar.Body"]
    assert min(math.hypot(v.co.x, v.co.y) for v in body.data.vertices) > 0
    kit.clear()
    checks.append("minimum neck produces positive collar inner radii; invalid standalone bands reject")
    with tempfile.TemporaryDirectory(prefix="asset-kit-probe-") as temp:
        root = Path(temp)
        existing = root / "existing"
        existing.mkdir()
        marker = existing / "marker.bin"
        marker.write_bytes(b"do not overwrite")
        for target in (existing, marker):
            try:
                generate.reserve_output(target)
            except FileExistsError:
                assert marker.read_bytes() == b"do not overwrite"
            else:
                raise AssertionError("Output collision accepted")
        collision = subprocess.run([
            "systemd-run", "--user", "--scope", "-p", "MemoryMax=20G", "-p", "MemorySwapMax=2G",
            bpy.app.binary_path, "--background", "--factory-startup", "--python-exit-code", "1",
            "--python", str(HERE / "generate.py"), "--", "--output", str(existing),
        ], capture_output=True, text=True, timeout=30)
        assert collision.returncode == 1, collision.stdout + collision.stderr
        assert "Output already exists; nothing changed" in collision.stdout + collision.stderr
        assert marker.read_bytes() == b"do not overwrite"
        assert list(existing.iterdir()) == [marker]
        alias = root / "alias"
        alias.symlink_to(existing, target_is_directory=True)
        dangling = root / "dangling"
        dangling.symlink_to(root / "missing")
        for target in (alias, dangling):
            try:
                generate.reserve_output(target)
            except FileExistsError:
                pass
            else:
                raise AssertionError("Symlink collision accepted")
    checks.append("directory/file/symlink/dangling output collisions preserve bytes; actual capped Blender generation exits 1 for an existing output")
    expected = {}
    for fixture in kit.FIXTURES:
        for lod in kit.LODS:
            measurements = []
            for repetition in range(2):
                kit.clear()
                random.seed(repetition + 91)
                for _ in range(100):
                    random.random()
                collection, _ = kit.build(fixture, lod)
                measured = kit.geometry(collection)
                for obj in collection.objects:
                    assert obj.type == "MESH" and not obj.modifiers and not obj.constraints
                    assert all(math.isfinite(x) for v in obj.data.vertices for x in v.co)
                    edges = {}
                    for face in obj.data.polygons:
                        assert face.area > 0, obj.name
                        ids = list(face.vertices)
                        for a, b in zip(ids, ids[1:] + ids[:1]):
                            edge = tuple(sorted((a, b)))
                            edges[edge] = edges.get(edge, 0) + 1
                    assert all(n == 2 for n in edges.values()), obj.name
                measurements.append(measured)
            assert measurements[0] == measurements[1], "Geometry changed with global random state"
            expected[f"{fixture}-{lod}"] = measurements[0]
        assert expected[f"{fixture}-reduced"]["triangles"] < expected[f"{fixture}-detailed"]["triangles"]
    checks.append("four assemblies reproduce exact geometry fingerprints across unrelated global RNG states")
    checks.append("all generated components have finite vertices, nonzero faces and closed two-face edge incidence")
    manifest = json.loads((output / "manifest.json").read_text())
    assert len(manifest["assemblies"]) == 4
    for name, sha in manifest["sources"].items():
        assert generate.digest(HERE / name) == sha, f"Source hash changed: {name}"
    before = {name: generate.digest(output / name) for name in manifest["files"]}
    assert before == manifest["files"], "Artifact hash mismatch"
    results = []
    for entry in manifest["assemblies"]:
        stem = f'{entry["fixture"]}-{entry["lod"]}'
        assert expected[stem]["geometry_sha256"] == entry["geometry_sha256"]
        bpy.ops.wm.open_mainfile(filepath=str(output / entry["blend"]))
        collections = [c for c in bpy.data.collections if c.name.startswith("Kit.")]
        assert len(collections) == 1
        collection = collections[0]
        assert all(obj.type == "MESH" for obj in bpy.data.objects), "Studio leaked into editable source"
        assert kit.geometry(collection) == expected[stem], "Saved editable geometry differs"
        assert sorted(o.name for o in collection.objects) == entry["components"]
        report = generate.inspect_glb(output / entry["glb"], entry["budget_triangles"])
        assert report["assembly"]["triangles"] == entry["exported_triangles"] == entry["triangles"]
        assert report["files"][0]["inventory"]["skins"] == 0
        assert report["files"][0]["inventory"]["animations"] == 0
        results.append({"assembly": stem, "triangles": entry["triangles"], "primitives": report["files"][0]["inventory"]["primitives"], "materials": report["files"][0]["inventory"]["materials"], "status": report["status"]})
    assert before == {name: generate.digest(output / name) for name in manifest["files"]}, "Verification modified an artifact"
    checks.append("four saved blends reopen with exact separate editable geometry")
    checks.append("four actual GLBs independently pass AT-01 budgets and have no skins/animations")
    checks.append("all source/artifact hashes match and output bytes survive verification")
    print("ASSET_KIT_VERIFIED", json.dumps({"checks": checks, "assemblies": results, "memory_scope": limits}, sort_keys=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    verify(args.output.resolve())
