"""Shared park dressing prop kit (Dressing lane; contract: design-v3/park/DRESSING-KITS.md).

A per-park recipe (tools/blender/park/props/<park>.py) declares kinds and variants:

    import kit
    K = kit.Kit("dam")

    @K.kind("gate_wheelhouse", hero=True, tags=["machine"], story="one line", variants="ab")
    def gate_wheelhouse(p, v, rng):
        p.box((2, 2, 0.5), (0, 0, 0.25), kit.C["concrete"])
        ...

    if __name__ == "__main__":
        K.main()

blender -b --factory-startup --threads 2 --python-exit-code 1 -P \
  sketches/core-loop/tools/blender/park/props/<park>.py -- \
  [--out-dir D] [--only k1,k2] [--count-only] [--preview-dir D]

Authoring frame: Blender Z up, floor at z = 0, front faces -Y (Godot +Z after import).
The kit recentres each model on its footprint (bbox xy centre) and drops its lowest point to
z = 0 before baking, so the origin is the foot centre. Every build then polishes (bevel,
subdivision), bakes AO and wear, exports LOD0, and exports LOD1 and LOD2 from a Decimate
(collapse) copy of the polished, baked mesh. Budgets are enforced at build time (exit 1).
"""
import argparse
import colorsys
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
BLENDER = HERE.parent.parent
sys.path.insert(0, str(BLENDER))
sys.path.insert(0, str(BLENDER.parent))
import common
import model_audit
import cycles_device
import polish

SCHEMA = "scrapkeep-park-props-kit/1"
SKETCH = Path(common.SKETCH)
RES_ROOT = "res://assets/models/park/props/"
LOADER = "src/presentation/park_props.gd (vignette file src/world/park/props/park_%s.json)"

# --- budgets (DRESSING-KITS.md) -----------------------------------------------------------
PERCH_MIN_HEIGHT = 6.0  # metres: a variant this tall or taller exports a `perch` anchor (design-v3/park/PERCH-ANCHOR.md)
BUDGET = {"dress_hero": (6000, 20000), "dress_prop": (300, 3000)}
LOD1_BAND, LOD2_BAND, LOD2_MIN_TRIS = (0.40, 0.60), (0.10, 0.20), 40
LOD1_TARGET, LOD2_TARGET = 0.50, 0.15
# A LOD that fills less than model_audit.COVER_MIN of LOD0's outline gets COVER_STEP times the triangles again, up to
# model_audit.COVER_CAP of LOD0's triangles (and no more than the LOD before it), and one still under model_audit.COVER_FLOOR there fails the build; the collapse otherwise ate whole parts (the dam's cable drums drew as floating rings at 100 m,
# 14 Nov, W1-29). Only those LODs pass their band's top.
COVER_STEP = 1.25
FLOOR_TOL = 0.02  # metres a LOD bottom may sit off y 0
RESEAT_MAX = 0.15  # metres decimate() may shift a LOD down or up to put its bottom back on the floor

# --- palette: only safe colours -----------------------------------------------------------
C = {
    "sandstone": "c6a274", "sandstone_dark": "a98b60", "sandstone_pale": "d8c19a",
    "concrete": "9a9a94", "concrete_dark": "6f706b", "concrete_light": "b8b7ae",
    "concrete_stain": "7d7a70",
    "timber": "8a6a46", "timber_dark": "5d4630", "timber_grey": "8e8470", "timber_pale": "a8885c",
    "canvas": "d9d2bc", "canvas_dark": "b9b095", "canvas_stain": "a79e83",
    "cable": "2a3231", "charcoal": "242a28", "iron": "4a4e4c", "iron_light": "6b706c",
    "verdigris": "5f8a7c", "rust": "8a5a44", "bone": "d2c5a5", "soil": "6a5a42",
    "leaf": "6f7f4a", "leaf_dark": "4f5e38", "dry_grass": "a39a64",
}
BANNED = {"ff5a3c", "9dff3c", "8bf0d3"}  # HAZARD, ANCIENT, MINT
# A colour this close (Euclidean, 0..1 sRGB) to a banned hex reads as that hex, so it fails too.
BANNED_NEAR = 0.08
WARN = {"e5a044", "b77843", "d9b44a"}  # AMBER, COPPER (never dominant), BRASS (Fleet only)


def hexcolor(c):
    """Palette name, hex string or sRGB triple -> 6-digit hex string."""
    if isinstance(c, str):
        c = C.get(c, c).lstrip("#").lower()
        if len(c) != 6:
            raise ValueError("bad colour " + c)
        return c
    return "".join("%02x" % round(max(0.0, min(1.0, x)) * 255) for x in c)


def _distance(a, b):
    """Euclidean distance of two 6-digit hexes in 0..1 sRGB."""
    return math.sqrt(sum((int(a[i:i + 2], 16) - int(b[i:i + 2], 16)) ** 2 for i in (0, 2, 4))) / 255


def check_colour(c, quiet=False):
    """Hard readability rule: no banned hexes, no hot red/orange stripes. The exact WARN hexes (AMBER, COPPER, BRASS) only warn."""
    h = hexcolor(c)
    if h in BANNED:
        raise ValueError("banned colour #" + h)
    for banned in BANNED:
        if _distance(h, banned) < BANNED_NEAR:
            raise ValueError("colour #%s is within %.2f of banned #%s" % (h, BANNED_NEAR, banned))
    if h in WARN:
        if not quiet:
            print("KIT warning: #%s is AMBER/COPPER/BRASS; never dominant, brass is Fleet-only" % h, flush=True)
        return h
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    if sat > 0.65 and val > 0.75 and (hue < 0.13 or hue > 0.95):
        raise ValueError("hazard-like colour #" + h)
    return h


def _selftest_colours():
    for ok in ("d9b44a", "e5a044", "b77843", "6f7f4a"):
        check_colour(ok, quiet=True)
    for bad in ("ff5a3c", "9dff3c", "8bf0d3", "ff3a20", "ff8a1c", "f95a3c", "9bff3a", "8bf0d8", "90f0d0"):
        try:
            check_colour(bad, quiet=True)
        except ValueError:
            continue
        raise AssertionError("colour #%s should fail check_colour" % bad)


_selftest_colours()


