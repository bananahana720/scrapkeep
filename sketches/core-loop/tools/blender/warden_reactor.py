"""KF5: the reactor relic's own body (design-v3/wardens/reactor.md sections 1, 5 and 9).

A fission pile that never shut down, clamped onto the water that used to cool it: a
squat ribbed drum in the clamp's jaws, three control-rod stacks that lift 0.6 m on the
pulse, a caged core dome on top, and uranium-glass seams that breathe. Its motion is
vertical. It replaces the shared clamp and the procedural reactor kit for this kind
(the way tools/blender/bosses/mind_body.py replaces them for the Mind); KF8 wires it.

Convention: +Y up in Godot (Blender +Z here, converted by the exporter), the ball's
approach along -Z (the body's front faces Godot +Z, Blender -Y), the origin at the
body's base centre where it meets the mounting. Metres.

Collider rule (warden.gd RADIUS 2.8, HALF_HEIGHT 1.6; warden_look.gd:31-32): below
2 m above the base nothing passes r = 2.8 m; above it no part passes r = 3.8 m, the
collider plus 1 m, in any view (the approach view's lateral reach is a subset). The
stacks rise past the collider's top on purpose: the sheet asks for 4 m stacks.
The weak point (WeakPoint, the core) sits at warden_kit.gd point_offset (DECK + 3.0)
plus HALF_HEIGHT: 6.8 m above the base, so warden.family_point_at() is unchanged.

Nodes (rigid, an empty hierarchy; each clip is one glTF animation of its length):
  WardenReactor > Drum (static: pedestal, skirt, drum core, iron bands, deck)
                  Jacket0..3 > SeamV0..3   the ribbed jacket quarters, centred at
                                           45/135/225/315 degrees, each with its seam
                  Stack0..2 > StackGlow0..2  control-rod stacks at 90/210/330 degrees
                  CageL, CageR             the core dome's lattice, split in x
                  WeakPoint                the core, r 0.9 at 6.8 m
                  JawL, JawR               the clamp's jaws at -X / +X, hinged on
                                           their bottom outer edge (lean = rotate Y)
                  GateL, GateR             spillway leaves on the back rim (dam_face)
                  PourLip                  the slag spout at the front foot (flume)
                  SteamRing                the pulse's steam ring, scale 0.02 at rest
                  Hardpoint                the crown eye, the body's own line point
                  SeamRing                 the pedestal's seam, under 2 m
Clips (section 5; name: length, blend): see CLIPS. chunk_lost moves Jacket0;
chunk_lost_1..3 are the same fall for Jacket1..3 (the mind_body phase_break idiom).
Seam light is emission on ancient_light; the clips carry its breath and its going dark
as the seams' scale (the runtime keeps owning the 0.8 / 5.0 emission levels).

Run under the 12 GiB prlimit address-space cap of tools/blender/PILOT-RIG.md:72:
  blender --background --threads 2 --python-exit-code 1 \
    --python sketches/core-loop/tools/blender/warden_reactor.py -- [--out file.glb] \
    [--count-only] [--render DIR]
--count-only builds and checks in Blender, exports nothing. --render DIR also writes
Cycles CPU look frames (20, 60, 150 m) for the blind pair reads.
Provenance: authored procedurally here from Blender primitives and bmesh operators;
no external meshes or textures. No light node is exported.
"""

import hashlib
import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
from common import Part  # noqa: E402

FPS = 30
# Section 5: clip -> (length s, blend s).
CLIPS = {
    "idle": (4.0, 1.0), "pulse_warn": (2.0, 2.0), "pulse": (0.3, 0.1), "active": (0.5, 0.5),
    "chunk_lost": (1.0, 0.8), "shrug": (0.4, 0.2), "gates_open": (0.6, 0.3), "pour": (1.0, 0.3),
    "final_quiet": (2.0, 2.0),
    "chunk_lost_1": (1.0, 0.8), "chunk_lost_2": (1.0, 0.8), "chunk_lost_3": (1.0, 0.8),
}
REQUIRED = ("idle", "pulse_warn", "pulse", "active", "chunk_lost", "shrug", "gates_open", "pour", "final_quiet")
BUDGET = {"tris": 5000, "verts": 9600, "draws": 32}
RADIUS = 2.8
HALF_HEIGHT = 1.6
LOW = 2.0
REACH = 1.0
CORE_Z = 2.2 + 3.0 + HALF_HEIGHT  # warden_kit.gd DECK + 3.0, plus HALF_HEIGHT
STACK_RISE = 0.6
JAW_LEAN = math.radians(14.0)  # warden_look.gd JAW_OPEN_DEGREES

