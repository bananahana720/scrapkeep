"""Geometry-only hashes for a mojulo export, so two machines can compare shape without metadata.

Usage: python3 geomhash.py <model.glb|model.stl> ...
glb: sha256 of the BIN chunk, and of the JSON chunk with names, extras and asset fields removed.
stl: sha256 of the triangle records, skipping the 80-byte header.
"""
import hashlib
import json
import struct
import sys


def strip(o):
    if isinstance(o, dict):
        return {k: strip(v) for k, v in o.items() if k not in ("name", "extras", "asset", "extensionsUsed", "extensions")}
    if isinstance(o, list):
        return [strip(v) for v in o]
    return o


for path in sys.argv[1:]:
    with open(path, "rb") as f:
        data = f.read()
    if path.endswith(".stl"):
        print(path, "stl_tris", hashlib.sha256(data[84:]).hexdigest(), struct.unpack("<I", data[80:84])[0])
        continue
    off, js, bin_ = 12, None, b""
    while off < len(data):
        n, kind = struct.unpack("<II", data[off:off + 8])
        chunk = data[off + 8:off + 8 + n]
        if kind == 0x4E4F534A:
            js = json.loads(chunk)
        elif kind == 0x004E4942:
            bin_ = chunk
        off += 8 + n
    if js is None:
        raise SystemExit(f"geomhash.py: missing GLB JSON chunk in {path}")
    print(path, "bin", hashlib.sha256(bin_).hexdigest(), "json_geom",
          hashlib.sha256(json.dumps(strip(js), sort_keys=True).encode()).hexdigest(),
          "names", sorted({m.get("name", "") for m in js.get("nodes", [])})[:4])