# --- board palette (opt-in per park; DRESSING-KITS.md "Board palette check") -----------------
# A park declares the swatches of its reference boards (docs/art/reference/); every painted colour must then
# sit on them. Known limit: the shared base palette `C` is not itself board-checked; it is accepted as the
# shared material set (sandstone, timber, canvas, iron ...) and is not park-specific. The snapshot is taken here,
# before any park script runs C.update(...), so a park's own additions get no free pass.
BASE_C = dict(C)
REPO = HERE.parents[5]
BOARD_ROOT = REPO / "docs" / "art" / "reference"
# Within this Euclidean distance (0..1 sRGB) of a swatch or approved hex counts as that colour: about 13/255 on
# each channel, the 0.05 that tint()'s default 0.08 value jitter moves a mid colour (0.08 x ~0.6), which covers
# hand-sampled swatch rounding and 8-bit quantisation.
BOARD_NEAR = 0.05
# An approved shade of a swatch keeps its hue and saturation and only changes value, as shade() and tint() do.
# 0.03 hue (about 11 degrees of 360) absorbs 8-bit quantisation of dark colours; a 0.08 hue shift fails.
SHADE_HUE = 0.03
SHADE_SAT = 0.08   # absolute saturation difference, same reason
# shade(c, 0.75) passes; tint() at its default amount spans 0.92..1.08; 1.25 allows a lightened wear tone.
SHADE_VAL_MIN, SHADE_VAL_MAX = 0.70, 1.25
BRASS_HEX = "d9b44a"  # the WARN brass: Fleet only, one tag per site
BRASS_TAG_PARTS = 4   # a plate plus its rivets
BRASS_TAG_BOX = 0.6   # metres: every brass face centre of a variant lies inside a box this size
# Known limit: the kit sees one variant at a time, so "one tag per site" (per vignette) is not checkable here.


def _hsv(h):
    return colorsys.rgb_to_hsv(*(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))


def is_shade_of(h, base):
    """True when h is an approved shade of base: same hue and saturation, value within the shade range."""
    hh, hs, hv = _hsv(h)
    bh, bs, bv = _hsv(base)
    if abs(hs - bs) > SHADE_SAT:
        return False
    if max(hs, bs) >= 0.10:  # greys have no meaningful hue
        d = abs(hh - bh)
        if min(d, 1.0 - d) > SHADE_HUE:
            return False
    return SHADE_VAL_MIN * bv <= hv <= SHADE_VAL_MAX * bv + 1.0 / 255


def check_board(c, board, where="?"):
    """Hard fail unless colour c is on the board (see the four ways in the card). board = {"swatches", "approved"} hex dicts."""
    h = hexcolor(c)
    swatches, approved = board["swatches"], board["approved"]
    for sw in swatches:
        if _distance(h, sw) <= BOARD_NEAR or is_shade_of(h, sw):
            return h
    for ap in approved:
        if _distance(h, ap) <= BOARD_NEAR:
            return h
    for base in BASE_C.values():
        if h == base or is_shade_of(h, base):
            return h
    near = min(swatches, key=lambda s: _distance(h, s))
    raise ValueError("off-board colour #%s in %s: nearest swatch #%s (%s) at %.3f"
                     % (h, where, near, swatches[near], _distance(h, near)))


def check_brass(where, centres):
    """centres: one list of face centres (x, y, z) per primitive painted in brass. They must form one tag."""
    if not centres:
        return
    pts = [p for prim in centres for p in prim]
    span = max(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3))
    if len(centres) > BRASS_TAG_PARTS or span > BRASS_TAG_BOX:
        raise ValueError("%s: brass on %d primitives spanning %.2f m; brass is one Fleet tag per site"
                         % (where, len(centres), span))


def make_board(park, board, root=None):
    """Validate a park's board declaration and return it normalised (lower-case hex)."""
    def hx(v, what):
        v = str(v).lstrip("#").lower()
        if len(v) != 6 or any(ch not in "0123456789abcdef" for ch in v):
            raise ValueError("%s: board %s #%s is not a 6-digit hex" % (park, what, v))
        check_colour(v, quiet=True)
        return v
    out = {"boards": list(board.get("boards", [])), "swatches": {}, "approved": {}}
    if not out["boards"]:
        raise ValueError(park + ": a board declares at least one reference board path")
    for path in out["boards"]:
        if not ((root or BOARD_ROOT) / path).exists():
            raise ValueError("%s: board %s not found under docs/art/reference/" % (park, path))
    for k, label in board.get("swatches", {}).items():
        out["swatches"][hx(k, "swatch")] = label
    if not out["swatches"]:
        raise ValueError(park + ": a board declares at least one swatch")
    for k, reason in board.get("approved", {}).items():
        if not str(reason).strip():
            raise ValueError("%s: approved #%s needs a reason" % (park, k))
        out["approved"][hx(k, "approved")] = reason
    return out


def mix(a, b, t):
    """Blend two colours; t = 0 gives a."""
    ca, cb = common.srgb(hexcolor(a)), common.srgb(hexcolor(b))
    return hexcolor(tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3)))


def shade(c, f):
    """Multiply value: f < 1 darkens, f > 1 lightens (clamped)."""
    return hexcolor(tuple(x * f for x in common.srgb(hexcolor(c))))


def tint(c, rng, amount=0.08):
    """Small seeded value jitter, so planks and stones differ."""
    return shade(c, 1.0 + rng.uniform(-amount, amount))


def _selftest_board():
    import tempfile
    board = {"swatches": {"365754": "petrol", "d2c5a5": "bone"}, "approved": {mix("365754", "d2c5a5", 0.5): "petrol-bone mix"}}
    rng = random.Random("selftest")
    for ok in ("365754", "d2c5a5", shade("365754", 0.75), tint("d2c5a5", rng), tint("365754", rng),
               board["approved"] and next(iter(board["approved"])), C["timber"], shade(C["timber"], 0.75)):
        check_board(ok, board, "selftest")
    for _ in range(200):
        for sw in board["swatches"]:
            check_board(tint(sw, rng), board, "selftest")
    for bad in ("3a5fa8", "e060a0"):  # planted off-board colours: mid saturated blue, pink
        try:
            check_board(bad, board, "selftest_a")
        except ValueError as e:
            assert str(e).startswith("off-board colour #%s in selftest_a: nearest swatch #" % bad), e
            continue
        raise AssertionError("colour #%s should fail check_board" % bad)
    C["selftest_planted"] = "3a5fa8"  # a park's own C.update(...) must not put a colour on board
    try:
        check_board("3a5fa8", board, "selftest")
    except ValueError:
        pass
    else:
        raise AssertionError("a colour added to C after import should fail check_board")
    finally:
        del C["selftest_planted"]
    hh, hs, hv = _hsv("365754")  # a 0.08 hue shift of petrol must fail
    shifted = hexcolor(colorsys.hsv_to_rgb((hh + 0.08) % 1.0, hs, hv))
    try:
        check_board(shifted, {"swatches": {"365754": "petrol"}, "approved": {}}, "selftest")
    except ValueError:
        pass
    else:
        raise AssertionError("a 0.08 hue shift should fail check_board")
    box = lambda x: [(x, 0.0, 0.0)]
    check_brass("selftest", [])
    check_brass("selftest", [box(0.0), box(0.2)])
    for bad in ([box(0.0)] * 5, [box(0.0), box(2.0)]):
        try:
            check_brass("selftest", bad)
        except ValueError as e:
            assert "one Fleet tag per site" in str(e)
            continue
        raise AssertionError("brass %r should fail check_brass" % (bad,))
    tmp = tempfile.TemporaryDirectory()
    root = Path(tmp.name)  # the self-test must not depend on the checkout's docs
    (root / "board.png").write_bytes(b"")
    for bad in ({"boards": ["no-such-board.png"], "swatches": {"365754": "p"}},
                {"boards": ["board.png"], "swatches": {"36575": "p"}},
                {"boards": ["board.png"], "swatches": {"365754": "p"}, "approved": {"3a5fa8": " "}},
                {"boards": ["board.png"], "swatches": {"ff5a3c": "banned"}}):
        try:
            make_board("selftest", bad, root)
        except ValueError:
            continue
        raise AssertionError("board %r should fail make_board" % (bad,))
    make_board("selftest", {"boards": ["board.png"], "swatches": {"365754": "p"}, "approved": {"3a5fa8": "kept"}}, root)
    tmp.cleanup()