ENAMEL = "petrol"
IRON = common.mix("charcoal", "petrol", 0.2)
COPPER = "copper"
SAND = common.mix("sandstone", "petrol", 0.22)
SAND_DARK = common.mix("sandstone", "charcoal", 0.45)
TOOTH = common.mix("sandstone", "bone", 0.35)  # the lightest value on the body: teeth over the dark jacket
ROD = common.mix("charcoal", "bone", 0.3)  # the ram's piston rod: thin and darker than its copper barrel, so the step reads in grey
DUST = common.mix("petrol", "sandstone", 0.3)

DRUM_R = 3.22
DRUM_Z = (2.5, 5.75)
JAW_R = (3.0, 3.78)
JAW_Z = (2.15, 6.45)
JAW_SPAN = math.radians(50)
STACK_R = 2.5
STACK_BASE = 5.95
STACK_ANGLES = (90.0, 210.0, 330.0)
SEAM_ANGLES = (60.0, 120.0, 240.0, 300.0)  # one per jacket quarter, two face the ball
CAGE_BASE = 6.3
CAGE_R = 1.45
CAGE_TOP = 7.9
HINGE = Vector((JAW_R[1], 0.0, JAW_Z[0]))
RAM_R = 2.48  # the rams' axis radius: barrel r 0.3 stays inside r 2.8 below 2 m
RAM_BARREL = (0.3, 1.4)  # the copper barrel's z range; the rod shows above it
RAM_DEG = 28.0  # each ram sits this far round from its jaw's middle, toward the front (Godot +Z)


# --- geometry helpers ------------------------------------------------------------------


def sweep(part, slot, profile, a0, a1, segs, color=None, caps=True):
    """Sweeps a closed (r, z) profile round the vertical axis from a0 to a1."""
    rows = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / segs
        ca, sa = math.cos(a), math.sin(a)
        rows.append([part.bm.verts.new((r * ca, r * sa, z)) for r, z in profile])
    faces = []
    n = len(profile)
    for k in range(segs):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j])))
    if caps:
        faces.append(part.bm.faces.new(list(reversed(rows[0]))))
        faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color)


def smooth(faces):
    for f in faces:
        f.smooth = True
    return faces


def finish(part, origin, parent, rot_z=None):
    """Outward normals, then the object. With rot_z the part was modelled in the +X
    frame round origin; the object turns it to its angle (so a local Y rotation is a
    lean about the tangent)."""
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    if rot_z is None:
        return part.to_object(origin, parent)
    obj = part.to_object(origin, parent)
    o = Vector(origin)
    turned = Vector((o.x * math.cos(rot_z) - o.y * math.sin(rot_z), o.x * math.sin(rot_z) + o.y * math.cos(rot_z), o.z))
    obj["world_origin"] = list(turned)
    obj.location = turned - Vector(parent["world_origin"])
    obj.rotation_euler = (0.0, 0.0, rot_z)
    return obj


def polar(r, deg, z):
    a = math.radians(deg)
    return Vector((r * math.cos(a), r * math.sin(a), z))


# --- parts ---------------------------------------------------------------------------------


