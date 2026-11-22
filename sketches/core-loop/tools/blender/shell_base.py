# Procedural class shells. VD-01 puts the clear rolling sphere under Core and
# the seated pilot, equipment and independent gyro under upright Pod.
# Blender +Z is up, +Y forward; glTF becomes Godot +Y up, -Z forward.
# Original shape helpers remain for recipe equipment. spherical() owns the new assembly.

import math
import random

import bmesh
from mathutils import Vector

import common
from common import Part

CORE_LIMIT = 0.985
SHELL_TRIS = (3000, 6500)
PILOT_TRIS = (400, 4800)


def scrap_core(part, rng, radius=0.84, panels=24, lift=(0.03, 0.09), bolts=26, lopsided=0.045):
    """Icosphere cut into Voronoi plate panels: charcoal seams, rubbed-bright plate
    edges, mismatched paint tops, a scatter of bolt heads, then scaled to fit."""
    bm = part.bm
    before = set(bm.verts)
    res = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=radius)
    faces = part._faces(res["verts"])
    for v in res["verts"]:
        n = v.co.normalized()
        k = 1.0 + lopsided * (0.6 * math.sin(2.1 * n.x + 0.7) + 0.4 * math.sin(3.3 * n.y - 1.1) + 0.5 * n.x)
        v.co = n * radius * k
    seeds = []
    while len(seeds) < panels:
        s = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)))
        if s.length > 1e-3:
            seeds.append(s.normalized())
    groups = [[] for _ in seeds]
    for f in faces:
        c = f.calc_center_median().normalized()
        groups[max(range(len(seeds)), key=lambda i: c.dot(seeds[i]))].append(f)
    last = None
    tops_all = []
    for g in groups:
        if not g:
            continue
        normal = sum((f.normal for f in g), Vector()).normalized()
        inset = bmesh.ops.inset_region(bm, faces=g, thickness=0.022, depth=0.0, use_even_offset=True)
        part.paint(inset["faces"], "rubber")
        ext = bmesh.ops.extrude_face_region(bm, geom=g)
        new_verts = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
        new_faces = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMFace)]
        bmesh.ops.translate(bm, vec=normal * rng.uniform(*lift), verts=new_verts)
        bmesh.ops.delete(bm, geom=[f for f in g if f.is_valid], context="FACES")
        vs = set(new_verts)
        bm.faces.index_update()
        new_faces.sort(key=lambda f: f.index)
        tops = [f for f in new_faces if all(v in vs for v in f.verts)]
        sides = [f for f in new_faces if f not in tops]
        choice = rng.choice([c for c in common.PAINT_SET if c != last])
        last = choice
        part.paint(tops, "paint", choice)
        part.paint(sides, "bare_metal")
        tops_all.extend(tops)
    bm.faces.index_update()
    tops_all.sort(key=lambda f: f.index)
    for f in rng.sample(tops_all, min(bolts, len(tops_all))):
        part.bolt(f.calc_center_median(), f.normal, r=0.03, h=0.03)
    core_verts = [v for v in bm.verts if v not in before]
    far = max(v.co.length for v in core_verts)
    if far > CORE_LIMIT:
        for v in core_verts:
            v.co *= CORE_LIMIT / far


def truss_cage(part, radius=0.95, width=0.05):
    """An open icosahedral truss around the core, joints included, inside the collider."""
    phi = (1 + 5 ** 0.5) / 2
    raw = [(-1, phi, 0), (1, phi, 0), (-1, -phi, 0), (1, -phi, 0), (0, -1, phi), (0, 1, phi),
           (0, -1, -phi), (0, 1, -phi), (phi, 0, -1), (phi, 0, 1), (-phi, 0, -1), (-phi, 0, 1)]
    pts = [Vector(p).normalized() * radius for p in raw]
    edge_len = min((pts[0] - p).length for p in pts[1:])
    for i in range(12):
        for j in range(i + 1, 12):
            if abs((pts[i] - pts[j]).length - edge_len) < 1e-3:
                part.beam("bare_metal", pts[i], pts[j], width)
        part.ico("rubber", width * 0.95, 1, loc=pts[i])


def saddle(part, center=(0.0, 0.0, 0.78), r_in=0.44, r_out=0.64, color="petrol"):
    """The ring the pod rides on, hugging the top of the ball."""
    cx, cy, cz = center
    part.ring("paint", r_in, r_out, 0.1, 18, loc=(cx, cy, cz), color=color, taper=0.05)
    part.ring("rubber", r_in + 0.02, r_out + 0.03, 0.04, 18, loc=(cx, cy, cz - 0.06))
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        r = (r_in + r_out) / 2
        part.bolt((cx + r * math.cos(a), cy + r * math.sin(a), cz + 0.05), (0, 0, 1), r=0.03, h=0.03)


def dome(part, center, radius):
    """Glass hemisphere plus a bolted rim ring."""
    c = Vector(center)
    res = bmesh.ops.create_uvsphere(part.bm, u_segments=16, v_segments=10, radius=radius,
                                    matrix=common.mtx(c))
    low = [v for v in res["verts"] if v.co.z < c.z - 1e-4]
    bmesh.ops.delete(part.bm, geom=low, context="VERTS")
    glass = [f for f in part._faces([v for v in res["verts"] if v.is_valid])]
    part.paint(glass, "glass")
    part.ring("bare_metal", radius - 0.03, radius + 0.05, 0.07, 16, loc=c)
    for k in range(8):
        a = k * math.tau / 8
        part.bolt((c.x + (radius + 0.01) * math.cos(a), c.y + (radius + 0.01) * math.sin(a), c.z + 0.035),
                  (0, 0, 1), r=0.022, h=0.02)


