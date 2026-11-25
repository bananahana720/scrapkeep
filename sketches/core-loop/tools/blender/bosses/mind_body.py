"""Mind body, rigid animation and CPU judge previews, from D4 BUILD-SPEC.

blender -b --factory-startup --threads 2 --python-exit-code 1 --python \
  sketches/core-loop/tools/blender/bosses/mind_body.py -- \
  --out-dir sketches/core-loop/assets/models/bosses \
  --preview artifacts/local/dress-preview/MND

Omit --preview for a deterministic export-only rebuild. No external assets needed.
Author coordinates are Godot metres, +Y up/-Z forward; B() converts once to Blender.
Both exports mount at arena ground identity. CombatSeat is at actor centre y=1.6;
KitMount is its identity alias. Lens seats are actor-local y=7.6, radius 1.6.
Other sockets use the table's ground-root coordinates. No colliders or root motion.

Wiring: seek warning clips by Hazard.age/warn_seconds, with a descriptor-driven
parent supplying committed yaw. split_lane_warn demonstrates +0.525 rad; runtime
overrides EmitterSocketR with the exact seeded signed offset, 0.35..0.7 radians.
Plate uses a lower 90-degree fan, never a ground damage mesh or verb-protection cue.
Play family_strike on Hazard.live and recovery after each family's live duration.
These two generic clips carry visual offsets on the common FamilyRecoil control.
Pulse clips ONLY touch PulseLip in glTF. Godot adds immutable rest tracks for absent
channels: filter each concurrent playback layer to its named controls, or use
AnimationTree track filters. The asset test exercises simultaneous pulse and rush.
phase_break, phase_break_2, phase_break_3 each shed one different mantle. Keep the
completed panel hidden in wiring; do not play all three every phase. The three
choir_change variants demonstrate the real seat transitions; code selects the seat
and owns the collision target. attention is only a small optical rotation.
stagger_open uncovers mint OpenLens behind opaque slate shutters. Runtime alone
decides when it opens. No mint crown/enamel, reward amber or attached hand geometry
(the GlovePlate below is a detached prop resting by the seat, not a hand on the crown).

The empty place (2026-10-18, design thread): the crew called the Mind the Mind because
it did the thinking and they were its hands. CrewBench is four empty seats on a low
plank behind the seat, facing the lens, outside every telegraph. GlovePlate is a work
glove laid flat by the bench; it rests hidden (scale 0.001) and only glove_down shows it
coming down onto the pad by the empty seat, while the mantles settle as in final_quiet.
glove_down is the base's defeat clip, played by mind_dress.gd from PR #113, which
falls back to final_quiet when it is missing; final_quiet stays. All clips are sampled
every frame with eased (auto-clamped Bezier) keys. family_strike ends holding
FamilyRecoil at z=-0.18, where recovery and hand_send (which replaces recovery when a
hand is sent) both start, easing back to 0, so neither pair pops.

One base allocation includes the crown, six slabs, supports, spine and seat. The kit
allocation includes the optics and all working tools. These REPLACE the old clamp
and kit; they are not additions to it. Material names follow the shared contract.
Preview staging (36 m pad, 2 m ball, lights/camera) is excluded from both exports.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import cycles_device
import polish

SKETCH = HERE.parents[2]
PALETTE = {"bone": "d2c5a5", "petrol": "365754", "charcoal": "242a28",
           "blue": "3d8bff", "hazard": "ff5a3c", "slate": "617481", "mint": "8bf0d3"}
CLIPS = {
    "attention": (4.0, 2.0), "phase_break": (1.0, 0.8),
    "phase_break_2": (1.0, 0.8), "phase_break_3": (1.0, 0.8),
    "lane_warn": (1.4, 1.4), "split_lane_warn": (1.6, 1.6),
    "rush_warn": (1.5, 1.5), "plate_warn": (1.8, 1.8),
    "family_strike": (0.2, 0.1), "recovery": (0.4, 0.2),
    "pulse_warn": (2.0, 2.0), "pulse": (0.3, 0.1),
    "choir_change": (0.6, 0.6), "choir_change_1_2": (0.6, 0.6),
    "choir_change_2_0": (0.6, 0.6), "stagger_open": (0.5, 0.5),
    "hand_send": (0.6, 0.3), "final_quiet": (2.0, 2.0),
    "glove_down": (2.4, 2.4),
}
GLOVE_AT = (4.3, 0.06, 3.0)
GLOVE_FROM = (0.0, 14.0, 1.0)
GLOVE_YAW = -125


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def B(v):
    return Vector((v[0], -v[2], v[1]))


def colour(name):
    return common.rgba(PALETTE.get(name, name))


def atlas():
    """Broad cast wear, embedded once per export, with no random or mesh chips."""
    image = bpy.data.images.new("MindCastWear", width=512, height=512, alpha=False)
    pixels = []
    for y in range(512):
        for x in range(512):
            broad = math.sin(x * .011 + math.sin(y * .017) * 2.3) * math.sin(y * .023 + x * .009)
            fleck = ((x * 73856093 ^ y * 19349663) & 1023) / 1023
            chip = broad > .82
            value = .57 + .02*fleck if chip else .88 + .045 * fleck + .05 * broad
            pixels.extend((value, value, value, 1.0))
    image.pixels.foreach_set(pixels)
    image.pack()
    return image


def materials():
    wear = atlas()
    for name, rough in (("ancient_enamel", .72), ("dark_joint", .86),
                        ("signal_surface", .48), ("glass", .13)):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = .12 if name != "glass" else 0.0
        vc = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Color"
        mat.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
        if name == "ancient_enamel":
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = wear
            multiply = mat.node_tree.nodes.new("ShaderNodeMixRGB")
            multiply.blend_type = "MULTIPLY"
            multiply.inputs[0].default_value = 1.0
            mat.node_tree.links.new(vc.outputs["Color"], multiply.inputs[1])
            mat.node_tree.links.new(tex.outputs["Color"], multiply.inputs[2])
            mat.node_tree.links.new(multiply.outputs[0], bsdf.inputs["Base Color"])
        elif name == "glass":
            bsdf.inputs["Alpha"].default_value = .16
            mat.surface_render_method = "BLENDED"
            bsdf.inputs["Coat Weight"].default_value = 1.0
            bsdf.inputs["Coat Roughness"].default_value = .07
        elif name == "signal_surface":
            mat.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = .32


def empty(name, at, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = B(at)
    obj.rotation_mode = "XYZ"
    return obj


class Mesh:
    def __init__(self, name):
        self.name = name
        self.verts, self.faces, self.paint = [], [], []

    def face(self, points, material="ancient_enamel", tint="bone"):
        start = len(self.verts)
        self.verts.extend(points)
        for i in range(1, len(points) - 1):
            self.faces.append((start, start + i, start + i + 1))
            self.paint.append((material, tint))

    def sweep(self, points, widths, depths, tint="bone", joint=True):
        rows = []
        for i, (p, width, depth) in enumerate(zip(points, widths, depths)):
            tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(0, i - 1)])
            across = Vector((tangent.y, -tangent.x, 0)).normalized()
            back = Vector((0, 0, 1))
            bevel = min(width, depth) * .19
            section = [(-width/2 + bevel, -depth/2), (width/2 - bevel, -depth/2),
                       (width/2, -depth/2 + bevel), (width/2, depth/2 - bevel),
                       (width/2 - bevel, depth/2), (-width/2 + bevel, depth/2),
                       (-width/2, depth/2 - bevel), (-width/2, -depth/2 + bevel)]
            rows.append([tuple(Vector(p) + across*x + back*z) for x, z in section])
        self.face(list(reversed(rows[0])), "dark_joint" if joint else "ancient_enamel", "charcoal" if joint else "petrol")
        self.face(rows[-1], "ancient_enamel", tint)
        for j in range(len(rows) - 1):
            for k in range(8):
                nxt = (k + 1) % 8
                slot = "dark_joint" if joint and k in (2, 6) else "ancient_enamel"
                shade = "charcoal" if slot == "dark_joint" else ("petrol" if k == 4 else tint)
                self.face([rows[j][k], rows[j+1][k], rows[j+1][nxt], rows[j][nxt]], slot, shade)

    def ring(self, radius, inner, height, y, segments=24, slots=("ancient_enamel", "dark_joint"), stripe=False):
        for i in range(segments):
            a, b = math.tau*i/segments, math.tau*(i+1)/segments
            def p(r, yy, angle):
                return (r*math.cos(angle), yy, r*math.sin(angle))
            lo, hi = y-height/2, y+height/2
            tint = "hazard" if i % 4 in (0, 1) else "charcoal"
            skew = .055 if stripe else 0
            self.face([p(radius,lo,a),p(radius,hi,a+skew),p(radius,hi,b+skew),p(radius,lo,b)],
                      "signal_surface" if stripe else slots[0], tint if stripe else "bone")
            self.face([p(inner,lo,b),p(inner,hi,b),p(inner,hi,a),p(inner,lo,a)], slots[1], "petrol")
            self.face([p(inner,hi,a),p(inner,hi,b),p(radius,hi,b+skew),p(radius,hi,a+skew)], slots[0], "bone")
            self.face([p(inner,lo,b),p(inner,lo,a),p(radius,lo,a),p(radius,lo,b)], slots[0], "petrol")

    def box(self, center, size, slot="ancient_enamel", tint="bone"):
        x,y,z = center
        w,h,d = [v/2 for v in size]
        v = [(x+sx*w,y+sy*h,z+sz*d) for sx,sy,sz in
             [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        for indices in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]:
            self.face([v[i] for i in indices], slot, tint)

    def object(self, at, parent):
        mesh = bpy.data.meshes.new(self.name)
        origin = Vector(at)
        mesh.from_pydata([tuple(B(Vector(v)-origin)) for v in self.verts], [], self.faces)
        slots = list(dict.fromkeys(slot for slot, tint in self.paint))
        for slot in slots:
            mesh.materials.append(bpy.data.materials[slot])
        colors = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        uv = mesh.uv_layers.new(name="UVMap")
        for poly, (slot, tint) in zip(mesh.polygons, self.paint):
            poly.material_index = slots.index(slot)
            for loop in poly.loop_indices:
                colors.data[loop].color = colour(tint)
                v = self.verts[mesh.loops[loop].vertex_index]
                uv.data[loop].uv = (v[0]*.051 + v[2]*.023, v[1]*.063 + v[2]*.021)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = B(at)
        obj.rotation_mode = "XYZ"
        return obj


def ribbon(name, points, widths, depths, parent, pivot=None, tint="bone"):
    m = Mesh(name)
    m.sweep(points, widths, depths, tint)
    return m.object(pivot or points[0], parent)


def base():
    root = empty("MindRoot", (0,0,0))
    frame = Mesh("CrownFrame")
    for side in (-1,1):
        frame.sweep([(side*.9,22,0),(side*5.2,21.4,0),(side*10.3,22.2,0),(side*14,24,0)],
                    [2.7,3.1,3.3,1.2], [3,3.7,3.4,2.3], "petrol")
        frame.sweep([(side*1.3,22.8,-1.5),(side*6,22.1,-1.65),(side*11,23.1,-1.5)],
                    [.38,.45,.32], [.22,.25,.2])
    frame.object((0,22,0), root)
    for side, suffix in ((-1,"L"),(1,"R")):
        ribbon("Support"+suffix, [(side*10,22,0),(side*9.1,18.9,.3),(side*6.5,15.2,.1),(side*3.7,11.5,0)],
               [2,2.2,2,0.7], [3,3,2.7,1.5], root, (side*10,22,0))
        empty("SupportSocket"+suffix, (side*10,22,0), root)
    panel_rows = [
        ([(-12,20,-1),(-13,22.6,-1),(-14.5,26,-1.1),(-16,28,-1.1)], [2.1,3.7,2.6,.06], [1.3,1.9,1.6,.65], (-12,22,-1)),
        ([(12,18.5,-2),(12.8,22,-2),(14,26.5,-2.5),(15.975,29.4,-3)], [1.4,3.8,2.4,.06], [1.2,1.9,1.7,.5], (12.8,22,-2)),
        ([(-6.2,20,2),(-7.6,24,2),(-8.1,27.2,1.8),(-7.3,30,1.8)], [1.2,4,2.4,.06], [1.1,1.8,1.5,.4], (-7.6,24,2)),
        ([(5.3,20.5,2),(6.2,23,2),(7.6,27,2),(8.5,29.5,2)], [1.1,3.8,2.3,.06], [1.1,1.8,1.4,.4], (6.2,23,2)),
        ([(-1.5,20,-3.8),(-2.4,24,-4.4),(-2,27.3,-5.2),(-1.8,30,-5.8)], [1.1,3.4,2.2,.06], [.8,1.7,1,.4], (-2.4,26,-4.4)),
        ([(1.2,21,3.4),(1.9,24,4.4),(2.6,27.2,5.3),(2.4,29.3,5.8)], [1.1,3.1,2.2,.06], [.8,1.4,1.1,.4], (1.9,25,4.4)),
    ]
    crown = bpy.data.objects["CrownFrame"]
    for i, (points,widths,depths,pivot) in enumerate(panel_rows):
        hinge = empty("MantleSocket%d"%i, tuple(Vector(pivot)-Vector((0,22,0))), crown)
        local = [tuple(Vector(p)-Vector(pivot)) for p in points]
        ribbon("Mantle%d"%i, local, widths, depths, hinge, (0,0,0))
    seam = Mesh("CrownSeams")
    for side in (-1,1):
        for a,b in [((side*1.2,22.2,-1.53),(side*5,21.65,-1.87)),
                    ((side*5,21.65,-1.87),(side*10.2,22.5,-1.74))]:
            aa,bb=Vector(a),Vector(b)
            perp=Vector((-(bb-aa).y,(bb-aa).x,0)).normalized()*.025
            seam.face([tuple(aa-perp),tuple(bb-perp),tuple(bb+perp),tuple(aa+perp)], "signal_surface", "blue")
    seam.object((0,0,0),root)
    spine = Mesh("AxisSpine")
    spine.sweep([(0,1.6,.5),(0,8,.5),(0,14,.5),(0,22,.5)], [1.6]*4, [1.13]*4, "petrol")
    for y in (5,10,15,20):
        spine.box((0,y,-.1),(1.5,.2,.25))
    spine.object((0,1.6,.5),root)
    empty("SeatTether", (0,1.6,0),root)
    seat = empty("CombatSeat", (0,1.6,0),root)
    empty("KitMount", (0,0,0),seat)
    body = Mesh("SeatBase")
    rings=[]
    for y,r in [(-1.6,2.45),(-1.15,2.8),(.55,2.1),(1.6,1.35)]:
        rings.append([(r*math.cos(i*math.tau/24),y,r*math.sin(i*math.tau/24)) for i in range(24)])
    body.face(list(reversed(rings[0])),"dark_joint","charcoal")
    body.face(rings[-1],"ancient_enamel","petrol")
    for j in range(3):
        for k in range(24):
            n=(k+1)%24
            dark=k%6==0
            body.face([rings[j][k],rings[j+1][k],rings[j+1][n],rings[j][n]],
                      "dark_joint" if dark else "ancient_enamel", "charcoal" if dark else ("petrol" if k%6==1 else "bone"))
    body.object((0,0,0),seat)
    crew_bench(root)
    glove_plate(root)
    return root


def crew_bench(root):
    """Four empty crew seats on a low curved plank behind the seat, each facing the lens."""
    bench = Mesh("CrewBench")
    radius = 4.4
    for i in range(4):
        a = math.radians(-33 + 22 * i)
        out = Vector((math.sin(a), 0, math.cos(a)))
        side = Vector((math.cos(a), 0, -math.sin(a)))
        c = out * radius

        def at(x, y, z):
            return tuple(c + side * x + Vector((0, y, 0)) + out * z)

        def block(x0, x1, y0, y1, z0, z1, slot, tint):
            v = [at(x, y, z) for x, y, z in [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
                                              (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]]
            for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]:
                bench.face([v[k] for k in f], slot, tint)
        block(-.48,.48,.5,.66,-.42,.42,"ancient_enamel","bone")
        block(-.46,.46,.66,1.5,.36,.5,"ancient_enamel","petrol")
        block(-.4,.4,1.18,1.3,.34,.52,"dark_joint","charcoal")
        for sx in (-.36,.36):
            for sz in (-.3,.3):
                block(sx-.06,sx+.06,.12,.5,sz-.06,sz+.06,"dark_joint","charcoal")
    for j in range(5):
        a0, a1 = math.radians(-44 + 17.6 * j), math.radians(-44 + 17.6 * (j + 1))
        p = [(r*math.sin(a), y, r*math.cos(a)) for a in (a0, a1) for r in (3.85, 4.95) for y in (0, .12)]
        lo0, hi0, lo1, hi1 = p[0], p[1], p[2], p[3]
        lo2, hi2, lo3, hi3 = p[4], p[5], p[6], p[7]
        mid = (a0 + a1) / 2
        radial = Vector((math.sin(mid), 0, math.cos(mid)))
        outward(bench, [hi0, hi2, hi3, hi1], Vector((0, 1, 0)), "ancient_enamel", "petrol")
        outward(bench, [lo0, lo1, lo3, lo2], Vector((0, -1, 0)), "dark_joint", "charcoal")
        outward(bench, [lo0, lo2, hi2, hi0], -radial, "dark_joint", "charcoal")
        outward(bench, [lo1, hi1, hi3, lo3], radial, "dark_joint", "charcoal")
    for a, inner, outer in ((-44, 3.85, 4.95), (44, 3.85, 4.95)):
        r = math.radians(a)
        q = [(rr*math.sin(r), y, rr*math.cos(r)) for rr in (inner, outer) for y in (0, .12)]
        tangent = Vector((math.cos(r), 0, -math.sin(r))) * (1 if a > 0 else -1)
        outward(bench, [q[0], q[2], q[3], q[1]], tangent, "dark_joint", "charcoal")
    bench.object((0,0,0), root)


def outward(mesh, points, out, slot, tint):
    """A planar face wound so its normal points along out (Godot frame; B() keeps handedness)."""
    a, b, c = (Vector(p) for p in points[:3])
    if (b - a).cross(c - a).dot(out) < 0:
        points = list(reversed(points))
    mesh.face(points, slot, tint)


def glove_plate(root):
    """A work glove laid flat, palm down: canvas back, leather cuff, five fingers."""
    glove = Mesh("GlovePlate")
    h = .14

    def slab(outline, y0, y1, tint, side="dark_joint"):
        area = sum(outline[k][0]*outline[(k+1)%len(outline)][1]-outline[(k+1)%len(outline)][0]*outline[k][1]
                   for k in range(len(outline)))
        if area > 0:
            outline = list(reversed(outline))
        top = [(x, y1, z) for x, z in outline]
        bottom = [(x, y0, z) for x, z in outline]
        glove.face(top, "ancient_enamel", tint)
        glove.face(list(reversed(bottom)), side, "charcoal")
        n = len(outline)
        for k in range(n):
            m = (k + 1) % n
            glove.face([bottom[k], bottom[m], top[m], top[k]], "ancient_enamel", tint)

    def digit(x, z0, length, width, a):
        d = (math.sin(a), math.cos(a))
        r = (d[1], -d[0])
        pts = []
        for s, w in ((0, width), (length*.9, width*.92)):
            pts.append((x + d[0]*s - r[0]*w/2, z0 + d[1]*s - r[1]*w/2))
        tip = (x + d[0]*length, z0 + d[1]*length)
        pts = [pts[0], pts[1], (tip[0] - r[0]*w*.3, tip[1] - r[1]*w*.3),
               (tip[0] + r[0]*w*.3, tip[1] + r[1]*w*.3),
               (x + d[0]*length*.9 + r[0]*w/2, z0 + d[1]*length*.9 + r[1]*w/2),
               (x + r[0]*width/2, z0 + r[1]*width/2)]
        return pts
    slab([(-.62,.55),(.62,.55),(.72,.2),(.7,-.45),(.55,-.62),(-.55,-.62),(-.7,-.45),(-.72,.2)], 0, h, "c9b48a")
    slab([(-.7,.95),(.7,.95),(.68,.55),(-.68,.55)], 0, h*1.25, "6b4a32")
    for x, length in ((-.45, .62), (-.15, .78), (.15, .82), (.44, .7)):
        slab(digit(x, -.58, length, .27, 0), 0, h*.9, "c9b48a")
    slab(digit(.68, .0, .62, .3, math.radians(-120)), 0, h*.9, "c9b48a")
    obj = glove.object((0,0,0), root)
    obj.location = B(GLOVE_AT)
    obj.rotation_euler.z = math.radians(GLOVE_YAW)
    obj.scale = Vector((1.6, 1.6, 1.6)) * .001


def optic(parent):
    seats=[]
    for i in range(3):
        a=i*math.tau/3
        seats.append(empty("LensSeat%d"%i, (1.6*math.cos(a),7.6,-1.6*math.sin(a)),parent))
    root=empty("LensRoot",(1.6,7.6,0),parent)
    empty("WeakPoint",(0,0,0),root)
    glass=Mesh("MainLens")
    rows=[]
    for r,z in [(.9,0),(.78,-.28),(.47,-.5),(.02,-.59)]:
        rows.append([(r*math.cos(i*math.tau/16),r*math.sin(i*math.tau/16),z) for i in range(16)])
    for j in range(3):
        for k in range(16):
            n=(k+1)%16
            glass.face([rows[j][k],rows[j+1][k],rows[j+1][n],rows[j][n]],"glass","ffffff")
    glass.face(rows[-1],"glass","ffffff")
    obj=glass.object((0,0,0),root)
    for poly in obj.data.polygons:
        poly.use_smooth=True
    live=Mesh("OpenLens")
    ring=[(.66*math.cos(i*math.tau/24),.66*math.sin(i*math.tau/24),-.64) for i in range(24)]
    live.face(list(reversed(ring)),"signal_surface","mint")
    live.object((0,0,0),root)
    for i in range(6):
        a=i*math.tau/6
        shutter=Mesh("Shutter%d"%i)
        pivot=(.9*math.cos(a),.9*math.sin(a),-.69)
        pts=[(.0,.0,-.695)]
        for k in range(5):
            b=a-math.pi/6+k*math.pi/12
            pts.append((1.04*math.cos(b),1.04*math.sin(b),-.695))
        shutter.face(list(reversed(pts)),"ancient_enamel","slate")
        for k in range(4):
            b=a-math.pi/6+k*math.pi/12
            c=b+math.pi/12
            shutter.face([(1.04*math.cos(b),1.04*math.sin(b),-.698),
                          (1.04*math.cos(c),1.04*math.sin(c),-.698),
                          (.88*math.cos(c),.88*math.sin(c),-.70),
                          (.88*math.cos(b),.88*math.sin(b),-.70)],"ancient_enamel","bone")
        hinge=empty("ShutterHinge%d"%i,pivot,root)
        hinge.rotation_euler.y=math.pi/2-a
        inv=hinge.rotation_euler.to_matrix().inverted()
        shutter.verts=[tuple(B(v)) for v in shutter.verts]
        shutter.verts=[tuple((inv@(Vector(v)-B(pivot)))) for v in shutter.verts]
        shutter.verts=[(v[0],v[2],-v[1]) for v in shutter.verts]
        shutter.object((0,0,0),hinge)
    return root


def kit():
    root=empty("MindKitRoot",(0,0,0))
    seat=empty("CombatSeat",(0,1.6,0),root)
    empty("KitMount",(0,0,0),seat)
    family=empty("FamilyRecoil",(0,0,0),seat)
    for side,suffix in ((-1,"L"),(1,"R")):
        socket=empty("EmitterSocket"+suffix,(side*2,1.4,-1),family)
        mesh=Mesh("Emitter"+suffix)
        mesh.sweep([(-1.2,0,-.025),(0,0,-.025),(1.2,0,-.025)],
                   [.72,.8,.72],[1.4,1.4,1.4],joint=False)
        mesh.object((0,.4,.675),socket)
        throat=Mesh("EmitterThroat"+suffix)
        throat.face([(-1.08,-.22,-.695),(1.08,-.22,-.695),(1.08,.22,-.695),(-1.08,.22,-.695)],"signal_surface","charcoal")
        for i in range(5):
            x=-1.0+i*.42
            throat.face([(x,-.21,-.698),(x+.21,-.21,-.698),(x+.4,.21,-.698),(x+.19,.21,-.698)],"signal_surface","hazard")
        throat.object((0,0,0),socket)
    collar=Mesh("RushCollar")
    collar.ring(3,2.2,.7,0,24,("ancient_enamel","ancient_enamel"),True)
    collar.object((0,0,0),empty("RushSocket",(0,4.4,0),family))
    lip=Mesh("PulseLip")
    lip.ring(2.5,2.1,.3,0,24,("ancient_enamel","ancient_enamel"),True)
    lip.object((0,0,0),empty("PulseSocket",(0,.6,0),seat))
    socket=empty("BraceSocket",(0,1.4,0),family)
    plate=Mesh("BracePlate")
    r=2*math.sqrt(2)
    inner=(r-2)*math.sqrt(2)
    def point(radius,angle,y):
        return (radius*math.sin(angle),y,-radius*math.cos(angle))
    for i in range(12):
        a=-math.pi/4+i*math.pi/24
        b=a+math.pi/24
        plate.face([point(inner,a,.15),point(inner,b,.15),point(r,b,.15),point(r,a,.15)],"ancient_enamel","bone")
        plate.face([point(r,a,-.15),point(r,b,-.15),point(inner,b,-.15),point(inner,a,-.15)],"ancient_enamel","petrol")
        for rad in (inner,r):
            plate.face([point(rad,a,-.15),point(rad,a,.15),point(rad,b,.15),point(rad,b,-.15)],"ancient_enamel","bone")
        plate.face([point(r*.64,a,.154),point(r*.64,b,.154),point(r,b,.154),point(r,a,.154)],"signal_surface","hazard" if i%3 else "charcoal")
    for a in (-math.pi/4,math.pi/4):
        plate.face([point(inner,a,-.15),point(r,a,-.15),point(r,a,.15),point(inner,a,.15)],"ancient_enamel","bone")
    plate_obj=plate.object((0,0,0),socket)
    plate_obj.rotation_euler.x=math.pi/2
    optic(seat)
    for suffix in ("L","R"):
        ref=empty("HandSpawnReference"+suffix,(0,0,0),root)
        ref["runtime_reference_only"]=True
    return root


def rest(root):
    return {o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in common.tree(root)}


def fit_mantle_envelope(root):
    """Fit the bevel tips to the specified 32 by 30 m envelope, keeping sockets fixed."""
    bpy.context.view_layer.update()
    slabs=[o for o in common.tree(root) if o.type=="MESH" and o.name.startswith("Mantle")]
    points=[o.matrix_world@v.co for o in slabs for v in o.data.vertices]
    left,right=min(p.x for p in points),max(p.x for p in points)
    top=max(p.z for p in points)
    for obj in slabs:
        inverse=obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            at=obj.matrix_world@vertex.co
            at.x=(at.x-(left+right)/2)*32/(right-left)
            if at.z>20:
                at.z=20+(at.z-20)*10/(top-20)
            vertex.co=inverse@at
        obj.data.update()


def reset_pose(root, snapshot):
    for o in common.tree(root):
        o.location,o.rotation_euler,o.scale=snapshot[o.name]


def pose(clip,t,root,snapshot):
    reset_pose(root,snapshot)
    objs={o.name:o for o in common.tree(root)}
    def obj(name):
        return objs.get(name)
    if clip.startswith("phase_break"):
        idx={"phase_break":0,"phase_break_2":1,"phase_break_3":2}[clip]
        slab=obj("Mantle%d"%idx)
        if slab:
            side=-1 if idx%2==0 else 1
            if t<.2:
                k=t/.2
                slab.rotation_euler.x=.05*k*math.sin(math.tau*15*t)
                slab.location+=B((side*.06*k*math.sin(math.tau*11*t),0,.04*k))
            else:
                u=(t-.2)/.8
                kick=min(1,u/.12)
                lateral=.18*kick*(2-kick)+.82*u**1.4
                lift=.35*math.sin(math.pi*min(1,u/.5))*(1-u)
                slab.location+=B((side*4*lateral,-5*u*u+lift,1.5*lateral))
                slab.rotation_euler.x=.65*u+.25*math.sin(math.pi*u)*(1-u)
                slab.rotation_euler.z=side*.3*math.sin(math.pi*u)
                slab.scale=Vector((1,1,1))*max(.015,1-u**6)
    if clip=="glove_down":
        settle=ease(t/.8)
        for i in range(6):
            slab=obj("Mantle%d"%i)
            if slab:
                slab.rotation_euler.x=(.09 if i%2 else -.07)*settle
        glove=obj("GlovePlate")
        if glove:
            u=ease((t-.15)/.7)
            land=ease((t-.85)/.15)
            at=Vector(GLOVE_FROM).lerp(Vector(GLOVE_AT)+Vector((0,.5,0)),u)
            at.y-=.5*land
            glove.location=B(at)
            glove.rotation_euler.z=math.radians(GLOVE_YAW)+(1-u)*.9
            glove.rotation_euler.x=(1-u)*.5
            glove.scale=Vector((1.6,1.6,1.6))*max(.001,min(1,(t-.1)/.08))
    if clip=="final_quiet":
        for i in range(6):
            slab=obj("Mantle%d"%i)
            if slab:
                slab.rotation_euler.x=(.09 if i%2 else -.07)*t
        if obj("LensRoot"):
            obj("LensRoot").rotation_euler.x=.22*t
    if clip=="attention" and obj("LensRoot"):
        obj("LensRoot").rotation_euler.z=.08*math.sin(math.tau*t)
        obj("LensRoot").rotation_euler.x=.03*math.sin(math.pi*t)
    if clip in ("lane_warn","split_lane_warn"):
        for suffix in ("L","R"):
            emitter=obj("Emitter"+suffix)
            if emitter and (clip=="split_lane_warn" or suffix=="L"):
                emitter.rotation_euler.x=.70*t
        if clip=="split_lane_warn" and obj("EmitterSocketR"):
            obj("EmitterSocketR").rotation_euler.z=-.525*t
    if clip=="rush_warn" and obj("RushCollar"):
        obj("RushCollar").location.z=-.42*t
        obj("RushCollar").scale.z=1-.30*t
    if clip=="plate_warn" and obj("BracePlate"):
        obj("BracePlate").rotation_euler.x=math.pi/2*(1-t)
    if clip=="pulse_warn" and obj("PulseLip"):
        obj("PulseLip").location.z=.45*t
    if clip=="pulse" and obj("PulseLip"):
        obj("PulseLip").location.z=.45*(1-t)-.10*math.sin(math.pi*t)
    if clip in ("family_strike","recovery") and obj("FamilyRecoil"):
        obj("FamilyRecoil").location.z=-.18*(ease(t/.6) if clip=="family_strike" else 1-ease(t))
    if clip.startswith("choir_change") and obj("LensRoot"):
        start={"choir_change":0,"choir_change_1_2":1,"choir_change_2_0":2}[clip]
        a=(start+t)*math.tau/3
        obj("LensRoot").location=B((1.6*math.cos(a),7.6,-1.6*math.sin(a)))
    if clip in ("stagger_open","final_quiet"):
        opened=t if clip=="stagger_open" else 1-t
        for i in range(6):
            shutter=obj("Shutter%d"%i)
            if shutter:
                shutter.rotation_euler.x=-1.24*opened
                shutter.location.z=.12*opened
    if clip=="hand_send" and obj("FamilyRecoil"):
        obj("FamilyRecoil").location.z=-.18*(1-ease(t))
    if clip=="hand_send" and obj("EmitterL"):
        obj("EmitterL").rotation_euler.z=.09*math.sin(math.pi*t)


def controls(clip,root):
    names=[]
    if clip.startswith("phase_break"):
        names=["Mantle%d"%{"phase_break":0,"phase_break_2":1,"phase_break_3":2}[clip]]
    elif clip=="attention": names=["LensRoot"]
    elif clip=="lane_warn": names=["EmitterL"]
    elif clip=="split_lane_warn": names=["EmitterL","EmitterR","EmitterSocketR"]
    elif clip=="rush_warn": names=["RushCollar"]
    elif clip=="plate_warn": names=["BracePlate"]
    elif clip in ("family_strike","recovery"): names=["FamilyRecoil"]
    elif clip in ("pulse_warn","pulse"): names=["PulseLip"]
    elif clip.startswith("choir_change"): names=["LensRoot"]
    elif clip=="stagger_open": names=["Shutter%d"%i for i in range(6)]
    elif clip=="hand_send": names=["EmitterL","FamilyRecoil"]
    elif clip=="glove_down": names=["Mantle%d"%i for i in range(6)]+["GlovePlate"]
    elif clip=="final_quiet": names=["Mantle%d"%i for i in range(6)]+["LensRoot"]+["Shutter%d"%i for i in range(6)]
    return [o for o in common.tree(root) if o.name in names]


def animate(root,snapshot):
    scene=bpy.context.scene
    scene.render.fps=30
    scene.frame_start=1
    scene.frame_end=121
    for clip,(duration,key) in CLIPS.items():
        for o in controls(clip,root):
            o.animation_data_create()
            act=bpy.data.actions.new(clip+"_"+o.name)
            o.animation_data.action=act
            act.use_fake_user=True
            frames=list(range(1,round(duration*30)+2))
            for f in frames:
                pose(clip,(f-1)/(duration*30),root,snapshot)
                for path in ("location","rotation_euler","scale"):
                    o.keyframe_insert(data_path=path,frame=f,group=o.name)
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for k in curve.keyframe_points:
                                k.interpolation="BEZIER"
                                k.handle_left_type="AUTO_CLAMPED"
                                k.handle_right_type="AUTO_CLAMPED"
                            curve.update()
            o.animation_data.action=None
            track=o.animation_data.nla_tracks.new()
            track.name=clip
            strip=track.strips.new(clip,1,act)
            strip.extrapolation="NOTHING"
            track.mute=True
    reset_pose(root,snapshot)


def glb_info(path):
    data=path.read_bytes()
    n=struct.unpack_from("<I",data,12)[0]
    doc=json.loads(data[20:20+n])
    triangles=vertices=draws=0
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            triangles+=doc["accessors"][prim["indices"]]["count"]//3
            vertices+=doc["accessors"][prim["attributes"]["POSITION"]]["count"]
            draws+=1
    return {"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),"tris":triangles,
            "verts":vertices,"draws":draws,"clips":[a["name"] for a in doc.get("animations",[])],
            "nodes":[n["name"] for n in doc["nodes"]],"materials":[m["name"] for m in doc["materials"]]}


def freeze_rest_export(path,snapshot):
    """NLA export can leave static defaults at zero. Pin them to authored rest.

    Animation samplers stay untouched. Roots remain identity, and every rigid pivot
    matches the same rest table used to author its clips and judge previews.
    """
    data=path.read_bytes()
    length=struct.unpack_from("<I",data,12)[0]
    doc=json.loads(data[20:20+length])
    for node in doc["nodes"]:
        if node["name"] not in snapshot:
            continue
        loc,rot,scale=snapshot[node["name"]]
        q=rot.to_quaternion()
        node.pop("matrix",None)
        node["translation"]=[loc.x,loc.z,-loc.y]
        node["rotation"]=[q.x,q.z,-q.y,q.w]
        node["scale"]=[scale.x,scale.z,scale.y]
    encoded=json.dumps(doc,sort_keys=True,separators=(",",":"),ensure_ascii=True).encode()
    encoded+=b" "*((-len(encoded))%4)
    binary=data[20+length:]
    path.write_bytes(struct.pack("<III",0x46546c67,2,20+len(encoded)+len(binary))+
                     struct.pack("<II",len(encoded),0x4e4f534a)+encoded+binary)


def export(root,path,snapshot):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(root):
        obj.select_set(True)
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute=False
    bpy.context.view_layer.objects.active=root
    bpy.context.scene.frame_set(0)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_yup=True,export_materials="EXPORT",export_vertex_color="ACTIVE",
        export_animations=True,export_animation_mode="NLA_TRACKS",export_merge_animation="NLA_TRACK",
        export_anim_slide_to_zero=True,export_frame_range=False,export_force_sampling=True,
        export_optimize_animation_keep_anim_object=True,export_extras=False,
        export_cameras=False,export_lights=False)
    for obj in common.tree(root):
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute=True
    freeze_rest_export(path,snapshot)
    common.canonical_indices(str(path),vertices=True)
    print("EXPORTED",path)


def previews(roots,snapshots,out):
    out.mkdir(parents=True,exist_ok=True)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples=12
    scene.cycles.use_denoising=True
    scene.cycles.seed=1979
    scene.render.resolution_x=960
    scene.render.resolution_y=900
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX"
    scene.view_settings.exposure=-.65
    world=bpy.data.worlds.new("JudgeSky")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs[0].default_value=(.32,.43,.55,1)
    world.node_tree.nodes["Background"].inputs[1].default_value=.5
    scene.world=world
    bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=36,depth=.2,location=(0,0,-.1))
    pad=bpy.context.object
    pad.name="PreviewArena36m"
    mat=bpy.data.materials.new("PreviewGround")
    mat.use_nodes=True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=common.rgba("c6a274")
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.9
    pad.data.materials.append(mat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=B((6,1,0)))
    ball=bpy.context.object
    ball.name="ReferenceBall2m"
    ballmat=bpy.data.materials.new("PreviewBall")
    ballmat.use_nodes=True
    ballmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=common.rgba("b77843")
    ballmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.45
    ball.data.materials.append(ballmat)
    for poly in ball.data.polygons: poly.use_smooth=True
    for name,at,power,size in [("Key",(-24,36,-25),42000,18),("Fill",(22,25,-15),22000,22),
                               ("Rim",(4,35,22),48000,14)]:
        data=bpy.data.lights.new(name,"AREA")
        data.energy=power
        data.shape="DISK"
        data.size=size
        light=bpy.data.objects.new(name,data)
        scene.collection.objects.link(light)
        light.location=B(at)
        light.rotation_euler=(B((0,16,0))-light.location).to_track_quat("-Z","Y").to_euler()
    camdata=bpy.data.cameras.new("JudgeCamera")
    cam=bpy.data.objects.new("JudgeCamera",camdata)
    scene.collection.objects.link(cam)
    scene.camera=cam
    camdata.type="ORTHO"
    camdata.ortho_scale=38
    rendered=[]
    def render(name,at,target):
        cam.location=B(at)
        cam.rotation_euler=(B(target)-cam.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=str(out/(name+".png"))
        bpy.ops.render.render(write_still=True)
        rendered.append(name+".png")
    for root in roots: reset_pose(root,snapshots[root.name])
    for label,at in [("front",(0,17,-65)),("side",(65,17,0)),("three_quarter",(46,22,-46))]:
        direction=Vector((at[0],0,at[2])).normalized()
        across=Vector((-direction.z,0,direction.x))
        ball.location=B(across*6+Vector((0,1,0)))
        render("mind_assembled_"+label,at,(0,15,0))
        for root in roots:
            for other in roots:
                for obj in common.tree(other): obj.hide_render=other!=root
            render(("boss_mind_base" if root.name=="MindRoot" else "boss_mind_kit")+"_"+label,at,(0,15,0))
        for root in roots:
            for obj in common.tree(root): obj.hide_render=False
    camdata.ortho_scale=38
    ball.location=B((6,1,0))
    for clip,(duration,key) in CLIPS.items():
        for root in roots: pose(clip,key/duration,root,snapshots[root.name])
        render("clip_"+clip,(35,20,-55),(0,15,0))
    camdata.ortho_scale=14
    for clip in ("lane_warn","split_lane_warn","rush_warn","plate_warn","pulse_warn","stagger_open"):
        for root in roots: pose(clip,1,root,snapshots[root.name])
        render("detail_"+clip,(18,13,-27),(0,5,0))
    (out/"preview-manifest.json").write_text(json.dumps({"renderer":"Blender Cycles "+bpy.context.scene.cycles.device,
        "samples":12,"resolution":[960,900],"arena_radius_m":36,"reference_ball_diameter_m":2,
        "views":"orthographic matched 38 m frame; detail inserts 14 m",
        "frames":rendered,"clip_key_seconds":{c:k for c,(d,k) in CLIPS.items()}},indent=2)+"\n")


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out-dir",type=Path,default=SKETCH/"assets/models/bosses")
    parser.add_argument("--preview",type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    common.reset()
    materials()
    base_root=base()
    fit_mantle_envelope(base_root)
    polish.enable(ao_reach=.08)
    polish.bake(base_root,polish.options())
    base_rest=rest(base_root)
    animate(base_root,base_rest)
    args.out_dir.mkdir(parents=True,exist_ok=True)
    export(base_root,args.out_dir/"boss_mind_base.glb",base_rest)
    # Free Blender-global names before the kit, but preserve base preview identity.
    for obj in common.tree(base_root): obj.name="BasePreview_"+obj.name
    kit_root=kit()
    polish.bake(kit_root,polish.options())
    kit_rest=rest(kit_root)
    animate(kit_root,kit_rest)
    export(kit_root,args.out_dir/"boss_mind_kit.glb",kit_rest)
    info={}
    for file,cap in (("boss_mind_base.glb",(20000,38400,32)),("boss_mind_kit.glb",(6000,11200,18))):
        row=glb_info(args.out_dir/file)
        assert all(row[k]<=limit for k,limit in zip(("tris","verts","draws"),cap)),(file,row,cap)
        info[file]=row
        print("MND_BUDGET",file,row["tris"],row["verts"],row["draws"],"bytes",row["bytes"],"sha256",row["sha256"])
        print("MND_CLIPS",file,",".join(row["clips"]))
    for obj in common.tree(base_root): obj.name=obj.name.removeprefix("BasePreview_")
    base_snapshot={obj.name:base_rest[obj.name.removesuffix(".001")] for obj in common.tree(base_root)}
    reset_pose(kit_root,kit_rest)
    kit_snapshot=kit_rest
    if args.preview:
        (args.preview).mkdir(parents=True,exist_ok=True)
        (args.preview/"asset-manifest.json").write_text(json.dumps(info,indent=2)+"\n")
        previews([base_root,kit_root],{base_root.name:base_snapshot,kit_root.name:kit_snapshot},args.preview)
    print("mind_body: PASS")


if __name__=="__main__":
    main()
