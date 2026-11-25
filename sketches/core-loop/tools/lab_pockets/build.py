"""Mint each lab pocket recipe with mojulo, export it lit and write <shape>.glb.

Run from sketches/core-loop: python3 tools/lab_pockets/build.py [shape ...]
Needs Node 22.14+ (npx -y mojulo@3.0.0). Exports can take minutes, so the tool budget is raised to 600 s.

Each glb is mojulo's lit export (`export_model { lit: true }`, real PBR materials) with three changes, so a lab scene
loads it as-is:
  - COLOR_0 decoded from sRGB to linear (gamma 2.2). Mojulo 3.0.0 stores sRGB tints in COLOR_0, which glTF defines as
    linear, so without this the colours render pale.
  - mojulo's studio ground plate (the `static` mesh, a sheet under the lowest point) dropped.
  - the five studio cameras dropped.
Writes build.json with each shape's ref, triangles, bytes and geometry sha256 (positions and indices only, so it does
not change with the sketch ref mojulo stamps into the file).
"""
import hashlib
import json
import os
import pathlib
import struct
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
MOJULO = ["npx", "-y", "mojulo@3.0.0"]
GAMMA = 2.2
DROP_MESHES = {"static"}
RENAME = {"rail_grove": {"static:pbr": "rail:pbr"}}


def call(tool, args):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(args, f)
        path = f.name
    env = dict(os.environ, MOJULO_MCP_TOOL_TIMEOUT_MS="600000")
    p = subprocess.run(MOJULO + ["call", tool, "--json", "@" + path], capture_output=True, text=True, env=env, timeout=900)
    os.unlink(path)
    if p.returncode != 0:
        raise SystemExit(f"{tool} failed: {(p.stdout + p.stderr)[-800:]}")
    return json.loads(p.stdout)


def read_glb(path):
    b = pathlib.Path(path).read_bytes()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    blen = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]
    return j, b[28 + jlen:28 + jlen + blen]


def write_glb(path, j, binary):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binary += b"\0" * (-len(binary) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(binary))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(binary), 0x004E4942) + binary
    pathlib.Path(path).write_bytes(out)


def rewrite(j, binary, rename=None):
    """Keep the root and its non-static mesh nodes; repack only the data they use; decode COLOR_0."""
    root_i = j["scenes"][j.get("scene", 0)]["nodes"][0]
    root = j["nodes"][root_i]
    keep = [i for i in root["children"] if "mesh" in j["nodes"][i] and j["meshes"][j["nodes"][i]["mesh"]]["name"] not in DROP_MESHES]
    nodes, meshes, accessors, views, materials = [], [], [], [], []
    mat_map, acc_map, blob = {}, {}, bytearray()
    geom = hashlib.sha256()

    def take_accessor(ai, colour=False):
        if ai in acc_map:
            return acc_map[ai]
        a = dict(j["accessors"][ai])
        v = j["bufferViews"][a["bufferView"]]
        data = bytearray(binary[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
        if colour:
            if a["componentType"] != 5126:
                raise SystemExit("COLOR_0 is not float; decode not implemented")
            vals = struct.unpack(f"<{len(data) // 4}f", data)
            comps = 4 if a["type"] == "VEC4" else 3
            dec = [x if (k % comps) == 3 else max(0.0, x) ** GAMMA for k, x in enumerate(vals)]
            data = bytearray(struct.pack(f"<{len(dec)}f", *dec))
        blob.extend(b"\0" * (-len(blob) % 4))
        nv = {k: x for k, x in v.items() if k != "byteOffset"}
        nv["byteOffset"] = len(blob)
        blob.extend(data)
        views.append(nv)
        a["bufferView"] = len(views) - 1
        accessors.append(a)
        acc_map[ai] = len(accessors) - 1
        return acc_map[ai]

    for ni in keep:
        n = dict(j["nodes"][ni])
        m = j["meshes"][n["mesh"]]
        prims = []
        for p in m["primitives"]:
            q = dict(p)
            q["attributes"] = {k: take_accessor(ai, colour=(k == "COLOR_0")) for k, ai in p["attributes"].items()}
            for key in ("POSITION",):
                v = j["bufferViews"][j["accessors"][p["attributes"][key]]["bufferView"]]
                geom.update(binary[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
            if "indices" in p:
                q["indices"] = take_accessor(p["indices"])
                v = j["bufferViews"][j["accessors"][p["indices"]]["bufferView"]]
                geom.update(binary[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
            if "material" in p:
                if p["material"] not in mat_map:
                    materials.append(j["materials"][p["material"]])
                    mat_map[p["material"]] = len(materials) - 1
                q["material"] = mat_map[p["material"]]
            prims.append(q)
        name = (rename or {}).get(m["name"], m["name"])
        meshes.append({**m, "name": name, "primitives": prims})
        n["mesh"] = len(meshes) - 1
        n["name"] = (rename or {}).get(n.get("name"), n.get("name"))
        nodes.append(n)
    new_root = {k: v for k, v in root.items() if k != "children"}
    new_root["children"] = list(range(len(nodes)))
    nodes.append(new_root)
    out = {k: v for k, v in j.items() if k not in ("cameras", "nodes", "meshes", "accessors", "bufferViews", "materials", "buffers", "scenes")}
    out.update(nodes=nodes, meshes=meshes, accessors=accessors, bufferViews=views, materials=materials,
               buffers=[{"byteLength": len(blob)}], scenes=[{"nodes": [len(nodes) - 1]}], scene=0)
    out.setdefault("asset", {})["generator"] = out["asset"].get("generator", "mojulo") + " + tools/lab_pockets/build.py"
    tris = sum(accessors[p["indices"]]["count"] // 3 for m in meshes for p in m["primitives"])
    return out, bytes(blob), tris, geom.hexdigest()


def main():
    subprocess.run([sys.executable, str(HERE / "gen.py")], check=True, stdout=subprocess.DEVNULL)
    shapes = sys.argv[1:] or ["half_pipe", "rolling_wall", "crevice", "hazard_field", "rail_grove"]
    report_path = HERE / "build.json"
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    for name in shapes:
        spec = json.loads((HERE / "recipes" / f"{name}.json").read_text())
        mint = call("mint_solid", {"kind": "workbench", "title": f"lab_pockets {name}", "spec": spec})
        ref = mint["ref"]
        exp = call("export_model", {"ref": ref, "format": "glb", "lit": True})
        j, binary = read_glb(exp["path"])
        j2, b2, tris, geom = rewrite(j, binary, RENAME.get(name))
        out = HERE / f"{name}.glb"
        write_glb(out, j2, b2)
        report[name] = {"ref": ref, "mint_faces": mint["stats"]["faces"], "triangles": tris, "bytes": out.stat().st_size,
                        "geometry_sha256": geom, "recipe": f"recipes/{name}.json"}
        print(name, json.dumps(report[name]))
    report_path.write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()
