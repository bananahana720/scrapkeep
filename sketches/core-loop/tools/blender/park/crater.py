"""Headless recipe for the crater family: crater_event and crater_ending (design-v3/PARK.md section 4, unit KC7).

Meteor Crater is the one landform older than any society. Both ids are rim recipes over the `crater` height stamp
(src/world/park/park_stamps.gd: a bowl of depth h inside stamp radius 0.8, a rim ring raised 0.2 h peaking at 0.85, flat
at 1.0). The GLB carries the stamp's own surface, so it stands alone or sits on a baked stamp, and adds the recipe: an
ejecta blanket from 1.0 to 1.5 stamp radii (a low apron of rays and hummocks), ejecta blocks on that blanket, and a
stratified wall (cream Kaibab limestone at the lip, sandstone, red slickrock, pale playa on the floor, desert varnish
streaks) painted in vertex colour. crater_event is the 40 to 60 m crater an impact leaves (KE5 overlays it);
crater_ending is the 400 m ending bowl (KC10 camera set, never a playable stage). The ending carries the same recipe at
8.4 times the size.

Convention, the same across the family: +Y up, the ride direction +Z (the fall line), origin at the entry lip on the
ground. The lip is where the stamp's inside wall crosses y 0 (stamp radius LIP_R = 0.7647) on the near (-Z) side, so the
bowl's centre is at z = LIP_R * F, the rim crest stands 0.2 h above the ground 0.085 F behind the origin, the far lip is
at z = 2 * LIP_R * F, and the blanket reaches 1.5 F from the centre. A park row places it by position, size and yaw; the
GLB is authored at its nominal size (F is the stamp radius in metres) and is never scaled.

Files per id, as park_recipes.gd loads them: <id>.glb (one drawn mesh "Bowl" in one vertex-colour material, plus the
collider mesh, authored "<id>-col-col" so Godot's importer leaves it named "<id>-col" with its trimesh body under it
(see COL_NODE); it is the same surface sampled coarser, with the same blocks), <id>_detail1.glb
(rim boulders, strata ledge ribbons) and <id>_detail2.glb (cobbles, sage tufts, varnish chips, floor cracks), each one
draw of the `detail` class. Detail shells are additive visuals with no collider: inside the stamp footprint nothing
stands more than RIDE_PROUD over the surface, and the lanes along the fall line (LANE_DEG either side of +Z) stay clear
of every block, boulder and cobble.

The vertex colours are the Arizona palette: cream limestone, sandstone, iron-oxide red, desert varnish, sage and juniper. No textures. No
people are named; the crater is natural and older than any society.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/crater.py -- [--out-dir DIR] [--count-only]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "dig_mechanical"))
import common
import kit

MODELS = kit.SKETCH / "assets/models/park"
MATERIAL = "enamel"
COL_NODE = "%s-col-col"

LIP_R = 0.7647097548633961
CREST_R = 0.85
RIM_FROM, RIM_TO = 0.7, 1.0
BLANKET_R = 1.5
BLANKET_AMP = 0.07
LANE_DEG = 20.0
RIDE_PROUD = 0.05
FOOT = 1.03

BUDGET_BASE = [16000, 48000, 2]
BUDGET_DETAIL = [1500, 3000, 1]

SPEC = {
    "crater_event": {"f": 28.0, "h": 8.0, "segs": 96, "col_segs": 48, "blocks": 14, "block": 1.7,
                     "boulders": 24, "boulder": 0.8, "cobbles": 90, "cobble": 0.28, "tufts": 44, "seed": 1},
    "crater_ending": {"f": 235.0, "h": 60.0, "segs": 128, "col_segs": 64, "blocks": 28, "block": 9.5,
                      "boulders": 30, "boulder": 4.5, "cobbles": 90, "cobble": 0.7, "tufts": 44, "seed": 2},
}
SIZE_TOL = 0.04

CREAM = (0.88, 0.80, 0.63)
SANDSTONE = common.srgb("sandstone")
SLICK = (0.66, 0.33, 0.23)
OXIDE = common.srgb("oxide")
PLAYA = (0.84, 0.74, 0.58)
VARNISH = (0.22, 0.17, 0.14)
SAGE = (0.50, 0.56, 0.42)
JUNIPER = (0.29, 0.37, 0.28)


def h32(a, b=0, c=0):
    """A deterministic hash to [0, 1): integer only, so a rebuild is byte-identical on any machine."""
    x = (a * 73856093 ^ b * 19349663 ^ c * 83492791) & 0xFFFFFFFF
    x ^= x >> 13
    x = (x * 0x5BD1E995) & 0xFFFFFFFF
    x ^= x >> 15
    return x / 4294967296.0


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def stamp(rho, h):
    """park_stamps.gd 'crater' at normalised radius rho (1.0 is the footprint edge)."""
    cut = 0.0
    if rho < 0.8:
        cut = -h * (1.0 - (rho / 0.8) ** 2)
    return cut + 0.2 * h * max(0.0, 1.0 - abs(rho - CREST_R) / 0.15)


def solve_lip(h=1.0):
    lo, hi = 0.7, CREST_R
    for _ in range(60):
        mid = (lo + hi) / 2
        if stamp(mid, h) < 0.0:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def ejecta_amp(phi, h):
    """The apron's thickness by bearing: uneven rays, never below a third of the peak."""
    a = 0.7 + 0.3 * math.sin(3 * phi + 0.6) + 0.2 * math.sin(7 * phi + 2.1)
    return BLANKET_AMP * h * max(a, 0.33)


