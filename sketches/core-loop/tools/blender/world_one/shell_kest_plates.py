import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import bmesh
import bpy
import common
import shell_base as sb
from common import Part, Vector
from mathutils.bvhtree import BVHTree

VANE_BETA = math.radians(70.0)
VANE_ALPHA = math.radians(10.0)
VANE_RH = 0.90
VANE_Y = -0.05
VANE_DEPTH = 0.03
SLAT_SPAN = 0.06
SLAT_GAP = 0.015
SLAT_SWEEP = 0.06
SLAT_W = (-0.06, 0.11)
SLAT_ROOT = 0.03
SLAT_COLORS = ("oxide", "oxide", "bone")
VANE_CLEAR = 0.15
SLIT_DEPTH = 0.008


def vane_hinge(side):
    return Vector((side * VANE_RH * math.sin(VANE_BETA), VANE_Y, VANE_RH * math.cos(VANE_BETA)))


def vane_frame(side):
    """(span, across) unit vectors of the folded slats, Blender axes."""
    span = Vector((side * math.sin(VANE_ALPHA), 0.0, math.cos(VANE_ALPHA)))
    across = Vector((-side * math.cos(VANE_ALPHA), 0.0, math.sin(VANE_ALPHA)))
    return span, across


def vane_part(name, side):
    """One vent, built in place around its hinge; the caller makes the object with the hinge as
    its origin, so the node turns about the hinge."""
    p = Part(name)
    h = vane_hinge(side)
    span, across = vane_frame(side)
    y = Vector((0, 1, 0))
    for k, color in enumerate(SLAT_COLORS):
        s0 = SLAT_ROOT + k * (SLAT_SPAN + SLAT_GAP)
        outline = [(s0, SLAT_W[0]), (s0 + SLAT_SPAN, SLAT_W[0]),
                   (s0 + SLAT_SPAN + SLAT_SWEEP, SLAT_W[1]), (s0 + SLAT_SWEEP, SLAT_W[1])]
        corners = [h + span * s + across * w for s, w in outline]
        lo = [p.bm.verts.new(c - y * VANE_DEPTH / 2) for c in corners]
        hi = [p.bm.verts.new(c + y * VANE_DEPTH / 2) for c in corners]
        faces = [p.bm.faces.new(list(reversed(lo))), p.bm.faces.new(hi)]
        faces += [p.bm.faces.new((lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i])) for i in range(4)]
        bmesh.ops.recalc_face_normals(p.bm, faces=faces)
        p.paint(faces, "paint", color)
        def at(w, ds):
            s = s0 + SLAT_SPAN / 2 + SLAT_SWEEP * (w - SLAT_W[0]) / (SLAT_W[1] - SLAT_W[0]) + ds
            return h + span * s + across * w
        wa, wb = SLAT_W[0] + 0.03, SLAT_W[1] - 0.03
        for face_y in (-1, 1):
            off = y * face_y * (VANE_DEPTH / 2 + 0.002)
            quad = [at(wa, -0.012) + off, at(wa, 0.012) + off, at(wb, 0.012) + off, at(wb, -0.012) + off]
            if (quad[1] - quad[0]).cross(quad[3] - quad[0]).dot(y * face_y) < 0:
                quad.reverse()
            rim = [p.bm.verts.new(v) for v in quad]
            tip = p.bm.verts.new(sum(quad, Vector()) / 4 - y * face_y * SLIT_DEPTH)
            slit = [p.bm.faces.new(rim)] + [p.bm.faces.new((rim[(k + 1) % 4], rim[k], tip)) for k in range(4)]
            p.paint(slit, "paint", "charcoal")
    p.rod("paint", h - y * 0.07, h + y * 0.07, 0.028, 6, color="charcoal")
    return p


PANEL_OUT = 0.92
PANEL_IN = 0.88
PANEL_SHRINK = 0.80
HOLE = 0.022
CAP_RIM = (sb.CAP_WIDTH / 2, sb.CAP_WIDTH / 2 + 0.018, 0.955, 0.9805)
FRONT_EYES = tuple(Vector((e.x, -e.y, e.z)) for e in sb.CHASE_EYES)
LOW_Z = -0.35
SIDE_Z = (-0.6, 0.45)
SPLIT_Z = 0.35
SATCHEL4_CLOCK = 225.0
SATCHEL_INNER = 1.082
BAND_COLOR = common.mix("amber", "oxide", 0.3)


PILOT_GLB = os.path.join(common.MODELS, "pilot_kest_anim.glb")
_PILOT = []


