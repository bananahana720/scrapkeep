"""Pixel promoter: the PNG (frame strip), its JSON and a provenance sidecar into
<pack promote.pixel.sprites>/<asset>/. Shares the sprite kind's file copier."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import forgecore as fc  # noqa: E402

_sprite = fc.load_module(Path(__file__).resolve().parents[1] / "sprite" / "promote.py", "forge_sprite_promote")


def promote(vdir, params, pack, manifest, force=False):
    asset = params["asset"]
    return _sprite.promote_files(vdir, params, pack, manifest, force, [asset + ".png", asset + ".json"], {}, "pixel")
