# W47-GRAPPLE-MUTS-3D: the 7 build-driven grapple mutations (one-part swap law, rule G1; master bible
# section 3.2, taste rubric section 6b, grounded sheet g11-universal-grapple-rigs-b.png row 4).
# Every mutation swaps EXACTLY ONE part of any pilot's 4-part grapple rig (Head, Line, or Drive) with a
# fixed canon-colour visual so the player reads which mutation is fitted directly off the rig on any pilot:
#
#   1. hot_wire         (heat)          swaps Line   Amber-orange internal glow + heat-coil ribbing (NEVER HAZARD #FF5A3C)
#   2. det_cord         (burst/split)   swaps Line   Banded charcoal & brass cord with fuse knots every metre
#   3. dragnet_siphon   (salvage)       swaps Head   Open iron mesh basket head with salvage rings & caught cogs
#   4. sonic_snap_sling (speed)         swaps Drive  Coil-spring drum with visible ratchet pawl (`pawl` actuator bone)
#   5. live_bus         (arc/chain)     swaps Head   Ceramic/bone insulator bells + copper bus bar (AMBER #E5A044, never mint/purple)
#   6. tether_slam      (pull/kinetic)  swaps Drive  Heavy flywheel clutch drum with bolted inertia weights
#   7. wrecking_flail   (mass/heft)     swaps Head   Weighted cast-iron demolition shackle head (Andrew Call #4)
#
#   blender -b --factory-startup --python-exit-code 1 -P tools/blender/grapple_mut_parts.py -- [--out-dir DIR] [--mut NAME]
#
# Files: assets/models/grapple_muts/grapple_mut_<name>_<part>.glb (detail class, assets/asset_budgets.json:
# 4,000 tris, 8,000 verts, 2 draws).
#
# Node, axis, and armature contract (drop-in match for grapple_rigs.py and W47-GRAPPLE-CODE / W47-GRAPPLE-MUTS-CODE):
#   Line swaps:  GrappleLine (empty) > Line. Seamless 1.0 m tile along Blender +Y (Godot -Z), y in [0.0, 1.0].
#   Head swaps:  GrappleHead (empty, line attach eye) > HeadRig (skeleton) > Head (skinned). Bites along +Y (Godot -Z).
#   Drive swaps: GrappleDrive (empty, axle centre) > Drive (rigid) or GrappleDrive > DriveRig > Drive (skinned, when
#                carrying the `pawl` actuator bone). Axle is local +X.
#
# Palette discipline: palette.gd hexes only (common.HEX, STEEL #9aa0a0, SODIUM #ffc070). Zero HAZARD (#ff5a3c),
# zero ARC mint (#8bf0d3), zero KINDNESS purple (#d936b0). Every mesh is checked watertight manifold (closed_report),
# within detail budget caps, and within REACH (1.75 m) & FLOOR_Z (-0.55 m) on all 5 pilot mounts.

import argparse
import contextlib
import hashlib
import json
import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common  # noqa: E402
import grapple_rigs as gr  # noqa: E402
from grapple_rigs import (  # noqa: E402
    AXLE,
    FLOOR_Z,
    LOW_RADIUS,
    REACH,
    STEEL,
    STEEL_DARK,
    STEEL_WORN,
    X,
    Y,
    Z,
    Rig,
    axle_frame,
    basis,
    bolts,
    flange_ticks,
    frame,
    vec3,
    wraps,
    x_to,
)

OUT_DIR = os.path.join(common.MODELS, "grapple_muts")
CAP = {"tris": 4000, "verts": 8000, "draws": 2}  # detail class (assets/asset_budgets.json)

# Canon palette mixes (palette.gd only; NEVER HAZARD #ff5a3c, ARC #8bf0d3, or KINDNESS #d936b0)
SODIUM = "ffc070"  # palette.gd SODIUM: warm paler glowing amber, hue 33.6 deg
HOT_COIL = common.mix("copper", "amber", 0.42)  # heated copper-amber coil ribbing (hue ~31 deg)
HOT_SHROUD = common.mix("charcoal", "copper", 0.25)  # scorched dark bronze heat collar
CAST_IRON = common.mix("charcoal", STEEL, 0.22)  # heavy cast-iron demolition & flywheel body
CAST_RIM = common.mix("charcoal", STEEL, 0.48)  # machined cast-iron rim
CERAMIC_BONE = common.mix("bone", "e6d9b8", 0.5)  # glazed bone-cream porcelain insulator bell
CERAMIC_GLAZE = common.mix("sandstone", "bone", 0.65)  # subtle warm ceramic skirt rim
BRASS_DARK = common.mix("brass", "charcoal", 0.30)  # weathered satin brass collar
CLUTCH_PAD = common.mix("copper", "oxide", 0.35)  # sintered bronze-oxide friction pad

# Emissive warm amber-orange slot for Hot-Wire internal core & Live-Bus live terminals.
# Base colour is AMBER (#e5a044) lightened 0.20 toward warm incandescent sodium (~hue 34 deg, 25 deg off HAZARD).
common.SLOTS.setdefault("amber_glow", {"color": "e5a044", "lighten": 0.20, "emit": 1.65, "rough": 0.35})