def pilot_tree():
    """BVH of the pilot body, built once (imports the rig into the current scene)."""
    if _PILOT:
        return _PILOT[0]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=PILOT_GLB)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in new:
        if o.type != "MESH" or o.parent is None or o.parent.type != "ARMATURE":
            continue
        ev = o.evaluated_get(dg)
        m = ev.to_mesh()
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in m.vertices]
        polys += [[base + i for i in p.vertices] for p in m.polygons]
        ev.to_mesh_clear()
    for o in new:
        bpy.data.objects.remove(o)
    _PILOT.append(BVHTree.FromPolygons(verts, polys))
    return _PILOT[0]


def hides_pilot(points, eyes=sb.CHASE_EYES + FRONT_EYES):
    """True when a ray from an eye through any point goes on to hit the pilot body."""
    tree = pilot_tree()
    for e in eyes:
        for p in points:
            d = p - e
            dist = d.length
            hit = tree.ray_cast(e, d / dist)
            if hit[0] is not None and hit[3] > dist:
                return True
    return False


def samples(corners, n=4):
    """Barycentric grid over a triangle, corners and edges included."""
    a, b, c = corners
    return [a * (i / n) + b * (j / n) + c * ((n - i - j) / n) for i in range(n + 1) for j in range(n + 1 - i)]


def _cone_hit(p, eyes):
    cos_half = math.cos(math.radians(sb.SIGHT_HALF_ANGLE))
    d = p - sb.HEAD
    if d.length < 1e-6:
        return False
    d.normalize()
    return any(d.dot((e - sb.HEAD).normalized()) > cos_half for e in eyes)


def gap_corners():
    """Per gap: (centre, [five_a, five_b], [three_c, three_d]) unit directions."""
    hubs, _, gaps = sb.lattice_layout()
    five, three = hubs[:12], hubs[12:]
    out = []
    for g in gaps:
        f = sorted(five, key=lambda h: -h.dot(g))[:2]
        t = sorted(three, key=lambda h: -h.dot(g))[:2]
        out.append((g, f, t))
    return out


def _triangle(corners):
    """Outer-face points of one shrunk triangle at PANEL_OUT."""
    c = sum(corners, Vector()) / 3
    return [(c + (v - c) * PANEL_SHRINK).normalized() for v in corners]


def panels_for_gap(g):
    _, (a, b), (c, d) = g
    return [_triangle([a, c, d]), _triangle([b, d, c])]


def panel_points(tri):
    return [v * PANEL_OUT for v in tri] + [v * PANEL_IN for v in tri]


def classify():
    """({class: [triangle]}, excluded count). Each gap's two triangles are judged on their own:
    one with a vertex in a sight cone or within VANE_CLEAR of a hinge stays open."""
    hinges = [vane_hinge(s) for s in (-1, 1)]
    by_class = {2: [], 3: [], 4: [], 5: []}
    excluded = 0
    gaps = gap_corners()
    low_gaps = [g for g in gaps if g[0].z < 0 and max(p.z for t in panels_for_gap(g) for p in panel_points(t)) < LOW_Z]
    low_gaps = sorted(low_gaps, key=lambda g: g[0].z)[:6]
    for g in gaps:
        c = g[0]
        if any(g is lg for lg in low_gaps):
            n = 2
        elif SIDE_Z[0] <= c.z <= SIDE_Z[1] and abs(c.x) >= abs(c.y):
            n = 3
        elif c.z < SPLIT_Z:
            n = 4
        else:
            n = 5
        for tri in panels_for_gap(g):
            pts = panel_points(tri)
            if any(_cone_hit(p, sb.CHASE_EYES) or _cone_hit(p, FRONT_EYES) for p in pts) \
                    or any((p - h).length < VANE_CLEAR for p in pts for h in hinges) \
                    or hides_pilot(samples([v * PANEL_OUT for v in tri], 10) + pts[3:]):
                excluded += 1
            else:
                by_class[n].append(tri)
    return by_class, excluded