def eye(part, loc, r=0.036):
    x, y, z = loc
    part.uv("pilot", r, 12, 8, loc=loc, scale=(1, 0.6, 1.1), color="charcoal")
    part.box("pilot", (r * 0.5, r * 0.3, r * 0.5), loc=(x + r * 0.3, y + r * 0.85, z + r * 0.35), color="bone")


def ear(part, base, height, width, tilt, color, inner=None, tip=None):
    """A flat triangular ear standing at base, leaning outward by tilt (radians)."""
    m = common.mtx(base, (math.pi / 2, tilt, 0))
    part.prism("pilot", [(-width / 2, 0), (width / 2, 0), (0, height)], 0.045, matrix=m, color=color)
    if inner:
        mi = common.mtx(base, (math.pi / 2, tilt, 0)) @ common.mtx((0, 0.02, -0.03))
        part.prism("pilot", [(-width * 0.3, 0), (width * 0.3, 0), (0, height * 0.7)], 0.02, matrix=mi, color=inner)
    if tip:
        mt = common.mtx(base, (math.pi / 2, tilt, 0))
        f = 0.7
        part.prism("pilot", [(-width / 2 * (1 - f), height * f), (width / 2 * (1 - f), height * f), (0, height)],
                   0.055, matrix=mt, color=tip)


def assemble(name, core, pod, dome_part, pilot, dome_center, extras=()):
    """Builds the node tree in the contract above. extras: (Part, origin) under Pod,
    or (name, origin) for an empty."""
    root = common.empty("Shell" + name)
    core_obj = core.to_object((0, 0, 0), root)
    pod_obj = pod.to_object((0, 0, 0), root)
    dome_obj = dome_part.to_object(dome_center, pod_obj)
    pilot_obj = pilot.to_object(dome_center, dome_obj)
    for item, origin in extras:
        if isinstance(item, str):
            common.empty(item, origin, pod_obj)
        else:
            item.to_object(origin, pod_obj)
    return root, core_obj, pilot_obj


def finish(name, root, core_obj, pilot_obj, shell_band=SHELL_TRIS, pod_obj=None, out=None):
    """Reports, checks and exports a shell. The Core check is at CORE_LIMIT (ROSTER-LOOK
    section 3 rule 6). With pod_obj (Hoberman shells) it also checks the Pod's reach below
    Z -0.6 and the sight cone (sight_cone_hits). A pilot that is an empty has no tri band."""
    a = common.args()
    shell_tris = common.tri_total(root, skip=(pilot_obj.name,))
    rows = [("shell", shell_tris, shell_band)]
    if pilot_obj.type == "MESH":
        rows.append(("pilot", common.tris(pilot_obj), PILOT_TRIS))
    ok = common.report(name, rows)
    radius = common.max_radius(core_obj)
    core_ok = radius <= CORE_LIMIT + 1e-4
    print("CORE_RADIUS %s %.4f limit %.3f %s" % (name, radius, CORE_LIMIT, "ok" if core_ok else "OUT"))
    pod_ok = True
    if pod_obj is not None:
        low = low_reach(pod_obj)
        cone = sight_cone_hits(pod_obj)
        print("POD_LOW_REACH %s %d vertices past radius %.2f below Z %.2f %s"
              % (name, low, LOW_RADIUS, LOW_Z, "ok" if low == 0 else "OUT"))
        print("SIGHT_CONE %s %d solid Pod vertices inside the %.0f degree cone %s"
              % (name, cone, SIGHT_HALF_ANGLE, "ok" if cone == 0 else "OUT"))
        pod_ok = low == 0 and cone == 0
    common.export(root, out or a["out"] or common.default_out("shell_" + name.lower()))
    if a["render"]:
        common.render_turntable(root, "shell_" + name.lower(), a["render"], [
            ("game", 8.0, 0.30, 65, (1920, 1080), 0.5),
            ("close", 3.6, 0.28, 38, (640, 640)),
        ], ground_z=-1.0, target=(0, 0, 0.25))
    if not ok or not core_ok or not pod_ok:
        raise SystemExit("budget out of range for " + name)


def rng_for(name):
    return random.Random("scrapkeep-" + name)


