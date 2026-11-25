import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
import bpy
import common
import shell_base as sb
import shell_kest_plates as kp
from common import Part, Vector

SHELL_BAND = (3000, 6500)
VERT_CAP = 11600
REACH = 1.70
POD_REACH = 1.25
LOW_Z = -0.55
PLATING = 1.0
BANK_SUPPORT = 0.965
VANE_GAP = 0.02
POD_X = 1.24
POD_Z = 0.03
HOUSING = (0.17, 0.53, 0.15, 0.15, 0.06)
PLATES = ((0.145, 0.195), (0.505, 0.555))
PLATE = (0.168, 0.168, 0.068)
BELL = ((0.46, 0.0), (0.46, 0.115), (0.60, 0.115), (0.60, 0.095), (0.71, 0.122), (0.785, 0.19),
        (0.81, 0.215), (0.81, 0.184), (0.73, 0.116), (0.66, 0.082), (0.66, 0.0))
BELL_SIDES = 12
BELL_STEEL = 6
THROAT_FUSE = (0.668, 0.07, 0.012)
MOUTH_Y = 0.82
CANISTER = (0.02, 0.34, -0.215, 0.07, 0.22, 0.48)
STRAPS = (0.27, 0.43)
FUSE_CAP = (0.06, 0.245)
TRUNNION = (0.33, -0.17, 0.045)
MORTAR_PIVOT = (0.0, TRUNNION[0], TRUNNION[1])
KICK_M = 0.09
POSES = (("rest", 0.0, 0.0), ("kick", 0.0, KICK_M), ("ready", -20.0, 0.0), ("ready kick", -20.0, KICK_M),
         ("riding", -45.0, KICK_M))
SATCHELS = ((90.0, 1), (180.0, 2), (270.0, 3), (kp.SATCHEL4_CLOCK, 4))
DRAWS = 15
BANK = (("FusePlunger", "plunger"), ("ChargeKey", "key"))
OLIVE = common.mix("petrol", "brass", 0.4)
STEEL = "9aa0a0"
STRIPE = common.mix("amber", "brass", 0.5)


def flag(name):
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if name not in argv:
        return None
    i = argv.index(name)
    return argv[i + 1] if i + 1 < len(argv) else True


def octagon(part, x, z, y0, y1, half_x, half_z, chamfer, color):
    """A box along +Y with its four long edges chamfered: one closed island, 28 triangles."""
    corners = [(half_x, half_z - chamfer), (half_x - chamfer, half_z), (-half_x + chamfer, half_z),
               (-half_x, half_z - chamfer), (-half_x, -half_z + chamfer), (-half_x + chamfer, -half_z),
               (half_x - chamfer, -half_z), (half_x, -half_z + chamfer)]
    back = [part.bm.verts.new((x + cx, y0, z + cz)) for cx, cz in corners]
    front = [part.bm.verts.new((x + cx, y1, z + cz)) for cx, cz in corners]
    faces = [part.bm.faces.new(back), part.bm.faces.new(list(reversed(front)))]
    faces += [part.bm.faces.new((back[(i + 1) % 8], back[i], front[i], front[(i + 1) % 8])) for i in range(8)]
    return part.paint(faces, "paint", color)


def lathe(part, origin, profile, sides, paints):
    """A closed surface of revolution about +Y through origin: profile (y, r) from one pole to the
    other. paints[i] is (slot, colour) for the band from point i to i + 1."""
    o = Vector(origin)
    rings = []
    for y, r in profile:
        if r == 0.0:
            rings.append([part.bm.verts.new((o.x, y, o.z))])
            continue
        rings.append([part.bm.verts.new((o.x + r * math.cos(k * math.tau / sides), y,
                                         o.z + r * math.sin(k * math.tau / sides))) for k in range(sides)])
    faces = []
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        band = []
        for k in range(sides):
            j = (k + 1) % sides
            if len(a) == 1:
                band.append(part.bm.faces.new((a[0], b[j], b[k])))
            elif len(b) == 1:
                band.append(part.bm.faces.new((a[k], a[j], b[0])))
            else:
                band.append(part.bm.faces.new((a[k], a[j], b[j], b[k])))
        slot, color = paints[i]
        part.paint(band, slot, color)
        faces += band
    return faces


