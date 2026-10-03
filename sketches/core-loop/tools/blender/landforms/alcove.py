"""Eroded bedding arch, six-metre clear flat floor and varnished recess."""
import math
import os
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_strata as kit

NAME = "alcove"


def front_depth(x, z):
    bases = [0.3, 2.4, 5.8, 8.5, 9.4, 10.2, 11.2]
    level = max((h for h in bases if h <= z + 1e-5), default=0.3)
    inset = 0.22 if z - level < 0.18 else 0
    return min(-2.9, max(-3.98, -3.6 + inset + 0.30 * math.sin(x * 0.7)))


def build():
    root = kit.common.empty(NAME)
    p = kit.common.Part(NAME + "_rock")
    # Each contour runs from lower left up over the lip to lower right.
    inner = [(-8.1, 0.3), (-8, 3), (-7.5, 5.4), (-6, 7.4), (-3.5, 8.2),
             (0, 8.5), (3.5, 8.3), (6.5, 7.0), (8, 4.4), (8.2, 0.3)]
    outer = [(-10, 0.3), (-9.9, 4), (-9.8, 8), (-8.9, 11), (-4.2, 11.9),
             (0, 12), (4.7, 11.7), (9.1, 10.6), (10, 6), (10, 0.3)]
    # Lip projects to -4; inner back is +2, giving exactly 6 m of open floor.
    rows = []
    for depth in [-3.98, -3.7, -2.1, 0.2, 2, 4]:
        inner_row, outer_row = [], []
        for i, ((x, z), (ox, oz)) in enumerate(zip(inner, outer)):
            roof_recede = 0.32 * (depth + 4) / 8 if 2 <= i <= 7 else 0
            inner_row.append(p.bm.verts.new((x * (1 - 0.015 * (depth + 4)), depth, z + roof_recede)))
            weathering = (depth + 3.98) / 7.98
            outer_row.append(p.bm.verts.new((ox * (1 - 0.045 * weathering), depth,
                                           oz - (0.6 * weathering * math.sin(i * 0.9) ** 2 if oz > 6 else 0))))
        rows.append((inner_row, outer_row))
    for j in range(len(rows) - 1):
        a, b = rows[j], rows[j + 1]
        for i in range(9):
            kit.face(p, [a[0][i], b[0][i], b[0][i + 1], a[0][i + 1]],
                     kit.blend(kit.SAND, kit.VARNISH, 0.45 + j * 0.06), smooth=True)
            kit.face(p, [a[1][i], a[1][i + 1], b[1][i + 1], b[1][i]], kit.BUFF)
    for j in (0, len(rows) - 1):
        a = rows[j]
        for i in range(9):
            kit.face(p, [a[0][i], a[0][i + 1], a[1][i + 1], a[1][i]],
                     kit.blend(kit.SAND, kit.RED, 0.24 if i % 3 else 0.5))
    # Close the two side feet. The doorway stays open.
    for i in (0, 9):
        for j in range(len(rows) - 1):
            a, b = rows[j], rows[j + 1]
            kit.face(p, [a[0][i], a[1][i], b[1][i], b[0][i]])
    # Cut true horizontal bedding planes into the shell. Alter only its front;
    # the roof and jamb boundaries deform with it, so the opening remains closed.
    cuts = [2.4, 5.8, 8.5, 9.4, 10.2, 11.2]
    for h in cuts:
        for z in [h, h + 0.18, h + 0.22]:
            kit.bmesh.ops.bisect_plane(p.bm, geom=list(p.bm.verts) + list(p.bm.edges) + list(p.bm.faces),
                                      dist=0.00001, plane_co=(0, 0, z), plane_no=(0, 0, 1))
    for center in (-6, 0, 6):
        for x in (center - 0.35, center, center + 0.35):
            kit.bmesh.ops.bisect_plane(p.bm, geom=list(p.bm.verts) + list(p.bm.edges) + list(p.bm.faces),
                                      dist=0.00001, plane_co=(x, 0, 0), plane_no=(1, 0, 0))
    for v in p.bm.verts:
        if v.co.y < -3.9:
            v.co.y = front_depth(v.co.x, v.co.z)
    p.bm.normal_update()
    for f in p.bm.faces:
        if all(v.co.y < -3.1 for v in f.verts):
            z = f.calc_center_median().z
            tone = kit.blend(kit.SAND, kit.BUFF if int(z * 2) % 3 else kit.RED, 0.3)
            p.paint([f], "paint", tone)
            for loop in f.loops:
                x, y, zz = loop.vert.co
                stain = max(max(0, 1 - abs(x - center) / 0.35) *
                            max(0, min(1, (zz - 9.1 - 0.2 * math.sin(center)) / 1.4))
                            for center in (-6, 0, 6))
                if zz > 11.4:
                    stain = 0
                loop[p.col] = kit.common.rgba(kit.blend(tone, kit.VARNISH, stain * 0.65))
    kit.attach(root, kit.finish(p))
    floor = kit.common.Part("alcove_floor")
    floor.box("paint", (20, 8, 0.3), (0, 0, 0.15), color=kit.BUFF)
    kit.attach(root, kit.finish(floor))
    back = kit.common.Part("alcove_recess_back")
    back.box("paint", (16, 2, 8), (0, 3, 4.3), color=kit.blend(kit.SAND, kit.VARNISH, 0.65))
    kit.attach(root, kit.finish(back))
    # The projecting lips stay inside the specified eight-metre depth.
    for o in root.children:
        for v in o.data.vertices:
            if v.co.y < -4:
                v.co.y = -4
    return root


if __name__ == "__main__":
    kit.deliver(build, NAME)
