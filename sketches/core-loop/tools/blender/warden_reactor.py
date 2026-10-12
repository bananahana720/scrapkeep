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
import re
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
ROD = "bone"  # KF7c round 3: the ram's piston rod, polished, the lightest value on the ram
COPPER_DARK = common.mix("copper", "charcoal", 0.6)  # KF7c round 3: the ram's fat barrel, dark under its rod
DUST = common.mix("petrol", "sandstone", 0.3)

# 2026-10-11 (w13 KF7c): the drum is slimmer (core 2.42, jacket ribs and bands to 2.62) so the
# jaws stand off it with a dark gap and their teeth stand proud of everything above and below them
# inside the 3.8 m reach; the stacks, cage and core keep their places.
DRUM_R = 2.42
DRUM_Z = (2.5, 5.75)
JACKET_R = (2.5, 2.6)  # the jacket's skin and its ribs
BAND_R = (2.38, 2.62)
# 2026-10-11 (w13 KF7c fix round): the drum stays at r 2.42, not KF7b's 3.22. Measured reason: the
# jaw must stand 0.3 m off the jacket (SIL_JAW_STANDOFF) and its teeth 0.5 m past every other part's
# outline (SIL_TOOTH_OUT_M), all inside the 3.8 m reach. A 3.22 drum puts the jaw's inner face at
# 3.52 at least and its outer face at 3.6, which leaves a tooth 0.2 m of reach: the teeth check
# cannot pass. Here: jacket ribs 2.6, jaw 2.98 to 3.2, teeth to 3.78 (0.58 proud of the lips).
JAW_R = (2.98, 3.2)  # the jaw's inner and outer face: 0.36 m off the bands
JAW_Z = (2.4, 6.9)  # the jaw's foot and crown
JAW_SPAN = math.radians(50)
# KF7c fix round: the gate read KF7c's frame jaw (two thin mandibles and two upright cheeks) as
# scaffold posts. Each jaw is now a mouth: a lower and an upper lip, 0.5 m thick at the middle,
# whose inner edges curve to meet at the jaw's two corners, so face on the jaw is a lens-shaped
# maw of dark drum ringed by light sandstone, with three big light fangs on each lip pointing at
# the other row. No upright member stands anywhere in the jaw.
LIP_H = 0.5
JAW_SEGS = 10
MOUTH_Z = sum(JAW_Z) / 2  # where the lips meet at the corners
MOUTH_G = (JAW_Z[1] - JAW_Z[0]) / 2 - LIP_H  # the maw's half height at the middle
# The fangs, per lip: (jaw-local degrees, lower height, upper height, base width). The middle
# fangs are the biggest; tip to tip about 0.9 m of dark drum shows between the rows. Each root
# runs out past the lip to r 3.78, so from the side every fang breaks the jaw's outline.
TEETH = ((0.0, 1.4, 1.25, 1.15), (-27.0, 1.0, 0.95, 0.9), (27.0, 1.0, 0.95, 0.9))
TOOTH_R = (2.98, 3.78, 3.25)  # inner face, root's outer face, point's outer face
TOOTH_W_OUT = 0.6  # the root's outer face width
# The side fangs' roots stay in at r 3.3: proud, their corners stood at 3.57 across the front read
# camera and hid the middle fangs' roots behind the same outline.
TOOTH_SIDE_R = 3.3
STACK_R = 2.5
STACK_BASE = 5.95
STACK_ANGLES = (90.0, 210.0, 330.0)
SEAM_ANGLES = (60.0, 120.0, 240.0, 300.0)  # one per jacket quarter, two face the ball
CAGE_BASE = 6.3
CAGE_R = 1.45
CAGE_TOP = 7.9
HINGE = Vector((JAW_R[1], 0.0, JAW_Z[0]))
# 2026-10-11 (w13 KF7b fix round): the second read still found no ram: the barrels stood in
# front of a pedestal as wide as their own circle, copper on dark enamel in the skirt's shade,
# and the rods were dark. Now the pedestal is a narrow stem, so each ram stands free with
# ground showing between it and the stem; the barrel is a thick copper cylinder on a sandstone
# clevis foot, and a bright steel rod rises out of it into the jaw's lug. The rams sit 45
# degrees round from each jaw's middle, so the over_shoulder read camera sees two in profile.
# 2026-10-11 (w13 KF7c): KF7b's rams sat inside the drum's outline and in its shade. Now the stem
# is r 1.25 to 1.1, the barrels are fatter (r 0.4, out to 2.78) and stand from the ground to 1.55
# m under a light gland collar, and the light rod slants out of the gland past the drum's edge to
# a lug under the jaw (outer face r 3.5): from the side the barrel stands clear of the stem.
# 2026-10-11 (w13 KF7c fix round): the gate read the upright barrels as copper legs on the ground,
# and the diagonal pistons that replaced them read as "angled legs", "short legs", "stubby feet" in
# the third blind read: a part that runs from the drum down toward the ground reads as a leg.
# 2026-10-11 (w13 KF7c round 3): the rams point the way they strike. The reactor has no ram attack
# (src/combat: no ram or piston strike); its rams' only stroke is the jaw lean, the stagger's
# 'active' clip here and warden_look.gd JAW_OPEN_DEGREES 14: each jaw turns about its bottom
# outer edge (HINGE, a line along the jaw's local Y) and every point of its crown moves straight
# out along the jaw's local +X, level. So each jaw has one level ram along its local +X, over the
# crown at one corner: a fat dark copper barrel on a post standing on the drum's top rim, a light
# gland collar at the barrel's mouth, the thin light rod out of it (2.47 to 1 in diameter) to a
# light eye pinned on a dark clevis rising from the jaw's crown. The barrel and post are the
# Drum's; the rod, eye and lug are the jaw's, so on the lean the rod slides out of the gland along
# the ram's own axis. JawR's ram rides its front corner (Godot +Z) and JawL's its back corner (the
# jaw frame turned a half turn): from the three_q read camera both stand past the body's left and
# right edges, and from over_shoulder they lie side on over the drum. A ram on the jaw's middle
# bearing was tried first: from over_shoulder its eye stood over the upper middle fang and took
# that fang's outline (teeth count 2 of 4). Nothing of a ram stands under 6.5 m.
PED_R = (1.0, 1.1)  # the pedestal stem's bottom and top radius
RAM_Z = 7.6  # the ram's axis height, over the jaw crown (6.9)
RAM_SIDE = 2.2  # the ram's offset from the jaw's middle plane, toward JawR's front (jaw frame -Y)
# Per side (1 JawR, -1 JawL), along the jaw frame's X: the barrel's inner end and its mouth, and
# the rod's inner end. JawR's ram rides the front, where it crosses the drum's front to the middle
# and its rod runs back inside the barrel past the full lean's 1.26 m stroke. JawL's rides the back,
# where its barrel must stay 0.95 m off the back stack's axis (Stack0, Godot z -2.5), so it is
# shorter and its rod shows 0.36 m out of the gland at the full lean.
RAM_BARREL = {1: (-0.6, 1.3), -1: (0.95, 1.75)}
RAM_ROD_IN = {1: 0.1, -1: 1.0}
RAM_BARREL_R = 0.42
RAM_GLAND = (0.15, 0.48)  # the gland collar's length past the barrel's mouth and its radius
RAM_EYE_X = 2.62  # the eye's centre along X: its far corner is r 3.74 at RAM_SIDE
RAM_ROD_R = 0.17
RAM_EYE_R = 0.26  # the eye's radius; its pin runs along the jaw's Y, 0.38 m long
RAM_POST_X = {1: 0.35, -1: 1.3}  # the barrel's post, standing on the drum's top rim
RAM_CLEVIS = (2.36, 2.88, 0.3)  # the lug block under the eye: inner and outer X, width along Y
# 2026-10-11 (w13 KF7c): the silhouette check (see "silhouette check" below).
# The read cameras: (name, eye offset in radii, look_subjects.gd constant and row). Each looks along
# -normalize(offset) in the body frame (coordinator ruling at the KF7c fix round: no probed staging
# yaw; a read direction tuned until the body passes is not a read). KF7c round 3: the offsets are
# world axes; the check turns them into the body frame by look_subjects.gd WARDEN_BODY_STAGE_YAW,
# read from that file at build time, the yaw look_harness stages and asserts (see sil_cameras).
SIL_CAMERAS = [
    ("over_shoulder", (0.0, 0.6, 2.0), "WARDEN_BODY_CAMERAS row 0"),
    ("three_q", (-1.97, 0.42, 1.31), "WARDEN_BODY_CAMERAS row 3"),
    ("under", (-1.2, -0.45, -1.06), "WARDEN_BODY_CAMERAS row 4"),
]
SIL_APPROACH = ("over_shoulder", "three_q")
# Thresholds (KF7c packet; fixed, never lowered inside a unit).
SIL_RAM_OUT_M = 0.5  # KF7c round 3: raised from 0.4 to hold the level rams (three_q 0.570 and 0.603)
SIL_RAM_OUT_FRAC = 0.3
SIL_RAM_COUNT = 2
SIL_RAM_MIN_Y = 4.0  # KF7c round 3: a ram's lowest vertex, metres over the base (7d87f33: 0.075, red)
SIL_RAM_STROKE_DEG = 20.0  # KF7c round 3: a ram's axis against its jaw's stroke (7d87f33: 30.3, red)
SIL_TOOTH_OUT_M = 0.5
SIL_TOOTH_COUNT = 4
# KF7c round 3 note: the 3D tooth height line (SIL_TOOTH_MIN_H) guards the teeth's size: the outline
# count measures how far a tooth's root breaks the outline sideways, not how tall the tooth is.
SIL_TOOTH_MIN_H = 0.6
SIL_TOOTH_PER_ROW = 3
SIL_JAW_STANDOFF = 0.3


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