class MultiRig(Rig):
    """Rig extension allowing a second material slot (e.g. amber_glow or matte paint) within the 2-draw detail cap."""

    @contextlib.contextmanager
    def using(self, slot):
        prev, self.slot = self.slot, slot
        try:
            yield
        finally:
            self.slot = prev

    def saw_ratchet(self, m, r_root, r_tip, teeth, depth, color):
        """Asymmetrical sawtooth ratchet wheel about local +Y of m (depth along Y)."""
        out = []
        step = math.tau / teeth
        for k in range(teeth):
            a = k * step
            # Steep locking face at a..a+0.12*step, gentle ramp back down to root.
            out += [
                (r_root, a),
                (r_tip, a + step * 0.14),
                (r_tip * 0.985, a + step * 0.26),
                (r_root, a + step * 0.88),
            ]
        rot = m @ Matrix.Rotation(-math.pi / 2, 4, "X")
        pts = [(r * math.cos(a), r * math.sin(a)) for r, a in out]
        return self.prism(pts, depth, rot, color)

    def sphere(self, center, radius, u_segs, v_segs, color):
        r = bmesh.ops.create_uvsphere(
            self.bm,
            u_segments=u_segs,
            v_segments=v_segs,
            radius=radius,
            matrix=Matrix.Translation(Vector(center)),
        )
        return self._fin(self.part._faces(r["verts"]), color)


# --- 1. Hot-Wire Arc Cutter (heat · swaps Line) ----------------------------------------------------


class HotWire:
    """Amber-orange internal glow core wrapped in twin copper-amber heat-coil ribs and finned
    charcoal insulator collars. Seamless 1.0 m tile along Blender +Y (10 whole coil turns/m).
    Strictly AMBER/SODIUM/COPPER — ZERO HAZARD #FF5A3C."""

    PART = "line"
    SLOT = "hydraulic"
    BONES = ()
    ACTUATORS = {}

    @staticmethod
    def build(rig):
        # Continuous glowing internal heating filament core (y = 0.0 .. 1.0 m).
        with rig.using("amber_glow"):
            rig.lathe(frame((0, 0, 0), Y), [(0.0, 0.0155), (1.0, 0.0155)], 10, "amber")
        # Twin open helical heat-coil ribs wrapping the glowing core (10 whole turns per metre -> seamless).
        rig.helix_rope(2, 0.0058, 0.0205, 10, 80, 5, HOT_COIL, length=1.0, phase=0.0)
        # Four finned heat-sink insulator collars spaced evenly along the metre (clear greyscale rhythm).
        for k in range(4):
            y0 = 0.125 + 0.25 * k
            prof = [
                (-0.022, 0.019),
                (-0.018, 0.028),
                (-0.011, 0.028),
                (-0.008, 0.021),
                (0.008, 0.021),
                (0.011, 0.028),
                (0.018, 0.028),
                (0.022, 0.019),
            ]
            cols = [
                HOT_SHROUD,
                "copper",
                HOT_SHROUD,
                "charcoal",
                HOT_SHROUD,
                "copper",
                HOT_SHROUD,
            ]
            rig.ring_lathe(frame((0, y0, 0), Y), prof, 10, cols + [HOT_SHROUD])


# --- 2. Det-Cord Line (burst/split · swaps Line) ---------------------------------------------------


class DetCord:
    """Banded charcoal & brass 4-strand braided cord with a bulky braided fuse knot and brass
    detonator crimp collars every metre (at y = 0.50 m). Seamless 1.0 m tile along Blender +Y."""

    PART = "line"
    SLOT = "paint"
    BONES = ()
    ACTUATORS = {}

    @staticmethod
    def build(rig):
        # Solid inner charcoal core so gaps between strands stay dark.
        rig.lathe(frame((0, 0, 0), Y), [(0.0, 0.011), (1.0, 0.011)], 6, "charcoal")
        # 4-strand alternating charcoal & brass braid (6 whole turns per metre -> seamless tile).
        for s in range(4):
            col = "brass" if s % 2 == 0 else "charcoal"
            p0 = s * math.tau / 4.0
            segs = 48
            pts = [
                (
                    0.013 * math.cos(p0 + math.tau * 6.0 * i / segs),
                    i / segs,
                    0.013 * math.sin(p0 + math.tau * 6.0 * i / segs),
                )
                for i in range(segs + 1)
            ]
            rig.sweep(pts, 0.0115, 5, col, up=(0, 0, 1))
        # Bulky Turk's-head fuse knot centred at y = 0.50 m (unmistakable silhouette every metre).
        knot_y = 0.50
        for i, (dy, R, r, tilt, col) in enumerate([
            (-0.044, 0.025, 0.012, 0.28, "charcoal"),
            (-0.022, 0.032, 0.013, -0.26, "brass"),
            (0.000, 0.036, 0.014, 0.24, "charcoal"),
            (0.022, 0.032, 0.013, -0.26, "brass"),
            (0.044, 0.025, 0.012, 0.28, "charcoal"),
        ]):
            nrm = Vector((math.sin(tilt), math.cos(tilt), 0.12 * (-1 if i % 2 else 1))).normalized()
            rig.torus((0, knot_y + dy, 0), nrm, R, r, 12, 6, col)
        # Metallic brass crimp sleeves & side primer cap flanking the fuse knot (2nd draw: hydraulic).
        with rig.using("hydraulic"):
            for sgn in (-1, 1):
                yc = knot_y + sgn * 0.072
                rig.lathe(
                    frame((0, yc - 0.016, 0), Y),
                    [(0.0, 0.024), (0.005, 0.030), (0.027, 0.030), (0.032, 0.024)],
                    10,
                    ["copper", "brass", "copper"],
                )
            # Small blasting primer node tucked along the knot shoulder (brass + warm amber, never HAZARD).
            rig.lathe(
                frame((0.038, knot_y - 0.028, 0.012), Y),
                [(0.0, 0.010), (0.014, 0.013), (0.046, 0.013), (0.056, 0.009)],
                8,
                ["copper", "brass", "amber"],
            )


