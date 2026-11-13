# The ball looks behind --ball-look=<id> (src/presentation/ball_looks.gd); today's shells are
# untouched. Andrew picked the cutaway on 13 Nov 2026 (ruling dm); the gyro and the bell stay as
# the candidates he saw.
#
#   gyro      three crossed hoops tumble around an open seat; nothing stands before the pilot
#   bell      a salvaged diving bell: painted prow, glass back and porthole, three tread hoops
#   cutaway   a solid plated ball; the game's shader opens a window on the side facing the camera
#
# The gyro and the bell are one shared shell each: Core (rolls with the ball), Pod (level, turns
# to the heading) and the Hoberman cockpit's seat and controls. The game takes only the Core of
# the cutaway and puts it on each pilot's own shell, so the pilot's kit, weapon ring and cockpit
# stay; cutaway_c2 to cutaway_c5 are what each heft class bolts onto that plating.
#
#   blender -b -P tools/blender/ball_looks.py -- [--out <dir>]     writes ball_look_<id>.glb
# Blender +Z is up, +Y forward; glTF becomes Godot +Y up, -Z forward.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402

AXES = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}


def _on_ring(axis, angle, radius):
    c, s = math.cos(angle) * radius, math.sin(angle) * radius
    return {"x": Vector((0, c, s)), "y": Vector((c, 0, s)), "z": Vector((c, s, 0))}[axis]


def hoop(part, axis, r_in, r_out, width, slot, color=None, marks=0, mark_slot="class_accent", mark_color=None):
    """A great-circle hoop about one axis, with blocks on its sides that show the turn."""
    part.ring(slot, r_in, r_out, width, 48, rot=AXES[axis], color=color)
    for k in range(marks):
        a = (k + 0.5) * math.tau / marks
        mid = _on_ring(axis, a, (r_in + r_out) / 2 - 0.004)
        rot = {"x": (a, 0, 0), "y": (0, -a, 0), "z": (0, 0, a)}[axis]
        size = {"x": (width + 0.03, 0.16, r_out - r_in - 0.012), "y": (r_out - r_in - 0.012, width + 0.03, 0.16),
                "z": (r_out - r_in - 0.012, 0.16, width + 0.03)}[axis]
        part.box(mark_slot, size, loc=mid, rot=rot, color=mark_color)


def hub(part, direction, r_in, r_out, radius=0.11):
    """A copper drum with a bolt circle where two hoops cross: the part a hand could undo.
    Bolts ride a slot the Core already has, to stay inside the shell class's ten draws."""
    n = Vector(direction).normalized()
    sb._drum(part, n, radius, r_in, r_out, 8, "copper")
    e1, e2 = sb._frame(n)
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        part.bolt(n * r_out + (e1 * math.cos(a) + e2 * math.sin(a)) * radius * 0.62, n, r=0.018, h=0.012, slot="rubber")


def assemble(name, core_part, pod_part, extras=(), weapon_ring=True):
    root = common.empty("BallLook" + name)
    # A hoop's corners and side blocks reach past its radius; the whole Core scales to the collider.
    far = max(v.co.length for v in core_part.bm.verts)
    if far > sb.CORE_LIMIT:
        for v in core_part.bm.verts:
            v.co *= sb.CORE_LIMIT / far
    core = core_part.to_object((0, 0, 0), root)
    pod = pod_part.to_object((0, 0, 0), root)
    for item in extras:
        item.to_object((0, 0, 0), pod)
    if weapon_ring:
        ring = sb.weapon_ring().to_object((0, 0, 0), pod)
        common.empty("WeaponMount", (0, sb.RING_BAND[1] + 0.13, sb.RING_BAND[3]), ring)
    for cname, point in sb.CONTROLS.items():
        common.empty("Control." + cname, point, pod)
    lap = sb.bpy_object(pod, "Control.LapBar")
    for hname, point in sb.LAP_HANDS.items():
        common.empty(hname, point, lap)
    for cname, point in zip(("Slot2", "Slot3"), sb.BANK):
        common.empty("Control." + cname, point, pod)
    dome = common.empty("Dome", (0, 0, 0), pod)
    common.empty("Pilot", (0, 0, 0), dome)
    return root, core


