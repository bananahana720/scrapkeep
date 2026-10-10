"""VFX promoter: effect.tscn, the spec, the preview strip and a provenance sidecar into
<pack promote.vfx.vfx>/<asset>/."""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402


def promote(vdir, params, pack, manifest, force=False):
    vdir = Path(vdir)
    asset = params["asset"]
    repo = Path(pack["repo_root"])
    dest = repo / pack["promote"]["vfx"]["vfx"] / asset
    files = {"effect.tscn": vdir / "out" / "effect.tscn", "effect.json": vdir / "out" / "effect.json",
             "recipe.py": vdir / "recipe.py"}
    preview = vdir / "preview" / "sheet.png"
    for name, src in files.items():
        if not src.is_file():
            raise SystemExit("forge: %s is missing; run `forge run` first" % src)
    if dest.exists() and any(dest.iterdir()) and not force:
        raise SystemExit("forge: %s already exists; pass --force to replace it" % dest)
    dest.mkdir(parents=True, exist_ok=True)
    written = []
    for name, src in files.items():
        shutil.copyfile(src, dest / name)
        written.append(dest / name)
    if preview.is_file():
        previews = repo / pack["previews"]
        previews.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(preview, previews / (asset + "_preview.png"))
        written.append(previews / (asset + "_preview.png"))
    side = dest / (asset + ".forge.json")
    fc.write_json(side, {
        "schema_version": 1,
        "asset": asset,
        "scene": "effect.tscn",
        "scene_sha256": fc.sha256_file(dest / "effect.tscn"),
        "source": {"spec": "effect.json", "spec_sha256": fc.sha256_file(dest / "effect.json"),
                   "recipe": "recipe.py", "forge_version": "%s/%s/%s" % (params["pack"], asset, vdir.name)},
        "creator": "%s through tools/asset-forge, commissioned by Andrew" % (", ".join(manifest.get("model_used") or [manifest.get("model_requested") or "model"])),
        "license_evidence": "Original locally generated particle spec; palette roles only; no external assets; no public license grant.",
        "transformations": ["spec validated, converted to a Godot text scene by the forge converter, loaded headless in Godot"],
        "actual_use": "core-loop sketch vfx (%s)" % params["category"],
        "prompt_sha256": manifest.get("prompt_sha256"),
        "validate_score": manifest.get("validate_score"),
        "particle_budget": params["band"],
        "limits": "preview is a Python simulation, not an in-engine render",
    })
    written.append(side)
    return written
