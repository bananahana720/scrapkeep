"""The Slag Bowl's Fleet yard: the stands, furnaces, ladles, ledger board and crew props behind the rim.

blender -b --threads 2 --python-exit-code 1 --python sketches/core-loop/tools/blender/bosses/arena_bowl_yard.py
Use -- --out /tmp/arena_bowl_yard.glb for a byte-identity rebuild.

Godot metres, no collision or animation. Everything stands outside the rim wall (r 60 to 62, top y 16) on a yard
deck at y 15, so nothing reaches the riding lane or a telegraph. Static parts are built at their bowl position;
CrewFan and CrewPennant are single plush crew built at the origin, facing +X, for src/presentation/arena_bowl_dress.gd
to seat by MultiMesh. LadleMelt and FurnaceGlow carry the slag_glow slot, which the dress gives an emissive material
that steps with Brindle's phase. STANDS mirrors arena_bowl_dress.gd STANDS: the dress seats the crew on these tiers.
"""
import math
from pathlib import Path
import sys

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "rogues"))
import common

SKETCH = HERE.parents[2]
MODEL = SKETCH / "assets/models/bosses/arena_bowl_yard.glb"
METAL, COPPER, SLAG, PAINT, GLOW = "foundry_steel", "foundry_copper", "cooled_slag", "paint", "slag_glow"
DECK_Y = 15.0
# Sector centre and half width in degrees; tiers step out and up from the deck.
STANDS = [(95.0, 18.0), (225.0, 12.0), (300.0, 18.0)]
TIERS = 5
TIER_R0, TIER_DR = 69.0, 2.4
TIER_Y0, TIER_DY = 18.0, 2.0
STEP_DEGREES = 6.0
SPOUTS = [15.0, 165.0, 255.0]
FURNACES = [50.0, 140.0, 345.0]
FURNACE_R = 84.0
LEDGER_ANGLE, LEDGER_R = 180.0, 76.0


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def polar(angle, radius, y):
    return (math.cos(angle) * radius, y, math.sin(angle) * radius)


def box(part, size, at, colour, slot=METAL, yaw=0):
    """size is (radial, height, tangential) when yaw is -angle."""
    part.box(slot, (size[0], size[2], size[1]), loc=xyz(at), rot=(0, 0, yaw), color=colour)


def beam(part, a, b, width, colour, height=None, slot=METAL):
    part.beam(slot, xyz(a), xyz(b), width, height, color=colour)


def rod(part, a, b, r, colour, slot=METAL, segs=8, r2=None):
    part.rod(slot, xyz(a), xyz(b), r, segs, color=colour, r2=r2)


def tri(part, a, b, c, colour, slot=PAINT):
    verts = [part.bm.verts.new(xyz(p)) for p in (a, b, c)]
    face = part.bm.faces.new(verts)
    back = part.bm.faces.new(list(reversed([part.bm.verts.new(xyz(p)) for p in (a, b, c)])))
    part.paint([face, back], slot, colour)


def tier(k):
    return TIER_R0 + TIER_DR * k, TIER_Y0 + TIER_DY * k


