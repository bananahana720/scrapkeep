#!/usr/bin/env python3
"""Mark pending registry rows as shipped when runtime code loads them.

A row ships when a file under src/ names its res:// path, or names its folder
and its file stem. Rows nothing loads stay pending. Prints what changed.
Usage: registry_sweep.py <sketch dir> [--write]
"""
import json
import pathlib
import sys

PENDING = "runtime integration pending"

# Loads built from a name at runtime, so no source file holds the literal path.
# Each entry is backed by the wiring unit's own test (WCO companion_body_test,
# WDG dig_scenery_test).
NAME_BUILT = [
    ("res://assets/models/companion/assembled/", "", "src/presentation/companion_body.gd"),
    ("res://assets/models/dig_mechanical/breach_wedge_", "_12x12.glb", "src/presentation/dig_scenery.gd"),
    ("res://assets/models/dig_mechanical/breach_wedge_", "_14x10.glb", "src/presentation/dig_scenery.gd"),
    ("res://assets/models/dig_mechanical/breach_rim_sector", ".glb", "src/presentation/dig_scenery.gd"),
]


def main():
    root = pathlib.Path(sys.argv[1])
    write = "--write" in sys.argv
    reg_path = root / "assets" / "registry.json"
    reg = json.loads(reg_path.read_text())
    rows = reg if isinstance(reg, list) else reg.get("assets", reg.get("entries", []))
    sources = {p: p.read_text() for p in (root / "src").rglob("*.gd")}
    flipped, left = [], []
    for row in rows:
        if PENDING not in str(row.get("loader", "")):
            continue
        path = row["path"]
        folder = path.rsplit("/", 1)[0] + "/"
        stem = path.rsplit("/", 1)[1].rsplit(".", 1)[0]
        hit = None
        for p, text in sources.items():
            if path in text:
                hit = p
                break
        if hit is None:
            for p, text in sources.items():
                if folder in text and stem in text:
                    hit = p
                    break
        if hit is None:
            for prefix, suffix, loader in NAME_BUILT:
                if path.startswith(prefix) and path.endswith(suffix):
                    hit = root / loader
                    break
        if hit is None:
            left.append(path)
        else:
            row["ships"] = True
            row["loader"] = str(hit.relative_to(root))
            flipped.append((path, row["loader"]))
    for path, loader in flipped:
        print("ships  %s  <- %s" % (path, loader))
    for path in left:
        print("pending %s" % path)
    print("flipped %d, still pending %d" % (len(flipped), len(left)))
    if write:
        reg_path.write_text(json.dumps(reg, indent=1) + "\n")


if __name__ == "__main__":
    main()