def drum(root):
    p = Part("Drum")
    # Pedestal and feet: everything under 2 m stays inside r = 2.8.
    p.cyl("ancient_enamel", 2.2, 2.45, 2.0, 16, loc=(0, 0, 1.0), color=ENAMEL)
    for k in range(4):
        a = 45 + 90 * k
        foot = polar(1.95, a, 0.25)
        p.box("ancient_enamel", (0.9, 0.8, 0.5), loc=foot, rot=(0, 0, math.radians(a)), color=IRON)
    # KF7b: the jaws' rams, two under each jaw (its front and back quarter): a thick copper
    # barrel on an iron clevis foot, an iron gland at its mouth, the jaw's piston rod rising
    # out of it. Inside r 2.8 below 2 m.
    for a in (-RAM_DEG, RAM_DEG, 180.0 - RAM_DEG, 180.0 + RAM_DEG):
        p.box("ancient_enamel", (0.56, 0.5, 0.3), loc=polar(RAM_R, a, 0.15), rot=(0, 0, math.radians(a)), color=IRON)
        p.cyl("ancient_enamel", 0.3, 0.3, RAM_BARREL[1] - RAM_BARREL[0], 8,
              loc=polar(RAM_R, a, sum(RAM_BARREL) / 2), color=COPPER)
        p.cyl("ancient_enamel", 0.3, 0.22, 0.16, 8, loc=polar(RAM_R, a, RAM_BARREL[1] + 0.08), color=IRON)
    p.ring("rubber", 2.28, 2.5, 0.18, 16, loc=(0, 0, 1.5))
    # Skirt flares above 2 m to the drum.
    p.cyl("ancient_enamel", 2.45, DRUM_R, DRUM_Z[0] - LOW, 24, loc=(0, 0, (LOW + DRUM_Z[0]) / 2), color=ENAMEL,
          caps=False)
    p.cyl("ancient_enamel", DRUM_R, DRUM_R, DRUM_Z[1] - DRUM_Z[0], 24, loc=(0, 0, sum(DRUM_Z) / 2), color=IRON,
          caps=False)
    p.cyl("ancient_enamel", DRUM_R, 2.0, 0.55, 24, loc=(0, 0, DRUM_Z[1] + 0.275), color=DUST, caps=False)
    p.cyl("ancient_enamel", 2.0, 2.0, 0.1, 24, loc=(0, 0, DRUM_Z[1] + 0.6), color=IRON)
    # Dark iron bands hold the jacket; a collar seats the core.
    for z in (DRUM_Z[0] + 0.02, DRUM_Z[1] - 0.02):
        p.ring("rubber", 3.18, 3.64, 0.14, 16, loc=(0, 0, z))
    p.ring("rubber", 0.85, 1.25, 0.24, 16, loc=(0, 0, DRUM_Z[1] + 0.68))
    return finish(p, (0, 0, 0), root)


def jacket(root, k):
    """One ribbed cooling-jacket quarter, 90 degrees round its centre, with a lit seam."""
    mid = 45 + 90 * k
    a0, a1 = math.radians(mid - 45), math.radians(mid + 45)
    prof = [(3.2, DRUM_Z[0] + 0.1), (3.42, DRUM_Z[0] + 0.1)]
    for zc in (3.1, 4.1, 5.1):
        prof += [(3.42, zc - 0.16), (3.58, zc - 0.1), (3.58, zc + 0.1), (3.42, zc + 0.16)]
    prof += [(3.42, DRUM_Z[1] - 0.1), (3.2, DRUM_Z[1] - 0.1)]
    p = Part("Jacket%d" % k)
    sweep(p, "ancient_enamel", prof, a0, a1, 4, ENAMEL)  # KF7b: 4 segments pay for the jaws' teeth
    seam_deg = SEAM_ANGLES[k]
    # beam(w, h): w runs radial after the roll, h tangential.
    p.beam("ancient_enamel", polar(3.585, seam_deg, 2.7), polar(3.585, seam_deg, 5.55), 0.06, 0.26,
           color=IRON, roll=math.radians(seam_deg))
    centre = polar(3.3, mid, sum(DRUM_Z) / 2)
    obj = finish(p, centre, root)
    s = Part("SeamV%d" % k)
    s.beam("ancient_light", polar(3.625, seam_deg, 2.8), polar(3.625, seam_deg, 5.45), 0.05, 0.12,
           roll=math.radians(seam_deg))
    finish(s, polar(3.625, seam_deg, 4.125), obj)
    return obj


def stack(root, k):
    deg = STACK_ANGLES[k]
    c = polar(STACK_R, deg, 0)
    top = STACK_BASE + 4.0 + (0.4 if k == 0 else 0.0)
    glow0, glow1 = 7.3, top - 1.0
    p = Part("Stack%d" % k)
    p.cyl("ancient_enamel", 0.5, 0.42, 0.55, 10, loc=c + Vector((0, 0, STACK_BASE + 0.275)), color=ENAMEL)
    p.cyl("ancient_enamel", 0.34, 0.34, glow0 - STACK_BASE - 0.55, 12,
          loc=c + Vector((0, 0, (STACK_BASE + 0.55 + glow0) / 2)), color=ENAMEL)
    p.cyl("ancient_enamel", 0.4, 0.4, 0.14, 10, loc=c + Vector((0, 0, glow0 - 0.1)), color=COPPER)
    for j in range(4):
        a = math.radians(45 + 90 * j)
        off = Vector((0.36 * math.cos(a), 0.36 * math.sin(a), 0))
        p.beam("ancient_enamel", c + off + Vector((0, 0, glow0)), c + off + Vector((0, 0, glow1)), 0.08,
               color=IRON)
    p.cyl("ancient_enamel", 0.4, 0.4, 0.14, 10, loc=c + Vector((0, 0, glow1 + 0.1)), color=COPPER)
    p.cyl("ancient_enamel", 0.38, 0.36, top - glow1 - 0.45, 10, loc=c + Vector((0, 0, (glow1 + 0.17 + top - 0.28) / 2)),
          color=ENAMEL)
    p.cyl("ancient_enamel", 0.46, 0.4, 0.28, 10, loc=c + Vector((0, 0, top - 0.14)), color=IRON)
    obj = finish(p, c + Vector((0, 0, STACK_BASE)), root)
    g = Part("StackGlow%d" % k)
    smooth(g.cyl("ancient_light", 0.29, 0.29, glow1 - glow0, 10, loc=c + Vector((0, 0, (glow0 + glow1) / 2)),
                 caps=False))
    finish(g, c + Vector((0, 0, (glow0 + glow1) / 2)), obj)
    return obj


