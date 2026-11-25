"""Dam park dressing kit (Dressing lane proof: the dam writer extends this recipe).

The dam crew was a survey-and-sluice outfit: timber and concrete works, canvas and chain,
tools left where the last shift dropped them.

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/dam.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kit
from kit import C, mix, tint

K = kit.Kit("dam", polish_opts={"detail": 1})


class Sc:
    """Scales a Prop's drawing calls by k, so kinds are authored in real metres and built at
    chunky storybook size (about 1.5 times real)."""

    def __init__(self, p, k=1.5, lite=False):
        self.p, self.k, self.rng, self.lite = p, k, p.rng, lite

    def _v(self, a):
        return tuple(x * self.k for x in a)

    def _kw(self, kw, ico=False):
        if self.lite and not ico:
            st = kw.get("style")
            if st is None:
                st = "round" if kw.pop("_default_round", False) else "hard"
            kw["style"] = {"hard_smooth": "hard", "round": "flat"}.get(st, st)
        elif self.lite and kw.get("style") is None:
            pass
        if kw.get("jit"):
            kw["jit"] = kw["jit"] * self.k
        if kw.get("r2") is not None:
            kw["r2"] = kw["r2"] * self.k
        if kw.get("h") is not None:
            kw["h"] = kw["h"] * self.k
        return kw

    def box(self, size, loc, color, **kw):
        return self.p.box(self._v(size), self._v(loc), color, **self._kw(kw))

    def cyl(self, radius, depth, loc, color, **kw):
        kw.setdefault("style", "hard")
        if self.lite:
            kw["segs"] = min(kw.get("segs", 10), 10)
        return self.p.cyl(radius * self.k, depth * self.k, self._v(loc), color, **self._kw(kw))

    def rod(self, a, b, radius, color, **kw):
        kw.setdefault("style", "round")
        return self.p.rod(self._v(a), self._v(b), radius * self.k, color, **self._kw(kw))

    def beam(self, a, b, width, color, **kw):
        return self.p.beam(self._v(a), self._v(b), width * self.k, color, **self._kw(kw))

    def uv(self, radius, loc, color, **kw):
        kw.setdefault("style", "round")
        return self.p.uv(radius * self.k, self._v(loc), color, **self._kw(kw))

    def ico(self, radius, loc, color, **kw):
        return self.p.ico(radius * self.k, self._v(loc), color, **self._kw(kw, ico=True))

    def ring(self, r_in, r_out, depth, loc, color, **kw):
        return self.p.ring(r_in * self.k, r_out * self.k, depth * self.k, self._v(loc), color, **self._kw(kw))

    def prism(self, outline, depth, loc, color, **kw):
        return self.p.prism([(x * self.k, y * self.k) for x, y in outline], depth * self.k,
                            self._v(loc), color, **self._kw(kw))

    def torus(self, big, small, loc, color, **kw):
        kw.setdefault("style", "round")
        if self.lite:
            kw["major"] = min(kw.get("major", 12), 12)
            kw["minor"] = min(kw.get("minor", 6), 5)
        return self.p.torus(big * self.k, small * self.k, self._v(loc), color, **self._kw(kw))

    def chain(self, a, b, color, link=0.14, radius=0.02, sag=0.1, **kw):
        return self.p.chain(self._v(a), self._v(b), color, link=link * self.k, radius=radius * self.k,
                            sag=sag * self.k, **kw)


@K.kind("gate_wheelhouse", hero=True, tags=["machine"], variants="ab",
        story="Sluice crew's wheelhouse: a big hand wheel chained shut, petrol-enamel walls on a concrete plinth.")
def gate_wheelhouse(p, v, rng):
    p = Sc(p, 1.8)
    sag = 0.38 if v == "b" else 0.0
    p.box((4.0, 3.2, 0.4), (0, 0, 0.2), C["concrete"], style="hard_smooth")
    p.box((4.1, 0.5, 0.18), (0, -1.55, 0.09), C["concrete_light"], style="hard_smooth")
    for x, y in ((-1.9, -1.5), (1.9, 1.5), (1.95, -1.4)):
        p.box((0.28, 0.28, 0.14), (x, y, 0.45), mix(C["concrete"], C["concrete_stain"], 0.5), rot=(0, 0, rng.uniform(0, 1.5)))
    for x in (-1.75, 1.75):
        for y in (-1.3, 1.3):
            p.beam((x, y, 0.4), (x, y, 2.35), 0.2, tint(mix(PETROL, "charcoal", 0.3), rng, 0.05))
    for i in range(16):
        x = -1.58 + i * 0.21
        p.box((0.2, 0.12, 1.9), (x, 1.3, 1.35), tint(PETROL, rng), jit=0.004)
    for s in (-1, 1):
        for i in range(11):
            y = -1.05 + i * 0.21
            if v == "b" and s == 1 and i in (3, 4):
                continue
            p.box((0.12, 0.2, 1.9), (s * 1.75, y, 1.35), tint(mix(PETROL, "concrete_stain", 0.3) if s == 1 else PETROL, rng), jit=0.004)
    for i in range(16):
        x = -1.58 + i * 0.21
        door = -0.62 <= x <= 0.1
        p.box((0.2, 0.12, 1.9 if not door else 1.75), (x, -1.3, 1.35 if not door else 1.275),
              tint(mix(PETROL, "bone", 0.2) if door else PETROL, rng), jit=0.004)
    for z in (0.7, 1.9):
        p.beam((-1.78, -1.38, z), (1.78, -1.38, z), 0.1, mix(PETROL, "charcoal", 0.3), h=0.08)
    rise, half, rows, segs = 0.75, 1.85, 8, 6
    theta = math.atan2(rise, half)
    seg_len = 3.9 / segs
    for s in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            for j in range(segs):
                if v == "b" and s == -1 and j in (2, 3) and r >= 5:
                    continue
                x = -1.95 + (j + 0.5) * seg_len
                dip = sag * (1 - (x / 1.95) ** 2) * (0.35 + 0.65 * t)
                slope = math.atan2(sag * 2 * x / 1.95 ** 2, 1.0) if sag else 0.0
                p.box((seg_len + 0.02, 0.5, 0.07),
                      (x, s * half * (1 - t), 2.35 + rise * t - dip),
                      tint(C["timber_grey"] if (r + j) % 3 else C["timber_dark"], rng, 0.07),
                      rot=(-s * theta, slope, 0), jit=0.005)
    for j in range(5):
        x = -1.9 + j * 0.95
        dip = sag * (1 - (x / 1.95) ** 2) * 0.4
        for s in (-1, 1):
            p.beam((x, s * half, 2.3), (x, 0, 2.3 + rise - dip - 0.05), 0.11, C["timber_dark"], h=0.09)
    p.beam((-1.95, 0, 2.3 + rise - 0.02), (1.95, 0, 2.3 + rise - 0.02 - (sag * 0.4)), 0.14, C["timber_dark"])
    if v == "b":
        p.ico(0.8, (-0.15, -0.5, 2.55), C["canvas_dark"], scale=(1.5, 1.0, 0.22), rot=(0.4, 0, 0.1), style="soft")
        p.box((1.6, 0.26, 0.07), (-0.6, -1.95, 0.1), C["timber_grey"], rot=(0, 0, 0.35))
        p.box((1.2, 0.24, 0.07), (0.3, -2.1, 0.22), C["timber_dark"], rot=(0.05, 0, -0.5))
        p.box((1.0, 0.22, 0.07), (-1.8, -1.85, 0.07), C["timber_pale"], rot=(0, 0, 1.2))
    else:
        p.ico(0.45, (-1.3, -1.7, 0.3), C["canvas"], scale=(1.0, 0.8, 0.7), style="soft")
    wx, wy, wz, wr = 0.95, -1.72, 1.35, 0.78
    face = (math.pi / 2, 0, 0)
    p.box((0.34, 0.3, 1.5), (wx, -1.5, 1.1), C["timber_dark"])
    p.cyl(0.09, 0.5, (wx, -1.65, wz), C["iron"], segs=8, rot=face)
    p.torus(wr, 0.075, (wx, wy, wz), OXIDE, rot=face, major=16, minor=6)
    p.cyl(0.2, 0.2, (wx, wy, wz), C["iron"], segs=10, rot=face, style="round")
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        p.rod((wx + 0.1 * math.cos(a), wy, wz + 0.1 * math.sin(a)),
              (wx + wr * math.cos(a), wy, wz + wr * math.sin(a)), 0.045, C["iron"], segs=6)
    for k in range(4):
        a = math.tau * k / 4 + 0.2
        p.cyl(0.06, 0.28, (wx + (wr + 0.02) * math.cos(a), wy - 0.05, wz + (wr + 0.02) * math.sin(a)),
              C["timber_dark"], segs=6, rot=face)
    ring_x = wx - 0.05
    p.ring(0.05, 0.12, 0.08, (ring_x, -1.85, 0.5), C["iron"], segs=8, rot=(math.pi / 2, 0, 0))
    if v == "a":
        p.chain((wx, wy - 0.12, wz + wr), (ring_x, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.3)
        p.chain((wx + wr, wy - 0.12, wz), (ring_x + 0.1, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.35)
    else:
        p.chain((wx, wy - 0.12, wz + wr), (ring_x + 0.4, -2.3, 0.1), C["cable"], link=0.12, radius=0.022, sag=0.3)
        p.chain((wx + wr, wy - 0.12, wz), (ring_x, -1.85, 0.55), C["cable"], link=0.12, radius=0.022, sag=0.3)
    p.box((0.22, 0.14, 0.26), (wx + 0.02, wy - 0.18, wz + 0.3), C["iron"], style="hard_smooth")
    p.cyl(0.07, 0.9, (-1.0, -2.35, 0.07), C["timber_dark"], segs=6, rot=(0, math.pi / 2, 0.3))
    p.cyl(0.13, 0.32, (-0.5, -2.2, 0.13), C["iron"], segs=8, rot=(0, math.pi / 2, 0.3), style="hard_smooth")


@K.kind("survey_tripod", hero=False, tags=["machine"], variants="ab", polish_opts={"detail": 1},
        story="A survey tripod knocked flat when the line broke, its plumb bob still on its cord.")
def survey_tripod(p, v, rng):
    p = Sc(p, 1.6, lite=True)
    leg_r = 0.045
    if v == "a":
        head = (0.0, 0.0, 0.24)
        feet = [(1.35, 0.15, 0.06), (0.4, 1.0, 0.07), (0.35, -0.55, 0.85)]
    else:
        head = (-0.7, 0.0, 0.2)
        feet = [(0.8, 0.14, 0.06), (0.75, -0.14, 0.06), (0.7, 0.0, 0.2)]
    for k, f in enumerate(feet):
        p.rod(head, f, leg_r, tint(C["timber"], rng), segs=6, r2=leg_r * 0.8)
        p.cyl(0.065, 0.14, f, C["iron"], segs=6, r2=0.03, style="hard_smooth",
              rot=(0, math.pi / 2 + (0.4 if k == 2 else 0.1), 0))
        mid = tuple(head[i] + (f[i] - head[i]) * 0.3 for i in range(3))
        p.box((0.1, 0.1, 0.1), mid, C["iron_light"], rot=(0.2 * k, 0.4, 0.3 * k))
    p.cyl(0.15, 0.1, head, C["iron"], segs=10, style="hard_smooth", rot=(0.3, 0.1, 0.4))
    p.cyl(0.04, 0.2, (head[0], head[1], head[2] + 0.12), C["iron_light"], segs=6, rot=(0.3, 0.1, 0.4))
    tx, ty = (-0.45, -0.35) if v == "a" else (0.0, -0.45)
    p.cyl(0.075, 0.55, (tx, ty, 0.1), C["canvas_dark"], segs=10, rot=(0, math.pi / 2, 0.3), style="hard_smooth")
    p.cyl(0.1, 0.1, (tx - 0.3, ty - 0.09, 0.1), C["iron"], segs=10, rot=(0, math.pi / 2, 0.3), style="hard_smooth")
    p.cyl(0.07, 0.08, (tx + 0.3, ty + 0.09, 0.1), C["verdigris"], segs=8, rot=(0, math.pi / 2, 0.3), style="hard_smooth")
    bx, by = (0.55, 0.45) if v == "a" else (-0.2, 0.55)
    p.cyl(0.11, 0.24, (bx, by, 0.11), C["charcoal"], segs=10, r2=0.02, rot=(0, math.pi / 2, 0.8), style="hard_smooth")
    p.uv(0.11, (bx - 0.07, by - 0.07, 0.11), C["iron"], scale=(1, 1, 0.95), u=10, v=6, style="round")
    pts = [(bx + 0.1, by + 0.1, 0.03), (bx + 0.3, by + 0.22, 0.03), (bx + 0.35, by + 0.5, 0.03),
           (bx + 0.12, by + 0.62, 0.03), (head[0] + 0.1, head[1] + 0.3, head[2] - 0.12)]
    for a, b in zip(pts, pts[1:]):
        p.rod(a, b, 0.016, C["cable"], segs=6)
    if v == "a":
        p.ico(0.22, (-0.9, 0.55, 0.12), C["canvas"], scale=(1.0, 0.8, 0.6), style="soft")
    else:
        p.ico(0.2, (0.2, -0.85, 0.11), C["canvas_dark"], scale=(1.1, 0.8, 0.55), style="soft")


V = kit.Vector if hasattr(kit, "Vector") else None
from mathutils import Euler, Matrix, Vector

PETROL, OXIDE = "365754", "9b513a"
DUSK_BLUE = mix(PETROL, "bone", 0.35)
FLOWER = "c9b45e"
SILVER_LEAF = "8f9a78"


def wheel(p, x, y, zc, r, w, rng, rim="iron_light"):
    """Soft-toy tyre with a hub, axis along X. Lateral sign decides which way the hub faces."""
    face = (0, math.pi / 2, 0)
    p.torus(r * 0.7, r * 0.3, (x, y, zc), "charcoal", rot=face, major=16, minor=6)
    p.cyl(r * 0.52, w, (x, y, zc), rim, segs=12, rot=face, style="round")
    p.cyl(r * 0.2, w * 1.5, (x, y, zc), "iron", segs=8, rot=face, style="round")


def bush(p, x, y, r, rng, leaf=SILVER_LEAF, flowers=True, n=9, h=1.0):
    """Brittlebush: a mound of silver-green leaf blobs with flower stems."""
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(0.2, 0.9)
        zc = r * 0.35 + rng.uniform(0, r * 0.35) * h
        p.ico(r * rng.uniform(0.35, 0.55), (x + d * math.cos(a), y + d * math.sin(a), zc),
              tint(leaf, rng, 0.12), scale=(1.1, 0.8, 0.55 * h), rot=(0, 0, a), style="round")
    if flowers:
        for k in range(5):
            a = rng.uniform(0, math.tau)
            d = r * rng.uniform(0.1, 0.8)
            top = (x + d * math.cos(a) * 1.1, y + d * math.sin(a) * 1.1, r * (1.0 + 0.5 * rng.random()) * h)
            p.rod((x + d * math.cos(a) * 0.5, y + d * math.sin(a) * 0.5, r * 0.5), top, 0.012, "leaf_dark", segs=4)
            p.ico(r * 0.1, top, FLOWER, style="flat", subdiv=1)


def tuft(p, x, y, r, rng, col="dry_grass", n=7, h=0.4):
    for k in range(n):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(0.0, 0.8)
        b = (x + d * math.cos(a), y + d * math.sin(a), 0.0)
        t = (b[0] + 0.12 * math.cos(a) * r, b[1] + 0.12 * math.sin(a) * r, h * rng.uniform(0.6, 1.2))
        p.rod(b, t, 0.02, tint(col, rng, 0.1), segs=4, r2=0.006, style="flat")


def rock(p, x, y, r, rng, col="sandstone", sc=(1.2, 1.0, 0.55)):
    p.ico(r, (x, y, r * sc[2] * 0.8), tint(col, rng, 0.06), scale=sc, rot=(0, 0, rng.uniform(0, 3)), style="round")


@K.kind("mixer_wreck", hero=True, tags=["machine"], variants="abc",
        story="A concrete mixer truck from the last pour: drum tipped, left where the crew walked off.")
def mixer_wreck(p, v, rng):
    p = Sc(p, 1.1)
    dz = -0.75 if v == "c" else 0.0
    p.box((1.5, 7.6, 0.34), (0, 0.3, 0.88 + dz), "iron", style="hard_smooth")
    p.box((2.1, 7.0, 0.1), (0, 0.4, 1.12 + dz), "charcoal", style="hard_smooth")
    for y in (-2.7, 1.5, 2.85):
        p.cyl(0.11, 2.2, (0, y, 0.6 + dz), "iron", segs=8, rot=(0, math.pi / 2, 0), style="round")
    for y in (-2.7, 1.5, 2.85):
        for sx in (-1, 1):
            if v == "b" and sx == -1 and y == -2.7:
                p.cyl(0.3, 0.3, (sx * 1.12, y, 0.6), "iron_light", segs=10, rot=(0, math.pi / 2, 0), style="round")
                continue
            wheel(p, sx * 1.12, y, 0.6 + dz, 0.62, 0.42, rng)
    if v == "b":
        p.torus(0.45, 0.2, (-3.5, -2.2, 0.2), "charcoal", rot=(0.05, 0.08, 0), major=16, minor=6)
        p.cyl(0.3, 0.12, (-3.5, -2.2, 0.18), "iron_light", segs=12, style="round")
        p.box((1.3, 0.28, 0.24), (-1.1, -2.55, 0.12), "timber_grey")
        p.box((0.28, 1.3, 0.24), (-1.0, -2.6, 0.36), "timber_dark")
    cab = PETROL if v != "c" else mix(PETROL, "concrete_stain", 0.3)
    cz = 2.15 + dz
    p.box((2.4, 2.1, 1.75), (0, -2.95, cz), cab, style="hard_smooth")
    p.box((2.5, 2.2, 0.14), (0, -2.95, cz + 0.95), "iron_light", style="hard_smooth")
    p.box((2.5, 0.28, 0.4), (0, -4.1, 1.15 + dz), "iron", style="hard_smooth")
    p.box((2.0, 0.1, 0.34), (0, -4.0, 1.55 + dz), "charcoal", style="hard_smooth")
    for sx in (-1, 1):
        p.box((0.1, 1.2, 0.7), (sx * 1.22, -3.1, cz + 0.3), "cable", style="hard_smooth")
        p.box((0.5, 1.0, 0.1), (sx * 1.2, -2.7, 1.55 + dz), "iron", style="hard_smooth")
    if v == "b":
        p.box((2.0, 0.08, 0.1), (0, -4.0, cz + 0.62), "iron_light")
        p.box((2.0, 0.08, 0.1), (0, -4.0, cz + 0.02), "iron_light")
        bush(p, 0, -3.5, 0.9, rng, n=12, h=1.2)
        p.ico(0.5, (0.2, -4.15, cz + 0.3), SILVER_LEAF, scale=(1.4, 0.7, 0.8), style="round")
    else:
        p.box((2.0, 0.08, 0.72), (0, -4.0, cz + 0.32), "cable", style="hard_smooth")
        p.box((2.0, 0.1, 0.08), (0, -4.0, cz + 0.7), "iron_light")
    p.cyl(0.38, 1.4, (1.1, 0.0, 1.3 + dz), "iron_light", segs=10, rot=(math.pi / 2, 0, 0), style="round")
    for y in (2.2,):
        for sx in (-1, 1):
            p.box((0.06, 0.6, 0.5), (sx * 1.35, y + 1.1, 0.5 + dz), "charcoal", style="fine")
    tilt = math.radians(26)
    d = Vector((0, math.cos(tilt), math.sin(tilt)))
    base = Vector((0, -1.1, 2.6 + dz))
    u = d.cross(Vector((1, 0, 0))).normalized()
    w = d.cross(u).normalized()

    def ax(t, ang=None, r=0.0):
        o = base + d * t
        if ang is not None:
            o = o + (u * math.cos(ang) + w * math.sin(ang)) * r
        return tuple(o)

    def rad(t):
        if t < 1.2:
            return 0.5 + (1.25 - 0.5) * t / 1.2
        if t < 3.2:
            return 1.25 + 0.08 * math.sin((t - 1.2) / 2.0 * math.pi)
        return 1.25 - (1.25 - 0.7) * (t - 3.2) / 1.6
    drum = "concrete_light" if v != "c" else mix("concrete_light", "concrete_stain", 0.4)
    p.rod(ax(0), ax(1.2), 0.5, drum, segs=14, r2=1.25)
    p.rod(ax(1.2), ax(3.2), 1.25, drum, segs=14, r2=1.25)
    p.rod(ax(3.2), ax(4.8), 1.25, mix(drum, "concrete_stain", 0.25), segs=14, r2=0.7)
    p.cyl(0.55, 0.2, ax(4.78), "concrete_dark", segs=14, rot=(math.pi / 2 - tilt + math.pi, 0, 0), style="round")
    for t in (1.25, 3.15):
        p.torus(rad(t) + 0.04, 0.09, ax(t), "iron", rot=(-tilt, 0, 0), major=20, minor=6)
    for ph in (0.0, math.pi * 2 / 3, math.pi * 4 / 3):
        pts = [ax(0.7 + t * 0.28, ph + t * 0.7, rad(0.7 + t * 0.28) + 0.04) for t in range(12)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.07, "concrete_dark", segs=5, style="flat")
    p.box((1.4, 0.4, 1.0), (0, -0.4, 1.7 + dz), "iron", style="hard_smooth")
    p.beam((-0.9, 3.0, 1.2 + dz), (-0.6, 3.1, 2.6 + dz), 0.22, "iron")
    p.beam((0.9, 3.0, 1.2 + dz), (0.6, 3.1, 2.6 + dz), 0.22, "iron")
    for i, a in enumerate((0.3, 1.6, 2.7, 4.2)):
        o = ax(4.6, a, 0.55)
        p.ico(0.22 + 0.06 * (i % 2), (o[0], o[1], o[2]), "concrete", scale=(1, 1, 1.6), style="round")
    p.ico(0.55, (0.8, 5.2, 0.28 + dz * 0), "concrete", scale=(1.4, 1.1, 0.5), style="round")
    if v == "c":
        p.cyl(4.6, 0.75, (0, 0.5, -0.38 + dz * 0), mix("sandstone", "soil", 0.3), segs=18, r2=3.6, style="hard_smooth")
        for i in range(10):
            a = rng.uniform(0, math.tau)
            dd = rng.uniform(1.5, 3.4)
            p.ico(rng.uniform(0.8, 1.5), (dd * math.cos(a) * 0.8, 0.5 + dd * math.sin(a) * 1.1, 0.0),
                  tint("sandstone_dark", rng, 0.1), scale=(1.1, 1.0, 0.35), style="round")
        for y in (-4.4, 4.6):
            tuft(p, 2.2, y, 0.8, rng, n=8, h=0.7)
    else:
        tuft(p, -2.0, 4.8, 0.7, rng, n=6, h=0.5)
        if v == "b":
            bush(p, 3.0, 3.0, 0.8, rng, n=9)
            bush(p, -2.6, 4.4, 0.6, rng, n=7)


@K.kind("survey_tent", hero=True, tags=["soft"], variants="ab",
        story="The survey crew's wall tent on its timber platform: a cot, a table, a mug left on the ledger.")
def survey_tent(p, v, rng):
    p = Sc(p, 1.5)
    L, W, WH = 4.2, 3.4, 1.55
    for x in (-1.4, 0, 1.4):
        p.box((0.22, 4.9, 0.3), (x, 0.0, 0.15), "timber_dark")
    for i in range(18):
        y = -2.3 + i * 0.27
        if v == "b" and i in (4, 5, 12):
            continue
        p.box((4.0, 0.25, 0.1), (0, y, 0.35), tint("timber_grey" if v == "b" else "timber", rng, 0.08), jit=0.004)
    if v == "a":
        sag = 0.22
        wall = "canvas"
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.beam((sx * 1.7, sy * 2.05, 0.4), (sx * 1.7, sy * 2.05, 0.4 + WH), 0.1, "timber_dark")
        for sy in (-1, 1):
            p.beam((0, sy * 2.2, 0.4), (0, sy * 2.2, 2.7), 0.12, "timber_dark")
        p.beam((0, -2.2, 2.7), (0, 0, 2.7 - sag), 0.1, "timber_dark")
        p.beam((0, 0, 2.7 - sag), (0, 2.2, 2.7), 0.1, "timber_dark")
        for sx in (-1, 1):
            for j in range(4):
                y = -1.9 + j * 1.2
                p.box((0.1, 1.15, WH), (sx * 1.75, y + 0.3, 0.4 + WH / 2), tint(wall, rng, 0.04), style="soft")
        for i in range(3):
            p.box((1.2, 0.1, WH), (-1.15 + i * 1.15, 2.1, 0.4 + WH / 2), tint(wall, rng, 0.04), style="soft")
        for sx in (-1, 1):
            p.box((0.5, 0.1, WH), (sx * 1.45, -2.1, 0.4 + WH / 2), tint(wall, rng, 0.04), rot=(0, 0, sx * -0.3), style="soft")
            p.ico(0.2, (sx * 1.2, -2.2, 1.0), "canvas_dark", scale=(0.6, 0.6, 1.6), style="round")
        n = 9
        for s_ in (-1, 1):
            for j in range(n):
                y = -2.25 + (j + 0.5) * 4.5 / n
                zr = 2.7 - sag * (1 - (y / 2.25) ** 2) if abs(y) < 2.25 else 2.7
                slope = math.atan2(zr - 0.4 - WH, 1.85)
                p.box((2.0, 4.5 / n + 0.03, 0.09), (s_ * 0.92, y, 0.4 + WH + (zr - 0.4 - WH) * 0.5),
                      tint(wall if (j % 2) else "canvas_dark", rng, 0.04), rot=(0, s_ * -slope, 0), style="soft")
        for sx in (-1, 1):
            p.box((0.06, 1.9, 0.06), (-1.15 + sx * 0.35, 0.8, 0.65), "timber_dark", style="fine")
            for y in (-0.1, 1.7):
                p.beam((-1.15 + sx * 0.35, y, 0.4), (-1.15 + sx * 0.35, y, 0.7), 0.06, "timber_dark")
        p.box((0.75, 1.85, 0.07), (-1.15, 0.8, 0.72), "canvas_dark", style="soft")
        p.ico(0.42, (-1.15, 0.65, 0.88), "dry_grass", scale=(0.8, 1.7, 0.35), style="round")
        p.ico(0.17, (-1.15, 1.55, 0.88), "canvas", scale=(1.3, 0.9, 0.6), style="round")
        p.box((1.0, 0.8, 0.07), (0.8, 1.3, 0.95), "timber_pale")
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.beam((0.8 + sx * 0.42, 1.3 + sy * 0.32, 0.4), (0.8 + sx * 0.42, 1.3 + sy * 0.32, 0.95), 0.05, "timber_dark")
        p.box((0.45, 0.32, 0.04), (0.6, 1.25, 1.0), "canvas", style="fine")
        p.cyl(0.07, 0.12, (1.05, 1.5, 1.04), "canvas", segs=8, style="round")
        p.cyl(0.1, 0.18, (0.35, 1.55, 1.07), "iron_light", segs=8, style="round")
        p.box((0.5, 0.06, 0.45), (1.2, 2.0, 1.3), "timber_dark")
        for sx in (-1, 1):
            p.rod((sx * 1.9, -2.05, 0.45), (sx * 2.6, -2.7, 0.15), 0.03, "timber_grey", segs=5)
            p.cyl(0.06, 0.3, (sx * 2.6, -2.7, 0.15), "timber_dark", segs=6, rot=(0.3, 0.2, 0))
    else:
        p.beam((-0.9, -1.0, 0.4), (0.4, 0.4, 1.7), 0.1, "timber_dark")
        p.beam((0.9, 1.4, 0.4), (-0.4, 0.2, 1.1), 0.1, "timber_dark")
        p.beam((-1.7, 2.0, 0.4), (-1.6, 2.1, 1.3), 0.1, "timber_dark")
        p.box((0.75, 1.85, 0.07), (-1.2, 0.8, 0.52), "canvas_dark", rot=(0, 0.1, 0.2), style="soft")
        p.box((1.0, 0.8, 0.07), (0.9, 1.3, 0.55), "timber_pale", rot=(0.1, 0.25, 0.3))
        for i, (x, y, r_, sc) in enumerate(((0, 0.2, 1.4, (1.5, 1.4, 0.55)), (-1.1, 1.4, 0.9, (1.2, 1.5, 0.5)),
                                            (1.0, -0.6, 0.8, (1.3, 1.0, 0.45)), (0.3, 1.9, 0.7, (1.4, 1.0, 0.5)))):
            p.ico(r_, (x, y, 0.55 + r_ * sc[2] * 0.6), tint("canvas" if i % 2 else "canvas_dark", rng, 0.05),
                  scale=sc, rot=(0, 0, i), style="round")
        p.ico(0.5, (-0.4, -1.6, 0.5), "canvas_stain", scale=(1.6, 0.9, 0.4), style="round")
        p.cyl(0.07, 0.12, (1.55, 0.4, 0.46), "canvas", segs=8, style="round")
        p.cyl(0.1, 0.2, (1.4, -0.9, 0.51), "iron_light", segs=8, rot=(0, math.pi / 2, 0.4), style="round")
        for sx in (-1, 1):
            p.rod((sx * 1.9, -2.2, 0.4), (sx * 2.7, -2.0, 0.12), 0.03, "timber_grey", segs=5)
        for i, (x, y, r_) in enumerate(((-1.6, -2.7, 0.4), (1.9, -2.9, 1.0), (2.4, 0.2, -0.5), (-2.3, 1.0, 0.9))):
            p.box((1.3, 0.24, 0.07), (x, y, 0.1), tint("timber_grey", rng, 0.08), rot=(0, 0, r_), jit=0.004)
        for i in range(8):
            a = i / 8 * math.tau
            p.box((0.9, 0.14, 0.14), (1.9 * math.cos(a), 1.5 * math.sin(a) + 0.2, 0.55 + 0.3 * (i % 3)),
                  tint("canvas" if i % 2 else "canvas_dark", rng, 0.05), rot=(0.2, 0.3, a + 1.2), style="soft")
        for sx in (-1, 1):
            p.ico(0.16, (0.8 + sx * 0.14, -1.9, 0.5), "timber_dark", scale=(0.7, 1.4, 0.7), style="round")
        p.torus(0.28, 0.05, (-0.6, 2.4, 0.14), "canvas_stain", major=12, minor=5)
        p.torus(0.2, 0.05, (-0.6, 2.4, 0.22), "canvas_stain", major=12, minor=5)
        p.cyl(0.14, 0.2, (1.7, 1.9, 0.44), "iron_light", segs=10, style="round")
        for i in range(3):
            p.beam((-2.3 + i * 0.2, 2.3, 0.4), (-1.9 + i * 0.25, 2.1, 0.12), 0.09, "timber_dark")
        bush(p, 2.4, 1.5, 0.7, rng, n=8)
        tuft(p, -2.4, -2.4, 0.8, rng, n=7, h=0.6)


@K.kind("flood_staff", hero=False, tags=["sign"], variants="abc",
        story="A water-level staff on a concrete pier, its high-water line repainted higher three times.")
def flood_staff(p, v, rng):
    p = Sc(p, {"a": 0.853, "b": 0.836, "c": 1.5}[v], lite=True)
    lean = {"a": 0.0, "b": 0.16, "c": 1.5}[v]
    pivot = (0, 0, 0.35)
    ca, sa = math.cos(lean), math.sin(lean)

    def T(x, y, z):
        """Rotate about the base pivot (around Y) so the pier can lean or lie."""
        return (pivot[0] + x * ca + (z - pivot[2]) * sa, y, pivot[2] - x * sa + (z - pivot[2]) * ca) if True else None
    p.box((1.9, 1.5, 0.35), (0, 0, 0.175), "concrete_light" if v == "a" else "concrete", style="hard_smooth")
    H = 2.5
    ppos = T(0, 0, 0.35 + H / 2)
    p.box((0.62, 0.5, H), ppos, "concrete", rot=(0, lean, 0), style="hard_smooth")
    face = T(0, -0.27, 0.35 + H / 2)
    p.box((0.46, 0.06, H - 0.2), face, "canvas", rot=(0, lean, 0), style="hard")
    for i in range(1, 5):
        zc = 0.35 + 0.1 + i * 0.5
        p.box((0.46, 0.07, 0.12), T(0, -0.3, zc), "charcoal", rot=(0, lean, 0), style="hard")
        p.box((0.12, 0.07, 0.2), T(-0.08, -0.31, zc + 0.2), "charcoal", rot=(0, lean, 0), style="hard")
        if i % 2:
            p.box((0.12, 0.07, 0.2), T(0.08, -0.31, zc + 0.2), "charcoal", rot=(0, lean, 0), style="hard")
    for k, zc in enumerate((1.0, 1.65, 2.35)):
        p.box((0.5, 0.08, 0.1), T(0, -0.31, 0.35 + zc), mix("timber_pale", "concrete_stain", 0.2 * k), rot=(0, lean, 0), style="hard")
        p.box((0.28, 0.06, 0.1), T(-0.36, -0.29, 0.35 + zc + 0.12), "bone", rot=(0, lean, 0), style="hard")
    p.box((0.74, 0.62, 0.2), T(0, 0, 0.35 + H + 0.1), "concrete_light", rot=(0, lean, 0), style="hard_smooth")
    if v == "c":
        for k in range(3):
            p.ico(0.6 + 0.1 * k, (-1.0 - k * 0.9, rng.uniform(-0.5, 0.5), 0.1), "sandstone_dark", scale=(1.4, 1.0, 0.35), style="round")
        bush(p, 1.3, 0.6, 0.5, rng, n=7)
    elif v == "b":
        p.ico(0.5, (0.9, -0.8, 0.12), "sandstone_dark", scale=(1.5, 1.0, 0.4), style="round")
        tuft(p, -0.9, 0.7, 0.4, rng, n=6, h=0.4)
    else:
        rock(p, 1.2, 0.4, 0.3, rng, "sandstone_dark")


@K.kind("stencil_post", hero=False, tags=["sign"], variants="abc",
        story="Stencil post and chalk tally board; variant c is the Fleet docket marker, a pile of 'surplus concrete' slabs.")
def stencil_post(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    if v == "c":
        for i, (x, y, z, sx, sy, sz, r) in enumerate(((0, 0, 0.12, 1.5, 1.0, 0.24, 0.1), (0.1, -0.05, 0.34, 1.3, 0.9, 0.2, -0.25),
                                                      (-0.15, 0.1, 0.52, 1.0, 0.8, 0.16, 0.5), (0.9, 0.55, 0.1, 0.9, 0.7, 0.2, 0.9),
                                                      (-0.95, -0.4, 0.09, 0.8, 0.6, 0.18, -0.6))):
            p.box((sx, sy, sz), (x, y, z), tint("concrete" if i % 2 else "concrete_light", rng, 0.06),
                  rot=(0.05 * (i % 3 - 1), 0.07 * (i % 2), r), style="hard_smooth", jit=0.01)
        bx, by = 1.3, -0.9
        for dx in (-0.4, 0.4):
            p.box((0.14, 0.4, 0.3), (bx + dx, by, 0.15), "timber_dark")
        p.box((1.1, 0.1, 0.7), (bx, by - 0.05, 0.62), "charcoal", rot=(0.12, 0, 0.08), style="hard_smooth")
        p.box((1.14, 0.06, 0.06), (bx, by - 0.12, 0.98), "rust", rot=(0.12, 0, 0.08), style="flat")
        for g in range(2):
            for k in range(4):
                p.box((0.03, 0.03, 0.22), (bx - 0.35 + g * 0.4 + k * 0.06, by - 0.12, 0.68), "canvas", rot=(0.12, 0, 0.08), style="flat")
            p.box((0.26, 0.03, 0.03), (bx - 0.28 + g * 0.4, by - 0.12, 0.68), "canvas", rot=(0.12, 0, 0.28), style="flat")
        p.box((0.22, 0.04, 0.16), (bx + 0.3, by - 0.14, 0.4), "d9b44a", rot=(0.12, 0, 0.08), style="flat")
        tuft(p, -1.3, 0.7, 0.4, rng, n=5, h=0.4)
        return
    p.box((0.8, 0.8, 0.12), (0, 0, 0.06), "concrete_light", style="hard_smooth")
    p.box((0.52, 0.52, 0.9), (0, 0, 0.57), "concrete", style="hard_smooth")
    p.box((0.6, 0.6, 0.12), (0, 0, 1.08), "concrete_light", style="hard_smooth")
    tilt = {"a": 0.0, "b": 0.35}[v]
    pc = (0, -0.34, 0.75)
    rot = (0, 0, 0) if v == "a" else (0, tilt, 0.2)
    p.box((1.3, 0.1, 0.7), pc, "iron", rot=rot, style="hard_smooth")
    p.box((1.18, 0.12, 0.58), pc, "canvas", rot=rot, style="hard")
    for row, widths in enumerate(((0.9, 0.7), (0.5, 0.3, 0.3), (0.9,))):
        x = -sum(widths) / 2 - 0.1 * (len(widths) - 1) / 2
        for wd in widths:
            p.box((wd * 0.9, 0.14, 0.09), (pc[0] + x + wd * 0.45, pc[1] - 0.01, pc[2] + 0.18 - row * 0.17),
                  "charcoal", rot=rot, style="fine")
            x += wd + 0.1
    bx = 1.7
    for dx in (-0.55, 0.55):
        p.box((0.16, 0.5, 0.5), (bx + dx, 0, 0.25), "timber_dark")
    p.box((1.4, 0.12, 0.85), (bx, -0.08, 0.7), "charcoal", rot=(0.14, 0, 0.05 if v == "a" else 0.3), style="hard_smooth")
    marks = {"a": 4, "b": 2}[v]
    for g in range(marks):
        for k in range(4):
            p.box((0.03, 0.03, 0.26), (bx - 0.5 + g * 0.42 + k * 0.07, -0.16, 0.74), "canvas", rot=(0.14, 0, 0), style="flat")
        p.box((0.32, 0.03, 0.03), (bx - 0.4 + g * 0.42, -0.16, 0.74), "canvas", rot=(0.14, 0, 0.2), style="flat")
    p.cyl(0.04, 0.2, (bx + 0.7, -0.4, 0.04), "canvas", segs=6, rot=(0, math.pi / 2, 0.5), style="round")


@K.kind("lunch_pail", hero=False, tags=[], variants="abc",
        story="A crew member's pail, thermos and tin cup left on a flat rock, one lunch break never finished.")
def lunch_pail(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    p.cyl(0.85, 0.28, (0, 0, 0.14), "sandstone", segs=12, r2=0.75, style="hard_smooth", jit=0.02)
    p.ico(0.5, (-0.3, 0.3, 0.2), "sandstone_dark", scale=(1.3, 1.0, 0.5), style="round")
    tip = v == "b"
    px, py = (-0.15, -0.05)
    if not tip:
        p.cyl(0.26, 0.36, (px, py, 0.46), "iron_light", segs=12, r2=0.3, style="hard_smooth")
        p.cyl(0.31, 0.06, (px, py, 0.66), "iron", segs=12, style="hard_smooth")
        p.torus(0.28, 0.018, (px, py, 0.7), "iron", rot=(0, 0.2, 0), major=14, minor=4)
    else:
        p.cyl(0.26, 0.36, (px, py, 0.31), "iron_light", segs=12, r2=0.3, style="hard_smooth", rot=(0, math.pi / 2, 0.5))
        p.cyl(0.31, 0.06, (px + 0.45, py - 0.25, 0.08), "iron", segs=12, style="hard_smooth")
        p.torus(0.2, 0.018, (px - 0.1, py + 0.15, 0.1), "iron", major=12, minor=4)
        p.ico(0.2, (px - 0.35, py + 0.15, 0.32), "canvas_dark", scale=(1.3, 1.0, 0.5), style="round")
    tx, ty = 0.4, -0.3
    if v == "c":
        p.cyl(0.14, 0.52, (tx, ty, 0.43), "verdigris", segs=10, r2=0.13, style="hard_smooth")
        p.cyl(0.15, 0.1, (tx, ty, 0.72), "iron", segs=10, style="hard_smooth")
    else:
        p.cyl(0.14, 0.52, (tx, ty, 0.3), "verdigris", segs=10, r2=0.13, style="hard_smooth", rot=(0, math.pi / 2, 0.4))
        p.cyl(0.15, 0.1, (tx + 0.25, ty + 0.1, 0.3), "iron", segs=10, style="hard_smooth", rot=(0, math.pi / 2, 0.4))
    cx, cy = (0.25, 0.4)
    p.cyl(0.11, 0.14, (cx, cy, 0.35), "iron_light", segs=10, r2=0.13, style="hard_smooth")
    p.cyl(0.085, 0.04, (cx, cy, 0.43), "charcoal", segs=10, style="flat")
    p.torus(0.07, 0.015, (cx + 0.13, cy, 0.35), "iron_light", rot=(math.pi / 2, 0, 0), major=8, minor=4)
    if v == "c":
        tuft(p, px, py, 0.3, rng, n=8, h=0.6)
        bush(p, -0.9, 0.8, 0.35, rng, n=6)
    elif v == "b":
        tuft(p, 0.9, 0.4, 0.3, rng, n=5, h=0.3)


def hat(p, loc, col, rot=(0, 0, 0), rng=None):
    p.ico(0.2, loc, col, scale=(1, 1, 0.75), rot=rot, subdiv=1, style="round")
    p.cyl(0.28, 0.04, (loc[0], loc[1], loc[2] - 0.01), col, segs=12, rot=rot, r2=0.26, style="hard_smooth")
    p.box((0.08, 0.3, 0.05), loc, mix(col, "iron", 0.2), rot=rot, style="fine")


@K.kind("hardhat_rack", hero=False, tags=["sign"], variants="abc",
        story="A peg board of hard hats against the works wall, one fallen where its owner went home.")
def hardhat_rack(p, v, rng):
    p = Sc(p, 1.35, lite=True)
    cols = ["canvas", "bone", "canvas_dark", DUSK_BLUE, "canvas", "bone"]
    p.box((3.0, 0.5, 1.7), (0, 0.3, 0.85), mix("concrete", "concrete_stain", 0.55), style="hard_smooth", jit=0.02)
    p.box((3.1, 0.6, 0.14), (0, 0.3, 1.74), mix("concrete_light", "concrete_stain", 0.4), style="hard_smooth", jit=0.02)
    p.box((3.02, 0.52, 0.35), (0, 0.3, 0.18), "concrete_dark", style="flat", jit=0.02)
    for sx, z in ((-1, 1.78), (1, 1.7), (-1, 0.2)):
        p.box((0.32, 0.62, 0.22), (sx * 1.5, 0.3, z), "soil", rot=(0, 0, 0.3 * sx), style="flat")
    p.box((0.05, 0.08, 0.9), (0.9, 0.02, 1.2), "charcoal", rot=(0, 0.45, 0), style="flat")
    p.box((0.05, 0.08, 0.6), (0.6, 0.02, 0.75), "charcoal", rot=(0, -0.35, 0), style="flat")
    bush(p, -1.6, -0.5, 0.45, rng, n=4)
    if v == "c":
        p.box((1.1, 0.5, 0.9), (1.6, 0.3, 0.45), "concrete", rot=(0, 0, 0.3), style="hard_smooth")
        p.ico(0.5, (0.9, -0.1, 0.25), "concrete_stain", scale=(1.4, 1.0, 0.4), style="round")
    ang = {"a": 0.0, "b": 0.0, "c": 0.0}[v]
    for i in range(5):
        p.box((0.4, 0.07, 1.0 if v != "c" else (0.7 if i % 2 else 1.0)), (-1.0 + i * 0.5, -0.03, 1.1),
              tint("timber_pale" if v == "a" else "timber_grey", rng, 0.08), jit=0.004)
    p.box((2.5, 0.08, 0.1), (0, -0.09, 1.4), "timber_dark")
    p.box((2.5, 0.08, 0.1), (0, -0.09, 0.75), "timber_dark")
    n = 6 if v == "a" else (4 if v == "b" else 2)
    for i in range(6):
        x = -1.0 + i * 0.4
        p.cyl(0.04, 0.2, (x, -0.2, 1.05), "timber_dark", segs=6, rot=(math.pi / 2, 0, 0), style="round")
        if i < n:
            hat(p, (x, -0.38, 1.02), cols[i], rot=(0.3, 0, 0))
    hat(p, (0.9, -1.0, 0.1), "canvas_dark", rot=(math.pi * 0.85, 0.2, 0.4))
    p.ico(0.12, (1.4, -0.7, 0.05), "dry_grass", scale=(1.2, 0.8, 0.3), style="round")
    if v == "c":
        bush(p, -1.7, -0.7, 0.5, rng, n=5)
        tuft(p, 0.0, -0.8, 0.5, rng, n=4, h=0.5)
    elif v == "b":
        tuft(p, -1.7, -0.5, 0.4, rng, n=5, h=0.4)


@K.kind("cable_drum", hero=False, tags=[], variants="abc",
        story="A wooden cable spool left flat on the ground, with a coil of rope the crew never stowed.")
def cable_drum(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    R, core = 1.05, 0.5
    fl = 0.1
    for z in (0.2 + fl / 2, 0.2 + 0.7 + fl * 1.5):
        for k in range(10):
            a = k / 10 * math.tau
            pass
    p.cyl(R, fl, (0, 0, 0.2 + fl / 2), "timber", segs=20, style="hard_smooth")
    p.cyl(core, 0.7, (0, 0, 0.2 + fl + 0.35), "timber_dark", segs=14, style="hard_smooth")
    top_z = 0.2 + fl + 0.7 + fl / 2
    if v != "c":
        p.cyl(R, fl, (0, 0, top_z), "timber_pale" if v == "a" else "timber_grey", segs=20, style="hard_smooth")
        p.cyl(core * 0.3, fl * 1.3, (0, 0, top_z), "charcoal", segs=10, style="round")
    for a_ in (0.5, 2.6, 4.7):
        p.box((0.5, 0.34, 0.2), (0.75 * math.cos(a_), 0.75 * math.sin(a_), 0.1), "timber_dark", rot=(0, 0, a_))
    wr = {"a": 0.85, "b": 0.62, "c": 0.6}[v]
    p.cyl(wr, 0.66, (0, 0, 0.2 + fl + 0.35), "cable", segs=20, style="round")
    for k in range(4):
        zc = 0.2 + fl + 0.1 + k * 0.17
        p.torus(wr, 0.045, (0, 0, zc), "iron", major=24, minor=4)
    if v == "b":
        pts = [(wr * 0.9, 0.2, 0.3), (1.2, -0.4, 0.1), (1.7, -0.8, 0.1), (2.0, -0.3, 0.1),
               (1.9, 0.4, 0.1), (1.5, 0.6, 0.1), (1.2, 0.3, 0.1)]
        for a, b in zip(pts, pts[1:]):
            p.rod(a, b, 0.06, "cable", segs=6)
    if v == "c":
        p.cyl(R, fl, (-1.7, -1.2, 0.2), "timber_grey", segs=20, rot=(0.04, 0.05, 0), r2=R, style="hard_smooth")
        p.box((0.9, 0.35, fl), (1.6, 1.2, 0.1), "timber_grey", rot=(0, 0, 0.5))
        p.box((0.7, 0.3, fl), (2.0, 1.7, 0.13), "timber_dark", rot=(0.1, 0, -0.3))
        bush(p, 1.5, -1.5, 0.6, rng, n=8)
    cx, cy = (-1.25, 0.75) if v != "c" else (-1.25, 1.0)
    for k in range(3):
        p.torus(0.5 - k * 0.1, 0.07, (cx, cy, 0.1 + k * 0.1), "canvas_stain" if v != "c" else "timber_grey", major=14, minor=5)
    p.cyl(0.18, 0.1, (cx, cy, 0.08), "canvas_dark", segs=10, style="round")
    p.rod((cx + 0.3, cy, 0.12), (cx + 0.9, cy + 0.35, 0.1), 0.07, "canvas_stain", segs=6)
    if v != "c":
        tuft(p, 1.4, -1.6, 0.6, rng, n=6, h=0.35)


@K.kind("compressor_cart", hero=False, tags=["machine"], variants="abc",
        story="A squat two-wheel air compressor on its tow bar, one stubby whistle on top; nobody blew the shift whistle.")
def compressor_cart(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    tilt = 0.2 if v == "b" else 0.0
    body = PETROL if v == "a" else ("rust" if v == "b" else mix(PETROL, "concrete_stain", 0.4))
    p.box((1.5, 0.95, 0.14), (0, 0, 0.52), "charcoal", rot=(0, tilt, 0), style="hard_smooth")
    p.cyl(0.24, 1.3, (0, 0, 0.38), "iron_light", segs=10, rot=(0, math.pi / 2 + tilt, 0), style="hard_smooth")
    p.box((1.0, 0.75, 0.7), (0, 0, 0.97), body, rot=(0, tilt, 0), style="hard_smooth")
    p.box((0.7, 0.06, 0.4), (0, -0.4, 1.0), "charcoal", rot=(0, tilt, 0), style="hard_smooth")
    p.box((0.74, 0.8, 0.08), (0, 0, 1.36), "iron_light", rot=(0, tilt, 0), style="hard_smooth")
    p.cyl(0.07, 1.9, (0, 0.1, 0.4), "iron", segs=8, rot=(0, math.pi / 2, 0), style="round")
    for sx in (-1, 1):
        if v == "b" and sx == 1:
            p.cyl(0.14, 0.2, (sx * 0.85, 0.1, 0.4), "iron_light", segs=8, rot=(0, math.pi / 2, 0), style="round")
            p.torus(0.28, 0.12, (1.9, 0.9, 0.2), "charcoal", rot=(0.05, 0.05, 0), major=14, minor=6)
            continue
        wheel(p, sx * 0.85, 0.1, 0.4, 0.4, 0.22, rng)
    p.rod((0, -0.45, 0.16), (0.1, -1.5, 0.12), 0.05, "iron_light", segs=6)
    p.torus(0.1, 0.03, (0.1, -1.6, 0.14), "iron", major=10, minor=4)
    for k in range(3):
        p.torus(0.26 - k * 0.02, 0.05, (-0.1, 0.1, 1.46 + k * 0.08), "cable", major=12, minor=5)
    if v != "c":
        p.cyl(0.09, 0.32, (0.28, -0.1, 1.56), "iron_light", segs=10, style="hard_smooth")
        p.cyl(0.12, 0.07, (0.28, -0.1, 1.76), "iron", segs=10, style="hard_smooth")
    p.ico(0.24, (0.9, -1.0, 0.14), "canvas", scale=(1.2, 0.8, 0.5), style="round")
    if v == "c":
        bush(p, 1.3, -0.3, 0.55, rng, n=7)
        tuft(p, -1.2, 0.6, 0.4, rng, n=5, h=0.5)
    elif v == "b":
        tuft(p, -1.2, -0.6, 0.4, rng, n=5, h=0.4)


@K.kind("cold_campfire", hero=False, tags=[], variants="abc",
        story="A stone ring of a cold campfire: charred logs, a seat, and the crew's kettle waiting on a stone.")
def cold_campfire(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    n = 11
    for i in range(n):
        a = i / n * math.tau
        if v == "b" and i in (2, 3, 7):
            a += 0.25
            rr = 1.25 + 0.25 * (i % 2)
        else:
            rr = 0.95
        r = rng.uniform(0.22, 0.32)
        p.ico(r, (rr * math.cos(a), rr * math.sin(a), r * 0.6), tint("sandstone" if i % 2 else "concrete_light", rng, 0.08),
              scale=(1.1, 1.0, 0.7), rot=(0, 0, a), style="round")
    p.cyl(0.88, 0.04, (0, 0, 0.03), "charcoal", segs=16, r2=0.8, style="flat")
    p.cyl(0.55, 0.05, (0.1, 0.1, 0.06), "concrete_dark", segs=14, style="flat")
    for a, ln in ((0.3, 1.1), (1.6, 1.0), (2.6, 0.9)):
        c = (0.1 * math.cos(a), 0.1 * math.sin(a), 0.17)
        d = Vector((math.cos(a), math.sin(a), 0.25 if v != "b" else 0.0)).normalized() * (ln / 2)
        p.rod((c[0] - d.x, c[1] - d.y, c[2] - d.z * 0.5), (c[0] + d.x, c[1] + d.y, c[2] + d.z + 0.15), 0.1, "charcoal", segs=8)
        p.ico(0.1, (c[0] + d.x, c[1] + d.y, c[2] + d.z + 0.15), "iron", scale=(1, 1, 0.6), style="round")
    p.rod((-1.9, -1.0, 0.25), (-0.9, -1.9, 0.25), 0.25, "timber_dark" if v != "c" else "timber_grey", segs=10)
    kx, ky = (1.8, -0.6)
    p.ico(0.4, (kx, ky, 0.2), "sandstone_dark", scale=(1.2, 1.0, 0.55), style="round")
    if v == "c":
        p.uv(0.28, (kx + 0.7, ky + 0.2, 0.25), "iron", scale=(1, 1, 0.8), rot=(1.2, 0.3, 0), u=10, v=7, style="round")
        p.cyl(0.07, 0.3, (kx + 0.5, ky + 0.5, 0.1), "iron", segs=8, rot=(1.4, 0.3, 0.2), style="round")
        tuft(p, 0.0, 0.0, 0.8, rng, n=6, h=0.7)
        tuft(p, 1.2, 0.8, 0.6, rng, n=4, h=0.6)
        bush(p, -1.3, 1.1, 0.5, rng, n=4)
    else:
        p.uv(0.28, (kx, ky, 0.65), "iron", scale=(1, 1, 0.8), u=10, v=7, style="round")
        p.cyl(0.12, 0.08, (kx, ky, 0.9), "iron_light", segs=10, style="hard_smooth")
        p.cyl(0.05, 0.1, (kx, ky, 0.98), "charcoal", segs=6, style="round")
        p.cyl(0.06, 0.34, (kx + 0.35, ky, 0.72), "iron", segs=8, r2=0.03, rot=(0, math.pi / 3, 0), style="round")
        p.torus(0.2, 0.025, (kx, ky, 0.88), "iron", rot=(math.pi / 2, 0, 0.3), major=12, minor=4)
        p.cyl(0.08, 0.14, (-0.4, -1.5, 0.12), "iron_light", segs=8, r2=0.1, style="hard_smooth")


def shirt(p, top, col, rot_z=0.0, size=1.0, rng=None):
    x, y, z = top
    p.ico(0.3 * size, (x, y, z - 0.4 * size), col, scale=(1.0, 0.18, 1.35), rot=(0, 0, rot_z), style="round")
    for sx in (-1, 1):
        p.ico(0.15 * size, (x + sx * 0.34 * size * math.cos(rot_z), y + sx * 0.34 * size * math.sin(rot_z), z - 0.15 * size),
              col, scale=(1.4, 0.4, 0.7), rot=(0, 0.3 * sx, rot_z), style="round")


@K.kind("laundry_line", hero=False, line_clear_m=30, tags=["soft"], variants="abc",
        story="A crew washing line between two leaning posts: shirts, a towel, a sock, left out in the dawn wind.")
def laundry_line(p, v, rng):
    p = Sc(p, 1.0 if v == "c" else 1.15, lite=True)
    ha, hb = 1.6, 1.4
    pa = (-1.6, 0.0, 0.0)
    pb = (1.7, 0.2, 0.0)
    fall = v == "c"
    p.cyl(0.3, 0.14, (pa[0], pa[1], 0.07), "concrete", segs=10, style="hard_smooth")
    p.cyl(0.3, 0.14, (pb[0], pb[1], 0.07), "concrete", segs=10, style="hard_smooth")
    p.beam((pa[0], pa[1], 0.1), (pa[0] - 0.1, pa[1], ha), 0.13, "timber_dark")
    if not fall:
        p.beam((pb[0], pb[1], 0.1), (pb[0] + 0.12, pb[1] + 0.05, hb), 0.13, "timber_grey")
    else:
        p.beam((pb[0], pb[1], 0.2), (pb[0] + 1.3, pb[1] + 0.6, 0.3), 0.13, "timber_grey", rot=0) if False else p.rod(
            (pb[0], pb[1], 0.2), (pb[0] + 1.3, pb[1] + 0.8, 0.12), 0.07, "timber_grey", segs=6)
    a = Vector((pa[0] - 0.1, pa[1], ha))
    b = Vector((pb[0] + 0.12, pb[1] + 0.05, hb)) if not fall else Vector((pb[0] + 1.3, pb[1] + 0.8, 0.12))
    sag = {"a": 0.28, "b": 0.7, "c": 1.0}[v]
    steps = 14
    prev = None
    pts = []
    for i in range(steps + 1):
        t = i / steps
        q = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        pts.append(q)
    for q0, q1 in zip(pts, pts[1:]):
        p.rod(tuple(q0), tuple(q1), 0.016, "canvas_stain", segs=4)
    items = [(0.18, DUSK_BLUE, 0.0, 1.0), (0.38, "canvas", 0.1, 0.9), (0.6, "dry_grass", -0.1, 1.1), (0.8, "canvas_dark", 0.0, 0.8)]
    if v == "a":
        for t, col, rz, sz in items[:3]:
            shirt(p, tuple(a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))), col, rz, sz)
        t = 0.8
        q = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        p.box((0.6, 0.06, 0.95), (q.x, q.y, q.z - 0.5), "canvas", style="soft")
        p.box((0.6, 0.07, 0.12), (q.x, q.y, q.z - 0.12), "timber_pale", style="soft")
        for t in (0.3, 0.7):
            q = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
            p.box((0.04, 0.05, 0.12), (q.x + 0.16, q.y, q.z), "timber_dark", style="fine")
    elif v == "b":
        t = 0.3
        q = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        shirt(p, tuple(q), DUSK_BLUE, 0.1, 1.0)
        t = 0.7
        q = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        p.box((0.6, 0.06, 0.8), (q.x, q.y, q.z - 0.42), "canvas_dark", rot=(0, 0.0, 0.0), style="soft")
        p.ico(0.35, (0.4, -1.0, 0.07), "canvas", scale=(1.4, 1.0, 0.25), style="round")
        tuft(p, -2.1, 0.5, 0.4, rng, n=5, h=0.4)
    else:
        for i, (x, y, col) in enumerate(((0.2, -0.5, DUSK_BLUE), (-0.5, 0.6, "canvas"), (1.0, 0.1, "dry_grass"))):
            p.ico(0.45, (x, y, 0.08 + 0.02 * i), col, scale=(1.2, 0.9, 0.25), rot=(0, 0, i * 1.1), style="round")
        bush(p, 0.2, 1.0, 0.5, rng, n=7)
        tuft(p, -1.2, -0.7, 0.4, rng, n=6, h=0.5)
    p.ico(0.1, (0.0, -0.9, 0.05), "canvas_stain", scale=(1.6, 0.6, 0.4), style="round")


@K.kind("sandbags", hero=False, tags=["soft"], variants="abc",
        story="A low curved wall of sandbags thrown up against the spring melt, slumping now.")
def sandbags(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    R = 2.0
    courses = {"a": 3, "b": 2, "c": 1}[v]
    for c in range(courses):
        count = 7 - c
        off = 0.5 * (c % 2)
        for i in range(count):
            t = (i + off + 0.5) / 7 - 0.5
            ang = t * math.radians(105) + math.pi / 2
            if v == "b" and c == 1 and i in (2, 5):
                continue
            x, y = R * math.cos(ang), R * math.sin(ang) - R * 0.6
            jx = rng.uniform(-0.04, 0.04)
            col = tint("canvas_stain" if (i + c) % 3 else "sandstone_pale", rng, 0.1)
            sink = 0.0
            if v == "c":
                sink = rng.uniform(-0.04, 0.02)
            p.ico(0.5, (x + jx, y, 0.2 + c * 0.28 + sink), col, scale=(1.05, 0.62, 0.42), rot=(0, 0.05 * rng.uniform(-1, 1), ang + math.pi / 2), style="round")
            p.box((0.1, 0.04, 0.04), (x, y - 0.0, 0.3 + c * 0.28 + sink), "canvas_dark", rot=(0, 0, ang), style="flat") if False else None
    if v in ("b", "c"):
        p.ico(0.5, (R * 0.35, -R * 0.4 - 0.1, 0.07), "sandstone_pale", scale=(1.3, 1.0, 0.25), style="round")
        p.ico(0.4, (R * 0.5, -R * 0.4 - 0.3, 0.15), "canvas_dark", scale=(1.1, 0.6, 0.35), rot=(0, 0.1, 0.5), style="round")
    if v == "c":
        for i in range(3):
            p.ico(0.45, (rng.uniform(-1.4, 1.4), rng.uniform(-1.6, -0.9), 0.12), "sandstone_pale", scale=(1.2, 0.7, 0.3),
                  rot=(0, 0, rng.uniform(0, 3)), style="round")
        tuft(p, -1.5, -2.0, 0.9, rng, n=9, h=0.6)
        bush(p, 1.5, -2.2, 0.45, rng, n=6)
    if v == "b":
        tuft(p, -2.2, -2.0, 0.5, rng, n=6, h=0.4)


@K.kind("rebar_bloom", hero=False, tags=["plant"], variants="abc",
        story="A bundle of rebar left in a slab chunk, with a brittlebush that has taken the scrap for a trellis.")
def rebar_bloom(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    p.box((1.9, 1.2, 0.34), (0, 0, 0.17), "concrete", rot=(0, 0.04, 0.2), style="hard_smooth", jit=0.03)
    p.box((1.1, 0.9, 0.3), (-0.7, -0.7, 0.4), "concrete_stain", rot=(0.06, -0.08, 0.7), style="hard_smooth", jit=0.03)
    p.box((0.7, 0.6, 0.24), (0.95, 0.4, 0.46), "concrete_light", rot=(0, 0.2, 0.3), style="hard_smooth", jit=0.03)
    n = {"a": 9, "b": 7, "c": 4}[v]
    for i in range(n):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.05, 0.45)
        base = (0.2 + d * math.cos(a), d * math.sin(a), 0.4)
        ln = rng.uniform(0.8, 1.15)
        lean = rng.uniform(0.08, 0.35) if v == "a" else rng.uniform(0.5, 1.15)
        top = (base[0] + ln * math.sin(lean) * math.cos(a), base[1] + ln * math.sin(lean) * math.sin(a), base[2] + ln * math.cos(lean))
        mid = ((base[0] + top[0]) / 2 + rng.uniform(-0.04, 0.04), (base[1] + top[1]) / 2 + rng.uniform(-0.04, 0.04), (base[2] + top[2]) / 2)
        col = tint("rust", rng, 0.1) if i % 3 else tint("iron", rng, 0.1)
        p.rod(base, mid, 0.035, col, segs=6)
        p.rod(mid, top, 0.035, col, segs=6)
        p.cyl(0.05, 0.06, top, col, segs=6, style="round")
    p.torus(0.2, 0.02, (0.2, 0.0, 0.8), "cable", major=12, minor=4)
    bush(p, 0.1, 0.0, 0.9 if v != "c" else 0.6, rng, n=14 if v != "c" else 8, h=1.0 if v == "a" else 0.8)
    if v == "c":
        for i in range(3):
            p.rod((1.0 + i * 0.2, -0.9 + i * 0.3, 0.02), (1.7 + i * 0.1, -0.7 + i * 0.3, 0.06), 0.035, "rust", segs=6)
        tuft(p, -1.0, 0.9, 0.7, rng, n=8, h=0.6)


@K.kind("desert_scrub", hero=False, tags=["plant"], variants="abc",
        story="Brittlebush and creosote clumps: what grows once the works are quiet.")
def desert_scrub(p, v, rng):
    p = Sc(p, 1.5, lite=True)
    if v == "a":
        bush(p, 0, 0, 1.2, rng, n=14)
        bush(p, 1.1, 0.8, 0.7, rng, n=7)
        rock(p, -1.0, 0.8, 0.3, rng, "sandstone_dark")
    elif v == "b":
        for k in range(11):
            a = rng.uniform(0, math.tau)
            lean = rng.uniform(0.15, 0.55)
            ln = rng.uniform(1.0, 1.7)
            b0 = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.0)
            tip = (b0[0] + ln * math.sin(lean) * math.cos(a), b0[1] + ln * math.sin(lean) * math.sin(a), ln * math.cos(lean))
            p.rod(b0, tip, 0.035, "timber_dark", segs=5, r2=0.012)
            for j in range(2):
                t = 0.6 + 0.3 * j
                q = (b0[0] + (tip[0] - b0[0]) * t, b0[1] + (tip[1] - b0[1]) * t, ln * math.cos(lean) * t)
                p.ico(0.17 + 0.03 * j, q, tint("leaf", rng, 0.12), scale=(1.1, 1.0, 0.8), style="round")
        tuft(p, 0.9, -0.7, 0.4, rng, n=6, h=0.4)
    else:
        bush(p, 0.0, 0.0, 0.8, rng, leaf="dry_grass", flowers=False, n=8, h=0.8)
        for k in range(9):
            a = rng.uniform(0, math.tau)
            tip = (0.9 * math.cos(a), 0.9 * math.sin(a), rng.uniform(0.9, 1.5))
            p.rod((0.1 * math.cos(a), 0.1 * math.sin(a), 0.1), tip, 0.025, "timber_grey", segs=5, r2=0.01)
        rock(p, 1.3, -0.5, 0.45, rng, "sandstone")
        tuft(p, -1.0, 0.7, 0.5, rng, n=7, h=0.5)


K.kind("foreman_billboard", hero=True, tags=["sign", "tall"], variants="ab",
       story="A cast Foreman notice, square and spotless, and the keepers' answer on it: a ball-shaped hole and chalk.")(kit.foreman_billboard)
K.kind("shift_table", tags=["machine"], variants="ab",
       story="A cast shift table still set for a crew that left: giant gloves laid out square, the clock stopped on the bell.")(kit.shift_table)


CAST = mix(PETROL, "verdigris", 0.35)
CAST_FIELD = mix(PETROL, "verdigris", 0.55)
CAST_EDGE = mix(PETROL, "verdigris", 0.8)
CHALK = "e6e3d6"
ROPE = "b77843"
PIPE = mix(OXIDE, "rust", 0.45)
PIPE_DARK = mix(PIPE, "charcoal", 0.35)
K.closed_lods |= {"intake_gantry", "takeoff_deck", "pump_elbow", "chalk_turn", "keeper_bunting"}


@K.kind("intake_gantry", hero=True, tags=["tall"], variants="ab",
        story="An old-works intake gantry: a squared cast portal with one oversized cable socket on its lintel end.")
def intake_gantry(p, v, rng):
    s = 1 if v == "a" else -1
    LX, LW, TOP = 3.7, 2.4, 14.6
    for x in (-LX, LX):
        p.box((4.0, 4.0, 0.9), (x, 0, 0.45), CAST, style="hard_smooth")
        p.box((3.3, 3.3, 0.7), (x, 0, 1.24), mix(CAST, "concrete_dark", 0.3), style="hard_smooth")
        p.box((LW, LW, TOP - 1.55), (x, 0, 1.55 + (TOP - 1.55) / 2), CAST, style="hard_smooth")
        for k, zc in enumerate((3.9, 7.9, 11.9)):
            for fy in (-1, 1):
                p.box((1.86, 0.2, 3.3), (x, fy * (LW / 2 + 0.06), zc), mix(CAST, "charcoal", 0.12), style="hard")
                p.box((1.38, 0.16, 2.78), (x, fy * (LW / 2 + 0.17), zc), CAST_FIELD, style="hard_smooth")
            p.box((0.2, 1.86, 3.3), (x + (x > 0 and 1 or -1) * (LW / 2 + 0.06), 0, zc), mix(CAST, "charcoal", 0.12), style="hard")
            p.box((0.16, 1.38, 2.78), (x + (x > 0 and 1 or -1) * (LW / 2 + 0.17), 0, zc), CAST_FIELD, style="hard_smooth")
        inner = -1 if x > 0 else 1
        p.prism([(0.0, 0.0), (1.9, 0.0), (0.0, -1.9)], LW * 0.92, (x + inner * LW / 2, 0, TOP - 0.02), CAST,
                rot=(math.pi / 2, 0, 0 if inner > 0 else math.pi), style="hard_smooth")
    p.box((2 * LX + LW + 1.6, 2.9, 2.8), (0, 0, TOP + 1.4), CAST, style="hard_smooth")
    for k in (-1, 0, 1):
        for fy in (-1, 1):
            p.box((2.5, 0.2, 1.8), (k * 3.0, fy * 1.56, TOP + 1.4), mix(CAST, "charcoal", 0.12), style="hard")
            p.box((2.0, 0.16, 1.32), (k * 3.0, fy * 1.67, TOP + 1.4), CAST_FIELD, style="hard_smooth")
    p.box((2 * LX + LW + 2.6, 3.7, 0.55), (0, 0, TOP + 3.08), mix(CAST, "charcoal", 0.1), style="hard_smooth")
    p.box((2 * LX + LW + 0.9, 2.6, 0.6), (0, 0, TOP + 3.62), CAST, style="hard_smooth")
    end = s * (LX + LW / 2 + 0.8)
    p.box((1.3, 2.4, 2.4), (end + s * 0.62, 0, TOP + 1.4), mix(CAST, "charcoal", 0.15), style="hard_smooth")
    p.cyl(1.25, 0.5, (end + s * 1.5, 0, TOP + 1.4), CAST_EDGE, segs=20, rot=(0, math.pi / 2, 0), style="round")
    p.cyl(0.95, 0.42, (end + s * 1.9, 0, TOP + 1.4), mix(CAST, "charcoal", 0.25), segs=20, rot=(0, math.pi / 2, 0), style="round")
    p.cyl(0.62, 0.08, (end + s * 2.14, 0, TOP + 1.4), "charcoal", segs=20, rot=(0, math.pi / 2, 0), style="flat")
    p.torus(0.62, 0.16, (end + s * 1.9, 0, TOP - 0.2), mix(CAST, "charcoal", 0.25), rot=(math.pi / 2, 0, 0), major=16, minor=6)
    for k in range(3 if v == "a" else 5):
        x = s * (LX + rng.uniform(-0.6, 0.6))
        ln = rng.uniform(1.6, 3.4)
        p.box((0.16, 0.05, ln), (x, -(LW / 2 + 0.27), TOP - 1.1 - ln / 2 - rng.uniform(0, 2.0)), CAST_EDGE, style="flat")
    if v == "b":
        p.box((1.4, 1.2, 0.5), (-s * (LX + 1.6), -1.4, TOP + 2.7), "concrete_stain", rot=(0.2, 0.15, 0.4), style="hard_smooth")


@K.kind("takeoff_deck", hero=False, tags=["sign"], variants="ab",
        story="The intake takeoff deck: two painted concrete cheeks either side of the slot, bone chevrons pointing at the lip.")
def takeoff_deck(p, v, rng):
    length, marks = (12.0, 5) if v == "a" else (8.0, 3)
    for sx in (-1, 1):
        x = sx * 4.6
        p.box((1.0, length, 0.55), (x, 0, 0.275), "concrete_light", style="hard_smooth")
        p.box((1.16, length + 0.2, 0.12), (x, 0, 0.06), "concrete_dark", style="hard")
        for k in range(marks):
            y = length / 2 - 1.8 - k * 2.2
            for arm in (-1, 1):
                p.box((0.62, 0.2, 0.05), (x + arm * 0.2, y + 0.2, 0.565), "bone", rot=(0, 0, arm * 0.9), style="flat")
            p.box((0.05, 0.9, 0.36), (x - sx * 0.515, y, 0.3), "bone" if k % 2 == 0 else "charcoal", style="flat")
        lip = -length / 2 - 0.6
        p.box((1.3, 1.3, 0.95), (x, lip, 0.475), "concrete", style="hard_smooth")
        p.box((1.36, 1.36, 0.22), (x, lip, 0.7), "bone", style="hard")
        p.box((1.2, 1.2, 0.08), (x, lip, 0.99), "concrete_light", style="hard")
        if v == "b":
            p.box((1.0, 1.8, 0.55), (x + sx * 0.3, length / 2 + 1.3, 0.4), "concrete_light", rot=(0.35, 0, sx * 0.25),
                  style="hard_smooth")
    for k in range(4):
        p.box((0.3, 0.3, 0.16), (rng.choice((-1, 1)) * (4.6 + rng.uniform(-0.4, 0.4)),
                                 rng.uniform(-length / 2 + 0.5, length / 2 - 0.5), 0.6),
              mix("concrete", "concrete_stain", 0.5), rot=(0, 0, rng.uniform(0, 1.5)), style="hard")


def _bend(p, centre, radius, a0, a1, pipe_r, plane, color, segs=6):
    """A segmented (lobster-back) pipe bend: segs closed cylinders round an arc of radius in a plane, each joint hidden
    under a weld collar. plane maps (u, w) on the arc to (x, y, z)."""
    pts = [plane(centre, radius * math.cos(a0 + (a1 - a0) * k / segs), radius * math.sin(a0 + (a1 - a0) * k / segs))
           for k in range(segs + 1)]
    for k, (a, b) in enumerate(zip(pts, pts[1:])):
        d = (Vector(b) - Vector(a)).normalized() * 0.02
        a2 = Vector(a) - d if k > 0 else Vector(a)
        b2 = Vector(b) + d if k < segs - 1 else Vector(b)
        p.rod(tuple(a2), tuple(b2), pipe_r, color, segs=12, style="hard")
    for k in range(1, segs):
        a, b = Vector(pts[k - 1]), Vector(pts[k + 1])
        d = (b - a).normalized()
        q = Vector(pts[k])
        p.rod(tuple(q - d * 0.09), tuple(q + d * 0.09), pipe_r * 1.08, mix(color, "charcoal", 0.2), segs=12, style="flat")
    return pts


def _flange(p, at, axis_rot, r, color, studs=6):
    p.cyl(r, 0.22, at, color, segs=14, rot=axis_rot, style="hard")
    m = Matrix.LocRotScale(Vector(at), Euler(axis_rot).to_quaternion(), Vector((1, 1, 1)))
    for k in range(studs):
        a = math.tau * k / studs
        q = m @ Vector((math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, 0.13))
        p.cyl(0.08, 0.08, tuple(q), "iron", segs=5, rot=axis_rot, style="flat")


@K.kind("pump_elbow", hero=False, tags=["machine"], variants="abc",
        story="Hydro pump elbows dragged out of the sunken yard: oversized, riveted flanges, oxide gone to rust.")
def pump_elbow(p, v, rng):
    xz = lambda c, u, w: (c[0] + u, c[1], c[2] + w)
    xy = lambda c, u, w: (c[0] + u, c[1] + w, c[2])
    R = 0.62
    if v == "a":
        p.box((2.2, 2.2, 0.35), (0, 0, 0.175), "concrete", style="hard_smooth")
        _flange(p, (0, 0, 0.47), (0, 0, 0), 0.95, PIPE_DARK)
        p.rod((0, 0, 0.5), (0, 0, 1.36), R, PIPE, segs=12, style="hard")
        _bend(p, (1.2, 0, 1.3), 1.2, math.pi, math.pi / 2, R, xz, PIPE)
        p.rod((1.14, 0, 2.5), (2.2, 0, 2.5), R, PIPE, segs=12, style="hard")
        _flange(p, (2.28, 0, 2.5), (0, math.pi / 2, 0), 0.92, PIPE_DARK)
        p.cyl(0.55, 0.06, (2.42, 0, 2.5), "charcoal", segs=12, rot=(0, math.pi / 2, 0), style="flat")
        p.box((0.6, 0.3, 1.9), (1.7, 0.0, 0.95), "iron", style="hard")
    elif v == "b":
        _bend(p, (0, 1.2, R), 1.2, -math.pi / 2, 0, R, xy, PIPE)
        _bend(p, (2.4, 1.2, R), 1.2, math.pi, math.pi * 1.5, R, xy, PIPE)
        _flange(p, (0, -0.08, R), (math.pi / 2, 0, 0), 0.9, PIPE_DARK)
        _flange(p, (2.4, 2.48, R), (math.pi / 2, 0, 0), 0.9, PIPE_DARK)
        p.rod((1.2, 1.2, R), (1.2, 1.2, 2.2), 0.12, "iron", segs=8, style="hard")
        p.torus(0.6, 0.08, (1.2, 1.2, 2.25), "iron_light", major=14, minor=5, style="flat")
        for k in range(4):
            a = math.tau * k / 4 + 0.4
            p.rod((1.2, 1.2, 2.25), (1.2 + 0.56 * math.cos(a), 1.2 + 0.56 * math.sin(a), 2.25), 0.05, "iron", segs=5, style="flat")
        for x in (0.3, 2.1):
            p.box((0.9, 0.6, 0.3), (x, 1.2, 0.15), "timber_dark", style="hard")
    else:
        _bend(p, (0, 0, 0.55), 1.5, 0, math.pi / 2, 0.78, xy, PIPE, segs=7)
        _flange(p, (1.5, -0.1, 0.55), (math.pi / 2, 0, 0), 1.12, PIPE_DARK)
        p.rod((0, 1.5, 0.55), (-1.2, 1.5, 0.55), 0.78, PIPE, segs=12, style="hard")
        p.box((0.9, 0.3, 0.9), (-1.35, 1.5, 0.55), PIPE_DARK, rot=(0, 0.4, 0.2), style="hard")
        for k in range(3):
            p.ico(0.7 + 0.15 * k, (0.6 - k * 0.8, 0.9 + k * 0.3, 0.05), "sandstone_pale", scale=(1.6, 1.1, 0.4), style="flat")
        rock(p, 2.1, 1.2, 0.35, rng, "sandstone_dark")


def _ground_stroke(p, a, b, width, rng, z=0.025):
    """A chalk stroke laid on the ground from a to b (x, y), a little crooked."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy)
    p.box((ln + width * 0.4, width, 0.05), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z), CHALK,
          rot=(0, 0, math.atan2(dy, dx) + rng.uniform(-0.03, 0.03)), style="flat")