def gyro():
    """A fairground gyro ride the crews kept running: three hoops, widest outermost."""
    core = Part("Core")
    hoop(core, "x", 0.875, 0.985, 0.20, "rubber", marks=8)
    hoop(core, "x", 0.80, 0.875, 0.24, "paint", color="bone")
    hoop(core, "y", 0.86, 0.975, 0.11, "paint", color="petrol", marks=6, mark_slot="paint", mark_color="bone")
    hoop(core, "z", 0.86, 0.965, 0.07, "copper")
    for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
        hub(core, d, 0.84, 0.985)
    # Turned an eighth about the upright axis, so the rest pose leaves the back and front open.
    twist = Matrix.Rotation(math.radians(45), 4, "Z")
    for v in core.bm.verts:
        v.co = twist @ v.co
    sb._sharpen(core)
    return assemble("Gyro", core, sb.cockpit("bone"))


def bell():
    """The dam's inspection bell: a level hull with a painted prow and a glass back."""
    core = Part("Core")
    for axis in ("x", "y", "z"):
        hoop(core, axis, 0.915, 0.985, 0.13, "rubber", marks=6)
    for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
        hub(core, d, 0.90, 0.985, 0.10)
    twist = Matrix.Rotation(math.radians(45), 4, "Z")
    for v in core.bm.verts:
        v.co = twist @ v.co
    sb._sharpen(core)
    hull = Part("Hull")
    radius = 0.86
    faces = hull.uv("paint", radius, 32, 16, color="petrol")
    port = Vector((0, 0.94, 0.34)).normalized()
    glass = []
    for f in faces:
        c = f.calc_center_median().normalized()
        if c.y < -0.02 or c.dot(port) > math.cos(math.radians(27)):
            glass.append(f)
        elif abs(c.z + 0.12) < 0.10:
            hull.paint([f], "paint", "bone")
        elif c.z < -0.62:
            hull.paint([f], "paint", "oxide")
    hull.paint(glass, "glass")
    # A bone liner inside the prow, so the pilot's back stands against a light wall.
    liner = hull.uv("paint", radius - 0.015, 32, 16, color="bone")
    drop = [f for f in liner if f.calc_center_median().y < -0.02
            or f.calc_center_median().normalized().dot(port) > math.cos(math.radians(27))]
    keep = [f for f in liner if f not in set(drop)]
    bmesh.ops.reverse_faces(hull.bm, faces=keep)
    bmesh.ops.delete(hull.bm, geom=drop, context="FACES")
    # The bolted frame where plate meets glass, the porthole's ring, and a hatch wheel on top.
    hull.ring("copper", radius - 0.01, radius + 0.035, 0.07, 40, loc=(0, -0.02, 0), rot=AXES["y"])
    for k in range(16):
        a = k * math.tau / 16
        n = Vector((math.cos(a), 0, math.sin(a)))
        hull.bolt(n * (radius + 0.035) + Vector((0, -0.02, 0)), n, r=0.02, h=0.014, slot="copper")
    e1, e2 = sb._frame(port)
    ring_r = radius * math.sin(math.radians(27))
    ring_at = port * radius * math.cos(math.radians(27))
    for k in range(20):
        a0, a1 = k * math.tau / 20, (k + 1) * math.tau / 20
        hull.beam("copper", ring_at + (e1 * math.cos(a0) + e2 * math.sin(a0)) * ring_r + port * 0.015,
                  ring_at + (e1 * math.cos(a1) + e2 * math.sin(a1)) * ring_r + port * 0.015, 0.05)
    hull.rod("copper", (0, 0.1, radius - 0.01), (0, 0.1, radius + 0.03), 0.03, 8)
    hull.bm.normal_update()
    for f in hull.bm.faces:
        f.smooth = len(f.verts) <= 4 and abs(f.calc_center_median().length - radius) < 0.03
    return assemble("Bell", core, sb.cockpit("bone"), extras=[hull], weapon_ring=False)