# --- 3. Dragnet Siphon (salvage · swaps Head) ------------------------------------------------------


class DragnetSiphon:
    """Open iron wire-mesh basket head with heavy salvage hoops, 4-strut bridle yoke, hinged intake
    salvage-ring clasp (`mouth` bone), nose tow-ring, and two tumbled worn-steel salvage cogs inside."""

    PART = "head"
    SLOT = "hydraulic"
    MOUTH_HINGE = Vector((0.0, 0.155, 0.105))
    BONES = [("head", Vector((0, 0, 0)), None), ("mouth", MOUTH_HINGE, "head")]
    ACTUATORS = {
        "mouth": {
            "turn_about": vec3(X),
            "open": -42,
            "why": "the hinged intake salvage ring swings open on cast to scoop scrap and cogs",
        }
    }

    @classmethod
    def build(cls, rig):
        # Line attach ferrule and forged steel swivel eye.
        rig.lathe(frame((0, -0.04, 0), Y), [(0.0, 0.020), (0.04, 0.024)], 8, "copper")
        rig.torus((0, 0.022, 0), X, 0.024, 0.0085, 10, 6, STEEL)
        rig.lathe(frame((0, 0.042, 0), Y), [(0.0, 0.024), (0.028, 0.032), (0.042, 0.026)], 10, STEEL_DARK)

        # Basket profile curve (y, radius) from rear intake ring (0.155) to nose collar (0.445).
        stations = [
            (0.155, 0.105),
            (0.215, 0.128),
            (0.285, 0.132),
            (0.355, 0.110),
            (0.415, 0.070),
            (0.448, 0.036),
        ]

        # 4-strut forged steel bridle from swivel hub to the rear salvage ring.
        for k in range(4):
            a = k * math.tau / 4.0 + math.pi / 4.0
            rim_pt = Vector((0.105 * math.cos(a), 0.155, 0.105 * math.sin(a)))
            hub_pt = Vector((0.020 * math.cos(a), 0.068, 0.020 * math.sin(a)))
            rig.cyl(hub_pt, rim_pt, 0.009, 6, STEEL_DARK)
            # Copper bridle lug clamp at the rear ring.
            rig.cyl(rim_pt - Y * 0.012, rim_pt + Y * 0.012, 0.014, 6, "copper")

        # Rear main salvage hoop + 3 circumferential basket hoops (open mesh silhouette).
        rig.torus((0, 0.155, 0), Y, 0.105, 0.0125, 18, 6, STEEL)
        for y_ring, r_ring, thick, col in [
            (0.215, 0.128, 0.0085, "brass"),
            (0.285, 0.132, 0.0105, STEEL_WORN),
            (0.355, 0.110, 0.0085, "copper"),
            (0.415, 0.070, 0.0080, STEEL),
        ]:
            rig.torus((0, y_ring, 0), Y, r_ring, thick, 18, 5, col)

        # 8 longitudinal curved iron mesh ribs from rear ring to nose collar.
        for k in range(8):
            a = k * math.tau / 8.0
            ca, sa = math.cos(a), math.sin(a)
            pts = [(r * ca, y, r * sa) for y, r in stations]
            col = STEEL_DARK if k % 2 == 0 else CAST_RIM
            rig.sweep(pts, 0.0072, 5, col, up=(ca, 0, sa))

        # 4 helical cross-mesh wire straps (half-turn over the belly for clear wire-basket weave).
        for k in range(4):
            a0 = k * math.tau / 4.0
            pts = []
            for i, (y, r) in enumerate(stations[:-1]):
                a = a0 + 0.35 * math.pi * (i / (len(stations) - 2))
                pts.append(((r - 0.003) * math.cos(a), y, (r - 0.003) * math.sin(a)))
            rig.sweep(pts, 0.0048, 4, STEEL_WORN, up=(0, 0, 1))

        # Forward nose collar and forged tow-ring tip.
        rig.lathe(frame((0, 0.435, 0), Y), [(0.0, 0.042), (0.022, 0.036), (0.038, 0.022)], 10, "copper")
        rig.torus((0, 0.490, 0), Z, 0.028, 0.009, 12, 6, STEEL_WORN)

        # Two worn-steel / brass salvage cogs visible inside the open mesh basket (g11 4.2 signature read).
        m_cog1 = Matrix.Translation(Vector((0.025, 0.255, -0.022))) @ Matrix.Rotation(math.radians(32), 4, "Z") @ Matrix.Rotation(math.radians(18), 4, "X")
        rig.gear(m_cog1, 0.032, 0.044, 8, 0.014, STEEL_WORN)
        m_cog2 = Matrix.Translation(Vector((-0.030, 0.320, 0.018))) @ Matrix.Rotation(math.radians(-48), 4, "X") @ Matrix.Rotation(math.radians(24), 4, "Z")
        rig.gear(m_cog2, 0.024, 0.034, 7, 0.012, "brass")

        # Actuator bone `mouth`: hinged salvage-ring clasp hoop on top of the intake mouth.
        with rig.on("mouth"):
            h = cls.MOUTH_HINGE
            rig.cyl(h - X * 0.032, h + X * 0.032, 0.011, 8, "copper")
            # Hinged brass salvage-ring arc that flips open to vacuum scrap.
            pts = []
            for i in range(9):
                ang = math.radians(-70 + 140 * i / 8)
                pts.append((0.088 * math.sin(ang), h.y - 0.018, h.z - 0.088 * (1.0 - math.cos(ang)) * 0.65 - 0.015))
            rig.sweep(pts, 0.0095, 6, "brass", up=(0, 1, 0))
            # Two inward salvage catch-hooks on the mouth clasp.
            for sx in (-1, 1):
                p0 = Vector((sx * 0.055, h.y - 0.018, h.z - 0.036))
                rig.cyl(p0, p0 + Vector((-sx * 0.018, 0.026, -0.014)), 0.007, 5, STEEL_WORN)


