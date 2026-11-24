"""Headless recipe for two keeper marks (wave 46 E3-02, concept sheet 03-arena-stands-camp, the camp hub props callouts):
the knitted scarf a keeper ties to a freed rescue cage's pole, and the camp's shift board of bolted planks. Camp kit
conventions (_camp.py header): metres at game scale, Godot +Y up, one enamel draw with COLOR_0 vertex colour, every part
a closed solid. Keeper hands made both (STORY-MAP section 3): patched, bolted, hand-made; no mint, no lettering.

rescue_keeper_scarf: a weathered orange-oxide wool scarf wrapped three times round a 0.14 m cage pole, knotted, two
  striped tails hanging out from the pole with fringed ends. Origin on the pole's axis at the middle of the wraps; the
  tails hang toward local +X and +Z, the cage's outside corner. src/world/rescue_site.gd ties it to the freed cage's
  front right post. No collision: it is dressing on a device, never a target or a solid.
camp_shift_board: three chunky splintered planks bolted across with a copper plate, the camp's tally of shifts in
  bone-white hash marks (groups of four strokes struck through), leaning back on two stakes. Origin on the ground under
  the board's middle, the marks facing local +Z (the plaza). Collision: one box round the board and its stakes.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/camp/keeper_marks.py [-- --out-dir DIR] [--count-only]

The scarf ships beside the cage (assets/models/world_one) and the board with the camp kit (assets/models/camp); --out-dir
writes both into one directory, for a determinism rebuild.
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _camp as cp

T = cp.T
pk = cp.pk
WORLD_ONE = cp.SKETCH / "assets/models/world_one"

WOOL, WOOL_DK, WOOL_LT, FRINGE = "d4703a", "a9542c", "e08a52", "b8602f"
POLE_R = 0.14
BOARD_LEAN = math.radians(16.0)


def band(s, r_in, r_out, h, y, tilt, n, color):
    """A closed wool wrap round the pole: an annulus tilted by tilt about X, its middle at height y."""
    ct, st = math.cos(tilt), math.sin(tilt)
    quad = [(r_in, -h / 2), (r_out, -h / 2), (r_out, h / 2), (r_in, h / 2)]
    verts = []
    for k in range(n):
        a = math.tau * k / n
        for r, dy in quad:
            x, yy, z = r * math.cos(a), dy, r * math.sin(a)
            verts.append((x, y + yy * ct - z * st, yy * st + z * ct))
    faces = []
    for k in range(n):
        j = (k + 1) % n
        for q in range(4):
            m = (q + 1) % 4
            faces.append((k * 4 + q, k * 4 + m, j * 4 + m, j * 4 + q))
    s.add(verts, faces, color)


def tail(s, root, yaw, drop, swing, width, segments, phase):
    """One hanging tail: thin knit segments falling from the knot in a soft S, kicked out from the pole, striped two
    wools to one, with a fringe of loose strands at the end."""
    x, y, z = root
    seg = drop / segments
    out_x, out_z = math.sin(yaw), math.cos(yaw)
    end = (x, y, z)
    for k in range(segments):
        u = (k + .5) / segments
        out = swing * math.sin(u * math.pi * .5) + .05 * math.sin(u * math.tau + phase)
        cx, cz = x + out_x * out, z + out_z * out
        cy = y - seg * (k + .5)
        color = WOOL_LT if k % 3 == 2 else (WOOL if (k + phase) % 2 == 0 else WOOL_DK)
        cp.obox(s, (width, seg * 1.15, .075), (cx, cy, cz), color, yaw=yaw + .1 * math.sin(k + phase), pitch=.12 * math.cos(u * math.pi), roll=.04 * math.sin(2 * k + phase))
        end = (cx, cy - seg / 2, cz)
    for f in range(6):
        v = (f - 2.5) * width * .17
        cp.obox(s, (.035, .24 + .05 * (f % 2), .035), (end[0] + math.cos(yaw) * v, end[1] - .11 - .025 * (f % 2), end[2] - math.sin(yaw) * v),
                FRINGE, yaw=yaw, roll=.1 * (f - 2.5))


def scarf(s):
    band(s, POLE_R + .005, POLE_R + .19, .2, .16, .14, 14, WOOL)
    band(s, POLE_R + .02, POLE_R + .21, .22, 0.0, -.12, 14, WOOL_DK)
    band(s, POLE_R + .01, POLE_R + .19, .2, -.17, .1, 14, WOOL_LT)
    # The knot on the outside corner, chunky, the two tails leaving it.
    cp.obox(s, (.3, .24, .24), (.28, -.08, .28), WOOL, yaw=math.pi / 4, pitch=.3, roll=.2)
    cp.obox(s, (.22, .2, .2), (.33, -.2, .3), WOOL_DK, yaw=math.pi / 4 + .5, pitch=-.2)
    tail(s, (.36, -.22, .26), math.radians(58), 1.35, .34, .28, 8, 0)
    tail(s, (.26, -.26, .38), math.radians(30), 1.0, .24, .26, 6, 1)


def plank_marks(s, y, x0, x1, z, k, pitch):
    """Bone hash marks along one plank face: groups of four strokes and a slash, the last group still open."""
    x = x0
    group = 0
    while x + .5 < x1:
        strokes = 4 if x + 1.1 < x1 or group % 2 else 2 + k % 2
        for i in range(strokes):
            cp.obox(s, (.05, .26, .02), (x + i * .1, y + .01 * ((i + k) % 2), z), T["bone"], pitch=pitch, roll=.06 * (i - 1.5))
        if strokes == 4:
            cp.obox(s, (.48, .05, .02), (x + .15, y, z + .012), T["bone"], pitch=pitch, roll=-.5)
        x += .62
        group += 1


def board_frame(z, y):
    """A point on the leaning board's face plane: z out of the face, y up the board from its foot."""
    return z * math.cos(BOARD_LEAN) - y * math.sin(BOARD_LEAN), y * math.cos(BOARD_LEAN) + z * math.sin(BOARD_LEAN)