def cutaway():
    """A solid plated ball: petrol gores, a bone belt, oxide caps, tread pads and bolts.
    An equipped paint takes the petrol gores only, so the dark gores, belt and caps keep the pattern."""
    core = Part("Core")
    faces = core.uv("paint", 0.965, 32, 16, rot=AXES["x"], color="petrol")
    dark = common.mix("petrol", "charcoal", 0.45)
    for f in faces:
        c = f.calc_center_median().normalized()
        gore = int((math.atan2(c.y, c.z) + math.pi) / math.tau * 8) % 2
        if abs(c.x) > 0.80:
            core.paint([f], "paint", "oxide", alpha=0.0)
        elif abs(c.x) < 0.14:
            core.paint([f], "paint", "bone", alpha=0.0)
        elif gore:
            core.paint([f], "paint", dark, alpha=0.0)
    for side in (-1, 1):
        hub(core, (side, 0, 0), 0.95, 0.985, 0.16)
        for k in range(8):
            a = (k + 0.5) * math.tau / 8
            n = Vector((side * 0.52, math.cos(a) * 0.854, math.sin(a) * 0.854)).normalized()
            sb._drum(core, n, 0.075, 0.955, 0.985, 6, "rubber")
    # Bone blocks on the belt show the turn. The class colour comes with each pilot's kit on the
    # level Pod: the ready glow swaps class_accent materials, which the window's shader would hide.
    for k in range(8):
        a = k * math.tau / 8
        n = Vector((0, math.cos(a), math.sin(a)))
        core.box("paint", (0.20, 0.10, 0.03), loc=n * 0.972, rot=(a - math.pi / 2, 0, 0), color="oxide")
    sb._sharpen(core)
    return assemble("Cutaway", core, sb.cockpit("bone"))


PLATE_RADIUS = 0.983


def _patch(part, slot, keep, color=None):
    """Plating a finger above the ball's own: the faces of a sphere whose centre passes keep()."""
    faces = part.uv(slot, PLATE_RADIUS, 32, 16, rot=AXES["x"], color=color)
    drop = [f for f in faces if not keep(f.calc_center_median().normalized())]
    bmesh.ops.delete(part.bm, geom=drop, context="FACES")


def _gore(c):
    return int((math.atan2(c.y, c.z) + math.pi) / math.tau * 8) % 2


def cutaway_heft(n):
    """What a heft class bolts onto the plated ball, each one slot: II copper hoops, III bone
    armour over the dark gores, IV tread cleats on the belt, V copper caps with a stud crown."""
    core = Part("Core")
    if n == 2:
        _patch(core, "copper", lambda c: 0.38 < abs(c.x) < 0.56)
    elif n == 3:
        _patch(core, "bare_metal", lambda c: 0.56 < abs(c.x) < 0.80 and _gore(c) == 1)
    elif n == 4:
        _patch(core, "rubber", lambda c: abs(c.x) < 0.14 and int((math.atan2(c.y, c.z) + math.pi) / math.tau * 16) % 2 == 0)
    else:
        _patch(core, "copper", lambda c: abs(c.x) > 0.90)
        for side in (-1, 1):
            for k in range(8):
                a = k * math.tau / 8
                n_ = Vector((side * 0.82, math.cos(a) * 0.572, math.sin(a) * 0.572)).normalized()
                sb._drum(core, n_, 0.045, 0.96, 0.983, 6, "copper")
    sb._sharpen(core)
    root = common.empty("BallLookCutawayC%d" % n)
    return root, core.to_object((0, 0, 0), root)


LOOKS = {"gyro": gyro, "bell": bell, "cutaway": cutaway}
for _n in (2, 3, 4, 5):
    LOOKS["cutaway_c%d" % _n] = lambda n=_n: cutaway_heft(n)


def main():
    a = common.args()
    out = a["out"] or os.path.join(common.MODELS, "world_one")
    for look, build in LOOKS.items():
        common.reset()
        root, core = build()
        radius = common.max_radius(core)
        print("BALL_LOOK %s core radius %.4f limit %.3f triangles %d" % (look, radius, sb.CORE_LIMIT, common.tri_total(root)))
        if radius > sb.CORE_LIMIT + 1e-4:
            raise SystemExit("core out of the collider for " + look)
        common.export(root, os.path.join(out, "ball_look_%s.glb" % look))


main()