# --- 4. Sonic Snap-Sling (speed · swaps Drive) -----------------------------------------------------


class SonicSnapSling:
    """Coil-spring drum with exposed spiral clockwork mainspring, sawtooth ratchet gear, and a high-contrast
    clicking ratchet pawl (`pawl` actuator bone). Axle is local +X; fits all 5 pilot mounts."""

    PART = "drive"
    SLOT = "hydraulic"
    PAWL_AT = Vector((0.094, 0.094, 0.082))
    BONES = [("drive", Vector((0, 0, 0)), None), ("pawl", PAWL_AT, "drive")]
    ACTUATORS = {
        "pawl": {
            "turn_about": vec3(X),
            "click": 22,
            "why": "the visible ratchet pawl lifts and clicks rhythmically over the sawtooth teeth while held",
        }
    }

    @classmethod
    def build(cls, rig):
        # Main steel axle shaft (seats in every pilot mount's bearing collars).
        rig.lathe(AXLE, [(-0.135, 0.022), (0.135, 0.022)], 10, "charcoal")
        # Inner tension drum barrel.
        rig.lathe(AXLE, [(-0.070, 0.060), (0.070, 0.060)], 12, STEEL_DARK)
        # 6 chunky high-contrast coil-spring wraps around the barrel (unmistakable coiled spring silhouette).
        wraps(rig, -0.056, 0.056, 0.061, 0.0145, 6, STEEL_WORN, segs=16, sides=6)

        # Twin heavy brass/copper drum flanges with dark recessed centres and bone rotation index ticks.
        for s in (-1, 1):
            a, b = (0.070, 0.086) if s > 0 else (-0.086, -0.070)
            rig.lathe(
                AXLE,
                [(a, 0.032), (a, 0.114), (b, 0.114), (b, 0.032)],
                16,
                ["charcoal", "copper", "charcoal"],
            )
            bolts(rig, s * 0.086, 0.055, 4, "charcoal", r=0.010, h=0.010, start=math.pi / 4)
        flange_ticks(rig, -0.086, 0.032, 0.110, "bone", count=1, w=0.024, h=0.010)
        flange_ticks(rig, 0.086, 0.032, 0.082, "bone", count=1, w=0.020, h=0.008, start=math.pi)

        # Exposed Archimedes spiral mainspring on the -X outboard face (visible coiled spring energy).
        spring_pts = []
        segs = 36
        for i in range(segs + 1):
            t = i / segs
            ang = t * math.tau * 2.5
            rr = 0.032 + 0.066 * t
            spring_pts.append((-0.104, rr * math.cos(ang), rr * math.sin(ang)))
        rig.sweep(spring_pts, 0.0075, 5, "brass", up=X)
        # Outer spring retainer pin anchoring the spiral tail to the flange.
        rig.cyl((-0.086, -0.098, 0.0), (-0.116, -0.098, 0.0), 0.011, 6, "copper")

        # Asymmetrical sawtooth ratchet wheel on the +X face (14 directional teeth).
        rig.saw_ratchet(axle_frame(0.096), 0.078, 0.108, 14, 0.018, "charcoal")
        # Copper centre boss cap on +X face.
        rig.lathe(AXLE, [(0.104, 0.044), (0.120, 0.038)], 10, "copper")

        # Visible clicking ratchet pawl (`pawl` actuator bone) biting the 12 o'clock sawtooth crest.
        with rig.on("pawl"):
            p = cls.PAWL_AT
            # Copper pivot boss & hinge pin.
            rig.cyl(p - X * 0.018, p + X * 0.018, 0.016, 8, "copper")
            # High-contrast bone pawl lever arm sweeping across the top teeth to bite at (0.094, 0.012, 0.106).
            nose = Vector((p.x, 0.008, 0.106))
            tail = Vector((p.x, p.y + 0.038, p.z - 0.012))
            rig.beam(p, nose, 0.022, 0.018, "bone", up=X)
            # Hooked brass ratchet tooth tip dropping cleanly into the sawtooth valley.
            rig.beam(nose, nose + Vector((0, -0.018, -0.024)), 0.020, 0.014, "brass", up=X)
            # Chunky thumb-release / click-indicator tail tab with brass weight cap.
            rig.beam(p, tail, 0.020, 0.016, "brass", up=X)
            rig.box(tail + Vector((0, 0.010, -0.004)), (0.026, 0.022, 0.022), "bone")