def _panel(p, tri):
    outer = [p.bm.verts.new(v * PANEL_OUT) for v in tri]
    inner = [p.bm.verts.new(v * PANEL_IN) for v in tri]
    n = sum(tri, Vector()).normalized()
    if (outer[1].co - outer[0].co).cross(outer[2].co - outer[0].co).dot(n) < 0:
        outer.reverse()
        inner.reverse()
    faces = [p.bm.faces.new(outer), p.bm.faces.new(list(reversed(inner)))]
    faces += [p.bm.faces.new((inner[i], inner[(i + 1) % 3], outer[(i + 1) % 3], outer[i])) for i in range(3)]
    p.paint(faces, "paint", "bone")
    c = sum((v.co for v in outer), Vector()) / 3
    for v in outer:
        at = c + (v.co - c) * 0.45
        nn = at.normalized()
        e1 = (v.co - c).normalized()
        e2 = nn.cross(e1)
        lift = nn * 0.002
        quad = [at + lift + (e1 * sx + e2 * sy) * HOLE for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        p.paint([p.bm.faces.new([p.bm.verts.new(q) for q in quad])], "paint", "charcoal")


def satchel(p, clock_deg, radius=1.14, z=-0.025):
    """One canvas satchel strapped flat to the ring row: oxide body, petrol flap, a horizontal
    ochre band (the band the volley count lights; shell_kest.band_attributes indexes it)."""
    a = math.radians(clock_deg)
    out = Vector((math.sin(a), math.cos(a), 0))
    yaw = -a
    loc = out * radius + Vector((0, 0, z))
    body = p.box("paint", (0.22, 0.11, 0.13), loc=loc, rot=(0, 0, yaw), color="oxide")
    flap = p.box("paint", (0.226, 0.03, 0.05), loc=loc + out * 0.05 + Vector((0, 0, 0.045)), rot=(0, 0, yaw), color="petrol")
    p.box("paint", (0.228, 0.118, 0.03), loc=loc + Vector((0, 0, -0.025)), rot=(0, 0, yaw), color=BAND_COLOR)
    return body + flap


def layer(n, by_class):
    root = common.empty("ShellKestC%d" % n)
    pod = Part("Pod")
    for tri in by_class[n]:
        _panel(pod, tri)
    sb._sharpen(pod)
    if n == 3:
        core = Part("Core")
        hubs, _, _ = sb.lattice_layout()
        skipped = []
        r_in, r_out, lo, hi = CAP_RIM
        for d in hubs:
            e1, e2 = sb._frame(d)
            ring = [math.cos(k * math.tau / 8) * e1 + math.sin(k * math.tau / 8) * e2 for k in range(8)]
            if hides_pilot([d * z + r_out * q for q in ring for z in (lo, hi)]):
                skipped.append(d)
                continue
            top_in = [core.bm.verts.new(d * hi + r_in * q) for q in ring]
            top_out = [core.bm.verts.new(d * hi + r_out * q) for q in ring]
            low_out = [core.bm.verts.new(d * lo + r_out * q) for q in ring]
            faces = []
            for k in range(8):
                j = (k + 1) % 8
                top = core.bm.faces.new((top_in[k], top_out[k], top_out[j], top_in[j]))
                wall = core.bm.faces.new((top_out[k], low_out[k], low_out[j], top_out[j]))
                top.normal_update()
                wall.normal_update()
                if top.normal.dot(d) < 0:
                    top.normal_flip()
                mid = (top_out[k].co + low_out[j].co) / 2
                if wall.normal.dot(mid - d * mid.dot(d)) < 0:
                    wall.normal_flip()
                faces += [top, wall]
            core.paint(faces, "rubber")
        print("RIMS Kest c3 %d of %d hubs get a rim; %d stay bare in front of the pilot (C6)"
              % (len(hubs) - len(skipped), len(hubs), len(skipped)))
        sb._sharpen(core)
        core_obj = core.to_object((0, 0, 0), root)
    else:
        core_obj = common.empty("Core", (0, 0, 0), root)
    pod_obj = pod.to_object((0, 0, 0), root)
    return root, core_obj, pod_obj


def main():
    common.reset()
    outdir = None
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--outdir" in argv:
        outdir = argv[argv.index("--outdir") + 1]
    outdir = outdir or os.path.join(common.MODELS, "world_one")
    by_class, excluded = classify()
    print("PLATES Kest %d of 60 gap triangles stay open (sight cones, vent hinges or in front of the pilot)" % excluded)
    ok = True
    for n in (2, 3, 4, 5):
        common.reset()
        root, core_obj, pod_obj = layer(n, by_class)
        tris = common.tri_total(root)
        far = max(((pod_obj.matrix_world @ v.co).length for v in pod_obj.data.vertices), default=0.0)
        panel_far = max((v.co.length for v in pod_obj.data.vertices if v.co.length < 1.0), default=0.0)
        low = sb.low_reach(pod_obj)
        cone = sb.sight_cone_hits(pod_obj)
        core_far = common.max_radius(core_obj) if core_obj.type == "MESH" else 0.0
        slots = sum(len({p.material_index for p in o.data.polygons}) for o in common.tree(root) if o.type == "MESH")
        good = tris <= 1500 and low == 0 and cone == 0 and panel_far <= PANEL_OUT + 0.0021 and core_far <= sb.CORE_LIMIT + 1e-4
        ok = ok and good
        print("LAYER Kest c%d panels=%d tris=%d draws=%d panel_r=%.4f pod_far=%.3f core_r=%.4f low=%d cone=%d %s"
              % (n, len(by_class[n]), tris, slots, panel_far, far, core_far, low, cone, "ok" if good else "OUT"))
        common.export(root, os.path.join(outdir, "shell_kest_c%d.glb" % n))
    if not ok:
        raise SystemExit("Kest layer checks failed")


if __name__ == "__main__":
    main()