_selftest_board()


# (bevel metres, subsurf levels) per look.
STYLES = {
    "hard": (0.04, 0),         # machinery, slabs, planks: crisp edges with a rounded bevel
    "hard_smooth": (0.04, 1),  # bevelled and softened: toy-like blocks
    "fine": (0.015, 0),        # thin boards, straps, small hard bits
    "round": (0.0, 1),         # drums, hubs, rims, rods
    "soft": (0.0, 2),          # cloth, sacks, plants, mud: chunky blobs, smooth
    "flat": (0.0, 0),          # thin sheets and decals as drawn
}


class Prop:
    """Prop builder handed to a kind's builder as `p`. Blender Z up; every helper takes a
    colour (palette name, hex, or kit.C entry) and a `style` from STYLES. `jit` jitters the
    primitive's vertices by that many metres with the variant's seeded rng. Helpers return
    the new faces."""

    def __init__(self, name, rng, board=None):
        common.reset()
        self.name = name
        self.rng = rng
        self.board = board
        self.brass = []  # face centres per primitive painted in brass
        self.root = common.empty(name)
        self.parts = {}
        self.perch_at = None

    def perch(self, point):
        """Optional perch anchor (design-v3/park/PERCH-ANCHOR.md): the centre of a flat deck a Dispatcher may stand
        on, in the authoring frame (Blender Z up, before the kit recentres the model). Only variants 6 m tall or
        more export it; without a point the kit uses the top-centre of the highest face."""
        self.perch_at = Vector(point)

    def part(self, style):
        if style not in STYLES:
            raise ValueError("unknown style " + style)
        if style not in self.parts:
            part = common.Part("Surface." + style)
            part.bevel, part.subsurf = STYLES[style]
            self.parts[style] = part
        return self.parts[style]

    def _paint_ok(self, color):
        """check_colour, then the board check (when a board is declared); returns the hex."""
        h = check_colour(color)
        if self.board:
            check_board(h, self.board, self.name)
        return h

    def _note_brass(self, h, faces):
        if _distance(h, BRASS_HEX) < BANNED_NEAR:
            self.brass.append([tuple(f.calc_center_median()) for f in faces])

    def _do(self, style, method, color, jit, *args, **kwargs):
        part = self.part(style)
        h = self._paint_ok(color)
        faces = getattr(part, method)("paint", *args, color=h, **kwargs)
        self._note_brass(h, faces)
        if jit:
            part.jitter(faces, self.rng, jit)
        return faces

    def box(self, size, loc, color, rot=(0, 0, 0), style="hard", jit=0):
        return self._do(style, "box", color, jit, size, loc=loc, rot=rot)

    def cyl(self, radius, depth, loc, color, segs=10, rot=(0, 0, 0), r2=None, style="hard", jit=0):
        """Cylinder along local Z (rot to lay it down); r2 tapers the top."""
        return self._do(style, "cyl", color, jit, radius, radius if r2 is None else r2, depth,
                        segs=segs, loc=loc, rot=rot)

    def rod(self, a, b, radius, color, segs=6, r2=None, style="round", jit=0):
        return self._do(style, "rod", color, jit, a, b, radius, segs=segs, r2=r2)

    def beam(self, a, b, width, color, h=None, roll=0.0, style="hard", jit=0):
        """Square-section beam from a to b (h = other side, roll about its axis)."""
        return self._do(style, "beam", color, jit, a, b, width, h=h, roll=roll)

    def uv(self, radius, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), u=8, v=6, style="round", jit=0):
        return self._do(style, "uv", color, jit, radius, u=u, v=v, loc=loc, scale=scale, rot=rot)

    def ico(self, radius, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), subdiv=1, style="soft", jit=0):
        return self._do(style, "ico", color, jit, radius, subdiv=subdiv, loc=loc, scale=scale, rot=rot)

    def ring(self, r_in, r_out, depth, loc, color, segs=12, rot=(0, 0, 0), arc=(0.0, 2 * math.pi),
             style="hard", jit=0):
        """Flat annulus with thickness (or an arc of one), axis along local Z."""
        return self._do(style, "ring", color, jit, r_in, r_out, depth, segs=segs, loc=loc, rot=rot, arc=arc)

    def prism(self, outline, depth, loc, color, rot=(0, 0, 0), style="hard", jit=0):
        """Extrudes a 2D outline [(x, y), ...] along local Z, centred, at loc/rot."""
        return self._do(style, "prism", color, jit, outline, depth, matrix=common.mtx(loc, rot))

    def torus(self, big, small, loc, color, rot=(0, 0, 0), scale=(1, 1, 1), major=12, minor=6,
              style="round", jit=0):
        """Torus about local Z: ring radius `big`, tube radius `small`."""
        part = self.part(style)
        m = common.mtx(loc, rot, scale)
        rows = []
        for i in range(major):
            t = math.tau * i / major
            row = []
            for j in range(minor):
                f = math.tau * j / minor
                rr = big + small * math.cos(f)
                row.append(part.bm.verts.new(m @ Vector((rr * math.cos(t), rr * math.sin(t), small * math.sin(f)))))
            rows.append(row)
        faces = [part.bm.faces.new((rows[i][j], rows[(i + 1) % major][j],
                                    rows[(i + 1) % major][(j + 1) % minor], rows[i][(j + 1) % minor]))
                 for i in range(major) for j in range(minor)]
        h = self._paint_ok(color)
        part.paint(faces, "paint", h)
        self._note_brass(h, faces)
        if jit:
            part.jitter(faces, self.rng, jit)
        return faces

    def chain(self, a, b, color, link=0.14, radius=0.02, sag=0.1, style="round"):
        """Hanging chain of alternating links from a to b, sagging by `sag` metres (never taut)."""
        a, b = Vector(a), Vector(b)
        n = max(2, int((b - a).length / (link * 0.8)))
        d = (b - a).normalized()
        for k in range(n + 1):
            t = k / n
            pos = a.lerp(b, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
            # The link's long axis (local X) follows the chord; odd links roll a quarter turn.
            quat = Quaternion(d, math.pi / 2 * (k % 2)) @ Vector((1, 0, 0)).rotation_difference(d)
            self.torus(link * 0.5, radius, pos, color, rot=quat.to_euler(), scale=(1.0, 0.7, 1.0),
                       major=6, minor=4, style=style)

    def finish(self):
        """Joins the parts into one 'Surface' mesh at the foot centre, floor at z = 0."""
        objs = [self.parts[k].to_object(parent=self.root) for k in sorted(self.parts)]
        if not objs:
            raise ValueError(self.name + ": the builder drew nothing")
        check_brass(self.name, self.brass)
        obj = objs[0]
        if len(objs) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.join()
        obj.name = obj.data.name = "Surface"
        # Origin at the foot centre: bbox xy centre, lowest point on the floor.
        me = obj.data
        lo = Vector((min(v.co[i] for v in me.vertices) for i in range(3)))
        hi = Vector((max(v.co[i] for v in me.vertices) for i in range(3)))
        shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
        me.transform(Matrix.Translation(shift))
        me.update()
        if self.perch_at is not None:
            obj["perch_local"] = list(self.perch_at + shift)
        return obj


# --- shared sight gags (W46-07): jokes told by objects, no words (ruling cx) -------------------------
# The old works' hand (design-v3/STORY-MAP.md section 2): cast, seamless, no fastener, pristine. The keepers' hand: chalk
# white and a ball-shaped dent. Each park recipe registers them with K.kind(...)(kit.foreman_billboard), so the dam and
# the flume carry the same two kinds. Authored in real metres, Blender Z up, front (the joke's face) toward -Y.
GAG_CAST = "b8b7ae"     # concrete_light: the works' cast body, never rusted, never bolted
GAG_FACE = "d9d2bc"     # canvas: the notice's pristine face
GAG_WATER = "5f8a7c"    # verdigris: water on the notice
GAG_INK = "242a28"      # charcoal: the notice's print
GAG_CHALK = "e6e3d6"    # chalk white: the keepers' marks
GAG_GLOVE = "b9b095"    # canvas_dark: a cast work glove
_FACE_ROT = (math.pi / 2, 0, 0)  # local Z to -Y: a prism outline (x, y) draws as (x, up) on the face


def _stroke(p, a, b, z_y, width=0.09, color=GAG_CHALK):
    """A chalk stroke on a face plane at depth z_y: a thin box from a to b, both (x, up)."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dz)
    p.box((ln + width * 0.5, 0.03, width), ((a[0] + b[0]) / 2, z_y, (a[1] + b[1]) / 2), color,
          rot=(0, -math.atan2(dz, dx), 0), style="flat")


def _chalk_path(p, pts, z_y, rng, wobble=0.05, width=0.09):
    """A hand-drawn chalk line through pts, each joint nudged so it never reads as printed."""
    q = [(x + rng.uniform(-wobble, wobble), z + rng.uniform(-wobble, wobble)) for x, z in pts]
    for a, b in zip(q, q[1:]):
        _stroke(p, a, b, z_y, width)


def _dent(p, cx, cz, r, face_y, rng):
    """A ball came through from behind: a dark hole, the face's torn petals curled out toward you, cracks running out.
    The face is one solid slab (no boolean), so the hole is a dark disc laid just proud of it."""
    front = face_y - 0.08
    p.cyl(r, 0.04, (cx, front - 0.02, cz), GAG_INK, segs=20, rot=_FACE_ROT, style="flat")
    n = 9
    for k in range(n):
        a = math.tau * (k + rng.uniform(-0.2, 0.2)) / n
        rr = r * rng.uniform(0.95, 1.08)
        p.box((r * 0.55, 0.05, r * 0.5), (cx + rr * math.cos(a), front - 0.14, cz + rr * math.sin(a)), GAG_FACE,
              rot=(0.75, math.pi / 2 - a, 0), style="fine")
    for k in range(6):
        a = rng.uniform(0, math.tau)
        r0, r1 = r * 1.1, r * rng.uniform(1.5, 2.2)
        _stroke(p, (cx + r0 * math.cos(a), cz + r0 * math.sin(a)), (cx + r1 * math.cos(a + 0.12), cz + r1 * math.sin(a + 0.12)),
                front - 0.01, width=0.06, color=GAG_INK)


def foreman_billboard(p, v, rng):
    """The Foreman's notice board: a 10 by 5 m cast face on two seamless legs, a pictogram printed square on it, and
    the keepers' answer. a: water drop with a barcode, an arrow, a crate (all water is inventory); a ball went through
    the arrow and chalk rings the hole with a tally. b: four bars climbing to a perfect arrow (efficiency up); a chalk
    river snakes over the bars to a chalk ball, and a small dent sits where the arrow meets the frame."""
    W, H, Z0 = 10.0, 5.0, 3.4
    zc = Z0 + H / 2
    for s in (-1, 1):
        p.box((0.7, 0.7, 0.36), (s * 3.4, 0.0, 0.18), GAG_CAST, style="hard_smooth")
        p.box((0.5, 0.5, Z0 + 0.4), (s * 3.4, 0.05, (Z0 + 0.4) / 2), GAG_CAST, style="hard_smooth")
    p.box((W + 0.5, 0.5, H + 0.5), (0, 0.1, zc), GAG_CAST, style="hard_smooth")
    face_y = -0.18
    p.box((W, 0.08, H), (0, face_y, zc), GAG_FACE, style="flat")
    for k in range(4):  # the back's cast ribs, one pour with the frame
        p.box((0.25, 0.3, H + 0.2), (-3.6 + 2.4 * k, 0.45, zc), GAG_CAST, style="hard")
    for s in (-1, 1):  # fluted legs on round cast footings
        p.cyl(0.55, 0.3, (s * 3.4, 0.0, 0.5), GAG_CAST, segs=20, style="round")
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            p.box((0.12, 0.12, Z0 - 0.2), (s * 3.4 + 0.3 * math.cos(a), 0.05 + 0.3 * math.sin(a), (Z0 - 0.2) / 2 + 0.35),
                  GAG_CAST, style="hard_smooth")
    # The service ledge under the face, one pour with the frame, its grating cast in.
    p.box((W + 0.2, 1.1, 0.18), (0, -0.55, Z0 - 0.15), GAG_CAST, style="hard_smooth")
    for k in range(12):
        p.box((0.08, 1.0, 0.06), (-4.95 + 0.9 * k, -0.6, Z0 - 0.02), GAG_INK, style="fine")
    # Three lamps on swan-neck arms light the notice from above, so it reads at dusk too.
    for k in (-1, 0, 1):
        x = k * 3.4
        p.rod((x, 0.2, Z0 + H + 0.2), (x, -0.4, Z0 + H + 0.9), 0.09, GAG_CAST, segs=10, style="round")
        p.rod((x, -0.4, Z0 + H + 0.9), (x, -1.1, Z0 + H + 0.8), 0.09, GAG_CAST, segs=10, style="round")
        p.cyl(0.42, 0.3, (x, -1.2, Z0 + H + 0.62), GAG_CAST, segs=20, r2=0.18, style="round")
        p.cyl(0.36, 0.04, (x, -1.2, Z0 + H + 0.46), GAG_FACE, segs=20, style="flat")
    fy = face_y - 0.06  # print sits just proud of the face
    if v == "a":
        drop = [(0.0, 1.55)] + [(1.05 * math.cos(math.radians(a)), -0.35 + 1.05 * math.sin(math.radians(a)))
                                for a in range(20, -201, -20)]
        p.prism(drop, 0.05, (-3.2, fy, zc - 0.05), GAG_WATER, rot=_FACE_ROT, style="flat")
        for k, w in enumerate((0.1, 0.06, 0.14, 0.06, 0.1, 0.16, 0.06)):
            p.box((w, 0.03, 0.9), (-3.65 + 0.15 * k, fy - 0.03, zc - 0.35), GAG_INK, style="flat")
        p.box((1.7, 0.04, 0.22), (-0.9, fy, zc), GAG_INK, style="flat")
        p.prism([(0.0, 0.45), (0.6, 0.0), (0.0, -0.45)], 0.04, (-0.05, fy, zc), GAG_INK, rot=_FACE_ROT, style="flat")
        for (bx, bz, bw, bh) in ((2.9, zc + 1.0, 2.4, 0.2), (2.9, zc - 1.0, 2.4, 0.2), (1.8, zc, 0.2, 2.2), (4.0, zc, 0.2, 2.2)):
            p.box((bw, 0.04, bh), (bx, fy, bz), GAG_WATER, style="flat")
        p.box((2.6, 0.035, 0.16), (2.9, fy, zc), GAG_WATER, rot=(0, -0.72, 0), style="flat")
        _dent(p, -0.6, zc + 0.15, 0.85, face_y, rng)
        ring = [(-0.6 + 1.45 * math.cos(a) * (1 + 0.06 * math.sin(3 * a)), zc + 0.15 + 1.3 * math.sin(a))
                for a in [math.tau * k / 12 for k in range(13)]]
        _chalk_path(p, ring, fy - 0.04, rng)
        for k in range(4):
            _chalk_path(p, [(0.9 + 0.28 * k, zc - 2.05), (0.95 + 0.28 * k, zc - 1.35)], fy - 0.04, rng, wobble=0.03)
        _chalk_path(p, [(0.75, zc - 1.55), (2.05, zc - 1.8)], fy - 0.04, rng, wobble=0.03)
    else:
        for k, h in enumerate((0.8, 1.4, 2.1, 2.9)):
            p.box((0.8, 0.04, h), (-3.6 + 1.25 * k, fy, Z0 + 0.6 + h / 2), GAG_WATER, style="flat")
        a0, a1 = (-4.2, Z0 + 1.2), (1.9, Z0 + 4.2)
        ang = math.atan2(a1[1] - a0[1], a1[0] - a0[0])
        p.box((math.dist(a0, a1), 0.035, 0.18), ((a0[0] + a1[0]) / 2, fy - 0.02, (a0[1] + a1[1]) / 2), GAG_INK,
              rot=(0, -ang, 0), style="flat")
        p.prism([(0.0, 0.4), (0.7, 0.0), (0.0, -0.4)], 0.04, (a1[0], fy - 0.02, a1[1]), GAG_INK,
                rot=(math.pi / 2, -ang, 0), style="flat")
        river = [(-4.6 + 0.55 * k, Z0 + 2.4 + 0.75 * math.sin(k * 0.9)) for k in range(15)]
        _chalk_path(p, river, fy - 0.05, rng, wobble=0.04, width=0.12)
        end = river[-1]
        ball = [(end[0] + 0.75 + 0.55 * math.cos(a), end[1] + 0.55 * math.sin(a)) for a in [math.tau * k / 10 for k in range(11)]]
        _chalk_path(p, ball, fy - 0.05, rng, wobble=0.02, width=0.1)
        for k in range(3):
            _chalk_path(p, [(end[0] - 0.1 - 0.25 * k, end[1] + 0.35 - 0.3 * k), (end[0] - 0.7 - 0.25 * k, end[1] + 0.35 - 0.3 * k)],
                        fy - 0.05, rng, wobble=0.02, width=0.07)
        _dent(p, 3.7, Z0 + 4.2, 0.55, face_y, rng)


def _glove(p, x, y, z, yaw=0.0, color=GAG_GLOVE):
    """A giant cast work glove lying palm down, fingers toward -Y (before yaw), cuff behind."""
    c, s = math.cos(yaw), math.sin(yaw)

    def at(lx, ly, lz):
        return (x + c * lx - s * ly, y + s * lx + c * ly, z + lz)
    p.box((0.42, 0.44, 0.12), at(0.0, 0.0, 0.06), color, rot=(0, 0, yaw), style="hard")
    p.cyl(0.19, 0.3, at(0.0, 0.36, 0.1), color, segs=10, rot=(math.pi / 2, 0, yaw), style="hard")
    for k in range(4):
        p.box((0.085, 0.3 - 0.03 * abs(k - 1.5), 0.09), at(-0.15 + 0.1 * k, -0.34 + 0.015 * abs(k - 1.5), 0.05), color,
              rot=(0, 0, yaw), style="hard")
    p.box((0.09, 0.24, 0.09), at(0.27, -0.1, 0.05), color, rot=(0, 0, yaw - 0.6), style="hard")


def shift_table(p, v, rng):
    """A cast shift table set for a crew that left: benches, a punch clock stopped on the bell, and giant cast gloves
    laid out square at every place, waiting. a: four places, all set. b: one glove gone, and the keepers chalked its
    outline on the table where it lay."""
    L, top = 4.2, 0.95
    p.box((L, 1.2, 0.12), (0, 0, top), GAG_CAST, style="hard")
    for s in (-1, 1):
        p.box((0.32, 0.9, top - 0.06), (s * 1.6, 0, (top - 0.06) / 2), GAG_CAST, style="hard")
        p.box((L - 0.2, 0.38, 0.1), (0, s * 1.0, 0.5), GAG_CAST, style="hard")
        for k in (-1, 1):
            p.box((0.26, 0.32, 0.45), (k * 1.5, s * 1.0, 0.225), GAG_CAST, style="hard")
    places = (-1.5, -0.5, 0.5, 1.5)
    for k, x in enumerate(places):
        if v == "b" and k == 2:
            outline = [(x - 0.22, -0.2), (x - 0.22, 0.25), (x + 0.22, 0.25), (x + 0.22, -0.2), (x + 0.2, -0.5),
                       (x - 0.18, -0.5), (x - 0.22, -0.2)]
            for a, b in zip(outline, outline[1:]):
                dx, dy = b[0] - a[0], b[1] - a[1]
                p.box((math.hypot(dx, dy) + 0.03, 0.05, 0.012), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, top + 0.066),
                      GAG_CHALK, rot=(0, 0, math.atan2(dy, dx)), style="flat")
            continue
        _glove(p, x, -0.12, top + 0.06)
        p.cyl(0.09, 0.16, (x, 0.42, top + 0.14), GAG_CAST, segs=10, style="hard")  # a cast cup at each place
    # The punch clock at the table's head: a cast post, a dial with both hands straight up.
    hx = L / 2 + 0.6
    p.box((0.5, 0.5, 0.2), (hx, 0, 0.1), GAG_CAST, style="hard")
    p.cyl(0.11, 1.5, (hx, 0, 0.95), GAG_CAST, segs=10, style="hard")
    p.cyl(0.34, 0.14, (hx, -0.02, 1.85), GAG_CAST, segs=16, rot=_FACE_ROT, style="hard")
    p.cyl(0.28, 0.03, (hx, -0.1, 1.85), GAG_FACE, segs=16, rot=_FACE_ROT, style="flat")
    p.box((0.04, 0.03, 0.22), (hx, -0.13, 1.95), GAG_INK, style="flat")
    p.box((0.05, 0.03, 0.15), (hx, -0.135, 1.92), GAG_INK, style="flat")


def drop_open_islands(mesh):
    """Deletes every connected island of mesh that has an open edge or fewer than four faces (a part the collapse shrank
    to loose triangles, or to a front-and-back pair with no volume, which the export does not keep closed)."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    seen, doomed = set(), []
    for face in bm.faces:
        if face.index in seen:
            continue
        island, stack, open_edge = [], [face], False
        seen.add(face.index)
        while stack:
            f = stack.pop()
            island.append(f)
            for e in f.edges:
                if len(e.link_faces) < 2:
                    open_edge = True
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        if open_edge or len(island) < 4:
            doomed.extend(island)
    if doomed:
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(mesh)
    bm.free()


class Kit:
    def __init__(self, park, polish_opts=None, board=None):
        self.park = park
        self.board = make_board(park, board) if board else None
        if not board:
            print("KIT note: %s declares no board palette; the board check is off" % park, flush=True)
        self.kinds = {}
        # Kinds whose LODs must stay closed (check_manifold.py --strict): a collapse that shrinks a small closed part to
        # a lone open triangle drops that part instead. Opt-in, so a kit's other kinds export as they always have.
        self.closed_lods = set()
        self._exporting = None
        self.polish_opts = dict(detail=2, bevel=0.04, bevel_min=0.08)
        self.polish_opts.update(polish_opts or {})
        assert self.polish_opts["detail"] >= 1, "polish detail %r: common _segs(n) returns 0 below 1 and every cylinder and sphere vanishes" % (self.polish_opts["detail"],)

    def kind(self, name, hero=False, tags=(), story="", variants="ab", polish_opts=None, line_clear_m=None):
        def deco(fn):
            if name in self.kinds:
                raise ValueError("duplicate kind " + name)
            if not 1 <= len(variants) <= 3:
                raise ValueError("2 or 3 variants per kind (1 allowed only while drafting)")
            self.kinds[name] = {"fn": fn, "class": "dress_hero" if hero else "dress_prop",
                                "tags": list(tags), "story": story, "variants": list(variants),
                                "polish": dict(polish_opts or {}), "line_clear_m": line_clear_m}
            return fn
        return deco

    # --- build ------------------------------------------------------------------------
    def build(self, kind, variant):
        spec = self.kinds[kind]
        rng = random.Random("%s/%s/%s" % (self.park, kind, variant))
        opts = dict(self.polish_opts, **spec["polish"])
        assert opts["detail"] >= 1, "%s: polish detail %r; common _segs(n) returns 0 below 1 and every cylinder and sphere vanishes" % (kind, opts["detail"])
        polish.enable(**opts)
        p = Prop("%s_%s" % (kind, variant), rng, self.board)
        spec["fn"](p, variant, rng)
        return p.root, p.finish()

    def main(self, argv=None):
        ap = argparse.ArgumentParser()
        ap.add_argument("--out-dir", type=Path)
        ap.add_argument("--only")
        ap.add_argument("--count-only", action="store_true")
        ap.add_argument("--preview-dir", type=Path)
        argv = sys.argv[sys.argv.index("--") + 1:] if argv is None and "--" in sys.argv else (argv or [])
        opts = ap.parse_args(argv)
        names = list(self.kinds)
        if opts.only:
            names = opts.only.split(",")
            missing = [n for n in names if n not in self.kinds]
            if missing:
                sys.exit("unknown kinds: " + ", ".join(missing))
        default = SKETCH / "assets" / "models" / "park" / "props" / self.park
        out_dir = opts.out_dir or default
        failures = []
        results = {}
        for kind in names:
            for v in self.kinds[kind]["variants"]:
                try:
                    results[(kind, v)] = (self.count(kind, v) if opts.count_only
                                          else self.export(kind, v, out_dir))
                except AssertionError as e:
                    failures.append(str(e))
                    print("KIT FAIL", e, flush=True)
        if failures:
            print("KIT: %d budget failure(s)" % len(failures), flush=True)
            sys.exit(1)
        if opts.count_only:
            return
        self.write_manifest(out_dir, names, results)
        if opts.out_dir is None:
            self.write_registry(out_dir)
            self.write_import_stubs(out_dir)
        if opts.preview_dir:
            self.preview(out_dir, opts.preview_dir, names)

    # --- budgets ----------------------------------------------------------------------
    def check_lod0(self, kind, variant, tris):
        lo, hi = BUDGET[self.kinds[kind]["class"]]
        assert lo <= tris <= hi, "%s_%s: LOD0 %d tris outside %s %d-%d" % (
            kind, variant, tris, self.kinds[kind]["class"], lo, hi)

    def count(self, kind, variant):
        root, obj = self.build(kind, variant)
        tris = common.tris(obj)
        print("KIT_COUNT %s_%s %s tris %d" % (kind, variant, self.kinds[kind]["class"], tris), flush=True)
        self.check_lod0(kind, variant, tris)
        return tris

    # --- export -----------------------------------------------------------------------
    def export(self, kind, variant, out_dir):
        out_dir.mkdir(parents=True, exist_ok=True)
        root, obj = self.build(kind, variant)
        self._exporting = kind
        base = "%s_%s" % (kind, variant)
        t0 = common.tris(obj)
        self.check_lod0(kind, variant, t0)
        bpy.context.view_layer.update()
        polish.bake(root, polish.options())
        verts = [v.co.copy() for v in obj.data.vertices]
        radius = max(math.hypot(v.x, v.y) for v in verts)
        height = max(v.z for v in verts)
        info = {"radius": round(radius, 3), "height": round(height, 3)}
        if height >= PERCH_MIN_HEIGHT:
            info["perch"] = perch_of(obj, verts)
        stats = [self.write(root, obj, out_dir / (base + ".glb"))]
        assert stats[0]["tris"] == t0, base + ": exported tris differ from mesh tris"
        full = out_dir / (base + ".glb")
        cap = model_audit.COVER_CAP
        for suffix, target, band, floor in (("_lod1", LOD1_TARGET, LOD1_BAND, 0),
                                            ("_lod2", LOD2_TARGET, LOD2_BAND, LOD2_MIN_TRIS)):
            want = max(round(t0 * target), floor)
            path = out_dir / (base + suffix + ".glb")
            raised = False
            while True:
                lod = self.decimate(root, obj, want)
                stat = self.write(root, lod, path)
                fills = model_audit.cover(full, path)
                # Never more than the LOD before it.
                most = min(math.floor(t0 * cap), stats[-1]["tris"])
                if fills >= model_audit.COVER_MIN or want >= most:
                    break
                bpy.data.objects.remove(lod)
                want = min(round(want * COVER_STEP), most)
                raised = True
            stats.append(stat)
            ratio = stats[-1]["tris"] / t0
            top = cap if raised else band[1]
            assert band[0] <= ratio <= top and stats[-1]["tris"] >= floor, \
                "%s%s: %d tris is %.1f%% of LOD0 %d (accept %d-%d%%, min %d)" % (
                    base, suffix, stats[-1]["tris"], ratio * 100, t0, band[0] * 100, top * 100, floor)
            assert stats[-1]["tris"] <= stats[-2]["tris"], "%s%s: %d tris, more than the LOD before it (%d)" % (
                base, suffix, stats[-1]["tris"], stats[-2]["tris"])
            assert not model_audit.under(fills, stats[-1]["tris"], t0, stats[-2]["tris"]), \
                "%s%s: fills %.3f of LOD0's outline at %d tris (want %.2f, or %.2f at the cap)" % (
                    base, suffix, fills, stats[-1]["tris"], model_audit.COVER_MIN, model_audit.COVER_FLOOR)
            if ratio > band[1]:
                print("KIT_COVER %s%s raised to %d tris (%.0f%%) to fill %.3f of LOD0's outline" % (
                    base, suffix, stats[-1]["tris"], ratio * 100, fills), flush=True)
            low = stats[-1]["bounds"][0][1]
            assert abs(low) <= FLOOR_TOL, "%s%s: bottom at y %.3f, not 0" % (base, suffix, low)
            bpy.data.objects.remove(lod)
        info["tris"] = [s["tris"] for s in stats]
        info["bounds"] = [s["bounds"] for s in stats]
        print("KIT_BUILT %s %s tris %s radius %.2f height %.2f" % (
            base, self.kinds[kind]["class"], info["tris"], info["radius"], info["height"]), flush=True)
        return info

    def decimate(self, root, src, want):
        """Collapse-decimated copy of the polished, baked mesh with about `want` triangles."""
        total = common.tris(src)
        mod = src.modifiers.new("lod", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.use_collapse_triangulate = True
        ratio, best = want / total, None
        for _ in range(8):
            mod.ratio = min(1.0, ratio)
            bpy.context.view_layer.update()
            ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
            n = sum(len(p.vertices) - 2 for p in ev.data.polygons)
            if best is None or abs(n - want) < abs(best[0] - want):
                best = (n, mod.ratio)
            if abs(n - want) <= max(2, want * 0.02):
                break
            ratio *= want / max(n, 1)
        mod.ratio = best[1]
        bpy.context.view_layer.update()
        ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = bpy.data.meshes.new_from_object(ev)
        src.modifiers.remove(mod)
        obj = bpy.data.objects.new("lod_tmp", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        common.place(obj, src["world_origin"], root)
        # Collapse can lift or sink the lowest vertex a few centimetres; re-seat the LOD on LOD0's floor so no recipe
        # needs a ground plinth to hold FLOOR_TOL. A shift past RESEAT_MAX means the silhouette broke, so it fails.
        if self._exporting in self.closed_lods:
            drop_open_islands(mesh)
        shift = min(v.co.z for v in src.data.vertices) - min(v.co.z for v in mesh.vertices)
        assert abs(shift) <= RESEAT_MAX, "LOD re-seat of %.3f m exceeds %.2f m" % (shift, RESEAT_MAX)
        for v in mesh.vertices:
            v.co.z += shift
        # Smooth, with LOD0's hard creases taken again from the collapsed shape: smoothing every edge let a fold (a drum
        # flange, a rope coil) average its vertex normals against its faces, so far meshes drew lit inside out (W1-29).
        for poly in mesh.polygons:
            poly.use_smooth = True
        mesh.set_sharp_from_angle(angle=math.radians(polish.options()["sharp_angle"]))
        if mesh.color_attributes.get("Color") is not None:
            mesh.color_attributes.active_color = mesh.color_attributes["Color"]
            mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
        return obj

    def write(self, root, obj, path):
        keep = obj.name
        for o in common.tree(root):
            if o is not obj and o.type == "MESH":
                o.hide_set(True)
        obj.name = obj.data.name = "Surface"
        bpy.ops.object.select_all(action="DESELECT")
        root.select_set(True)
        obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_apply=False, export_yup=True, export_materials="EXPORT",
                                  export_vertex_color="ACTIVE", export_extras=False,
                                  export_animations=False, export_cameras=False, export_lights=False)
        common.canonical_indices(str(path), vertices=True)
        for o in common.tree(root):
            if o.type == "MESH":
                o.hide_set(False)
        obj.name = keep
        return inspect_glb(path)

    # --- manifest, registry -----------------------------------------------------------
    def write_manifest(self, out_dir, names, results):
        path = out_dir / "manifest.json"
        old = json.loads(path.read_text())["kinds"] if path.exists() else {}
        kinds = {}
        for kind, spec in self.kinds.items():
            variants = {}
            for v in spec["variants"]:
                if kind in names:
                    info = results[(kind, v)]
                elif kind in old and v in old[kind]["variants"]:
                    variants[v] = old[kind]["variants"][v]
                    continue
                else:
                    continue
                base = "%s_%s" % (kind, v)
                prefix = "%s%s/" % (RES_ROOT, self.park)
                variants[v] = {"lod": [prefix + base + s + ".glb" for s in ("", "_lod1", "_lod2")],
                               "tris": info["tris"], "radius": info["radius"], "height": info["height"]}
                if "perch" in info:
                    variants[v]["perch"] = info["perch"]
            if not variants:
                continue
            tags = list(spec["tags"])
            if max(x["height"] for x in variants.values()) > 3 and "tall" not in tags:
                tags.append("tall")
            kinds[kind] = {"class": spec["class"], "tags": tags, "story": spec["story"], "variants": variants}
            if spec.get("line_clear_m") is not None:
                kinds[kind]["line_clear_m"] = float(spec["line_clear_m"])
        doc = {"schema": SCHEMA, "park": self.park,
               "recipe": "tools/blender/park/props/%s.py" % self.park, "kinds": kinds}
        path.write_text(json.dumps(doc, indent=1) + "\n")
        print("KIT_MANIFEST", path, flush=True)

    def write_registry(self, out_dir):
        manifest = json.loads((out_dir / "manifest.json").read_text())
        rows = []
        for kind, spec in manifest["kinds"].items():
            for v, var in spec["variants"].items():
                for i, res in enumerate(var["lod"]):
                    info = inspect_glb(out_dir / res.rsplit("/", 1)[1])
                    lo, hi = info["bounds"]
                    rows.append({
                        "id": "dprop_%s_%s_%s%s" % (self.park, kind, v, ("", "_lod1", "_lod2")[i]),
                        "path": res, "class": spec["class"], "ships": True,
                        "loader": LOADER % self.park,
                        "provenance": {"recipe": manifest["recipe"],
                                       "notes": "%s variant %s LOD%d (%d tris): %s Deterministic; Decimate (collapse) copy of the polished, baked LOD0." % (
                                           kind, v, i, var["tris"][i], spec["story"]) if i else
                                       "%s variant %s LOD0 (%d tris): %s Deterministic; polished and baked." % (
                                           kind, v, var["tris"][0], spec["story"])},
                        "bounds": {"min": lo, "max": hi, "size": [round(h - l, 4) for l, h in zip(lo, hi)]}})
        frag = SKETCH / "assets" / "registry.d" / ("park_props_%s.json" % self.park)
        frag.write_text(json.dumps({"assets": rows}, indent=1) + "\n")
        print("KIT_REGISTRY", frag, len(rows), "rows", flush=True)

    def write_import_stubs(self, out_dir):
        """Godot's automatic mesh LOD generation must be off (the kit ships its own LODs). A
        `.glb.import` that exists keeps its params, so write a stub for any GLB without one;
        Godot fills in the rest (uid, paths) on the next import. Commit the filled files
        (the .gitignore re-includes assets/models/park/props/*/*.glb.import)."""
        for glb in sorted(out_dir.glob("*.glb")):
            imp = Path(str(glb) + ".import")
            if not imp.exists():
                imp.write_text('[remap]\n\nimporter="scene"\ntype="PackedScene"\n\n'
                               '[params]\n\nmeshes/generate_lods=false\n')
                print("KIT_IMPORT_STUB", imp, flush=True)

    # --- preview ----------------------------------------------------------------------
    def preview(self, out_dir, folder, names):
        folder.mkdir(parents=True, exist_ok=True)
        tile = 360
        tiles, strips = [], []
        for kind in names:
            hero = self.kinds[kind]["class"] == "dress_hero"
            for v in self.kinds[kind]["variants"]:
                base = out_dir / ("%s_%s" % (kind, v))
                png = folder / ("%s_%s.png" % (kind, v))
                render([Path(str(base) + ".glb")], png, tile, tile)
                tiles.append((png, "%s_%s" % (kind, v)))
                if hero:
                    strip = folder / ("%s_%s_lods.png" % (kind, v))
                    render([Path(str(base) + s) for s in (".glb", "_lod1.glb", "_lod2.glb")],
                           strip, tile * 3, tile, spread=True)
                    strips.append((strip, "%s_%s  LOD0 / LOD1 / LOD2" % (kind, v)))
        sheet = folder / ("%s_contact_sheet.png" % self.park)
        compose(tiles, strips, sheet, tile)
        print("KIT_SHEET", sheet, flush=True)


def perch_of(obj, verts):
    """The variant's `perch` as [x, y, z] in glTF's frame (Y up, metres, origin at the foot centre): the recipe's point
    (Prop.perch) when given, else the area-weighted centre of the faces within 2 cm of the highest face's height."""
    local = obj.get("perch_local")
    if local is not None:
        x, y, z = (float(c) for c in local)
    else:
        polys = [(p.center, p.area) for p in obj.data.polygons]
        top = max(c.z for c, _ in polys)
        deck = [(c, a) for c, a in polys if c.z >= top - 0.02]
        area = sum(a for _, a in deck) or 1.0
        x = sum(c.x * a for c, a in deck) / area
        y = sum(c.y * a for c, a in deck) / area
        z = sum(c.z * a for c, a in deck) / area
    assert all(math.isfinite(c) for c in (x, y, z)) and z > 0, "perch %r is not above the foot" % ((x, y, z),)
    return [round(x, 3) + 0.0, round(z, 3) + 0.0, round(-y, 3) + 0.0]


def inspect_glb(path):
    """Counts and bounds of a kit GLB; asserts the one-surface, one-material, no-image rule."""
    raw = Path(path).read_bytes()
    gltf = json.loads(raw[20:20 + int.from_bytes(raw[12:16], "little")])
    prims = [p for m in gltf["meshes"] for p in m["primitives"]]
    assert len(prims) == 1, "%s: %d surfaces, want 1" % (Path(path).name, len(prims))
    assert len(gltf["materials"]) == 1 and not gltf.get("images"), Path(path).name + ": one vertex-colour material only"
    assert not any(any(m.get("emissiveFactor", [0])) for m in gltf["materials"]), Path(path).name + ": emissive"
    assert "COLOR_0" in prims[0]["attributes"], Path(path).name + ": no COLOR_0 vertex colours (the props would render white)"
    pos = gltf["accessors"][prims[0]["attributes"]["POSITION"]]
    return {"tris": gltf["accessors"][prims[0]["indices"]]["count"] // 3, "verts": pos["count"],
            "bounds": [[round(x, 4) for x in pos["min"]], [round(x, 4) for x in pos["max"]]],
            "sha256": hashlib.sha256(raw).hexdigest()}


def render(paths, out, width, height, spread=False):
    """Cycles CPU render of one or more imported GLBs (side by side when spread)."""
    common.reset()
    objs = []
    gap = 0.0
    for k, path in enumerate(paths):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        new = [o for o in bpy.data.objects if o not in before]
        if spread:
            meshes = [o for o in new if o.type == "MESH"]
            if k == 0:
                size = max(max(d) for d in (o.dimensions for o in meshes))
                gap = size * 1.25
            for o in new:
                if o.parent is None:
                    o.location.x += gap * (k - (len(paths) - 1) / 2)
        objs += new
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    cycles_device.use(scene)
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("fill")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = common.rgba("a9b6c0")
    bg.inputs["Strength"].default_value = 0.8
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, lo.z - 0.005))
    bpy.context.object.data.materials.append(common._flat("floor", "8a8372"))
    light = bpy.data.lights.new("sun", "AREA")
    light.energy, light.shape, light.size = 1200, "DISK", 6
    sun = bpy.data.objects.new("sun", light)
    scene.collection.objects.link(sun)
    sun.location = (-4, -5, hi.z + 7)
    centre = (lo + hi) / 2
    sun.rotation_euler = (centre - sun.location).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    direction = Vector((0.9, -1.3, 0.75)).normalized()
    cam.location = centre + direction * 30
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    inv = cam.rotation_euler.to_matrix().transposed()
    ip = [inv @ (p - centre) for p in pts]
    w = max(p.x for p in ip) - min(p.x for p in ip)
    h = max(p.y for p in ip) - min(p.y for p in ip)
    cam.data.ortho_scale = max(w, h * width / height) * 1.15
    cam.location += cam.rotation_euler.to_matrix() @ Vector(
        (-(max(p.x for p in ip) + min(p.x for p in ip)) / 2, -(max(p.y for p in ip) + min(p.y for p in ip)) / 2, 0))
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)


def compose(tiles, strips, out, tile, cols=4):
    from PIL import Image, ImageDraw
    pad = 18
    rows = (len(tiles) + cols - 1) // cols
    width = max(cols * tile, 3 * tile)
    height = rows * (tile + pad) + len(strips) * (tile + pad)
    sheet = Image.new("RGB", (width, height), (36, 42, 40))
    draw = ImageDraw.Draw(sheet)
    for k, (png, label) in enumerate(tiles):
        x, y = (k % cols) * tile, (k // cols) * (tile + pad)
        sheet.paste(Image.open(png).convert("RGB"), (x, y + pad))
        draw.text((x + 4, y + 3), label, fill=(230, 225, 205))
    y = rows * (tile + pad)
    for png, label in strips:
        sheet.paste(Image.open(png).convert("RGB"), (0, y + pad))
        draw.text((4, y + 3), label, fill=(230, 225, 205))
        y += tile + pad
    sheet.save(out)