# --- 5. Live-Bus Conductor (arc/chain · swaps Head) ------------------------------------------------


class LiveBusConductor:
    """Ceramic/bone fluted insulator bells mounted on a heavy curved copper bus bar yoke, with twin
    clamping copper contact forks (`jaw.0`, `jaw.1` bones) and warm AMBER #E5A044 live-bus terminals
    (NEVER mint #8BF0D3, NEVER purple #D936B0, NEVER hazard #FF5A3C)."""

    PART = "head"
    SLOT = "hydraulic"
    JAW_PIVOTS = (Vector((-0.092, 0.228, 0.0)), Vector((0.092, 0.228, 0.0)))
    BONES = [
        ("head", Vector((0, 0, 0)), None),
        ("jaw.0", JAW_PIVOTS[0], "head"),
        ("jaw.1", JAW_PIVOTS[1], "head"),
    ]
    ACTUATORS = {
        "jaw.0": {
            "turn_about": vec3(Z),
            "clamp": -22,
            "why": "left copper bus contact jaw clamps inward onto powered world relays",
        },
        "jaw.1": {
            "turn_about": vec3(Z),
            "clamp": 22,
            "why": "right copper bus contact jaw clamps inward onto powered world relays",
        },
    }

    @classmethod
    def build(cls, rig):
        # Copper line ferrule, attach eye, and insulated charcoal stem.
        rig.lathe(frame((0, -0.04, 0), Y), [(0.0, 0.020), (0.04, 0.024)], 8, "copper")
        rig.torus((0, 0.022, 0), X, 0.024, 0.0085, 10, 6, STEEL)
        rig.lathe(frame((0, 0.045, 0), Y), [(0.0, 0.022), (0.095, 0.026)], 10, "charcoal")
        # Central copper bus-junction clamp block.
        rig.box((0, 0.155, 0), (0.072, 0.064, 0.060), "charcoal")
        rig.box((0, 0.155, 0), (0.082, 0.044, 0.042), "copper")

        # Curved heavy copper bus bar yoke arching across X = -0.132 .. +0.132 m (g11 4.2 iconic arc).
        yoke_pts = []
        for i in range(11):
            t = -1.0 + 2.0 * i / 10.0
            yoke_pts.append((0.132 * t, 0.155 + 0.052 * (1.0 - t * t), 0.0))
        rig.sweep(yoke_pts, 0.018, 8, "copper", up=Z)
        # Bolted charcoal mounting saddles on the bus bar at left, centre, right.
        for sx in (-0.092, 0.0, 0.092):
            yy = 0.155 + 0.052 * (1.0 - (sx / 0.132) ** 2)
            rig.box((sx, yy, 0.0), (0.036, 0.040, 0.046), "charcoal")

        # Forward twin-stage ceramic/bone insulator bells (high-voltage shed profile) at left & right.
        bell_profile = [
            (0.000, 0.026),
            (0.016, 0.032),
            (0.024, 0.048),
            (0.036, 0.048),
            (0.044, 0.034),
            (0.060, 0.036),
            (0.070, 0.056),
            (0.084, 0.056),
            (0.092, 0.040),
            (0.108, 0.044),
            (0.120, 0.065),
            (0.132, 0.063),
            (0.138, 0.046),
        ]
        bell_cols = [
            "charcoal",
            CERAMIC_BONE,
            CERAMIC_GLAZE,
            CERAMIC_BONE,
            CERAMIC_BONE,
            CERAMIC_BONE,
            CERAMIC_GLAZE,
            CERAMIC_BONE,
            CERAMIC_BONE,
            CERAMIC_BONE,
            CERAMIC_GLAZE,
            CERAMIC_BONE,
        ]

        for idx, piv in enumerate(cls.JAW_PIVOTS):
            sgn = -1 if idx == 0 else 1
            with rig.on("jaw.%d" % idx):
                # Pivot pin & copper arm mounting each ceramic bell forward along +Y.
                rig.cyl(piv - Z * 0.032, piv + Z * 0.032, 0.014, 8, "copper")
                # Ceramic/bone fluted insulator bell pointing slightly outward-forward.
                bell_dir = Vector((sgn * 0.16, 1.0, 0.0)).normalized()
                bell_base = piv + Vector((0.0, 0.016, 0.0))
                rig.lathe(frame(bell_base, bell_dir), bell_profile, 14, bell_cols)
                # Copper electrode stud & bus contact jaw extending from the bell mouth.
                tip_base = bell_base + bell_dir * 0.136
                tip_end = bell_base + bell_dir * 0.200
                rig.lathe(
                    frame(tip_base, bell_dir),
                    [(0.0, 0.022), (0.022, 0.026), (0.062, 0.016)],
                    10,
                    ["copper", "brass"],
                )
                # Inward-hooked copper bus-bar contact shoe.
                shoe_in = tip_end + Vector((-sgn * 0.032, 0.020, 0.0))
                rig.beam(tip_end, shoe_in, 0.022, 0.024, "copper", up=Z)
                # Warm AMBER #E5A044 live terminal cap + inner spark node (2nd draw: amber_glow).
                with rig.using("amber_glow"):
                    rig.lathe(
                        frame(tip_base + bell_dir * 0.030, bell_dir),
                        [(0.0, 0.028), (0.014, 0.030), (0.022, 0.024)],
                        10,
                        "amber",
                    )
                    rig.sphere(shoe_in, 0.017, 10, 6, "amber")

        # Subtle warm AMBER live-bus spark bridge rod suspended between the two insulator bells (TADR-008).
        with rig.using("amber_glow"):
            arc_pts = [
                (-0.086, 0.398, 0.0),
                (-0.042, 0.420, 0.014),
                (0.0, 0.404, -0.012),
                (0.042, 0.422, 0.010),
                (0.086, 0.398, 0.0),
            ]
            rig.sweep(arc_pts, 0.0085, 6, "amber", up=Z)


