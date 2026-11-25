"""MWA: two continuous cast arches, open bays and interrupted launch rail.

Run Blender headless with --out FILE and optionally --render DIR (Cycles CPU).
Original hive, six drones, queen target and hatch remain coordinator-owned.
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import warden_mantle_meltdown as mwa


def ribs(parent):
    p = mwa.common.Part("BroodRibs")
    for x in (-1.35, -.05):
        rows = []
        for k in range(13):
            a = math.pi * k / 12
            z = 2.22 * math.cos(a)
            y = .35 + 2.12 * math.sin(a)
            rows.append([(x-.09, y, z), (x+.09, y, z),
                         (x+.09, y+.18*math.sin(a), z+.18*math.cos(a)),
                         (x-.09, y+.18*math.sin(a), z+.18*math.cos(a)), (x-.09, y, z)])
        mwa.strip(p, rows, ["ancient_enamel"]*4, [mwa.ENAMEL]*4)
        for row in (rows[0][:-1], list(reversed(rows[-1][:-1]))):
            mwa.face(p, row, "ancient_enamel", mwa.ENAMEL)
        for slot, lo, hi, behind in (("rubber", .04, .14, .094), ("ancient_light", .065, .115, .096)):
            for k in range(5):
                points = []
                for a, t in ((65+50*k/5, lo), (65+50*(k+1)/5, lo),
                             (65+50*(k+1)/5, hi), (65+50*k/5, hi)):
                    angle = math.radians(a)
                    points.append((x-behind, .35+(2.12+t)*math.sin(angle), (2.22+t)*math.cos(angle)))
                mwa.face(p, points, slot)
    mwa.box(p, "ancient_enamel", (1.48, .18, .18), (-.70, .44, 2.28), mwa.ENAMEL)
    mwa.bmesh.ops.recalc_face_normals(p.bm, faces=list(p.bm.faces))
    upper = [f for f in p.bm.faces if f.material_index == p.slots.index("ancient_enamel")
             and f.normal.z > .8 and f.calc_center_median().z > 2.2]
    for f in upper[::2][:4]:
        p.paint([f], "ancient_enamel", mwa.common.mix("petrol", "bone", .38))
    return mwa.finish(p, parent)


def rail(parent):
    p = mwa.common.Part("BroodLaunchRail")
    for sign in (-1, 1):
        mwa.box(p, "ancient_enamel", (.24, .35, 1.16), (.53, .85, sign*1.32), mwa.ENAMEL)
    mwa.box(p, "ancient_enamel", (.24, .16, 1.48), (.53, .265, 0), mwa.ENAMEL)
    for z, y in ((-1.1, .85), (0, .29), (1.1, .85)):
        for sign in (-1, 1):
            mwa.box(p, "ancient_enamel", (.07, .025, .62), (.655, y+sign*.1125, z), mwa.ENAMEL)
            mwa.box(p, "ancient_enamel", (.07, .20, .035), (.655, y, z+sign*.2925), mwa.ENAMEL)
        points = [(.66, y-.10, z-.275), (.66, y-.10, z+.275),
                  (.66, y+.10, z+.275), (.66, y+.10, z-.275)]
        mwa.face(p, points, "mantle_tool", None,
                 [(0, 0), (.55/mwa.UV_PITCH, 0), (.55/mwa.UV_PITCH, .2/mwa.UV_PITCH), (0, .2/mwa.UV_PITCH)])
    return mwa.finish(p, parent)


def main():
    mwa.setup()
    root = mwa.common.empty("MantleBrood")
    mount = mwa.common.empty("MountBody", parent=root)
    ribs(mount)
    rail(mount)
    opts = mwa.common.args()
    path = opts["out"] or mwa.common.default_out("warden_mantle_brood")
    mwa.export_checked(root, path, (1300, 1400, 5))
    if opts["render"]:
        mwa.preview(path, opts["render"], "hive", "brood")


if __name__ == "__main__":
    main()
