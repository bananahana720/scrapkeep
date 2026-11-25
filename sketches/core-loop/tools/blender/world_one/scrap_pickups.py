"""Four shared, rigid salvage meshes and the cog, centred inside the field's 0.8 m cube.

blender -b --factory-startup --python-exit-code 1 -P scrap_pickups.py
One opaque vertex-colour surface per variant. Runtime supplies mint/amber tint
and the existing pickup emission, just as Brindle's folded casting does.

The cog is the money (story map: the one part every maker still needs): a worn steel spur gear
with bone-worn teeth and a charcoal hub, flat in the ground plane like the coin it is. It is
steel, not brass, because brass is Brindle's and the Fleet's tags and a deuteranope reads brass
as the relic's amber (visual assets audit finding 5, W1-21; an assumption Andrew can overturn).
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import common
import polish
from common import Part

SLOT = "field"
LIGHT = "ffffff"
MID = "c7ccc9"
DARK = "6c7872"
STEEL = "9aa0a0"
BONE = "d2c5a5"
CHARCOAL = "242a28"
COG_TEETH = 10


def finish(part, root):
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    obj = part.to_object(parent=root)
    print("PICKUP", part.name, common.tris(obj), len(obj.data.vertices))
    assert common.tris(obj) <= 270, part.name + " prop triangle budget"
    assert all(max(abs(c) for c in v.co) <= 0.4001 for v in obj.data.vertices), part.name + " bounds"
    return obj


def build():
    common.reset()
    common.SLOTS[SLOT] = {"vc": True, "rough": 0.8}
    polish.enable(detail=1, bevel=0, bevel_min=0.3, ao_strength=0.3, edge=0.1)
    root = common.empty("ScrapPickups")

    plate = Part("BentPlate")
    plate.bevel = 0.015
    plate.prism(SLOT, [(-.38, -.31), (.22, -.31), (.37, -.16),
                      (.34, .29), (-.24, .33), (-.38, .18)], .13,
                matrix=common.mtx((0, 0, -.08)), color=MID)
    plate.box(SLOT, (.51, .46, .07), loc=(-.035, .015, .065), rot=(0, .28, -.09), color=LIGHT)
    plate.box(SLOT, (.12, .43, .06), loc=(-.18, .01, .16), rot=(0, -.25, 0), color=MID)
    for x, y in [(.13, .13), (.12, -.16)]:
        plate.cyl(SLOT, .065, .065, .05, segs=6, loc=(x, y, .15), color=DARK)
    finish(plate, root)

    gear = Part("GearSegment")
    gear.ring(SLOT, .15, .30, .19, segs=9, arc=(-.3, 3.8), color=MID)
    for i in range(7):
        a = -.15 + i * .60
        gear.box(SLOT, (.12, .13, .19), loc=(.325 * math.cos(a), .325 * math.sin(a), 0),
                 rot=(0, 0, a), color=LIGHT)
    gear.ring(SLOT, .15, .19, .23, segs=9, arc=(-.3, 3.8), color=DARK)
    finish(gear, root)

    pipe = Part("PipeStub")
    pipe.ring(SLOT, .16, .23, .55, segs=8, color=MID)
    pipe.ring(SLOT, .16, .31, .07, segs=8, loc=(0, 0, -.27), color=LIGHT)
    pipe.ring(SLOT, .16, .255, .05, segs=8, loc=(0, 0, .27), color=DARK)
    for a in [0, math.pi * .67, math.pi * 1.33]:
        pipe.cyl(SLOT, .037, .037, .05, segs=6,
                 loc=(.26 * math.cos(a), .26 * math.sin(a), -.325), color=DARK)
    finish(pipe, root)

    bolts = Part("BoltCluster")
    bolts.prism(SLOT, [(-.31, -.24), (.26, -.24), (.34, .09), (.13, .26), (-.29, .21)],
                .10, matrix=common.mtx((0, 0, -.22)), color=DARK)
    for x, y, tilt in [(-.16, -.08, -.16), (.15, -.05, .15), (.01, .15, -.1)]:
        bolts.cyl(SLOT, .063, .063, .43, segs=6, loc=(x, y, -.015), rot=(0, tilt, 0), color=MID)
        bolts.cyl(SLOT, .12, .12, .12, segs=6, loc=(x + tilt * .16, y, .22), color=LIGHT)
        bolts.ring(SLOT, .068, .094, .04, segs=4, loc=(x, y, -.10), color=LIGHT)
    finish(bolts, root)

    cog = Part("Cog")
    cog.ring(SLOT, .085, .29, .12, segs=COG_TEETH, color=STEEL)
    for i in range(COG_TEETH):
        a = (i + .5) * math.tau / COG_TEETH
        cog.box(SLOT, (.1, .085, .1), loc=(.33 * math.cos(a), .33 * math.sin(a), 0), rot=(0, 0, a), color=BONE)
    cog.ring(SLOT, .05, .11, .17, segs=6, color=CHARCOAL)
    finish(cog, root)
    return root


if __name__ == "__main__":
    root = build()
    path = common.args()["out"] or os.path.join(common.MODELS, "world_one", "scrap_pickups.glb")
    common.export(root, path)
    print("SCRAP PICKUPS", common.tri_total(root), "T / 4 variants and the cog / 1 draw per pickup")