def surface(spec, rho, phi):
    """Height of the ground at stamp radius rho and bearing phi (radians from +Z, toward +X)."""
    h = spec["h"]
    if rho <= 1.0:
        return stamp(rho, h)
    t = (rho - 1.0) / (BLANKET_R - 1.0)
    if t >= 1.0:
        return 0.0
    return ejecta_amp(phi, h) * (1.0 - t) ** 2 * smooth(t / 0.3)


def centre_z(spec):
    return LIP_R * spec["f"]


def world(spec, rho, phi):
    f = spec["f"]
    return (rho * f * math.sin(phi), surface(spec, rho, phi), centre_z(spec) + rho * f * math.cos(phi))


def ground_at(spec, x, z):
    f = spec["f"]
    dx, dz = x, z - centre_z(spec)
    rho = math.hypot(dx, dz) / f
    return surface(spec, rho, math.atan2(dx, dz)), rho


def in_lane(phi):
    a = abs(math.atan2(math.sin(phi), math.cos(phi)))
    return min(a, math.pi - a) < math.radians(LANE_DEG)


def streak(phi, depth, n=11, width=0.07):
    """Desert varnish runs down the wall: each streak wanders a little with depth and thins toward the floor."""
    best = 0.0
    for k in range(n):
        a = math.tau * h32(7, k) + 0.05 * math.sin(11.0 * depth + 6.0 * h32(9, k))
        d = abs(math.atan2(math.sin(phi - a), math.cos(phi - a)))
        w = width * (1.0 - 0.45 * depth)
        best = max(best, max(0.0, 1.0 - d / w) * (0.4 + 0.6 * h32(8, k)) * (1.0 - 0.5 * depth))
    return best


def terrain_color(spec, rho, phi, y, i, j):
    h = spec["h"]
    n = h32(i, j, spec["seed"])
    if rho > 1.0:
        t = (rho - 1.0) / (BLANKET_R - 1.0)
        ray = 0.5 + 0.5 * math.sin(11 * phi + 1.3) * math.sin(5 * phi + 0.4)
        col = mixc(CREAM, SANDSTONE, 0.25 + 0.5 * ray)
        col = mixc(col, SANDSTONE, smooth(t * 1.4))
        col = mixc(col, SAGE, 0.22 * t * n)
        return mixc(col, VARNISH, 0.08 * n)
    d = -y / h
    if d < 0.0:
        col = CREAM
    elif d < 0.25:
        col = mixc(CREAM, SANDSTONE, d / 0.25)
    elif d < 0.5:
        col = mixc(SANDSTONE, SLICK, (d - 0.25) / 0.25)
    elif d < 0.8:
        col = mixc(SLICK, OXIDE, (d - 0.5) / 0.3)
    else:
        col = mixc(OXIDE, PLAYA, smooth((d - 0.8) / 0.2))
    wall = smooth((d - 0.05) / 0.2) * (1.0 - smooth((d - 0.8) / 0.15))
    col = mixc(col, VARNISH, 0.34 * streak(phi, min(max(d, 0.0), 1.0)) * wall)
    return mixc(col, VARNISH, 0.07 * n)