def cage_half(root, side):
    """Half the dome lattice: three meridian bars and two half rings, a lit base arc."""
    p = Part("CageR" if side > 0 else "CageL")
    centre = Vector((0, 0, CAGE_BASE))
    for j in range(3):
        a = (-60 + 60 * j) if side > 0 else (120 + 60 * j)
        pts = []
        for i in range(4):
            phi = (math.pi / 2) * i / 3 * 0.92
            r = CAGE_R * math.cos(phi)
            pts.append(polar(r, a, CAGE_BASE + (CAGE_TOP - CAGE_BASE) * math.sin(phi)))
        for u, v in zip(pts, pts[1:]):
            smooth(p.rod("bare_metal", u, v, 0.07, 5))
    arc = (-math.pi / 2, math.pi / 2) if side > 0 else (math.pi / 2, 3 * math.pi / 2)
    p.ring("bare_metal", CAGE_R - 0.08, CAGE_R + 0.1, 0.16, 8, loc=centre, arc=arc)
    p.ring("bare_metal", CAGE_R * 0.72 - 0.06, CAGE_R * 0.72 + 0.06, 0.1, 8,
           loc=centre + Vector((0, 0, (CAGE_TOP - CAGE_BASE) * 0.68)), arc=arc)
    p.ring("ancient_light", CAGE_R + 0.1, CAGE_R + 0.16, 0.07, 8, loc=centre + Vector((0, 0, 0.02)), arc=arc)
    return finish(p, centre, root)


def core(root):
    p = Part("WeakPoint")
    smooth(p.uv("ancient_light", 0.9, 12, 8, loc=(0, 0, CORE_Z)))
    return finish(p, (0, 0, CORE_Z), root)


def tooth(part, r0, r1, deg, z, width, height, color):
    """A triangular tooth in the jaw's arc at angle deg: base on z, point height above it
    (negative points down), extruded radially from r0 to r1."""
    a = math.radians(deg)
    t = Vector((-math.sin(a), math.cos(a), 0.0))
    n = Vector((math.cos(a), math.sin(a), 0.0))
    c = n * ((r0 + r1) / 2) + Vector((0.0, 0.0, z))
    m = Matrix(((t.x, 0.0, n.x, c.x), (t.y, 0.0, n.y, c.y), (t.z, 1.0, n.z, c.z), (0.0, 0.0, 0.0, 1.0)))
    part.prism("ancient_enamel", [(-width / 2, 0.0), (width / 2, 0.0), (0.0, height)], r1 - r0, matrix=m,
               color=color)


