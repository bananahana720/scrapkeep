"""Remembered cannon: contained cast kit in a repaired rolling hull.

blender -b --threads 2 --python-exit-code 1 --python this_file.py
No embedded pilot. Geometry uses Blender +Y forward, +Z up, metres.
"""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
from common import Part

MODEL = HERE.parents[2] / "assets/models/world_one/shell_cannon.glb"
SOCKETS = {
    "LaneMuzzle": ((0, .85, -.29), (0, 1, 0)),
    "BarrelPivot": ((0, .44, -.29), (0, 1, 0)),
    "SplitExit.R": ((.32, -.71, -.30), (.22, -1, 0)),
    "SplitExit.L": ((-.32, -.71, -.30), (-.22, -1, 0)),
    "SectorPivot": ((0, .60, -.56), (0, 1, 0)),
    "RushContact": ((0, 0, -.81), (0, 0, -1)),
    "Grip.R": ((.32, .40, .05), (0, 1, 0)),
    "Grip.L": ((-.32, .40, .05), (0, 1, 0)),
}


def hull_panels(p):
    """Curved salvage panels, fitted directly to the lower glass hemisphere."""
    colours = ("petrol", "petrol", "bone", "petrol", "oxide", "petrol")
    # Three staggered courses with broad, deliberately mismatched repairs.
    for band, (z0, z1) in enumerate(((-.92, -.72), (-.715, -.49), (-.485, -.25))):
        for sector in range(12):
            if band == 2 and sector in (2, 3):
                continue
            a0 = sector * math.tau / 12 + band * .10 + .007
            a1 = a0 + math.tau / 12 - .014
            rows = []
            for j in range(4):
                z = z0 + (z1-z0)*j/3
                r = math.sqrt(.962**2-z*z)
                rows.append([p.bm.verts.new(Vector((r*math.cos(a), r*math.sin(a), z)))
                             for a in [a0+(a1-a0)*k/4 for k in range(5)]])
            faces = []
            for j in range(3):
                for k in range(4):
                    f = p.bm.faces.new((rows[j][k], rows[j][k+1], rows[j+1][k+1], rows[j+1][k]))
                    f.smooth = True
                    faces.append(f)
            p.paint(faces, "paint", colours[(sector + band*2) % len(colours)])
            # Shaped scuffs occupy a few large corners, rather than noisy speckles.
            if (sector+band) % 3 == 0:
                p.paint([faces[0]], "paint", "bone")
    p.uv("rubber", .952, 24, 12, scale=(1, 1, 1))
    # Remove the dark backing above the lower hull, leaving the upper glass clear.
    import bmesh
    high = [v for v in p.bm.verts if v.co.z > -.245 or
            (v.co.z > -.49 and v.co.y > .65 and abs(v.co.x) < .49)]
    bmesh.ops.delete(p.bm, geom=high, context="VERTS")


