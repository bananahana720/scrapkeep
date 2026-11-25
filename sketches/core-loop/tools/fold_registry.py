#!/usr/bin/env python3
"""Fold independently owned asset fragments into the core-loop registry."""

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile


def asset_id(row):
    if not isinstance(row, dict):
        raise ValueError("asset row must be an object")
    identity = row.get("id", row.get("path"))
    if not isinstance(identity, str) or not identity:
        raise ValueError("asset row needs a nonempty id or path")
    return identity


def read_document(path):
    with path.open(encoding="utf-8") as source:
        document = json.load(source)
    if not isinstance(document, dict) or not isinstance(document.get("assets"), list):
        raise ValueError(f"{path.name}: expected an object with an assets array")
    return document


def fold(root):
    registry = root / "assets/registry.json"
    document = read_document(registry)
    previous = document.get("fragment_ids", [])
    if not isinstance(previous, list) or not all(isinstance(x, str) for x in previous):
        raise ValueError("registry fragment_ids must be an array of strings")
    rows = {}
    paths = set()

    def insert(row, owner, check_glb=False):
        identity = asset_id(row)
        if identity in rows:
            raise ValueError(f"duplicate id: {identity} ({owner})")
        resource = row.get("path")
        if not isinstance(resource, str) or not resource.startswith("res://assets/"):
            raise ValueError(f"{owner}: invalid asset path: {resource}")
        asset = (root / resource.removeprefix("res://")).resolve()
        if not asset.is_relative_to((root / "assets").resolve()):
            raise ValueError(f"{owner}: asset path escapes assets: {resource}")
        if resource in paths:
            raise ValueError(f"duplicate path: {resource} ({owner})")
        if check_glb and resource.lower().endswith(".glb") and not asset.is_file():
            raise ValueError(f"{owner}: GLB does not exist: {resource}")
        rows[identity] = row
        paths.add(resource)

    existing_ids = set()
    existing_paths = set()
    for row in document["assets"]:
        identity = asset_id(row)
        if identity in existing_ids:
            raise ValueError(f"duplicate id: {identity} (registry.json)")
        if row.get("path") in existing_paths:
            raise ValueError(f"duplicate path: {row.get('path')} (registry.json)")
        existing_ids.add(identity)
        existing_paths.add(row.get("path"))
        if identity not in previous:
            insert(row, "registry.json")
    fragment_ids = []
    for fragment in sorted((root / "assets/registry.d").glob("*.json")):
        for row in read_document(fragment)["assets"]:
            insert(row, fragment.name, check_glb=True)
            fragment_ids.append(asset_id(row))
    document["assets"] = sorted(rows.values(), key=lambda row: (row["path"], asset_id(row)))
    if fragment_ids:
        document["fragment_ids"] = sorted(fragment_ids)
    else:
        document.pop("fragment_ids", None)
    rendered = json.dumps(document, indent=1, ensure_ascii=False) + "\n"
    if registry.read_text(encoding="utf-8") != rendered:
        mode = registry.stat().st_mode & 0o777
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=registry.parent,
                                             prefix=".registry-", delete=False) as output:
                temporary = Path(output.name)
                output.write(rendered)
            temporary.chmod(mode)
            os.replace(temporary, registry)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
    return len(rows), len(fragment_ids)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="core-loop project root (defaults to this script's project)")
    args = parser.parse_args()
    try:
        count, fragments = fold(args.root.resolve())
    except (ValueError, OSError) as error:
        print(f"fold_registry: ERROR {error}", file=sys.stderr)
        return 1
    print(f"fold_registry: PASS ({count} assets, {fragments} fragment assets)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