def jaw(root, side):
    """One cast jaw, modelled in the +X frame and turned to its side.

    2026-10-11 (w13 KF7b): the KF8-LOOK blind read saw these jaws as a tapered skirt and their
    copper rods as thin pipes: from the read cameras a 72 degree jaw sat on the drum's
    outline, light sandstone against light ground. So each jaw now wraps 100 degrees of the
    drum, where its sandstone lies over the dark jacket, as a toothed lower mandible under
    the drum's lower band and an upper one over its top edge, joined by the spine outside;
    the teeth (light, triangular, gaps of dark jacket between them) bite into the drum, and
    the mandible's ledge breaks the drum's outline at the side. A lug under the lower
    mandible carries the ram's piston rod, which rises out of its copper barrel on the base
    when the jaw leans open (the barrel is the Drum's)."""
    p = Part("JawR" if side > 0 else "JawL")
    r0, r1 = JAW_R
    z0, z1 = JAW_Z
    sweep(p, "ancient_enamel", [(2.95, z0), (r1, z0), (r1, z0 + 0.62), (3.3, z0 + 0.62)], -JAW_SPAN, JAW_SPAN, 10,
          SAND)
    sweep(p, "ancient_enamel", [(r0, z1 - 0.5), (r1, z1 - 0.5), (r1, z1), (r0, z1)], -JAW_SPAN, JAW_SPAN, 10, SAND)
    spine = math.radians(11)
    sweep(p, "ancient_enamel", [(3.58, z0 + 0.62), (r1, z0 + 0.62), (r1, z1 - 0.5), (3.58, z1 - 0.5)],
          -spine, spine, 2, SAND)
    span = math.degrees(JAW_SPAN)
    for k in range(6):
        deg = -span + 6.0 + (2 * span - 12.0) * k / 5
        if abs(deg) < 12.0:
            continue  # the spine's place
        tooth(p, 3.42, r1, deg, z0 + 0.6, 0.78, 0.8, TOOTH)
        tooth(p, 3.42, r1, deg, z1 - 0.48, 0.66, -0.62, TOOTH)
    # The rams' lugs and piston rods, under the lower mandible in its front and back quarters,
    # so a camera on either side of the drum sees one ram per jaw.
    for deg in (-RAM_DEG, RAM_DEG):
        p.box("ancient_enamel", (0.8, 0.7, 0.3), loc=polar(RAM_R + 0.05, deg, z0 + 0.05),
              rot=(0, 0, math.radians(deg)), color=SAND_DARK)
        p.cyl("ancient_enamel", 0.17, 0.17, z0 - 0.05 - RAM_BARREL[1] + 0.35, 8,
              loc=polar(RAM_R, deg, (z0 - 0.05 + RAM_BARREL[1] - 0.35) / 2), color=ROD)
    p.cyl("ancient_enamel", 0.12, 0.12, 0.75, 8, loc=(3.6, 0.0, z0 + 0.15), rot=(math.pi / 2, 0, 0),
          color=IRON)
    return finish(p, HINGE, root, rot_z=0.0 if side > 0 else math.pi)


def gate(root, side):
    """A spillway leaf lying on the back rim, hinged on its outer edge (+X frame)."""
    p = Part("GateR" if side > 0 else "GateL")
    p.box("ancient_enamel", (1.0, 1.3, 0.14), loc=(2.85 - 0.5, 0, 6.12), color=DUST)
    for y in (-0.45, 0.0, 0.45):
        p.box("ancient_enamel", (1.0, 0.1, 0.12), loc=(2.35, y, 6.24), color=IRON)
    p.cyl("ancient_enamel", 0.1, 0.1, 1.4, 8, loc=(2.85, 0, 6.08), rot=(math.pi / 2, 0, 0), color=COPPER)
    return finish(p, (2.85, 0, 6.08), root, rot_z=math.radians(90 + 42 * (-side)))


def pour_lip(root):
    """The slag spout at the front foot of the drum, hinged at the drum (+X frame)."""
    p = Part("PourLip")
    p.box("ancient_enamel", (0.5, 1.1, 0.12), loc=(3.5, 0, 2.55), color=IRON)
    for y in (-0.55, 0.55):
        p.box("ancient_enamel", (0.5, 0.1, 0.3), loc=(3.5, y, 2.66), color=ENAMEL)
    return finish(p, (3.25, 0, 2.6), root, rot_z=math.radians(270))


def steam(root):
    p = Part("SteamRing")
    res = bmesh.ops.create_cone(p.bm, cap_ends=False, segments=12, radius1=3.0, radius2=3.2, depth=0.3,
                                matrix=common.mtx((0, 0, 2.25)))
    smooth(p.paint(p._faces(res["verts"]), "glass"))
    obj = finish(p, (0, 0, 2.25), root)
    obj.scale = (0.02, 0.02, 0.02)  # hidden in the drum until the pulse blows it out
    return obj


def hardpoint(root):
    p = Part("Hardpoint")
    p.cyl("ancient_enamel", 0.42, 0.32, 0.25, 10, loc=(0, 0, CAGE_TOP + 0.05), color=IRON)
    p.ring("ancient_enamel", 0.22, 0.4, 0.14, 10, loc=(0, 0, CAGE_TOP + 0.55), rot=(math.pi / 2, 0, 0), color=ENAMEL)
    p.ring("ancient_light", 0.4, 0.45, 0.06, 10, loc=(0, 0, CAGE_TOP + 0.55), rot=(math.pi / 2, 0, 0))
    return finish(p, (0, 0, CAGE_TOP - 0.08), root)