def plug(part, corners, normal, depth, color, slot="paint"):
    """A closed flat mark: the polygon on a face, closed to a point depth behind it."""
    n = Vector(normal).normalized()
    pts = [Vector(c) for c in corners]
    if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) < 0:
        pts.reverse()
    rim = [part.bm.verts.new(p) for p in pts]
    tip = part.bm.verts.new(sum(pts, Vector()) / len(pts) - n * depth)
    k = len(rim)
    faces = [part.bm.faces.new(rim)] + [part.bm.faces.new((rim[(i + 1) % k], rim[i], tip)) for i in range(k)]
    return part.paint(faces, slot, color)


def cylinder_y(part, x, z, y0, y1, r, sides, color, cap_color=None):
    """A closed cylinder along +Y, its end caps in cap_color."""
    ring0 = [part.bm.verts.new((x + r * math.cos(k * math.tau / sides), y0, z + r * math.sin(k * math.tau / sides)))
             for k in range(sides)]
    ring1 = [part.bm.verts.new((x + r * math.cos(k * math.tau / sides), y1, z + r * math.sin(k * math.tau / sides)))
             for k in range(sides)]
    sides_f = [part.bm.faces.new((ring0[k], ring0[(k + 1) % sides], ring1[(k + 1) % sides], ring1[k]))
               for k in range(sides)]
    caps = [part.bm.faces.new(list(reversed(ring0))), part.bm.faces.new(ring1)]
    part.paint(sides_f, "paint", color)
    part.paint(caps, "paint", cap_color or color)
    return sides_f + caps


def cylinder_z(part, slot, x, y, z0, z1, r, sides, color=None):
    """A closed upright cylinder."""
    lo = [part.bm.verts.new((x + r * math.cos(k * math.tau / sides), y + r * math.sin(k * math.tau / sides), z0))
          for k in range(sides)]
    hi = [part.bm.verts.new((x + r * math.cos(k * math.tau / sides), y + r * math.sin(k * math.tau / sides), z1))
          for k in range(sides)]
    faces = [part.bm.faces.new(list(reversed(lo))), part.bm.faces.new(hi)]
    faces += [part.bm.faces.new((lo[k], lo[(k + 1) % sides], hi[(k + 1) % sides], hi[k])) for k in range(sides)]
    return part.paint(faces, slot, color)


def stripes(part, centre, u, v, normal, size, count, depth=0.004):
    """A hazard panel on a flat face: a charcoal plate standing proud by 6 mm with count diagonal
    stripes on it. centre on the face, u along the panel, v across, size (along, across)."""
    c, u, v, n = Vector(centre), Vector(u).normalized(), Vector(v).normalized(), Vector(normal).normalized()
    a, b = size[0] / 2, size[1] / 2
    lift = n * 0.006
    plate = [c - u * a - v * b, c + u * a - v * b, c + u * a + v * b, c - u * a + v * b]
    inner = [p - n * 0.01 for p in plate]
    lo = [part.bm.verts.new(p) for p in inner]
    hi = [part.bm.verts.new(p + lift + n * 0.01) for p in inner]
    faces = [part.bm.faces.new(lo), part.bm.faces.new(hi)]
    faces += [part.bm.faces.new((lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i])) for i in range(4)]
    bmesh.ops.recalc_face_normals(part.bm, faces=faces)
    part.paint(faces, "paint", "charcoal")
    top = c + lift + n * 0.0015
    w = size[0] / (2 * count + 1)
    slant = b * 0.9
    for k in range(count):
        s0 = -a + w * (2 * k + 1) - slant * 0.5
        quad = [top + u * (s0 - slant * 0.5) - v * b * 0.9, top + u * (s0 + w - slant * 0.5) - v * b * 0.9,
                top + u * (s0 + w + slant * 0.5) + v * b * 0.9, top + u * (s0 + slant * 0.5) + v * b * 0.9]
        plug(part, quad, n, depth, STRIPE)
    return faces