class Mesh:
    """Vertices in Godot space, triangles, a colour per vertex and a smooth flag per triangle."""

    def __init__(self):
        self.verts, self.tris, self.colors, self.smooth = [], [], [], []

    def add(self, verts, tris, colors, smooth_shade, face="up"):
        """face: 'up' winds every triangle so its normal points up (ground sheets), 'out' away from the part's centre
        (closed blocks), None keeps the winding given (double-sided blades)."""
        off = len(self.verts)
        self.verts.extend(verts)
        self.colors.extend(colors)
        mid = tuple(sum(v[k] for v in verts) / len(verts) for k in range(3))
        for t in tris:
            a, b, c = (verts[i] for i in t)
            n = cross(sub(b, a), sub(c, a))
            if face == "up":
                flip = n[1] < 0
            elif face == "out":
                flip = dot(n, sub(tuple((a[k] + b[k] + c[k]) / 3 for k in range(3)), mid)) < 0
            else:
                flip = False
            u, v, w = (t[0], t[2], t[1]) if flip else t
            self.tris.append((u + off, v + off, w + off))
            self.smooth.append(smooth_shade)


def ring_list(col):
    """Stamp radii of the polar grid: the bowl, the rim ring in steps of 0.025 (0.85 is a ring), the blanket."""
    if col:
        rings = [0.2, 0.4, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.1, 1.2, 1.3, 1.4, BLANKET_R]
    else:
        rings = [round(0.1 * k, 4) for k in range(1, 7)] + [round(0.7 + 0.025 * k, 4) for k in range(0, 13)]
        rings += [round(1.05 + 0.05 * k, 4) for k in range(0, 10)]
    return rings


def terrain(spec, col):
    segs = spec["col_segs"] if col else spec["segs"]
    rings = ring_list(col)
    m = Mesh()
    f = spec["f"]
    verts, colors = [], []
    verts.append(world(spec, 0.0, 0.0))
    colors.append(terrain_color(spec, 0.0, 0.0, -spec["h"], 0, 0))
    for r, rho in enumerate(rings):
        for k in range(segs):
            phi = math.tau * k / segs
            v = world(spec, rho, phi)
            verts.append(v)
            colors.append(terrain_color(spec, rho, phi, v[1], r + 1, k))
    tris = []
    for k in range(segs):
        tris.append((0, 1 + (k + 1) % segs, 1 + k))
    for r in range(len(rings) - 1):
        a = 1 + r * segs
        b = 1 + (r + 1) * segs
        for k in range(segs):
            k2 = (k + 1) % segs
            tris.append((a + k, a + k2, b + k))
            tris.append((a + k2, b + k2, b + k))
    m.add(verts, tris, colors, True)
    return m


