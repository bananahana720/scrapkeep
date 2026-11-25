"""Swarm remnant body (KF6, wave 13): the hive, design-v3/wardens/swarm.md sections 1.1, 5 and 9.

Blender 5.2.2, memory-capped by prlimit (address space 12884901888 bytes, prlimit -v, the address-space limit):
  prlimit -v12884901888 blender --background --threads 2 --python-exit-code 1
    --python tools/blender/warden_swarm.py -- [--out DIR] [--count-only] [--render DIR]
  --out DIR      write both GLBs into DIR (default assets/models)
  --count-only   build and print the counts, export nothing
  --render DIR   after the check, preview PNGs at 20, 60 and 150 m (Eevee; run it on card 1)

Convention (the GLBs as exported): +Y up, metres, the ball approaches along -Z (it sees the +Z
face). The origin is the body's base centre: the collider's floor, where hero_assets.gd puts the
clamp base (position.y = -HALF_HEIGHT), so warden_kit.gd's swarm point_offset (0, 5.1, 0) from
the Warden's centre is (0, 6.7, 0) here, the queen. The swarm hangs from above: Suspension, the
eye on top of the yoke, is the point the hoist rope or the nest's timbers hold (KF8 places it).
Authored below in Blender Z-up; export_yup maps Blender (x, y, z) to glTF (x, z, -y), so the
ball's side is Blender -Y.

Builds two GLBs:
  warden_swarm.glb             warden_base. Swarm (armature) holds the hive as one skinned mesh
                               (ancient_enamel, rubber, ancient_light: 3 draws) and the nodes
                               WeakPoint (on the queen bone), Grip0..2 (the three grip cells,
                               green rims, harpoon hardpoints), Suspension.
                               Bones: Root > Hull, Yoke, Ring0..5 > Cell<i> > Shutter<i>_0..2 and
                               Seam<i>; Cell0 > QueenCore. Ring0 is the queen (Cell0), Ring1 6 shuttered cells round
                               it, Ring2 12 shuttered cells (19 shuttered: section 1.1), Ring3 to
                               Ring5 the lower comb (34 small cells). chunk_shed keys the same
                               fall (drop, drift, spin) on each shed ring bone, SHED_RINGS (Ring5,
                               Ring4, Ring3, Ring2), with the cells static under it; KF8 enables
                               only chunk n's ring track, then hides that ring by its ring bone.
  warden_swarm_kit_drones.glb  warden_kit, the drone dressing: SwarmDrones (armature) > eight
                               flat cast triangles, bone Drone<i> each, in the same frame.
Both carry every section 5 clip by name and length, so KF8 plays one name on both players:
  idle 4.0, pulse 2.4 (the 2.0 s charge then the 0.4 s pulse), active 4.0 (loop), hoist_ride 2.0,
  snip 2.0, stagger_open 4.0, chunk_shed 1.0, brood_dark 1.0 (holds its last pose), break 3.0.
The seams' brightness is the pinpricks' depth: a Seam bone sinks them into the lip (dim) or
lifts them proud (bright); warden_kit.gd's emission levels stay the runtime's. The snip's rope
runs from Grip0 (on the ball's side) toward +Z glTF and 30 degrees down; KF8 turns the kit node
to the live rope.
The collider rule (warden.gd RADIUS 2.8, warden_look.gd:31-32): below 2 m nothing passes 2.8 m
from the axis, above it nothing passes 3.8 m, at rest and in every second frame of idle, active,
hoist_ride, snip, pulse, stagger_open and brood_dark (the body), and of idle, active, hoist_ride,
stagger_open and brood_dark (the drones). Not held to it: chunk_shed and break (falling cells),
the drones' 0.4 s pulse burst (3 m out, section 5) and their snip walk along the rope.
The drones never sink into the hive: rig_pose_audit.py skins the body at the same clip time and
holds the kit to it in every shared clip but break and snip. They cling to the lower dome,
and in chunk_shed lift out of the way of the shed rings.
In stagger_open the queen's lit core (bone QueenCore) rises 0.6 m out of the open cell and swells.
Provenance: authored procedurally here from bmesh primitives; no external meshes or textures.
"""

import argparse
import hashlib
import json
import math
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import common  # noqa: E402
import polish  # noqa: E402

# Cast comb: 3 cm chamfers on real corners, smooth shading, baked AO (POLISH.md). Cells keep
# their hexagons; no edge lightening and softer AO keep ancient enamel under its cap.
polish.enable(detail=1, bevel=0.03, bevel_angle=46.0, edge=0.0, ao_strength=0.35)
from common import Part  # noqa: E402

FPS = 30
CLIPS = {"idle": 4.0, "pulse": 2.4, "active": 4.0, "hoist_ride": 2.0, "snip": 2.0,
         "stagger_open": 4.0, "chunk_shed": 1.0, "brood_dark": 1.0, "break": 3.0}
# Clips whose every pose keeps the collider rule (the rest are debris in flight).
HELD = ("idle", "active", "hoist_ride", "snip", "stagger_open", "brood_dark")
# The drones' snip walks the rope away from the body, so the kit holds the rule in the rest.
KIT_HELD = ("idle", "active", "hoist_ride", "stagger_open", "brood_dark")
# Polished caps (POLISH.md, 18 Oct), well under the warden_base and warden_kit class caps.
BUDGET = {"warden_swarm": ("warden_base", 13000, 17000, 32), "warden_swarm_kit_drones": ("warden_kit", 1500, 2800, 18)}
RADIUS = 2.8          # warden.gd RADIUS
LOW_BAND = 2.0        # below this height nothing passes RADIUS
REACH = RADIUS + 1.0  # above it nothing passes RADIUS + 1 m
QUEEN = Vector((0.0, 0.0, 6.7))  # warden_kit.gd swarm point_offset 5.1 + warden.gd HALF_HEIGHT 1.6

ENAMEL = common.srgb("petrol")
LIP = common.mix("petrol", "bone", 0.18)
IRON = common.mix("charcoal", "petrol", 0.28)
PLATE = common.mix("charcoal", "petrol", 0.45)
DUSTY = common.mix("petrol", "sandstone", 0.3)