def stands(root):
    part = common.Part("FleetStands")
    for centre, half in STANDS:
        lo, hi = math.radians(centre - half), math.radians(centre + half)
        steps = round(2 * half / STEP_DEGREES)
        for s in range(steps):
            a0 = lo + (hi - lo) * s / steps
            a1 = lo + (hi - lo) * (s + 1) / steps
            mid = (a0 + a1) / 2
            for k in range(TIERS):
                r, y = tier(k)
                width = (a1 - a0) * r + .06
                box(part, (2.4, .32, width), polar(mid, r, y - .16), "6d6656" if (s + k) % 2 else "5f5a4d", yaw=-mid)
                box(part, (.22, y - DECK_Y, width), polar(mid, r - 1.2, (y + DECK_Y) / 2 - .16), "4a4e47", yaw=-mid)
            # Bolted frame posts at every step line, raked like the wall's own repairs.
            for k in range(TIERS):
                r, y = tier(k)
                beam(part, polar(a0, r + .9, DECK_Y), polar(a0, r + .9, y - .3), .26, "514c40")
            r, y = tier(TIERS - 1)
            rod(part, polar(a0, r + 1.0, y), polar(a0, r + 1.0, y + 1.15), .05, "8a7556", slot=COPPER, segs=6)
            rod(part, polar(a0, r + 1.0, y + 1.1), polar(a1, r + 1.0, y + 1.1), .045, "8a7556", slot=COPPER, segs=6)
        r, y = tier(TIERS - 1)
        rod(part, polar(hi, r + 1.0, y), polar(hi, r + 1.0, y + 1.15), .05, "8a7556", slot=COPPER, segs=6)
        for end in (lo, hi):
            beam(part, polar(end, TIER_R0 - 1.1, DECK_Y), polar(end, r + 1.0, y + .2), .34, "4c5148")
            for k in range(TIERS):
                rk, yk = tier(k)
                box(part, (2.6, yk - DECK_Y, .3), polar(end, rk, (yk + DECK_Y) / 2), "554f43", yaw=-end)
        # The Fleet banner over each stand: a tall brass cloth on twin poles, the requisition roundel on it.
        c = math.radians(centre)
        for da in (-.045, .045):
            rod(part, polar(c + da, r + 1.6, DECK_Y), polar(c + da, r + 1.6, y + 8.2), .12, "4b5149", segs=8)
        box(part, (.08, 5.6, 5.4), polar(c, r + 1.5, y + 5.0), "a48f55", slot=PAINT, yaw=-c)
        part.cyl(PAINT, 1.4, 1.4, .1, 18, loc=xyz(polar(c, r + 1.44, y + 5.4)), rot=(0, math.pi / 2, -c), color="6e4a36")
        part.cyl(PAINT, .9, .9, .12, 18, loc=xyz(polar(c, r + 1.42, y + 5.4)), rot=(0, math.pi / 2, -c), color="a48f55")
        # Bunting along the top rail between the banner poles and the stand ends.
        n = round(2 * half / 2.0)
        for i in range(n):
            a0 = lo + (hi - lo) * i / n
            a1 = lo + (hi - lo) * (i + 1) / n
            m = (a0 + a1) / 2
            top = y + 2.1
            tri(part, polar(a0, r + 1.05, top), polar(a1, r + 1.05, top), polar(m, r + 1.05, top - .9),
                "9a6a45" if i % 2 else "a08d5c")
    part.to_object(parent=root)


def deck(root):
    part = common.Part("YardDeck")
    part.ring(METAL, 62.1, 81.5, .5, segs=72, loc=(0, 0, DECK_Y - .25), color="4f5249")
    for k in range(36):
        a = k * math.tau / 36
        beam(part, polar(a, 62.3, DECK_Y + .02), polar(a, 81.3, DECK_Y + .02), .1, "3e423c", .04)
    part.to_object(parent=root)