def pod(m, side):
    """One mortar pod, built in ring space on the side x = side * POD_X."""
    x = side * POD_X
    y0, y1, hw, hh, ch = HOUSING
    octagon(m, x, POD_Z, y0, y1, hw, hh, ch, OLIVE)
    for p0, p1 in PLATES:
        octagon(m, x, POD_Z, p0, p1, PLATE[0], PLATE[1], PLATE[2], "petrol")
    paints = [("paint", STEEL)] * BELL_STEEL + [("paint", "charcoal")] * (len(BELL) - 1 - BELL_STEEL)
    lathe(m, (x, 0, POD_Z), BELL, BELL_SIDES, paints)
    fy, fr, fd = THROAT_FUSE
    disc = [(x + fr * math.cos(k * math.tau / BELL_SIDES), fy, POD_Z + fr * math.sin(k * math.tau / BELL_SIDES))
            for k in range(BELL_SIDES)]
    plug(m, disc, (0, 1, 0), fd, None, "class_accent")
    stripes(m, (x + side * hw, 0.40, POD_Z), (0, 1, 0), (0, 0, 1), (side, 0, 0), (0.20, hh * 2 - ch * 2), 3)
    stripes(m, (x, PLATES[0][0], POD_Z), (side, 0, 0), (0, 0, 1), (0, -1, 0), (0.22, 0.16), 3)
    shift, cy, cz, cr, c0, c1 = CANISTER
    cx = x - side * shift
    cylinder_y(m, cx, cz, c0, c1, cr, 10, "brass", "charcoal")
    z0, z1 = cz - cr - 0.012, POD_Z - hh + 0.02
    for sy in STRAPS:
        m.box("paint", (2 * cr + 0.03, 0.026, z1 - z0), loc=(cx, sy, (z0 + z1) / 2), color="oxide")
    fx = x + side * FUSE_CAP[0]
    cylinder_z(m, "paint", fx, FUSE_CAP[1], POD_Z + hh - 0.01, POD_Z + hh + 0.035, 0.038, 8, "charcoal")
    cylinder_z(m, "class_accent", fx, FUSE_CAP[1], POD_Z + hh + 0.035, POD_Z + hh + 0.075, 0.03, 8)
    ty, tz, tr = TRUNNION
    inner = x - side * hw
    lug_top = POD_Z - hh + 0.03
    m.box("paint", (0.07, 0.12, lug_top - tz + tr), loc=(inner + side * 0.025, ty, (lug_top + tz - tr) / 2), color="petrol")
    m.rod("paint", Vector((inner + side * 0.05, ty, tz)), Vector((inner - side * 0.05, ty, tz)), tr, 8, color="charcoal")


def mortar_part():
    """Both pods, one mesh that pitches and recoils on the trunnion line; built in ring space,
    made into an object with its origin at MORTAR_PIVOT."""
    m = Part("Mortar")
    for side in (-1, 1):
        pod(m, side)
    sb._sharpen(m)
    return m


def ring_kit():
    """Kest's weapon ring parts in ring space (the ring sits at the Pod origin): the trunnion yokes
    clamped on the band under the pods, and the four satchels."""
    r = Part("RingKit")
    mid = (sb.RING_BAND[0] + sb.RING_BAND[1]) / 2
    ty, tz, _ = TRUNNION
    for side in (-1, 1):
        band_x = math.sqrt(mid * mid - ty * ty)
        pin = POD_X - HOUSING[2] - 0.05
        r.box("paint", (0.06, 0.15, 0.13), loc=(side * band_x, ty, 0.0), color="charcoal")
        r.beam("rubber", (side * band_x, ty, -0.03), (side * (pin + 0.01), ty, tz), 0.07, 0.10)
    for clock, _ in SATCHELS:
        kp.satchel(r, clock)
    return r