# The hull's revolved profile (r, z): a hanging egg, narrow at the base so the lower comb stays
# inside the 2.8 m collider below 2 m.
PROFILE = [(0.55, 0.0), (1.25, 0.25), (1.8, 0.75), (2.15, 1.4), (2.35, 2.0), (2.75, 2.7), (3.0, 3.4),
           (3.05, 4.2), (2.85, 4.9), (2.4, 5.6), (1.75, 6.2), (1.0, 6.7), (0.5, 6.95)]
SEGS = 12
# Rings: (name, count, z on the profile, azimuth offset deg, cell circumradius, protrusion, shuttered)
RINGS = [
    ("Ring1", 6, 6.25, 0.0, 0.78, 0.33, True),
    ("Ring2", 12, 5.15, 15.0, 0.78, 0.30, True),
    ("Ring3", 12, 3.85, 0.0, 0.70, 0.30, False),
    ("Ring4", 12, 2.78, 15.0, 0.62, 0.26, False),
    ("Ring5", 9, 1.4, 20.0, 0.55, 0.2, False),
]
BALL_AZ = -90.0          # Blender -Y is the ball's side
GRIP_CELLS = (1, 3, 5)   # Ring1 cells at -90, 30 and 150 degrees
# The ring each chunk sheds, chunk 1 to 4 (section 3.2: lowest first); chunk_shed keys all four.
SHED_RINGS = ("Ring5", "Ring4", "Ring3", "Ring2")
RING_REST = {}           # ring bone -> rest axes (3x3), filled once the armature exists
YOKE_AZ = (-60.0, 60.0, 180.0)
SEAM_DIM = -0.05
SEAM_OFF = -0.13
SEAM_BRIGHT = 0.05


def profile_r(z):
    pts = PROFILE
    if z <= pts[0][1]:
        return pts[0][0]
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return pts[-1][0]


def profile_normal(z):
    """The outward normal of the revolved profile in the (r, z) plane, central difference."""
    dz = 0.18
    dr = profile_r(z + dz) - profile_r(z - dz)
    n = Vector((2 * dz, -dr))
    return n.normalized()


def basis(n):
    """Orthonormal (u, v) across the axis n; u is horizontal unless n is vertical."""
    n = Vector(n).normalized()
    up = Vector((0, 0, 1))
    u = up.cross(n) if abs(n.dot(up)) < 0.98 else Vector((1, 0, 0))
    u.normalize()
    v = n.cross(u).normalized()
    return u, v


class Mesh:
    """One bmesh whose vertices each belong to one bone (rigid skinning)."""

    def __init__(self, name):
        self.part = Part(name)
        self.bm = self.part.bm
        self.owner = []  # bone name per vertex, in creation order

    def claim(self, bone, start):
        self.owner += [bone] * (len(self.bm.verts) - start)

    def mark(self):
        return len(self.bm.verts)

    def face(self, verts, slot, color, outward):
        """A face whose winding is flipped if its normal points away from outward."""
        f = self.bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(Vector(outward)) < 0:
            f.normal_flip()
        self.part.paint([f], slot, color)
        return f

    def v(self, co):
        return self.bm.verts.new(Vector(co))


def hex_corners(centre, u, v, r, rot=0.0):
    return [centre + (u * math.cos(rot + k * math.pi / 3) + v * math.sin(rot + k * math.pi / 3)) * r for k in range(6)]


def build_cell(m, bone, seam, cell):
    """A hexagonal cell: sides sunk into the hull, a lighter lip, a charcoal groove and floor, a
    small green core under the shutter, pinpricks at the lip corners on the seam bone."""
    s, n, rc, h, rot = cell["base"], cell["axis"], cell["rc"], cell["out"], cell["rot"]
    u, v = cell["u"], cell["v"]
    face = s + n * h
    depth = cell["depth"]
    mk = m.mark()
    top = [m.v(c) for c in hex_corners(face, u, v, rc, rot)]
    bot = [m.v(c) for c in hex_corners(s - n * cell.get("sink", 0.3), u, v, rc * 0.92, rot)]
    inner = [m.v(c) for c in hex_corners(face, u, v, rc * 0.8, rot)]
    for k in range(6):
        j = (k + 1) % 6
        mid = (top[k].co + top[j].co) / 2
        m.face([bot[k], bot[j], top[j], top[k]], "ancient_enamel", cell["color"], mid - (s + n * (h / 2)))
        m.face([top[k], top[j], inner[j], inner[k]], "ancient_enamel", LIP, n)
    if cell["shutters"]:
        # Open: a charcoal groove and floor with a small green core, seen only past the shutter.
        deep = [m.v(c) for c in hex_corners(face - n * depth, u, v, rc * 0.8, rot)]
        for k in range(6):
            j = (k + 1) % 6
            m.face([inner[k], inner[j], deep[j], deep[k]], "rubber", None, face - (inner[k].co + inner[j].co) / 2)
        m.face(list(deep), "rubber", None, n)
        core = [m.v(c) for c in hex_corners(face - n * (depth - 0.02), u, v, rc * 0.32, rot)]
        m.face(core, "ancient_light", None, n)
    else:
        # The comb is sealed: a low dark-iron cap, so the green stays in the seams.
        apex = m.v(face + n * 0.1)
        for k in range(6):
            j = (k + 1) % 6
            m.face([inner[k], inner[j], apex], "ancient_enamel", PLATE, n)
    if cell.get("grip"):
        outer = [m.v(c) for c in hex_corners(face + n * 0.03, u, v, rc * 1.14, rot)]
        rim = [m.v(c) for c in hex_corners(face + n * 0.03, u, v, rc * 0.98, rot)]
        low = [m.v(c) for c in hex_corners(face - n * 0.12, u, v, rc * 1.14, rot)]
        for k in range(6):
            j = (k + 1) % 6
            m.face([rim[k], rim[j], outer[j], outer[k]], "ancient_light", None, n)
            m.face([outer[k], outer[j], low[j], low[k]], "ancient_light", None, (outer[k].co + outer[j].co) / 2 - face)
    m.claim(bone, mk)
    mk = m.mark()
    corners = range(6) if cell["shutters"] else (0, 2, 4)
    size = 0.075 if not cell.get("queen") else 0.1
    for k in corners:
        c = top[k].co
        radial = (c - face).normalized()
        side = n.cross(radial).normalized()
        a = m.v(c + n * 0.005 + radial * size)
        b = m.v(c + n * 0.005 - radial * size * 0.5 + side * size * 0.87)
        d = m.v(c + n * 0.005 - radial * size * 0.5 - side * size * 0.87)
        apex = m.v(c + n * 0.12)
        m.face([a, b, d], "ancient_light", None, -n)
        for p, q in ((a, b), (b, d), (d, a)):
            m.face([p, q, apex], "ancient_light", None, (p.co + q.co) / 2 - c)
    m.claim(seam, mk)
    return top