def spherical(name, kit, animal, extras=()):
    """VD-01: full glass rolling hull, upright cockpit, independent gyro bearing."""
    root = common.empty("Shell" + name)
    hull = Part("Core")
    hull.uv("glass", 0.98, 40, 24)
    core = hull.to_object((0, 0, 0), root)
    for polygon in core.data.polygons:
        polygon.use_smooth = True
    # Refit the existing class equipment below shoulder height, inside the ball.
    def kit_point(point):
        v = Vector(point)
        return Vector((v.x * 0.67, v.y * 0.67, (v.z - 0.78) * 0.67 - 0.28))
    for v in kit.bm.verts:
        v.co = kit_point(v.co)
    kit.ring("paint", 0.86, 0.92, 0.12, 48, loc=(0, 0, -0.29), color="petrol")
    for k in range(16):
        a = k * math.tau / 16
        normal = Vector((math.cos(a), math.sin(a), 0))
        kit.bolt(normal * 0.925 + Vector((0, 0, -0.29)), normal, r=0.018, h=0.015)
        # Broken enamel at the rim exposes small warm metal edges.
        kit.ring("paint", 0.916, 0.925, 0.04, 2, loc=(0, 0, -0.26), color="bone",
                 arc=(a + 0.06, a + 0.13))
    kit.cyl("rubber", 0.36, 0.28, 0.16, 20, loc=(0, 0, -0.6))
    for z in (-0.62, -0.69, -0.76):
        kit.ring("field", 0.18, 0.25, 0.027, 24, loc=(0, 0, z))
    seat = [(-0.22, -0.27), (0.22, -0.27), (0.27, -0.20), (0.24, 0.14), (0.16, 0.20), (-0.16, 0.20), (-0.24, 0.14), (-0.27, -0.20)]
    kit.prism("paint", seat, 0.09, matrix=common.mtx((0, -0.27, -0.1), (math.pi / 2, 0, 0)), color="oxide")
    kit.uv("rubber", 0.22, 12, 8, loc=(0, -0.22, -0.12), scale=(1.0, 0.35, 1.15))
    kit.box("rubber", (0.48, 0.42, 0.09), loc=(0, 0, -0.34))
    for side in (-1, 1):
        kit.rod("bare_metal", (side * 0.34, 0.28, -0.32), (side * 0.32, 0.4, 0.0), 0.025, 8)
        kit.rod("rubber", (side * 0.32, 0.4, 0.0), (side * 0.32, 0.4, 0.1), 0.045, 8)
    pod = kit.to_object((0, 0, 0), root)
    dome = common.empty("Dome", (0, 0, 0), pod)
    # Head groups are reduced together; the connected seated body stays full size.
    for v in animal.bm.verts:
        v.co = (v.co - Vector((0, 0.2 if name == "Kest" else 0.0, 1.1))) * 1.2325 + Vector((0, 0.015, 0.17))
    jacket = "bone" if name == "Rivet" else "oxide"
    animal.uv("pilot", 0.26, 20, 12, loc=(0, -0.005, -0.17), scale=(1.07, 0.78, 1.0), color=jacket)
    animal.uv("pilot", 0.13, 12, 8, loc=(0, 0.035, 0.005), scale=(1.2, 0.75, 0.6), color="bone")
    for side in (-1, 1):
        animal.uv("pilot", 0.12, 8, 6, loc=(side * 0.18, 0.18, -0.3), scale=(1, 1.5, 0.85), color="oxide")
        animal.rod("pilot", (side * 0.18, 0.2, -0.3), (side * 0.2, 0.38, -0.46), 0.09, 8, color="petrol")
        animal.uv("pilot", 0.1, 8, 6, loc=(side * 0.2, 0.45, -0.48), scale=(1, 1.4, 0.6), color="charcoal")
        animal.uv("pilot", 0.12, 12, 8, loc=(side * 0.22, 0.005, -0.09), scale=(1.0, 0.85, 1.12), color=jacket)
        animal.rod("pilot", (side * 0.24, 0.015, -0.09), (side * 0.36, 0.24, -0.12), 0.09, 8, color=jacket)
        animal.rod("pilot", (side * 0.36, 0.24, -0.12), (side * 0.32, 0.4, 0.04), 0.07, 8, color="charcoal")
        animal.uv("pilot", 0.075, 8, 6, loc=(side * 0.32, 0.4, 0.05), color="sandstone")
        animal.beam("pilot", (side * 0.16, 0.22, -0.25), (side * 0.14, 0.19, 0.06), 0.035, 0.02, color="copper")
    animal.bm.normal_update()
    for face in animal.bm.faces:
        face.smooth = True
    for edge in animal.bm.edges:
        if edge.is_manifold and edge.calc_face_angle() > 1.2:
            edge.smooth = False
    pilot_obj = animal.to_object((0, 0, 0), dome)
    gyro = Part("Gyro")
    gyro.ring("bare_metal", 0.938, 0.965, 0.055, 64, rot=(math.pi / 2, 0, 0))
    gyro.ring("paint", 0.946, 0.972, 0.028, 64, rot=(math.pi / 2, 0, 0), color="oxide")
    for side in (-1, 1):
        gyro.cyl("class_accent", 0.065, 0.065, 0.024, 12, loc=(side * 0.94, 0, 0), rot=(0, math.pi / 2, 0))
    gyro.to_object((0, 0, 0), pod)
    for item, origin in extras:
        if isinstance(item, str):
            common.empty(item, kit_point(origin), pod)
        else:
            for v in item.bm.verts:
                v.co = kit_point(v.co)
            item.to_object(kit_point(origin), pod)
    return root, core, pilot_obj


# --- Hoberman mecha (ROSTER-LOOK section 0; unit PD-0 HOBERMAN-BASE) ----------------------
#
# hoberman() builds the base every pilot shell stands on. Node tree, origin at the ball centre:
#   Core                the fully expanded Hoberman lattice; tumbles with the ball. 32 copper hubs
#                       with rubber tread caps, Hub.00 to Hub.11 five-way and Hub.12 to Hub.31
#                       three-way, joined by 60 scissor chains of X-pairs, and Gap.00 to Gap.29
#                       empties at the 30 open diamonds.
#   Pod                 upright, turns to the heading: seat, DecalPlate, the CONTROLS layout, the
#                       outer gimbal bosses and axles.
#   Pod > Gyro          the two nested gimbal rings, one mesh (see GIMBAL_INNER).
#   Pod > WeaponRing    the level band over its bearing collar; hero_assets yaws it to the aim.
#                       WeaponMount marks the weapon's seat on the front arc.
#   Pod > Dome > Pilot  where the animated pilot sits; an empty unless the recipe passes a body.
# Every Hub, Gap and Control empty faces outward or up: its local +Z (Godot +Y) points away
# from the centre for Hub and Gap. Blender +Y forward, +Z up; Godot -Z forward, +Y up.
# Draws (one per slot per mesh): Core paint, copper, rubber; Pod paint, rubber, copper; Gyro
# rubber; WeaponRing paint, rubber, copper. That is 10, the shell class cap
# (assets/asset_budgets.json). A slot a recipe adds to any of these meshes costs a draw.

