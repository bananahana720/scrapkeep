"""Headless recipe for the steam lift in the approved FLUX.1 schnell concept picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props-r2/lift_platform_202.png (board alpha-props-r2, seed 202): a round
copper-rimmed deck on a black column with collar bands, over two domed petrol tanks with copper pipes, gauges and a valve
block on a dark square base, a copper safety-valve chimney and a lit lamp.

Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
Class "landmark" (900 tris, 2000 verts, 2 draws per GLB):
  lift_platform_deck.glb   enamel (plate: copper rim, petrol underside) and steel (deck plate, column): rides the lift body
  lift_platform_pump.glb   enamel (tanks, pipes, valve block, chimney, lamp) and steel (base, cradles, riser, gauge housings)
  lift_platform_glass.glb  glass: the gauge faces, at the pump's origin
No state key: the lift carries no state colour (its fired fact is a code puff, contraptions.gd:194-197).

Footprint (src/world/contraptions.gd:375-417, map_gorge.gd:350-351). The deck's origin is the lift body: the plate is a
1 m thick disc of radius 4.5 with its top at +0.5 (lift_top, :416-417), the collider is the same cylinder (:381-386), and the
piston (radius 1.2, rise + 1 = 14 m long) hangs from the plate centre to y -14 (:395-403). The ball rolls across the whole
disc and the plate sits flush with the ground at home (foot - 0.45, :405), so nothing on the deck rises above +0.5 or
reaches past 4.5 m (DECK_CLEAR), and the picture's railing and its glass bulb (the board prompt's "ball shell with a glass
cockpit dome", which is the player's own ball) are not modelled. The tanks cannot sit under a plate that rests on the
ground, so the pump and base are a separate static GLB with its origin at the foot, standing on -x beside the plate
(PUMP_AT; the code's dial stands on +x at radius + 1.6, :406), every vertex at least a ball's width outside the rim
(PUMP_CLEAR). No facing.

Lore (research/lore-makers-2026-10-09.md): copper rim, pipes, chimney and valve block (the picture's brass and copper),
petrol enamel tanks and underside, oil charcoal iron for the deck plate, column and base. Switchback Enclaves construction:
compact, serviceable: the pump is a bolted service module beside the lift with bolted inspection bosses on the tank ends
and a strapped tank band (the detail shells add the bolt rows and a hose clamp).

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lift_platform.py [-- --out-dir DIR]
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
LANDMARK = [2500, 2000, 2]
FINISH = {"Plate": {"bevel": .03}, "Column": {"bevel": .03}, "Pump": {"bevel": .03}, "Frame": {"bevel": .03}, "Faces": {"bevel": .04}, "Detail1": {"bevel": 0}, "Detail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


NAME = "lift_platform"

TONES = {
    "body": "petrol",
    "iron": "charcoal",
    "copper": "copper",
    "face": "e6d9b8",
    "lamp": "9dff3c",
}

RADIUS = 4.5
TOP = .5
PISTON = (1.2, 14.0)
DECK_CLEAR = (RADIUS + .001, TOP + .001)
ND = 24
NC = 12
PLATE = [(.02, .49, "iron"), (4.26, .49, "iron"), (4.26, .49, "copper"), (4.5, .4, "copper"), (4.5, -.12, "copper"),
         (4.42, -.2, "copper"), (4.42, -.2, "body"), (3.9, -.5, "body"), (.02, -.5, "body")]
DECK = (4.27, TOP, .47)
COLUMN = [(.02, -.45), (1.6, -.45), (1.6, -1.2), (1.2, -1.2), (1.2, -2.5), (1.48, -2.5), (1.48, -3.25), (1.2, -3.25),
          (1.2, -PISTON[1]), (.02, -PISTON[1])]
PUMP_AT = (-9.0, 0.0, 0.0)
PUMP_CLEAR = RADIUS + 2.0
BASE = ((0.0, .175, 0.0), (2.0, .175, 2.9))
NT = 10
TANK_Z = (-1.4, 1.4)
TANK_Y = 1.95
TANK = [(.02, -1.9), (.75, -1.82), (1.12, -1.6), (1.3, -1.25), (1.3, 1.25), (1.12, 1.6), (.75, 1.82), (.02, 1.9)]
BOSS = (.34, .22)
CRADLE_X = (-.9, .9)
RISER = [(.02, 2.7), (.6, 2.7), (.6, 3.3), (.95, 3.3), (.95, 3.45), (.6, 3.45), (.6, 3.95), (.02, 3.95)]
RISER_AT = (.2, 0.0)
CHIMNEY = ((-.2, -.25), (.17, 3.95, 4.95), (.26, 4.95, 5.12))
LAMP = ((.45, .3), (.11, 3.95, 5.0), (.18, 4.95, 5.08), (.17, .31, 5.08, 5.4))
PIPE_R = .17
U_PIPE = [(.6, 3.0, 1.75), (.6, 3.75, 1.75), (.6, 3.75, 3.25), (.6, 1.3, 3.25), (.6, 1.3, 2.85)]
ELBOW = [(-.5, 1.6, -2.65), (-.5, 1.6, -3.25), (-.5, 2.5, -3.25)]
ELBOW_VALVE = ((-.5, -3.25), (.24, 2.5, 2.7), (.13, 2.7, 3.05))
FEED = [(1.6, .9, -.5), (2.15, .9, -.5), (2.15, -.4, -.5)]
VALVE_BLOCK = ((.55, 1.4, 2.95), (.55, .38, .32))
GAUGES = [((-.55, 2.75, 2.75), .46, .38, .5), ((.55, 1.4, 3.3), .3, .24, .06)]
SIZE = {"lift_platform_deck": [8.923, 14.5, 8.923], "lift_platform_pump": [4.541, 5.8, 6.828], "lift_platform_glass": [1.7, 1.921, .6]}


def tone(name):
    return common.srgb(TONES[name])


def unit(v):
    m = math.sqrt(sum(c * c for c in v))
    return tuple(c / m for c in v)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def add(a, b):
    return tuple(a[k] + b[k] for k in range(3))


class Frame:
    """Adds local (x, t, z) parts to a Surface along an axis: x along u, t along d, z along u x d (right-handed)."""

    def __init__(self, s, origin, d, u):
        self.s, self.o, self.d, self.u = s, origin, unit(d), unit(u)
        self.w = cross(self.u, self.d)

    def at(self, v):
        return tuple(self.o[k] + v[0] * self.u[k] + v[1] * self.d[k] + v[2] * self.w[k] for k in range(3))

    def add(self, verts, faces, color="petrol", colors=None):
        self.s.add([self.at(v) for v in verts], faces, color, colors)


def ring(s, rows, n, color, start=None, tones=None, at=(0.0, 0.0)):
    aa = around(n, math.pi / n if start is None else start)
    verts = [(at[0] + r * math.sin(a), t, at[1] + r * math.cos(a)) for r, t in rows for a in aa]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rows) - 1) for i in range(n)]
    colors = [c for c in tones for _ in range(n)] if tones else None
    s.add(verts, faces, color, colors)


def slab(s, centre, half, color):
    cx, ct, cz = centre
    hx, ht, hz = half
    s.add([(cx + a * hx, ct + b * ht, cz + c * hz) for a, b, c in
           [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]],
          [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], color)


def pump(v):
    return add(PUMP_AT, v)


def pipe(s, points, r, color, n=6):
    pts = [pump(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        d0 = unit(tuple(pts[i][k] - pts[i - 1][k] for k in range(3))) if i else None
        d1 = unit(tuple(pts[i + 1][k] - pts[i][k] for k in range(3))) if i + 1 < len(pts) else None
        d = unit(tuple((d0 or d1)[k] + (d1 or d0)[k] for k in range(3)))
        up = (0.0, 1.0, 0.0) if abs(d[1]) < .9 else (1.0, 0.0, 0.0)
        a = unit(cross(d, up))
        b = cross(a, d)
        scale = 1.0 / max(.5, sum((d0 or d)[k] * d[k] for k in range(3)))
        rings.append([tuple(p[k] + r * (math.cos(t) * a[k] * scale + math.sin(t) * b[k]) for k in range(3))
                      for t in around(n, math.pi / n)])
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
             for k in range(len(rings) - 1) for i in range(n)]
    s.add([v for rr in rings for v in rr], faces, color)


def tank_frame(s, z):
    return Frame(s, pump((0.0, TANK_Y, z)), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))


def gauge_frame(s, g):
    return Frame(s, pump(g[0]), (0.0, 0.0, 1.0), (1.0, 0.0, 0.0))


def deck_enamel(s):
    ring(s, [(r, y) for r, y, _ in PLATE], ND, tone("body"), tones=[tone(t) for _, _, t in PLATE])


def deck_steel(s):
    r, y1, y0 = DECK
    ring(s, [(.02, y1), (r, y1), (r, y0), (.02, y0)], ND, tone("iron"))
    ring(s, COLUMN, NC, tone("iron"))


def pump_enamel(s):
    for z in TANK_Z:
        ring(tank_frame(s, z), TANK, NT, tone("body"))
    pipe(s, U_PIPE, PIPE_R, tone("copper"))
    pipe(s, ELBOW, PIPE_R, tone("copper"))
    pipe(s, FEED, PIPE_R * 1.3, tone("copper"))
    (x, z), (r0, y0, y1), (r1, y2, y3) = ELBOW_VALVE
    frustum(s, r0, r0, y0, y1, 6, tone("copper"), at=(PUMP_AT[0] + x, z))
    frustum(s, r1, r1, y2, y3, 6, tone("copper"), at=(PUMP_AT[0] + x, z))
    (x, z), (pr, p0, p1), (cr, c0, c1) = CHIMNEY
    frustum(s, pr, pr, p0, p1, 6, tone("copper"), at=(PUMP_AT[0] + x, z))
    frustum(s, cr, cr * .8, c0, c1, 6, tone("copper"), at=(PUMP_AT[0] + x, z))
    centre, half = VALVE_BLOCK
    slab(s, pump(centre), half, tone("copper"))
    (x, z), _, (cr, c0, c1), (u0, u1, y0, y1) = LAMP
    ring(s, [(.02, c0), (cr, c0), (cr, c1), (u0, y0), (u1, y1), (.02, y1 - .04)], 6, tone("copper"),
         at=(PUMP_AT[0] + x, z), tones=[tone("copper")] * 3 + [tone("lamp")] * 3)


def pump_steel(s):
    centre, half = BASE
    slab(s, pump(centre), half, tone("iron"))
    for z in TANK_Z:
        for x in CRADLE_X:
            slab(s, pump((x, .65, z)), (.14, .3, .8), tone("iron"))
        r, h = BOSS
        frustum(tank_frame(s, z), r, r, -1.95 - h, -1.8, 6, tone("iron"))
    ring(s, RISER, 6, tone("iron"), at=(PUMP_AT[0] + RISER_AT[0], RISER_AT[1]))
    (x, z), (pr, p0, p1), _, _ = LAMP
    frustum(s, pr, pr, p0, p1, 6, tone("iron"), at=(PUMP_AT[0] + x, z))
    for g in GAUGES:
        _, br, fr, depth = g
        ring(gauge_frame(s, g), [(.02, -depth), (br, -depth), (br, .04), (fr, .04), (fr, 0.0), (.02, 0.0)], 8,
             tone("iron"), tones=[tone("iron")] * 2 + [tone("copper")] * 4)


def glass(s):
    for g in GAUGES:
        fr = g[2]
        ring(gauge_frame(s, g), [(.02, -.02), (fr - .01, -.02), (fr - .01, .02), (.02, .03)], 10, tone("face"))


def deck_clear(name, verts):
    r, top = DECK_CLEAR
    high = [v for v in verts if v[1] > top]
    wide = [v for v in verts if math.hypot(v[0], v[2]) > r]
    assert not high and not wide, (name, "deck clear", len(high), len(wide), (high + wide)[:3])
    print("LIFT_DECK_CLEAR", name, "max_y", round(max(v[1] for v in verts), 3),
          "max_r", round(max(math.hypot(v[0], v[2]) for v in verts), 3))


def pump_clear(name, verts):
    near = min(math.hypot(v[0], v[2]) for v in verts)
    assert near >= PUMP_CLEAR, (name, "pump clear", round(near, 3), PUMP_CLEAR)
    print("LIFT_PUMP_CLEAR", name, "nearest_to_axis", round(near, 3))


def export(name, surfaces, out_dir, check, budget=LANDMARK, tag="LIFT", size=None):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    for part, slot, smooth, build in surfaces:
        s = kit.Surface(part, slot, smooth=smooth)
        build(s)
        check(name + ":" + part, s.verts)
        s.finish(root)
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
    export(NAME + "_deck", [("Plate", "enamel", False, deck_enamel), ("Column", "steel", False, deck_steel)], d, deck_clear)
    export(NAME + "_pump", [("Pump", "enamel", False, pump_enamel), ("Frame", "steel", False, pump_steel)], d, pump_clear)
    export(NAME + "_glass", [("Faces", "glass", True, glass)], d, pump_clear)


if __name__ == "__main__":
    main()