def band_attributes(ring):
    """UV2 on the ring mesh (glTF TEXCOORD_1, Godot UV2): x is the satchel band index (1 to 4)
    on the ochre band faces and 0 elsewhere; y is the heft class a face shows from (4 on the
    whole fourth satchel, 0 elsewhere). Blender's exporter writes V as 1 - v, so v is stored as
    1 - class and Godot reads the class. Returns {band index: face count} and the gated count."""
    mesh = ring.data
    col = mesh.color_attributes["Color"]
    ochre = common.rgba(kp.BAND_COLOR)
    uv = mesh.uv_layers.new(name="UVMap")
    band = mesh.uv_layers.new(name="Band")
    for loop in uv.data:
        loop.uv = (0.0, 0.0)
    seen, gated = {}, 0
    for poly in mesh.polygons:
        c = poly.center
        clock = math.degrees(math.atan2(c.x, c.y)) % 360.0
        near = min(SATCHELS, key=lambda s: abs((clock - s[0] + 180.0) % 360.0 - 180.0))
        off = abs((clock - near[0] + 180.0) % 360.0 - 180.0)
        first = col.data[poly.loop_indices[0]].color
        is_band = all(abs(first[k] - ochre[k]) < 1e-3 for k in range(3))
        index = near[1] if is_band and off < 10.0 else 0
        gate = 4 if near[1] == 4 and off < 10.0 and (is_band or math.hypot(c.x, c.y) > kp.SATCHEL_INNER) else 0
        if index:
            seen[index] = seen.get(index, 0) + 1
        gated += 1 if gate else 0
        for li in poly.loop_indices:
            band.data[li].uv = (float(index), 1.0 - float(gate))
    return seen, gated


def islands(bm):
    bm.faces.index_update()
    seen, out = set(), []
    for start in bm.faces:
        if start.index in seen:
            continue
        group, stack = [], [start]
        seen.add(start.index)
        while stack:
            f = stack.pop()
            group.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        out.append(group)
    return out


def strip_neutral_mount(ring):
    """Removes the neutral weapon seat (the mount block and rod at 12 o'clock) from the ring."""
    bm = bmesh.new()
    bm.from_mesh(ring.data)
    doomed = [f for g in islands(bm) for f in g
              if all(v.co.y > 1.07 and abs(v.co.x) < 0.08 for f2 in g for v in f2.verts)]
    verts = {v for f in doomed for v in f.verts}
    bmesh.ops.delete(bm, geom=list(verts), context="VERTS")
    bm.to_mesh(ring.data)
    bm.free()
    return len(verts)


def strip_pins(core):
    """Drops the lattice's copper pin heads (shell_base._stud: four faces round four corners) and
    keeps the chalk balance mark (paint). Returns the count dropped."""
    copper = [m.name for m in core.data.materials].index("copper")
    bm = bmesh.new()
    bm.from_mesh(core.data)
    pins = [g for g in islands(bm) if len(g) == 4 and all(f.material_index == copper for f in g)
            and len({v for f in g for v in f.verts}) == 4]
    verts = sorted({v.index for g in pins for f in g for v in f.verts})
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in verts], context="VERTS")
    bm.to_mesh(core.data)
    bm.free()
    return len(pins)


def merge_into(target, part):
    """Folds a Part into an existing mesh object (both at the shell origin), mapping slots onto
    the target's materials so no new surface appears for a slot it already has."""
    extra = part.to_object((0, 0, 0), None)
    mats = target.data.materials
    remap = {}
    for i, m in enumerate(extra.data.materials):
        names = [t.name for t in mats]
        if m.name not in names:
            mats.append(m)
            names.append(m.name)
        remap[i] = names.index(m.name)
    for poly in extra.data.polygons:
        poly.material_index = remap[poly.material_index]
    bm = bmesh.new()
    bm.from_mesh(target.data)
    bm.from_mesh(extra.data)
    bm.to_mesh(target.data)
    bm.free()
    mesh = extra.data
    bpy.data.objects.remove(extra)
    bpy.data.meshes.remove(mesh)


def brackets():
    """Gap brackets: a slim arm from each outer gimbal boss to its vent hinge."""
    p = Part("Brackets")
    for side in (-1, 1):
        h = kp.vane_hinge(side)
        p.beam("rubber", (side * 0.89, 0.0, 0.0), h, 0.04)
    return p