# Copper keeps its colour under any equipped paint (ROSTER-LOOK section 6); hero_assets.SLOTS
# carries the runtime row.
common.SLOTS.setdefault("copper", {"color": "copper", "metal": 0.6, "rough": 0.4})

# Lattice radii (ROSTER-LOOK sections 0.1 and 2). The strut pair is 0.035 m thick, outer face
# 0.975, inner face 0.94; the hub caps' tread faces reach CORE_LIMIT.
LATTICE_OUTER = 0.975
STRUT_PAIR = 0.035
LATTICE_INNER = LATTICE_OUTER - STRUT_PAIR
HUB_RADIUS = LATTICE_OUTER - STRUT_PAIR / 2
# Strut bar face width and hub tread cap diameter. hoberman() and lattice() take strut_width and
# cap_width; these are the defaults. 2026-10-10 (PD-0b): 0.10 / 0.14 (ROSTER-LOOK section 3 rule 7)
# down to 0.06 / 0.10 by the strut-table rule: no width from 0.10 to 0.05 met rule 1 (pilot 75%,
# head 90%) on the neutral shell, so the rule's fallback applies (0.06 m is about 6 px at the
# chase mid eye); the coordinator re-pins rules 1 and 7 from that table.
BAR_WIDTH = 0.06
CAP_WIDTH = 0.10
CHAIN_WIDTH = 0.12
HUB_BODY = (0.10, 0.937, LATTICE_OUTER)      # radius, inner and outer reach of the copper drum
# The rubber tread cap: radius, the reach of its buried point and of its tread face, whose rim
# reaches CORE_LIMIT. Its sides close to the point inside the copper drum (_tread_cap).
HUB_CAP = (CAP_WIDTH / 2, 0.940, 0.9824)
HUB_CLEAR = 0.075                            # chain ends tuck under the hub drum
PIN_DEPTH = 0.012                            # a pin's buried point, inside the outer bar
# One equator gap faces the front (+Y) and one the rear, so the face and the head show
# through open diamonds in the rest pose.
LATTICE_TWIST = math.radians(72)
# Gimbal rings: inside clears the kept-clip envelope of Tarn, Tally and the Cannon (0.799 m,
# PD-0 envelope-kept.json) by 0.03 m; the outer ring stays inside the lattice inner face, and
# inside it at the 0.92 landing fold. Rivet's, Sable's and Kest's kept clips reach 0.92 to
# 1.03 m, past the lattice itself (cage_contract_test KNOWN_OVER); no ring here can clear them,
# so their clip units (PE-RIVET, PE-SABLE, PE-KEST) re-key those clips.
GIMBAL_INNER = (0.830, 0.846)
GIMBAL_OUTER = (0.848, 0.862)
GIMBAL_DEPTH = 0.04
# Weapon ring: band 1.03 to 1.08 m, 0.08 m tall, at the equator; the collar sits under it.
RING_BAND = (1.03, 1.08, 0.08, 0.0)
RING_COLLAR = (1.035, 1.075, 0.03, -0.055)
RING_SEGMENTS = 40
# The cockpit control layout, the same in all six (ROSTER-LOOK 0.7, PILOT-CLIPS section 5).
# Each name becomes a Control.<name> empty under Pod at its point (Blender metres, Pod space).
# BANK holds the slot 2 and slot 3 points beside the right yoke; a recipe names them through
# hoberman(bank=...), e.g. (("GaugeLever", "lever"), ("SpoolBrake", "lever")) for Sable.
CONTROLS = {
    "Grip.L": (-0.32, 0.40, 0.05),
    "Grip.R": (0.32, 0.40, 0.05),
    "Trigger": (0.32, 0.43, 0.09),
    "LapBar": (0.0, 0.05, -0.33),
    "Pedal.L": (-0.13, 0.45, -0.62),
    "Pedal.R": (0.13, 0.45, -0.62),
}
LAP_HANDS = {"LapBar.L": (-0.14, 0.28, -0.17), "LapBar.R": (0.14, 0.28, -0.17)}
BANK = [(0.52, 0.30, -0.27), (0.52, 0.18, -0.27)]
BANK_KINDS = ("lever", "button", "plunger", "crank", "key", "tab")
SEAT_TOP = -0.30
SEAT_BACK_TOP = -0.10
DECAL_PLATE = ((0.0, -0.2325, -0.25), (0.36, 0.015, 0.30))
# Sight cone (ROSTER-LOOK section 3 rule 3): from the pilot's head to the chase eyes at the
# close, mid and far cameras (section 9 step 6, here in Blender axes), half-angle 35 degrees.
HEAD = Vector((0.0, 0.02, 0.20))
CHASE_EYES = (Vector((0.0, -3.44, 1.06)), Vector((0.0, -7.17, 2.22)), Vector((0.0, -11.46, 3.55)))
SIGHT_HALF_ANGLE = 35.0
LOW_RADIUS = 1.0
LOW_Z = -0.6