def build_plate(m, bone, cell, j, thick, raise_):
    """One of the three iris plates: centre, corners 2j, 2j+1, 2j+2 of the lip's inner hex,
    pulled 0.035 toward its own middle so the plates read as three."""
    face = cell["base"] + cell["axis"] * cell["out"]
    n = cell["axis"]
    cs = hex_corners(face, cell["u"], cell["v"], cell["rc"] * 0.79, cell["rot"])
    pts = [face, cs[2 * j], cs[(2 * j + 1) % 6], cs[(2 * j + 2) % 6]]
    mid = sum(pts, Vector()) / 4
    pts = [p + (mid - p).normalized() * 0.035 for p in pts]
    mk = m.mark()
    up = [m.v(p + n * (0.02 + (raise_ if i == 0 else 0.0))) for i, p in enumerate(pts)]
    lo = [m.v(p - n * thick) for p in pts]
    m.face(list(up), "ancient_enamel", PLATE, n)
    m.face(list(lo), "ancient_enamel", IRON, -n)
    for k in range(4):
        q = (k + 1) % 4
        m.face([lo[k], lo[q], up[q], up[k]], "ancient_enamel", IRON, (up[k].co + up[q].co) / 2 - mid)
    m.claim(bone, mk)
    # The hinge: through the plate's outer corner, along the chord of its two side corners.
    return cs[(2 * j + 1) % 6], (cs[(2 * j + 2) % 6] - cs[2 * j]).normalized(), (face - cs[(2 * j + 1) % 6]).normalized()


def hive_cells(rng):
    cells = []
    queen = {"name": "Cell0", "ring": "Ring0", "queen": True, "shutters": True, "rc": 0.95, "out": 0.0,
             "base": Vector((0, 0, 7.6)), "axis": Vector((0, 0, 1)), "rot": math.radians(BALL_AZ), "depth": 0.9, "sink": 1.5,
             "color": ENAMEL, "h": 1.0}
    queen["u"], queen["v"] = basis(queen["axis"])
    cells.append(queen)
    idx = 1
    for ring, count, z, off, rc, out, shut in RINGS:
        for k in range(count):
            az = math.radians(BALL_AZ + off + k * 360.0 / count + rng.uniform(-3.0, 3.0))
            zz = z + rng.uniform(-0.08, 0.08)
            nr, nz = profile_normal(zz)
            radial = Vector((math.cos(az), math.sin(az), 0))
            axis = (radial * nr + Vector((0, 0, nz))).normalized()
            base = radial * profile_r(zz) + Vector((0, 0, zz))
            cell = {"name": "Cell%d" % idx, "ring": ring, "shutters": shut, "rc": rc + rng.uniform(-0.04, 0.03),
                    "out": out + rng.uniform(-0.07, 0.07), "base": base, "axis": axis, "az": az,
                    "depth": 0.16, "color": DUSTY if (shut and rng.random() < 0.3) else ENAMEL,
                    "h": max(0.0, min(1.0, zz / 7.6)), "grip": ring == "Ring1" and (k + 1) in GRIP_CELLS}
            cell["u"], cell["v"] = basis(axis)
            cell["rot"] = rng.uniform(-0.12, 0.12)
            cells.append(cell)
            idx += 1
    bottom = {"name": "Cell%d" % idx, "ring": "Ring5", "shutters": False, "rc": 0.6, "out": 0.25,
              "base": Vector((0, 0, 0.37)), "axis": Vector((0, 0, -1)), "rot": 0.3, "depth": 0.16,
              "color": ENAMEL, "h": 0.0}
    bottom["u"], bottom["v"] = basis(bottom["axis"])
    cells.append(bottom)
    return cells


def build_hull(m):
    mk = m.mark()
    rows = []
    for r, z in PROFILE:
        rows.append([m.v((r * math.cos(a), r * math.sin(a), z)) for a in
                     (math.radians(BALL_AZ) + k * math.tau / SEGS for k in range(SEGS))])
    for a, b in zip(rows, rows[1:]):
        for k in range(SEGS):
            j = (k + 1) % SEGS
            mid = (a[k].co + b[j].co) / 2
            m.face([a[k], a[j], b[j], b[k]], "ancient_enamel", IRON, Vector((mid.x, mid.y, 0)))
    m.face(list(rows[0]), "ancient_enamel", IRON, (0, 0, -1))
    m.face(list(rows[-1]), "ancient_enamel", IRON, (0, 0, 1))
    m.claim("Hull", mk)


def build_yoke(m):
    """Three cast arms from the shoulder to a collar and the suspension eye: clamp iron."""
    mk = m.mark()
    p = m.part
    for az in YOKE_AZ:
        a = math.radians(az)
        d = Vector((math.cos(a), math.sin(a), 0))
        foot = d * 2.3 + Vector((0, 0, 5.62))
        knee = d * 1.5 + Vector((0, 0, 7.15))
        head = d * 0.62 + Vector((0, 0, 8.3))
        p.beam("ancient_enamel", foot, knee, 0.34, 0.28, color=IRON, roll=a)
        p.beam("ancient_enamel", knee, head, 0.3, 0.26, color=IRON, roll=a)
        p.ico("ancient_enamel", 0.26, 1, loc=knee, color=PLATE)
        p.box("ancient_enamel", (0.5, 0.42, 0.34), loc=foot, rot=(0, -0.7, a), color=IRON)
    p.ring("ancient_enamel", 0.3, 0.8, 0.45, 8, loc=(0, 0, 8.45), color=IRON)
    p.ring("rubber", 0.78, 0.84, 0.12, 8, loc=(0, 0, 8.45))
    p.ring("ancient_enamel", 0.17, 0.38, 0.16, 8, loc=(0, 0, 8.95), rot=(math.pi / 2, 0, 0), color=PLATE)
    m.claim("Yoke", mk)


