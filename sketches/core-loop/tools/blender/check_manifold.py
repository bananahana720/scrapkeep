"""Watertight check for GLB models, mesh by mesh, with no Blender needed.

Each mesh's triangles (every primitive, so a piece that spans two material slots counts as one)
are welded by position, then every edge is counted. An open edge is used by one triangle; a
non-manifold edge by three or more. A connected piece of welded triangles is an island, and an
island with any open edge is an open island. The report lists the open islands by size, so a
lattice of identical open bars reads as one line ("240 x 8 tris").

    python3 sketches/core-loop/tools/blender/check_manifold.py [--strict] [--max-open N]
        [--max-nonmanifold N] [--mesh NAME] [--weld METRES] FILE.glb [FILE.glb ...]

Report mode (the default) prints and exits 0. --strict exits 1 when a file has more than
--max-open open edges or more than --max-nonmanifold non-manifold edges (both default 0).
Exit 2 is a usage or read error. The convention for closed pieces is in POLISH.md, "Watertight".
"""

import argparse
import json
import struct
import sys
from collections import Counter, defaultdict

COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
TRIANGLES = 4
WELD = 1e-5


def read_glb(path):
    """The glTF JSON and the binary chunk of a .glb."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 20 or data[:4] != b"glTF":
        raise ValueError("%s is not a binary glTF file" % path)
    offset, doc, blob = 12, None, b""
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk)
        elif kind == 0x004E4942:
            blob = chunk
        offset += 8 + length
    if doc is None:
        raise ValueError("%s has no JSON chunk" % path)
    return doc, blob


def accessor(doc, blob, index):
    a = doc["accessors"][index]
    fmt, size = COMPONENT[a["componentType"]]
    n = WIDTH[a["type"]]
    if "bufferView" not in a:
        return [(0,) * n] * a["count"]
    view = doc["bufferViews"][a["bufferView"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", size * n)
    unpack = struct.Struct("<" + fmt * n).unpack_from
    return [unpack(blob, start + k * stride) for k in range(a["count"])]


def mesh_names(doc):
    """Mesh index -> the names of the nodes that show it (Godot names a MeshInstance3D after its
    node), falling back to the mesh's own name."""
    names = defaultdict(list)
    for node in doc.get("nodes", []):
        if "mesh" in node:
            names[node["mesh"]].append(node.get("name", ""))
    return {i: "/".join(names[i]) or m.get("name", "mesh%d" % i) for i, m in enumerate(doc.get("meshes", []))}


def triangles(doc, blob, mesh, weld):
    """The mesh's triangles as triples of welded vertex keys, degenerate ones dropped."""
    out = []
    for prim in mesh.get("primitives", []):
        if prim.get("mode", TRIANGLES) != TRIANGLES or "POSITION" not in prim.get("attributes", {}):
            continue
        pos = accessor(doc, blob, prim["attributes"]["POSITION"])
        keys = [tuple(round(c / weld) for c in p) for p in pos]
        idx = [i[0] for i in accessor(doc, blob, prim["indices"])] if "indices" in prim else list(range(len(pos)))
        for t in range(0, len(idx) - 2, 3):
            tri = (keys[idx[t]], keys[idx[t + 1]], keys[idx[t + 2]])
            if len(set(tri)) == 3:
                out.append(tri)
    return out


def scan(tris):
    """Counts for one mesh: triangles, islands, open islands and their sizes, open and
    non-manifold edges."""
    edges = Counter()
    for a, b, c in tris:
        for e in ((a, b), (b, c), (c, a)):
            edges[e if e[0] <= e[1] else (e[1], e[0])] += 1
    parent = {}

    def find(v):
        root = v
        while parent.setdefault(root, root) != root:
            root = parent[root]
        while parent[v] != root:
            parent[v], v = root, parent[v]
        return root

    for a, b, c in tris:
        ra, rb, rc = find(a), find(b), find(c)
        parent[rb] = ra
        parent[find(rc)] = ra
    size = Counter(find(t[0]) for t in tris)
    open_roots = {find(e[0]) for e, n in edges.items() if n == 1}
    return {
        "tris": len(tris),
        "islands": len(size),
        "open_islands": len(open_roots),
        "open_sizes": Counter(size[r] for r in open_roots),
        "open_edges": sum(1 for n in edges.values() if n == 1),
        "nonmanifold_edges": sum(1 for n in edges.values() if n >= 3),
    }


def pieces(sizes):
    return ", ".join("%d x %d tris" % (count, tris) for tris, count in sorted(sizes.items(), key=lambda kv: (-kv[1], kv[0])))


def check(path, weld=WELD, only=None):
    """Prints the per-mesh report for one file; returns its totals."""
    doc, blob = read_glb(path)
    names = mesh_names(doc)
    total = Counter()
    rows = []
    for i, mesh in enumerate(doc.get("meshes", [])):
        if only and names[i] not in only and mesh.get("name") not in only:
            continue
        r = scan(triangles(doc, blob, mesh, weld))
        rows.append((names[i], r))
        for key in ("tris", "islands", "open_islands", "open_edges", "nonmanifold_edges"):
            total[key] += r[key]
    if only and not rows:
        raise ValueError("no mesh matching %s" % ", ".join(only))
    print("FILE %s" % path)
    width = max([len(n) for n, _ in rows] + [4])
    for name, r in rows:
        if r["open_edges"] == 0 and r["nonmanifold_edges"] == 0:
            state = "closed"
        elif r["open_edges"] > 0:
            state = "OPEN"
        else:
            state = "NON-MANIFOLD"
        print("  %-*s %6d tris %5d islands %5d open %6d open edges %4d non-manifold  %s"
              % (width, name, r["tris"], r["islands"], r["open_islands"], r["open_edges"], r["nonmanifold_edges"], state))
        if r["open_sizes"]:
            print("  %-*s   open pieces: %s" % (width, "", pieces(r["open_sizes"])))
    print("MANIFOLD %s %d tris, %d islands, %d open islands, %d open edges, %d non-manifold edges"
          % (path, total["tris"], total["islands"], total["open_islands"], total["open_edges"], total["nonmanifold_edges"]))
    return total


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="+", help="GLB files to check")
    ap.add_argument("--strict", action="store_true", help="exit 1 when a file is over a threshold")
    ap.add_argument("--max-open", type=int, default=0, help="open edges a file may have under --strict")
    ap.add_argument("--max-nonmanifold", type=int, default=0, help="non-manifold edges a file may have under --strict")
    ap.add_argument("--mesh", action="append", help="check only this mesh (node name); repeatable")
    ap.add_argument("--weld", type=float, default=WELD, help="weld distance in metres (default %g)" % WELD)
    a = ap.parse_args(argv)
    if a.weld <= 0.0:
        print("ERROR --weld must be > 0 (got %g)" % a.weld, file=sys.stderr)
        return 2
    over = []
    for path in a.files:
        try:
            t = check(path, a.weld, a.mesh)
        except (OSError, ValueError, KeyError, struct.error) as e:
            print("ERROR %s: %s" % (path, e), file=sys.stderr)
            return 2
        if t["open_edges"] > a.max_open or t["nonmanifold_edges"] > a.max_nonmanifold:
            over.append("%s (%d open, %d non-manifold)" % (path, t["open_edges"], t["nonmanifold_edges"]))
    if a.strict and over:
        print("STRICT FAIL over --max-open %d / --max-nonmanifold %d: %s" % (a.max_open, a.max_nonmanifold, "; ".join(over)))
        return 1
    if a.strict:
        print("STRICT PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
