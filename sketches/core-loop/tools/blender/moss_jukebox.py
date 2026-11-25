"""Headless recipe for Moss's bay jukebox in the approved FLUX.1 schnell concept picture
artifacts/local/alpha/push/w12/concepts/boards/alpha-props/moss_jukebox_101.png (board alpha-props, seed 101): an arched
retro cabinet face on, a cream outer arch over a lit band and a tan front, a mesh speaker dome with a bulb, a display
window between two speaker grilles, an oval teal panel with a lattice, and black feet.

Same route as lantern_beacon.py: kit.Surface parts, COLOR_0 vertex colour, materials named for dig_scenery.gd SLOTS.
Class "prop" (270 tris, 610 verts, 1 draw per GLB), so each slot is its own GLB, all at one origin:
  moss_jukebox_cabinet.glb  enamel: arch body, amber band, tan front, teal pillar strips, dome, bulb, display row,
                            oval panel and bezel, keystone
  moss_jukebox_trim.glb     steel: copper pillar bands, keystone frame, dome arc, display plate, knobs, lattice, patch
  moss_jukebox_feet.glb     elastomer: two rubber bumper feet and the kick strip between them
No slot emits, so the bulb and the amber band are vertex colour only (today's grille glows, bay.gd:535).

Footprint (src/world/bay.gd:534): the cabinet box is 1.8 x 2.6 x 1.2 m with its floor at y 0; origin at the cabinet's
floor centre; the face is on -z, where today's glowing grille sits (bay.gd:535), toward the pad and the anchor.

Lore (research/lore-makers-2026-10-09.md): the picture's brass trim is COPPER; Switchback Enclaves construction
(compact, felt-lined, serviceable): the cabinet stands on rubber bumper feet with a rubber kick strip, and the oval panel
is a bolted service hatch (detail1 adds its thumb screws). Repairer's hand: a riveted copper patch on the left pillar.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/moss_jukebox.py [-- --out-dir DIR]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lantern_beacon import kit, common
import polish

MODELS = kit.SKETCH / "assets/models"
PROP = [500, 610, 1]
FINISH = {"Cabinet": {"bevel": .04}, "Trim": {"bevel": .02}, "Feet": {"bevel": 0, "subsurf": 1}, "Detail1": {"bevel": 0}, "Detail2": {"bevel": 0}}


def polish_on():
    polish.enable(bevel=.03, bevel_min=.15, **kit.BAKE)
    kit.FINISH.update(FINISH)


NAME = "moss_jukebox"

TONES = {
    "arch": "e6d9b8",
    "band": "amber",
    "front": "sandstone",
    "panel": "petrol",
    "bezel": "e6d9b8",
    "dome": "amber",
    "bulb": "e6d9b8",
    "window": "amber",
    "drawer": "sandstone",
    "speaker": "charcoal",
    "keystone": "oxide",
    "copper": "copper",
    "feet": "charcoal",
    "mesh": "d2c5a5",
    "groove": "2a3231",
}

W, H, D = 1.8, 2.6, 1.2
ARCH_R = .88
ARCH_C = H - ARCH_R
BAND_R, FRONT_R = .72, .6
BODY_Y0 = .2
SEGS = 8
Z_BODY = (-.45, .6)
Z_BAND, Z_FRONT, Z_STRIP = -.48, -.5, -.51
STRIP = (.6, .68, .46, 1.78)
DOME = (ARCH_C - .03, .42, .08)
BULB = (DOME[0] + .33, .065, .055)
PLATE = (.48, 1.27, 1.66)
WINDOW = (.17, 1.44, 1.62)
DRAWER = (.17, 1.3, 1.41)
SPEAKER = (.22, .44, 1.33, 1.6)
OVAL = (.85, .42, .46, .05)
BANDS = [1.71, 1.59, 1.46]
KEYSTONE = [(-.15, 2.47), (.15, 2.47), (.09, 2.22), (-.09, 2.22)]
KNOBS = [(-.34, 1.3), (0.0, 1.27), (.34, 1.3), (0.0, 1.06)]
LATTICE = [((-.24, 1.25), (0, 1.06)), ((.24, 1.25), (0, 1.06)), ((0, 1.06), (-.2, .72)), ((-.2, .72), (0, .42)),
           ((0, .42), (.2, .72)), ((.2, .72), (0, 1.06))]
PATCH = (-.86, -.74, .58, .8)
FOOT = (.715, .185, .6, .46)
KICK = (.53, .08, .22)
SOCKETS = {"socket_grille": [0, DOME[0], -.58]}
SIZE = {"cabinet": [1.76, 2.4, 1.185], "trim": [1.8, 2.17, 1.18], "feet": [1.8, .46, 1.2]}


def tone(name):
    return common.srgb(TONES[name])


def prism(s, outline, z0, z1, color, back=True):
    n = len(outline)
    verts = [(x, y, z) for z in (z0, z1) for x, y in outline]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n))]
    if back:
        faces.append(tuple(reversed(range(n, 2 * n))))
    s.add(verts, faces, color)


def tomb(r, y0, cy, segs=SEGS):
    return [(-r, y0), (r, y0)] + [(r * math.cos(math.pi * i / segs), cy + r * math.sin(math.pi * i / segs))
                                  for i in range(segs + 1)]


def rect(x0, x1, y0, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def oval(cy, hw, hh, n=10):
    return [(hw * math.sin(math.tau * i / n), cy - hh * math.cos(math.tau * i / n)) for i in range(n)]


def half_dome(s, cy, r, bulge, z0, segs, color):
    ring0 = [(r * math.cos(math.pi * i / segs), cy + r * math.sin(math.pi * i / segs), z0) for i in range(segs + 1)]
    ring1 = [(.6 * r * math.cos(math.pi * i / segs), cy + .6 * r * math.sin(math.pi * i / segs), z0 - .8 * bulge)
             for i in range(segs + 1)]
    apex = (0.0, cy, z0 - bulge)
    m = segs + 1
    faces = [(i, i + 1, m + i + 1, m + i) for i in range(segs)] + [(m + i, m + i + 1, 2 * m) for i in range(segs)]
    faces.append((0, m, 2 * m, 2 * m - 1, m - 1))
    s.add(ring0 + ring1 + [apex], faces, color)


def bead(s, c, r, h, color, k=6):
    x, y, z = c
    ring = [(x + r * math.cos(math.tau * i / k), y + r * math.sin(math.tau * i / k), z) for i in range(k)]
    faces = [(i, (i + 1) % k, k) for i in range(k)] + [((i + 1) % k, i, k + 1) for i in range(k)]
    s.add(ring + [(x, y, z - h), (x, y, z + h)], faces, color)


def cabinet(s):
    prism(s, tomb(ARCH_R, BODY_Y0, ARCH_C), Z_BODY[0], Z_BODY[1], tone("arch"))
    prism(s, tomb(BAND_R, BODY_Y0, ARCH_C), Z_BAND, Z_BODY[0] + .02, tone("band"), back=False)
    prism(s, tomb(FRONT_R, BODY_Y0, ARCH_C), Z_FRONT, Z_BAND + .02, tone("front"), back=False)
    x0, x1, y0, y1 = STRIP
    for k in (-1, 1):
        prism(s, rect(*sorted((k * x0, k * x1)), y0, y1), Z_STRIP, Z_FRONT + .02, tone("panel"), back=False)
    cy, r, bulge = DOME
    half_dome(s, cy, r, bulge, Z_FRONT - .005, 6, tone("dome"))
    by, br, bh = BULB
    bead(s, (0.0, by, Z_FRONT - .03), br, bh, tone("bulb"))
    zp = -.525
    hw, w0, w1 = WINDOW
    prism(s, rect(-hw, hw, w0, w1), zp - .02, zp + .01, tone("window"), back=False)
    hw, d0, d1 = DRAWER
    prism(s, rect(-hw, hw, d0, d1), zp - .02, zp + .01, tone("drawer"), back=False)
    sx0, sx1, sy0, sy1 = SPEAKER
    for k in (-1, 1):
        prism(s, rect(*sorted((k * sx0, k * sx1)), sy0, sy1), zp - .015, zp + .01, tone("speaker"), back=False)
    ocy, ohw, ohh, bez = OVAL
    prism(s, oval(ocy, ohw + bez, ohh + bez), -.525, Z_FRONT + .01, tone("bezel"), back=False)
    prism(s, oval(ocy, ohw, ohh), -.54, -.52, tone("panel"), back=False)
    prism(s, KEYSTONE, -.53, Z_BODY[0] + .02, tone("keystone"), back=False)


def bar(s, a, b, w, z0, z1, color, ends=True):
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln * w / 2, dx / ln * w / 2
    outline = [(a[0] - nx, a[1] - ny), (b[0] - nx, b[1] - ny), (b[0] + nx, b[1] + ny), (a[0] + nx, a[1] + ny)]
    verts = [(x, y, z) for z in (z0, z1) for x, y in outline]
    faces = [(0, 1, 2, 3), (0, 4, 5, 1), (2, 6, 7, 3)]
    if ends:
        faces += [(1, 5, 6, 2), (3, 7, 4, 0)]
    s.add(verts, faces, color)


def arc_strip(s, cy, r0, r1, segs, z0, z1, color):
    for i in range(segs):
        a0, a1 = math.pi * i / segs, math.pi * (i + 1) / segs
        p = [(r * math.cos(a), cy + r * math.sin(a)) for r in (r0, r1) for a in (a0, a1)]
        v = [(x, y, z) for z in (z0, z1) for x, y in p]
        s.add(v, [(0, 1, 3, 2), (2, 3, 7, 6), (1, 0, 4, 5)], color)


def knob(s, x, y, z0, r, h, color, k=6):
    ring = [(x + r * math.cos(math.tau * i / k), y + r * math.sin(math.tau * i / k)) for i in range(k)]
    prism(s, ring, z0 - h, z0, color, back=False)


def trim(s):
    c = tone("copper")
    for y in BANDS:
        for k in (-1, 1):
            x0, x1 = k * .58, k * (W / 2)
            v = [(x, yy, z) for z in (-.53, .6) for x, yy in rect(*sorted((x0, x1)), y - .035, y + .035)]
            inner = (0, 3, 7, 4) if k > 0 else (1, 2, 6, 5)
            faces = [f for f in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (3, 2, 6, 7), (1, 5, 6, 2), (0, 3, 7, 4)]
                     if f != inner]
            s.add(v, faces, c)
    for k in (-1, 1):
        bar(s, (k * .21, 2.575), (k * .1, 2.2), .07, -.56, -.5, c)
    bar(s, (-.24, 2.55), (.24, 2.55), .06, -.56, -.5, c)
    cy, r, _ = DOME
    arc_strip(s, cy, r, r + .06, 6, -.55, Z_FRONT + .01, c)
    hw, y0, y1 = PLATE
    prism(s, rect(-hw, hw, y0, y1), -.515, Z_FRONT + .01, c, back=False)
    bar(s, (-hw - .02, DOME[0] - .02), (hw + .02, DOME[0] - .02), .06, -.55, -.51, c)
    for x, y in KNOBS:
        knob(s, x, y, -.53, .045, .05, c)
    for a, b in LATTICE:
        bar(s, a, b, .035, -.555, -.535, c, ends=False)
    x0, x1, y0, y1 = PATCH
    prism(s, rect(x0, x1, y0, y1), -.47, Z_BODY[0] + .01, c, back=False)


def feet(s):
    c = tone("feet")
    cx, hw, hd, top = FOOT
    for k in (-1, 1):
        x = k * cx

        def ring(y, inset):
            w, d, ch = hw - inset, hd - inset, .08
            pts = [(-w + ch, -d), (w - ch, -d), (w, -d + ch), (w, d - ch), (w - ch, d), (-w + ch, d), (-w, d - ch),
                   (-w, -d + ch)]
            return [(x + px, y, pz) for px, pz in pts]
        rings = [ring(0.0, .04), ring(.06, 0.0), ring(top, 0.0)]
        n = 8
        faces = [(r * n + i, r * n + (i + 1) % n, (r + 1) * n + (i + 1) % n, (r + 1) * n + i) for r in range(2) for i in range(n)]
        faces += [tuple(reversed(range(n))), tuple(range(2 * n, 3 * n))]
        s.add([v for rg in rings for v in rg], faces, c)
    kx, k0, k1 = KICK
    s.box((2 * kx + .04, k1 - k0, 1.1), (0.0, (k0 + k1) / 2, -.01), c)


def export(name, part, slot, build, size, sockets, out_dir, budget=PROP, tag="JUKEBOX"):
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name)
    s = kit.Surface(part, slot, smooth=False)
    build(s)
    s.finish(root)
    for socket, loc in sockets.items():
        kit.empty(socket, loc, root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    got = metrics["bounds"]["size"]
    print(tag + "_SIZE", name, [round(v, 3) for v in got], metrics["bounds"], metrics["triangles"], metrics["vertices"],
          metrics["draws"])
    assert all(metrics[k] <= cap for k, cap in zip(["triangles", "vertices", "draws"], budget)), (name, metrics, budget)
    assert metrics["materials"] == [slot], (name, metrics["materials"])
    assert all(abs(a - b) <= .03 * b for a, b in zip(got, size)), (name, got, size)
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
    export(NAME + "_cabinet", "Cabinet", "enamel", cabinet, SIZE["cabinet"], SOCKETS, d)
    export(NAME + "_trim", "Trim", "steel", trim, SIZE["trim"], {}, d)
    export(NAME + "_feet", "Feet", "elastomer", feet, SIZE["feet"], {}, d)


if __name__ == "__main__":
    main()