def sweep_var(part, slot, profile_at, a0, a1, segs, color=None):
    """sweep() with a profile that changes with the angle: profile_at(a) gives the (r, z) loop."""
    rows = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / segs
        ca, sa = math.cos(a), math.sin(a)
        rows.append([part.bm.verts.new((r * ca, r * sa, z)) for r, z in profile_at(a)])
    faces = []
    n = len(rows[0])
    for k in range(segs):
        for i in range(n):
            j = (i + 1) % n
            faces.append(part.bm.faces.new((rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j])))
    faces.append(part.bm.faces.new(list(reversed(rows[0]))))
    faces.append(part.bm.faces.new(rows[-1]))
    return part.paint(faces, slot, color)


def maw(a):
    """(lower lip top, upper lip bottom) at jaw-local angle a: an ellipse that closes at the corners."""
    g = MOUTH_G * math.sqrt(max(0.0, 1.0 - (a / JAW_SPAN) ** 2))
    return MOUTH_Z - g, MOUTH_Z + g


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


def ram_point(x, side=1):
    """A point on a ram's level axis, x along the jaw frame's X (side 1: JawR, -1: JawL, the jaw
    frame turned a half turn)."""
    return Vector((side * x, -side * RAM_SIDE, RAM_Z))


# --- silhouette check (w13 KF7c) -----------------------------------------------------------
# 2026-10-11 (w13 KF7c): two blind reads failed in one class: the named parts did not break the
# body's outline from the read cameras. This check measures that on the rest-pose mesh and fails
# the build, so geometry is tuned against a number and a regression fails here, not in a read.
# The read directions copy sketches/core-loop/tools/look_subjects.gd (WARDEN_BODY_CAMERAS /
# WARDEN_BODY_MIND_CAMERAS: eye offset in radii from the warden_bounds centre), and the view
# direction is -normalize(offset) in the body frame. An orthographic projection along the view
# direction stands in for the harness's perspective at about two radii. Thresholds are fixed by the
# KF7c packet; never lower them to pass a candidate (raising one to hold a gain is allowed).


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(a):
    n = math.sqrt(_dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n)