def _arrow(p, tail, tip, width, rng, head=1.1):
    """A chalked arrow: a shaft of three crooked strokes and two head strokes."""
    pts = [tail] + [(tail[0] + (tip[0] - tail[0]) * t + rng.uniform(-0.08, 0.08),
                     tail[1] + (tip[1] - tail[1]) * t + rng.uniform(-0.08, 0.08)) for t in (0.35, 0.7)] + [tip]
    for a, b in zip(pts, pts[1:]):
        _ground_stroke(p, a, b, width, rng)
    ang = math.atan2(tip[1] - tail[1], tip[0] - tail[0])
    for side in (-1, 1):
        aa = ang + math.pi + side * 0.62
        _ground_stroke(p, tip, (tip[0] + head * math.cos(aa), tip[1] + head * math.sin(aa)), width, rng)


@K.kind("chalk_turn", hero=False, tags=["sign"], variants="abc",
        story="A keeper's chalk turn mark at the mouth of a side route: a fat crooked arrow and a stone to hold the place.")
def chalk_turn(p, v, rng):
    W = 0.36
    if v == "a":
        _arrow(p, (0.0, 2.2), (0.0, -2.2), W, rng, head=1.3)
        for k in range(3):
            _ground_stroke(p, (1.0 + 0.3 * k, 1.9), (1.05 + 0.3 * k, 1.1), 0.12, rng)
    elif v == "b":
        _ground_stroke(p, (0.0, 2.4), (0.0, 0.4), W, rng)
        _arrow(p, (0.0, 0.4), (-1.6, -1.9), W, rng, head=1.1)
        _arrow(p, (0.0, 0.4), (1.6, -1.9), W * 0.7, rng, head=0.9)
        _ground_stroke(p, (-1.25, -1.2), (-1.85, -2.3), W * 0.6, rng)
    else:
        p.box((1.6, 0.28, 1.1), (0, 0, 0.55), "concrete", rot=(-0.28, 0, 0.05), style="hard_smooth")
        face = -0.32
        q = lambda x, z: (x, face + (z - 0.55) * 0.28, z)
        for a, b in (((-0.55, 0.55), (0.45, 0.6)), ((0.45, 0.6), (0.15, 0.85)), ((0.45, 0.6), (0.12, 0.33))):
            ax, az = a
            bx, bz = b
            ln = math.hypot(bx - ax, bz - az)
            mid = q((ax + bx) / 2, (az + bz) / 2)
            p.box((ln + 0.08, 0.04, 0.13), mid, CHALK, rot=(-0.28, -math.atan2(bz - az, bx - ax), 0.05), style="flat")
        p.ico(0.42, (0.0, 0.55, 0.2), "sandstone_dark", scale=(1.3, 1.0, 0.6), style="soft")
        _arrow(p, (0.0, -0.6), (0.0, -2.6), W * 0.8, rng, head=0.9)
    p.cyl(0.07, 0.3, (0.5 if v != "b" else -0.6, 2.6, 0.07), CHALK, segs=8, rot=(0, math.pi / 2, 0.6), style="hard")
    for k in range(4):
        _ground_stroke(p, (-0.7 + 0.22 * k, -2.9), (-0.45 + 0.22 * k, -2.55), 0.08, rng)
    rock(p, -1.1 if v != "b" else 0.9, 2.3, 0.32, rng, "sandstone_dark")
    p.ico(0.22, (-1.45 if v != "b" else 1.25, 2.0, 0.05), "sandstone", scale=(1.2, 1.0, 0.5), style="soft")


