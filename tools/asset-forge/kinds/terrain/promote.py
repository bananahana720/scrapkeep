"""Terrain promoter: the five maps, the preview sheet, the recipe and a provenance sidecar into
<textures dir>/<asset>/, plus a .tres regenerated here from tres.py (the sandbox's copy is
recipe-controllable and is never promoted)."""
import math
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from tres import PLACEHOLDER, tres_text  # noqa: E402
MAPS = ("albedo", "normal", "roughness", "ao", "height")


def res_folder(pack, textures_dir):
    sketch = Path(pack["repo_root"]) / pack["sketch"]
    return "res://" + Path(textures_dir).relative_to(sketch).as_posix()


def promote(vdir, params, pack, manifest, force=False):
    vdir = Path(vdir)
    asset = params["asset"]
    repo = Path(pack["repo_root"])
    textures = repo / pack["promote"]["terrain"]["textures"]
    dst = textures / asset
    tres_dst = dst / (asset + ".tres")
    if tres_dst.exists() and not force:
        raise SystemExit("forge: %s already exists; pass --force to replace it" % tres_dst)
    dst.mkdir(parents=True, exist_ok=True)
    written = []
    for m in MAPS:
        src = vdir / "out" / ("%s_%s.png" % (asset, m))
        shutil.copyfile(src, dst / src.name)
        written.append(dst / src.name)
    try:
        uv = float((fc.read_json(vdir / "result.json") or {}).get("uv_scale", 1.0))
    except (TypeError, ValueError):
        uv = 1.0
    if not (math.isfinite(uv) and 0 < uv <= 64):
        uv = 1.0
    tres_dst.write_text(tres_text(asset, uv_scale=uv).replace(PLACEHOLDER, res_folder(pack, textures)))
    written.append(tres_dst)
    sheet = vdir / "preview" / "sheet.png"
    if sheet.is_file():
        shutil.copyfile(sheet, dst / (asset + "_preview.png"))
        written.append(dst / (asset + "_preview.png"))
    recipe_dst = dst / (asset + ".recipe.py")
    recipe_dst.write_text(
        "# %s: promoted from the asset forge (tools/asset-forge), pack %s, %s.\n"
        "# Run inside Blender's Python with tools/asset-forge/kinds/terrain on sys.path (texlib.py);\n"
        "# the forge's terrain entry calls build(params) and writes the maps. Original procedural code.\n\n"
        % (asset, params["pack"], vdir.name) + (vdir / "recipe.py").read_text())
    written.append(recipe_dst)
    side = {
        "schema_version": 1,
        "asset": asset,
        "kind": "terrain",
        "material": tres_dst.name,
        "files": {p.name: fc.sha256_file(p) for p in written},
        "source": {"recipe": str(recipe_dst.relative_to(repo)),
                   "forge_version": "%s/%s/%s" % (params["pack"], asset, vdir.name),
                   "texlib_sha256": fc.sha256_file(Path(__file__).with_name("texlib.py"))},
        "creator": "%s through tools/asset-forge, commissioned by Andrew" % (", ".join(manifest.get("model_used") or [manifest.get("model_requested") or "model"])),
        "license_evidence": "Original locally generated procedural textures; no external images, scans or texture packs; no public license grant.",
        "transformations": ["Blender %s Python (numpy) recipe build, wrapped noise only, palette ramps" % manifest.get("blender", "")],
        "actual_use": "core-loop sketch ground material",
        "prompt_sha256": manifest.get("prompt_sha256"),
        "validate_score": manifest.get("validate_score"),
        "resolution": (fc.read_json(vdir / "result.json", {}).get("measure") or {}).get("size"),
        "normal_convention": "OpenGL (Y+), Godot",
    }
    side_dst = dst / (asset + ".forge.json")
    fc.write_json(side_dst, side)
    written.append(side_dst)
    return written
