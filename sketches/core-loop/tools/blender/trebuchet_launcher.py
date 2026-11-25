"""Headless recipe for the trebuchet launcher in the approved FLUX.1 schnell concept picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props-r2/trebuchet_launcher_202.png (board alpha-props-r2, seed 202):
a tall petrol riveted A-frame of girders under an oxide top beam; a charcoal pipe across the middle with a hub, a hex
fitting and a flywheel; a large dark glass sphere in a copper band on a plinth, with a gear and a piston above it; a
petrol control box with two gauges and an ancient-green lamp on the right; a copper pulley on the left.

Same route as cannon_launcher.py and lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for
dig_scenery.gd SLOTS. Class "landmark" (900 tris, 2000 verts, 2 draws per GLB):
  trebuchet_launcher_frame.glb  enamel (girders, beams, plinth, control box, lamp) and steel (bearings, axle, flywheel,
                                hex fitting, base plate, copper band, gear, piston, pulley, cables, foot pads, gauge bezels)
  trebuchet_launcher_arm.glb    steel: the throwing arm, origin at its pivot; the code's `arm` node (contraptions.gd:490-496)
  trebuchet_launcher_glass.glb  glass: the sphere and the two gauge faces, at the frame's origin
No state key: the launcher's amber cradle ring and its gauge dial stay code-drawn (contraptions.gd:424-435, :508). The lamp
is ANCIENT (#9dff3c, src/core/palette.gd:15) as vertex colour only: no slot emits.

Footprint (src/world/contraptions.gd:481-496, :519-521, map_gorge.gd:354): origin at the mouth point ground(at, 1.0), so the
ground is at y -1.0, and +z is the aim. Posts 1 x 12 x 1 at mouth - aim*6 +- side*3 + UP*5 (y -1 to 11); the arm 1 x 1 x 20
at mouth - aim*6 + UP*10.5, posed by Basis.looking_at(aim rotated about the side axis by lerp(-0.9, 0.7, g)), so the arm's
local -z points along the rotated aim and its local x maps to world -x: the arm GLB is symmetric in x, its -z end is the
throwing end. Every fixed part stays out of the arm's swing (SWEEP, asserted) and out of the ring's opening (CLEAR).

Lore (research/lore-makers-2026-10-09.md): copper band, pulley, flywheel and fittings (the picture's brass and copper),
petrol enamel girders, oxide top beam, oil charcoal iron. Highdraft Roosts construction: open frames, tensioned cables,
hung parts; here the guy cables from the top beam to the skids and the control box hung off the right post.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/trebuchet_launcher.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lantern_beacon import kit, common, frustum, around
from ore_cart import strut
import polish

MODELS = kit.SKETCH / "assets/models"
LANDMARK = [2400, 2000, 2]
FINISH = {"Girders": {"bevel": .04}, "Fittings": {"bevel": .03}, "Arm": {"bevel": .04}, "Glass": {"bevel": .04}, "Detail1": {"bevel": 0}, "Detail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.04, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


NAME = "trebuchet_launcher"

TONES = {
    "girder": "petrol",
    "beam": "oxide",
    "iron": "charcoal",
    "copper": "copper",
    "cable": "2a3231",
    "face": "e6d9b8",
    "lamp": "9dff3c",
}

GROUND = -1.0
FZ = -6.0
PIVOT = (0.0, 10.5, FZ)
POST = (3.0, 11.0, .9)
OUTER = ((5.4, GROUND), (4.35, 11.78))
BRACES = (3.2, 7.6)
BEAM = (4.75, 11.78, 12.18, .3)
BEARING = (.6, 10.0, 11.0, .55)
AXLE = (.28, .82, 3.75)
FLY = (4.05, 1.2, .28)
HEX_END = (-4.1, .45, .35)
STUB = (.14, 11.5)
BASE = (5.75, -1.0, -.45, .5)
SKID = (4.35, (-8.3, -3.95), (-1.0, -.7), .3)
SPHERE = ((0.0, 2.08, FZ), 2.2)
BAND = (2.24, .14)
PLINTH = (2.3, 1.5, (-.75, -.45))
PLATE = (1.8, -.45, -.12)
GEAR = (.6, .74, 4.15, 4.5, 16)
PISTON = (.36, 4.5, 6.8)
ROD = (.15, 6.8, 9.1)
PULLEY = ((-4.05, .75, FZ + 1.0), .95, .26)
PEDESTAL = ((-4.05, FZ + 1.0), .3, .45)
BOX = ((2.15, 3.85), (-1.0, 2.75), (FZ + 1.1, FZ + 2.3))
GAUGES = [((2.6, 2.25), .33), ((3.3, 1.05), .48)]
KNOB = ((3.0, -.25), .32)
LAMP = ((1.85, .95, FZ + 1.7), .16, .55)
VALVE = ((1.85, .1, FZ + 1.7), .2)
PIPE = ((2.8, 2.75, FZ + 1.5), 6.2, (3.0, FZ + .5))
CABLES = [((-4.5, 11.9, FZ), (-4.35, -.72, -8.2)), ((-4.5, 11.9, FZ), (-4.35, -.72, -3.98)),
          ((4.5, 11.9, FZ), (4.35, -.72, -8.2)), ((4.5, 11.9, FZ), (4.35, -.72, -3.98))]
ARM = (.45, 10.0)
HUB = (.7, .7)
ARM_FIT = (.6, -10.0, -9.3)
ARM_DRUM = (.95, 8.1, 9.7)
SWING = (-.9, .7)
CLEAR = 3.6
N = 8
SIZE = {"trebuchet_launcher_frame": [11.562, 13.211, 4.81], "trebuchet_launcher_arm": [1.755, 1.755, 20.0],
        "trebuchet_launcher_glass": [5.821, 4.4, 4.532]}


def tone(name):
    return common.srgb(TONES[name])


def unit(v):
    m = math.sqrt(sum(c * c for c in v))
    return tuple(c / m for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class Frame:
    """Adds local (x, t, z) parts to a Surface along an axis: x along u, t along d, z along u x d (right-handed)."""

    def __init__(self, s, origin, d, u):
        self.s, self.o, self.d, self.u = s, origin, unit(d), unit(u)
        self.w = cross(self.u, self.d)

    def at(self, v):
        return tuple(self.o[k] + v[0] * self.u[k] + v[1] * self.d[k] + v[2] * self.w[k] for k in range(3))

    def add(self, verts, faces, color="petrol", colors=None):
        self.s.add([self.at(v) for v in verts], faces, color, colors)


def ring(s, rows, n, color, start=None, tones=None, at=(0.0, 0.0), radius=None):
    aa = around(n, math.pi / n if start is None else start)
    rr = radius or (lambda r, i: r)
    verts = [(at[0] + rr(r, i) * math.sin(a), t, at[1] + rr(r, i) * math.cos(a)) for r, t in rows for i, a in enumerate(aa)]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rows) - 1) for i in range(n)]
    colors = [c for c in tones for _ in range(n)] if tones else None
    s.add(verts, faces, color, colors)


def cylinder(s, r, t0, t1, n, color):
    ring(s, [(.02, t0), (r, t0), (r, t1), (.02, t1)], n, color)


def box(s, lo, hi, color, top=None):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    verts = [(x, y, z) for x, y, z in [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                       (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]]
    colors = [top if top and v[1] == y1 else color for v in verts] if top else None
    s.add(verts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], color, colors)


def torus(s, centre, major, minor, seg, sides, color):
    verts = []
    for i in range(seg):
        a = math.tau * i / seg
        for j in range(sides):
            b = math.tau * j / sides + math.pi / sides
            r = major + minor * math.cos(b)
            verts.append((centre[0] + r * math.sin(a), centre[1] + minor * math.sin(b), centre[2] + r * math.cos(a)))
    faces = [(i * sides + j, i * sides + (j + 1) % sides, ((i + 1) % seg) * sides + (j + 1) % sides, ((i + 1) % seg) * sides + j)
             for i in range(seg) for j in range(sides)]
    s.add(verts, faces, color)


def along_x(s, centre):
    return Frame(s, centre, (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))


def along_z(s, centre):
    return Frame(s, centre, (0.0, 0.0, 1.0), (1.0, 0.0, 0.0))


def girders(s):
    px, top, w = POST
    (fx, fy), (hx, hy) = OUTER
    for sx in (-1.0, 1.0):
        strut(s, (sx * px, GROUND, FZ), (sx * px, BEAM[1], FZ), w, w, tone("girder"))
        strut(s, (sx * fx, fy, FZ), (sx * hx, hy, FZ), w * .85, w * .85, tone("girder"))
        for y in BRACES:
            x = fx + (hx - fx) * (y - fy) / (hy - fy)
            strut(s, (sx * (px + w / 2 - .05), y, FZ), (sx * (x - w * .42 + .05), y, FZ), .4, .5, tone("girder"))
    hl, b0, b1, hd = BEAM
    box(s, (-hl, b0, FZ - hd), (hl, b1, FZ + hd), tone("beam"))
    bl, y0, y1, bd = BASE
    box(s, (-bl, y0, FZ - bd), (bl, y1, FZ + bd), tone("girder"), top=tone("beam"))
    sx_, (z0, z1), (k0, k1), sw = SKID
    for sx in (-1.0, 1.0):
        box(s, (sx * sx_ - sw, k0, z0), (sx * sx_ + sw, k1, z1), tone("girder"), top=tone("beam"))
    hx_, hz, (p0, p1) = PLINTH
    box(s, (-hx_, p0, FZ - hz), (hx_, p1, FZ + hz), tone("girder"), top=tone("beam"))
    (x0, x1), (y0, y1), (z0, z1) = BOX
    box(s, (x0, y0, z0), (x1, y1, z1), tone("girder"), top=tone("girder"))
    (lx, ly, lz), lr, lh = LAMP
    frustum(s, lr, .02, ly, ly + lh, 6, tone("lamp"), caps=(True, False), at=(lx, lz))
    (pxx, pz), phx, phz = PEDESTAL
    box(s, (pxx - phx, GROUND, pz - phz), (pxx + phx, PULLEY[0][1] - .3, pz + phz), tone("girder"), top=tone("beam"))


def fittings(s):
    hw, y0, y1, hd = BEARING
    px = POST[0]
    for sx in (-1.0, 1.0):
        box(s, (sx * px - hw, y0, FZ - hd), (sx * px + hw, y1, FZ + hd), tone("iron"))
        a = along_x(s, (0.0, PIVOT[1], FZ))
        r, x0, x1 = AXLE
        lo, hi = (x0, x1) if sx > 0 else (-x1, -x0)
        frustum(a, r, r, lo, hi, 6, tone("iron"), caps=(False, False))
    f = along_x(s, (FLY[0], PIVOT[1], FZ))
    fr, fh = FLY[1], FLY[2]
    ring(f, [(.3, -fh), (fr, -fh), (fr, fh), (.3, fh), (.3, -fh)], 12, tone("copper"))
    h = along_x(s, (HEX_END[0], PIVOT[1], FZ))
    cylinder(h, HEX_END[1], -HEX_END[2], HEX_END[2], 6, tone("iron"))
    sr, sy = STUB
    frustum(s, sr, sr, sy, BEAM[1] + .02, 6, tone("iron"), caps=(False, False), at=(0.0, FZ))
    pr, p0, p1 = PLATE
    ring(s, [(.02, p0), (pr, p0), (pr, p1), (.02, p1)], 8, tone("iron"), at=(0.0, FZ))
    (cx, cy, cz), _ = SPHERE
    torus(s, (cx, cy, cz), BAND[0], BAND[1], 12, 3, tone("copper"))
    g0, g1, gy0, gy1, teeth = GEAR
    ring(s, [(.02, gy0), (g0, gy0), (g0, gy1), (.02, gy1)], 10, tone("iron"), at=(0.0, FZ))
    frustum(s, PISTON[0], PISTON[0], PISTON[1], PISTON[2], N, tone("iron"), caps=(False, True), at=(0.0, FZ))
    frustum(s, ROD[0], ROD[0], ROD[1], ROD[2], 6, tone("copper"), caps=(False, True), at=(0.0, FZ))
    (qx, qy, qz), qr, qh = PULLEY
    q = along_x(s, (qx, qy, qz))
    ring(q, [(.18, -qh), (qr, -qh), (qr * .8, 0.0), (qr, qh), (.18, qh), (.18, -qh)], 8, tone("copper"))
    for (gx, gy), br in GAUGES:
        b = along_z(s, (gx, gy, BOX[2][1]))
        ring(b, [(.02, -.02), (br, -.02), (br, .08), (.02, .08)], 8, tone("copper"))
    (kx, ky), kr = KNOB
    k = along_z(s, (kx, ky, BOX[2][1]))
    ring(k, [(.02, -.02), (kr, -.02), (kr * .6, .2), (.02, .2)], 6, tone("copper"))
    (vx, vy, vz), vr = VALVE
    strut(s, (BOX[0][0] + .05, vy, vz), (vx - .05, vy, vz), .22, .22, tone("copper"))
    box(s, (vx - vr, vy - .25, vz - vr), (vx + vr, vy + .25, vz + vr), tone("copper"))
    strut(s, (BOX[0][0] + .05, LAMP[0][1] - .05, LAMP[0][2]), (LAMP[0][0], LAMP[0][1] - .05, LAMP[0][2]), .16, .16, tone("copper"))
    (fx, fy, fz), ty, (ex, ez) = PIPE
    frustum(s, .14, .14, fy - .05, ty, 6, tone("iron"), caps=(False, False), at=(fx, fz))
    strut(s, (fx, ty, fz), (ex, ty, ez), .28, .28, tone("iron"))
    for a, b in CABLES:
        strut(s, a, b, .09, .09, tone("cable"))


def glass(s):
    (cx, cy, cz), r = SPHERE
    rows = [(max(.02, r * math.sin(math.pi * k / 9)), cy - r * math.cos(math.pi * k / 9)) for k in range(10)]
    ring(s, rows, 14, tone("iron"), at=(cx, cz))
    for (gx, gy), br in GAUGES:
        b = along_z(s, (gx, gy, BOX[2][1]))
        fr = br * .8
        ring(b, [(.02, .07), (fr, .07), (fr, .11), (.02, .12)], 8, tone("face"))


def arm(s):
    r, hl = ARM
    z = along_z(s, (0.0, 0.0, 0.0))
    fr, f0, f1 = ARM_FIT
    dr, d0, d1 = ARM_DRUM
    ring(z, [(.02, -hl), (fr, -hl), (fr, f1), (r, f1), (r, d0), (dr, d0), (dr, d1), (r, d1), (r, hl), (.02, hl)], N,
         tone("iron"), tones=[tone("iron")] * 3 + [tone("iron")] * 2 + [tone("copper")] * 2 + [tone("iron")] * 3)
    h = along_x(s, (0.0, 0.0, 0.0))
    hr, hw = HUB
    cylinder(h, hr, -hw, hw, N, tone("copper"))


def edge_points(verts, faces, step=.1):
    pts = list(verts)
    for f in faces:
        for i in range(len(f)):
            a, b = verts[f[i]], verts[f[(i + 1) % len(f)]]
            d = math.dist(a, b)
            for k in range(1, int(d / step)):
                t = k * step / d
                pts.append(tuple(a[j] + (b[j] - a[j]) * t for j in range(3)))
    return pts


def in_arm(p):
    x, y, z = p
    rad = math.hypot(x, y)
    m = .05
    if abs(z) <= ARM[1] + m and rad <= ARM[0] + m:
        return True
    if math.hypot(y, z) <= HUB[0] + m and abs(x) <= HUB[1] + m:
        return True
    if ARM_FIT[1] - m <= z <= ARM_FIT[2] + m and rad <= ARM_FIT[0] + m:
        return True
    return ARM_DRUM[1] - m <= z <= ARM_DRUM[2] + m and rad <= ARM_DRUM[0] + m


def sweep(name, verts, faces):
    pts = edge_points(verts, faces)
    hits = 0
    for k in range(161):
        a = SWING[0] + (SWING[1] - SWING[0]) * k / 160
        s_, c_ = math.sin(a), math.cos(a)
        for v in pts:
            p = (v[0] - PIVOT[0], v[1] - PIVOT[1], v[2] - PIVOT[2])
            if abs(p[0]) > max(HUB[1], ARM_DRUM[0]) + .1:
                continue
            hits += in_arm((-p[0], c_ * p[1] - s_ * p[2], -s_ * p[1] - c_ * p[2]))
    assert hits == 0, (name, "arm swing", hits)
    print("TREBUCHET_SWEEP", name, "points", len(pts), "angles 161", "hits 0")


def clear(name, verts):
    near = min(math.hypot(v[0], v[2]) for v in verts)
    assert near >= CLEAR, (name, "ring footprint", near)
    print("TREBUCHET_CLEAR", name, "nearest_horizontal_to_mouth", round(near, 3))


def export(name, surfaces, sockets, out_dir, budget=LANDMARK, tag="TREBUCHET", size=None, fixed=True):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    for part, slot, smooth, build in surfaces:
        s = kit.Surface(part, slot, smooth=smooth)
        build(s)
        if fixed:
            clear(name + ":" + part, s.verts)
            sweep(name + ":" + part, s.verts, s.faces)
        s.finish(root)
    for pname, row in kit.PARTS.items():
        kit.empty(pname, row["reference_position"], root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    got = metrics["bounds"]["size"]
    print(tag + "_SIZE", name, [round(v, 3) for v in got], metrics["bounds"], metrics["triangles"], metrics["vertices"], metrics["draws"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], budget)), (name, metrics, budget)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    want = size or SIZE[name]
    assert all(abs(a - b) <= .03 * b for a, b in zip(got, want)), (name, got, want)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print(tag + "_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def out_dir():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    return parser.parse_args(argv).out_dir


def main():
    polish_on()
    d = out_dir()
    export(NAME + "_frame", [("Girders", "enamel", False, girders), ("Fittings", "steel", False, fittings)],
           {"socket_arm": list(PIVOT), "socket_sphere": list(SPHERE[0])}, d)
    export(NAME + "_arm", [("Arm", "steel", False, arm)], {}, d, fixed=False)
    export(NAME + "_glass", [("Glass", "glass", True, glass)], {}, d)


if __name__ == "__main__":
    main()
