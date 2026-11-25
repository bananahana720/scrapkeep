#!/usr/bin/env python3
"""CPU gate for every WebP under assets/textures, including unshipped rows.

Interface: python3 tools/tile_check.py [--project-root DIR] [--json]
Requires numpy and Pillow with WebP support. No Godot import cache is needed.
Exit 0 = all pass, 1 = asset/registry rejection, 2 = setup/argument error.

Compare left/right and top/bottom outermost pixel pairs, in matching order.
Differences are absolute channel differences on a 0..255 scale. RGB is
premultiplied by alpha; alpha is also compared, so invisible RGB is ignored
but transparency discontinuities fail. Each pair must pass BOTH its mean and
peak cap. Defaults (mean 8, peak 32) are provisional production tolerances,
not visual approval. Size defaults to assets/asset_budgets.json texture.max_side.
This checks boundary discontinuities, not slopes, mips, UVs or artistic quality.
No historical asset is silently exempted and no input file is modified.
"""

import argparse
import json
import math
from pathlib import Path
import sys


DEFAULT_MAX_MEAN_DIFF = 8.0
DEFAULT_MAX_PEAK_DIFF = 32.0
TEXTURE_PREFIX = "res://assets/textures/"


def dependencies():
    """Return (numpy module, PIL.Image module), or a readable setup error."""
    try:
        import numpy
        from PIL import Image, features
    except ImportError as exc:
        raise RuntimeError("requires numpy and Pillow in this interpreter: " + str(exc)) from exc
    if not features.check("webp"):
        raise RuntimeError("Pillow requires WebP decoding support")
    return numpy, Image


def registry_errors(registry, paths):
    """Require an exact one-to-one registry match for the discovered WebPs."""
    errors = []
    if not isinstance(registry, dict) or not isinstance(registry.get("assets"), list):
        return ["registry must be an object with an assets array"]
    registered = set()
    for index, row in enumerate(registry["assets"]):
        if not isinstance(row, dict) or not isinstance(row.get("path"), str):
            errors.append(f"registry assets[{index}] requires a string path")
            continue
        path = row["path"]
        if not path.startswith(TEXTURE_PREFIX) or Path(path).suffix.lower() != ".webp":
            continue
        if path in registered:
            errors.append(f"duplicate registry texture: {path}")
        registered.add(path)
        if row.get("class") != "texture":
            errors.append(f"registry texture has wrong class: {path}")
    for path in sorted(set(paths) - registered):
        errors.append(f"unregistered texture: {path}")
    for path in sorted(registered - set(paths)):
        errors.append(f"registry texture missing on disk: {path}")
    if not paths:
        errors.append("no WebP textures found")
    return errors


def measure_image(path, np, image_module, max_side, max_mean_diff, max_peak_diff):
    """Return dimensions, per-edge mean/peak differences and rejection reasons."""
    result = {"path": str(path), "errors": []}
    try:
        with image_module.open(path) as image:
            width, height = image.size
            result.update(width=width, height=height, max_side=max(width, height))
            if width < 2 or height < 2:
                result["errors"].append("requires at least 2 pixels on each side")
            if max(width, height) > max_side:
                result["errors"].append(f"max side {max(width, height)} exceeds {max_side}")
            if result["errors"]:
                return result
            if image.format != "WEBP":
                result["errors"].append("file is not WebP")
                return result
            if getattr(image, "n_frames", 1) != 1:
                result["errors"].append("animated texture is not supported")
                return result
            pixels = np.asarray(image.convert("RGBA"), dtype=np.float64)
            pixels[:, :, :3] *= pixels[:, :, 3:4] / 255.0
            if bool(np.all(pixels[:, :, 3] == 255)):
                pixels = pixels[:, :, :3]
            pairs = {
                "left_right": (pixels[:, 0, :], pixels[:, -1, :]),
                "top_bottom": (pixels[0, :, :], pixels[-1, :, :]),
            }
            result["edges"] = {}
            for name, (first, last) in pairs.items():
                difference = np.abs(first - last)
                mean, peak = float(np.mean(difference)), float(np.max(difference))
                result["edges"][name] = {"mean": mean, "peak": peak}
                if mean > max_mean_diff or peak > max_peak_diff:
                    result["errors"].append(
                        f"{name} mean {mean:.3f}, peak {peak:.3f} exceeds "
                        f"mean {max_mean_diff:g} / peak {max_peak_diff:g}"
                    )
    except (OSError, ValueError, image_module.DecompressionBombError) as exc:
        result["errors"].append(f"cannot decode texture: {exc}")
    return result


def run_check(root, np, image_module, max_side, max_mean_diff, max_peak_diff):
    registry = json.loads((root / "assets/registry.json").read_text())
    paths = sorted(
        path for path in (root / "assets/textures").rglob("*")
        if path.is_file() and path.suffix.lower() == ".webp"
    )
    resource_paths = ["res://" + path.relative_to(root).as_posix() for path in paths]
    errors = registry_errors(registry, resource_paths)
    textures = []
    for path, resource_path in zip(paths, resource_paths):
        result = measure_image(path, np, image_module, max_side, max_mean_diff, max_peak_diff)
        result["path"] = resource_path
        textures.append(result)
    return {
        "limits": {"max_side": max_side, "max_mean_diff": max_mean_diff,
                   "max_peak_diff": max_peak_diff},
        "registry_errors": errors,
        "textures": textures,
        "passed": not errors and all(not row["errors"] for row in textures),
    }


def channel_limit(value):
    number = float(value)
    if not math.isfinite(number) or not 0 <= number <= 255:
        raise argparse.ArgumentTypeError("must be finite and between 0 and 255")
    return number


def side_limit(value):
    number = int(value)
    if number < 2:
        raise argparse.ArgumentTypeError("must be at least 2")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--max-side", type=side_limit, help="override the project texture budget")
    parser.add_argument("--max-mean-diff", type=channel_limit, default=DEFAULT_MAX_MEAN_DIFF)
    parser.add_argument("--max-peak-diff", type=channel_limit, default=DEFAULT_MAX_PEAK_DIFF)
    parser.add_argument("--json", action="store_true", help="emit a machine-readable report")
    args = parser.parse_args(argv)
    try:
        np, image_module = dependencies()
        root = args.project_root.resolve()
        max_side = args.max_side
        if max_side is None:
            budget = json.loads((root / "assets/asset_budgets.json").read_text())["texture"]["max_side"]
            if type(budget) is not int or budget < 2:
                raise ValueError("texture.max_side must be an integer of at least 2")
            max_side = budget
        report = run_check(root, np, image_module, max_side, args.max_mean_diff, args.max_peak_diff)
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        if args.json:
            print(json.dumps({"passed": False, "setup_error": str(exc)}))
        else:
            print(f"tile_check: ERROR ({exc})")
        return 2
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(f"limits: max_side={max_side}, mean={args.max_mean_diff:g}, peak={args.max_peak_diff:g} (0..255)")
        for error in report["registry_errors"]:
            print("REGISTRY FAIL: " + error)
        for row in report["textures"]:
            label = "FAIL" if row["errors"] else "PASS"
            metrics = " ".join(
                f"{name}=mean:{edge['mean']:.3f}/peak:{edge['peak']:.3f}"
                for name, edge in row.get("edges", {}).items()
            )
            print(f"{label} {row['path']} {row.get('width', '?')}x{row.get('height', '?')} {metrics}")
            for error in row["errors"]:
                print("  " + error)
        count = len(report["registry_errors"]) + sum(bool(row["errors"]) for row in report["textures"])
        print("tile_check: PASS" if report["passed"] else f"tile_check: FAIL ({count})")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
