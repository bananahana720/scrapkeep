"""Serial headless build, manifest and byte-identity check. No GPU or git writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import struct
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/dig_stone"
ROOT = SKETCH.parents[1]
PREVIEW = ROOT / "artifacts/local/dress-preview/MDS"
NAMES = ("cut_face_long", "cut_face_scoop", "rubble_cluster", "breach_socket", "bed_floor", "bed_cut", "bed_rubble", "bed_recess")
PARTS = ("CutFace", "CutScoop", "Rubble", "SocketCut", "FloorStudy", "CutStudy", "RubbleStudy", "RecessStudy")


def limit():
    resource.setrlimit(resource.RLIMIT_AS, (8 * 1024 ** 3, 8 * 1024 ** 3))


def run_recipe(name, path):
    command = ["blender", "-b", "--factory-startup", "--threads", "2", "--python-exit-code", "1", "--python", str(HERE / (name + ".py")), "--", "--out", str(path)]
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=180, preexec_fn=limit)
    print(result.stdout, end="", flush=True)
    if result.returncode:
        print(result.stderr, flush=True)
        raise SystemExit(result.returncode)


def glb_info(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    triangles, vertices, draws = 0, 0, 0
    low, high = [float("inf")] * 3, [float("-inf")] * 3
    for mesh in doc["meshes"]:
        for p in mesh["primitives"]:
            a = doc["accessors"][p["attributes"]["POSITION"]]
            vertices += a["count"]
            triangles += doc["accessors"][p["indices"]]["count"] // 3
            draws += 1
            low = [min(low[k], a["min"][k]) for k in range(3)]
            high = [max(high[k], a["max"][k]) for k in range(3)]
    sockets = {n["name"]: n.get("translation", [0, 0, 0]) for n in doc["nodes"] if n["name"].startswith("socket_")}
    return {"file": path.name, "root": path.stem, "nodes": [n["name"] for n in doc["nodes"]],
            "sockets": sockets, "material_slots": [m["name"] for m in doc["materials"]],
            "bounds_min": low, "bounds_max": high, "bounds_size": [high[k] - low[k] for k in range(3)],
            "triangles": triangles, "exported_vertices": vertices, "surfaces": draws,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rerun-check", action="store_true")
    opt = parser.parse_args()
    MODELS.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, part in zip(NAMES, PARTS):
        path = MODELS / (name + ".glb")
        run_recipe(name, path)
        row = glb_info(path)
        row.update({"part": part, "budget_row": "landform", "caps": {"triangles": 8000, "imported_vertices": 24000, "surfaces": 1},
                    "origin": "membrane centre at nominal top Y=0" if name == "breach_socket" else "bottom-centre",
                    "static_pivot": [0, 0, 0], "collision": False, "clips": []})
        assert row["triangles"] <= (600 if name == "rubble_cluster" else 8000)
        assert row["exported_vertices"] <= 24000 and row["surfaces"] == 1
        rows.append(row)
    manifest = {"schema": "scrapkeep-dig-stone/1", "unit": "MDS", "frame": "+Y up, +X right, -Z forward, metres",
                "material": "res://assets/materials/dig_stone/stone.tres",
                "shared_bed_source": "515f919:assets/shaders/target_bed4.gdshaderinc (unmerged input, vendored verbatim in recipe directory)",
                "bed_thickness_table_m": [1.7, 0.8, 2.6, 1.1, 0.6, 2.1, 1.4, 0.9],
                "bed_seed": 3, "bed_widen": 1.0, "assets": rows,
                "integration_notes": [
                    "No runtime loader, placement, registry, collision or gameplay change is supplied.",
                    "Admit the unmerged shared-bed method explicitly; align terrain material parameters before claiming bed continuity.",
                    "GLB stone is a neutral fallback. Its Color channel contains grayscale wear only, never per-piece coloured albedo beds. Override with the single shared stone.tres after import.",
                    "cut_face_long is buried 0.25 m during placement; origins remain authored bottom-centre.",
                    "Studies are look references; never tile them as walkable islands. Actual terrain remains authoritative.",
                    "breach_socket follows the 8x1x8 m KD surround with open 6 m throat. It is an offline study, not a support fitted to the P-R6 12x12 / 14x10 gameplay rectangles. Wiring owner must reconcile the surround footprint; never scale it blindly or plug the throat.",
                    "socket_landing_preview is a preview-only reference, not an approved gameplay landing.",
                    "Suggested bed_recess hollow instance parameter: [3.6,-0.8,0.75,3.2]; use only off-route.",
                    "CPU preview uses the same eight bed thicknesses in a Blender world-position material; its lighting and procedural tone are an offline approximation, not Godot renderer evidence."]}
    (MODELS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if opt.rerun_check:
        with tempfile.TemporaryDirectory(prefix="mds-rerun-") as temp:
            for row in rows:
                name = Path(row["file"]).stem
                target = Path(temp) / row["file"]
                run_recipe(name, target)
                assert hashlib.sha256(target.read_bytes()).hexdigest() == row["sha256"], name + " differs on rerun"
                print("MDS_REPRO %s: identical %s" % (name, row["sha256"]), flush=True)
        print("MDS_REPRO: PASS (8/8 byte-identical GLBs)", flush=True)


if __name__ == "__main__":
    main()