def seam_ring(root):
    p = Part("SeamRing")
    p.ring("ancient_light", 2.46, 2.56, 0.07, 16, loc=(0, 0, 1.5))
    return finish(p, (0, 0, 1.5), root)


def build():
    common.reset()
    root = common.empty("WardenReactor")
    drum(root)
    for k in range(4):
        jacket(root, k)
    for k in range(3):
        stack(root, k)
    cage_half(root, -1)
    cage_half(root, 1)
    core(root)
    jaw(root, -1)
    jaw(root, 1)
    gate(root, -1)
    gate(root, 1)
    pour_lip(root)
    steam(root)
    hardpoint(root)
    seam_ring(root)
    bpy.context.view_layer.update()
    return root


# --- clips ----------------------------------------------------------------------------------


def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


QUIET_ORDER = ["SeamV0", "SeamV1", "SeamV2", "SeamV3", "StackGlow0", "StackGlow1", "StackGlow2", "SeamRing"]


def controls(clip):
    stacks = ["Stack%d" % k for k in range(3)]
    seams = ["SeamV%d" % k for k in range(4)]
    if clip == "idle":
        return stacks + seams
    if clip == "pulse_warn":
        return stacks + seams + ["CageL", "CageR", "WeakPoint"]
    if clip == "pulse":
        return stacks + ["SteamRing"]
    if clip == "active":
        return ["JawL", "JawR", "CageL", "CageR", "WeakPoint"]
    if clip.startswith("chunk_lost"):
        return ["Jacket%d" % (int(clip[-1]) if clip[-1].isdigit() else 0)]
    if clip == "shrug":
        return ["Hardpoint"]
    if clip == "gates_open":
        return ["GateL", "GateR"]
    if clip == "pour":
        return ["PourLip"]
    if clip == "final_quiet":
        return QUIET_ORDER + stacks + ["WeakPoint"]
    return []


def pose(clip, t, objs, rest):
    """Sets every control of the clip at normalised time t, from its rest."""
    for name in controls(clip):
        o = objs[name]
        loc, rot, scale = rest[name]
        o.location, o.rotation_euler, o.scale = loc.copy(), rot.copy(), scale.copy()
    u = smoothstep(t)
    if clip == "idle":
        for k in range(3):
            objs["Stack%d" % k].location.z += 0.025 * math.sin(math.tau * 2 * t + k * 2.1) - 0.025 * math.sin(k * 2.1)
        breath = 1.0 + 0.12 * (0.5 - 0.5 * math.cos(math.tau * t))
        for k in range(4):
            objs["SeamV%d" % k].scale = rest["SeamV%d" % k][2] * breath
    elif clip == "pulse_warn":
        for k in range(3):
            objs["Stack%d" % k].location.z += STACK_RISE * u
        for k in range(4):
            objs["SeamV%d" % k].scale = rest["SeamV%d" % k][2] * (1.0 + 0.3 * u)
        for name in ("CageL", "CageR"):
            objs[name].scale = rest[name][2] * (1.0 + 0.05 * u)
        objs["WeakPoint"].scale = rest["WeakPoint"][2] * (1.0 + 0.1 * u)
    elif clip == "pulse":
        for k in range(3):
            objs["Stack%d" % k].location.z += STACK_RISE * (1.0 - t * t)
        puff = math.sin(math.pi * min(t / 0.85, 1.0))
        s = 0.02 + 1.3 * puff
        objs["SteamRing"].scale = Vector((s, s, 0.02 + puff))
        objs["SteamRing"].location.z += 0.6 * t
    elif clip == "active":
        objs["JawL"].rotation_euler.y += JAW_LEAN * u
        objs["JawR"].rotation_euler.y += JAW_LEAN * u
        objs["CageL"].location.x -= 0.6 * u
        objs["CageL"].rotation_euler.y -= math.radians(20) * u
        objs["CageR"].location.x += 0.6 * u
        objs["CageR"].rotation_euler.y += math.radians(20) * u
        objs["WeakPoint"].scale = rest["WeakPoint"][2] * (1.0 + 0.3 * u)
    elif clip.startswith("chunk_lost"):
        k = int(clip[-1]) if clip[-1].isdigit() else 0
        o = objs["Jacket%d" % k]
        out = polar(1.0, 45 + 90 * k, 0)
        o.location += out * (1.4 * t) + Vector((0, 0, -4.6 * t * t))
        tangent = Vector((-out.y, out.x, 0))
        o.rotation_euler = (tangent * (-math.radians(35) * t)).to_tuple()
    elif clip == "shrug":
        kick = math.sin(math.pi * t)
        objs["Hardpoint"].location.z += 0.5 * kick
        objs["Hardpoint"].rotation_euler.x += math.radians(18) * kick
    elif clip == "gates_open":
        for name in ("GateL", "GateR"):
            objs[name].rotation_euler.y += math.radians(80) * u
    elif clip == "pour":
        objs["PourLip"].rotation_euler.y += math.radians(30) * math.sin(math.pi * t)
    elif clip == "final_quiet":
        for i, name in enumerate(QUIET_ORDER):
            start = 0.05 + 0.11 * i
            f = smoothstep((t - start) / 0.08)
            objs[name].scale = rest[name][2] * (1.0 - 0.99 * f)
        for k in range(3):
            objs["Stack%d" % k].location.z -= 0.15 * u
        objs["WeakPoint"].scale = rest["WeakPoint"][2] * (1.0 - 0.4 * smoothstep((t - 0.9) / 0.1))


