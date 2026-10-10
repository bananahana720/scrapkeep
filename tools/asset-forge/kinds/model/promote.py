"""Model promoter: GLB + provenance manifest into the pack's models dir, recipe made
standalone into the pack's recipes dir."""
import json
import shutil
import sys
import textwrap
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402

FOOTER = '''

def _render(root, outdir):
    import math
    from mathutils import Vector
    pts = [o.matrix_world @ Vector(c) for o in common.tree(root) if o.type == "MESH" for c in o.bound_box]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    half = 0.5 * math.dist(lo, hi)
    dist = max(1.0, half * 1.4 / math.sin(math.radians(15)))
    views = [("eye", dist, 0.30, 30, (384, 384)), ("high", dist, 0.95, 30, (384, 384))]
    common.render_turntable(root, NAME, outdir, views, ground_z=0.0, target=(0, 0, (lo[2] + hi[2]) / 2))


def main():
    common.reset()
    a = common.args()
    root = build(PARAMS)
    common.export(root, a["out"] or common.default_out(NAME))
    if a["render"]:
        _render(root, a["render"])


main()
'''


def standalone_recipe(asset, version, params, recipe_src):
    # Colours and slots come from common.py when the recipe runs; a frozen copy here would go
    # stale the next time the palette changes (it did: ancient blue became uranium green).
    keep = {k: v for k, v in params.items()
            if k not in ("helper_dir", "inspect_script", "preview", "palette", "slot_specs", "slots", "profile")}
    header = textwrap.dedent('''\
        # %(asset)s: promoted from the asset forge (tools/asset-forge), pack %(pack)s, %(version)s.
        # Provenance: authored by a model-written Blender recipe from the prompt in the sidecar
        # %(asset)s.forge.json; built only from common.py primitives, no external assets.
        # Run: systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \\
        #   blender -b --factory-startup -P %(asset)s.py -- [--out file.glb] [--render dir]

        import json
        import os
        import sys

        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

        NAME = %(asset)r
        PARAMS = json.loads(%(params)r)

        # ---- recipe as written by the forge agent ----
        ''') % {"asset": asset, "pack": params["pack"], "version": version, "params": json.dumps(keep, sort_keys=True)}
    return header + recipe_src.rstrip() + "\n" + FOOTER


def promote(vdir, params, pack, manifest, force=False):
    vdir = Path(vdir)
    asset = params["asset"]
    models = Path(pack["repo_root"]) / pack["promote"]["model"]["models"]
    recipes = Path(pack["repo_root"]) / pack["promote"]["model"]["recipes"]
    glb_dst = models / (asset + ".glb")
    recipe_dst = recipes / (asset + ".py")
    side_dst = models / (asset + ".forge.json")
    for p in (glb_dst, recipe_dst):
        if p.exists() and not force:
            raise SystemExit("forge: %s already exists; pass --force to replace it" % p)
    models.mkdir(parents=True, exist_ok=True)
    recipes.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(vdir / "out" / (asset + ".glb"), glb_dst)
    recipe_dst.write_text(standalone_recipe(asset, vdir.name, params, (vdir / "recipe.py").read_text()))
    repo = Path(pack["repo_root"])
    side = {
        "schema_version": 1,
        "asset": asset,
        "glb": glb_dst.name,
        "glb_sha256": fc.sha256_file(glb_dst),
        "source": {"recipe": str(recipe_dst.relative_to(repo)),
                   "forge_version": "%s/%s/%s" % (params["pack"], asset, vdir.name),
                   "recipe_sha256": fc.sha256_file(recipe_dst)},
        "creator": "%s through tools/asset-forge, commissioned by Andrew" % (", ".join(manifest.get("model_used") or [manifest.get("model_requested") or "model"])),
        "license_evidence": "Original locally generated procedural geometry; no external meshes, textures or scans; no public license grant.",
        "transformations": ["Blender %s recipe build, glTF export with canonical triangle order" % manifest.get("blender", "")],
        "actual_use": "core-loop sketch %s" % params["category"],
        "prompt_sha256": manifest.get("prompt_sha256"),
        "concept_sha256": manifest.get("concept_sha256"),
        "validate_score": manifest.get("validate_score"),
        "triangle_band": params["band"],
    }
    fc.write_json(side_dst, side)
    return [glb_dst, recipe_dst, side_dst]
