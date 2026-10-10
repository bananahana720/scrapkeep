"""Sprite promoter: the sheet PNG, its JSON and a provenance sidecar into
<pack promote.sprite.sprites>/<asset>/. The pixel kind reuses promote_files()."""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402


def promote_files(vdir, params, pack, manifest, force, files, extra, key):
    """Copies `files` (names under out/) to the pack's sprite dir and writes the sidecar."""
    vdir = Path(vdir)
    asset = params["asset"]
    repo = Path(pack["repo_root"])
    dest = repo / pack["promote"][key]["sprites"] / asset
    side_dst = dest / (asset + ".forge.json")
    for name in files + [side_dst.name]:
        if (dest / name).exists() and not force:
            raise SystemExit("forge: %s already exists; pass --force to replace it" % (dest / name))
    dest.mkdir(parents=True, exist_ok=True)
    written = []
    for name in files:
        shutil.copyfile(vdir / "out" / name, dest / name)
        written.append(dest / name)
    side = {
        "schema_version": 1,
        "asset": asset,
        "kind": params["kind"],
        "files": {n: fc.sha256_file(dest / n) for n in files},
        "source": {"forge_version": "%s/%s/%s" % (params["pack"], asset, vdir.name),
                   "recipe_sha256": fc.sha256_file(vdir / "recipe.py")},
        "creator": "%s through tools/asset-forge, commissioned by Andrew" % (", ".join(manifest.get("model_used") or [manifest.get("model_requested") or "a model"])),
        "license_evidence": "Original locally generated art; no external images, textures or scans; no public license grant.",
        "transformations": ["forge %s kind: palette-strict, binary alpha, quantized to the shade ramp" % params["kind"]],
        "actual_use": "core-loop sketch menus, icons and UI",
        "import_note": "Import with nearest filtering (no mipmaps, no filter) so the pixels stay crisp.",
        "prompt_sha256": manifest.get("prompt_sha256"),
        "validate_score": manifest.get("validate_score"),
        **extra,
    }
    fc.write_json(side_dst, side)
    return written + [side_dst]


def promote(vdir, params, pack, manifest, force=False):
    asset = params["asset"]
    extra = {}
    if (Path(vdir) / "reference" / "source.glb").is_file():
        extra["reference_glb_sha256"] = fc.sha256_file(Path(vdir) / "reference" / "source.glb")
    return promote_files(vdir, params, pack, manifest, force, [asset + "_sheet.png", asset + ".json"], extra, "sprite")