# ---------------------------------------------------------------------------- armature


def new_armature(name):
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    return obj


def bone(arm, name, head, tail, parent=None, roll_to=None):
    eb = arm.data.edit_bones.new(name)
    eb.head = Vector(head)
    eb.tail = Vector(tail)
    if roll_to is not None:
        eb.align_roll(Vector(roll_to))
    if parent is not None:
        eb.parent = arm.data.edit_bones[parent]
    eb.use_deform = True
    return eb


def skin(m, arm, name):
    m.bm.verts.index_update()
    # Owners ride in the bmesh's deform layer, so polish bevels carry them onto new vertices.
    names = list(dict.fromkeys(m.owner))
    index = {owner: k for k, owner in enumerate(names)}
    deform = m.bm.verts.layers.deform.verify()
    assert len(m.owner) == len(m.bm.verts), (len(m.owner), len(m.bm.verts))
    for v, owner in zip(m.bm.verts, m.owner):
        v[deform][index[owner]] = 1.0
    obj = m.part.to_object((0, 0, 0))
    obj.name = name
    for owner in names:
        obj.vertex_groups.new(name=owner)
    # Rigid skinning: every vertex keeps only its strongest bone, at full weight.
    for v in obj.data.vertices:
        groups = sorted(((g.weight, -g.group) for g in v.groups), reverse=True)
        if len(groups) > 1 or (groups and groups[0][0] != 1.0):
            keep = -groups[0][1]
            for _, g in groups[1:]:
                obj.vertex_groups[-g].remove([v.index])
            obj.vertex_groups[keep].add([v.index], 1.0, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


def marker(name, arm, bone_name, at):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    if bone_name:
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
    bpy.context.view_layer.update()
    obj.matrix_world = Matrix.Translation(Vector(at))
    return obj


# ---------------------------------------------------------------------------- the hive


def build_body():
    rng = random.Random("scrapkeep-warden-swarm")
    cells = hive_cells(rng)
    m = Mesh("SwarmHive")
    build_hull(m)
    build_yoke(m)
    plates = []
    for c in cells:
        build_cell(m, c["name"], "Seam" + c["name"][4:], c)
        if c["shutters"]:
            for j in range(3):
                name = "Shutter%s_%d" % (c["name"][4:], j)
                thick, raise_ = (0.12, 0.16) if c.get("queen") else (0.06, 0.07)
                hinge, along, inward = build_plate(m, name, c, j, thick, raise_)
                plates.append({"name": name, "cell": c, "hinge": hinge, "along": along, "inward": inward})
    # The queen's lit core, at the point.
    mk = m.mark()
    m.part.ico("ancient_light", 0.5, 1, loc=QUEEN)
    m.claim("QueenCore", mk)
    arm = new_armature("Swarm")
    bone(arm, "Root", (0, 0, 0), (0, 0, 1))
    bone(arm, "Hull", (0, 0, 0.4), (0, 0, 1.4), "Root")
    bone(arm, "Yoke", (0, 0, 8.45), (0, 0, 9.0), "Root")
    for ring in ["Ring0"] + [r[0] for r in RINGS]:
        z = 6.7 if ring == "Ring0" else next(r[2] for r in RINGS if r[0] == ring)
        bone(arm, ring, (0, 0, z), (0, 0, z + 0.5), "Root")
    for c in cells:
        n = c["axis"]
        head = QUEEN if c.get("queen") else c["base"]
        bone(arm, c["name"], head, head + n * 0.4, c["ring"], roll_to=c["u"])
        face = c["base"] + n * c["out"]
        bone(arm, "Seam" + c["name"][4:], face, face + n * 0.25, c["name"], roll_to=c["u"])
    bone(arm, "QueenCore", QUEEN, QUEEN + Vector((0, 0, 0.4)), "Cell0")
    for p in plates:
        n = p["cell"]["axis"]
        bone(arm, p["name"], p["hinge"], p["hinge"] + n * 0.25, p["cell"]["name"], roll_to=p["along"])
    bpy.ops.object.mode_set(mode="OBJECT")
    # Which way a plate turns about its local Z to open: its inward direction toward +Y (the axis).
    for p in plates:
        b = arm.data.bones[p["name"]]
        x = b.matrix_local.to_3x3().col[0]
        p["sign"] = 1.0 if x.dot(p["inward"]) > 0 else -1.0
    hive = skin(m, arm, "SwarmHive")
    markers = [marker("WeakPoint", arm, "Cell0", QUEEN)]
    for i, c in enumerate([c for c in cells if c.get("grip")]):
        markers.append(marker("Grip%d" % i, arm, c["name"], c["base"] + c["axis"] * c["out"]))
    top = max((hive.matrix_world @ v.co).z for v in hive.data.vertices)
    markers.append(marker("Suspension", arm, "Yoke", (0, 0, top)))
    return arm, hive, markers, cells, plates


def body_pose(clip, t, cells, plates):
    """Per-bone (location in the bone's rest axes, quaternion, scale) at time t of a clip."""
    pose = {}
    L = CLIPS[clip]
    for c in cells:
        h = c["h"]
        loc, rot, scale = Vector(), Quaternion(), 1.0
        seam = SEAM_DIM
        if clip == "idle":
            scale = 1.0 + 0.02 * math.sin(math.tau * (t / 4.0 - h * 0.6))
            seam = SEAM_DIM + 0.04 * math.sin(math.tau * (t / 2.0 - h))
        elif clip == "pulse":
            if t <= 2.0:
                o = smooth((t - (0.15 + 1.2 * h)) / 0.45)
                seam = SEAM_DIM + (SEAM_BRIGHT - SEAM_DIM) * o
                scale = 1.0 + 0.02 * o
            else:
                k = (t - 2.0) / 0.4
                scale = 1.0 + 0.06 * math.exp(-6 * k) * math.cos(9 * k)
                seam = SEAM_BRIGHT + (SEAM_DIM - SEAM_BRIGHT) * smooth(k)
        elif clip == "active":
            scale = 1.0 + 0.015 * math.sin(math.tau * (t / 2.0 - h))
            seam = 0.0 + 0.03 * math.sin(math.tau * (t / 1.0 - h))
        elif clip == "hoist_ride":
            brace = math.sin(math.pi * t / 2.0)
            loc = Vector((0, -0.06 * brace, 0))
            scale = 1.0 - 0.02 * brace
            seam = SEAM_DIM
        elif clip == "snip":
            seam = SEAM_DIM + 0.03 * math.sin(math.tau * (t / 0.5 - h))
            if c.get("grip"):
                seam = SEAM_BRIGHT * (0.6 + 0.4 * math.sin(math.tau * t / 0.25))
        elif clip == "stagger_open":
            o = smooth(t / 0.25)
            seam = SEAM_DIM + (SEAM_BRIGHT + 0.02 - SEAM_DIM) * o
            if c.get("queen"):
                scale = 1.0 + 0.3 * smooth(t / 0.35) + 0.03 * math.sin(math.tau * t / 0.5) * o
            else:
                scale = 1.0 + 0.03 * o
        elif clip == "chunk_shed":
            # The fall rides the ring bones (below); every cell only shudders and its pinpricks
            # flicker, so one clip serves whichever ring KF8 lets fall.
            scale = 1.0 + 0.04 * math.exp(-5 * t) * math.sin(math.tau * t / 0.25)
            seam = SEAM_DIM + (SEAM_OFF - SEAM_DIM) * math.exp(-4 * t) * abs(math.sin(math.tau * t / 0.2))
        elif clip == "brood_dark":
            seam = SEAM_DIM + (SEAM_OFF - SEAM_DIM) * smooth(t / 0.8)
            scale = 1.0 - 0.015 * smooth(t / 0.8)
        elif clip == "break":
            t0 = 0.15 + 0.5 * ((int(c["name"][4:]) * 7) % 11) / 10.0
            k = max(0.0, t - t0)
            split = c["axis"] * (0.9 * smooth(k / 0.3))
            fall = Vector((0, 0, -0.5 * 9.8 * k * k))
            loc = local_vector(c["rest"], split + fall)
            rot = Quaternion(Vector((1, 0.3, 0)).normalized(), 2.0 * k * (1 if int(c["name"][4:]) % 2 else -1))
            seam = SEAM_DIM + (SEAM_OFF - SEAM_DIM) * smooth((t - 0.1) / 0.4)
        pose[c["name"]] = (loc, rot, Vector((scale, scale, scale)))
        pose["Seam" + c["name"][4:]] = (Vector((0, seam, 0)), Quaternion(), Vector((1, 1, 1)))
    for p in plates:
        c = p["cell"]
        h = c["h"]
        ang = 0.0
        if clip == "pulse":
            if t <= 2.0:
                ang = math.radians(50) * smooth((t - (0.15 + 1.2 * h)) / 0.45)
            else:
                ang = math.radians(50) * (1.0 - smooth((t - 2.0) / 0.08))
        elif clip == "active":
            if int(c["name"][4:]) % 2 == 0:
                ang = math.radians(28 + 6 * math.sin(math.tau * (t / 2.0 + h)))
        elif clip == "stagger_open":
            # Ring2 sits on the widest shoulder: its plates stop at 50 degrees so an open
            # shutter stays inside 3.8 m.
            full = 125 if c.get("queen") else (50 if c["ring"] == "Ring2" else 105)
            ang = math.radians(full) * smooth(t / 0.22) + math.radians(4) * math.sin(math.tau * t / 0.5) * smooth(t / 0.3)
        elif clip == "break":
            ang = math.radians(70) * smooth((t - 0.2) / 0.6)
        pose[p["name"]] = (Vector(), Quaternion((0, 0, 1), p["sign"] * ang), Vector((1, 1, 1)))
    root_loc, root_rot, root_scale = Vector(), Quaternion(), Vector((1, 1, 1))
    hull_scale = Vector((1, 1, 1))
    hull_loc = Vector()
    if clip == "hoist_ride":
        brace = math.sin(math.pi * t / 2.0)
        root_rot = Quaternion((1, 0, 0), math.radians(1.5) * math.sin(math.tau * t / 2.0))
        root_scale = Vector((1.0 + 0.01 * brace, 1.0 - 0.02 * brace, 1.0 + 0.01 * brace))
    elif clip == "break":
        k = max(0.0, t - 0.9)
        hull_loc = Vector((0, -0.5 * 9.8 * k * k, 0))
        hull_scale = Vector((1, 1, 1)) * (1.0 - 0.3 * smooth((t - 0.9) / 1.5))
    pose["Root"] = (root_loc, root_rot, root_scale)
    pose["Hull"] = (hull_loc, Quaternion(), hull_scale)
    pose["Yoke"] = (Vector(), Quaternion(), Vector((1, 1, 1)))
    core_loc, core_scale = 0.0, 1.0
    if clip == "stagger_open":
        # The finisher window: the lit core rises out of the open queen and swells.
        core_loc = 0.6 * smooth(t / 0.3)
        core_scale = 1.0 + 0.25 * smooth(t / 0.3) + 0.05 * math.sin(math.tau * t / 0.5) * smooth(t / 0.3)
    elif clip == "pulse" and t <= 2.0:
        core_scale = 1.0 + 0.1 * smooth((t - 1.2) / 0.8)
    elif clip == "break":
        core_scale = 1.0 - smooth((t - 0.1) / 0.5) * 0.9
    pose["QueenCore"] = (Vector((0, core_loc, 0)), Quaternion(), Vector((core_scale, core_scale, core_scale)))
    for ring in ["Ring0"] + [r[0] for r in RINGS]:
        pose[ring] = (Vector(), Quaternion(), Vector((1, 1, 1)))
        if clip == "chunk_shed" and ring in SHED_RINGS:
            pose[ring] = ring_fall(t, RING_REST[ring])
    return pose


def ring_fall(t, rest3):
    """One shed ring breaking away: it drops under gravity, drifts off the ball's side and
    spreads a little, spinning about the hive's axis and tumbling. Identical on every shed ring
    bone (all share the rest axes), so KF8 picks the ring by which track it enables."""
    k = max(0.0, t - 0.08)
    world = Vector((0, 1.2 * k, -0.5 * 9.8 * k * k))
    loc = local_vector(rest3, world)
    spin = Quaternion((0, 1, 0), 1.6 * k)             # the bone's Y is the hive's axis
    tumble = Quaternion((1, 0, 0), 0.6 * k)
    spread = 1.0 + 0.12 * smooth(k / 0.5)
    return (loc, tumble @ spin, Vector((spread, spread, spread)))


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def local_vector(rest3, world):
    """A world (armature-space) offset in a bone's rest axes, its parents at rest."""
    return rest3.inverted() @ world


# ---------------------------------------------------------------------------- the drones


DRONES = [  # (height z, azimuth deg, wander phase)
    (3.75, 0.0, 0.0), (3.7, 270.0, 0.3), (3.5, 90.0, 0.55), (3.3, 180.0, 0.15),
    (3.6, 225.0, 0.7), (3.65, 135.0, 0.4), (3.15, 45.0, 0.85), (3.4, 315.0, 0.25),
]
# A drone clings flat to the comb, DRONE_CLEAR off the hull along its normal: the lips and caps
# stand up to 0.45 m proud and the pinpricks sink below the lip, so the underside (0.05 m below the
# frame) clears them. They crawl the lower dome, below the shuttered rings, where the plates open
# and the yoke arms stand clear of the comb. In chunk_shed they start up by SHED_LIFT as the rings
# break away (the falling cells spread 12 percent, drift and tumble past them) and hold it to the
# clip's end: the next clip blends them back down once the ring is gone.
DRONE_CLEAR = 0.53
SHED_LIFT = 1.2
SNIP_FILE = (0, 1, 7)


def surface_frame(z, az, heading=0.0, clear=DRONE_CLEAR):
    """Armature-space matrix of a drone on the hive at height z and azimuth az: local Y out of
    the surface, local Z its heading (0 = round the hive, counter-clockwise)."""
    a = math.radians(az)
    radial = Vector((math.cos(a), math.sin(a), 0))
    nr, nz = profile_normal(z)
    n = (radial * nr + Vector((0, 0, nz))).normalized()
    around = Vector((-math.sin(a), math.cos(a), 0))
    up_surf = n.cross(around).normalized()
    fwd = (around * math.cos(heading) + up_surf * math.sin(heading)).normalized()
    pos = radial * profile_r(z) + Vector((0, 0, z)) + n * clear
    x = n.cross(fwd).normalized()
    m = Matrix((x, n, fwd)).transposed().to_4x4()
    m.translation = pos
    return m


def build_drone(m, i, frame):
    """A flat cast triangle (point forward), a raised spine and a green lens at the tip."""
    mk = m.mark()
    x, n, f = frame.col[0].to_3d(), frame.col[1].to_3d(), frame.col[2].to_3d()
    o = frame.translation

    def at(px, pf, pn):
        return o + x * px + f * pf + n * pn

    def tri_prism(outline, z0, z1, slot, color, side_color):
        lo = [m.v(at(a, b, z0)) for a, b in outline]
        hi = [m.v(at(a, b, z1)) for a, b in outline]
        m.face(lo, slot, side_color, -n)
        m.face(hi, slot, color, n)
        c = sum((p.co for p in hi), Vector()) / 3
        for k in range(3):
            q = (k + 1) % 3
            m.face([lo[k], lo[q], hi[q], hi[k]], slot, side_color, (hi[k].co + hi[q].co) / 2 - c)

    tri_prism([(0, 0.48), (-0.42, -0.24), (0.42, -0.24)], -0.05, 0.05, "ancient_enamel", ENAMEL, IRON)
    tri_prism([(0, 0.3), (-0.2, -0.16), (0.2, -0.16)], 0.05, 0.12, "ancient_enamel", PLATE, IRON)
    # Flanking uranium-glass green (#9DFF3C) seam ribs along the cast drone chassis (g08 canon).
    for sign in (-1.0, 1.0):
        tri_prism([(sign * 0.08, 0.24), (sign * 0.28, -0.12), (sign * 0.20, -0.16)], 0.052, 0.072, "ancient_light", None, None)
    tip = at(0, 0.3, 0.13)
    a, b, d = m.v(tip + f * 0.06), m.v(tip - f * 0.04 + x * 0.06), m.v(tip - f * 0.04 - x * 0.06)
    apex = m.v(tip + n * 0.05)
    m.face([a, b, d], "ancient_light", None, -n)
    for p, q in ((a, b), (b, d), (d, a)):
        m.face([p, q, apex], "ancient_light", None, (p.co + q.co) / 2 - tip)
    m.claim("Drone%d" % i, mk)


def drone_target(clip, i, t):
    z0, az0, ph = DRONES[i]
    wander = lambda: (az0 + 14 * math.sin(math.tau * (t / 4.0 + ph)), z0 + 0.25 * math.sin(math.tau * (t / 2.0 + ph)),
                      math.radians(25) * math.cos(math.tau * (t / 4.0 + ph)))
    if clip == "idle":
        az, z, hd = wander()
        return surface_frame(z, az, hd)
    if clip == "chunk_shed":
        az, z, hd = wander()
        return surface_frame(z, az, hd, DRONE_CLEAR + SHED_LIFT * smooth(t / 0.2))
    if clip == "pulse":
        az, z, hd = wander()
        mtx = surface_frame(z, az, hd)
        if t > 2.0:
            k = (t - 2.0) / 0.4
            burst = 3.0 * math.sin(math.pi * min(1.0, k * 1.6)) * (1.0 - smooth(k))
            mtx = Matrix.Translation(mtx.col[1].to_3d() * burst) @ mtx
        return mtx
    if clip == "active":
        return surface_frame(z0, az0 + 360.0 * t / 4.0, 0.0)
    if clip == "stagger_open":
        az, z, hd = (az0 + 18 * math.sin(math.tau * (t / 1.0 + ph)), z0 + 0.22 * math.sin(math.tau * (t / 0.5 + ph)),
                     math.radians(60) * math.cos(math.tau * (t / 1.0 + ph)))
        return surface_frame(z, az, hd)
    if clip == "hoist_ride":
        return surface_frame(z0, az0, 0.0)
    if clip == "brood_dark":
        az, z, hd = (az0 + 14 * math.sin(math.tau * ph), z0 + 0.25 * math.sin(math.tau * ph), math.radians(25) * math.cos(math.tau * ph))
        return surface_frame(z, az, hd)
    if clip == "snip":
        if i in SNIP_FILE:
            # The file of three walks the lined rope from Grip0 toward the ball: out along the
            # ball's side and 30 degrees down, 0.9 m apart, 9 m in the 2 s charge.
            g = surface_frame(6.25, BALL_AZ, 0.0, 0.33 + 0.1)
            rope = Vector((0, -math.cos(math.radians(30)), -math.sin(math.radians(30))))
            slot = SNIP_FILE.index(i)
            s = max(0.0, 4.5 * t - 0.9 * slot)
            pos = g.translation + rope * s
            up = Vector((0, 0, 1))
            x = rope.cross(up).normalized()
            n = x.cross(rope).normalized()
            m = Matrix((x, n, rope)).transposed().to_4x4()
            m.translation = pos + n * 0.1
            return m
        az, z, hd = wander()
        return surface_frame(z, az, hd)
    if clip == "break":
        az, z, hd = wander()
        mtx = surface_frame(z, az, hd)
        t0 = 0.1 + 0.08 * i
        k = max(0.0, t - t0)
        drop = Vector((0, 0, -min(14.0, 0.5 * 9.8 * k * k)))
        out = mtx.col[1].to_3d() * (0.8 * smooth(k / 0.4))
        spin = Matrix.Rotation(min(math.pi, 4.0 * k), 4, "X")
        res = Matrix.Translation(drop + out) @ mtx @ spin
        return res
    raise ValueError(clip)


def build_kit():
    m = Mesh("SwarmDrones")
    rest = [drone_target("idle", i, 0.0) for i in range(len(DRONES))]
    for i, frame in enumerate(rest):
        build_drone(m, i, frame)
    arm = new_armature("SwarmDrones")
    bone(arm, "Root", (0, 0, 0), (0, 0, 1))
    for i, frame in enumerate(rest):
        o = frame.translation
        bone(arm, "Drone%d" % i, o, o + frame.col[1].to_3d() * 0.3, "Root", roll_to=frame.col[2].to_3d())
    bpy.ops.object.mode_set(mode="OBJECT")
    kit = skin(m, arm, "SwarmDrones")
    return arm, kit, rest


def kit_pose(clip, t, arm, rest):
    pose = {"Root": (Vector(), Quaternion(), Vector((1, 1, 1)))}
    for i in range(len(DRONES)):
        r = arm.data.bones["Drone%d" % i].matrix_local
        basis_m = r.inverted() @ drone_target(clip, i, t) @ (r.inverted() @ rest[i]).inverted()
        loc, rot, scale = basis_m.decompose()
        pose["Drone%d" % i] = (loc, rot, scale)
    return pose


# ---------------------------------------------------------------------------- clips and export


def author_clips(arm, pose_fn):
    scene = bpy.context.scene
    scene.render.fps = FPS
    arm.animation_data_create()
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for clip, length in CLIPS.items():
        arm.animation_data.action = None
        last = {}
        end = int(round(length * FPS))
        frames = list(range(0, end + 1, 2))
        if frames[-1] != end:
            frames.append(end)
        for f in frames:
            pose = pose_fn(clip, f / FPS)
            for pb in arm.pose.bones:
                loc, rot, scale = pose[pb.name]
                rot = rot.normalized()
                if pb.name in last and last[pb.name].dot(rot) < 0:
                    rot = -rot
                last[pb.name] = rot
                pb.location = loc
                pb.rotation_quaternion = rot
                pb.scale = scale
                for path in ("location", "rotation_quaternion", "scale"):
                    pb.keyframe_insert(data_path=path, frame=f, group=pb.name)
        act = arm.animation_data.action
        act.name = clip
        act.use_fake_user = True
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.interpolation = "LINEAR"
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    scene.frame_set(0)


def reach(obj, arm, clip_names):
    """Widest radius below and above LOW_BAND over every second frame of the named clips, and at rest."""
    worst = {"rest": rest_reach(obj)}
    deps = bpy.context.evaluated_depsgraph_get()
    for clip in clip_names:
        act = bpy.data.actions[clip]
        arm.animation_data.action = act
        low = high = 0.0
        for f in range(0, int(round(CLIPS[clip] * FPS)) + 1, 2):
            bpy.context.scene.frame_set(f)
            ev = obj.evaluated_get(deps)
            mesh = ev.to_mesh()
            mw = obj.matrix_world
            for v in mesh.vertices:
                p = mw @ v.co
                r = math.hypot(p.x, p.y)
                if p.z < LOW_BAND:
                    low = max(low, r)
                else:
                    high = max(high, r)
            ev.to_mesh_clear()
        worst[clip] = (low, high)
    arm.animation_data.action = None
    bpy.context.scene.frame_set(0)
    return worst


def rest_reach(obj):
    low = high = 0.0
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        r = math.hypot(p.x, p.y)
        if p.z < LOW_BAND:
            low = max(low, r)
        else:
            high = max(high, r)
    return (low, high)


def export(objs, path):
    bpy.context.view_layer.update()
    if common.POLISH is not None:
        polish.bake(objs[0], common.POLISH)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_extras=False, export_cameras=False, export_lights=False,
                              export_skins=True, export_def_bones=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
                              export_frame_range=False, export_force_sampling=True,
                              export_optimize_animation_size=True,
                              export_optimize_animation_keep_anim_armature=True)
    common.canonical_indices(path, vertices=common.POLISH is not None)
    print("EXPORTED", path)