def sil_axes(offset):
    """(view, up, right) in the body's Godot frame for an eye offset: view = -normalize(offset)."""
    view = _unit((-offset[0], -offset[1], -offset[2]))
    up0 = (0.0, 1.0, 0.0) if abs(view[1]) <= 0.9 else (0.0, 0.0, -1.0)
    up = _unit(_sub(up0, tuple(view[i] * _dot(up0, view) for i in range(3))))
    return view, up, _cross(up, view)


def sil_project(points, axes):
    _, up, right = axes
    return [(_dot(p, right), _dot(p, up)) for p in points]


def _turn(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def sil_hull(pts):
    """Monotone chain convex hull, counter-clockwise, no repeated end point."""
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in pts))
    if len(pts) < 3:
        return pts
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and _turn(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and _turn(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def _seg_dist(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = dx * dx + dy * dy
    t = 0.0 if n == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / n))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def _inside(p, hull):
    n = len(hull)
    return n >= 3 and all(_turn(hull[i], hull[(i + 1) % n], p) >= -1e-9 for i in range(n))


def sil_outside(p, hull):
    """0 inside the hull, else the distance to its boundary."""
    if _inside(p, hull):
        return 0.0
    n = len(hull)
    return min(_seg_dist(p, hull[i], hull[(i + 1) % n]) for i in range(n))


def _cross_segs(a, b, c, d):
    return (_turn(a, b, c) * _turn(a, b, d) < 0) and (_turn(c, d, a) * _turn(c, d, b) < 0)


def sil_hull_gap(h1, h2):
    """Minimal distance between two convex polygons, 0 when they touch or overlap."""
    if any(_inside(p, h2) for p in h1) or any(_inside(p, h1) for p in h2):
        return 0.0
    n1, n2 = len(h1), len(h2)
    for i in range(n1):
        for j in range(n2):
            if _cross_segs(h1[i], h1[(i + 1) % n1], h2[j], h2[(j + 1) % n2]):
                return 0.0
    best = min(_seg_dist(p, h2[j], h2[(j + 1) % n2]) for p in h1 for j in range(n2))
    return min(best, min(_seg_dist(p, h1[i], h1[(i + 1) % n1]) for p in h2 for i in range(n1)))


def sil_part_outside(part_pts, outline_pts, axes):
    """(outside_m, outside_frac) of a part's vertices against the outline's projected hull."""
    hull = sil_hull(sil_project(outline_pts, axes))
    d = [sil_outside(p, hull) for p in sil_project(part_pts, axes)]
    return max(d), sum(1 for x in d if x > 1e-6) / len(d)


# 2026-10-11 (w13 KF7c round 3): one frame for this check and the render. The read cameras' eye
# offsets are world axes, and look_harness stages the body at look_subjects.gd
# WARDEN_BODY_STAGE_YAW, so the check reads that yaw from the same file at build time and turns each
# offset into the body frame by it (no copied or probed yaw). SIL_CAMERAS stays the readable copy:
# a row that drifts from look_subjects.gd fails the build.
LOOK_SUBJECTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "look_subjects.gd")