# --- 6. Tether-Slam Clutch (pull/kinetic · swaps Drive) --------------------------------------------


class TetherSlamClutch:
    """Heavy cast-iron flywheel clutch drum with dished clutch webs, bronze friction shoes, and 6 bolted
    perimeter inertia weights. Axle is local +X; fits all 5 pilot mounts within FLOOR_Z (-0.55 m)."""

    PART = "drive"
    SLOT = "hydraulic"
    BONES = ()
    ACTUATORS = {}

    @staticmethod
    def build(rig):
        # Oversized forged steel axle shaft & stepped hex locknuts.
        rig.lathe(AXLE, [(-0.138, 0.026), (0.138, 0.026)], 10, "charcoal")
        for s in (-1, 1):
            a, b = (0.100, 0.126) if s > 0 else (-0.126, -0.100)
            rig.lathe(AXLE, [(a, 0.042), (b, 0.038)], 6, STEEL_WORN)

        # Compact inner cable drum & heavy steel cable wraps.
        rig.lathe(AXLE, [(-0.052, 0.058), (0.052, 0.058)], 12, STEEL_DARK)
        wraps(rig, -0.038, 0.038, 0.058, 0.012, 4, STEEL, segs=14, sides=5)

        # Twin massive cast-iron flywheel clutch plates with dished clutch recess & machined rim bevel.
        for s in (-1, 1):
            x_in = s * 0.050
            x_mid = s * 0.072
            x_out = s * 0.098
            x_dish = s * 0.082
            prof = [
                (x_in, 0.032),
                (x_in, 0.108),
                (x_mid, 0.114),
                (x_out, 0.114),
                (x_out, 0.088),
                (x_dish, 0.080),
                (x_dish, 0.044),
                (x_out, 0.042),
                (x_out, 0.032),
            ]
            if s < 0:
                prof = list(reversed(prof))
            cols = [CAST_IRON, CAST_RIM, STEEL_WORN, CAST_RIM, CAST_IRON, "charcoal", CAST_IRON, CAST_RIM, CAST_IRON]
            rig.ring_lathe(AXLE, prof, 20, cols)

            # 3 raised cast-iron clutch spoke ribs + 3 bronze friction clutch pads inside the dish.
            for k in range(3):
                ang = k * math.tau / 3.0 + (0.0 if s > 0 else math.pi / 3.0)
                d = Vector((0, math.cos(ang), math.sin(ang)))
                side = Vector((0, -math.sin(ang), math.cos(ang)))
                rig.obox(
                    Vector((s * 0.086, 0, 0)) + d * 0.062,
                    (X, d, side),
                    (0.018, 0.044, 0.020),
                    CAST_RIM,
                )
                # Sintered bronze-oxide clutch shoe tucked between the spokes.
                ang2 = ang + math.pi / 3.0
                d2 = Vector((0, math.cos(ang2), math.sin(ang2)))
                side2 = Vector((0, -math.sin(ang2), math.cos(ang2)))
                rig.obox(
                    Vector((s * 0.088, 0, 0)) + d2 * 0.064,
                    (X, d2, side2),
                    (0.014, 0.028, 0.034),
                    CLUTCH_PAD,
                )

            # 6 heavy perimeter flywheel bolts.
            bolts(rig, s * 0.098, 0.101, 6, STEEL_WORN, r=0.0075, h=0.008)

        # 6 chunky bolted inertia counterweight blocks bridging the outer flywheel rims (radius <= 0.125 m).
        for k in range(6):
            ang = k * math.tau / 6.0 + math.pi / 6.0
            d = Vector((0, math.cos(ang), math.sin(ang)))
            side = Vector((0, -math.sin(ang), math.cos(ang)))
            # Heavy dark cast-iron inertia block proud of the flywheel rim.
            rig.obox(d * 0.111, (X, d, side), (0.056, 0.022, 0.048), CAST_IRON)
            # Copper/brass retaining strap & bolt boss over each inertia weight.
            rig.obox(d * 0.121, (X, d, side), (0.024, 0.006, 0.050), "brass" if k % 2 == 0 else "copper")

        # High-contrast bone flywheel timing stripe on both outer faces (clear rotation read at chase cam).
        flange_ticks(rig, -0.098, 0.040, 0.110, "bone", count=1, w=0.026, h=0.010)
        flange_ticks(rig, 0.098, 0.040, 0.110, "bone", count=1, w=0.026, h=0.010, start=math.pi)