def check(path, name):
    """Fails loud: budget, every clip by name and length, the collider rule at rest, no light."""
    data = open(path, "rb").read()
    n = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20 + n])
    bin_start = 20 + n + 8
    cls, max_t, max_v, max_d = BUDGET[name]
    tris = verts = draws = 0
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            tris += g["accessors"][prim["indices"]]["count"] // 3
            verts += g["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws += 1
    problems = []
    if not (0 < tris <= max_t and verts <= max_v and draws <= max_d):
        problems.append("budget %s: %d tris, %d verts, %d draws over %d/%d/%d" % (cls, tris, verts, draws, max_t, max_v, max_d))
    lengths = {}
    for anim in g.get("animations", []):
        lengths[anim["name"]] = max(g["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
    for clip, length in CLIPS.items():
        if clip not in lengths:
            problems.append("clip %s missing" % clip)
        elif abs(lengths[clip] - length) > 0.05:
            problems.append("clip %s is %.3f s, want %.2f" % (clip, lengths[clip], length))
    if name == "warden_swarm":
        # Each shed ring bone carries the fall in chunk_shed (KF8 enables chunk n's track).
        node_ids = {nd.get("name"): i for i, nd in enumerate(g["nodes"])}
        shed = next((a for a in g.get("animations", []) if a["name"] == "chunk_shed"), None)
        for ring in SHED_RINGS:
            drop = 0.0
            for ch in (shed or {}).get("channels", []):
                if ch["target"].get("node") == node_ids.get(ring) and ch["target"]["path"] == "translation":
                    acc = g["accessors"][shed["samplers"][ch["sampler"]]["output"]]
                    view = g["bufferViews"][acc["bufferView"]]
                    base = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                    ys = [struct.unpack_from("<fff", data, base + k * view.get("byteStride", 12))
                          for k in range(acc["count"])]
                    drop = max(math.dist(ys[0], v) for v in ys)
            if drop < 2.0:
                problems.append("chunk_shed moves %s only %.2f m (want a fall on every shed ring)" % (ring, drop))
    if "KHR_lights_punctual" in json.dumps(g.get("extensionsUsed", [])) or any("extensions" in nd and "KHR_lights_punctual" in nd["extensions"] for nd in g["nodes"]):
        problems.append("a light node")
    low = high = 0.0
    for mesh in g["meshes"]:
        for prim in mesh["primitives"]:
            acc = g["accessors"][prim["attributes"]["POSITION"]]
            view = g["bufferViews"][acc["bufferView"]]
            base = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            for k in range(acc["count"]):
                x, y, z = struct.unpack_from("<fff", data, base + k * stride)
                r = math.hypot(x, z)
                if y < LOW_BAND:
                    low = max(low, r)
                else:
                    high = max(high, r)
    if low > RADIUS + 1e-3:
        problems.append("below 2 m reaches %.3f m, past the %.1f m collider" % (low, RADIUS))
    if high > REACH + 1e-3:
        problems.append("above 2 m reaches %.3f m, past %.1f m" % (high, REACH))
    print("KF6 %s class=%s T=%d V=%d D=%d clips=%s low=%.3f high=%.3f SHA256=%s" % (
        os.path.basename(path), cls, tris, verts, draws, ",".join("%s:%.2f" % kv for kv in sorted(lengths.items())),
        low, high, hashlib.sha256(data).hexdigest()))
    if problems:
        raise SystemExit("KF6 check failed for %s: %s" % (path, "; ".join(problems)))


def check_reach(label, worst):
    problems = []
    for clip, (low, high) in worst.items():
        print("KF6_REACH %s %s low=%.3f high=%.3f" % (label, clip, low, high))
        if low > RADIUS + 1e-3:
            problems.append("%s below 2 m %.3f" % (clip, low))
        if high > REACH + 1e-3:
            problems.append("%s above 2 m %.3f" % (clip, high))
    if problems:
        raise SystemExit("KF6 collider rule failed for %s: %s" % (label, "; ".join(problems)))


def render(paths, outdir):
    """Preview frames of the imported GLBs at 20, 60 and 150 m, the ball's approach view."""
    common.reset()
    for p in paths:
        bpy.ops.import_scene.gltf(filepath=p)
    scene = bpy.context.scene
    root = common.empty("PreviewRoot")
    for o in list(scene.objects):
        if o.parent is None and o != root:
            o.parent = root
    for dist in (20, 60, 150):
        common.render_turntable(root, "swarm_%dm" % dist, outdir, [("d%d" % dist, float(dist), 0.12, 50, (1280, 720))],
                                ground_z=0.0, target=(0, 0, 4.0), yaws=(0, 120))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=common.MODELS)
    ap.add_argument("--count-only", action="store_true")
    ap.add_argument("--render", default=None)
    a = ap.parse_args(argv)
    body_path = os.path.join(a.out, "warden_swarm.glb")
    kit_path = os.path.join(a.out, "warden_swarm_kit_drones.glb")

    common.reset()
    arm, hive, markers, cells, plates = build_body()
    for c in cells:
        c["rest"] = arm.data.bones[c["name"]].matrix_local.to_3x3()
    for ring in SHED_RINGS:
        RING_REST[ring] = arm.data.bones[ring].matrix_local.to_3x3()
    print("KF6_COUNT body tris=%d bones=%d cells=%d shuttered=%d" % (
        common.tris(hive), len(arm.data.bones), len(cells), sum(1 for c in cells if c["shutters"])))
    if a.count_only:
        print("KF6_REACH body rest low=%.3f high=%.3f" % rest_reach(hive))
    else:
        author_clips(arm, lambda clip, t: body_pose(clip, t, cells, plates))
        check_reach("body", reach(hive, arm, HELD + ("pulse",)))
        export([arm, hive] + markers, body_path)

    common.reset()
    karm, kit, rest = build_kit()
    print("KF6_COUNT kit tris=%d bones=%d" % (common.tris(kit), len(karm.data.bones)))
    if a.count_only:
        print("KF6_REACH kit rest low=%.3f high=%.3f" % rest_reach(kit))
        return
    author_clips(karm, lambda clip, t: kit_pose(clip, t, karm, rest))
    check_reach("kit", reach(kit, karm, KIT_HELD))
    export([karm, kit], kit_path)

    check(body_path, "warden_swarm")
    check(kit_path, "warden_swarm_kit_drones")
    if a.render:
        render([body_path, kit_path], a.render)


main()