def block(spec, i, kind, size, rho_lo, rho_hi, base_sink):
    """An ejecta block: a cuboid of jittered corners, sunk into the blanket, flat shaded. Returns (verts, tris, colours)."""
    seed = spec["seed"] * 1000 + kind
    for k in range(40):
        phi = math.tau * h32(seed, i, k)
        if not in_lane(phi):
            break
    s = size * lerp(0.55, 1.2, h32(seed + 2, i))
    sx, sz = s * lerp(0.8, 1.4, h32(seed + 3, i)), s * lerp(0.8, 1.4, h32(seed + 4, i))
    rho = lerp(rho_lo, rho_hi, h32(seed + 1, i)) + 0.75 * max(sx, sz) / spec["f"]
    cx, gy, cz = world(spec, rho, phi)
    sy = s * lerp(0.5, 1.0, h32(seed + 5, i))
    yaw = math.tau * h32(seed + 6, i)
    cy, sn = math.cos(yaw), math.sin(yaw)
    verts = []
    corners = [(-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)]
    for c, (ax, ay, az) in enumerate(corners):
        jx = lerp(-0.3, 0.3, h32(seed + 7, i, c))
        jz = lerp(-0.3, 0.3, h32(seed + 8, i, c))
        jy = lerp(-0.12, 0.12, h32(seed + 9, i, c)) * (1 if ay else 0)
        top_in = 0.62 if ay else 1.0
        lx, lz = (ax + jx) * sx * 0.5 * top_in, (az + jz) * sz * 0.5 * top_in
        verts.append((cx + lx * cy - lz * sn, gy - base_sink * s + ay * (sy + base_sink * s + jy * s), cz + lx * sn + lz * cy))
    faces = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7)]
    tone = [CREAM, SANDSTONE, mixc(CREAM, SANDSTONE, 0.5), mixc(SANDSTONE, SLICK, 0.35), CREAM, mixc(SANDSTONE, VARNISH, 0.25), mixc(CREAM, SANDSTONE, 0.3), SLICK][int(h32(seed + 10, i) * 8) % 8]
    cols = []
    for c, v in enumerate(verts):
        top = v[1] > gy + 0.2 * s
        cols.append(mixc(tone, VARNISH, 0.35 if not top else 0.08 + 0.1 * h32(seed + 11, i, c)))
    return verts, faces, cols


def base_mesh(spec, col):
    m = terrain(spec, col)
    for i in range(spec["blocks"]):
        v, t, c = block(spec, i, 1, spec["block"], 1.10, 1.36, 0.45)
        m.add(v, t, c, False, "out")
    return m


def shell1(spec):
    """Rim boulders on the blanket and strata ledge ribbons flush on the wall."""
    m = Mesh()
    for i in range(spec["boulders"]):
        v, t, c = block(spec, i, 2, spec["boulder"], 1.05, 1.46, 0.3)
        m.add(v, t, c, False, "out")
    f = spec["f"]
    width_rho = 0.008
    for b, d in enumerate((0.30, 0.42, 0.58, 0.80)):
        rho = 0.8 * math.sqrt(1.0 - d)
        segs = 64
        for k in range(segs):
            if h32(spec["seed"] + 20, b, k) < 0.5:
                continue
            p0, p1 = math.tau * k / segs, math.tau * (k + 1) / segs
            quad = []
            for rr in (rho, rho + width_rho * (1.0 + 0.6 * h32(spec["seed"] + 21, b, k))):
                for ph in (p0, p1):
                    x, y, z = world(spec, rr, ph)
                    quad.append((x, y + 0.03, z))
            tone = mixc(mixc(VARNISH, OXIDE, 0.3 + 0.4 * h32(spec["seed"] + 22, b, k)), SLICK, 0.55)
            m.add(quad, [(0, 2, 1), (1, 2, 3)], [tone] * 4, False)
    return m


def tuft(spec, i, size):
    """Sage tuft: six thin blades leaning out of one point, double sided. Returns (verts, tris, colours) or None."""
    seed = spec["seed"] * 1000 + 30
    for k in range(40):
        phi = math.tau * h32(seed, i, k)
        if not in_lane(phi):
            break
    rho = lerp(1.06, 1.44, h32(seed + 1, i))
    cx, gy, cz = world(spec, rho, phi)
    verts, tris, cols = [], [], []
    for b in range(6):
        a = math.tau * (b + 0.4 * h32(seed + 2, i, b)) / 6
        lean = size * lerp(0.35, 0.7, h32(seed + 3, i, b))
        tall = size * lerp(0.8, 1.3, h32(seed + 4, i, b))
        w = size * 0.07
        ox, oz = math.cos(a), math.sin(a)
        verts += [(cx - oz * w, gy - 0.02, cz + ox * w), (cx + oz * w, gy - 0.02, cz - ox * w),
                  (cx + ox * lean, gy + tall, cz + oz * lean)]
        tris.append((3 * b, 3 * b + 1, 3 * b + 2))
        tone = mixc(SAGE, JUNIPER, h32(seed + 5, i, b))
        cols += [mixc(tone, VARNISH, 0.25), mixc(tone, VARNISH, 0.25), tone]
    return verts, tris, cols


