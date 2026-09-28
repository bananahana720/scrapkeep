# The parts every class shell shares (VISUAL-LANGUAGE.md section 9): a lopsided scrap
# ball core that rolls, an upright pod saddle that yaws to the heading, and a glass
# cockpit dome with the pilot bust inside. Provenance: authored procedurally here from
# Blender primitives and bmesh operators; no external assets. Shared by
# shell_sable.py, shell_rivet.py and shell_kest.py.
#
# Axes: Blender +Z is up and +Y is forward, which glTF export turns into Godot +Y up and
# -Z forward. The ball centre is the origin and the player collider radius is 1.0 m
# (src/movement/tuning.gd RADIUS), so the core stays inside CORE_LIMIT.
#
# Node contract read by src/presentation/hero_assets.gd:
#   Shell (root)
#     Core   rolls with the ball
#     Pod    stays upright and yaws to the heading; carries the class kit
#       Dome   the cockpit glass and rim, origin at the dome centre
#         Pilot  the animal bust, origin at the dome centre

import math
import random

import bmesh
from mathutils import Vector

import common
from common import Part

CORE_LIMIT = 0.985
SHELL_TRIS = (3000, 5000)
PILOT_TRIS = (400, 800)


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
    part.uv("pilot", r, 6, 4, loc=loc, color="charcoal")
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


def finish(name, root, core_obj, pilot_obj):
    a = common.args()
    shell_tris = common.tri_total(root, skip=(pilot_obj.name,))
    ok = common.report(name, [("shell", shell_tris, SHELL_TRIS),
                              ("pilot", common.tris(pilot_obj), PILOT_TRIS)])
    radius = common.max_radius(core_obj)
    print("CORE_RADIUS %s %.3f %s" % (name, radius, "ok" if radius <= 1.0 else "OUT"))
    common.export(root, a["out"] or common.default_out("shell_" + name.lower()))
    if a["render"]:
        common.render_turntable(root, "shell_" + name.lower(), a["render"], [
            ("game", 8.0, 0.30, 65, (1920, 1080), 0.5),
            ("close", 3.6, 0.28, 38, (640, 640)),
        ], ground_z=-1.0, target=(0, 0, 0.25))
    if not ok or radius > 1.0:
        raise SystemExit("budget out of range for " + name)


def rng_for(name):
    return random.Random("scrapkeep-" + name)