def _pennant(p, top, w, h, color, rng):
    """A triangular cloth pennant hanging from a point on a line, a hair thick."""
    p.prism([(-w / 2, 0.0), (w / 2, 0.0), (rng.uniform(-0.05, 0.05), -h)], 0.03, top, color,
            rot=(math.pi / 2, 0, rng.uniform(-0.25, 0.25)), style="flat")


@K.kind("keeper_bunting", hero=False, tags=["soft", "sign"], variants="ab",
        story="Keeper bunting at a side route's mouth: crooked poles, sand and bone cloth, tied on with copper rope.")
def keeper_bunting(p, v, rng):
    def pole(x, y, h, lean):
        top = (x + lean[0], y + lean[1], h)
        p.rod((x, y, -0.05), top, 0.09, "timber_grey", segs=8, r2=0.07, style="round")
        p.ico(0.32, (x, y, 0.08), "sandstone_dark", scale=(1.4, 1.2, 0.5), style="soft")
        for k in range(2):
            p.torus(0.12, 0.035, (top[0] * 0.96, top[1] * 0.96, h - 0.25 - 0.12 * k), ROPE, major=10, minor=4)
        return top
    if v == "a":
        top = pole(0, 0, 3.0, (0.12, -0.05))
        for k, (dz, col) in enumerate(((0.0, "bone"), (-0.7, "canvas"), (-1.35, "canvas_dark"))):
            p.box((0.06, 0.62, 0.72), (top[0] + 0.05, top[1] - 0.36 - 0.05 * k, top[2] - 0.45 + dz), col,
                  rot=(0.06 * k, 0.05, 0.08 * k), style="flat")
        p.box((0.05, 0.9, 0.6), (top[0] - 0.02, top[1] + 0.52, top[2] - 0.4), "bone", rot=(0, 0, -0.1), style="flat")
        p.box((0.04, 0.12, 0.12), (top[0] - 0.02, top[1] + 0.95, top[2] - 0.36), OXIDE, style="flat")
    else:
        a = pole(-1.9, 0, 2.7, (0.1, 0.05))
        b = pole(1.9, 0.1, 2.5, (-0.12, -0.04))
        n = 7
        cols = ("bone", "canvas", OXIDE, "bone", "canvas_dark", "bone", OXIDE)
        prev = None
        for k in range(n + 1):
            t = k / n
            pt = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t - 0.5 * 4 * t * (1 - t) - 0.18)
            if prev is not None:
                p.rod(prev, pt, 0.03, ROPE, segs=5, style="flat")
            prev = pt
            if 0 < k < n + 1 and k < n:
                q = (pt[0] + (b[0] - a[0]) / n * 0.5, pt[1], pt[2] - 0.05)
                _pennant(p, q, 0.42, 0.55, cols[k % len(cols)], rng)


if __name__ == "__main__":
    K.main()