def furnaces(root):
    part = common.Part("CupolaFurnaces")
    glow = common.Part("FurnaceGlow")
    for degrees in FURNACES:
        a = math.radians(degrees)
        base = polar(a, FURNACE_R, DECK_Y)
        x, _, z = base
        part.cyl(METAL, 4.6, 4.2, 22, 20, loc=xyz((x, DECK_Y + 11, z)), color="57524a")
        part.cyl(METAL, 4.2, 2.6, 5, 20, loc=xyz((x, DECK_Y + 24.5, z)), color="4b4a44")
        part.cyl(METAL, 2.6, 2.4, 9, 16, loc=xyz((x, DECK_Y + 31.5, z)), color="44473f")
        for y in (DECK_Y + 4, DECK_Y + 12, DECK_Y + 20):
            part.cyl(COPPER, 4.85, 4.85, .5, 20, loc=xyz((x, y, z)), color="7a5f45")
        # Charging platform and its ladder face the bowl.
        part.ring(METAL, 4.6, 6.6, .3, segs=20, loc=xyz((x, DECK_Y + 16, z)), color="5c574a")
        for k in range(8):
            leg = a + k * math.tau / 8
            beam(part, (x + math.cos(leg) * 6.3, DECK_Y, z + math.sin(leg) * 6.3),
                 (x + math.cos(leg) * 6.3, DECK_Y + 16, z + math.sin(leg) * 6.3), .3, "4a4e47")
        door = polar(a, FURNACE_R - 4.55, DECK_Y + 18.5)
        box(part, (.6, 3.4, 3.6), door, "3b3e39", yaw=-a)
        box(glow, (.2, 2.4, 2.6), polar(a, FURNACE_R - 4.85, DECK_Y + 18.5), "ffffff", slot=GLOW, yaw=-a)
        tap = polar(a, FURNACE_R - 4.5, DECK_Y + 3.0)
        box(part, (2.2, .5, 1.2), tap, "6b5a45", slot=COPPER, yaw=-a)
        box(glow, (.3, .9, 1.0), polar(a, FURNACE_R - 4.65, DECK_Y + 2.1), "ffffff", slot=GLOW, yaw=-a)
        # The mouth of the stack: a glowing inner rim the smoke column rises out of.
        glow.ring(GLOW, 1.7, 2.35, .3, segs=16, loc=xyz((x, DECK_Y + 36.1, z)), color="ffffff")
    part.to_object(parent=root)
    glow.to_object(parent=root)


def ladles(root):
    part = common.Part("LadleCars")
    melt = common.Part("LadleMelt")
    for degrees in SPOUTS:
        a = math.radians(degrees)
        # A bogie on its own girder past the catch pan, the bucket tipped at the trough head.
        box(part, (6.0, .7, 4.6), polar(a, 76.5, DECK_Y + 2.6), "4e5249", yaw=-a)
        for side in (-1, 1):
            t = Vector((-math.sin(a), 0, math.cos(a))) * side * 2.0
            for r in (74.6, 78.4):
                p = polar(a, r, DECK_Y + 2.0)
                part.cyl(METAL, .55, .55, .4, 12, loc=xyz((p[0] + t.x, p[1], p[2] + t.z)), rot=(0, math.pi / 2, -a + math.pi / 2), color="383c37")
            # The girder the bogie runs on: wheel bottoms (DECK_Y + 1.45) sit on its rail cap.
            run = polar(a, 76.5, DECK_Y + .675)
            box(part, (8.0, 1.35, .4), (run[0] + t.x, run[1], run[2] + t.z), "4a4e47", yaw=-a)
            box(part, (8.2, .1, .6), (run[0] + t.x, DECK_Y + 1.4, run[2] + t.z), "383c37", yaw=-a)
            post = polar(a, 76.2, DECK_Y + 3.0)
            beam(part, (post[0] + t.x * 1.25, post[1], post[2] + t.z * 1.25), (post[0] + t.x * 1.25, post[1] + 4.6, post[2] + t.z * 1.25), .5, "5b5548")
        bottom = polar(a, 77.0, DECK_Y + 4.8)
        top = polar(a, 74.4, DECK_Y + 7.4)
        rod(part, bottom, top, 1.8, "6f5a43", slot=COPPER, segs=16, r2=2.25)
        lip_lo = Vector(top) + (Vector(top) - Vector(bottom)).normalized() * -.05
        rod(part, tuple(lip_lo), tuple(Vector(top) + (Vector(top) - Vector(bottom)).normalized() * .25), 2.4, "7d6449", slot=COPPER, segs=16)
        # Trunnion axle across the bucket.
        t = Vector((-math.sin(a), 0, math.cos(a))) * 2.7
        mid = (Vector(bottom) + Vector(top)) / 2
        rod(part, tuple(mid - t), tuple(mid + t), .32, "4b4f47", segs=10)
        surface = Vector(top) + (Vector(bottom) - Vector(top)).normalized() * .35
        rod(melt, tuple(surface), tuple(surface + (Vector(top) - Vector(bottom)).normalized() * .12), 2.12, "ffffff", slot=GLOW, segs=16)
    part.to_object(parent=root)
    melt.to_object(parent=root)