def lattice_layout(twist=LATTICE_TWIST):
    """Unit directions of the icosahedral Hoberman layout: (hubs, links, gaps). hubs[0:12] are
    the five-way hubs (icosahedron vertices), hubs[12:32] the three-way hubs (face centres);
    links pair a five-way and a three-way index (60); gaps are the 30 diamond centres, each
    the midpoint of two neighbouring five-way hubs. accretion.gd mirrors this layout."""
    zr, rr = 1 / 5 ** 0.5, 2 / 5 ** 0.5
    five = [Vector((0, 0, 1))]
    for k in range(5):
        a = twist + k * math.tau / 5
        five.append(Vector((rr * math.cos(a), rr * math.sin(a), zr)))
    for k in range(5):
        a = twist + math.pi / 5 + k * math.tau / 5
        five.append(Vector((rr * math.cos(a), rr * math.sin(a), -zr)))
    five.append(Vector((0, 0, -1)))
    edge = min((five[0] - p).length for p in five[1:])
    edges = [(i, j) for i in range(12) for j in range(i + 1, 12) if abs((five[i] - five[j]).length - edge) < 1e-6]
    linked = set(edges)
    faces = [(i, j, k) for i, j in edges for k in range(j + 1, 12) if (i, k) in linked and (j, k) in linked]
    three = [(five[i] + five[j] + five[k]).normalized() for i, j, k in faces]
    links = [(v, 12 + f) for f, face in enumerate(faces) for v in face]
    gaps = [(five[i] + five[j]).normalized() for i, j in edges]
    return five + three, links, gaps


def _frame(n):
    """Two unit vectors spanning the plane normal to n, e1 x e2 = n."""
    n = Vector(n).normalized()
    e1 = Vector((0, 0, 1)).cross(n) if abs(n.z) < 0.9 else Vector((1, 0, 0)).cross(n)
    e1.normalize()
    return e1, n.cross(e1)


# Watertight rule (POLISH.md, "Watertight"): every piece the base builds is a closed island, so
# the light bake and cull_back shadows cannot see through it; check_manifold.py proves a GLB.
# Each closed piece costs no more triangles than the open piece it replaced.

