"""Clips for the Spillway field crew: idle, move, windup, attack, hit and death per kind.

One clips-only GLB per kind (assets/models/world_one/clips/<kind>_clips.glb): a motion
skeleton whose bones stand on the parts the body recipe already exports, keyed with the
kill-first kit (kill_first_rig.Rig, so bone axes are Godot axes and `rot` is pitch, yaw, roll
in degrees about the bone head). No mesh is touched or re-exported: the body GLBs, their
draws and their byte checks stay as they are. src/presentation/enemy_clips.gd plays the
bones onto the body parts through joint nodes (see its rows for the part each bone drives).

Timing. The wind-up and attack lengths are read from the enemy scripts here, not copied, so
a tuning edit there changes the clip on the next build and enemy_clips_test fails until it
does. The runtime samples `windup` by the attack's own progress (telegraph or charge) and
`attack` by the seconds since the strike, so the clip cannot drift from the telegraph or
its sound; the verifier holds each length to its source within one 30 fps frame.

  windup  the attack's lead: anticipation that grows to a held squash on the release frame
  attack  the strike's live time (capped at ATTACK_CAP): the snap and follow-through
  idle    two bars at 129 BPM (3.72 s), looping, beat-keyed tics so a pack reads alive
  move    one beat (0.465 s), looping, sampled by distance travelled (STRIDE metres a loop)
  hit     0.3 s flinch: squash on frame two, overshoot, settle
  death   0.5 s downed-machine gag, played straight, before the break-up scatters it

Tone (TONE-BIBLE.md): machines are workers, so motion is holds, snaps and overshoot; the
crews ride machines that keep crisp bevels, so nothing here bends a mesh. Each death ends on
one wink (a fin boing, a lid pop, a rotor wobble), never a cheer.

  python3 field_motion.py [--kind chaser] [--sheet dir]

Procedural in this repository; no external rigs, clips or motion data.
"""
import json
import os
import re
import struct
import sys
import tempfile

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common
from kill_first_rig import BAR2, BEAT, FPS, Rig, frame, hold, merge, shake

F = 1 / FPS
SRC = os.path.join(common.SKETCH, "src", "combat")
OUT = os.path.join(common.MODELS, "world_one", "clips")
CLIPS = ("idle", "move", "windup", "attack", "hit", "death")
HIT = 0.3
DEATH = 0.5
MOVE = BEAT
ATTACK_CAP = 0.6


def gd_number(script, pattern):
    """The first number `pattern` captures in src/combat/<script>.gd."""
    text = open(os.path.join(SRC, script + ".gd")).read()
    found = re.search(pattern, text, re.M)
    assert found, (script, pattern)
    return float(found.group(1))


def const(script, name):
    return gd_number(script, r"^const %s := ([0-9.]+)\s*$" % name)


def configured(script, field):
    return gd_number(script, r"^\t%s = ([0-9.]+)\s*$" % field)


def snap(seconds):
    return (frame(seconds) - 1) / FPS


def flinch(bone_scale=(1.08, 0.88, 1.08), over=(0.97, 1.05, 0.97), drop=-0.04):
    return [(0, {}), (2 * F, {"loc": (0, drop, 0), "scale": bone_scale}), (6 * F, {"scale": over}),
            (0.2, {"scale": (1.01, 0.99, 1.01)}), (HIT, {})]


def beat_tics(t_list, pose, rise=2 * F, fall=6 * F, length=BAR2):
    """A rest track with a snap to `pose` and back at each time in t_list."""
    rows = [(0, {})]
    for t in t_list:
        rows += [(t, {}), (t + rise, pose), (t + rise + fall, {})]
    return hold(rows, length)


def throb(length, amp, beats=8):
    """Engine rumble: a small squash on every beat, closing the loop."""
    rows = []
    for b in range(beats):
        t = b * length / beats
        rows += [(t, {}), (t + 2 * F, {"scale": (1 + amp, 1 - amp, 1 + amp)})]
    return rows + [(length, {})]


def gait(length, pitch, bounce, phase=0.0):
    """One beat of a stomping roll: two dips and two rocks per loop."""
    q = length / 4
    a = [(0, {"rot": (pitch * (1 if phase == 0 else -1), 0, 0)}),
         (q, {"loc": (0, bounce, 0)}),
         (2 * q, {"rot": (-pitch * (1 if phase == 0 else -1), 0, 0)}),
         (3 * q, {"loc": (0, bounce, 0)})]
    return a + [(length, dict(a[0][1]))]


def windup_build(length, squash, shudder_axis=2, shudder=2.5, lean=None):
    """Anticipation: a slow load, a rising shudder over the last half and a held squash on
    the last three frames, so the release frame is the tightest pose of the clip."""
    held = {"scale": squash}
    if lean:
        held["rot"] = lean
    start = length * 0.45
    return merge([(0, {}), (start, {"scale": tuple(1 + (s - 1) * 0.4 for s in squash)})],
                 shake(start + F, length - 3 * F, shudder, period=2 * F, axis=shudder_axis,
                       base={"scale": tuple(1 + (s - 1) * 0.7 for s in squash)}, decay=1.12),
                 [(length - 3 * F, held), (length, held)])


def strike(length, stretch, settle=None):
    """The snap: full stretch by frame two, hold through the strike, ease home by the end."""
    hold_until = max(4 * F, length * 0.6)
    rows = [(0, {"scale": stretch}), (2 * F, {"scale": stretch}), (hold_until, {"scale": stretch})]
    if settle:
        rows.append(((hold_until + length) / 2, settle))
    return rows + [(length, {})]


