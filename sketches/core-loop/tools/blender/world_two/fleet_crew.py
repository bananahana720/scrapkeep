"""The shared anonymous two-eared Fleet crew head (kite drone's read), for the world 2 and 3
bodies. Godot metres; the face looks along `facing` (a unit XZ direction, default +Z).
`hat` is "helmet" (the Dig's miner's helmet with a bone headlamp), "goggles" (the Highdraft's
flying goggles) or None. All on one fleet_paint surface so the crew flashes with its enemy.
"""
import math

from mathutils import Vector


def g(x, y, z):
    return (x, -z, y)


def head(part, at, r=0.3, facing=(0.0, 1.0), hat=None, slot="fleet_paint"):
    at = Vector(at)
    f = Vector((facing[0], 0.0, facing[1])).normalized()
    s = Vector((f.z, 0.0, -f.x))
    yaw = math.atan2(f.x, f.z)

    def p(v):
        return g(*v)

    part.uv(slot, r, u=8, v=5, loc=p(at), color="oxide")
    muzzle = at + f * (r * 0.68) + Vector((0, -r * 0.28, 0))
    part.uv(slot, r * 0.52, u=6, v=4, loc=p(muzzle), scale=(0.95, 0.95, 0.65), rot=(0, 0, yaw), color="bone")
    part.box(slot, (r * 0.3, r * 0.3, r * 0.22), loc=p(muzzle + f * (r * 0.45) + Vector((0, r * 0.08, 0))),
             rot=(0, 0, yaw), color="charcoal")
    for side in (-1, 1):
        part.cyl(slot, r * 0.36, 0.0, r * 0.95, segs=5, loc=p(at + s * (side * r * 0.62) + Vector((0, r * 1.0, 0))),
                 color="oxide")
        if hat != "goggles":
            part.box(slot, (r * 0.16, r * 0.16, r * 0.2),
                     loc=p(at + f * (r * 0.9) + s * (side * r * 0.36) + Vector((0, r * 0.18, 0))),
                     rot=(0, 0, yaw), color="charcoal")
    if hat == "helmet":
        part.cyl(slot, r * 1.06, r * 0.75, r * 0.6, segs=8, loc=p(at + Vector((0, r * 0.62, 0))), color="charcoal")
        part.cyl(slot, r * 1.3, r * 1.3, r * 0.08, segs=8, loc=p(at + Vector((0, r * 0.36, 0))), color="charcoal")
        part.cyl(slot, r * 0.28, r * 0.28, r * 0.2, segs=6, loc=p(at + f * (r * 1.0) + Vector((0, r * 0.68, 0))),
                 rot=(math.pi / 2, 0, yaw), color="bone")
    elif hat == "goggles":
        part.beam(slot, Vector(p(at + s * (-r * 1.02) + Vector((0, r * 0.2, 0)))),
                  Vector(p(at + s * (r * 1.02) + Vector((0, r * 0.2, 0)))), r * 0.22, r * 0.22, color="charcoal")
        for side in (-1, 1):
            part.cyl(slot, r * 0.26, r * 0.26, r * 0.22, segs=6,
                     loc=p(at + f * (r * 0.86) + s * (side * r * 0.36) + Vector((0, r * 0.2, 0))),
                     rot=(math.pi / 2, 0, yaw), color="a8aaa3")