def ledger(root):
    part = common.Part("LedgerBoard")
    a = math.radians(LEDGER_ANGLE)
    y = DECK_Y + 10.0
    box(part, (.5, 8.6, 15.6), polar(a, LEDGER_R, y), "3a3f3a", yaw=-a)
    box(part, (.12, 7.8, 14.8), polar(a, LEDGER_R - .3, y), "262b29", slot=PAINT, yaw=-a)
    for dy in (-4.35, 4.35):
        box(part, (.7, .3, 16.2), polar(a, LEDGER_R - .05, y + dy), "a48f55", slot=COPPER, yaw=-a)
    # Ruled lines: the ledger's columns, chalked in.
    # Clear of the dress's chalk: title above, the phase's figure between, the caption below.
    for dy in (2.15, -1.95, -3.45):
        box(part, (.04, .06, 13.6), polar(a, LEDGER_R - .37, y + dy), "6c6a5e", slot=PAINT, yaw=-a)
    for da in (-.085, .085):
        beam(part, polar(a + da, LEDGER_R + .2, DECK_Y), polar(a + da, LEDGER_R + .2, y - 4.3), .5, "4a4e47")
        beam(part, polar(a + da, LEDGER_R + 3.5, DECK_Y), polar(a + da, LEDGER_R + .4, y + 2), .34, "4a4e47")
    part.to_object(parent=root)


def ingots(root):
    part = common.Part("IngotStock")
    for degrees, radius, layers in [(42, 72.5, 5), (58, 74.0, 4), (130, 72.0, 4), (150, 73.5, 6), (334, 72.5, 5), (354, 74.5, 3)]:
        a = math.radians(degrees)
        box(part, (3.0, .3, 3.0), polar(a, radius, DECK_Y + .15), "5a4636", yaw=-a)
        for layer in range(layers):
            y = DECK_Y + .3 + .22 + layer * .44
            cross = layer % 2
            for k in range(4):
                off = (k - 1.5) * .68
                tangent = Vector((-math.sin(a), 0, math.cos(a)))
                radial = Vector((math.cos(a), 0, math.sin(a)))
                at = Vector(polar(a, radius, y)) + (tangent if cross else radial) * off
                size = (2.6, .4, .5) if cross else (.5, .4, 2.6)
                box(part, size, tuple(at), "6a6b62" if (k + layer) % 3 else "7b6650", yaw=-a)
        # Requisition tag on each stack: brass, the Fleet's colour on everything it counts.
        box(part, (.05, .5, .8), polar(a, radius - 1.52, DECK_Y + .9), "a48f55", slot=COPPER, yaw=-a)
    part.to_object(parent=root)


