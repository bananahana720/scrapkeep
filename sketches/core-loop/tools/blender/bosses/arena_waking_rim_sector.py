"""Curved release rim for the Waking's existing 36 m floor radius. No collision.

Run: blender -b --python tools/blender/bosses/arena_waking_rim_sector.py
"""
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "dig_mechanical"))
from kit import Surface, common, gltf_metrics

MODELS = HERE.parents[2] / "assets/models/bosses"
NAME = "arena_waking_rim_sector"


def main():
    common.reset()
    root = common.empty(NAME)
    surface = Surface("ReleaseRim", "steel")
    angles = [math.radians(.06 + i * 14.88 / 6) for i in range(7)]
    profile = [(35.3, 0), (36, 0), (36, -.65), (35.3, -.65), (35.3, 0)]
    rings = [lambda a, r=r, y=y: (r * math.sin(a), y, -r * math.cos(a)) for r, y in profile]
    surface.rings(rings, angles, palette=lambda r, i: "bone" if r == 2 else "petrol")
    surface.finish(root)
    path = MODELS / (NAME + ".glb")
    common.export(root, str(path))
    metrics = gltf_metrics(path)
    assert metrics["triangles"] <= 270 and metrics["vertices"] <= 610 and metrics["draws"] == 1, metrics
    row = {
        "id": path.name, "path": "res://assets/models/bosses/" + path.name,
        "class": "prop", "ships": True,
        "loader": "src/presentation/arena_waking_dress.gd:_load_parts",
        "provenance": {"recipe": "tools/blender/bosses/" + NAME + ".py", "source": "authored curved casting following the Dig steel slot"},
        "recipe": "tools/blender/bosses/" + NAME + ".py", "budget_row": "prop",
        "material_slots": ["steel"], "root": NAME, "parts": ["ReleaseRim"],
        "collision": False, "units": "metres, Godot +Y up, -Z forward",
        "assembly": {"repeat": 24, "yaw_step_degrees": 15, "radius": 36, "height": .65},
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), **metrics,
    }
    (MODELS / "arena_waking.registry-fragment.json").write_text(json.dumps({"schema": "scrapkeep-arena-waking/1", "assets": [row]}, indent=2, sort_keys=True) + "\n")
    print("ARW_EXPORT: PASS " + json.dumps(metrics, sort_keys=True))


if __name__ == "__main__":
    main()