def sil_frame(subject, const):
    """(stage yaw in degrees or None, {camera: world eye offset}) from look_subjects.gd."""
    with open(LOOK_SUBJECTS) as f:
        text = f.read()
    m = re.search(r"const WARDEN_BODY_STAGE_YAW := \{([^}]*)\}", text)
    yaws = {k: float(v) for k, v in re.findall(r'"(\w+)":\s*(-?[0-9.]+)', m.group(1))} if m else {}
    start = text.find("const %s := [" % const)
    rows = {}
    if start >= 0:
        block = text[start:text.index("]]", start) + 2]
        rows = {k: tuple(float(x) for x in v.split(",")) for k, v in re.findall(r'\["(\w+)", Vector3\(([^)]*)\)', block)}
    return yaws.get(subject), rows


def sil_turn(v, deg):
    """v turned deg about +Y (Godot frame)."""
    a = math.radians(deg)
    return (v[0] * math.cos(a) + v[2] * math.sin(a), v[1], -v[0] * math.sin(a) + v[2] * math.cos(a))


def sil_cameras(subject, const, fails):
    """[(name, body-frame offset)] for SIL_CAMERAS, a CHECK line each; a missing stage yaw or a copy
    that drifts from look_subjects.gd appends to fails."""
    yaw, rows = sil_frame(subject, const)
    print("CHECK silhouette_stage_yaw %s %s from look_subjects.gd WARDEN_BODY_STAGE_YAW" % (subject, yaw))
    if yaw is None:
        print("SILHOUETTE FAIL %s frame stage_yaw missing wants a WARDEN_BODY_STAGE_YAW row" % subject)
        fails.append("stage yaw")
        yaw = 0.0
    out = []
    for name, off, src in SIL_CAMERAS:
        live = rows.get(name)
        if live is None or max(abs(a - b) for a, b in zip(live, off)) >= 1e-6:
            print("SILHOUETTE FAIL %s frame %s offset=%s wants look_subjects.gd %s %s" % (subject, name, off, const, live))
            fails.append("camera drift " + name)
        body = sil_turn(off, -yaw)
        view = _unit((-body[0], -body[1], -body[2]))
        print("CHECK silhouette_dir %s offset=(%.3f, %.3f, %.3f) from look_subjects.gd %s stage_yaw=%.1f body_view=(%.3f, %.3f, %.3f)"
              % (name, off[0], off[1], off[2], src, yaw, view[0], view[1], view[2]))
        out.append((name, body))
    return out


def sil_say(ok, body, camera, part, metric, value, want):
    print("SILHOUETTE %s %s %s %s %s=%.3f wants %s" % ("ok" if ok else "FAIL", body, camera, part, metric, value, want))
    return ok



# The parts the check names: each tagged vertex carries its label's code in an integer layer
# "sil" that travels with the vertex into the mesh (an index range does not: to_mesh reorders), and
# silhouette() drops the attribute again before export.
TAGS = []
SIL_LAYER = "sil"


def tagged(part, label, fn, *a, **kw):
    layer = part.bm.verts.layers.int.get(SIL_LAYER) or part.bm.verts.layers.int.new(SIL_LAYER)
    faces = fn(*a, **kw)  # every Part builder returns the faces it made
    if label not in TAGS:
        TAGS.append(label)
    for f in faces:
        for v in f.verts:
            v[layer] = TAGS.index(label) + 1
    return faces


def ram_label(deg):
    return "ram%03d" % (int(round(deg)) % 360)


