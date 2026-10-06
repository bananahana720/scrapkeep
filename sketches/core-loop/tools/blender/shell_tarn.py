"""Contained Redjaw vice shell. No pilot placeholder or shell skeleton.

blender -b --threads 2 --python-exit-code 1 -P this_file
Uses spherical's original glass, seat, grips and gyro dimensions locally, because
its dispatch embeds another pilot and adds decorative mint field geometry.
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[1]
sys.path.insert(0, str(HERE))
import common
from common import Part


def socket(name, location, parent, direction=(0, 1, 0)):
    node = common.empty(name, location, parent)
    node.rotation_euler = Vector((0, 1, 0)).rotation_difference(Vector(direction)).to_euler()
    return node


def lower_hull(p):
    # Irregular broad spherical repair plates keep an open cockpit/control cone.
    count = 20
    for band in range(3):
        z0, z1 = [(-.91, -.72), (-.72, -.48), (-.48, -.255)][band]
        for k in range(count):
            a0 = k * math.tau / count + .013
            a1 = (k + 1) * math.tau / count - .013
            # The working jaws sit inside the collision ball but outside these open
            # armour bays. A closed spherical apron would conceal their bite.
            if band == 2 and math.sin((a0 + a1) / 2) > .30:
                continue
            # Each plate has one inset dark edge and a raised, rubbed painted top.
            rows = []
            for z in (z0 + .008, z1 - .008):
                radial = math.sqrt(.926 ** 2 - z * z)
                rows.append([p.bm.verts.new((radial * math.cos(a), radial * math.sin(a), z)) for a in (a0, (a0 + a1) / 2, a1)])
            for j in range(2):
                f = p.bm.faces.new((rows[0][j], rows[0][j + 1], rows[1][j + 1], rows[1][j]))
                p.paint([f], "paint", ("petrol", "petrol", "bone", "oxide", "petrol")[(k + band * 3) % 5])
            # Bolts/wear go only at actual plate corners and carrying joints.
            if k % 2 == band % 2:
                z = z1 - .035
                r = math.sqrt(.93 ** 2 - z * z)
                normal = Vector((math.cos(a0), math.sin(a0), 0))
                p.bolt((r * normal.x, r * normal.y, z), normal, .014, .008, 6, "paint")
    inside = p.uv("rubber", .916, 24, 14, loc=(0, 0, 0))
    # Remove the rubber upper hemisphere: it would hide the animal inside glass.
    high = [v for v in p.verts_of(inside) if v.co.z > -.27 or (v.co.y > .25 and v.co.z > -.53)]
    import bmesh
    bmesh.ops.delete(p.bm, geom=high, context="VERTS")


def build_shell():
    common.SLOTS["class_accent"] = {"color": "oxide", "rough": .75}
    root = common.empty("ShellTarn")
    glass = Part("Core")
    glass.uv("glass", .98, 40, 24)
    core = glass.to_object(parent=root)
    for polygon in core.data.polygons:
        polygon.use_smooth = True
    p = Part("Pod")
    lower_hull(p)
    p.ring("paint", .86, .92, .12, 32, loc=(0, 0, -.29), color="petrol", arc=(math.pi - .24, math.tau + .24))
    p.ring("paint", .69, .745, .06, 24, loc=(0, 0, -.60), color="petrol", arc=(.24, math.pi - .24))
    p.cyl("rubber", .36, .28, .16, 20, loc=(0, 0, -.6))
    # Same seat and control positions as shell_base.spherical, counted only once.
    seat = [(-.22, -.27), (.22, -.27), (.27, -.20), (.24, .14), (.16, .20), (-.16, .20), (-.24, .14), (-.27, -.20)]
    p.prism("paint", seat, .09, matrix=common.mtx((0, -.27, -.1), (math.pi / 2, 0, 0)), color="petrol")
    p.uv("rubber", .22, 12, 8, loc=(0, -.22, -.12), scale=(1, .35, 1.15))
    p.box("rubber", (.48, .42, .09), loc=(0, 0, -.34))
    for sign in (-1, 1):
        p.rod("paint", (sign * .34, .28, -.32), (sign * .32, .4, 0), .025, 8, color="bone")
        p.rod("rubber", (sign * .32, .4, 0), (sign * .32, .4, .1), .045, 8)
        # Loaded hinge seats and repaired casing share the Pod paint surface.
        p.box("paint", (.11, .16, .22), loc=(sign * .58, .275, -.37), color="petrol")
        p.box("paint", (.075, .08, .06), loc=(sign * .58, .245, -.22), color="oxide")
        p.cyl("class_accent", .055, .055, .018, 10, loc=(sign * .643, .32, -.37), rot=(0, math.pi / 2, 0))
        # Rear cheek casing brackets anchor the tension drum to the load frame.
        p.cyl("paint", .177, .161, .047, 16, loc=(sign * .225, -.58, -.29), rot=(0, math.pi / 2, 0), color="petrol")
        p.cyl("paint", .052, .052, .059, 10, loc=(sign * .23, -.58, -.29), rot=(0, math.pi / 2, 0), color="oxide")
    p.box("paint", (.38, .14, .14), loc=(0, .57, -.36), color="petrol")
    for sign in (-1, 1):
        p.box("paint", (.078, .15, .04), loc=(sign * .154, .57, -.271), color="oxide")
    rake = [(-.20, -.12), (.20, -.12), (.20, .095), (.145, .12), (.105, .06), (.06, .12), (.02, .065), (-.02, .12), (-.06, .065), (-.105, .12), (-.145, .06), (-.20, .095)]
    p.prism("paint", rake, .08, matrix=common.mtx((0, .23, -.72)), color="bone", side_color="oxide")
    # A few asymmetrical riveted repair straps, no decorative hazard stripes.
    for k in range(7):
        a = .23 + k * math.tau / 7
        if math.sin(a) > .25:
            continue
        p.ring("paint", .913, .926, .031, 2, loc=(0, 0, -.258),
               arc=(a, a + .13 + .025 * (k % 3)), color="bone" if k % 3 else "oxide")
    pod = p.to_object(parent=root)
    common.empty("Dome", parent=pod)
    gyro = Part("Gyro")
    gyro.ring("bare_metal", .938, .965, .055, 64, rot=(math.pi / 2, 0, 0))
    gyro.to_object(parent=pod)
    for side, sign in (("R", 1), ("L", -1)):
        for label, z, flip in (("Upper", -.31, 1), ("Lower", -.43, -1)):
            jaw = Part("Claw" + label + "." + side)
            # One connected three-tooth plate: narrow waist, broad working bite.
            outline = [(-.105, -.08), (.105, -.08), (.11, .13), (.09, .26),
                       (.052, .28), (.033, .205), (.018, .28), (-.018, .28),
                       (-.033, .205), (-.052, .28), (-.09, .26), (-.11, .13)]
            faces = jaw.prism("bare_metal", outline, .041, matrix=common.mtx((sign * .58, .32, z)))
            for vertex in jaw.verts_of(faces):
                if vertex.co.y > .46:
                    vertex.co.z -= flip * .055 * min(1, (vertex.co.y - .46) / .14)
                    vertex.co.x -= sign * .10 * (vertex.co.y - .46)
            jaw.cyl("bare_metal", .056, .056, .225, 12, loc=(sign * .58, .32, z), rot=(0, math.pi / 2, 0))
            jaw.to_object((sign * .58, .32, z), pod)
        socket("ClawPivot." + side, (sign * .58, .32, -.31), pod, (1, 0, 0))
        socket("ClawTip." + side, (sign * .58, .55, -.36), pod)
        socket("Grip." + side, (sign * .32, .40, .05), pod)
    drum = Part("PullDrum")
    drum.cyl("rubber", .146, .146, .42, 24, loc=(0, -.58, -.29), rot=(0, math.pi / 2, 0))
    # Rope grooves are the drum's surface, not a mesh of loose pipe primitives.
    for k in range(12):
        drum.ring("rubber", .145, .15, .019, 20, loc=(-.195 + k * .035, -.58, -.29), rot=(0, math.pi / 2, 0))
    drum.to_object((0, -.58, -.29), pod)
    socket("PullExit", (0, -.74, -.29), pod, (0, -1, 0))
    socket("RendContact", (0, .23, -.79), pod, (0, 0, -1))
    bpy.context.view_layer.update()
    for obj in common.tree(root):
        if obj.type == "MESH":
            assert common.max_radius(obj) <= .985001, (obj.name, common.max_radius(obj))
    assert common.tri_total(root) <= 11000
    return root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=SKETCH / "assets/models/world_one/shell_tarn.glb")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    common.reset()
    root = build_shell()
    common.export(root, str(args.out))
    print("TARN_SHELL: PASS", common.tri_total(root), "triangles; every resting mesh inside 0.985 m")


if __name__ == "__main__":
    main()