def build():
    common.SLOTS["ancient_light"] = dict(common.SLOTS["ancient_light"], emit=.45)
    root = common.empty("ShellCannon")
    glass = Part("Core")
    glass.uv("glass", .98, 40, 24)
    core = glass.to_object(parent=root)
    for f in core.data.polygons:
        f.use_smooth = True
    p = Part("Pod")
    hull_panels(p)
    # Copied seat/control geometry from shell_base.spherical, without its pilot,
    # legacy kit refit or mint field rings. Ancient parts have no fasteners.
    for a0, a1, segments in ((0, math.pi/2-.36, 10), (math.pi/2+.36, math.tau, 34)):
        p.ring("paint", .86, .92, .12, segments, loc=(0, 0, -.29), color="petrol", arc=(a0, a1))
    p.cyl("rubber", .36, .28, .16, 20, loc=(0, 0, -.6))
    seat = [(-.22, -.27), (.22, -.27), (.27, -.20), (.24, .14),
            (.16, .20), (-.16, .20), (-.24, .14), (-.27, -.20)]
    p.prism("paint", seat, .09, matrix=common.mtx((0, -.27, -.1), (math.pi/2, 0, 0)), color="oxide")
    p.uv("rubber", .22, 12, 8, loc=(0, -.22, -.12), scale=(1, .35, 1.15))
    p.box("rubber", (.48, .42, .09), loc=(0, 0, -.34))
    for side in (-1, 1):
        p.rod("paint", (side*.34, .28, -.32), (side*.32, .4, 0), .025, 8, color="bone")
        p.rod("rubber", (side*.32, .4, 0), (side*.32, .4, .1), .045, 8)
    # U cradle is a single broad concave casting in the XZ plane.
    u = [(-.29, .22), (-.20, .22), (-.20, -.04), (-.13, -.13),
         (.13, -.13), (.20, -.04), (.20, .22), (.29, .22),
         (.29, -.10), (.18, -.22), (-.18, -.22), (-.29, -.10)]
    p.prism("ancient_enamel", u, .42,
            matrix=common.mtx((0, .42, -.34), (math.pi/2, 0, 0)), color="bone")
    # Inset rush annulus, with a narrow reclaimed-origin blue cue.
    p.ring("ancient_enamel", .15, .22, .03, 32, loc=(0, 0, -.78), color="bone")
    p.ring("ancient_light", .157, .163, .004, 32, loc=(0, 0, -.798))
    # Charcoal cavities behind single-material moving cast meshes.
    p.cyl("rubber", .079, .079, .008, 24, loc=(0, .54, -.29), rot=(math.pi/2, 0, 0))
    for s in (-1, 1):
        p.box("rubber", (.15, .012, .14), loc=(s*.32, -.685, -.30), rot=(0, 0, s*.18))
    pod = p.to_object(parent=root)
    common.empty("Dome", parent=pod)
    # Reuse spherical's independent gyro dimensions, packed into one paint draw.
    g = Part("Gyro")
    g.ring("paint", .938, .965, .055, 64, rot=(math.pi/2, 0, 0), color="bone")
    g.ring("paint", .946, .972, .028, 64, rot=(math.pi/2, 0, 0), color="petrol")
    g.to_object(parent=pod)
    b = Part("MainBarrel")
    b.ring("ancient_enamel", .08, .17, .785, 24, loc=(0, .4225, -.29), rot=(math.pi/2, 0, 0), color="petrol")
    b.ring("ancient_enamel", .08, .17, .035, 24, loc=(0, .8325, -.29), rot=(math.pi/2, 0, 0), color="bone")
    b.to_object((0, .44, -.29), pod)
    ports = Part("SplitPorts")
    for s in (-1, 1):
        outline = [(-.11, -.09), (-.09, -.11), (.09, -.11), (.11, -.09),
                   (.11, .09), (.09, .11), (-.09, .11), (-.11, .09)]
        # Four broad walls leave an actual open aperture, not a black decal.
        transform = common.mtx((s*.32, -.58, -.30), (math.pi/2, 0, s*.18))
        inner = [(x*.65, y*.65) for x, y in outline]
        for i in range(8):
            j = (i+1)%8
            ports.prism("ancient_enamel", [outline[i], outline[j], inner[j], inner[i]],
                        .26, matrix=transform, color="bone")
    ports.to_object(parent=pod)
    shutter = Part("SectorShutter")
    shutter.prism("ancient_enamel", [(-.25, -.065), (-.22, -.09), (.22, -.09),
                                     (.25, -.065), (.25, .09), (-.25, .09)], .14,
                  matrix=common.mtx((0, .60, -.56), (math.pi/2, 0, 0)), color="petrol")
    shutter.to_object((0, .60, -.56), pod)
    for name, (loc, forward) in SOCKETS.items():
        socket = common.empty(name, loc, pod)
        # Local -Z is glTF/Godot forward after export, authored as +Y here.
        socket.rotation_euler = Vector((0, 1, 0)).rotation_difference(Vector(forward).normalized()).to_euler()
    bpy.context.view_layer.update()
    radius = max(common.max_radius(o) for o in common.tree(root) if o.type == "MESH")
    assert radius <= .985001, radius
    assert common.tri_total(root) <= 11000
    print("CANNON_SHELL: rest radius %.6f; triangles %d" % (radius, common.tri_total(root)))
    return root


def main():
    common.reset()
    root = build()
    common.export(root, str(common.args()["out"] or MODEL))


if __name__ == "__main__":
    main()