def chaser(root):
    windup = snap(const("chaser", "WINDUP"))
    attack = snap(min(const("chaser", "LUNGE_TIME"), ATTACK_CAP))
    rig = Rig(root, "ChaserMotion", [
        ("body", (0, -1.0, 0), None),
        ("fin", (0, 0.95, 0.40), "body"),
        ("claws", (0, -0.1, 0.2), None),
    ])
    paw = 5 * BEAT
    rig.clip("idle", BAR2, {
        "body": merge(throb(BAR2, 0.012)[:-1], [(6 * BEAT, {}), (6 * BEAT + 3 * F, {"rot": (-5, 0, 0)}),
                                              (6.8 * BEAT, {"rot": (-5, 0, 0)}), (7.2 * BEAT, {}), (BAR2, {})]),
        "fin": beat_tics([3 * BEAT, 7 * BEAT], {"rot": (-14, 0, 0)}),
        "claws": [(0, {}), (paw, {}), (paw + 3 * F, {"rot": (16, 0, 0)}), (paw + 6 * F, {"rot": (-4, 0, 0)}),
                  (paw + 9 * F, {"rot": (16, 0, 0)}), (paw + 13 * F, {}), (BAR2, {})],
    })
    rig.clip("move", MOVE, {
        "body": gait(MOVE, 4.0, 0.07),
        "claws": [(0, {"rot": (14, 0, 0)}), (MOVE / 2, {"rot": (-14, 0, 0)}), (MOVE, {"rot": (14, 0, 0)})],
        "fin": [(0, {"rot": (8, 0, 0)}), (MOVE / 4, {"rot": (12, 0, 0)}), (MOVE / 2, {"rot": (8, 0, 0)}),
                (3 * MOVE / 4, {"rot": (12, 0, 0)}), (MOVE, {"rot": (8, 0, 0)})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.05, 0.93, 1.05)),
        "claws": [(0, {}), (0.12 * windup / 0.6, {"rot": (22, 0, 0)}), (0.22 * windup / 0.6, {"rot": (-6, 0, 0)}),
                  (0.32 * windup / 0.6, {"rot": (22, 0, 0)}), (0.42 * windup / 0.6, {"rot": (8, 0, 0)}),
                  (windup, {"rot": (8, 0, 0)})],
        "fin": merge([(0, {})], shake(windup - 6 * F, windup - F, 6, period=F, axis=0), [(windup, {})]),
    })
    rig.clip("attack", attack, {
        "body": strike(attack, (0.92, 0.9, 1.2), settle={"scale": (1.02, 1.03, 0.98)}),
        "claws": [(0, {"rot": (-28, 0, 0)}), (attack * 0.6, {"rot": (-28, 0, 0)}), (attack, {})],
        "fin": [(0, {"rot": (26, 0, 0)}), (attack * 0.6, {"rot": (26, 0, 0)}), (attack, {})],
    })
    rig.clip("hit", HIT, {
        "body": flinch(),
        "fin": merge([(0, {})], shake(F, 0.24, 14, period=2 * F, axis=0, decay=0.7), [(HIT, {})]),
    })
    rig.clip("death", DEATH, {
        "body": [(0, {}), (3 * F, {"loc": (0, -0.12, 0), "scale": (1.12, 0.78, 1.12)}),
                 (0.2, {"loc": (0, -0.2, 0), "rot": (0, 0, 14), "scale": (1.08, 0.82, 1.08)}),
                 (DEATH, {"loc": (0, -0.22, 0), "rot": (0, 0, 16), "scale": (1.08, 0.82, 1.08)})],
        "claws": [(0, {}), (3 * F, {"scale": (1.45, 0.7, 1.1)}), (DEATH, {"scale": (1.5, 0.66, 1.1)})],
        "fin": merge([(0, {}), (4 * F, {"rot": (-38, 0, 0)})],
                     shake(6 * F, DEATH - F, 22, period=2 * F, axis=0, base={"rot": (-30, 0, 0)}, decay=0.72),
                     [(DEATH, {"rot": (-30, 0, 0)})]),
    })
    return rig