def _bar(part, a, b, width, thick, slot, color=None, facing=1):
    """A closed bar from a to b lying on the sphere: a three-sided prism with a flat face width
    across and a ridge thick from it. facing 1 turns the flat face away from the centre, -1
    toward it. Three sides and two end caps are 8 triangles, as many as the old open tube."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    n = ((a + b) / 2).normalized()
    u = d.cross(n).normalized()
    n = u.cross(d)
    corners = [(facing, facing), (-facing, facing), (0, -facing)]
    ra = [part.bm.verts.new(a + u * (sx * width / 2) + n * (sy * thick / 2)) for sx, sy in corners]
    rb = [part.bm.verts.new(b + u * (sx * width / 2) + n * (sy * thick / 2)) for sx, sy in corners]
    faces = [part.bm.faces.new((ra[k], rb[k], rb[(k + 1) % 3], ra[(k + 1) % 3])) for k in range(3)]
    faces.append(part.bm.faces.new(ra))
    faces.append(part.bm.faces.new(list(reversed(rb))))
    return part.paint(faces, slot, color)


# A stud's corners sit this far out for the old disc's radius, so its triangle keeps most of the
# hexagon's area (72%) and still sits on its bar.
STUD_SPAN = 1.2


def _stud(part, centre, normal, radius, depth, slot, color=None, toward=None, roll=0.0):
    """A closed pin head: a flat triangle facing along normal at centre, closed by three faces to a
    point depth below it, buried in the part under it. 4 triangles, as many as a 6-sided _disc.
    One corner points along toward when given (a link's direction), else at roll."""
    c, nrm = Vector(centre), Vector(normal).normalized()
    e1, e2 = _frame(nrm)
    if toward is not None:
        t = Vector(toward)
        t = t - nrm * t.dot(nrm)
        if t.length > 1e-9:
            e1 = t.normalized()
            e2 = nrm.cross(e1)
            roll = 0.0
    r = radius * STUD_SPAN
    vs = [part.bm.verts.new(c + r * (math.cos(roll + k * math.tau / 3) * e1 + math.sin(roll + k * math.tau / 3) * e2))
          for k in range(3)]
    tip = part.bm.verts.new(c - nrm * depth)
    faces = [part.bm.faces.new(vs)] + [part.bm.faces.new((vs[(k + 1) % 3], vs[k], tip)) for k in range(3)]
    return part.paint(faces, slot, color)


def _tread_cap(part, direction, radius, r_tip, r_out, sides, slot, roll=0.0, color=None):
    """A closed cap on the radial axis through direction: a flat face at r_out from the centre
    whose sides close to a point at r_tip, buried in the part under it. 2 x sides - 2 triangles,
    sides fewer than an open-bottomed _drum (3 x sides - 2)."""
    n = Vector(direction).normalized()
    e1, e2 = _frame(n)
    hi = [part.bm.verts.new(n * r_out + radius * (math.cos(roll + k * math.tau / sides) * e1
                                                  + math.sin(roll + k * math.tau / sides) * e2)) for k in range(sides)]
    tip = part.bm.verts.new(n * r_tip)
    faces = [part.bm.faces.new(hi)] + [part.bm.faces.new((hi[(k + 1) % sides], hi[k], tip)) for k in range(sides)]
    return part.paint(faces, slot, color)


def _disc(part, centre, normal, radius, sides, slot, color=None, roll=0.0):
    """A flat polygon facing along normal: one face, so an open island. The base's own pins,
    studs and chalk mark use _stud; this stays for recipe marks that sit flush on a face."""
    c = Vector(centre)
    e1, e2 = _frame(normal)
    vs = [part.bm.verts.new(c + radius * (math.cos(roll + k * math.tau / sides) * e1
                                          + math.sin(roll + k * math.tau / sides) * e2)) for k in range(sides)]
    return part.paint([part.bm.faces.new(vs)], slot, color)


def _drum(part, direction, radius, r_in, r_out, sides, slot, roll=0.0, bottom=True, color=None):
    """A drum on the radial axis through direction, from radius r_in to r_out from the centre."""
    n = Vector(direction).normalized()
    e1, e2 = _frame(n)
    ring = [math.cos(roll + k * math.tau / sides) * e1 + math.sin(roll + k * math.tau / sides) * e2
            for k in range(sides)]
    lo = [part.bm.verts.new(n * r_in + radius * p) for p in ring]
    hi = [part.bm.verts.new(n * r_out + radius * p) for p in ring]
    faces = [part.bm.faces.new(hi)]
    if bottom:
        faces.append(part.bm.faces.new(list(reversed(lo))))
    sides_f = [part.bm.faces.new((lo[k], lo[(k + 1) % sides], hi[(k + 1) % sides], hi[k])) for k in range(sides)]
    return part.paint(faces + sides_f, slot, color)


def _sharpen(part, angle=0.9):
    """Rounded parts read smooth, flat parts keep hard edges: smooth faces stay smooth across
    shallow edges only, so the exporter splits vertices only where the shape turns a corner."""
    part.bm.normal_update()
    for f in part.bm.faces:
        f.smooth = True
    for e in part.bm.edges:
        if e.is_manifold and e.calc_face_angle() > angle:
            e.smooth = False


def _slerp(a, b, t):
    om = a.angle(b)
    return (a * math.sin((1 - t) * om) + b * math.sin(t * om)) / math.sin(om)


def lattice(part, enamel="petrol", pairs=2, hub_sides=8, cap_sides=8, rng=None, strut_width=BAR_WIDTH, cap_width=CAP_WIDTH):
    """The Core: hubs with tread caps and the scissor chains between them, every piece a closed
    island. Returns the layout."""
    rng = rng or random.Random("scrapkeep-hoberman")
    cap_r = cap_width / 2
    hubs, links, gaps = lattice_layout()
    r_outer_bar = LATTICE_OUTER - STRUT_PAIR / 4
    r_inner_bar = LATTICE_INNER + STRUT_PAIR / 4
    for i, j in links:
        a, b = hubs[i], hubs[j]
        s = a.cross(b).normalized()
        span = HUB_CLEAR / (HUB_RADIUS * a.angle(b))
        for k in range(pairs):
            t0 = span + (1 - 2 * span) * k / pairs
            t1 = span + (1 - 2 * span) * (k + 1) / pairs
            c0, c1, cm = _slerp(a, b, t0), _slerp(a, b, t1), _slerp(a, b, (t0 + t1) / 2)
            # The pair's flat faces are its outer and inner faces (LATTICE_OUTER and LATTICE_INNER);
            # the two ridges point at each other between them.
            _bar(part, c0 * r_outer_bar - s * CHAIN_WIDTH / 2, c1 * r_outer_bar + s * CHAIN_WIDTH / 2,
                 strut_width, STRUT_PAIR / 2, "paint", enamel, facing=1)
            _bar(part, c0 * r_inner_bar + s * CHAIN_WIDTH / 2, c1 * r_inner_bar - s * CHAIN_WIDTH / 2,
                 strut_width, STRUT_PAIR / 2, "paint", enamel, facing=-1)
            _stud(part, cm * (LATTICE_OUTER + 0.002), cm, 0.028, PIN_DEPTH, "copper", toward=b - a)
            if k > 0:
                for side in (-1, 1):
                    p = c0 * (LATTICE_OUTER + 0.002) + s * (side * CHAIN_WIDTH / 2)
                    _stud(part, p, p, 0.022, PIN_DEPTH, "copper", toward=b - a)
    for h, d in enumerate(hubs):
        _drum(part, d, HUB_BODY[0], HUB_BODY[1], HUB_BODY[2], hub_sides, "copper", roll=0.0)
        # Rule 8: each cap's tread turns differently, so the pattern cannot strobe.
        _tread_cap(part, d, cap_r, HUB_CAP[1], HUB_CAP[2], cap_sides, "rubber", roll=rng.uniform(0, math.tau))
    # The chalk balance mark on one tread cap, so the eye can count a turn (rule 8); it scales
    # with the cap (0.035 m out, 0.018 m radius on the 0.14 m cap).
    e1, _ = _frame(hubs[0])
    _stud(part, hubs[0] * (HUB_CAP[2] + 0.0003) + e1 * (cap_r * 0.5), hubs[0], cap_r * 0.018 / 0.07, 0.004, "paint", "bone")
    _sharpen(part)
    return hubs, links, gaps


def _point_empty(name, direction, radius, parent):
    d = Vector(direction).normalized()
    obj = common.empty(name, d * radius, parent)
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    return obj


def weapon_ring(enamel_band="bone"):
    """The level band (worn bone segments, charcoal clamp blocks) over its dark collar with
    dark studs, and a neutral mount block on the front arc."""
    r = Part("WeaponRing")
    b_in, b_out, b_h, b_z = RING_BAND
    r.ring("paint", b_in, b_out, b_h, RING_SEGMENTS, loc=(0, 0, b_z), color=enamel_band)
    for k in range(10):
        a = (k + 0.5) * math.tau / 10
        r.box("rubber", (0.06, b_out - b_in + 0.012, b_h + 0.012), loc=((b_in + b_out) / 2 * math.cos(a),
              (b_in + b_out) / 2 * math.sin(a), b_z), rot=(0, 0, a + math.pi / 2))
    c_in, c_out, c_h, c_z = RING_COLLAR
    r.ring("rubber", c_in, c_out, c_h, RING_SEGMENTS, loc=(0, 0, c_z))
    # The collar studs and the mount rod ride the rubber slot, so WeaponRing is two draws and
    # the gimbal's inner ring can be its own mesh inside the 10-draw shell cap.
    for k in range(12):
        a = k * math.tau / 12 + 0.13
        n = Vector((math.cos(a), math.sin(a), 0))
        _stud(r, n * (c_out + 0.002) + Vector((0, 0, c_z)), n, 0.012, 0.006, "rubber")
    # Neutral weapon seat at 12 o'clock; a pilot recipe replaces it with its weapon.
    r.box("rubber", (0.14, 0.07, 0.11), loc=(0, b_out + 0.03, b_z))
    r.rod("rubber", (0, b_out + 0.06, b_z), (0, b_out + 0.13, b_z), 0.025, 8)
    _sharpen(r)
    return r


def gimbal():
    """The two nested gimbal rings, both upright and facing the front (mechanism.png panel C):
    Gyro, the outer ring, pivots on Pod's left-right axis (the Pod axles); GyroInner, the inner
    ring and the two bosses that join it to the outer ring at top and bottom, pivots on that
    vertical axis. Returns (outer, inner) Parts; each is one rubber draw."""
    outer = Part("Gyro")
    outer.ring("rubber", GIMBAL_OUTER[0], GIMBAL_OUTER[1], GIMBAL_DEPTH, RING_SEGMENTS, rot=(math.pi / 2, 0, 0))
    _sharpen(outer)
    inner = Part("GyroInner")
    inner.ring("rubber", GIMBAL_INNER[0], GIMBAL_INNER[1], GIMBAL_DEPTH, RING_SEGMENTS, rot=(math.pi / 2, 0, 0))
    for side in (-1, 1):
        inner.box("rubber", (0.05, GIMBAL_DEPTH + 0.02, GIMBAL_OUTER[1] - GIMBAL_INNER[0]),
                  loc=(0, 0, side * (GIMBAL_INNER[0] + GIMBAL_OUTER[1]) / 2))
    _sharpen(inner)
    return outer, inner


def _bank_control(p, point, kind):
    x, y, z = point
    if kind == "button":
        p.cyl("copper", 0.03, 0.03, 0.03, 8, loc=(x, y, z + 0.05))
    elif kind == "plunger":
        p.rod("rubber", (x, y, z), (x, y, z + 0.16), 0.016, 6)
        p.box("copper", (0.08, 0.02, 0.02), loc=(x, y, z + 0.17))
    elif kind == "crank":
        p.cyl("rubber", 0.06, 0.06, 0.02, 8, loc=(x - 0.02, y, z + 0.06), rot=(0, math.pi / 2, 0))
        p.rod("copper", (x - 0.03, y, z + 0.11), (x + 0.03, y, z + 0.11), 0.012, 6)
    elif kind in ("key", "tab"):
        p.box("copper", (0.03, 0.05, 0.08), loc=(x, y, z + 0.06))
    else:
        p.rod("rubber", (x, y, z), (x, y + 0.04, z + 0.17), 0.014, 6)
        p.uv("copper", 0.025, 6, 4, loc=(x, y + 0.04, z + 0.18))


def cockpit(seat="bone", bank=(("Slot2", "lever"), ("Slot3", "lever"))):
    """The upright Pod: seat and DecalPlate, twin yokes, the slot 2 and 3 bank beside the right
    yoke, the copper lap bar, two pedals, and the outer gimbal axles with copper bosses. Pod
    geometry stays inside the gimbal sweep (radius 0.829) except the bosses on the ring axis."""
    p = Part("Pod")
    p.box("paint", (0.44, 0.42, 0.07), loc=(0, 0.04, SEAT_TOP - 0.035), color=seat)
    p.box("paint", (0.44, 0.07, SEAT_BACK_TOP - SEAT_TOP + 0.1), loc=(0, -0.19, (SEAT_BACK_TOP + SEAT_TOP - 0.1) / 2),
          color=seat)
    p.box("rubber", (0.30, 0.30, 0.10), loc=(0, 0.0, SEAT_TOP - 0.12))
    (dx, dy, dz), size = DECAL_PLATE
    p.box("paint", size, loc=(dx, dy, dz), color=seat)
    # Floor rail to the pedals.
    p.beam("rubber", (0, 0.10, SEAT_TOP - 0.16), (0, 0.42, -0.66), 0.06)
    for side in (-1, 1):
        gx, gy, gz = CONTROLS["Grip.R"]
        p.rod("rubber", (side * gx, 0.30, SEAT_TOP - 0.06), (side * gx, gy, gz - 0.06), 0.02, 6)
        p.rod("rubber", (side * gx, gy, gz - 0.07), (side * gx, gy, gz + 0.07), 0.03, 8)
        px, py, pz = CONTROLS["Pedal.R"]
        p.box("rubber", (0.09, 0.15, 0.02), loc=(side * px, py, pz + 0.03), rot=(-0.5, 0, 0))
        # Outer gimbal axle and its copper boss on the ring axis.
        p.rod("rubber", (side * 0.24, -0.02, SEAT_TOP + 0.02), (side * 0.80, 0, 0), 0.02, 6)
        p.rod("copper", (side * 0.80, 0, 0), (side * 0.89, 0, 0), 0.04, 8)
    tx, ty, tz = CONTROLS["Trigger"]
    p.box("copper", (0.02, 0.03, 0.04), loc=(tx, ty, tz))
    # The lap bar: the largest control, copper, both hands on it for the ultimate.
    lx = LAP_HANDS["LapBar.R"][0] + 0.12
    _, ly, lz = LAP_HANDS["LapBar.R"]
    p.rod("copper", (-lx, ly, lz), (lx, ly, lz), 0.028, 8)
    hx, hy, hz = CONTROLS["LapBar"]
    for side in (-1, 1):
        p.rod("copper", (side * lx, ly, lz), (side * (lx - 0.02), hy, hz), 0.02, 6)
    # The bank beside the right yoke.
    p.box("rubber", (0.10, 0.26, 0.05), loc=(BANK[0][0], (BANK[0][1] + BANK[1][1]) / 2, BANK[0][2] - 0.02))
    for (name, kind), point in zip(bank, BANK):
        if kind not in BANK_KINDS:
            raise ValueError("unknown bank control kind %s for %s" % (kind, name))
        _bank_control(p, point, kind)
    _sharpen(p)
    return p


def hoberman(name, enamel="petrol", seat="bone", pairs=2, bank=(("Slot2", "lever"), ("Slot3", "lever")),
             pilot=None, hub_sides=8, cap_sides=8, strut_width=BAR_WIDTH, cap_width=CAP_WIDTH):
    """Builds the Hoberman base under a new root. pilot: a Part for the seated body (a recipe's
    placeholder), or None for an empty Pilot node. Returns {root, core, pod, gyro, ring, pilot,
    hubs, gaps} (Blender objects; hubs and gaps are the empties in index order)."""
    if len(bank) != len(BANK):
        raise ValueError("bank names the slot 2 and slot 3 controls, %d given" % len(bank))
    root = common.empty("Shell" + name)
    core_part = Part("Core")
    hub_dirs, _, gap_dirs = lattice(core_part, enamel, pairs, hub_sides, cap_sides, rng_for(name + "-lattice"),
                                    strut_width, cap_width)
    core = core_part.to_object((0, 0, 0), root)
    hubs = [_point_empty("Hub.%02d" % i, d, HUB_RADIUS, core) for i, d in enumerate(hub_dirs)]
    gaps = [_point_empty("Gap.%02d" % i, d, HUB_RADIUS, core) for i, d in enumerate(gap_dirs)]
    pod = cockpit(seat, bank).to_object((0, 0, 0), root)
    outer, inner = gimbal()
    gyro = outer.to_object((0, 0, 0), pod)
    inner.to_object((0, 0, 0), gyro)
    ring = weapon_ring().to_object((0, 0, 0), pod)
    common.empty("WeaponMount", (0, RING_BAND[1] + 0.13, RING_BAND[3]), ring)
    for cname, point in CONTROLS.items():
        common.empty("Control." + cname, point, pod)
    lap = bpy_object(pod, "Control.LapBar")
    for hname, point in LAP_HANDS.items():
        common.empty(hname, point, lap)
    for (cname, _), point in zip(bank, BANK):
        common.empty("Control." + cname, point, pod)
    common.empty("DecalPlate", (DECAL_PLATE[0][0], DECAL_PLATE[0][1] - DECAL_PLATE[1][1] / 2, DECAL_PLATE[0][2]), pod)
    dome = common.empty("Dome", (0, 0, 0), pod)
    pilot_obj = pilot.to_object((0, 0, 0), dome) if pilot is not None else common.empty("Pilot", (0, 0, 0), dome)
    return {"root": root, "core": core, "pod": pod, "gyro": gyro, "ring": ring, "pilot": pilot_obj,
            "hubs": hubs, "gaps": gaps}


def bpy_object(parent, name):
    return next(c for c in parent.children if c.name == name)


def low_reach(pod_obj):
    """Pod-subtree vertices past LOW_RADIUS below LOW_Z (rule 6: slopes must not swallow them)."""
    bad = 0
    for o in common.tree(pod_obj):
        if o.type != "MESH":
            continue
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co
            if w.z < LOW_Z and w.length > LOW_RADIUS:
                bad += 1
    return bad


def sight_cone_hits(pod_obj, head=HEAD, eyes=CHASE_EYES, half_angle=SIGHT_HALF_ANGLE):
    """Solid Pod vertices inside the sight cone from the head to any chase eye, over every mesh
    under Pod (heft layers and pilot modules included). Gyro and GyroInner (thin moving rings)
    and WeaponRing (the band) may cross the cone (rule 3) and are skipped with their children,
    as is Dome with the pilot."""
    cos_half = math.cos(math.radians(half_angle))
    axes = [(e - head).normalized() for e in eyes]
    bad = 0
    for o in cone_meshes(pod_obj):
        mw = o.matrix_world
        for v in o.data.vertices:
            d = (mw @ v.co) - head
            if d.length < 1e-6:
                continue
            d.normalize()
            if any(d.dot(a) > cos_half for a in axes):
                bad += 1
    return bad


CONE_SKIP = ("Gyro", "WeaponRing", "Dome")


def cone_meshes(obj, top=True):
    """Meshes under obj that the sight cone counts: obj itself and every descendant, minus the
    subtrees rooted at a CONE_SKIP node (a recipe's numbered duplicate such as Dome.001 too)."""
    if not top and obj.name.split(".")[0] in CONE_SKIP:
        return []
    out = [obj] if obj.type == "MESH" else []
    for c in obj.children:
        out += cone_meshes(c, False)
    return out
