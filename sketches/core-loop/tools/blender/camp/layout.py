"""The camp's hub ring layout in Godot space (metres, +Y up, the player wakes at the origin facing -Z, the launch gate).

Andrew's storyboard call (DECISIONS.md, board 7, tapped 2026-10-16 22:36:12Z): "Hub ring: plaza spawn, launch gate straight
ahead at 70 m". Stations sit on a 48 m ring around a 26 m plaza; each is one short roll off the ring. At cruise (14 m/s) the
gate is 5 s away by rolling; the mint shortcut ramp launches the ball over the spoke for the 2 s target (DESIGN-V3.md, the
camp). The time-trial track and the sandbox yard sit outside the ring, east and west, where their size does not crowd it.

Angles are bearings in degrees measured from -Z (straight ahead) turning clockwise seen from above, so 0 is the gate,
90 is east (+X), 180 is behind the spawn and 270 is west. Every station faces the plaza: its local +Z points at the origin.
This file is data for recipes and the preview render. The camp scene (machine work) owns the placed copy.
"""
import math

RING_R = 48.0
PLAZA_R = 26.0
GATE_R = 70.0
SPOKE_W = 5.0

STATIONS = {
    "gate": (0.0, GATE_R),
    "pet": (55.0, RING_R),
    "skee": (120.0, RING_R),
    "settings": (160.0, RING_R),
    "achieve": (205.0, RING_R),
    "moss": (250.0, RING_R),
    "lockers": (305.0, RING_R),
}

TRIAL_AT = (122.0, 0.0, -20.0)
SANDBOX_AT = (-122.0, 0.0, 10.0)
SHORTCUT_AT = (0.0, 0.0, -36.0)


DRESSING = [
    *[("camp_lamp_post", b + 14.0, RING_R + 4.2, 0.0) for b in (0.0, 55.0, 120.0, 160.0, 205.0, 250.0, 305.0)],
    ("camp_signpost", 26.0, PLAZA_R + 2.5, 0.0),
    ("camp_fire_pit", 160.0, 15.0, 0.0),
    ("camp_bench", 145.0, 19.5, 0.0),
    ("camp_bench", 175.0, 19.5, 0.0),
    ("camp_shift_board", 194.0, 21.0, 0.0),
    ("camp_tarp", 270.0, 20.0, 0.0),
    ("camp_tool_rack", 280.0, 56.0, 0.0),
    ("camp_crate_stack", 232.0, 57.0, 30.0),
    ("camp_barrel", 236.0, 54.0, 0.0),
    ("camp_barrel", 330.0, 55.0, 0.0),
    ("camp_crate_stack", 90.0, 56.0, -20.0),
    *[("camp_fence", b, 61.0, 90.0) for b in (240.0, 244.0, 248.0, 252.0, 256.0, 260.0)],
]


def at(bearing, r):
    b = math.radians(bearing)
    return (r * math.sin(b), 0.0, -r * math.cos(b))


def yaw_to_centre(x, z):
    """The yaw (radians about +Y) that turns a piece's local +Z toward the origin."""
    return math.atan2(-x, -z)


def station(sid):
    bearing, r = STATIONS[sid]
    x, y, z = at(bearing, r)
    return (x, y, z), yaw_to_centre(x, z)