def _labelled_points(root):
    bpy.context.view_layer.update()
    pts, labels, faces = [], [], []
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        base = len(pts)
        mw = o.matrix_world
        codes = o.data.attributes.get(SIL_LAYER)
        for i, v in enumerate(o.data.vertices):
            w = mw @ v.co
            pts.append((w.x, w.z, -w.y))  # Blender to the Godot frame
            code = codes.data[i].value if codes is not None else 0
            labels.append(TAGS[code - 1] if code else o.name)
        for poly in o.data.polygons:
            faces.append((o.name, [base + i for i in poly.vertices]))
    return pts, labels, faces


def _jaw_standoff(pts, labels, faces, jaw):
    """The least radial gap from the jaw slab's vertices to the drum surface (Drum without the rams,
    the jacket quarters and their seams) at the same height and bearing; faces stand in for the
    surface by their outermost vertex, so a chord never reads as a gap."""
    drum = set(["Drum"] + ["Jacket%d" % k for k in range(4)] + ["SeamV%d" % k for k in range(4)])
    spans = []
    for name, idx in faces:
        if name not in drum or any(labels[i].startswith("ram") for i in idx):
            continue
        ys = [pts[i][1] for i in idx]
        rs = [math.hypot(pts[i][0], pts[i][2]) for i in idx]
        angs = [math.atan2(pts[i][2], pts[i][0]) for i in idx]
        spans.append((min(ys), max(ys), max(rs), angs))
    worst = math.inf
    for p, lab in zip(pts, labels):
        if lab != "jawslab_" + jaw:
            continue
        r = math.hypot(p[0], p[2])
        a = math.atan2(p[2], p[0])
        surface = 0.0
        for y0, y1, rmax, angs in spans:
            if not (y0 - 0.05 <= p[1] <= y1 + 0.05):
                continue
            rel = [math.remainder(b - a, math.tau) for b in angs]
            if min(abs(x) for x in rel) < math.radians(3.0) or (min(rel) <= 0.0 <= max(rel) and max(rel) - min(rel) < math.pi):
                surface = max(surface, rmax)
        worst = min(worst, r - surface)
    return worst


def _ram_stroke_angle(points):
    """Degrees between a ram's axis (the centroid of its innermost 30% of radial extent to that of its
    outermost 30%) and the stroke of its outer end: the direction that point moves as its jaw leans
    out about its hinge line (the jaw is rigid: the line through HINGE along the jaw frame's Y, the
    jaw being JawR on the +X side, JawL on the -X side). Godot frame; unsigned."""
    rs = [math.hypot(p[0], p[2]) for p in points]
    lo, hi = min(rs), max(rs)

    def centroid(sel):
        return tuple(sum(p[i] for p in sel) / len(sel) for i in range(3))

    ci = centroid([p for p, r in zip(points, rs) if r <= lo + 0.3 * (hi - lo)])
    co = centroid([p for p, r in zip(points, rs) if r >= hi - 0.3 * (hi - lo)])
    axis = _unit(_sub(co, ci))
    a = 0.0 if co[0] >= 0.0 else math.pi  # the Blender bearing of its jaw's middle
    hinge = (JAW_R[1] * math.cos(a), JAW_Z[0], -JAW_R[1] * math.sin(a))
    tangent = (-math.sin(a), 0.0, -math.cos(a))
    stroke = _unit(_cross(tangent, _sub(co, hinge)))
    return math.degrees(math.acos(min(1.0, abs(_dot(axis, stroke)))))