# --- 7. Wrecking Flail (mass/heft · swaps Head, Andrew Call #4) ------------------------------------


class WreckingFlail:
    """Weighted cast-iron demolition shackle head (moved off Sable baseline per Andrew Call #4):
    heavy forged clevis shackle + copper clevis pin + bolted demolition collar + studded cast-iron
    wrecking sphere with equatorial riveted band (`flail` actuator bone pivots at the shackle pin)."""

    PART = "head"
    SLOT = "hydraulic"
    FLAIL_PIVOT = Vector((0.0, 0.125, 0.0))
    BONES = [("head", Vector((0, 0, 0)), None), ("flail", FLAIL_PIVOT, "head")]
    ACTUATORS = {
        "flail": {
            "turn_about": vec3(X),
            "swing": 28,
            "why": "the weighted cast-iron demolition ball lags and swings on its clevis shackle pin",
        }
    }

    @classmethod
    def build(cls, rig):
        # Heavy copper line ferrule and forged steel attach eye.
        rig.lathe(frame((0, -0.04, 0), Y), [(0.0, 0.022), (0.04, 0.028)], 8, "copper")
        rig.torus((0, 0.024, 0), Z, 0.028, 0.0105, 12, 6, STEEL_DARK)
        # First heavy forged chain link bridging the attach eye to the demolition clevis shackle.
        rig.link((0, 0.074, 0), Y, X, 0.092, 0.060, 0.013, STEEL)

        # Actuator bone `flail`: oversized forged clevis shackle + bolted collar + weighted studded cast-iron ball.
        with rig.on("flail"):
            p = cls.FLAIL_PIVOT
            # Oversized U-shaped forged demolition clevis shackle.
            bow_pts = []
            for i in range(11):
                ang = math.radians(-115 + 230 * i / 10)
                bow_pts.append((0.046 * math.sin(ang), p.y + 0.016 - 0.044 * math.cos(ang), 0.0))
            rig.sweep(bow_pts, 0.014, 7, STEEL_DARK, up=Z)
            # Heavy copper clevis cross-pin with oversized end caps.
            rig.cyl((p.x - 0.064, p.y + 0.036, 0.0), (p.x + 0.064, p.y + 0.036, 0.0), 0.016, 8, "copper")
            for sx in (-1, 1):
                rig.cyl(
                    (sx * 0.064, p.y + 0.036, 0.0),
                    (sx * 0.078, p.y + 0.036, 0.0),
                    0.022,
                    8,
                    STEEL_WORN,
                )

            # Heavy bolted demolition shackle collar seating onto the cast-iron sphere.
            rig.lathe(
                frame((0, 0.165, 0), Y),
                [(0.0, 0.056), (0.016, 0.068), (0.054, 0.068), (0.068, 0.058)],
                12,
                [CAST_RIM, CAST_IRON, "copper"],
            )
            for k in range(6):
                a = k * math.tau / 6.0
                c = Vector((0.068 * math.cos(a), 0.198, 0.068 * math.sin(a)))
                rad = Vector((math.cos(a), 0, math.sin(a)))
                rig.cyl(c - rad * 0.004, c + rad * 0.012, 0.010, 6, "copper")

            # Weighted cast-iron demolition sphere (centred at y = 0.345 m, R = 0.138 m).
            ball_c = Vector((0.0, 0.345, 0.0))
            ball_r = 0.138
            rig.sphere(ball_c, ball_r, 16, 12, CAST_IRON)

            # Riveted equatorial & meridian reinforcement bands (crisp industrial break in greyscale).
            rig.torus(ball_c, Y, ball_r + 0.004, 0.012, 18, 6, CAST_RIM)
            rig.torus(ball_c, Z, ball_r + 0.003, 0.010, 18, 6, STEEL_DARK)

            # 13 chunky cast-iron demolition studs (blunt chamfered spikes with bright STEEL_WORN impact tips).
            stud_dirs = [Vector((0, 1, 0))]  # Nose demolition boss
            for ring_y, ring_count, phase in [
                (0.45, 6, 0.0),
                (-0.42, 6, math.pi / 6.0),
            ]:
                r_xy = math.sqrt(max(0.0, 1.0 - ring_y * ring_y))
                for k in range(ring_count):
                    a = phase + k * math.tau / ring_count
                    stud_dirs.append(Vector((r_xy * math.cos(a), ring_y, r_xy * math.sin(a))).normalized())

            for d in stud_dirs:
                base = ball_c + d * (ball_r - 0.008)
                rig.lathe(
                    frame(base, d),
                    [(0.0, 0.030), (0.014, 0.026), (0.034, 0.014), (0.042, 0.005)],
                    6,
                    [CAST_RIM, STEEL, STEEL_WORN],
                )