def pilot():
    """Static head placeholder, the C09 Kest head at lower resolution moved onto the Hoberman seat
    (head centre at shell_base.HEAD), smooth so it shares vertices; hidden in play under the
    animated pilot, kept because hero_assets_test reads a Pod > Dome > Pilot mesh."""
    f = Part("Pilot")
    crest = common.mix("oxide", "amber", 0.2)
    beak = common.mix("amber", "sandstone", 0.35)
    f.uv("pilot", 0.21, 16, 10, loc=(0, 0.2, 1.09), scale=(1.02, 0.88, 1.0), color="bone")
    for side in (-1, 1):
        f.uv("pilot", 0.08, 8, 6, loc=(side * 0.115, 0.302, 1.085), scale=(0.85, 0.40, 1.15), color="charcoal")
        f.ring("pilot", 0.044, 0.063, 0.03, 10, loc=(side * 0.088, 0.35, 1.155), rot=(math.pi / 2, 0, 0), color="copper")
        sb.eye(f, (side * 0.088, 0.374, 1.155), 0.040)
    f.uv("pilot", 0.08, 10, 6, loc=(0, 0.357, 1.035), scale=(0.8, 1.2, 0.6), color=beak)
    f.rod("pilot", (0, 0.39, 1.043), (0, 0.475, 0.99), 0.045, 8, color=beak, r2=0.006)
    for k in range(3):
        f.uv("pilot", 0.07, 8, 6, loc=(0, 0.16 - k * 0.05, 1.3 + k * 0.015), scale=(0.42, 0.65, 1.75),
             rot=(0.35 + k * 0.2, 0, 0), color=crest)
    shift = sb.HEAD - Vector((0, 0.2, 1.09))
    bmesh.ops.translate(f.bm, vec=shift, verts=f.bm.verts)
    for face in f.bm.faces:
        face.smooth = True
    return f


