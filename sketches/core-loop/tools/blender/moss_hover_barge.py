"""Headless recipe for moss_hover_barge.glb and moss_hover_barge_thrusters.glb, the skin of Moss's hover barge in the
approved FLUX.1 schnell re-roll artifacts/local/alpha/push/w12/concepts/boards/alpha-props-r2/moss_hover_barge_202.png:
a teal rounded-square hull with a dark stripe and a dark underside, a bolted rim around the deck, a round sign swung
up on a hinged bracket at the back, and orange thruster wheels at the corners.

The deck stays the code heightfield (src/world/bay.gd:387-397, deck_height :260-269); this is the hull-and-fixtures
skin under and around it. Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named
for dig_scenery.gd SLOTS, class "landmark" (900 tris, 2000 verts, 2 draws per GLB). moss_hover_barge.glb: enamel
(hull, rim coping, sign face) and steel (stripe, sign bracket and mast, patch plate). moss_hover_barge_thrusters.glb:
elastomer (the four thruster wheels) and steel (the four jet housings at the code's jet points), the cart's
body-and-tyre split, because three slots exceed the class's two draws.

Footprint (bay.gd): origin at the Barge node, +X along `facing` (u), +Z is v. The deck is 62 x 42 m and its perimeter
sits at RIM 4.0 (deck_height returns RIM wherever the stadium offset passes 7 m, which is every perimeter point), so
the coping meets the deck edge at y 4.0 from outside and tucks under it; nothing rises above the deck inside the
62 x 42 rectangle. The hull bottom is today's box bottom (60 x 40 at y -3.5, :400-406); the jet housings keep the
code's jets (r 2.0 top, 3.2 bottom, 3 m tall, centred (+-25, -4.5, +-16), :407-418). The sign rides the -u end
outside the deck. Repairer's hand (Switchback Enclaves: compact, serviceable): the sign is a bolt-on bracket and an
oxide patch plate is bolted over a hull dent.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/moss_hover_barge.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lantern_beacon import kit, common, frustum
from ore_cart import strut
import polish

MODELS = kit.SKETCH / "assets/models"
LANDMARK = [2700, 2000, 2]
FINISH = {"Hull": {"bevel": .04}, "Fittings": {"bevel": .03}, "Wheels": {"bevel": 0, "subsurf": 1}, "Jets": {"bevel": .03}, "Detail1": {"bevel": 0}, "Detail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


TONES = {
    "hull": "365754",
    "under": "242a28",
    "stripe": "242a28",
    "sign": "e5a044",
    "sign_face": "e6d9b8",
    "copper": "b77843",
    "patch": "9b513a",
    "cable": "2a3231",
}

DECK_U, DECK_V, RIM_Y = 31.0, 21.0, 4.0
SEG = 4
SEAM = .002
HULL = [
    (30.6, 20.6, .6, -.8, "hull"),
    (31.0, 21.0, .25, RIM_Y - .04, "hull"),
    (31.7, 21.7, 1.5, RIM_Y, "hull"),
    (32.15, 22.15, 1.95, 3.7, "hull"),
    (32.3, 22.3, 2.1, 3.1, "hull"),
    (32.3, 22.3, 2.1, .6, "hull"),
    (32.3, 22.3, 2.1, -.7, "hull"),
    (32.3, 22.3, 2.1, -.7 - SEAM, "under"),
    (32.0, 22.0, 2.4, -1.6, "under"),
    (31.2, 21.2, 2.9, -2.7, "under"),
    (30.0, 20.0, 3.4, -3.5, "under"),
]
STRIPE = (32.3, 22.3, 2.1, -.85, .45, .1)
JETS = [(25.0, 16.0), (-25.0, 16.0), (25.0, -16.0), (-25.0, -16.0)]
JET = [(2.0, -3.0, "copper"), (3.2, -5.7, "copper"), (3.2, -6.0, "copper"), (2.5, -6.0, "cable"), (2.1, -5.5, "cable")]
WHEELS = [(24.0, 1), (-24.0, 1), (24.0, -1), (-24.0, -1)]
WHEEL = (2.4, -.4, 12)
SIGN = (-10.0, 4.2, .4, 16, math.radians(18))
SIGN_HINGE = (-22.75, 5.0)
PATCH = (10.0, -.0, 3.2, 1.8)
SIZE = {"moss_hover_barge": [64.8, 17.03, 48.09], "moss_hover_barge_thrusters": [56.4, 8.0, 46.6]}


def tone(name):
    return common.srgb(TONES[name])


def plan(hu, hv, r, y, grow=0.0):
    pts = []
    cu, cv = hu - r, hv - r
    for k, (su, sv) in enumerate([(1, 1), (-1, 1), (-1, -1), (1, -1)]):
        for i in range(SEG + 1):
            a = math.pi / 2 * (k + i / SEG)
            pts.append((su * cu + (r + grow) * math.cos(a), y, sv * cv + (r + grow) * math.sin(a)))
    return pts


def loft(s, rings, colors, cap_first=False, cap_last=False):
    n = len(rings[0])
    verts = [v for ring in rings for v in ring]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    if cap_first:
        faces.append(tuple(reversed(range(n))))
    if cap_last:
        faces.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    s.add(verts, faces, colors=[c for c in colors for _ in range(n)])


def hull(s):
    loft(s, [plan(*row[:4]) for row in HULL], [tone(row[4]) for row in HULL], cap_first=True, cap_last=True)


def sign_frame():
    u, r, t, n, lean = SIGN
    hz, hy = SIGN_HINGE
    up = (math.cos(lean), -math.sin(lean))
    normal = (math.sin(lean), math.cos(lean))
    return (u, hy + up[0] * (r + .5), hz + up[1] * (r + .5)), up, normal


def sign_face(s):
    u, r, t, n, lean = SIGN
    (cu, cy, cz), up, normal = sign_frame()

    def ring(rr, d):
        return [(cu + rr * math.sin(a), cy + up[0] * rr * math.cos(a) + normal[0] * d,
                 cz + up[1] * rr * math.cos(a) + normal[1] * d) for a in [math.tau * i / n for i in range(n)]]
    rows = [(ring(r, -t / 2), "sign"), (ring(r, t / 2), "sign"), (ring(r * .48, t / 2), "sign"),
            (ring(r * .48 - SEAM, t / 2), "sign_face")]
    loft(s, [rw for rw, _ in rows], [tone(c) for _, c in rows], cap_first=True, cap_last=True)


def enamel(s):
    hull(s)
    sign_face(s)


def steel(s):
    hu, hv, r, y0, y1, out = STRIPE
    loft(s, [plan(hu, hv, r, y0), plan(hu, hv, r, y0, out), plan(hu, hv, r, y1, out), plan(hu, hv, r, y1)],
         [tone("stripe")] * 4)
    u = SIGN[0]
    hz, hy = SIGN_HINGE
    s.box((1.6, 2.2, .5), (u, 2.9, -22.55), tone("cable"))
    strut(s, (u, 3.9, -22.55), (u, hy, hz), .45, .45, tone("cable"))
    s.box((1.2, .5, .7), (u, hy, hz), tone("copper"))
    (cu, cy, cz), up, normal = sign_frame()
    for du in (-.5, .5):
        strut(s, (u + du, hy, hz), (cu + du, cy - normal[0] * .2, cz - normal[1] * .2), .18, .18, tone("cable"))
    u, y, w, h = PATCH
    s.box((w, h, .08), (u, y, 22.3 + .04), tone("patch"))


def wheels(s):
    r, y, n = WHEEL
    aa = [math.tau * i / n for i in range(n)]
    for u, side in WHEELS:
        z0 = side * 21.9
        prof = [(r, 0.0, "copper"), (r, 1.0, "copper"), (r * .88, 1.25, "copper"), (r * .45, 1.3, "cable"),
                (r * .38, 1.5, "copper")]
        rings = [[(u + rr * math.cos(a), y + rr * math.sin(a), z0 + side * d) for a in aa] for rr, d, _ in prof]
        loft(s, rings, [tone(c) for _, _, c in prof], cap_last=True)


def housings(s):
    n = 10
    aa = [math.tau * i / n + math.pi / n for i in range(n)]
    for u, v in JETS:
        rings = [[(u + rr * math.sin(a), y, v + rr * math.cos(a)) for a in aa] for rr, y, _ in JET]
        loft(s, rings, [tone(c) for _, _, c in JET], cap_last=True)


def export(name, surfaces, out_dir):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    for part, slot, smooth, build in surfaces:
        sf = kit.Surface(part, slot, smooth=smooth)
        build(sf)
        sf.finish(root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    size = metrics["bounds"]["size"]
    print("MHB_SIZE", name, [round(v, 3) for v in size], metrics["triangles"], metrics["vertices"], metrics["draws"],
          metrics["bounds"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], LANDMARK)), (name, metrics, LANDMARK)
    assert sorted(metrics["materials"]) == sorted(slot for _, slot, _, _ in surfaces), (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(size, SIZE[name])), (name, size, SIZE[name])
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("MHB_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    args = parser.parse_args(argv)
    polish_on()
    export("moss_hover_barge", [("Hull", "enamel", False, enamel), ("Fittings", "steel", False, steel)], args.out_dir)
    export("moss_hover_barge_thrusters", [("Wheels", "elastomer", False, wheels), ("Jets", "steel", False, housings)],
           args.out_dir)


if __name__ == "__main__":
    main()