MUTATIONS = {
    "hot_wire": HotWire,
    "det_cord": DetCord,
    "dragnet_siphon": DragnetSiphon,
    "sonic_snap_sling": SonicSnapSling,
    "live_bus": LiveBusConductor,
    "tether_slam": TetherSlamClutch,
    "wrecking_flail": WreckingFlail,
}


def build_mutation(name, out_dir):
    common.reset()
    cls = MUTATIONS[name]
    part = cls.PART
    rig = MultiRig(gr.MESHES[part], cls.SLOT, cls.BONES)
    cls.build(rig)
    bmesh.ops.recalc_face_normals(rig.bm, faces=rig.bm.faces[:])
    local = rig.verts()
    root = common.empty(gr.ROOTS[part])
    obj = rig.part.to_object((0, 0, 0), root)
    gr.smooth(obj)
    closed = gr.closed_report(obj)
    arm_name = {"head": "HeadRig", "drive": "DriveRig", "mount": "MountRig"}.get(part)
    arm = gr.make_armature(root, obj, cls.BONES, arm_name) if cls.BONES else None
    path = os.path.join(out_dir, "grapple_mut_%s_%s.glb" % (name, part))
    gr.export_glb(root, path, arm)
    m = gr.gltf_metrics(path)
    m.update({
        "file": os.path.basename(path),
        "mutation": name,
        "swaps": part,
        "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(),
        "closed": closed,
        "actuators": cls.ACTUATORS,
    })
    print("GRAPPLE_MUT_EXPORT", name, part, json.dumps(m, sort_keys=True))
    ok = closed and m["tris"] <= CAP["tris"] and m["verts"] <= CAP["verts"] and m["draws"] <= CAP["draws"]
    return ok, m, local


def check_swap_fit(name, part, local_verts):
    """Verify drop-in compatibility: Line tiles in y in [0, 1]; Head & Drive fit all 5 pilot mounts
    within REACH (1.75 m) and FLOOR_Z (-0.55 m)."""
    if part == "line":
        ys = [v.y for v in local_verts]
        ok = min(ys) >= -0.012 and max(ys) <= 1.012
        print("GRAPPLE_MUT_FIT %s line y=[%.4f, %.4f] %s" % (name, min(ys), max(ys), "ok" if ok else "OUT"))
        return ok
    all_ok = True
    worst_reach = 0.0
    worst_low = 9e9
    for pilot, r in gr.RIGS.items():
        if part == "head":
            pts = [r.HEAD_AT + p for p in local_verts]
        else:
            q = x_to(r.DRIVE_AXIS)
            pts = [r.DRIVE_C + q @ p for p in local_verts]
        reach = max(p.length for p in pts)
        low = min(p.z for p in pts)
        outside = [p for p in pts if p.z < FLOOR_Z and p.length > LOW_RADIUS]
        ok = reach <= REACH and not outside
        worst_reach = max(worst_reach, reach)
        worst_low = min(worst_low, low)
        if not ok:
            print(
                "GRAPPLE_MUT_FIT %s on %s FAIL reach=%.4f (limit %.2f) low=%.4f low_outside=%d"
                % (name, pilot, reach, REACH, low, len(outside))
            )
            all_ok = False
    print(
        "GRAPPLE_MUT_FIT %s %s across 5 pilots worst_reach=%.4f (limit %.2f) worst_low=%.4f %s"
        % (name, part, worst_reach, REACH, worst_low, "ok" if all_ok else "OUT")
    )
    return all_ok


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=OUT_DIR)
    ap.add_argument("--mut", choices=list(MUTATIONS.keys()), action="append")
    args = ap.parse_args(argv)
    ok = True
    for name in args.mut or list(MUTATIONS.keys()):
        good, _, local = build_mutation(name, args.out_dir)
        fit_ok = check_swap_fit(name, MUTATIONS[name].PART, local)
        ok = ok and good and fit_ok
    if not ok:
        raise SystemExit("grapple_mut_parts: a mutation mesh is over budget, open, or out of rest fit")


if __name__ == "__main__":
    main()