def stable_pilot_normals(path):
    """Two exports differed by 0.00009 in a static pilot smooth normal (C09).
    Round components to 0.001 and normalize; geometry stays intact."""
    with open(path, "rb") as f:
        data = bytearray(f.read())
    json_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_len])
    bin_start = 28 + json_len
    for mesh in gltf["meshes"]:
        if mesh["name"] != "Pilot":
            continue
        for primitive in mesh["primitives"]:
            accessor = gltf["accessors"][primitive["attributes"]["NORMAL"]]
            view = gltf["bufferViews"][accessor["bufferView"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            start = bin_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            for i in range(accessor["count"]):
                offset = start + i * stride
                normal = struct.unpack_from("<3f", data, offset)
                rounded = tuple(round(x, 3) or 0.0 for x in normal)
                length = math.sqrt(math.fsum(x * x for x in rounded))
                struct.pack_into("<3f", data, offset, *(x / length for x in rounded))
    with open(path, "wb") as f:
        f.write(data)
    common.canonical_indices(path)
    print("STABLE_NORMALS Kest static Pilot, component precision 0.001")


def world_verts(obj):
    mw = obj.matrix_world
    return [mw @ v.co for v in obj.data.vertices]


def edge_points(obj, step=0.03):
    """World points along every edge of a mesh (its vertices included), so a chord between two
    far vertices is held too."""
    mw = obj.matrix_world
    pts = []
    for e in obj.data.edges:
        a, b = mw @ obj.data.vertices[e.vertices[0]].co, mw @ obj.data.vertices[e.vertices[1]].co
        n = max(1, int((b - a).length / step))
        pts += [a.lerp(b, i / n) for i in range(n + 1)]
    return pts


def hull2(points):
    """Convex hull of 2D points (monotone chain), counter-clockwise."""
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def outside_by(hull, p):
    """Signed distance of a 2D point outside a counter-clockwise convex hull (negative inside)."""
    worst = -math.inf
    for i in range(len(hull)):
        a, b = hull[i], hull[(i + 1) % len(hull)]
        ex, ey = b[0] - a[0], b[1] - a[1]
        length = math.hypot(ex, ey)
        if length < 1e-12:
            continue
        worst = max(worst, ((p[0] - a[0]) * ey - (p[1] - a[1]) * ex) / length)
    return worst


def vane_region(vanes, angle):
    """The (rho, z) hull of both vents' blades at a hinge angle (radians, 0 folded): a pod point
    inside it meets a vent at some ring yaw, since the ring turns freely against the Pod."""
    for hinge, side in vanes:
        hinge.rotation_euler = (0.0, side * angle, 0.0)
    bpy.context.view_layer.update()
    pts = [(math.hypot(p.x, p.y), p.z) for hinge, _ in vanes for c in hinge.children for p in world_verts(c)]
    for hinge, _ in vanes:
        hinge.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    return hull2(pts)


def mortar_report(ring, mortar, vanes):
    """Reach, ground clearance, plating clearance and vane clearance of the pods in each pose, and
    the carrier bank support of every ring part at rest. Returns True when every check holds."""
    ok = True
    regions = {"folded": vane_region(vanes, 0.0), "cracked": vane_region(vanes, math.pi / 6),
               "open": vane_region(vanes, math.pi / 2)}
    meets = {"rest": ("folded", "open"), "kick": ("folded", "cracked", "open"), "ready": ("cracked", "open"),
             "ready kick": ("cracked", "open"), "riding": ("open",)}
    rest_loc = mortar.location.copy()
    for name, deg, back in POSES:
        mortar.rotation_euler = (math.radians(deg), 0.0, 0.0)
        mortar.location = rest_loc - Vector((0, back, 0))
        bpy.context.view_layer.update()
        pts = world_verts(mortar)
        reach = max(p.length for p in pts)
        low = min(p.z for p in pts)
        near = min(p.length for p in pts)
        samples = [(math.hypot(p.x, p.y), p.z) for p in edge_points(mortar)]
        gaps = {state: min(outside_by(regions[state], s) for s in samples) for state in meets[name]}
        good = reach <= REACH and low >= LOW_Z and near >= PLATING and all(g >= VANE_GAP for g in gaps.values())
        ok = ok and good
        print("MORTAR %s pitch %+.0f recoil %.2f: reach %.3f (limit %.2f), lowest Z %.3f (limit %.2f), nearest %.3f "
              "(plating %.2f), vent gap %s %s" % (name, deg, back, reach, REACH, low, LOW_Z, near, PLATING,
                                                  ", ".join("%s %.3f" % kv for kv in gaps.items()), "ok" if good else "OUT"))
    mortar.rotation_euler = (0.0, 0.0, 0.0)
    mortar.location = rest_loc
    bpy.context.view_layer.update()
    support = max(0.5 * math.hypot(p.x, p.y) - 0.866 * p.z for o in (ring, mortar) for p in world_verts(o))
    bank_ok = support <= BANK_SUPPORT
    print("BANK_SUPPORT ring and pods 0.5 rho - 0.866 z at most %.3f (limit %.3f) %s"
          % (support, BANK_SUPPORT, "ok" if bank_ok else "OUT"))
    return ok and bank_ok


def vane_report(pod, vanes):
    """Folded and open reach of each vent past the lattice, the open sight cone, and the
    clearance above the weapon band. Returns True when every check holds."""
    ok = True
    blades = {hinge.name: hinge.children[0] for hinge, _ in vanes}
    bpy.context.view_layer.update()
    folded = {n: max(p.length for p in world_verts(b)) for n, b in blades.items()}
    for hinge, side in vanes:
        hinge.rotation_euler = (0.0, side * math.pi / 2, 0.0)
    bpy.context.view_layer.update()
    opened = {n: max(p.length for p in world_verts(b)) for n, b in blades.items()}
    band_top = sb.RING_BAND[2] / 2 + sb.RING_BAND[3]
    low = min(p.z for b in blades.values() for p in world_verts(b) if p.length > sb.RING_BAND[0] - 0.05)
    cone_open = sb.sight_cone_hits(pod)
    for hinge, _ in vanes:
        hinge.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    for name in folded:
        f_past, o_past = folded[name] - sb.LATTICE_OUTER, opened[name] - sb.LATTICE_OUTER
        good = abs(f_past - 0.10) <= 0.03 and abs(o_past - 0.25) <= 0.03 and opened[name] <= POD_REACH
        ok = ok and good
        print("VANE %s folded %.3f m past the lattice, open %.3f m past (radius %.3f) %s"
              % (name, f_past, o_past, opened[name], "ok" if good else "OUT"))
    tip = max(world_verts(blades["VaneR"]), key=lambda p: p.length)
    clock = math.degrees(math.atan2(tip.x, tip.z))
    print("VANE_CLOCK folded tip at %.0f degrees from the top (2 o'clock is 60) %s"
          % (clock, "ok" if 45 <= clock <= 75 else "OUT"))
    print("VANE_OPEN sight cone %d Pod vertices, lowest open vane point past r %.2f at Z %.3f (band top %.2f) %s"
          % (cone_open, sb.RING_BAND[0] - 0.05, low, band_top, "ok" if cone_open == 0 and low > band_top + 0.05 else "OUT"))
    return ok and 45 <= clock <= 75 and cone_open == 0 and low > band_top + 0.05


def draws(root):
    return sum(len({p.material_index for p in o.data.polygons}) for o in common.tree(root) if o.type == "MESH")


def closed_report(root):
    """Open and non-manifold edges per mesh after welding by position, as check_manifold.py does."""
    ok = True
    for o in common.tree(root):
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
        many = sum(1 for e in bm.edges if len(e.link_faces) > 2)
        bm.free()
        ok = ok and boundary == 0 and many == 0
        if boundary or many:
            print("OPEN %s boundary=%d nonmanifold=%d" % (o.name, boundary, many))
    print("CLOSED every mesh %s" % ("ok" if ok else "OUT"))
    return ok


def main():
    common.reset()
    common.preview_class("amber")
    roost = flag("--variant") == "roost"
    name = "KestRoost" if roost else "Kest"
    shell = sb.hoberman(name, enamel="petrol", seat="petrol", pairs=1 if roost else 2, bank=BANK,
                        pilot=pilot(), hub_sides=8 if roost else 6, cap_sides=8)
    pod_obj, ring = shell["pod"], shell["ring"]
    print("STRIP neutral weapon seat %d vertices" % strip_neutral_mount(ring))
    print("STRIP lattice pins %d (the cutaway plating covers the lattice)" % strip_pins(shell["core"]))
    merge_into(ring, ring_kit())
    bands, gated = band_attributes(ring)
    print("BANDS Kest ring band faces by index %s, %d faces gated to class IV" % (sorted(bands.items()), gated))
    merge_into(pod_obj, brackets())
    mortar = mortar_part().to_object(MORTAR_PIVOT, ring)
    for side, tag in ((-1, "L"), (1, "R")):
        common.empty("MortarMouth." + tag, (side * POD_X, MOUTH_Y, POD_Z), mortar)
    vanes = []
    for vname, side in (("VaneL", -1), ("VaneR", 1)):
        hinge = common.empty(vname, kp.vane_hinge(side), pod_obj)
        blade = kp.vane_part(vname + ".Blade", side)
        blade.to_object(kp.vane_hinge(side), hinge)
        vanes.append((hinge, side))
    bpy.context.view_layer.update()
    root = shell["root"]
    reach = max(p.length for o in common.tree(pod_obj) if o.type == "MESH" and o.name != "Pilot"
                and o.name != "WeaponRing" and o.name != "Mortar" for p in world_verts(o))
    n_draws = draws(root)
    print("REACH Kest Pod subtree outside the ring %.3f m, limit %.2f %s" % (reach, POD_REACH, "ok" if reach <= POD_REACH else "OUT"))
    print("DRAWS %s %d surfaces (Core 3, Pod 3, Gyro 1, GyroInner 1, WeaponRing 2, Mortar 2, VaneL.Blade 1, "
          "VaneR.Blade 1, Pilot 1)" % (name, n_draws))
    vane_ok = vane_report(pod_obj, vanes)
    mortar_ok = mortar_report(ring, mortar, vanes)
    closed = closed_report(root)
    verts = sum(len(o.data.vertices) for o in common.tree(root) if o.type == "MESH")
    print("MORTAR tris %d" % common.tris(mortar))
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one",
                                               "shell_kest_roost.glb" if roost else "shell_kest.glb")
    band = (3000, 11000) if roost else SHELL_BAND
    sb.finish(name, root, shell["core"], shell["pilot"], shell_band=band, pod_obj=pod_obj, out=out)
    stable_pilot_normals(out)
    exported = glb_vertices(out)
    print("VERTS %s %d exported (Blender %d), cap %d %s" % (name, exported, verts, VERT_CAP, "ok" if exported <= VERT_CAP else "OUT"))
    bands_ok = sorted(bands) == [1, 2, 3, 4] and gated > 0
    if reach > POD_REACH or not vane_ok or not mortar_ok or n_draws != DRAWS or not bands_ok or not closed \
            or exported > VERT_CAP:
        raise SystemExit("Kest machinery checks failed")


def glb_vertices(path):
    """Vertices as Godot loads them: the POSITION count of every primitive."""
    with open(path, "rb") as f:
        data = f.read()
    json_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_len])
    return sum(gltf["accessors"][p["attributes"]["POSITION"]]["count"] for m in gltf["meshes"] for p in m["primitives"])


main()
