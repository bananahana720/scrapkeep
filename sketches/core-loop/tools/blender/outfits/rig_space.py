"""Rest-pose joint frames read straight from a shipped GLB, in Blender pilot space.

An outfit part rides a BoneAttachment3D, so its vertices must be authored in that bone's
local frame. Recipes model in pilot space (+Z up, +Y forward, sphere centre at the origin)
and call to_bone() to move a part into the bone's frame. Godot uses the GLB's node TRS as
each bone's rest, so these frames are the ones the attachment uses.
"""
import json
import struct

from mathutils import Matrix, Quaternion, Vector

TO_GLTF = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))


def _gltf(path):
    data = open(path, "rb").read()
    size = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + size])


def _trs(node):
    if "matrix" in node:
        m = node["matrix"]
        return Matrix([m[i::4] for i in range(4)])
    t = Vector(node.get("translation", (0, 0, 0)))
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    s = Vector(node.get("scale", (1, 1, 1)))
    return Matrix.LocRotScale(t, Quaternion((w, x, y, z)), s)


def joint_frames(path):
    """{joint name: 4x4 rest frame in Blender pilot space} for the GLB's first skin."""
    gltf = _gltf(path)
    nodes = gltf["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", ())}

    def world(i):
        m = _trs(nodes[i])
        while i in parent:
            i = parent[i]
            m = _trs(nodes[i]) @ m
        return m

    inv = TO_GLTF.inverted()
    return {nodes[j]["name"]: inv @ world(j) @ TO_GLTF for j in gltf["skins"][0]["joints"]}


def _read(gltf, blob, index):
    a = gltf["accessors"][index]
    view = gltf["bufferViews"][a["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    kind = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[a["componentType"]]
    step = view.get("byteStride") or struct.calcsize("<" + kind) * width
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from("<%d%s" % (width, kind), blob, start + k * step) for k in range(a["count"])]


def bone_vertices(path):
    """{joint name: [Vector]} of the skinned meshes' rest vertices, in Blender pilot space.
    Every shipped pilot and SPIL-9 vertex has one rigid weight, so JOINTS_0[0] owns it."""
    data = open(path, "rb").read()
    size = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + size])
    blob = data[20 + size + 8:]
    nodes = gltf["nodes"]
    joints = [nodes[j]["name"] for j in gltf["skins"][0]["joints"]]
    out = {}
    for node in nodes:
        if "mesh" not in node or "skin" not in node:
            continue
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            pos = _read(gltf, blob, prim["attributes"]["POSITION"])
            owner = _read(gltf, blob, prim["attributes"]["JOINTS_0"])
            for (x, y, z), j in zip(pos, owner):
                out.setdefault(joints[j[0]], []).append(Vector((x, -z, y)))
    return out


def clip_lengths(path, names):
    """{clip: seconds} read from the GLB's animation samplers."""
    data = open(path, "rb").read()
    size = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + size])
    out = {}
    for anim in gltf.get("animations", ()):
        if anim["name"] in names:
            out[anim["name"]] = max(gltf["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
    missing = set(names) - set(out)
    assert not missing, (path, missing)
    return out