def rest(root):
    return {o.name: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in common.tree(root)}


def reset_pose(root, snapshot):
    for o in common.tree(root):
        o.location, o.rotation_euler, o.scale = snapshot[o.name]
    bpy.context.view_layer.update()


def animate(root, snapshot):
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = 1 + int(round(max(d for d, _ in CLIPS.values()) * FPS))
    objs = {o.name: o for o in common.tree(root)}
    for clip, (duration, _blend) in CLIPS.items():
        frames = int(round(duration * FPS))
        for name in controls(clip):
            o = objs[name]
            o.animation_data_create()
            act = bpy.data.actions.new(clip + "_" + name)
            act.use_fake_user = True
            o.animation_data.action = act
            for f in range(frames + 1):
                pose(clip, f / frames, objs, snapshot)
                for path in ("location", "rotation_euler", "scale"):
                    o.keyframe_insert(data_path=path, frame=1 + f, group=name)
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for key in curve.keyframe_points:
                                key.interpolation = "LINEAR"
            o.animation_data.action = None
            track = o.animation_data.nla_tracks.new()
            track.name = clip
            strip = track.strips.new(clip, 1, act)
            strip.extrapolation = "NOTHING"
            track.mute = True
        reset_pose(root, snapshot)


# --- export and checks --------------------------------------------------------------------


def freeze_rest_export(path, snapshot):
    """NLA export can leave static defaults at the last evaluated pose; pin every node to
    its authored rest (mind_body.py freeze_rest_export) and re-encode the JSON sorted."""
    data = open(path, "rb").read()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    for node in doc["nodes"]:
        if node["name"] not in snapshot:
            continue
        loc, rot, scale = snapshot[node["name"]]
        q = rot.to_quaternion()
        node.pop("matrix", None)
        node["translation"] = [loc.x, loc.z, -loc.y]
        node["rotation"] = [q.x, q.z, -q.y, q.w]
        node["scale"] = [scale.x, scale.z, scale.y]
    encoded = json.dumps(doc, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    encoded += b" " * ((-len(encoded)) % 4)
    binary = data[20 + length:]
    open(path, "wb").write(struct.pack("<III", 0x46546C67, 2, 20 + len(encoded) + len(binary)) +
                           struct.pack("<II", len(encoded), 0x4E4F534A) + encoded + binary)


def export(root, path, snapshot):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(root):
        obj.select_set(True)
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = False
    bpy.context.view_layer.objects.active = root
    bpy.context.scene.frame_set(0)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_merge_animation="NLA_TRACK", export_anim_slide_to_zero=True,
                              export_frame_range=False, export_force_sampling=True,
                              export_optimize_animation_keep_anim_object=True, export_extras=False,
                              export_cameras=False, export_lights=False)
    for obj in common.tree(root):
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = True
    freeze_rest_export(path, snapshot)
    common.canonical_indices(path)
    reset_pose(root, snapshot)
    print("EXPORTED", path)


