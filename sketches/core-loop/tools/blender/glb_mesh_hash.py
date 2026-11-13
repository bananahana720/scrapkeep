"""Order-independent hash of a glb's meshes: per mesh and material, the sorted multiset of
triangles, each a sorted tuple of its corners' attributes rounded to 1e-3 (float noise from summing smooth normals in another order is ~1e-4)."""
import json, struct, sys, hashlib
CT = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4), 5121: ("B", 1)}
N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
def load(path):
    d = open(path, "rb").read()
    jl = struct.unpack_from("<I", d, 12)[0]
    g = json.loads(d[20:20 + jl]); off = 20 + jl
    bin_ = d[off + 8:]
    def acc(i):
        a = g["accessors"][i]; bv = g["bufferViews"][a["bufferView"]]
        fmt, sz = CT[a["componentType"]]; n = N[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", sz * n)
        return [struct.unpack_from("<" + fmt * n, bin_, start + k * stride) for k in range(a["count"])]
    out = {}
    for m in g["meshes"]:
        for p in m["primitives"]:
            attrs = {k: acc(v) for k, v in sorted(p["attributes"].items())}
            idx = [i[0] for i in acc(p["indices"])]
            mat = g["materials"][p["material"]]["name"] if "material" in p else None
            def corner(v):
                return tuple(tuple(round(x, 3) for x in attrs[k][v]) for k in attrs)
            tris = sorted(tuple(sorted(corner(v) for v in idx[t:t+3])) for t in range(0, len(idx), 3))
            out.setdefault(m["name"], []).append((mat, hashlib.sha1(repr(tris).encode()).hexdigest()[:16], len(tris)))
    return out
for path in sys.argv[1:]:
    print(path, json.dumps(load(path), sort_keys=True))