def crew_yard(root):
    part = common.Part("CrewYard")
    # Five crew gyrospheres parked nose-in between stands C and A, chocked, bay lines painted.
    for i in range(5):
        a = math.radians(262 + i * 3.4)
        at = polar(a, 71.5, DECK_Y + .95)
        with part.region(bevel=0):
            part.uv(PAINT, .92, 14, 9, loc=xyz(at), color=["8f6b4c", "7b7a64", "6e5a4c", "86704a", "707866"][i])
        part.ring(COPPER, .9, 1.0, .16, segs=20, loc=xyz(at), rot=(math.pi / 2, 0, -a), color="7d6449")
        box(part, (.6, .35, .28), polar(a, 70.4, DECK_Y + .17), "3b3f3a", yaw=-a)
        box(part, (3.2, .02, .08), polar(a + .029, 71.5, DECK_Y + .01), "a39468", slot=PAINT, yaw=-a)
    # Hard-hat rack and the tea urn cart, beside stand B.
    a = math.radians(121)
    rack = polar(a, 70.5, DECK_Y)
    box(part, (.3, 2.0, 2.6), (rack[0], DECK_Y + 1.0, rack[2]), "4c5148", yaw=-a)
    for row in range(2):
        for k in range(3):
            t = Vector((-math.sin(a), 0, math.cos(a))) * (k - 1) * .8
            at = Vector(polar(a, 70.2, DECK_Y + 1.0 + row * .7)) + t
            with part.region(bevel=0):
                part.uv(PAINT, .26, 8, 5, loc=xyz(tuple(at)), scale=(1, 1, .62), color="a48f55" if (k + row) % 2 else "8c6a45")
    a = math.radians(125)
    cart = polar(a, 71.0, DECK_Y + .7)
    box(part, (1.2, .5, 1.8), cart, "6b5a45", slot=COPPER, yaw=-a)
    part.cyl(COPPER, .38, .34, .9, 14, loc=xyz((cart[0], cart[1] + .7, cart[2])), color="8a6b4a")
    part.cyl(METAL, .12, .12, .2, 8, loc=xyz((cart[0], cart[1] + 1.25, cart[2])), color="4b4f47")
    for side in (-1, 1):
        t = Vector((-math.sin(a), 0, math.cos(a))) * side * .8
        part.cyl(METAL, .28, .28, .12, 12, loc=xyz((cart[0] + t.x, DECK_Y + .28, cart[2] + t.z)), rot=(0, math.pi / 2, -a + math.pi / 2), color="2f3330")
    # The hiring board: four crew gloves on pegs under a notice, the Mind's "All hands" planted in world 1.
    a = math.radians(64)
    board = polar(a, 70.0, DECK_Y + 4.6)
    box(part, (.16, 2.2, 3.2), board, "5c4b3a", yaw=-a)
    box(part, (.06, 1.4, 2.8), polar(a, 69.9, DECK_Y + 4.9), "b8ad92", slot=PAINT, yaw=-a)
    for da in (-.02, .02):
        beam(part, polar(a + da, 70.05, DECK_Y), polar(a + da, 70.05, DECK_Y + 5.7), .14, "4a4e47")
    for k in range(4):
        t = Vector((-math.sin(a), 0, math.cos(a))) * (k - 1.5) * .7
        palm = Vector(polar(a, 69.85, DECK_Y + 3.85)) + t
        with part.region(bevel=0):
            box(part, (.12, .34, .3), tuple(palm), "c2b79c" if k != 2 else "8f8a7c", slot=PAINT, yaw=-a)
            for f in range(4):
                tip = palm + Vector((0, .3, 0)) + t.normalized() * (f - 1.5) * .07
                rod(part, tuple(palm + Vector((0, .1, 0)) + t.normalized() * (f - 1.5) * .07), tuple(tip), .03, "c2b79c" if k != 2 else "8f8a7c", slot=PAINT, segs=4)
    # The safety tally at the end of stand A.
    a = math.radians(279.5)
    box(part, (.14, 2.0, 3.4), polar(a, 70.2, DECK_Y + 3.6), "2c312e", slot=PAINT, yaw=-a)
    box(part, (.18, .2, 3.6), polar(a, 70.2, DECK_Y + 4.65), "a48f55", slot=COPPER, yaw=-a)
    for da in (-.022, .022):
        beam(part, polar(a + da, 70.3, DECK_Y), polar(a + da, 70.3, DECK_Y + 4.6), .14, "4a4e47")
    part.to_object(parent=root)