def shift_board(s):
    lean = -BOARD_LEAN
    rows = [(.34, 3.3, -.02), (.82, 3.05, .06), (1.3, 3.2, -.05)]
    for k, (h, length, dx) in enumerate(rows):
        dz, dy = board_frame(0.0, h)
        cp.obox(s, (length, .44, .18), (dx, dy, dz), cp.jitter_tone("timber", k + 3, 0.12), pitch=lean)
        # Splintered ends: a ragged sliver standing proud of each end.
        for side in (-1, 1):
            cp.obox(s, (.32, .12, .1), (dx + side * (length / 2 - .05), dy + .1 * side, dz + .03), cp.jitter_tone("timber_lt", k, .1),
                    roll=.25 * side, pitch=lean)
        fz, fy = board_frame(.1, h)
        plank_marks(s, fy, dx - length / 2 + .35, dx + length / 2 - .35 - (.7 if k == 1 else 0), fz, k, lean)
    # The copper plate bolted across all three, its bolt heads proud.
    pz, py = board_frame(.11, .82)
    cp.obox(s, (.7, 1.5, .04), (-.85, py, pz), T["copper"], pitch=lean)
    for bx in (-1.1, -.6):
        for by in (.38, .82, 1.26):
            bz, byy = board_frame(.15, by)
            cp.obox(s, (.1, .1, .05), (bx, byy, bz), T["copper_dk"], pitch=lean)
    # Two stakes behind, driven into the sand, and a cross batten tying them.
    for x in (-1.15, 1.15):
        top_z, top_y = board_frame(-.14, 1.45)
        cp.obox(s, (.14, 1.6, .14), (x, .78, top_z - .16), cp.jitter_tone("timber", 7, .1), pitch=-.1)
    cp.obox(s, (2.6, .12, .1), (0.0, .5, board_frame(-.14, .5)[0] - .1), cp.jitter_tone("timber", 9, .1))


def shift_board_col(s):
    cp.obox(s, (3.6, 1.62, 1.0), (0.0, .79, -.37), "iron")


def main():
    args = cp.options()
    default = str(cp.MODELS)
    world = str(WORLD_ONE) if args.out_dir == default else args.out_dir
    cp.export("camp_shift_board", shift_board, "prop", args, col=shift_board_col)
    args.out_dir = world
    cp.export("rescue_keeper_scarf", scarf, "prop", args)


if __name__ == "__main__":
    main()
