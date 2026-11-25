import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy

import common
from common import Vector
from mathutils import Quaternion

MAX_CHUNKS = 36
BANDS = ((12, "small"), (24, "medium"), (36, "large"))
TUCK = (0.52, 0.74)
HEFT_CLASS = 3
SHELL_PER_CLASS = 0.07


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type != "MESH":
            continue
        attrs = o.data.color_attributes
        for i, slot in enumerate(o.material_slots):
            name = slot.material.name.split(".")[0] if slot.material else ""
            if name in common.SLOTS:
                mat = common.material(name).copy() if attrs else common.material(name)
                node = mat.node_tree.nodes.get("Color Attribute")
                if node is not None and attrs:
                    node.layer_name = attrs[0].name
                o.material_slots[i].material = mat
    return new


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def main():
    common.reset()
    a = common.args()
    cls = sys.argv[sys.argv.index("--class") + 1] if "--class" in sys.argv else "rivet"
    common.preview_class({"sable": "mint", "rivet": "copper", "kest": "amber"}[cls])
    shell = import_glb(os.path.join(common.MODELS, "shell_%s.glb" % cls))
    root = [o for o in shell if o.parent is None][0]
    root.rotation_mode = "XYZ"
    chunk_objs = {o.name: o for o in import_glb(os.path.join(common.MODELS, "chunks.glb")) if o.type == "MESH"}
    for o in chunk_objs.values():
        o.hide_render = True
    scale = 1.0 + SHELL_PER_CLASS * (HEFT_CLASS - 1)
    for i in range(MAX_CHUNKS):
        y = 1.0 - (i + 0.5) / MAX_CHUNKS * 2.0
        r = math.sqrt(max(0.0, 1.0 - y * y))
        ang = i * 2.39996
        g = Vector((math.cos(ang) * r, y, math.sin(ang) * r))
        d = Vector((g.x, -g.z, g.y))
        size = next(name for limit, name in BANDS if i < limit)
        src = chunk_objs["chunk_%s_%d" % (size, i % 3)]
        tuck = 1.0 - smoothstep(TUCK[0], TUCK[1], d.z)
        if tuck <= 0.0:
            continue
        o = bpy.data.objects.new("placed_%d" % i, src.data)
        bpy.context.scene.collection.objects.link(o)
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d) @ Quaternion((0, 0, 1), i * 1.3)
        o.location = d * 1.02 * scale
        o.scale = Vector((scale, scale, scale)) * tuck
        o.parent = root
    common.render_turntable(root, "growth_" + cls, a["render"], [
        ("game", 8.0, 0.30, 65, (1920, 1080), 0.5),
        ("close", 4.2, 0.28, 38, (640, 640)),
    ], ground_z=-1.1, target=(0, 0, 0.25), yaws=(0, 90, 180))


main()