def glb_info(path):
    data = open(path, "rb").read()
    n = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + n])
    tris = verts = draws = 0
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            tris += doc["accessors"][prim["indices"]]["count"] // 3
            verts += doc["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws += 1
    clips = {}
    for anim in doc.get("animations", []):
        clips[anim["name"]] = max(doc["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
    lights = "KHR_lights_punctual" in doc.get("extensionsUsed", []) or any(
        "KHR_lights_punctual" in node.get("extensions", {}) for node in doc["nodes"])
    textures = [(img.get("name"), ) for img in doc.get("images", [])]
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "tris": tris, "verts": verts,
            "draws": draws, "clips": clips, "lights": lights, "images": textures,
            "nodes": sorted(node["name"] for node in doc["nodes"])}


def blender_counts(root):
    tris = draws = 0
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        tris += common.tris(o)
        draws += len({p.material_index for p in o.data.polygons})
    return tris, draws


def collider_rule(root):
    """Rest-pose vertices in the body frame: (lowest, max r under 2 m, max r above)."""
    bpy.context.view_layer.update()
    low = high = 0.0
    bottom = math.inf
    worst = ("", "")
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            r = math.hypot(w.x, w.y)
            bottom = min(bottom, w.z)
            if w.z <= LOW:
                if r > low:
                    low, worst = r, (o.name, worst[1])
            elif r > high:
                high, worst = r, (worst[0], o.name)
    return bottom, low, high, worst


def check(root, info=None):
    """Fails loud on the budget, the clips, the collider rule and any light node."""
    problems = []
    tris, draws = blender_counts(root)
    bottom, low, high, worst = collider_rule(root)
    print("REACTOR_BLENDER tris=%d draws=%d bottom=%.3f low_r=%.3f (%s) high_r=%.3f (%s)" %
          (tris, draws, bottom, low, worst[0], high, worst[1]))
    if tris > BUDGET["tris"] or draws > BUDGET["draws"]:
        problems.append("budget (blender) tris %d draws %d" % (tris, draws))
    if bottom < -1e-4:
        problems.append("geometry below the base origin: %.3f" % bottom)
    if low > RADIUS + 1e-4:
        problems.append("below 2 m r %.3f passes the collider %.1f (%s)" % (low, RADIUS, worst[0]))
    if high > RADIUS + REACH + 1e-4:
        problems.append("above 2 m r %.3f passes collider + 1 m (%s)" % (high, worst[1]))
    if info is not None:
        print("REACTOR_GLB tris=%d verts=%d draws=%d bytes=%d sha256=%s" %
              (info["tris"], info["verts"], info["draws"], info["bytes"], info["sha256"]))
        for key in ("tris", "verts", "draws"):
            if info[key] > BUDGET[key]:
                problems.append("budget %s %d > %d" % (key, info[key], BUDGET[key]))
        for clip in REQUIRED:
            got = info["clips"].get(clip)
            want = CLIPS[clip][0]
            print("REACTOR_CLIP %s %s want %.2f" % (clip, "missing" if got is None else "%.3f" % got, want))
            if got is None or abs(got - want) > 0.05:
                problems.append("clip %s length %s, want %.2f" % (clip, got, want))
        if info["lights"]:
            problems.append("a light node in the GLB")
        if info["images"]:
            problems.append("textures in the GLB: %s" % info["images"])
    if problems:
        raise SystemExit("warden_reactor check FAILED: " + "; ".join(problems))
    print("warden_reactor check: PASS")


# --- look frames ------------------------------------------------------------------------------


def look_frames(root, out_dir):
    """Cycles CPU frames of the body at rest at 20, 60 and 150 m, front three-quarter at
    the ball's eye height range; plus the hero turntable. The coordinator's in-engine
    look rows are in look_subjects.json beside these frames (KF8 wires the body)."""
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.cycles.seed = 1979
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("LookSky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=800, location=(0, 0, 0))
    ground = bpy.context.object
    ground.data.materials.append(common._flat("LookGround", "sandstone"))
    sun = bpy.data.lights.new("LookSun", "SUN")
    sun.energy = 3.5
    sun_obj = bpy.data.objects.new("LookSun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), 0, math.radians(30))
    cam_data = bpy.data.cameras.new("LookCam")
    cam_data.angle = math.radians(62)
    cam = bpy.data.objects.new("LookCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    shots = []
    for dist in (20, 60, 150):
        eye = Vector((dist * math.sin(math.radians(25)), -dist * math.cos(math.radians(25)), 3.0 + dist * 0.12))
        target = Vector((0, 0, 4.5))
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, "reactor_%dm.png" % dist)
        bpy.ops.render.render(write_still=True)
        shots.append(scene.render.filepath)
    print("LOOK_FRAMES", " ".join(shots))
    return shots


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = common.args()
    root = build()
    snapshot = rest(root)
    animate(root, snapshot)
    reset_pose(root, snapshot)
    if "--count-only" in argv:
        check(root)
        return
    out = a["out"] or common.default_out("warden_reactor")
    export(root, out, snapshot)
    info = glb_info(out)
    print("REACTOR_NODES", ",".join(info["nodes"]))
    check(root, info)
    if a["render"]:
        look_frames(root, a["render"])


main()