# Mojulo shell recipes beside this file (crew_shells.py mints them to shells/); hands in Blender metres, matching the recipes.
CREW_SHELLS = {"CrewFan": "crew_fan", "CrewPennant": "crew_pennant"}
CREW_HANDS = {"CrewFan": [(.20, .54, 1.56), (.20, -.54, 1.56)], "CrewPennant": [(.30, .44, 1.18), (.44, -.26, .34)]}
CREW_TRIS = {"Body": 1100, "Hat": 220, "Teeth": 12}
FUR, BELLY, HAT, BAND, MITT, TAIL, NOSE = "a99a84", "c4b8a2", "a48f55", "6e5734", "8f6b4c", "7d6450", "3b302a"


def crew_paint(name):
    """Vertex colour by position on the shell: cream belly and muzzle, brown mittens, a darker paddle tail and nose,
    a dark hat band. Blends stay on the one skin, so no colour seams."""
    hands = [Vector(h) for h in CREW_HANDS[name]]

    def paint(co, normal):
        if any((co - h).length < .15 for h in hands):
            return MITT
        if co.x < -.24 and co.z < .2:
            return TAIL
        if co.x > .39 and co.z > 1.03:
            return NOSE
        if abs(co.y) < .26 and ((co.x > .2 and .14 < co.z < .9) or (co.x > .26 and .9 < co.z < 1.12)):
            return BELLY
        return FUR
    return paint


def crew(root, name, pennant):
    """One plush crew member from its mojulo smooth shell, seat at the origin, facing +X: pear body, wide work hat,
    paddle tail, mittens up (docs/art/reference/bosses/crowd)."""
    import kit
    kit.SHELLS = str(HERE / "shells")
    pieces, new = kit.import_shells(CREW_SHELLS[name])
    part = common.Part(name)
    part.bevel = 0
    part.subsurf = 0
    paints = {"Body": crew_paint(name), "Hat": lambda co, n: BAND if 1.38 < co.z < 1.43 else HAT,
              "Teeth": lambda co, n: "d2c5a5"}
    for piece in ("Body", "Hat", "Teeth"):
        kit.add_shell(part, kit.shell_mesh(pieces[piece], CREW_TRIS[piece], (0, 0, 0)), PAINT, paints[piece])
    kit.drop(new)
    for side in (-1, 1):
        part.uv(PAINT, .035, 6, 4, loc=(.355, side * .105, 1.19), color="2a2420")
    if pennant:
        rod(part, (.3, .15, -.44), (.3, 1.85, -.44), .025, "6c6a5e")
        tri(part, (.3, 1.85, -.44), (.3, 1.45, -.44), (-.35, 1.65, -.5), "94503c")
    part.to_object(parent=root)


def build():
    common.reset()
    for slot, roughness, metallic in [(METAL, .87, .18), (COPPER, .76, .28), (SLAG, .97, .04), (PAINT, .9, 0.0), (GLOW, .6, 0.0)]:
        common.SLOTS[slot] = {"vc": True, "rough": roughness, "metal": metallic}
    root = common.empty("FleetYard")
    deck(root)
    stands(root)
    furnaces(root)
    ladles(root)
    ledger(root)
    ingots(root)
    crew_yard(root)
    crew(root, "CrewFan", False)
    crew(root, "CrewPennant", True)
    return root


if __name__ == "__main__":
    import polish
    # Machines keep crisp bevels; the crew and their gyrospheres go soft (soft-toy ruling, 18 Oct). The AO reach is
    # set for props a few metres across, not the 170 m yard: a fraction of the whole tree's radius.
    polish.enable(detail=1, bevel=.03, ao_reach=.012, bake_slots=(METAL, COPPER, PAINT))
    options = common.args()
    root = build()
    common.export(root, str(options["out"] or MODEL))
    print("ARB yard triangles:", common.tri_total(root))
    for o in common.tree(root):
        if o.type == "MESH":
            print("  %-16s %6d tris %d slots" % (o.name, common.tris(o), len(o.data.materials)))