def shell2(spec):
    """Cobbles and sage tufts on the blanket, varnish chips on the wall, hairline cracks on the floor."""
    m = Mesh()
    for i in range(spec["cobbles"]):
        seed = spec["seed"] * 1000 + 40
        for k in range(40):
            phi = math.tau * h32(seed, i, k)
            if not in_lane(phi):
                break
        rho = lerp(1.06, 1.46, h32(seed + 1, i))
        cx, gy, cz = world(spec, rho, phi)
        s = spec["cobble"] * lerp(0.5, 1.4, h32(seed + 2, i))
        yaw = math.tau * h32(seed + 3, i)
        base = [(math.cos(yaw + a) * s * lerp(0.8, 1.2, h32(seed + 4, i, k)), math.sin(yaw + a) * s * lerp(0.8, 1.2, h32(seed + 5, i, k)))
                for k, a in enumerate((0, math.pi / 2, math.pi, 3 * math.pi / 2))]
        verts = [(cx + dx, gy - 0.05, cz + dz) for dx, dz in base] + [(cx + 0.1 * s, gy + s * lerp(0.4, 0.7, h32(seed + 6, i)), cz - 0.1 * s)]
        tone = [CREAM, SANDSTONE, mixc(SANDSTONE, SLICK, 0.4), SANDSTONE, CREAM][int(h32(seed + 7, i) * 5) % 5]
        m.add(verts, [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], [mixc(tone, VARNISH, 0.3)] * 4 + [tone], False, "out")
    for i in range(spec["tufts"]):
        v, t, c = tuft(spec, i, 0.9 * (spec["cobble"] / 0.28) ** 0.5)
        m.add(v, t, c, False, None)
    for i in range(60):
        seed = spec["seed"] * 1000 + 50
        phi = math.tau * h32(seed, i)
        d = lerp(0.25, 0.85, h32(seed + 1, i))
        rho = 0.8 * math.sqrt(1.0 - d)
        cx, _, cz = world(spec, rho, phi)
        w = spec["cobble"] * lerp(0.5, 1.2, h32(seed + 2, i))
        quad = []
        for dx, dz in ((-w, -w * 0.6), (w, -w * 0.6), (-w, w * 0.6), (w, w * 0.6)):
            x, z = cx + dx, cz + dz
            quad.append((x, ground_at(spec, x, z)[0] + 0.02, z))
        m.add(quad, [(0, 2, 1), (1, 2, 3)], [mixc(VARNISH, OXIDE, 0.25)] * 4, False)
    for i in range(14):
        seed = spec["seed"] * 1000 + 60
        phi = math.tau * h32(seed, i)
        a0 = lerp(0.12, 0.5, h32(seed + 1, i))
        a1 = a0 + lerp(0.04, 0.09, h32(seed + 2, i))
        pts = []
        for rho in (a0, a1):
            for w in (-0.004, 0.004):
                x, _, z = world(spec, rho, phi + w / max(rho, 0.05))
                pts.append((x, ground_at(spec, x, z)[0] + 0.015, z))
        m.add(pts, [(0, 2, 1), (1, 2, 3)], [mixc(VARNISH, PLAYA, 0.4)] * 4, False)
    return m


def check_mesh(name, m, spec, base, col=False):
    """Fails loud: finite, upward-wound terrain, the surface where the stamp says it is, no part proud inside the footprint."""
    f = spec["f"]
    for v in m.verts:
        assert all(math.isfinite(c) for c in v), (name, v)
    proud_worst = -1e9
    for v in m.verts:
        y, rho = ground_at(spec, v[0], v[2])
        if rho <= FOOT:
            proud_worst = max(proud_worst, v[1] - y)
    if not base:
        assert proud_worst <= RIDE_PROUD + 1e-6, (name, "part proud inside the footprint", proud_worst)
    return proud_worst