def lobber(root):
    windup = snap(const("lobber", "TELEGRAPH"))
    attack = snap(const("lobber", "POSE_RECOVERY") + 0.17)
    rig = Rig(root, "LobberMotion", [
        ("body", (0, -1.5, 0), None),
        ("barrel", (0, 2.38, -0.45), "body"),
        ("bulb", (0, 2.6, 0), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": throb(BAR2, 0.008),
        "barrel": beat_tics([1 * BEAT, 5 * BEAT], {"rot": (-6, 0, 0)}, fall=10 * F),
        "bulb": [(0, {}), (2 * BEAT, {"scale": 1.035}), (4 * BEAT, {}), (6 * BEAT, {"scale": 1.035}), (BAR2, {})],
    })
    rig.clip("move", MOVE, {
        "body": [(0, {"rot": (0, 0, 2.5)}), (MOVE / 2, {"rot": (0, 0, -2.5)}), (MOVE, {"rot": (0, 0, 2.5)})],
        "barrel": [(0, {}), (MOVE / 4, {"rot": (3, 0, 0)}), (MOVE / 2, {}), (3 * MOVE / 4, {"rot": (3, 0, 0)}), (MOVE, {})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.04, 0.95, 1.04), shudder=1.4),
        "barrel": merge([(0, {})], shake(windup * 0.6, windup - 3 * F, 2.5, period=2 * F, axis=0),
                        [(windup - 3 * F, {"scale": (1.06, 0.94, 1.06)}), (windup, {"scale": (1.06, 0.94, 1.06)})]),
    })
    rig.clip("attack", attack, {
        "body": [(0, {"loc": (0, -0.12, 0), "scale": (1.08, 0.88, 1.08)}), (3 * F, {"scale": (0.97, 1.05, 0.97)}),
                 (attack * 0.7, {"scale": (1.01, 0.99, 1.01)}), (attack, {})],
        "barrel": [(0, {"scale": (0.9, 1.22, 0.9)}), (3 * F, {"scale": (1.05, 0.95, 1.05)}), (attack, {})],
        "bulb": [(0, {"scale": 0.82}), (4 * F, {"scale": 1.08}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": flinch(), "bulb": [(0, {}), (2 * F, {"scale": 0.9}), (6 * F, {"scale": 1.05}), (HIT, {})]})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"rot": (10, 0, 0), "scale": (1.04, 0.92, 1.04)}), (DEATH, {"rot": (14, 0, 4), "loc": (0, -0.1, 0)})],
        "barrel": [(0, {}), (5 * F, {"rot": (28, 0, 0)}), (DEATH, {"rot": (34, 0, 0)})],
        "bulb": [(0, {}), (4 * F, {"loc": (0, 0.5, 0), "scale": 1.15}), (0.3, {"loc": (0, 0.7, 0.2), "rot": (0, 0, 25)}),
                 (DEATH, {"loc": (0, 0.55, 0.3), "rot": (0, 0, 40)})],
    })
    return rig


def mag_trapper(root):
    windup = snap(configured("mag_trapper", "warn_seconds"))
    attack = snap(min(configured("mag_trapper", "live_seconds"), ATTACK_CAP))
    rig = Rig(root, "MagTrapperMotion", [
        ("cart", (0, -1.1, 0), None),
        ("stack", (0, -0.23, -1.95), "cart"),
    ])
    rig.clip("idle", BAR2, {
        "cart": [(0, {}), (2 * BEAT, {"rot": (0, 0, 1.5)}), (4 * BEAT, {}), (6 * BEAT, {"rot": (0, 0, -1.5)}), (BAR2, {})],
        "stack": [(0, {}), (4 * BEAT, {"rot": (0, 18, 0)}), (4 * BEAT + 3 * F, {"rot": (0, 18, 0), "scale": (1.04, 0.96, 1.04)}),
                  (4 * BEAT + 8 * F, {"rot": (0, 18, 0)}), (7 * BEAT, {"rot": (0, 18, 0)}), (BAR2, {})],
    })
    rig.clip("move", MOVE, {
        "cart": gait(MOVE, 2.0, 0.05),
        "stack": [(0, {}), (MOVE / 2, {"loc": (0, 0.04, 0)}), (MOVE, {})],
    })
    rig.clip("windup", windup, {
        "cart": windup_build(windup, (1.03, 0.96, 1.03), shudder=1.2, lean=(-4, 0, 0)),
        "stack": [(0, {}), (windup * 0.5, {"scale": (1.03, 1.0, 1.03)}), (windup - 3 * F, {"scale": (1.08, 0.94, 1.08)}),
                  (windup, {"scale": (1.08, 0.94, 1.08)})],
    })
    rig.clip("attack", attack, {
        "cart": [(0, {"rot": (6, 0, 0)}), (3 * F, {"rot": (8, 0, 0)}), (attack * 0.6, {"rot": (2, 0, 0)}), (attack, {})],
        "stack": [(0, {"scale": (0.9, 1.12, 0.9)}), (3 * F, {"scale": (1.04, 0.97, 1.04)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"cart": flinch(), "stack": [(0, {}), (2 * F, {"rot": (0, 20, 0)}), (HIT, {})]})
    rig.clip("death", DEATH, {
        "cart": [(0, {}), (4 * F, {"rot": (-6, 0, 0), "scale": (1.05, 0.9, 1.05)}), (DEATH, {"rot": (-9, 0, -5), "loc": (0, -0.1, 0)})],
        "stack": [(0, {}), (4 * F, {"loc": (0, 0.3, 0)}), (0.3, {"loc": (0.3, 0.1, -0.2), "rot": (0, 60, 35)}),
                  (DEATH, {"loc": (0.45, -0.15, -0.3), "rot": (0, 80, 70)})],
    })
    return rig


def plated_brute(root):
    windup = snap(configured("plated_brute", "warn_seconds"))
    attack = snap(min(max(configured("plated_brute", "live_seconds"), 0.35), ATTACK_CAP))
    rig = Rig(root, "BruteMotion", [
        ("body", (0, -1.1, 0), None),
        ("feet", (0, -1.1, 0), None),
        ("pad_l", (-0.5, -0.44, 0.12), None),
        ("pad_r", (0.5, -0.44, 0.12), None),
    ])
    rig.clip("idle", BAR2, {
        "body": [(0, {}), (2 * BEAT, {"scale": (1.025, 1.015, 1.025)}), (4 * BEAT, {}),
                 (6 * BEAT, {"scale": (1.025, 1.015, 1.025)}), (BAR2, {})],
        "pad_l": beat_tics([1.5 * BEAT], {"rot": (0, 0, 8)}, fall=8 * F),
        "pad_r": beat_tics([5.5 * BEAT], {"rot": (0, 0, -8)}, fall=8 * F),
    })
    rig.clip("move", MOVE, {
        "body": [(0, {"loc": (0, -0.06, 0), "rot": (0, 0, 2)}), (MOVE / 4, {}), (MOVE / 2, {"loc": (0, -0.06, 0), "rot": (0, 0, -2)}),
                 (3 * MOVE / 4, {}), (MOVE, {"loc": (0, -0.06, 0), "rot": (0, 0, 2)})],
        "pad_l": [(0, {"rot": (10, 0, 0)}), (MOVE / 2, {"rot": (-10, 0, 0)}), (MOVE, {"rot": (10, 0, 0)})],
        "pad_r": [(0, {"rot": (-10, 0, 0)}), (MOVE / 2, {"rot": (10, 0, 0)}), (MOVE, {"rot": (-10, 0, 0)})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.06, 1.04, 1.06), shudder=1.5),
        "feet": [(0, {}), (windup * 0.3, {"scale": (1.08, 0.9, 1.08)}), (windup, {"scale": (1.1, 0.88, 1.1)})],
        "pad_l": merge([(0, {})], shake(windup * 0.5, windup - 3 * F, 4, period=2 * F, axis=2),
                       [(windup - 3 * F, {"scale": 1.12}), (windup, {"scale": 1.12})]),
        "pad_r": merge([(0, {})], shake(windup * 0.5 + F, windup - 3 * F, 4, period=2 * F, axis=2),
                       [(windup - 3 * F, {"scale": 1.12}), (windup, {"scale": 1.12})]),
    })
    rig.clip("attack", attack, {
        "body": [(0, {"loc": (0, -0.16, 0), "scale": (1.12, 0.84, 1.12)}), (3 * F, {"scale": (0.97, 1.05, 0.97)}),
                 (attack * 0.7, {"scale": (1.01, 0.99, 1.01)}), (attack, {})],
        "feet": [(0, {"scale": (1.18, 0.8, 1.18)}), (attack, {})],
        "pad_l": [(0, {"scale": (1.2, 0.8, 1.2)}), (attack, {})],
        "pad_r": [(0, {"scale": (1.2, 0.8, 1.2)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": flinch((1.06, 0.92, 1.06), (0.98, 1.03, 0.98))})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"loc": (0, -0.3, 0), "scale": (1.14, 0.8, 1.14)}), (0.25, {"loc": (0, -0.25, 0), "rot": (8, 0, 0)}),
                 (DEATH, {"loc": (0, -0.3, 0), "rot": (10, 0, 0), "scale": (1.08, 0.86, 1.08)})],
        "pad_l": [(0, {}), (5 * F, {"rot": (0, 0, 35)}), (DEATH, {"rot": (0, 0, 42)})],
        "pad_r": [(0, {}), (5 * F, {"rot": (0, 0, -35)}), (DEATH, {"rot": (0, 0, -42)})],
    })
    return rig


def winch_drone(root):
    windup = snap(configured("winch_drone", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "WinchMotion", [
        ("body", (0, 0.4, 0), None),
        ("drum", (0, -1.4, 0), "body"),
        ("rotor", (0, 2.0, 0), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": [(0, {}), (2 * BEAT, {"rot": (2, 0, 1.5)}), (4 * BEAT, {}), (6 * BEAT, {"rot": (-2, 0, -1.5)}), (BAR2, {})],
        "drum": beat_tics([3 * BEAT, 6.5 * BEAT], {"rot": (-15, 0, 0)}, fall=4 * F),
        "rotor": [(0, {}), (BAR2 / 2, {"rot": (1.5, 0, 0)}), (BAR2, {})],
    })
    rig.clip("move", MOVE, {
        "body": [(0, {"rot": (-7, 0, 0)}), (MOVE / 2, {"rot": (-8.5, 0, 0), "loc": (0, 0.05, 0)}), (MOVE, {"rot": (-7, 0, 0)})],
        "rotor": [(0, {"rot": (-3, 0, 0)}), (MOVE, {"rot": (-3, 0, 0)})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.03, 0.97, 1.03), shudder=2.0, shudder_axis=0, lean=(6, 0, 0)),
        "drum": [(0, {}), (windup - 3 * F, {"scale": (1.0, 1.1, 1.1)}), (windup, {"scale": (1.0, 1.1, 1.1)})],
    })
    rig.clip("attack", attack, {
        "body": [(0, {"rot": (-10, 0, 0), "loc": (0, -0.12, 0)}), (4 * F, {"rot": (-6, 0, 0)}), (attack * 0.7, {"rot": (-2, 0, 0)}), (attack, {})],
        "drum": [(0, {"scale": (1.0, 0.9, 0.9)}), (3 * F, {"scale": (1.0, 1.04, 1.04)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": [(0, {}), (2 * F, {"rot": (0, 0, 12), "loc": (0, -0.1, 0)}), (8 * F, {"rot": (0, 0, -5)}), (HIT, {})]})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"loc": (0, -0.3, 0), "rot": (0, 0, 18)}), (DEATH, {"loc": (0, -0.7, 0), "rot": (12, 0, 28)})],
        "rotor": merge([(0, {})], shake(F, DEATH - F, 14, period=3 * F, axis=0, decay=0.95), [(DEATH, {"rot": (10, 0, 0)})]),
        "drum": [(0, {}), (DEATH, {"rot": (-90, 0, 0)})],
    })
    return rig


def jolt_layer(root):
    windup = snap(configured("jolt_layer", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "JoltMotion", [
        ("body", (0, -1.1, 0), None),
        ("coil", (0, 2.4, -0.25), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": throb(BAR2, 0.01),
        "coil": merge([(0, {})], shake(6 * BEAT, 6 * BEAT + 8 * F, 3, period=F, axis=2), [(BAR2, {})]),
    })
    rig.clip("move", MOVE, {
        "body": gait(MOVE, 2.5, 0.04),
        "coil": [(0, {"rot": (6, 0, 0)}), (MOVE / 2, {"rot": (2, 0, 0)}), (MOVE, {"rot": (6, 0, 0)})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.04, 0.95, 1.04), shudder=1.5),
        "coil": merge([(0, {})], shake(windup * 0.4, windup - 3 * F, 5, period=F, axis=2),
                      [(windup - 3 * F, {"scale": (1.15, 1.1, 1.15)}), (windup, {"scale": (1.15, 1.1, 1.15)})]),
    })
    rig.clip("attack", attack, {
        "body": [(0, {"loc": (0, -0.1, 0), "scale": (1.06, 0.9, 1.06)}), (3 * F, {"scale": (0.98, 1.03, 0.98)}), (attack, {})],
        "coil": [(0, {"scale": (0.9, 1.25, 0.9)}), (4 * F, {"scale": (1.03, 0.98, 1.03)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"loc": (0, -0.15, 0), "scale": (1.1, 0.82, 1.1)}), (DEATH, {"loc": (0, -0.2, 0), "rot": (0, 0, -10)})],
        "coil": merge([(0, {}), (3 * F, {"loc": (0, 0.4, 0), "scale": (1, 1.3, 1)})],
                      shake(5 * F, DEATH - F, 18, period=2 * F, axis=2, base={"loc": (0, 0.35, 0)}, decay=0.75),
                      [(DEATH, {"loc": (0, 0.35, 0)})]),
    })
    return rig


def hooker(root):
    windup = snap(configured("hooker", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "HookerMotion", [
        ("body", (0, -1.1, 0), None),
        ("harpoon", (0.9, 3.1, 0), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": [(0, {}), (2 * BEAT, {"rot": (0, 0, 1.2)}), (4 * BEAT, {}), (6 * BEAT, {"rot": (0, 0, -1.2)}), (BAR2, {})],
        "harpoon": beat_tics([3 * BEAT, 7 * BEAT], {"rot": (-6, 0, 0)}, fall=5 * F),
    })
    rig.clip("move", MOVE, {
        "body": gait(MOVE, 2.0, 0.05),
        "harpoon": [(0, {"rot": (3, 0, 0)}), (MOVE / 2, {"rot": (-3, 0, 0)}), (MOVE, {"rot": (3, 0, 0)})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.04, 0.95, 1.04), shudder=1.4, lean=(0, 0, -3)),
        "harpoon": merge([(0, {})], shake(windup * 0.5, windup - 3 * F, 3, period=2 * F, axis=1),
                         [(windup - 3 * F, {"scale": (1.0, 0.95, 1.08)}), (windup, {"scale": (1.0, 0.95, 1.08)})]),
    })
    rig.clip("attack", attack, {
        "body": [(0, {"rot": (0, 0, 4), "scale": (0.97, 1.04, 0.97)}), (3 * F, {"rot": (0, 0, 2)}), (attack, {})],
        "harpoon": [(0, {"rot": (6, 0, 0)}), (3 * F, {"rot": (-3, 0, 0)}), (attack * 0.6, {"rot": (1, 0, 0)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"loc": (0, -0.12, 0), "scale": (1.08, 0.86, 1.08)}), (DEATH, {"loc": (0, -0.2, 0), "rot": (0, 0, 9)})],
        "harpoon": [(0, {}), (5 * F, {"rot": (-24, 0, 0)}), (0.3, {"rot": (-40, 0, 6)}), (DEATH, {"rot": (-36, 0, 6)})],
    })
    return rig


def ramp_flipper(root):
    windup = snap(configured("ramp_flipper", "warn_seconds"))
    attack = snap(min(const("ramp_flipper", "TILT") + 0.05, ATTACK_CAP))
    rig = Rig(root, "RampMotion", [
        ("body", (0, -1.1, 0), None),
    ])
    rig.clip("idle", BAR2, {
        "body": merge(throb(BAR2, 0.01)[:-1], [(5 * BEAT, {}), (5 * BEAT + 3 * F, {"rot": (0, 0, 2.5)}),
                                             (5.6 * BEAT, {"rot": (0, 0, -1.5)}), (6.2 * BEAT, {}), (BAR2, {})]),
    })
    rig.clip("move", MOVE, {"body": gait(MOVE, 3.0, 0.05)})
    rig.clip("windup", windup, {"body": windup_build(windup, (1.05, 0.94, 1.05), shudder=1.6, lean=(-6, 0, 0))})
    rig.clip("attack", attack, {"body": strike(attack, (0.95, 1.08, 0.95), settle={"rot": (3, 0, 0)})})
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"rot": (0, 0, 10), "scale": (1.06, 0.9, 1.06)}), (0.3, {"rot": (0, 0, 22), "loc": (0, -0.1, 0)}),
                 (DEATH, {"rot": (0, 0, 20), "loc": (0, -0.14, 0)})],
    })
    return rig


def boom_tender(root):
    windup = snap(configured("boom_tender", "warn_seconds"))
    attack = snap(const("boom_tender", "SWEEP"))
    rig = Rig(root, "BoomMotion", [
        ("hull", (0, -1.3, 0), None),
        ("reel", (0, 0.2, 0.5), "hull"),
        ("boom", (0, -1.8, 0), None),
    ])
    rig.clip("idle", BAR2, {
        "hull": merge(throb(BAR2, 0.008)[:-1], [(0, {}), (2 * BEAT, {"rot": (0, 0, 1.5)}), (4 * BEAT, {}),
                                              (6 * BEAT, {"rot": (0, 0, -1.5)}), (BAR2, {})]),
        "reel": beat_tics([1.5 * BEAT, 5.5 * BEAT], {"rot": (-8, 0, 0)}, fall=4 * F),
        "boom": [(0, {}), (3 * BEAT, {"rot": (0, 2, 0)}), (5 * BEAT, {}), (7 * BEAT, {"rot": (0, -2, 0)}), (BAR2, {})],
    })
    rig.clip("move", MOVE, {
        "hull": gait(MOVE, 1.5, 0.03),
        "boom": [(0, {"rot": (0, 1.5, 0)}), (MOVE / 2, {"rot": (0, -1.5, 0)}), (MOVE, {"rot": (0, 1.5, 0)})],
    })
    clicks = []
    for k in range(5):
        t = windup * (0.1 + 0.16 * k)
        clicks += [(t, {"rot": (-6 * k, 0, 0)}), (t + 2 * F, {"rot": (-6 * (k + 1), 0, 0), "scale": 1.04}), (t + 4 * F, {"rot": (-6 * (k + 1), 0, 0)})]
    rig.clip("windup", windup, {
        "hull": windup_build(windup, (1.04, 0.95, 1.04), shudder=1.0, lean=(3, 0, 0)),
        "reel": [(0, {})] + clicks + [(windup, {"rot": (-30, 0, 0)})],
    })
    rig.clip("attack", attack, {
        "hull": [(0, {"rot": (-4, 0, 0), "scale": (0.97, 1.03, 0.97)}), (4 * F, {"rot": (-2, 0, 0)}), (attack, {})],
        "reel": [(0, {"rot": (-30, 0, 0)}), (attack * 0.7, {"rot": (6, 0, 0)}), (attack, {})],
        "boom": [(0, {"scale": (1.0, 1.0, 1.03)}), (attack * 0.5, {"scale": (1.0, 1.0, 1.0)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"hull": flinch((1.05, 0.92, 1.05), (0.98, 1.03, 0.98))})
    rig.clip("death", DEATH, {
        "hull": [(0, {}), (4 * F, {"rot": (0, 0, -8), "scale": (1.05, 0.9, 1.05)}), (DEATH, {"rot": (-4, 0, -14), "loc": (0, -0.15, 0)})],
        "reel": [(0, {}), (0.25, {"rot": (120, 0, 0)}), (DEATH, {"rot": (240, 0, 0)})],
        "boom": [(0, {}), (0.3, {"rot": (0, 14, 0), "loc": (0, -0.05, 0)}), (DEATH, {"rot": (0, 20, 0), "loc": (0, -0.08, 0)})],
    })
    return rig


def netcaster(root):
    windup = snap(configured("netcaster", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "NetcasterMotion", [
        ("body", (0, -1.1, 0), None),
    ])
    rig.clip("idle", BAR2, {
        "body": merge(throb(BAR2, 0.008)[:-1], [(5 * BEAT, {}), (5 * BEAT + 2 * F, {"rot": (0, 0, 2.0)}),
                                              (5 * BEAT + 5 * F, {"rot": (0, 0, -2.0)}), (5 * BEAT + 8 * F, {"rot": (0, 0, 1.0)}),
                                              (6 * BEAT, {}), (BAR2, {})]),
    })
    rig.clip("move", MOVE, {"body": gait(MOVE, 2.5, 0.05)})
    rig.clip("windup", windup, {"body": windup_build(windup, (1.08, 0.9, 1.08), shudder=1.0, lean=(-5, 16, 0))})
    rig.clip("attack", attack, {"body": [(0, {"rot": (6, -14, 0), "scale": (0.94, 1.1, 0.94)}), (3 * F, {"rot": (4, -10, 0)}),
                                         (attack * 0.6, {"rot": (2, -3, 0)}), (attack, {})]})
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"scale": (1.06, 0.9, 1.06)}), (0.25, {"rot": (24, 0, 0), "loc": (0, -0.12, 0)}),
                 (0.36, {"rot": (19, 0, 0), "loc": (0, -0.12, 0)}), (DEATH, {"rot": (21, 0, 0), "loc": (0, -0.14, 0)})],
    })
    return rig


def bola_thrower(root):
    windup = snap(configured("bola_thrower", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "BolaMotion", [
        ("body", (0, -1.1, 0), None),
        ("bola", (0, 2.2, 0), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": [(0, {}), (2 * BEAT, {"rot": (0, 0, 1.5)}), (4 * BEAT, {}), (6 * BEAT, {"rot": (0, 0, -1.5)}), (BAR2, {})],
        "bola": beat_tics([1 * BEAT, 3 * BEAT, 5 * BEAT, 7 * BEAT], {"loc": (0, -0.04, 0)}, fall=5 * F),
    })
    rig.clip("move", MOVE, {"body": gait(MOVE, 2.0, 0.05)})
    rig.clip("windup", windup, {"body": windup_build(windup, (1.06, 0.92, 1.06), shudder=1.2, lean=(-9, -32, 0))})
    rig.clip("attack", attack, {
        "body": [(0, {"rot": (14, 26, 0), "scale": (0.93, 1.1, 0.93)}), (3 * F, {"rot": (11, 22, 0)}),
                 (attack * 0.6, {"rot": (3, 6, 0)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"loc": (0, -0.14, 0), "scale": (1.1, 0.84, 1.1)}), (DEATH, {"loc": (0, -0.22, 0), "rot": (-8, 0, 6)})],
        "bola": merge([(0, {}), (5 * F, {"loc": (0, -0.6, 0.2)})],
                      shake(6 * F, DEATH - F, 18, period=3 * F, axis=2, base={"loc": (0, -0.7, 0.2)}, decay=0.7),
                      [(DEATH, {"loc": (0, -0.7, 0.2)})]),
    })
    return rig


def swatter(root):
    windup = snap(configured("swatter", "warn_seconds"))
    attack = snap(min(const("swatter", "BAT") + 0.05, ATTACK_CAP))
    rig = Rig(root, "SwatterMotion", [
        ("body", (0, -1.1, 0), None),
        ("paddle", (0, -0.6, 0), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": throb(BAR2, 0.01),
        "paddle": beat_tics([2 * BEAT, 6 * BEAT], {"rot": (-4, 0, 0)}, fall=4 * F),
    })
    rig.clip("move", MOVE, {"body": gait(MOVE, 1.2, 0.05)})
    rig.clip("windup", windup, {"body": windup_build(windup, (1.05, 0.94, 1.05), shudder=1.8, lean=(0, 18, 0))})
    rig.clip("attack", attack, {"body": [(0, {"rot": (0, -20, 0), "scale": (0.94, 1.08, 0.94)}), (3 * F, {"rot": (0, -16, 0)}),
                                         (attack * 0.6, {"rot": (0, -5, 0)}), (attack, {})]})
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"scale": (1.08, 0.86, 1.08)}), (0.28, {"rot": (0, 0, -20), "loc": (0, -0.14, 0)}),
                 (DEATH, {"rot": (0, 0, -18), "loc": (0, -0.16, 0)})],
        "paddle": merge([(0, {})], shake(4 * F, DEATH - F, 9, period=2 * F, axis=1, decay=0.72), [(DEATH, {})]),
    })
    return rig


def catch_trap(root):
    windup = snap(configured("catch_trap", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "CatchMotion", [
        ("body", (0, -1.1, 0), None),
        ("cup", (0, 1.6, -0.3), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": throb(BAR2, 0.012),
        "cup": beat_tics([3 * BEAT, 7 * BEAT], {"rot": (-8, 0, 0)}),
    })
    rig.clip("move", MOVE, {
        "body": gait(MOVE, 3.0, 0.05),
        "cup": [(0, {"rot": (4, 0, 0)}), (MOVE / 2, {"rot": (-4, 0, 0)}), (MOVE, {"rot": (4, 0, 0)})],
    })
    rig.clip("windup", windup, {"body": windup_build(windup, (1.1, 0.86, 1.1), shudder=1.6, lean=(-12, 0, 0))})
    rig.clip("attack", attack, {"body": strike(attack, (0.9, 1.14, 0.9), settle={"rot": (-10, 0, 0)})})
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (3 * F, {"loc": (0, -0.12, 0), "scale": (1.12, 0.8, 1.12)}), (DEATH, {"loc": (0, -0.18, 0), "rot": (-6, 0, 0)})],
        "cup": merge([(0, {}), (5 * F, {"rot": (40, 0, 0)})],
                     shake(6 * F, DEATH - F, 10, period=2 * F, axis=2, base={"rot": (34, 0, 0)}, decay=0.7),
                     [(DEATH, {"rot": (34, 0, 0)})]),
    })
    return rig


def deflector(root):
    windup = snap(configured("deflector", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "DeflectorMotion", [
        ("body", (0, -1.1, 0), None),
        ("dish", (0.6, 0.75, 1.15), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": [(0, {}), (2 * BEAT, {"rot": (0, 0, 1.4)}), (4 * BEAT, {}), (6 * BEAT, {"rot": (0, 0, -1.4)}), (BAR2, {})],
        "dish": beat_tics([3 * BEAT, 7 * BEAT], {"rot": (0, 3, 0)}),
    })
    rig.clip("move", MOVE, {"body": gait(MOVE, 2.0, 0.04)})
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.12, 0.84, 1.12), shudder=1.6, lean=(8, -30, 0)),
        "dish": [(0, {}), (windup * 0.6, {"rot": (-16, -10, 0)}), (windup, {"rot": (-22, -14, 0)})],
    })
    rig.clip("attack", attack, {
        "body": [(0, {"rot": (6, 26, 0), "scale": (1.12, 0.86, 1.12)}), (3 * F, {"rot": (5, 20, 0)}),
                 (attack * 0.6, {"rot": (2, 6, 0)}), (attack, {})],
        "dish": [(0, {"rot": (10, 12, 0), "loc": (0, 0, 0.2)}), (3 * F, {"rot": (8, 9, 0), "loc": (0, 0, 0.16)}),
                 (attack * 0.6, {"rot": (2, 2, 0)}), (attack, {})],
    })
    rig.clip("hit", HIT, {"body": flinch(), "dish": merge([(0, {})], shake(F, 0.24, 4, period=2 * F, axis=1, decay=0.7), [(HIT, {})])})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"scale": (1.06, 0.88, 1.06)}), (DEATH, {"rot": (-10, 0, 0), "loc": (0, -0.16, 0)})],
        "dish": merge([(0, {}), (6 * F, {"rot": (52, 0, 0), "loc": (0, -0.3, 0)})],
                      shake(7 * F, DEATH - F, 8, period=2 * F, axis=2, base={"rot": (54, 0, 0), "loc": (0, -0.34, 0)}, decay=0.7),
                      [(DEATH, {"rot": (54, 0, 0), "loc": (0, -0.34, 0)})]),
    })
    return rig


