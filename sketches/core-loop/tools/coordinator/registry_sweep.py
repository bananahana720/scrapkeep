#!/usr/bin/env python3
"""Mark pending registry fragment rows as shipped when runtime code loads them.

A row ships when a file under src/ names its res:// path, or names its folder
and its file stem, or matches a name-built load in NAME_BUILT. Rows nothing
loads stay pending. Edits assets/registry.d fragments (the fold's source of
truth), so run tools/fold_registry.py afterwards. Prints what changed.
Usage: registry_sweep.py <sketch dir> [--write]
"""
import json
import pathlib
import sys

PENDING = "runtime integration pending"

NAME_BUILT = [
    ("res://assets/models/companion/assembled/", "", "src/presentation/companion_body.gd"),
    ("res://assets/models/dig_mechanical/breach_wedge_", "_12x12.glb", "src/presentation/dig_scenery.gd"),
    ("res://assets/models/dig_mechanical/breach_wedge_", "_14x10.glb", "src/presentation/dig_scenery.gd"),
    ("res://assets/models/dig_mechanical/breach_rim_sector", ".glb", "src/presentation/dig_scenery.gd"),
]


def loader_for(path, root, sources):
    for p, text in sources.items():
        if path in text:
            return str(p.relative_to(root))
    folder = path.rsplit("/", 1)[0] + "/"
    stem = path.rsplit("/", 1)[1].rsplit(".", 1)[0]
    for p, text in sources.items():
        if folder in text and stem in text:
            return str(p.relative_to(root))
    for prefix, suffix, loader in NAME_BUILT:
        if path.startswith(prefix) and path.endswith(suffix):
            return loader
    return None


def main():
    root = pathlib.Path(sys.argv[1])
    write = "--write" in sys.argv
    sources = {p: p.read_text() for p in (root / "src").rglob("*.gd")}
    flipped, left = [], []
    for fragment in sorted((root / "assets" / "registry.d").glob("*.json")):
        doc = json.loads(fragment.read_text())
        changed = False
        for row in doc["assets"]:
            if PENDING not in str(row.get("loader", "")):
                continue
            loader = loader_for(row["path"], root, sources)
            if loader is None:
                left.append(row["path"])
                continue
            row["ships"] = True
            row["loader"] = loader
            flipped.append((row["path"], loader))
            changed = True
        if changed and write:
            fragment.write_text(json.dumps(doc, indent=1) + "\n")
    for path, loader in flipped:
        print("ships  %s  <- %s" % (path, loader))
    for path in left:
        print("pending %s" % path)
    print("flipped %d, still pending %d" % (len(flipped), len(left)))


if __name__ == "__main__":
    main()