def silhouette(root):
    """Prints a SILHOUETTE line per rule; returns the failures."""
    pts, labels, faces = _labelled_points(root)
    for o in common.tree(root):
        if o.type == "MESH" and o.data.attributes.get(SIL_LAYER) is not None:
            o.data.attributes.remove(o.data.attributes[SIL_LAYER])
    fails = []
    axes = {name: sil_axes(off) for name, off in sil_cameras("warden_body_reactor", "WARDEN_BODY_CAMERAS", fails)}
    rams = sorted(set(l for l in labels if l.startswith("ram")))
    teeth = sorted(set(l for l in labels if l.startswith("tooth_")))
    by_label = {}
    for p, l in zip(pts, labels):
        by_label.setdefault(l, []).append(p)
    best_ram = best_tooth = (-1, "")
    for cam in SIL_APPROACH:
        good_rams = good_teeth = 0
        for part in rams + teeth:
            outline = [p for p, l in zip(pts, labels) if l != part]
            out_m, frac = sil_part_outside(by_label[part], outline, axes[cam])
            print("SILHOUETTE row reactor %s %s outside_m=%.3f outside_frac=%.3f" % (cam, part, out_m, frac))
            if part.startswith("ram") and out_m >= SIL_RAM_OUT_M and frac >= SIL_RAM_OUT_FRAC:
                good_rams += 1
            if part.startswith("tooth_") and out_m >= SIL_TOOTH_OUT_M:
                good_teeth += 1
        best_ram = max(best_ram, (good_rams, cam))
        best_tooth = max(best_tooth, (good_teeth, cam))
    if not sil_say(best_ram[0] >= SIL_RAM_COUNT, "reactor", best_ram[1], "rams",
                   "count(outside_m>=%.1f,outside_frac>=%.1f)" % (SIL_RAM_OUT_M, SIL_RAM_OUT_FRAC), best_ram[0],
                   ">=%d on over_shoulder or three_q" % SIL_RAM_COUNT):
        fails.append("rams")
    # 2026-10-11 (w13 KF7c round 3): the outline count above passed the 7d87f33 rams, which read as
    # legs. Two 3D lines hold the new form: every ram stands clear of the ground (its lowest vertex
    # over SIL_RAM_MIN_Y, so no ram runs down toward the ground plane), and each ram's axis lies within
    # SIL_RAM_STROKE_DEG of its jaw's stroke (the way its outer end moves when the jaw leans about
    # HINGE), so the body's ram and the jaw lean it drives share one line. Both read the mesh.
    for ram in rams:
        low = min(p[1] for p in by_label[ram])
        if not sil_say(low >= SIL_RAM_MIN_Y, "reactor", "3d", ram, "min_y_m", low, ">=%.1f" % SIL_RAM_MIN_Y):
            fails.append(ram + " low")
        angle = _ram_stroke_angle(by_label[ram])
        if not sil_say(angle <= SIL_RAM_STROKE_DEG, "reactor", "3d", ram, "stroke_angle_deg", angle,
                       "<=%.1f" % SIL_RAM_STROKE_DEG):
            fails.append(ram + " stroke")
    if not sil_say(best_tooth[0] >= SIL_TOOTH_COUNT, "reactor", best_tooth[1], "teeth",
                   "count(outside_m>=%.1f)" % SIL_TOOTH_OUT_M, best_tooth[0],
                   ">=%d on over_shoulder or three_q" % SIL_TOOTH_COUNT):
        fails.append("teeth")
    rows = {}
    for t in teeth:
        ys = [p[1] for p in by_label[t]]
        if not sil_say(max(ys) - min(ys) >= SIL_TOOTH_MIN_H, "reactor", "3d", t, "height_m", max(ys) - min(ys),
                       ">=%.1f" % SIL_TOOTH_MIN_H):
            fails.append(t + " height")
        rows.setdefault(t.rsplit("_", 1)[0], []).append(t)
    for row, members in sorted(rows.items()):
        if not sil_say(len(members) <= SIL_TOOTH_PER_ROW, "reactor", "3d", row, "teeth", len(members),
                       "<=%d" % SIL_TOOTH_PER_ROW):
            fails.append(row + " count")
    for jaw in ("JawL", "JawR"):
        gap = _jaw_standoff(pts, labels, faces, jaw)
        if not sil_say(gap >= SIL_JAW_STANDOFF, "reactor", "3d", jaw, "standoff_m", gap, ">=%.1f" % SIL_JAW_STANDOFF):
            fails.append(jaw + " standoff")
    return fails


# --- parts ---------------------------------------------------------------------------------


def drum(root):
    p = Part("Drum")
    # Pedestal: a narrow stem; everything under 2 m stays inside r = 2.8.
    p.cyl("ancient_enamel", PED_R[0], PED_R[1], 2.0, 16, loc=(0, 0, 1.0), color=ENAMEL)
    # KF7c round 3: each jaw's ram barrel, level over the crown at a corner (see RAM_Z): a dark
    # iron post on the drum's top band, the fat dark copper barrel on it with a dark iron band at
    # its mouth, and the light gland collar (the rod, eye and lug are the jaw's).
    for side, jaw_deg in ((1, 0.0), (-1, 180.0)):
        label = ram_label(jaw_deg)
        x0, x1 = RAM_BARREL[side]
        post = ram_point(RAM_POST_X[side], side)
        p.box("ancient_enamel", (0.3, 0.3, RAM_Z - DRUM_Z[1]), loc=(post.x, post.y, (RAM_Z + DRUM_Z[1]) / 2),
              color=IRON)
        tagged(p, label, p.rod, "ancient_enamel", ram_point(x0, side), ram_point(x1, side), RAM_BARREL_R, 10,
               color=COPPER_DARK)
        tagged(p, label, p.rod, "ancient_enamel", ram_point(x1 - 0.12, side), ram_point(x1, side),
               RAM_BARREL_R + 0.03, 10, color=IRON)
        tagged(p, label, p.rod, "ancient_enamel", ram_point(x1, side), ram_point(x1 + RAM_GLAND[0], side),
               RAM_GLAND[1], 10, color=TOOTH)
    p.ring("rubber", PED_R[1] - 0.05, PED_R[1] + 0.14, 0.18, 16, loc=(0, 0, 1.5))
    # Skirt flares above 2 m from the stem to the drum, an overhang the jaws' lower mandibles
    # stand clear of.
    p.cyl("ancient_enamel", PED_R[1], DRUM_R, DRUM_Z[0] - LOW, 24, loc=(0, 0, (LOW + DRUM_Z[0]) / 2), color=ENAMEL,
          caps=False)
    p.cyl("ancient_enamel", DRUM_R, DRUM_R, DRUM_Z[1] - DRUM_Z[0], 24, loc=(0, 0, sum(DRUM_Z) / 2), color=IRON,
          caps=False)
    p.cyl("ancient_enamel", DRUM_R, 2.0, 0.55, 24, loc=(0, 0, DRUM_Z[1] + 0.275), color=DUST, caps=False)
    p.cyl("ancient_enamel", 2.0, 2.0, 0.1, 24, loc=(0, 0, DRUM_Z[1] + 0.6), color=IRON)
    # Dark iron bands hold the jacket; a collar seats the core.
    for z in (DRUM_Z[0] + 0.02, DRUM_Z[1] - 0.02):
        p.ring("rubber", BAND_R[0], BAND_R[1], 0.14, 16, loc=(0, 0, z))
    p.ring("rubber", 0.85, 1.25, 0.24, 16, loc=(0, 0, DRUM_Z[1] + 0.68))
    return finish(p, (0, 0, 0), root)