def check_terrain_matches(spec, m):
    """The base mesh's grid vertices sit on the surface function exactly (they are built from it)."""
    worst = 0.0
    for v in m.verts[: 1 + len(ring_list(False)) * spec["segs"]]:
        y, _ = ground_at(spec, v[0], v[2])
        worst = max(worst, abs(v[1] - y))
    assert worst < 1e-6, ("terrain vertex off the surface", worst)
    return worst


def material():
    mat = bpy.data.materials.new(MATERIAL)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.93
    bsdf.inputs["Metallic"].default_value = 0.0
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    mat.use_backface_culling = False
    return mat


def make_object(name, m, root, with_material):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([kit.xyz(v) for v in m.verts], [], m.tris)
    mesh.update()
    for poly, sm in zip(mesh.polygons, m.smooth):
        poly.use_smooth = sm
    if with_material:
        attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        for poly in mesh.polygons:
            for li in poly.loop_indices:
                attr.data[li].color = common.rgba(m.colors[mesh.loops[li].vertex_index])
        mesh.color_attributes.active_color = attr
        mesh.materials.append(material())
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj


def build(id, spec, out_dir, count_only):
    f, h = spec["f"], spec["h"]
    base = base_mesh(spec, False)
    colm = base_mesh(spec, True)
    s1, s2 = shell1(spec), shell2(spec)
    check_terrain_matches(spec, base)
    check_mesh(id, base, spec, True)
    check_mesh(id + "-col", colm, spec, True)
    p1 = check_mesh(id + "_detail1", s1, spec, False)
    p2 = check_mesh(id + "_detail2", s2, spec, False)
    counts = {
        id: len(base.tris), id + "-col": len(colm.tris), id + "_detail1": len(s1.tris), id + "_detail2": len(s2.tris)}
    assert counts[id] + counts[id + "-col"] <= BUDGET_BASE[0], (id, counts)
    assert counts[id + "_detail1"] <= BUDGET_DETAIL[0] and counts[id + "_detail2"] <= BUDGET_DETAIL[0], (id, counts)
    print("CRATER_COUNT", id, json.dumps(counts, sort_keys=True), "proud", round(p1, 4), round(p2, 4))
    if count_only:
        return {}
    rows = {}
    for gname, parts in ((id, [("Bowl", base, True), (COL_NODE % id, colm, False)]), (id + "_detail1", [("Detail1", s1, True)]),
                         (id + "_detail2", [("Detail2", s2, True)])):
        common.reset()
        root = common.empty(gname)
        for oname, m, mat in parts:
            make_object(oname, m, root, mat)
        path = Path(out_dir) / (gname + ".glb")
        common.export(root, str(path))
        metrics = kit.gltf_metrics(path)
        budget = BUDGET_BASE if gname == id else BUDGET_DETAIL
        assert metrics["triangles"] <= budget[0] and metrics["vertices"] <= budget[1] and metrics["draws"] <= budget[2], (gname, metrics, budget)
        if gname == id:
            assert metrics["materials"] == [MATERIAL], (gname, metrics["materials"])
            assert COL_NODE % id in metrics["nodes"] and "Bowl" in metrics["nodes"], (gname, metrics["nodes"])
            size = metrics["bounds"]["size"]
            want = [2 * BLANKET_R * f, None, 2 * BLANKET_R * f]
            for got, w in ((size[0], want[0]), (size[2], want[2])):
                assert abs(got - w) <= SIZE_TOL * w, (gname, size, want)
            assert metrics["bounds"]["min"][1] <= -h * 0.99 and metrics["bounds"]["max"][1] >= 0.2 * h * 0.9, (gname, metrics["bounds"])
        else:
            assert metrics["materials"] == [MATERIAL], (gname, metrics["materials"])
        rows[gname] = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        print("CRATER_EXPORT", gname, json.dumps({k: v for k, v in rows[gname].items() if k != "nodes"}, sort_keys=True))
    return rows


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    assert abs(LIP_R - solve_lip()) < 1e-9, ("LIP_R drifted from the stamp", solve_lip())
    Path(args.out_dir).mkdir(parents=True, exist_ok=True)
    for id, spec in SPEC.items():
        if args.only and id != args.only:
            continue
        build(id, spec, args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