def gyro_jammer(root):
    windup = snap(configured("gyro_jammer", "warn_seconds"))
    attack = snap(ATTACK_CAP)
    rig = Rig(root, "GyroMotion", [
        ("body", (0, -1.1, 0), None),
        ("aerial", (0, 2.6, -0.2), "body"),
    ])
    rig.clip("idle", BAR2, {
        "body": [(0, {}), (2 * BEAT, {"rot": (2, 0, 0)}), (4 * BEAT, {}), (6 * BEAT, {"rot": (0, 0, 1.5)}), (BAR2, {})],
        "aerial": beat_tics([1 * BEAT, 5 * BEAT], {"rot": (-5, 0, 0)}, fall=5 * F),
    })
    rig.clip("move", MOVE, {
        "body": gait(MOVE, 2.5, 0.05),
        "aerial": [(0, {"rot": (3, 0, 0)}), (MOVE / 2, {"rot": (-3, 0, 0)}), (MOVE, {"rot": (3, 0, 0)})],
    })
    rig.clip("windup", windup, {
        "body": windup_build(windup, (1.14, 0.82, 1.14), shudder=2.0, lean=(-14, 0, 9)),
        "aerial": merge([(0, {}), (windup * 0.5, {"loc": (0, 0.22, 0), "scale": (1.0, 1.12, 1.0)})],
                        shake(windup * 0.5 + F, windup - 3 * F, 7, period=F, axis=0,
                              base={"loc": (0, 0.3, 0), "scale": (1.0, 1.16, 1.0)}),
                        [(windup - 3 * F, {"loc": (0, 0.34, 0), "scale": (1.0, 1.18, 1.0)}),
                         (windup, {"loc": (0, 0.34, 0), "scale": (1.0, 1.18, 1.0)})]),
    })
    rig.clip("attack", attack, {
        "body": [(0, {"rot": (-20, 0, 9), "scale": (0.88, 1.18, 0.88)}), (3 * F, {"rot": (-18, 0, 8), "scale": (0.9, 1.14, 0.9)}),
                 (attack * 0.6, {"rot": (-8, 0, 3)}), (attack * 0.8, {"rot": (6, 0, -1)}), (attack, {})],
        "aerial": merge([(0, {"loc": (0, 0.5, 0), "scale": (1.0, 1.24, 1.0), "rot": (-16, 0, 0)})],
                        shake(F, attack * 0.6, 12, period=2 * F, axis=0, base={"loc": (0, 0.4, 0), "scale": (1.0, 1.14, 1.0)}, decay=0.7),
                        [(attack, {})]),
    })
    rig.clip("hit", HIT, {"body": flinch()})
    rig.clip("death", DEATH, {
        "body": [(0, {}), (4 * F, {"loc": (0, -0.1, 0), "scale": (1.08, 0.86, 1.08)}), (DEATH, {"loc": (0, -0.16, 0), "rot": (0, 0, 8)})],
        "aerial": merge([(0, {}), (5 * F, {"loc": (0, -0.5, 0)})],
                        shake(6 * F, DEATH - F, 8, period=2 * F, axis=2, base={"loc": (0, -0.6, 0)}, decay=0.72),
                        [(DEATH, {"loc": (0, -0.6, 0)})]),
    })
    return rig