def jacket(root, k):
    """One ribbed cooling-jacket quarter, 90 degrees round its centre, with a lit seam."""
    mid = 45 + 90 * k
    a0, a1 = math.radians(mid - 45), math.radians(mid + 45)
    skin, rib = JACKET_R
    prof = [(DRUM_R - 0.02, DRUM_Z[0] + 0.1), (skin, DRUM_Z[0] + 0.1)]
    for zc in (3.1, 4.1, 5.1):
        prof += [(skin, zc - 0.16), (rib, zc - 0.1), (rib, zc + 0.1), (skin, zc + 0.16)]
    prof += [(skin, DRUM_Z[1] - 0.1), (DRUM_R - 0.02, DRUM_Z[1] - 0.1)]
    p = Part("Jacket%d" % k)
    sweep(p, "ancient_enamel", prof, a0, a1, 4, ENAMEL)  # KF7b: 4 segments pay for the jaws' teeth
    seam_deg = SEAM_ANGLES[k]
    # beam(w, h): w runs radial after the roll, h tangential.
    p.beam("ancient_enamel", polar(rib + 0.005, seam_deg, 2.7), polar(rib + 0.005, seam_deg, 5.55), 0.06, 0.26,
           color=IRON, roll=math.radians(seam_deg))
    centre = polar(skin, mid, sum(DRUM_Z) / 2)
    obj = finish(p, centre, root)
    s = Part("SeamV%d" % k)
    s.beam("ancient_light", polar(rib + 0.045, seam_deg, 2.8), polar(rib + 0.045, seam_deg, 5.45), 0.05, 0.12,
           roll=math.radians(seam_deg))
    finish(s, polar(rib + 0.045, seam_deg, 4.125), obj)
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
    p.cyl("ancient_enamel", 0.32, 0.3, top - glow1 - 0.45, 10, loc=c + Vector((0, 0, (glow1 + 0.17 + top - 0.28) / 2)),
          color=ENAMEL)
    p.cyl("ancient_enamel", 0.36, 0.32, 0.28, 10, loc=c + Vector((0, 0, top - 0.14)), color=IRON)
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


