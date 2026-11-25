import argparse
import hashlib
import json
import math
import os
import sys

import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common
from mathutils import Vector
import grapple_rigs as gr
from grapple_rigs import X, Y, Z, Rig, frame

common.SLOTS.setdefault("enamel", {"vc": True, "rough": 0.6, "metal": 0.1})
common.SLOTS.setdefault("steel", {"vc": True, "rough": 0.45, "metal": 0.5})

CAP = {"tris": 2000, "verts": 4600, "draws": 1}
CONCRETE = common.mix("sandstone", "bone", 0.45)
CONCRETE_DARK = common.mix("sandstone", "charcoal", 0.30)
PETROL = common.mix("petrol", "bone", 0.10)
IRON = common.mix("charcoal", gr.STEEL, 0.35)

HUB = Vector((0.0, -0.32, 1.95))
RIM_R, RIM_T = 0.85, 0.055
BITE = Vector((0.0, 0.0, 1.07))


def body(rig):
    rig.box((0, 0.15, 0.25), (1.5, 1.3, 0.5), CONCRETE)
    rig.box((0, 0.15, 0.52), (1.3, 1.1, 0.04), CONCRETE_DARK)
    rig.lathe(frame((0, 0.15, 0.50), Z), [(0.0, 0.27), (0.06, 0.27), (0.06, 0.20), (0.45, 0.20)], 10,
              ["copper", "copper", PETROL])
    rig.lathe(frame((-0.75, 0.15, 1.10), X), [(0.0, 0.20), (0.13, 0.20), (0.13, 0.30), (0.20, 0.30), (0.20, 0.26),
                                               (0.30, 0.36), (0.75, 0.42), (1.20, 0.36), (1.30, 0.26), (1.30, 0.30),
                                               (1.37, 0.30), (1.37, 0.20), (1.50, 0.20)], 12,
              [PETROL, PETROL, "copper", "copper", PETROL, PETROL, PETROL, PETROL, PETROL, "copper", "copper", PETROL])
    for xs in (-0.585, 0.585):
        for k in range(6):
            a = k * math.tau / 6 + math.pi / 6
            c = Vector((xs, 0.15 + 0.25 * math.cos(a), 1.10 + 0.25 * math.sin(a)))
            rig.cyl(c - X * 0.05, c + X * 0.05, 0.022, 6, gr.STEEL)
    rig.lathe(frame((0, 0.15, 1.48), Z), [(0.0, 0.22), (0.05, 0.22), (0.05, 0.16), (0.20, 0.16)], 10,
              ["copper", "copper", PETROL])
    for s in (-1, 1):
        rig.beam((s * 0.13, 0.15, 1.62), (s * 0.13, 0.12, 1.80), 0.05, 0.05, IRON)
    rig.box((0, 0.12, 1.95), (0.44, 0.38, 0.34), PETROL)
    rig.box((0, 0.12, 2.13), (0.36, 0.30, 0.04), IRON)
    rig.cyl((0, -0.05, 1.95), (0, HUB.y + 0.07, 1.95), 0.06, 10, gr.STEEL)
    rig.cyl((0, -0.07, 1.95), (0, -0.11, 1.95), 0.10, 10, "copper")


def wheel(rig):
    rig.torus((0, 0, 0), Y, RIM_R, RIM_T, 32, 8, IRON)
    for k in range(5):
        a = math.pi / 2 + math.pi / 5 + k * math.tau / 5
        d = Vector((math.cos(a), 0, math.sin(a)))
        rig.cyl(d * 0.10, d * (RIM_R - 0.02), 0.032, 6, gr.STEEL)
    rig.lathe(frame((0, 0.07, 0), -Y), [(0.0, 0.13), (0.16, 0.13), (0.16, 0.09), (0.22, 0.07)], 12,
              ["copper", "copper", "copper"])
    g = Vector((math.cos(math.radians(210)), 0, math.sin(math.radians(210)))) * RIM_R
    rig.lathe(frame(g, -Y), [(0.0, 0.035), (0.04, 0.042), (0.17, 0.042), (0.19, 0.03)], 8, "bone")
    rig.cyl((0, 0, RIM_R - 0.02), (0, 0, BITE.z - 0.13), 0.045, 8, "amber")
    rig.lathe(frame((0, 0.05, RIM_R), -Y), [(0.0, 0.07), (0.1, 0.07)], 10, IRON)
    rig.torus(BITE, Y, 0.125, 0.036, 20, 8, "amber")


def export(name, root_name, mesh, slot, build, sockets, out_dir):
    common.reset()
    rig = Rig(mesh, slot)
    build(rig)
    bmesh.ops.recalc_face_normals(rig.bm, faces=rig.bm.faces[:])
    root = common.empty(root_name)
    obj = rig.part.to_object((0, 0, 0), root)
    gr.smooth(obj)
    closed = gr.closed_report(obj)
    for socket, loc in sockets.items():
        common.empty(socket, loc, root)
    path = os.path.join(out_dir, name + ".glb")
    gr.export_glb(root, path)
    m = gr.gltf_metrics(path)
    m.update({"file": os.path.basename(path), "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(),
              "closed": closed})
    print("SLUICE_VALVE_EXPORT", name, json.dumps(m, sort_keys=True))
    return closed and all(m[k] <= CAP[k] for k in CAP)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=gr.OUT_DIR)
    args = ap.parse_args(argv)
    ok = export("sluice_valve_body", "SluiceValveBody", "Body", "enamel", body, {"socket_hub": HUB}, args.out_dir)
    ok = export("sluice_valve_wheel", "SluiceValveWheel", "Wheel", "steel", wheel, {"socket_bite": BITE}, args.out_dir) and ok
    if not ok:
        raise SystemExit("grapple_sluice_valve: a file is over the prop class or open")


if __name__ == "__main__":
    main()