KINDS = {"chaser": chaser, "lobber": lobber, "mag_trapper": mag_trapper, "plated_brute": plated_brute,
         "winch_drone": winch_drone, "jolt_layer": jolt_layer, "hooker": hooker, "ramp_flipper": ramp_flipper,
         "boom_tender": boom_tender, "netcaster": netcaster, "bola_thrower": bola_thrower, "swatter": swatter,
         "catch_trap": catch_trap, "deflector": deflector, "gyro_jammer": gyro_jammer}


def export(rig, path):
    """Writes the clips-only GLB (bones and animations, no mesh) byte-identically on rerun
    and returns {clip: seconds} as the file holds them."""
    assert sorted(rig.clips) == sorted(CLIPS), sorted(rig.clips)
    rig.stop()
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 1, frame(max(rig.clips.values()))
    bpy.context.view_layer.update()
    for o in scene.objects:
        o.select_set(False)
    for o in common.tree(rig.root):
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig.arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="scrapkeep-fm-") as scratch:
        packed = os.path.join(scratch, os.path.basename(path))
        bpy.ops.export_scene.gltf(filepath=packed, export_format="GLB", use_selection=True,
            export_animations=True, export_animation_mode="ACTIONS", export_anim_slide_to_zero=True,
            export_frame_range=False, export_force_sampling=True, export_def_bones=False,
            export_skins=True, export_yup=True, export_materials="NONE", export_extras=False,
            export_cameras=False, export_lights=False)
        data = open(packed, "rb").read()
    with open(path, "wb") as fh:
        fh.write(data)
    size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + size])
    assert not doc.get("meshes"), "a clips file carries no mesh"
    lengths = {}
    for anim in doc["animations"]:
        times = [doc["accessors"][s["input"]]["max"][0] for s in anim["samplers"]]
        lengths[anim["name"]] = round(max(times), 4)
    for name, seconds in rig.clips.items():
        assert abs(lengths[name] - seconds) <= 0.5 / FPS, (name, lengths[name], seconds)
    print("CLIPS EXPORTED", os.path.basename(path), json.dumps(lengths, sort_keys=True))
    return lengths


def build(kind, sheet=None):
    common.reset()
    root = common.empty(kind.title().replace("_", "") + "Clips")
    rig = KINDS[kind](root)
    lengths = export(rig, os.path.join(OUT, "%s_clips.glb" % kind))
    if sheet:
        import field_motion_sheet
        field_motion_sheet.render(kind, rig, sheet)
    return lengths


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    kinds = [argv[argv.index("--kind") + 1]] if "--kind" in argv else list(KINDS)
    sheet = argv[argv.index("--sheet") + 1] if "--sheet" in argv else None
    report = {kind: build(kind, sheet) for kind in kinds}
    print("FIELD MOTION", json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