def tooth(part, r0, r1, deg, z, width, height, color, r_tip=None, width_out=None):
    """A fang in the jaw's arc at angle deg: a base width wide at r0 (width_out at r1) on z, its
    point height above it (negative points down) as an edge from r0 to r_tip, so the outer face
    slopes back toward the drum and only the root stands proud of the lip (KF7c). The narrower
    outer root keeps its corners inside the 3.8 m reach. Returns its faces."""
    a = math.radians(deg)
    t = Vector((-math.sin(a), math.cos(a), 0.0))
    n = Vector((math.cos(a), math.sin(a), 0.0))
    up = Vector((0.0, 0.0, 1.0))
    base = Vector((0.0, 0.0, z))
    r_tip = r1 if r_tip is None else r_tip
    bm = part.bm
    wo = width if width_out is None else width_out
    b = [bm.verts.new(base + n * r + t * s) for r, s in ((r0, -width / 2), (r1, -wo / 2), (r1, wo / 2),
                                                         (r0, width / 2))]
    tip = [bm.verts.new(base + n * r + up * height) for r in (r0, r_tip)]
    faces = [bm.faces.new(b), bm.faces.new((b[1], b[2], tip[1])), bm.faces.new((b[3], b[0], tip[0])),
             bm.faces.new((b[0], b[1], tip[1], tip[0])), bm.faces.new((b[2], b[3], tip[0], tip[1]))]
    return part.paint(faces, "ancient_enamel", color)


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
    when the jaw leans open (the barrel is the Drum's).
    2026-10-11 (w13 KF7c fix round): now two lips that close at the corners round a lens-shaped
    maw, three fangs per lip (see LIP_H and TEETH), the rams' lugs on the corners."""
    p = Part("JawR" if side > 0 else "JawL")
    r0, r1 = JAW_R
    z0, z1 = JAW_Z
    # 2026-10-11 (w13 KF7c fix round): the jaw is a mouth standing 0.36 m off the drum (see LIP_H).
    slab = "jawslab_" + p.name
    tagged(p, slab, sweep_var, p, "ancient_enamel",
           lambda a: [(r0 + 0.05, z0), (r1, z0 + 0.35), (r1, maw(a)[0]), (r0, maw(a)[0])], -JAW_SPAN, JAW_SPAN, JAW_SEGS, SAND)
    tagged(p, slab, sweep_var, p, "ancient_enamel",
           lambda a: [(r0, maw(a)[1]), (r1, maw(a)[1]), (r1, z1 - 0.3), (r0 + 0.05, z1)], -JAW_SPAN, JAW_SPAN, JAW_SEGS, SAND)
    for n, (deg, h_low, h_up, width) in enumerate(TEETH):
        low, up = maw(math.radians(deg))
        root_r = TOOTH_R[1] if deg == 0.0 else TOOTH_SIDE_R
        tagged(p, "tooth_%s_lower_%d" % (p.name, n), tooth, p, TOOTH_R[0], root_r, deg, low - 0.05, width,
               h_low, TOOTH, min(root_r, TOOTH_R[2]), TOOTH_W_OUT)
        tagged(p, "tooth_%s_upper_%d" % (p.name, n), tooth, p, TOOTH_R[0], root_r, deg, up + 0.05, width,
               -h_up, TOOTH, min(root_r, TOOTH_R[2]), TOOTH_W_OUT)
    # KF7c round 3: the ram's moving half (see RAM_Z), modelled in JawR's frame: the light rod
    # out of the Drum's gland, its light eye on a pin along Y, and a dark clevis block rising from
    # the crown under the eye (no cheek in front of the eye, so the side view shows the eye's ring).
    label = ram_label(0.0 if side > 0 else 180.0)
    tagged(p, label, p.rod, "ancient_enamel", ram_point(RAM_ROD_IN[side]), ram_point(RAM_EYE_X), RAM_ROD_R, 8,
           color=ROD)
    tagged(p, label, p.cyl, "ancient_enamel", RAM_EYE_R, RAM_EYE_R, 0.38, 10, loc=ram_point(RAM_EYE_X),
           rot=(math.pi / 2, 0, 0), color=TOOTH)
    lug_z0 = z1 - 0.2
    lug_z1 = RAM_Z - RAM_EYE_R + 0.05
    tagged(p, label, p.box, "ancient_enamel", (RAM_CLEVIS[1] - RAM_CLEVIS[0], RAM_CLEVIS[2], lug_z1 - lug_z0),
           loc=(sum(RAM_CLEVIS[:2]) / 2, -RAM_SIDE, (lug_z0 + lug_z1) / 2), color=SAND_DARK)
    p.cyl("ancient_enamel", 0.1, 0.1, 0.75, 8, loc=(r0 + 0.06, 0.0, z0 + 0.12), rot=(math.pi / 2, 0, 0), color=IRON)
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
    # 2026-10-11 (w13 KF7c): 0.8 m in, onto the slimmer drum's foot.
    p.box("ancient_enamel", (0.5, 1.1, 0.12), loc=(2.7, 0, 2.55), color=IRON)
    for y in (-0.55, 0.55):
        p.box("ancient_enamel", (0.5, 0.1, 0.3), loc=(2.7, y, 2.66), color=ENAMEL)
    return finish(p, (2.45, 0, 2.6), root, rot_z=math.radians(270))


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
    p.ring("ancient_light", PED_R[1] + 0.09, PED_R[1] + 0.17, 0.07, 16, loc=(0, 0, 1.5))
    return finish(p, (0, 0, 1.5), root)


def build():
    common.reset()
    del TAGS[:]
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
    silhouette_fails = silhouette(root)
    if silhouette_fails:
        if "--count-only" in argv:
            check(root)
        raise SystemExit("warden_reactor silhouette FAILED: " + ", ".join(silhouette_fails))
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
