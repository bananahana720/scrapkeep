#!/usr/bin/env python3
"""Turns build_all.sh's AMBIENT_EXPORT rows into the assets/registry.d/ambient_life.json fragment (rows sorted by path).

Every row is class `ambient` and ships: src/core/ambient_kinds.gd names each model and the ambient life driver loads it by
kind. Provenance carries the recipe and the file's sha256, like the camp generator.
  python3 registry_fragment.py BUILD_LOG > assets/registry.d/ambient_life.json
"""
import json
import sys


def main():
    rows = []
    for line in open(sys.argv[1]):
        if not line.startswith("AMBIENT_EXPORT "):
            continue
        r = json.loads(line[len("AMBIENT_EXPORT "):])
        stem = r["file"][:-4]
        rows.append({
            "id": "ambient_" + stem,
            "path": "res://assets/models/ambient/" + r["file"],
            "class": "ambient",
            "ships": True,
            "loader": "src/core/ambient_kinds.gd",
            "provenance": {
                "recipe": "tools/blender/ambient/%s.py" % r["kind"],
                "note": "Ambient life kit (issue #149, wave 17). Authored procedurally in this repository from soft ellipsoids, "
                         "capsules and swept tubes (tools/blender/ambient/_life.py), one skinned mesh, one vertex-colour material, "
                         "clips idle, move and react baked in; palette, height and triangle band read from "
                         "src/core/ambient_kinds.gd; no imported mesh, texture or scan. "
                         "assets/models/ambient/ambient.PROVENANCE.txt. sha256 " + r["sha256"],
            },
        })
    rows.sort(key=lambda r: r["path"])
    print(json.dumps({"assets": rows}, indent=1))


if __name__ == "__main__":
    main()
