"""Rig pose audit: bone and weight audit, extreme-pose collapse metrics, rigid-part clip and gap
metrics, loop seam check, and a pose contact sheet for the enemy and Warden rigs
(AMBITION-BRIEF "Rigs and motion": range-of-motion tests at extreme poses, corrective shapes where
joints collapse, seamless loops, bone budgets per class).

  prlimit -v12884901888 blender -b --factory-startup --threads 2 --python-exit-code 1 \
      -P sketches/core-loop/tools/blender/rig_pose_audit.py -- --world one --out DIR \
      [--glb world_one/enemy_foreman.glb] [--size 360] [--samples 10] [--no-render] [--strict]

--world one|two|three|bosses picks the set; --glb audits one rig (a path under assets/models, with or
without assets/models/ or res://assets/models/ and .glb). Writes
  DIR/rig_audit_<world>.json   every number below
  DIR/pose_sheet_<world>.png   one row per rig: rest, then the 5 worst poses, labelled
  DIR/loops_<world>.png        per looped clip: first, middle, last, last over first at 50%
and prints one `RIG_AUDIT <glb> {json summary}` line per rig. Flags are findings, so the exit
code is 0 whenever the audit ran, unless --strict is given: then it is 1 when any rig has an
unexcused COLLAPSE, CLIP or GAP flag (not DELIBERATE-*) or a failing loop seam not listed in
STRICT_EXCUSED, so a gate can run the audit. The default behaviour is unchanged.

--world bosses audits the boss rigs. They are not skinned: every part is a rigid node animated by
object-level fcurves (no armature; boss_brindle.glb et al.), so the bone, collapse, clip and gap
metrics do not apply and are reported as untested ("node_rig": true). Their loop seams are
measured with the same seam rule, one row per animated node, from LOOPS below.

Godot axes. Poses and ranges are expressed in Godot axes about the bone head (Godot (x, y, z) is
Blender (x, -z, y)): rotation in degrees about X, Y, Z (Euler XYZ), translation in metres, scale
as a factor. Bones are posed relative to their parent at rest, one bone at a time, so a bone's
extreme moves its subtree rigidly. tools/blender/world_one/kill_first_rig.py documents the
convention these GLBs follow: each mesh island is weighted whole to one bone; only the Linker,
the Plated Brute and warden_mind blend weights.

Ranges of motion. Rigs with clips: every action sampled every 1/30 s. Procedural rigs (no clips):
PROCEDURAL below, read from the game scripts (file:line beside each entry). A pose is each deforming
bone at its in-game extreme on each axis it moves (both signs where both occur), plus a stress pose
at 1.25x that extreme (+-15 degrees where the game rotates the axis by less than 10), plus each
clip's whole-rig extreme frame (the sampled frame with the largest summed bone rotation).

Metrics, on the deformed mesh (linear blend skinning in numpy, checked once per rig against
Blender's own evaluation):
  triangles touching a blended vertex: min deformed/rest area; max angle between the deformed
  normal and the normal a rigid move by the triangle's dominant bone would give, and the count that
  point the other way; edges between two blended vertices: min deformed/rest length.
  COLLAPSE: area ratio < 0.35, edge ratio < 0.5, or any blended triangle turned inside out where
  something can see it (normal_flipped_visible: the flipped triangle's centroid has a free ray out
  of the rest of the mesh) at an in-game extreme; STRESS-COLLAPSE: only at a stress pose. A flip
  buried inside other geometry is reported as normal_flipped but is not a flag.
  Rigid islands (connected components, welded by position, weighted whole to one bone), island
  pairs on parent/child bones and on any two bones whose islands touch at rest:
  CLIP: vertices of one island that sit inside the other island's volume at the pose and did not
  at rest (inside = behind the nearest face's normal; closed islands are exact, an open island
  falls back to the nearest-surface depth along the normal and is marked open_mesh). Depth is
  the distance to that surface. Flag over max(30 mm, 5% of the smaller island's rest bounding
  box diagonal). The old triangle-pair overlap count stays as clip_tri_pairs, info only.
  GAP: islands closer than 0.01 m at rest and farther than max(30 mm, 5% of the smaller diagonal)
  at the pose, with the gap also given as a fraction of that diagonal.
  STRESS-CLIP and STRESS-GAP when only a stress pose does it. Clips listed in DELIBERATE are
  designed detachments or impacts: their GAP and CLIP become DELIBERATE-GAP and DELIBERATE-CLIP
  and leave the defect counts; COLLAPSE is never excused and is reported separately. Listing a
  clip there takes it out of the range of motion (it adds only extremes beyond the others, no stress
  pose), so it is for designed clips only. A motion a rig designs in every clip goes in
  DESIGNED_PAIRS instead: those pairs are excused in every pose and every clip still sets the
  ranges. Tool limit: the extremes are per Godot axis, so a hinge turned about an oblique axis is
  split into per-axis poses (a plate "rY +22 deg" is rotated about the wrong axis); such a pose is
  not one the game reaches, and only a render settles whether it is a defect.
  Kit against its body (HOSTS below): a kit rig whose parts never touch one another is measured
  against the body it rides. The body is skinned at the same clip time, every 1/15 s of every clip
  both share except the exempt ones, and each kit vertex is tested against the whole body mesh
  (nearest face, behind its normal and the ray straight out from the axis meets the body = inside),
  and each body vertex inside a kit part's bounding box is tested against the kit's closed prisms.
  A part deeper than max(30 mm, 5% of its own bounding box diagonal) is a CLIP defect, reported as host_clip in the JSON and on the rig's sheet row.
  Loop seam (clips the game loops, LOOPS below): per bone the pose delta between the first and
  last key, the velocity change between the first and last 1/30 s steps. SEAM: location > 1 mm,
  rotation > 0.5 degrees, scale > 0.001, or a velocity change at the seam above 1.5 x the clip's
  largest interior frame-to-frame velocity change and above a floor of 5 mm, 0.5 degrees or 0.01
  scale per frame (the rule in tests/rig_loop_seam_test.gd, which runs the same check on the
  imported Godot animations); both numbers are reported.

Renders. EEVEE and Workbench need an EGL context this box lacks, so the sheets render with Cycles
CPU at a low sample count and the vertex colours as base colour (as glb_stills.py does). Every
tile of a rig shares one three-quarter camera framed on the rest bounds over a neutral ground.
Procedural in this repository; numpy and mathutils ship with Blender; no added dependencies.
"""
import fnmatch
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
SKETCH = os.path.normpath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(SKETCH, "assets", "models")
sys.path.insert(0, HERE)
import cycles_device

WORLDS = {
    "one": ["world_one/enemy_foreman", "world_one/enemy_dispatcher", "world_one/enemy_splitter",
            "world_one/enemy_splitter_piece", "world_one/enemy_linker", "world_one/enemy_miniboss",
            "world_one/enemy_plated_brute", "warden_reactor"],
    "two": ["world_two/enemy_lamp_swarm", "warden_swarm", "warden_swarm_kit_drones"],
    "three": ["world_three/enemy_anchor_crew", "world_three/enemy_kite_drone", "warden_mind",
              "bosses/mind_hand"],
    "bosses": ["bosses/boss_brindle", "bosses/boss_brindle_scooter", "bosses/boss_mind_base",
               "bosses/boss_mind_kit", "bosses/boss_waking_base", "bosses/boss_waking_kit"],
}
NODE_RIGS = set(WORLDS["bosses"])

LOOPS = {
    "world_one/enemy_foreman": ["idle"],
    "world_one/enemy_dispatcher": ["idle"],
    "world_one/enemy_splitter": ["crawl"],
    "world_one/enemy_splitter_piece": ["scurry"],
    "world_one/enemy_linker": ["idle", "braced"],
    "warden_reactor": ["idle"],
    "warden_swarm": ["idle"],
    "warden_swarm_kit_drones": ["idle"],
    "warden_mind": ["idle"],
    "bosses/mind_hand": ["still_track"],
    "bosses/boss_brindle": ["idle_roll"],
    "bosses/boss_brindle_scooter": ["chase"],
    "bosses/boss_mind_kit": ["attention"],
}

STRICT_EXCUSED = {
}

HOSTS = {"warden_swarm_kit_drones": {"host": "warden_swarm", "skip": ("break", "snip")}}
HOST_STEP = 1.0 / 15

_SHED_CELLS = ("Cell[7-9]", "Cell[1-4][0-9]", "Cell5[01]")

LAND_PAIRS = [("Palm", "Finger?_0"), ("Finger?_0", "Finger?_1"), ("Finger?_1", "Finger?_2"), ("Finger?_0", "Knuckle?")]
DELIBERATE = {
    "world_one/enemy_foreman": {
        "break": {"pairs": [("Cabinet", "Hat"), ("Cabinet", "Hand"), ("Chassis", "Mast"), ("Mast", "Horn*")],
                  "cite": "kfm:124-126 'the hand spins out to six o'clock, the hat flies and lands askew; then each trombone note sags the mast one step further'; Hat key y 1.15 m kfm:154, Hand 900 deg kfm:152-153, mast and horn droop keys kfm:138-147"},
        "tell": {"pairs": [("Cabinet", "Hat")],
                 "cite": "kfm:101 'the steam at 0.55 pops the hat again'; Hat keys kfm:109-112. Mast/Horn overlap is not excused"},
    },
    "world_one/enemy_dispatcher": {
        "break": {"pairs": [("Root", "Body"), ("Body", "Eye?"), ("Mast", "Radar"), ("Body", "Tongue")],
                  "cite": "kfm:258-260 'line disconnected. The printer jams and spews paper, the mast sproings up and wobbles with the radar spinning off-beat, the eyes boing out on springs, then the box sags sideways'; Tongue kfm:275-277, Radar 710 deg kfm:281-282, eye_boing kfm:262-267"},
    },
    "world_one/enemy_splitter": {
        "break_split": {"pairs": [("Pod?", "*"), ("Core", "*"), ("*", "Lamp")],
                        "cite": "kfm:376-377 'the three pods burst out and the core and fuse go', SPLIT_BURST 0.45 m kfm:300"},
        "break_clean": {"pairs": [("*", "Lamp"), ("Core", "Leg??"), ("Core", "Pod?"), ("Leg??", "Pod?")],
                        "cite": "kfm:390-391 'one fat pop. Squashed flat, it bounces once and deflates; the fuse lamp pops off its neck, flies, lands beside it'; Body squash kfm:393-397, hips lift kfm:402-403. part() (kfm:324-333) never names a mesh island Body: the squashed shell is Core"},
    },
    "world_one/enemy_linker": {
        "cut": {"pairs": [("*", "Dish*"), ("Root", "Boom"), ("Cab", "Crew"), ("Cab", "Ears"), ("Crew", "Ears")],
                "cite": "kfm:565-568 'The dish drops onto its partner, slides off and lands on its back... The boom, freed of its load, springs up; the crew ducks, then peeks over the cab roof'"},
    },
    "world_two/enemy_lamp_swarm": {
        **{"proc:LampShutter%d%s:rY%s" % (i, b, sign): {
            "pairs": [("LampShutter%d" % i, "LampShutter%dB" % i)],
            "cite": "lamp_swarm.gd:193 the barn doors swing apart to +-100 deg on the warn (enemy_lamp_swarm.py:221-227 previews it)"}
           for i in range(3) for b, sign in (("", "-"), ("B", "+"))},
        **{"proc:LampLens%d:sU+" % i: {
            "pairs": [("LampBulb%d" % i, "LampLens%d" % i)],
            "cite": "lamp_swarm.gd:191 the lens shrinks to 0.001 at the bone head, inside its bulb, until open"}
           for i in range(3)},
    },
    "world_one/enemy_plated_brute": {
        "proc:SlamPadLeft:tY+": {"pairs": [("BruteFeet", "SlamPad*"), ("BruteRear", "SlamPad*")],
                                 "cite": "plated_brute.gd:288-309 e09_pads_raise: the pads rise PAD_RISE 2.5 m (:45) off the body on the warn"},
        "proc:SlamPadLeft:tY-": {"pairs": [("BruteFeet", "SlamPad*"), ("BruteRear", "SlamPad*")],
                                 "cite": "plated_brute.gd:48 PAD_PLANT -0.47 m, :302 held for the rest of LIVE (lift = PAD_PLANT / PAD_RISE); the shoulder strip inverts here but sits wholly inside the torso (rig audit, normal_flipped_visible 0)"},
        "proc:SlamPadRight:tY-": {"pairs": [("BruteFeet", "SlamPad*"), ("BruteRear", "SlamPad*")],
                                  "cite": "plated_brute.gd:48 PAD_PLANT -0.47 m, :302 held for the rest of LIVE; shoulder strip inside the torso (normal_flipped_visible 0)"},
        "proc:SlamPadRight:tY+": {"pairs": [("BruteFeet", "SlamPad*"), ("BruteRear", "SlamPad*")],
                                  "cite": "plated_brute.gd:288-309 e09_pads_raise: the pads rise PAD_RISE 2.5 m (:45) off the body on the warn"},
    },
    "world_three/enemy_anchor_crew": {
        "proc:CrewBrace:tY-": {"pairs": [("AnchorFeet", "CrewBrace")],
                               "cite": "anchor_crew.gd:122 the body sinks 0.08 m with the wind-up and holds it; enemy_anchor_crew.py:72-75 the feet boxes sit inside the hull at rest"},
    },
    "world_three/enemy_kite_drone": {
        **{"proc:KitePaw%s:t%s" % (side, axis): {"pairs": [("KitePaw*", "PodRoot")],
                                                 "cite": "kite_drone.gd:177-180 the paws tuck 0.08 m back (and 0.08 up) into the pod with the wind-up tension"}
           for side in ("Left", "Right") for axis in ("Z-", "Y+")},
    },
    "warden_swarm": {
        "break": {"pairs": [("*", "*")], "cite": "ws:42 'chunk_shed and break (falling cells)'; cells split off and fall ws:491-498, hull falls ws:528-531"},
        "chunk_shed": {"pairs": [("Cell[7-9]", "Yoke"), ("Cell1[0-8]", "Yoke"), ("Cell[7-9]", "Cell[1-6]"), ("Cell1[0-8]", "Cell[1-6]"),
                                 *[(c, "Seam" + n[4:]) for c in _SHED_CELLS for n in _SHED_CELLS]],
                       "cite": "ws:26-29, :42, :110, :483-487, :547-548, :552-563 the shed rings' cells (Cell7 to Cell51) fall away from the Yoke, Ring1 and each other (a shed ring's cells against another shed ring's pinpricks); hero_assets.gd:2310-2318 enables one ring's track"},
    },
    "warden_swarm_kit_drones": {
        "break": {"pairs": [("*", "*")], "cite": "ws:721-730 drones drop, spin and fly out"},
        "snip": {"pairs": [("*", "*")], "cite": "ws:704-718 the file of three walks off along the rope (:42-43)"},
    },
    "warden_mind": {
        **{c: {"pairs": [("Finger*", "Finger*")],
               "cite": "wm:45-48 'A lost finger folds shut under its neighbours: the last two segments drop about a metre'; fold wm:639-647, :712-717"}
           for c in ("chunk_lost", "chunk_lost_ring", "chunk_lost_middle", "chunk_lost_index")},
        "grip_falter": {"pairs": [("Stalk*", "*"), ("LensMount", "*"), ("Lens", "*")],
                        "cite": "wm:740-746 Stalk1, Stalk2 and LensMount drop DROP/3, the lens swells"},
        **{c: {"pairs": [("Knuckle*", "*")],
               "cite": "wm:728-734 the knuckle flicks out along its dome normal and swells 25%; design-v3/wardens/mind.md:127 'shrug: the flared knuckle flicks outward'"}
           for c in ("shrug", "shrug_1", "shrug_2")},
        "knocked_down": {"pairs": [("Hand", "*"), ("Palm", "*"), ("Finger*", "*"), ("Stalk*", "Lens"), ("LensMount", "Lens")],
                         "cite": "wm:769-775 the hand tumbles over and the fingers splay; wm:979 'tumble the hand (knocked_down)'; wm:773 the lens swells 1.3x over the last sleeve end"},
        "active": {"pairs": [("Stalk*", "Lens"), ("LensMount", "Lens")],
                   "cite": "wm:705-710 Lens scales 1.3 about its centre; the shell grows over Stalk2's sleeve end and the neck core, which sit inside the cap at rest (renders: nothing shows through)"},
        "glide": {"pairs": [("LensMount", "Lens"), ("Stalk*", "Lens")],
                  "cite": "wm:760 Lens pitches 0.25 +- 0.05 rad; the neck core rides inside the centred seat, wm:512-515, and the sleeve end sinks into the cap (renders clean)"},
        **{c: {"pairs": LAND_PAIRS + extra,
               "cite": cite}
           for c, extra, cite in (
               ("land", [], "wm:762-768 the clamp curls every finger to 0.75/0.9/0.7 rad (clamp :764, curl :767) and the thumb 0.35 rad; ROOT_Y wm:197 seats each root one JOINT_R (wm:194, :457) inside the palm edge, so the root drum meets the palm and the joint drums meet their neighbours (renders: nothing shows through)"),
               ("takeoff", [("Palm", "Thumb_0"), ("Thumb_?", "Thumb_?")],
                "wm:747-754 the fist: every finger curls to CURL_SHUT (wm:638), thumbs turn 0.5/0.6/0.5 rad; the land contacts (wm:762-768, ROOT_Y :197, JOINT_R :194) plus the thumb drums"))},
        "final_quiet": {"pairs": [("Thumb_*", "*"), ("Lens*", "*"), ("SmallLens*", "*")],
                        "cite": "wm:776-785 thumbs fold shut and the iris closes"},
        "perch": {"pairs": [("Stalk*", "Stalk*"), ("Stalk*", "LensMount"), ("Stalk*", "Lens"), ("Finger?_1", "Finger?_2"),
                            ("Thumb_?", "Thumb_?")],
                  "cite": "wm:720-724 the thumb turns 0.45 and 0.6 rad and its wedge sits inside the 0.22 m joint drum (wm:483); wm:491-492 each stalk core 'hides in the sleeve above it at rest'; wm:648-649, :725-727 the perch "
                          "lift slides Stalk1, Stalk2 and LensMount up into their sleeves; wm:720-722 the hook folds segment 2 "
                          "back under segment 1 (pi + 0.1 - c1), touching only at the knuckle cap; the same lift telescopes the lens up "
                          "into the stalk's last sleeve (renders: the lens cap rides under the sleeve ring, nothing shows through)"},
    },
    "bosses/mind_hand": {
        **{c: {"pairs": [("LensRoot", "MainLens"), ("Iris?", "MainLens"), ("MainLens", "*Target"), ("MintTarget", "SlateTarget")],
               "cite": "bosses/mind_hand.py:309-316 MainLens scales to 1.5 (lens_scale), the six irises open to 0.24 m on the lens face (aperture) and the mint and slate targets swap by scale on the same lens face; keys :335-340 for exact_strike, brace and recover"}
           for c in ("brace", "recover")},
        "exact_strike": {"pairs": [("LensRoot", "MainLens"), ("Iris?", "MainLens"), ("MainLens", "*Target"), ("MintTarget", "SlateTarget"),
                                   ("Segment1", "Segment2")],
                         "cite": "bosses/mind_hand.py:309-316 MainLens 1.5, irises and targets as brace/recover; :335-340 key; the Segment1 bend and Segment2 re-aim :302-308"},
        "quote_warn": {"pairs": [("LensRoot", "MainLens"), ("Iris?", "MainLens"), ("MainLens", "*Target"), ("Segment1", "Segment2")],
                       "cite": "bosses/mind_hand.py:334 key lens_scale 1.3 and bend -0.5; the lens swell and the Segment1 bend :302-308; MintTarget hidden at scale 0.001 (:311) collapses to a point inside the lens"},
        "still_track": {"pairs": [("MainLens", "MintTarget")],
                        "cite": "bosses/mind_hand.py:296 reset_pose hides MintTarget at scale 0.001, a point inside the r 0.7 lens (:282)"},
        "lens_break": {"pairs": [("LensRoot", "*"), ("*", "MainLens")],
                       "cite": "bosses/mind_hand.py:317-320 LensRoot drops 0.55 m and tips, MainLens shrinks to 0.05; key :341"},
    },
}


def pose_arrays(rig, clip, t):
    """The rig's skinned vertices at time t seconds into the clip."""
    vals = {b: v for b, v in clip.sample(clip.start + t * clip.fps).items() if b in rig.index}
    basis = {rig.index[b]: m for b, m in basis_of_named(rig, vals).items()}
    return rig.skin(rig.chain(basis))


def host_frames(spec):
    """{clip: [(t, vertices)]} of the body the kit rides, every HOST_STEP, plus its triangles."""
    host = Rig(spec["host"])
    out = {}
    for clip in host.clips.values():
        if clip.name in spec["skip"]:
            continue
        n = int(clip.seconds / HOST_STEP + 1e-6)
        ts = [i * HOST_STEP for i in range(n + 1)] + ([clip.seconds] if clip.seconds - n * HOST_STEP > 1e-6 else [])
        out[clip.name] = [(t, pose_arrays(host, clip, t)) for t in ts]
    return out, host.T.copy()


def host_clip(rig, frames, tris):
    """Per shared clip: the deepest a kit vertex sits inside the body and the deepest a body vertex
    sits inside a kit part (depth_mm is the larger), where, and the threshold."""
    owner = [row[0][0] if row else -1 for row in rig.groups]
    pts = {}
    for v, b in enumerate(owner):
        pts.setdefault(b, []).append(v)
    thr = {b: max(MIN_DEPTH, MIN_FRAC * float(np.linalg.norm(np.ptp(rig.V0[vs], axis=0)))) for b, vs in pts.items()}
    res = {}
    for name, rows in frames.items():
        clip = rig.clips.get(name)
        if clip is None:
            continue
        worst = {"depth_mm": 0.0, "t": None, "part": None, "thr_mm": None, "over": False, "kit_in_body_mm": 0.0, "body_in_kit_mm": 0.0}

        def note(kind, depth, t, b):
            worst[kind] = max(worst[kind], round(depth * 1000, 2))
            if depth * 1000 > worst["depth_mm"]:
                worst.update({"depth_mm": round(depth * 1000, 2), "t": round(t, 4), "part": rig.names[b], "thr_mm": round(thr[b] * 1000, 1),
                              "over": depth > thr[b]})
        for t, Vh in rows:
            Vk = pose_arrays(rig, clip, t)
            tree = BVHTree.FromPolygons(Vh.tolist(), tris.tolist(), all_triangles=True)
            for v in range(len(Vk)):
                r = tree.find_nearest(tuple(Vk[v]))
                if r is None or (Vector(Vk[v]) - r[0]).dot(r[1]) >= 0:
                    continue
                out = Vector((Vk[v][0], Vk[v][1], 0.0))
                if out.length < 1e-6 or tree.ray_cast(Vector(Vk[v]), out.normalized())[0] is None:
                    continue
                note("kit_in_body_mm", r[3], t, owner[v])
            ktree = BVHTree.FromPolygons(Vk.tolist(), rig.T.tolist(), all_triangles=True)
            for b, vs in pts.items():
                lo, hi = Vk[vs].min(0) - 0.01, Vk[vs].max(0) + 0.01
                for w in np.nonzero(((Vh >= lo) & (Vh <= hi)).all(1))[0]:
                    r = ktree.find_nearest(tuple(Vh[w]))
                    if r is not None and (Vector(Vh[w]) - r[0]).dot(r[1]) < 0:
                        note("body_in_kit_mm", r[3], t, b)
        res[name] = worst
    return res


DESIGNED_PAIRS = {
    "warden_swarm": [
        (r"Cell(\d+)/Seam\1", "ws:35, :113-114, :451-498 the Seam bone sinks a cell's own pinpricks into its lip (SEAM_DIM -0.05, SEAM_OFF -0.13) and "
                              "lifts them proud (SEAM_BRIGHT): a buried pinprick reads as CLIP and GAP"),
        (r"Seam7/Cell18|Cell14/Seam15|Cell16/Seam17|Cell26/Seam38|Cell30/Seam42",
         "ws:35, :113-114 the pinprick at a cell's lip corner also sits on the lip of the neighbouring cell at rest (the five contacts the audit finds); "
         "sunk or lifted by its own Seam bone it passes through that lip, hidden, and nothing else of cell i touches cell j (renders, 4x, every pose)"),
        (r"Cell(\d+)/Shutter\1_\d", "ws:507-516 each cell's plates sit in its opening and turn about the hinge (pulse 50, active 28, stagger_open 50 to 125 deg): a hinge turn "
                                    "split per Godot axis is not a pose the game reaches"),
        (r"Cell0/QueenCore", "ws:536-539 the lit core sits inside the queen cell, swells and rises 0.6 m out of it in stagger_open"),
    ],
}


def designed(key, a, b):
    return any(re.fullmatch(rx, a + "/" + b) or re.fullmatch(rx, b + "/" + a) for rx, _ in DESIGNED_PAIRS.get(key, ()))


def excused(key, clip, a, b):
    if designed(key, a, b):
        return True
    row = DELIBERATE.get(key, {}).get(clip)
    if not row:
        return False
    return any((fnmatch.fnmatchcase(a, x) and fnmatch.fnmatchcase(b, y)) or (fnmatch.fnmatchcase(a, y) and fnmatch.fnmatchcase(b, x))
               for x, y in row["pairs"])


_D = math.degrees
PROCEDURAL = {
    "world_one/enemy_miniboss": {
        "MinibossBody": {"rot": {"X": (-_D(0.35), 0.0)}, "pivot": "origin", "loc": {"Y": (-1.035, 0.0)},
                         "group": ["MinibossFistLeft", "MinibossFistRight", "MinibossPlateLeft", "MinibossPlateRight",
                                   "MinibossHalo"]},
        "MinibossFistLeft": {"loc": {"Y": (-0.6, 1.8), "Z": (-0.85, 0.5)}},
        "MinibossFistRight": {"loc": {"Y": (-0.6, 1.8), "Z": (-0.85, 0.5)}},
        "MinibossFootLeft": {"rot": {"X": (-_D(0.6), _D(0.2)), "Z": (0.0, _D(0.3))},
                             "loc": {"X": (-0.6, 0.0), "Y": (0.0, 1.1)}},
        "MinibossFootRight": {"rot": {"X": (-_D(0.6), _D(0.2)), "Z": (-_D(0.3), 0.0)},
                              "loc": {"X": (0.0, 0.6), "Y": (0.0, 1.1)}},
        "MinibossHalo": {"rot": {"Y": (-180.0, 180.0)}},
        "MinibossPlateLeft": {"rot": {"Y": (-_D(1.15), _D(1.15))}, "loc": {"X": (-0.45, 0.0), "Y": (-0.7, 0.0)}},
        "MinibossPlateRight": {"rot": {"Y": (-_D(1.15), _D(1.15))}, "loc": {"X": (0.0, 0.45), "Y": (-0.7, 0.0)}},
    },
    "world_one/enemy_plated_brute": {
        "SlamPadLeft": {"loc": {"Y": (-0.47, 2.5)}},
        "SlamPadRight": {"loc": {"Y": (-0.47, 2.5)}},
        "BruteRear": {"rot": {"X": (-30.0, 0.0)}},
    },
    "world_three/enemy_anchor_crew": {
        "CrewBrace": {"rot": {"X": (0.0, 8.0)}, "loc": {"Y": (-0.08, 0.0)}},
        "ClutchTab0": {"loc": {"Y": (0.0, 0.09)}},
        "ClutchTab1": {"loc": {"Y": (-0.045, 0.0), "Z": (0.0, 0.0779)}},
        "ClutchTab2": {"loc": {"Y": (-0.045, 0.0), "Z": (-0.0779, 0.0)}},
        "HostileHook": {"loc": {"Z": (-0.2, 0.0)}},
    },
    "world_three/enemy_kite_drone": {
        "KiteWingLeft": {"rot": {"Z": (-5.0, 0.0)}},
        "KiteWingRight": {"rot": {"Z": (0.0, 5.0)}},
        "KitePawLeft": {"loc": {"Y": (0.0, 0.08), "Z": (-0.08, 0.0)}},
        "KitePawRight": {"loc": {"Y": (0.0, 0.08), "Z": (-0.08, 0.0)}},
    },
    "world_two/enemy_lamp_swarm": {
        **{"LampShutter%d" % i: {"rot": {"Y": (-100.0, 0.0)}} for i in range(3)},
        **{"LampShutter%dB" % i: {"rot": {"Y": (0.0, 100.0)}} for i in range(3)},
        **{"LampLens%d" % i: {"scale": (0.001, 1.0)} for i in range(3)},
    },
}

AREA_FLAG = 0.35
EDGE_FLAG = 0.5
GAP_REST = 0.01
GAP_POSE = 0.03
SEAM_LOC_MM = 1.0
SEAM_ROT_DEG = 0.5
SEAM_SCALE = 0.001
SEAM_HARSHER = 1.5
SEAM_FLOOR_LOC_MM = 5.0
SEAM_FLOOR_ROT_DEG = 0.5
SEAM_FLOOR_SCALE = 0.01
MIN_DEPTH = 0.030
MIN_FRAC = 0.05
ROT_MOVES = 0.5
LOC_MOVES = 0.001
SCALE_MOVES = 0.002
STRESS = 1.25
SMALL_ROT = 10.0
SMALL_ROT_STRESS = 15.0
STEP = 1.0 / 30.0
GAP_SAMPLES = 200
INSIDE_CAP = 1500
RAY_DIRS = [Vector(d).normalized() for d in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1),
                                             (1, 1, 0), (-1, 1, 0), (1, -1, 0), (-1, -1, 0), (1, 0, 1), (-1, 0, 1),
                                             (0, 1, 1), (0, -1, 1), (1, 0, -1), (-1, 0, -1), (0, 1, -1), (0, -1, -1)]]
GAIN_MIN = 0.001
SIBLING_CAP = 1500
KINDS_GAME = ("extreme", "clip")

C = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]])
AXIS = {"X": np.array([1.0, 0, 0]), "Y": np.array([0, 1.0, 0]), "Z": np.array([0, 0, 1.0])}


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    a = {"world": "", "glb": "", "out": "", "size": 360, "samples": 10, "no-render": False, "strict": False}
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if key not in a:
            raise SystemExit("rig_pose_audit: unknown flag " + argv[i])
        if key in ("no-render", "strict"):
            a[key] = True
            i += 1
            continue
        if i + 1 >= len(argv):
            raise SystemExit("rig_pose_audit: %s takes a value" % argv[i])
        a[key] = type(a[key])(argv[i + 1])
        i += 2
    if not a["out"] or (not a["world"] and not a["glb"]):
        raise SystemExit("rig_pose_audit: --out and --world or --glb are required")
    if a["world"] and a["world"] not in WORLDS:
        raise SystemExit("rig_pose_audit: --world is one, two, three or bosses")
    return a


def norm_key(path):
    p = path.replace("res://", "").replace("\\", "/")
    p = p.split("assets/models/")[-1]
    return p[:-4] if p.endswith(".glb") else p


_FONT = {
    "A": "0E 11 11 1F 11 11 11", "B": "1E 11 11 1E 11 11 1E", "C": "0E 11 10 10 10 11 0E",
    "D": "1E 11 11 11 11 11 1E", "E": "1F 10 10 1E 10 10 1F", "F": "1F 10 10 1E 10 10 10",
    "G": "0E 11 10 17 11 11 0F", "H": "11 11 11 1F 11 11 11", "I": "0E 04 04 04 04 04 0E",
    "J": "07 02 02 02 02 12 0C", "K": "11 12 14 18 14 12 11", "L": "10 10 10 10 10 10 1F",
    "M": "11 1B 15 15 11 11 11", "N": "11 11 19 15 13 11 11", "O": "0E 11 11 11 11 11 0E",
    "P": "1E 11 11 1E 10 10 10", "Q": "0E 11 11 11 15 12 0D", "R": "1E 11 11 1E 14 12 11",
    "S": "0F 10 10 0E 01 01 1E", "T": "1F 04 04 04 04 04 04", "U": "11 11 11 11 11 11 0E",
    "V": "11 11 11 11 11 0A 04", "W": "11 11 11 15 15 15 0A", "X": "11 11 0A 04 0A 11 11",
    "Y": "11 11 0A 04 04 04 04", "Z": "1F 01 02 04 08 10 1F",
    "0": "0E 11 13 15 19 11 0E", "1": "04 0C 04 04 04 04 0E", "2": "0E 11 01 02 04 08 1F",
    "3": "1F 02 04 02 01 11 0E", "4": "02 06 0A 12 1F 02 02", "5": "1F 10 1E 01 01 11 0E",
    "6": "06 08 10 1E 11 11 0E", "7": "1F 01 02 04 08 08 08", "8": "0E 11 11 0E 11 11 0E",
    "9": "0E 11 11 0F 01 02 0C",
    ".": "00 00 00 00 00 0C 0C", "-": "00 00 00 1F 00 00 00", "+": "00 04 04 1F 04 04 00",
    ":": "00 0C 0C 00 0C 0C 00", "/": "01 01 02 04 08 10 10", "=": "00 00 1F 00 1F 00 00",
    "_": "00 00 00 00 00 00 1F", "(": "02 04 08 08 08 04 02", ")": "08 04 02 02 02 04 08",
    ",": "00 00 00 00 0C 04 08", "%": "18 19 02 04 08 13 03", "*": "00 04 15 0E 15 04 00",
    "|": "04 04 04 04 04 04 04", " ": "00 00 00 00 00 00 00",
}
GLYPH = {}
for _ch, _rows in _FONT.items():
    _bits = np.zeros((7, 5), dtype=bool)
    for _r, _hx in enumerate(_rows.split()):
        _v = int(_hx, 16)
        for _c in range(5):
            _bits[_r, _c] = bool(_v & (1 << (4 - _c)))
    GLYPH[_ch] = _bits


def draw_text(img, x, y, text, scale=2, colour=(1.0, 1.0, 1.0)):
    """img: (H, W, 3) top-down float array; text drawn with its top-left at (x, y)."""
    for k, ch in enumerate(text.upper()):
        bits = GLYPH.get(ch, GLYPH["*"])
        px = x + k * 6 * scale
        if px + 5 * scale > img.shape[1] or y + 7 * scale > img.shape[0]:
            break
        big = np.kron(bits, np.ones((scale, scale), dtype=bool))
        img[y:y + 7 * scale, px:px + 5 * scale][big] = colour


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def action_fcurves(action):
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


_PATH = re.compile(r'pose\.bones\["(.+)"\]\.(location|rotation_quaternion|rotation_euler|scale)$')


class Clip:
    """One action as per-bone fcurve lists; evaluates basis values at a Blender frame."""

    def __init__(self, action, fps):
        self.name = action.name.split("|")[-1]
        self.fps = fps
        self.tracks = {}
        lo, hi = math.inf, -math.inf
        for fc in action_fcurves(action):
            m = _PATH.match(fc.data_path)
            if not m or not len(fc.keyframe_points):
                continue
            bone, prop = m.groups()
            self.tracks.setdefault(bone, {}).setdefault(prop, {})[fc.array_index] = fc
            lo = min(lo, fc.keyframe_points[0].co[0])
            hi = max(hi, fc.keyframe_points[-1].co[0])
        self.start = 0.0 if lo == math.inf else lo
        self.end = self.start if hi == -math.inf else hi
        self.seconds = (self.end - self.start) / fps

    def frames(self, step_s=STEP):
        n = max(1, int(round(self.seconds / step_s)))
        return [self.start + i * step_s * self.fps for i in range(n)] + [self.end]

    def sample(self, frame):
        out = {}
        for bone, props in self.tracks.items():
            loc = np.array([props["location"][i].evaluate(frame) if i in props.get("location", {}) else 0.0
                            for i in range(3)])
            if "rotation_quaternion" in props:
                q = props["rotation_quaternion"]
                quat = np.array([q[i].evaluate(frame) if i in q else (1.0 if i == 0 else 0.0) for i in range(4)])
            elif "rotation_euler" in props:
                e = props["rotation_euler"]
                from mathutils import Euler
                quat = np.array(Euler([e[i].evaluate(frame) if i in e else 0.0 for i in range(3)]).to_quaternion())
            else:
                quat = np.array([1.0, 0, 0, 0])
            sc = np.array([props["scale"][i].evaluate(frame) if i in props.get("scale", {}) else 1.0
                           for i in range(3)])
            n = np.linalg.norm(quat)
            out[bone] = (loc, quat / n if n > 1e-12 else np.array([1.0, 0, 0, 0]), sc)
        return out


def quat_matrix(q):
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def rot_axis(axis, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    if axis == "X":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == "Y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def mat4(rot=None, loc=None, scale=None):
    m = np.eye(4)
    r = np.eye(3) if rot is None else rot
    if scale is not None:
        r = r @ np.diag(scale)
    m[:3, :3] = r
    if loc is not None:
        m[:3, 3] = loc
    return m


def rot_angle_deg(r):
    return math.degrees(math.acos(max(-1.0, min(1.0, (np.trace(r) - 1) / 2))))


def euler_xyz_deg(r, prev=None):
    from mathutils import Euler, Matrix as Mx
    e = Mx(r.tolist()).to_euler("XYZ", Euler(prev) if prev is not None else Euler((0, 0, 0)))
    return np.array([math.degrees(v) for v in e])


class Rig:
    def __init__(self, key):
        self.key = key
        reset_scene()
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, key + ".glb"))
        self.fps = bpy.context.scene.render.fps
        arms = [o for o in bpy.data.objects if o.type == "ARMATURE" and len(o.data.bones)]
        if not arms:
            raise SystemExit("rig_pose_audit: no armature in " + key)
        self.arm = arms[0]
        self.arm.animation_data_clear()
        bones = list(self.arm.data.bones)
        self.bones = bones
        self.names = [b.name for b in bones]
        self.index = {n: i for i, n in enumerate(self.names)}
        self.parent = [self.index[b.parent.name] if b.parent else -1 for b in bones]
        self.rest = np.array([np.array(b.matrix_local) for b in bones])
        self.rest_inv = np.array([np.linalg.inv(m) for m in self.rest])
        self.rel_rest = np.array([self.rest_inv[self.parent[i]] @ self.rest[i] if self.parent[i] >= 0 else self.rest[i]
                                  for i in range(len(bones))])
        self.aw = np.array(self.arm.matrix_world)
        self.aw_inv = np.linalg.inv(self.aw)
        self.clips = {}
        for act in bpy.data.actions:
            clip = Clip(act, self.fps)
            self.clips[clip.name] = clip
        self.meshes = [o for o in bpy.data.objects if o.type == "MESH"
                       and any(m.type == "ARMATURE" and m.object == self.arm for m in o.modifiers)]
        self._read_mesh()

    def _read_mesh(self):
        verts, tris, groups, offs = [], [], [], 0
        K = 8
        self.mesh_slices = []
        for o in self.meshes:
            me = o.data
            n = len(me.vertices)
            co = np.empty(n * 3)
            me.vertices.foreach_get("co", co)
            mw = np.array(o.matrix_world)
            co = co.reshape(n, 3)
            verts.append(co @ mw[:3, :3].T + mw[:3, 3])
            me.calc_loop_triangles()
            t = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
            me.loop_triangles.foreach_get("vertices", t)
            tris.append(t.reshape(-1, 3) + offs)
            gname = [vg.name for vg in o.vertex_groups]
            for v in me.vertices:
                row = sorted(((self.index[gname[g.group]], g.weight) for g in v.groups
                              if gname[g.group] in self.index and g.weight > 0), key=lambda p: -p[1])
                groups.append(row)
            self.mesh_slices.append((o, offs, n))
            offs += n
        self.V0 = np.concatenate(verts) if verts else np.zeros((0, 3))
        self.T = np.concatenate(tris) if tris else np.zeros((0, 3), dtype=np.int64)
        self.groups = groups
        N = len(groups)
        self.K = max(1, min(K, max((len(r) for r in groups), default=1)))
        self.idx = np.zeros((N, self.K), dtype=np.int64)
        self.w = np.zeros((N, self.K))
        for i, row in enumerate(groups):
            for k, (b, w) in enumerate(row[:self.K]):
                self.idx[i, k] = b
                self.w[i, k] = w
        self.wsum = self.w.sum(1)

    def chain(self, basis):
        """basis: {bone index: 4x4 matrix_basis}. Returns world-space deltas, (B, 4, 4)."""
        B = len(self.bones)
        pose = [None] * B

        def get(i):
            if pose[i] is None:
                local = self.rel_rest[i] @ basis.get(i, np.eye(4))
                pose[i] = get(self.parent[i]) @ local if self.parent[i] >= 0 else local
            return pose[i]
        D = np.array([get(i) @ self.rest_inv[i] for i in range(B)])
        return self.aw @ D @ self.aw_inv

    def skin(self, Dw):
        R = Dw[:, :3, :3]
        t = Dw[:, :3, 3]
        Rk = R[self.idx]
        tk = t[self.idx]
        moved = np.einsum("nkij,nj->nki", Rk, self.V0) + tk
        w = self.w
        s = self.wsum
        safe = np.where(s > 1e-4, s, 1.0)
        blended = (moved * w[..., None]).sum(1) / safe[:, None]
        return np.where((s > 1e-4)[:, None], blended, self.V0)

    def basis_from_arm_delta(self, bone, dp):
        return self.rest_inv[bone] @ dp @ self.rest[bone]

    def head(self, bone):
        return self.rest[bone][:3, 3]

    def to_godot(self, bone, loc, quat, sc, prev=None):
        brot = self.rest[bone][:3, :3]
        rarm = brot @ quat_matrix(quat) @ brot.T
        rg = C @ rarm @ C.T
        return euler_xyz_deg(rg, None if prev is None else [math.radians(v) for v in prev]), C @ (brot @ loc), sc

    def apply_blender(self, basis_values):
        """basis_values: {bone name: (loc, quat, scale)} written to the pose bones; others rest."""
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            v = basis_values.get(pb.name)
            if v is None:
                pb.location = (0, 0, 0)
                pb.rotation_quaternion = (1, 0, 0, 0)
                pb.scale = (1, 1, 1)
            else:
                pb.location = tuple(v[0])
                pb.rotation_quaternion = tuple(v[1])
                pb.scale = tuple(v[2])
        bpy.context.view_layer.update()


def basis_of(values):
    """{bone index: 4x4} from {bone index: (loc, quat, scale)}."""
    return {b: mat4(quat_matrix(q), l, s) for b, (l, q, s) in values.items()}


def pose_values(rig, spec):
    """Blender-basis (loc, quat, scale) per bone for a single-bone pose spec."""
    b = rig.index[spec["bone"]]
    head = rig.head(b)
    pivot = np.zeros(3) if spec.get("pivot") == "origin" else head
    ax, val = spec["axis"], spec["value"]
    kind = ax[0]
    if kind == "r":
        r_arm = C.T @ rot_axis(ax[1], val) @ C
        dp = mat4(np.eye(3), pivot) @ mat4(r_arm) @ mat4(np.eye(3), -pivot)
    elif kind == "t":
        t_g = AXIS[ax[1]] * val
        dp = mat4(np.eye(3), C.T @ t_g)
    else:
        s_g = np.ones(3)
        if ax[1] == "U":
            s_g[:] = val
        else:
            s_g[list("XYZ").index(ax[1])] = val
        s_arm = C.T @ np.diag(s_g) @ C
        dp = mat4(np.eye(3), head) @ mat4(s_arm) @ mat4(np.eye(3), -head)
    from mathutils import Matrix as Mx
    values, basis = {}, {}
    for name in [spec["bone"]] + list(spec.get("group", [])):
        bi = rig.index[name]
        m = rig.basis_from_arm_delta(bi, dp)
        loc, quat, scale = Mx(m.tolist()).decompose()
        values[name] = (np.array(loc), np.array(quat), np.array(scale))
        basis[bi] = m
    return values, basis


def weight_audit(rig):
    N = len(rig.groups)
    infl = np.array([sum(1 for _, w in row if w > 0.01) for row in rig.groups]) if N else np.zeros(0, dtype=int)
    hist = {}
    for c in infl:
        hist[int(c)] = hist.get(int(c), 0) + 1
    sums = np.array([sum(w for _, w in row) for row in rig.groups]) if N else np.zeros(0)
    weighted = set()
    for row in rig.groups:
        for b, w in row:
            if w > 0.01:
                weighted.add(b)
    blended = int((infl > 1).sum())
    neutral = {i for i, n in enumerate(rig.names) if n.startswith("neutral_bone")}
    neutral_v = int(sum(1 for row in rig.groups if row and row[0][0] in neutral))
    return {
        "vertices": int(N),
        "triangles": int(len(rig.T)),
        "skinned_meshes": [o.name for o in rig.meshes],
        "joints": len(rig.bones),
        "deforming_bones": sorted(rig.names[b] for b in weighted),
        "deforming_bone_count": len(weighted),
        "influence_histogram": {str(k): v for k, v in sorted(hist.items())},
        "blended_vertices": blended,
        "max_influences": int(infl.max()) if N else 0,
        "unweighted_vertices": int((infl == 0).sum()) + neutral_v,
        "unweighted_no_group": int((infl == 0).sum()),
        "unweighted_neutral_bone": neutral_v,
        "neutral_bones": sorted(rig.names[i] for i in neutral),
        "max_weight_sum_deviation": round(float(np.abs(sums - 1).max()), 6) if N else 0.0,
        "bones_without_weights": sorted(rig.names[b] for b in range(len(rig.bones)) if b not in weighted),
    }, weighted


def bone_budget():
    path = os.path.join(SKETCH, "assets", "asset_budgets.json")
    try:
        data = json.load(open(path))
    except OSError:
        return None
    found = {}
    for cls, row in data.get("classes", {}).items():
        for k in ("bones", "joints"):
            if k in row:
                found[cls] = {k: row[k]}
    return found or None


def clip_ranges(rig, names=None):
    """Per bone ranges over the clips in names (all if None), sampled every 1/30 s: Godot degrees,
    metres, scale."""
    rng = {}
    for clip in rig.clips.values():
        if names is not None and clip.name not in names:
            continue
        prev = {}
        for f in clip.frames():
            for bname, (loc, quat, sc) in clip.sample(f).items():
                if bname not in rig.index:
                    continue
                b = rig.index[bname]
                e, t, s = rig.to_godot(b, loc, quat, sc, prev.get(bname))
                prev[bname] = e
                r = rng.setdefault(bname, {"rot": {}, "loc": {}, "scale": {}})
                for i, a in enumerate("XYZ"):
                    for key, v in (("rot", e[i]), ("loc", t[i]), ("scale", sc[i])):
                        lo, hi = r[key].get(a, (math.inf, -math.inf))
                        src = r.setdefault("src", {}).setdefault((key, a), [None, None])
                        if v < lo:
                            src[0] = clip.name
                        if v > hi:
                            src[1] = clip.name
                        r[key][a] = (min(lo, v), max(hi, v))
    return rng


def table_ranges(key):
    out = {}
    for bone, row in PROCEDURAL[key].items():
        r = {"rot": dict(row.get("rot", {})), "loc": dict(row.get("loc", {})), "scale": {},
             "pivot": row.get("pivot"), "group": row.get("group", [])}
        if "scale" in row:
            r["scale"]["U"] = row["scale"]
        out[bone] = r
    return out


def make_specs(ranges, deforming_names):
    specs = []
    for bone, r in ranges.items():
        if bone not in deforming_names:
            continue
        base = {"bone": bone, "pivot": r.get("pivot"), "group": r.get("group", [])}

        def src(key, a, v, lo, hi):
            pair = r.get("src", {}).get((key, a))
            return {"src": pair[0] if v == lo else pair[1]} if pair else {}
        for a, (lo, hi) in r["rot"].items():
            for v in dict.fromkeys([x for x in (hi, lo) if abs(x) > ROT_MOVES]):
                specs.append({**base, "axis": "r" + a, "value": v, "kind": "extreme", **src("rot", a, v, lo, hi)})
                if abs(v) < SMALL_ROT:
                    for sv in (SMALL_ROT_STRESS, -SMALL_ROT_STRESS):
                        specs.append({**base, "axis": "r" + a, "value": sv, "kind": "stress", "of": v})
                else:
                    specs.append({**base, "axis": "r" + a, "value": v * STRESS, "kind": "stress", "of": v})
        for a, (lo, hi) in r["loc"].items():
            for v in dict.fromkeys([x for x in (hi, lo) if abs(x) > LOC_MOVES]):
                specs.append({**base, "axis": "t" + a, "value": v, "kind": "extreme", **src("loc", a, v, lo, hi)})
                specs.append({**base, "axis": "t" + a, "value": v * STRESS, "kind": "stress", "of": v})
        for a, (lo, hi) in r["scale"].items():
            for v in dict.fromkeys([x for x in (hi, lo) if abs(x - 1) > SCALE_MOVES]):
                specs.append({**base, "axis": "s" + a, "value": v, "kind": "extreme", **src("scale", a, v, lo, hi)})
                specs.append({**base, "axis": "s" + a, "value": max(0.001, 1 + (v - 1) * STRESS),
                              "kind": "stress", "of": v})
    return specs


def union_find_islands(n, tris):
    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in tris.tolist():
        ra, rb, rc = find(a), find(b), find(c)
        if ra != rb:
            parent[rb] = ra
        rc = find(c)
        ra = find(a)
        if ra != rc:
            parent[rc] = ra
    return np.array([find(i) for i in range(n)])


class Metrics:
    def __init__(self, rig):
        self.rig = rig
        V0, T = rig.V0, rig.T
        N = len(V0)
        infl = np.array([sum(1 for _, w in row if w > 0.01) for row in rig.groups]) if N else np.zeros(0, dtype=int)
        self.blended_v = infl > 1
        dom = np.array([row[0][0] if row else -1 for row in rig.groups], dtype=np.int64)
        tb_blend = self.blended_v[T].any(1) if len(T) else np.zeros(0, dtype=bool)
        tb_cross = ((dom[T[:, 0]] != dom[T[:, 1]]) | (dom[T[:, 1]] != dom[T[:, 2]])) if len(T) else np.zeros(0, dtype=bool)
        tb = tb_blend | tb_cross
        self.cross_bone_tris = int((tb_cross & ~tb_blend).sum())
        self.dom = dom
        self.bt = T[tb]
        self.non_bt = np.nonzero(~tb)[0]
        self.bt_area0, self.bt_n0 = self.tri_area_normal(V0, self.bt)
        self.bt_bone = np.zeros(len(self.bt), dtype=np.int64)
        for i, tri in enumerate(self.bt):
            acc = {}
            for v in tri:
                for b, w in rig.groups[v]:
                    acc[b] = acc.get(b, 0.0) + w
            self.bt_bone[i] = max(acc, key=acc.get) if acc else 0
        e = np.concatenate([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]]) if len(T) else np.zeros((0, 2), dtype=np.int64)
        e.sort(axis=1)
        e = np.unique(e, axis=0) if len(e) else e
        keep = ((self.blended_v[e[:, 0]] & self.blended_v[e[:, 1]]) | (dom[e[:, 0]] != dom[e[:, 1]])) if len(e) else np.zeros(0, dtype=bool)
        self.edges = e[keep]
        self.edge0 = np.linalg.norm(V0[self.edges[:, 0]] - V0[self.edges[:, 1]], axis=1) if len(self.edges) else np.zeros(0)
        self.edge_ok = self.edge0 > 1e-9
        self._islands()
        self._pairs()

    @staticmethod
    def tri_area_normal(V, tris):
        if not len(tris):
            return np.zeros(0), np.zeros((0, 3))
        c = np.cross(V[tris[:, 1]] - V[tris[:, 0]], V[tris[:, 2]] - V[tris[:, 0]])
        a = np.linalg.norm(c, axis=1)
        return a / 2, c / np.where(a > 1e-14, a, 1.0)[:, None]

    def _islands(self):
        rig = self.rig
        V0, T = rig.V0, rig.T
        N = len(V0)
        dom = np.array([row[0][0] if row else -1 for row in rig.groups], dtype=np.int64)
        keyed = np.concatenate([np.round(V0 / 1e-5).astype(np.int64), dom[:, None]], axis=1)
        _, wid = np.unique(keyed, axis=0, return_inverse=True)
        wid = wid.ravel()
        lab = union_find_islands(int(wid.max()) + 1, wid[T])[wid] if N and len(T) else np.zeros(N, dtype=np.int64)
        used = np.zeros(N, dtype=bool)
        used[T.ravel()] = True
        by = {}
        for v in np.nonzero(used)[0]:
            by.setdefault(int(lab[v]), []).append(int(v))
        tri_lab = lab[T[:, 0]]
        tris_by = {}
        for ti, l in enumerate(tri_lab):
            tris_by.setdefault(int(l), []).append(ti)
        self.islands = []
        for l, vs in by.items():
            bone = -1
            ok = True
            for v in vs:
                row = rig.groups[v]
                if not row or row[0][1] < 0.99:
                    ok = False
                    break
                if bone < 0:
                    bone = row[0][0]
                elif row[0][0] != bone:
                    ok = False
                    break
            tris = np.array(tris_by[l], dtype=np.int64)
            verts = np.array(vs)
            e = np.concatenate([wid[T[tris]][:, [0, 1]], wid[T[tris]][:, [1, 2]], wid[T[tris]][:, [2, 0]]])
            e.sort(axis=1)
            _, cnt = np.unique(e, axis=0, return_counts=True)
            lo, hi = V0[verts].min(0), V0[verts].max(0)
            self.islands.append({"bone": bone if ok else -1, "verts": verts, "tris": tris,
                                 "diag": float(np.linalg.norm(hi - lo)), "closed": bool((cnt == 2).all()),
                                 "id": len(self.islands)})
        self.rigid = [isl for isl in self.islands if isl["bone"] >= 0]
        self.bone_tris = {}
        for isl in self.rigid:
            self.bone_tris.setdefault(isl["bone"], []).append(isl["tris"])
        self.bone_tris = {b: np.concatenate(v) for b, v in self.bone_tris.items()}

    @staticmethod
    def bvh(V, tri_ids, T):
        sub = T[tri_ids]
        u, inv = np.unique(sub.ravel(), return_inverse=True)
        return BVHTree.FromPolygons(V[u].tolist(), inv.reshape(-1, 3).tolist(), all_triangles=True)

    @staticmethod
    def inside(V, isl, tree, lo, hi):
        """{vertex: signed depth} for the vertices of isl inside box lo..hi against the island behind
        tree: positive behind the nearest face's normal (inside), negative in front. For an open
        island this is the nearest-surface depth along the normal."""
        pts = V[isl["verts"]]
        sel = isl["verts"][((pts >= lo) & (pts <= hi)).all(1)]
        if len(sel) > INSIDE_CAP:
            sel = sel[np.linspace(0, len(sel) - 1, INSIDE_CAP).astype(int)]
        out = {}
        for v in sel:
            r = tree.find_nearest(tuple(V[v]))
            if r is not None:
                out[int(v)] = r[3] if (Vector(V[v]) - r[0]).dot(r[1]) < 0 else -r[3]
        return out

    def _pairs(self):
        rig = self.rig
        V0, T = rig.V0, rig.T
        self.pairs = []
        self.sibling_capped = False
        for c in self.bone_tris:
            p = rig.parent[c]
            if p >= 0 and p in self.bone_tris:
                self.pairs.append((p, c))
        parent_child = set(self.pairs)
        self.rest_overlap = {}
        self.contacts = {}
        self.ipairs = {}
        rest_tree = {}

        def tree0(isl):
            if isl["id"] not in rest_tree:
                rest_tree[isl["id"]] = self.bvh(V0, isl["tris"], T)
            return rest_tree[isl["id"]]
        box0 = {i["id"]: (V0[i["verts"]].min(0), V0[i["verts"]].max(0)) for i in self.rigid}

        def add(p, c, a, b, touching_only):
            lo_a, hi_a = box0[a["id"]]
            lo_b, hi_b = box0[b["id"]]
            near = not ((lo_a > hi_b + GAP_REST).any() or (lo_b > hi_a + GAP_REST).any())
            small, big = (a, b) if len(a["verts"]) <= len(b["verts"]) else (b, a)
            contact = None
            if near:
                sv = small["verts"][np.linspace(0, len(small["verts"]) - 1, min(GAP_SAMPLES, len(small["verts"]))).astype(int)]
                tree = tree0(big)
                d = math.inf
                for v in sv:
                    r = tree.find_nearest(tuple(V0[v]))
                    if r is not None:
                        d = min(d, r[3])
                if d < GAP_REST:
                    contact = {"small": small, "big": big, "samples": sv, "rest": d, "diag": min(a["diag"], b["diag"])}
            if touching_only and contact is None:
                return False
            rest_a, rest_b = {}, {}
            if not ((lo_a > hi_b).any() or (lo_b > hi_a).any()):
                rest_a = self.inside(V0, a, tree0(b), lo_b, hi_b)
                rest_b = self.inside(V0, b, tree0(a), lo_a, hi_a)
            self.ipairs.setdefault((p, c), []).append(
                {"a": a, "b": b, "diag": min(a["diag"], b["diag"]), "rest_a": rest_a, "rest_b": rest_b,
                 "open": not (a["closed"] and b["closed"])})
            if contact:
                self.contacts.setdefault((p, c), []).append(contact)
            return True
        for p, c in list(self.pairs):
            tp, tc = self.bone_tris[p], self.bone_tris[c]
            ov = self.bvh(V0, tp, T).overlap(self.bvh(V0, tc, T))
            self.rest_overlap[(p, c)] = {(int(tp[i]), int(tc[j])) for i, j in ov}
            self.ipairs[(p, c)] = []
            self.contacts[(p, c)] = []
            ip = [i for i in self.rigid if i["bone"] == p]
            ic = [i for i in self.rigid if i["bone"] == c]
            for a in ip:
                lo_a, hi_a = box0[a["id"]]
                for b in ic:
                    lo_b, hi_b = box0[b["id"]]
                    if len(ip) * len(ic) > 4000 and ((lo_a > hi_b + 1.0).any() or (lo_b > hi_a + 1.0).any()):
                        continue
                    add(p, c, a, b, False)
        R = len(self.rigid)
        if R > 1:
            lo = np.array([box0[i["id"]][0] for i in self.rigid]) - GAP_REST
            hi = np.array([box0[i["id"]][1] for i in self.rigid]) + GAP_REST
            bone = np.array([i["bone"] for i in self.rigid])
            found = 0
            for x in range(R):
                near = ((lo[x] <= hi[x + 1:]) & (hi[x] >= lo[x + 1:])).all(1) & (bone[x] != bone[x + 1:])
                for y in np.nonzero(near)[0] + x + 1:
                    a, b = self.rigid[x], self.rigid[y]
                    p, c = (a["bone"], b["bone"]) if a["bone"] < b["bone"] else (b["bone"], a["bone"])
                    if (p, c) in parent_child or (c, p) in parent_child:
                        continue
                    if found >= SIBLING_CAP:
                        self.sibling_capped = True
                        break
                    if (p, c) not in self.rest_overlap:
                        tp, tc = self.bone_tris[p], self.bone_tris[c]
                        ov = self.bvh(V0, tp, T).overlap(self.bvh(V0, tc, T))
                        self.rest_overlap[(p, c)] = {(int(tp[i]), int(tc[j])) for i, j in ov}
                    aa, bb = (a, b) if a["bone"] == p else (b, a)
                    if add(p, c, aa, bb, True):
                        found += 1
                        if (p, c) not in self.pairs:
                            self.pairs.append((p, c))
                if self.sibling_capped:
                    break
        self.pairs = [pc for pc in self.pairs if self.ipairs.get(pc)]
        self.sibling_pairs = len([pc for pc in self.pairs if pc not in parent_child])

    def evaluate(self, Vp, Dw):
        rig = self.rig
        out = {"area_min": None, "edge_min": None, "normal_dev_max_deg": None, "normal_flipped": None,
               "collapse_focus": None, "normal_flipped_visible": 0,
               "clip_depth_mm": 0.0, "clip_verts": 0, "clip_frac": 0.0, "clip_thr_mm": None, "clip_open": False,
               "clip_pair": None, "clip_ratio": 0.0, "clip_over": False, "clip_depth_max_mm": 0.0,
               "clip_tri_pairs": 0, "clip_tri_pair": None, "clip_hits": [], "gap_hits": [],
               "gap_mm": 0.0, "gap_frac": 0.0, "gap_thr_mm": None, "gap_pair": None, "gap_ratio": 0.0, "gap_over": False}
        focus_area = focus_edge = None
        if len(self.bt):
            area, n1 = self.tri_area_normal(Vp, self.bt)
            ratio = np.where(self.bt_area0 > 1e-12, area / np.maximum(self.bt_area0, 1e-12), 1.0)
            out["area_min"] = round(float(ratio.min()), 5)
            focus_area = Vp[self.bt[int(ratio.argmin())]].mean(0)
            ne = np.einsum("nij,nj->ni", Dw[self.bt_bone][:, :3, :3], self.bt_n0)
            ne /= np.maximum(np.linalg.norm(ne, axis=1, keepdims=True), 1e-12)
            valid = area > 1e-12
            dot = np.clip((n1 * ne).sum(1), -1, 1)
            ang = np.degrees(np.arccos(dot))
            out["normal_dev_max_deg"] = round(float(ang[valid].max()), 3) if valid.any() else 180.0
            fl = np.nonzero((dot < 0) & valid)[0]
            out["normal_flipped"] = int(len(fl))
            vis = 0
            if len(fl):
                tree = self.bvh(Vp, self.non_bt, rig.T)
                for i in fl:
                    c = Vp[self.bt[i]].mean(0)
                    if any(tree.ray_cast(Vector(c) + d * 1e-3, d)[0] is None for d in RAY_DIRS):
                        vis += 1
            out["normal_flipped_visible"] = vis
        if len(self.edges):
            l1 = np.linalg.norm(Vp[self.edges[:, 0]] - Vp[self.edges[:, 1]], axis=1)
            ok = np.nonzero(self.edge_ok)[0]
            if len(ok):
                r = l1[ok] / self.edge0[ok]
                out["edge_min"] = round(float(r.min()), 5)
                e = self.edges[ok[int(r.argmin())]]
                focus_edge = (Vp[e[0]] + Vp[e[1]]) / 2
        focus = focus_area
        if focus_edge is not None and (out["edge_min"] < EDGE_FLAG and not (out["area_min"] is not None and out["area_min"] < AREA_FLAG)):
            focus = focus_edge
        out["collapse_focus"] = [round(float(x), 4) for x in focus] if focus is not None else None
        T = rig.T
        V0 = rig.V0
        trees, boxes = {}, {}

        def treep(isl):
            if isl["id"] not in trees:
                trees[isl["id"]] = self.bvh(Vp, isl["tris"], T)
            return trees[isl["id"]]

        def boxp(isl):
            if isl["id"] not in boxes:
                pts = Vp[isl["verts"]]
                boxes[isl["id"]] = (pts.min(0), pts.max(0))
            return boxes[isl["id"]]

        def gained(inside_now, rest, other_bone):
            """Depth gained against rest per vertex, bounded by its own travel relative to the other
            island (so a vertex resting on the boundary reports about how far it moved inward)."""
            R, t = Dw[other_bone][:3, :3], Dw[other_bone][:3, 3]
            res = {}
            for v, sd in inside_now.items():
                if sd <= 0:
                    continue
                g = sd - rest.get(v, 0.0)
                if g > GAIN_MIN:
                    res[v] = min(g, float(np.linalg.norm(Vp[v] - (R @ V0[v] + t))))
            return {v: d for v, d in res.items() if d > GAIN_MIN}
        for p, c in self.pairs:
            if np.abs(Dw[p] - Dw[c]).max() < 1e-9:
                continue
            pn = rig.names[p] + "/" + rig.names[c]
            tp, tc = self.bone_tris[p], self.bone_tris[c]
            ov = self.bvh(Vp, tp, T).overlap(self.bvh(Vp, tc, T))
            new = len({(int(tp[i]), int(tc[j])) for i, j in ov} - self.rest_overlap[(p, c)])
            if new > out["clip_tri_pairs"]:
                out["clip_tri_pairs"] = new
                out["clip_tri_pair"] = pn
            for ip in self.ipairs[(p, c)]:
                a, b = ip["a"], ip["b"]
                lo_a, hi_a = boxp(a)
                lo_b, hi_b = boxp(b)
                if (lo_a > hi_b).any() or (lo_b > hi_a).any():
                    continue
                ga = gained(self.inside(Vp, a, treep(b), lo_b, hi_b), ip["rest_a"], b["bone"])
                gb = gained(self.inside(Vp, b, treep(a), lo_a, hi_a), ip["rest_b"], a["bone"])
                n = len(ga) + len(gb)
                if not n:
                    continue
                depth = max(list(ga.values()) + list(gb.values()))
                thr = max(MIN_DEPTH, MIN_FRAC * ip["diag"])
                out["clip_depth_max_mm"] = max(out["clip_depth_max_mm"], round(depth * 1000, 2))
                hit = {"pair": pn, "depth_mm": round(depth * 1000, 2), "verts": n,
                       "frac": round(depth / max(ip["diag"], 1e-9), 4), "thr_mm": round(thr * 1000, 1),
                       "open": ip["open"], "ratio": round(depth / thr, 4)}
                if depth > thr:
                    out["clip_hits"].append(hit)
                if hit["ratio"] > out["clip_ratio"]:
                    out.update({"clip_depth_mm": hit["depth_mm"], "clip_verts": n, "clip_frac": hit["frac"],
                                "clip_thr_mm": hit["thr_mm"], "clip_open": ip["open"], "clip_pair": pn,
                                "clip_ratio": hit["ratio"], "clip_over": depth > thr})
            for ct in self.contacts.get((p, c), []):
                tree = treep(ct["big"])
                best = math.inf
                for v in ct["samples"]:
                    r = tree.find_nearest(tuple(Vp[v]))
                    if r is not None:
                        best = min(best, r[3])
                thr = max(MIN_DEPTH, MIN_FRAC * ct["diag"])
                if best == math.inf:
                    continue
                hit = {"pair": pn, "gap_mm": round(best * 1000, 2), "frac": round(best / max(ct["diag"], 1e-9), 4),
                       "thr_mm": round(thr * 1000, 1), "ratio": round(best / thr, 4)}
                if best > thr:
                    out["gap_hits"].append(hit)
                if hit["ratio"] > out["gap_ratio"]:
                    out.update({"gap_mm": hit["gap_mm"], "gap_frac": hit["frac"], "gap_thr_mm": hit["thr_mm"],
                                "gap_pair": pn, "gap_ratio": hit["ratio"], "gap_over": best > thr})
        return out


def collapse_ratio(m):
    """>1 when the area or edge ratio is under its COLLAPSE limit (bigger is worse)."""
    r = 0.0
    if m["area_min"] is not None:
        r = max(r, AREA_FLAG / max(m["area_min"], 1e-3))
    if m["edge_min"] is not None:
        r = max(r, EDGE_FLAG / max(m["edge_min"], 1e-3))
    if m.get("normal_flipped_visible"):
        r = max(r, 1.0 + min(m["normal_flipped_visible"], 999) / 1000.0)
    return r


def pose_flags(m, kind):
    """m carries clip_over/gap_over for the defect hits and x_clip/x_gap for the excused ones."""
    flags = []
    pre = "" if kind in KINDS_GAME else "STRESS-"
    if collapse_ratio(m) > 1:
        flags.append(pre + "COLLAPSE")
    if m["clip_over"]:
        flags.append(pre + "CLIP")
    if m["gap_over"]:
        flags.append(pre + "GAP")
    if m.get("x_clip"):
        flags.append("DELIBERATE-CLIP")
    if m.get("x_gap"):
        flags.append("DELIBERATE-GAP")
    return flags


def split_hits(m, key, clip):
    """Move the hits DESIGNED_PAIRS (any pose) and the DELIBERATE table (this clip) excuse out of the defect fields."""
    x_clip = [h for h in m["clip_hits"] if excused(key, clip, *h["pair"].split("/"))]
    x_gap = [h for h in m["gap_hits"] if excused(key, clip, *h["pair"].split("/"))]
    d_clip = [h for h in m["clip_hits"] if h not in x_clip]
    d_gap = [h for h in m["gap_hits"] if h not in x_gap]
    out = dict(m)
    out["x_clip"], out["x_gap"] = x_clip, x_gap
    out["clip_over"], out["gap_over"] = bool(d_clip), bool(d_gap)
    out["x_ratio"] = max([h["ratio"] for h in x_clip + x_gap], default=0.0)
    if d_clip:
        h = max(d_clip, key=lambda h: h["ratio"])
        out.update({"clip_depth_mm": h["depth_mm"], "clip_verts": h["verts"], "clip_frac": h["frac"], "clip_thr_mm": h["thr_mm"],
                    "clip_open": h["open"], "clip_pair": h["pair"], "clip_ratio": h["ratio"]})
    else:
        out["clip_ratio"] = m["clip_ratio"] if not m["clip_over"] and not x_clip else 0.0
    if d_gap:
        h = max(d_gap, key=lambda h: h["ratio"])
        out.update({"gap_mm": h["gap_mm"], "gap_frac": h["frac"], "gap_thr_mm": h["thr_mm"], "gap_pair": h["pair"], "gap_ratio": h["ratio"]})
    else:
        out["gap_ratio"] = m["gap_ratio"] if not m["gap_over"] and not x_gap else 0.0
    return out


def severity(m, kind, deliberate):
    """Defect severity (bigger is worse) and the metric that gives it. A COLLAPSE ranks above every
    CLIP or GAP; deliberate clips rank under the rest."""
    sc, cr, gr = collapse_ratio(m), m["clip_ratio"], m["gap_ratio"]
    if sc > 1:
        parts = []
        if m["area_min"] is not None:
            parts.append("AREA %.2f" % m["area_min"])
        if m["edge_min"] is not None and m["edge_min"] < EDGE_FLAG:
            parts.append("EDGE %.2f" % m["edge_min"])
        if m.get("normal_flipped_visible"):
            parts.append("FLIP %d" % m["normal_flipped_visible"])
        return (1000.0 if kind in KINDS_GAME else 500.0) + sc, "COLLAPSE " + " ".join(parts)
    scale = 1.0
    if m.get("x_ratio", 0.0) > max(cr, gr):
        return m["x_ratio"] * 0.001, "DELIBERATE %.1fX" % m["x_ratio"]
    if cr >= gr and cr > 0:
        return cr * scale, "CLIP %.0fMM %.0f%%" % (m["clip_depth_mm"], m["clip_frac"] * 100)
    if gr > 0:
        return gr * scale, "GAP %.0fMM %.0f%%" % (m["gap_mm"], m["gap_frac"] * 100)
    return 0.001 * sc, "OK AREA %s" % ("-" if m["area_min"] is None else "%.2f" % m["area_min"])


def seam_check(rig, clip):
    """Per bone first/last key delta and the first/last 1/30 s step mismatch."""
    f0, f1 = clip.start, clip.end
    dt = STEP * clip.fps
    cache = {}

    def at(f):
        if f not in cache:
            cache[f] = clip.sample(f)
        return cache[f]
    frames = clip.frames()
    first, last = at(f0), at(f1)
    rows = {}
    for bone in first:
        if bone not in rig.index:
            continue
        b = rig.index[bone]
        brot = rig.rest[b][:3, :3]
        l0, q0, s0 = first[bone]
        l1, q1, s1 = last[bone]
        dloc = np.linalg.norm(C @ (brot @ (l1 - l0))) * 1000
        r0, r1 = quat_matrix(q0), quat_matrix(q1)
        drot = rot_angle_deg(r0.T @ r1)
        dscale = float(np.abs(s1 - s0).max())

        def rvec(ra, rb):
            from mathutils import Matrix as Mx
            ax, ang = Mx((ra.T @ rb).tolist()).to_quaternion().to_axis_angle()
            return np.array(ax) * math.degrees(ang)

        def steps(fa, fb):
            a, b2 = at(fa)[bone], at(fb)[bone]
            return (b2[0] - a[0]) * 1000, rvec(quat_matrix(a[1]), quat_matrix(b2[1])), b2[2] - a[2]
        seq = [steps(fa, fb) for fa, fb in zip(frames[:-1], frames[1:])]
        jumps, inside, floors = [], [], (SEAM_FLOOR_LOC_MM, SEAM_FLOOR_ROT_DEG, SEAM_FLOOR_SCALE)
        for k in range(3):
            inside.append(max((float(np.linalg.norm(seq[f][k] - seq[f - 1][k])) for f in range(1, len(seq))), default=0.0))
            jumps.append(float(np.linalg.norm(seq[0][k] - seq[-1][k])) if seq else 0.0)
        vel_fail = [jumps[k] > max(SEAM_HARSHER * inside[k], floors[k]) for k in range(3)]
        fails = []
        if dloc > SEAM_LOC_MM:
            fails.append("loc %.3f mm" % dloc)
        if drot > SEAM_ROT_DEG:
            fails.append("rot %.3f deg" % drot)
        if dscale > SEAM_SCALE:
            fails.append("scale %.4f" % dscale)
        for k, nm in enumerate(("loc", "rot", "scale")):
            if vel_fail[k]:
                fails.append("%s velocity jump %.4f/frame > %.1f x the clip's own %.4f (floor %s)" % (
                    nm, jumps[k], SEAM_HARSHER, inside[k], floors[k]))
        rows[bone] = {"loc_mm": round(dloc, 4), "rot_deg": round(drot, 4), "scale": round(dscale, 5),
                      "vel_jump": [round(j, 5) for j in jumps], "vel_interior_max": [round(p, 5) for p in inside],
                      "vel_limit": [round(max(SEAM_HARSHER * inside[k], floors[k]), 5) for k in range(3)],
                      "seam": bool(fails), "why": fails}
    bad = {b: r for b, r in rows.items() if r["seam"]}
    if not rows:
        return {"clip": clip.name, "seconds": round(clip.seconds, 4), "bones": 0, "seam": None, "failing_bones": [],
                "seam_untested": "NO BONE FCURVES (Blender import); Godot rig_loop_seam_test covers its tracks",
                "bones_detail": {}}
    return {"clip": clip.name, "seconds": round(clip.seconds, 4), "bones": len(rows),
            "seam": bool(bad), "failing_bones": sorted(bad), "bones_detail": rows}


class Stage:
    def __init__(self, rig, size, samples):
        self.rig = rig
        self.size = size
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        cycles_device.use(scene)
        scene.cycles.samples = samples
        scene.cycles.use_denoising = False
        scene.render.resolution_x = size
        scene.render.resolution_y = int(size * 0.75)
        scene.render.resolution_percentage = 100
        scene.view_settings.view_transform = "Standard"
        self.tmp = os.path.join(tempfile.gettempdir(), "rig_pose_audit_%d.png" % os.getpid())
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            nodes = mat.node_tree.nodes
            bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None or bsdf.inputs["Base Color"].is_linked:
                continue
            if rig.meshes and any(len(o.data.color_attributes) for o in rig.meshes):
                attr = nodes.new("ShaderNodeVertexColor")
                attr.layer_name = rig.meshes[0].data.color_attributes[0].name if rig.meshes[0].data.color_attributes else "Color"
                mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        pts = [rig.V0]
        for o in bpy.data.objects:
            if o.type == "MESH" and o not in rig.meshes and o.name not in ("Ground",) and not o.name.endswith("-col"):
                pts.append(np.array([np.array(o.matrix_world @ Vector(c)) for c in o.bound_box]))
        V = np.concatenate(pts)
        lo, hi = V.min(0), V.max(0)
        centre = Vector((lo + hi) / 2)
        radius = max(float(np.linalg.norm(hi - lo)) / 2, 0.1)
        world = bpy.data.worlds.new("Audit")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.52, 0.55, 1)
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
        scene.world = world
        sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        sun.data.energy = 3.5
        sun.rotation_euler = (math.radians(50), 0, math.radians(35))
        scene.collection.objects.link(sun)
        s = radius * 8
        ground = bpy.data.meshes.new("Ground")
        ground.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
        gobj = bpy.data.objects.new("Ground", ground)
        gobj.location.z = float(lo[2])
        gmat = bpy.data.materials.new("GroundMat")
        gmat.use_nodes = True
        gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.42, 0.44, 1)
        ground.materials.append(gmat)
        scene.collection.objects.link(gobj)
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        cam.data.lens = 50
        scene.collection.objects.link(cam)
        scene.camera = cam
        dist = radius * 3.4
        yaw = math.radians(35)
        eye = centre + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, radius * 0.9))
        cam.location = eye
        cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
        self.cam, self.eye, self.centre = cam, eye, centre

    def render(self, values, focus=None, zoom=3.0):
        """focus: world point for a close-up on the same three-quarter bearing at 1/zoom the distance."""
        self.rig.apply_blender(values)
        if focus is not None:
            f = Vector(focus)
            eye = f + (self.eye - self.centre) / zoom
            self.cam.location = eye
            self.cam.rotation_euler = (f - eye).to_track_quat("-Z", "Y").to_euler()
        scene = bpy.context.scene
        scene.render.filepath = self.tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(self.tmp)
        img.colorspace_settings.name = "Non-Color"
        h, w = img.size[1], img.size[0]
        px = np.empty(h * w * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        bpy.data.images.remove(img)
        if focus is not None:
            self.cam.location = self.eye
            self.cam.rotation_euler = (self.centre - self.eye).to_track_quat("-Z", "Y").to_euler()
        return px.reshape(h, w, 4)[::-1, :, :3].copy()


def srgb(a):
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(np.clip(a, 0, 1), 1 / 2.4) - 0.055)


def tile(img, lines, flagged=False):
    """img: (h, w, 3) linear render. Returns tile with a 3 line label band below."""
    h, w, _ = img.shape
    band = 3 * 16 + 4
    out = np.zeros((h + band, w, 3), dtype=np.float32)
    out[:h] = np.clip(img, 0, 1)
    out[h:] = (0.16, 0.05, 0.05) if flagged else (0.08, 0.09, 0.1)
    for i, line in enumerate(lines[:3]):
        draw_text(out, 3, h + 3 + 16 * i, line[: (w - 6) // 12], 2, (1.0, 0.75, 0.7) if flagged and i > 0 else (0.95, 0.95, 0.9))
    return out


def save_png(arr, path):
    h, w, _ = arr.shape
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = arr
    img = bpy.data.images.new("sheet", w, h, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def hstack(tiles, w, h):
    row = np.zeros((h, w * len(tiles), 3), dtype=np.float32)
    for i, t in enumerate(tiles):
        row[:t.shape[0], i * w:i * w + t.shape[1]] = t
    return row


def fmt_spec(spec):
    ax = spec["axis"]
    unit = "DEG" if ax[0] == "r" else ("M" if ax[0] == "t" else "X")
    return "%s %s %+.3g%s" % (spec["bone"], ax, spec["value"], unit)


def audit_rig(key, a, sheet_rows, loop_rows):
    t0 = time.time()
    hspec = HOSTS.get(key)
    frames, tris = host_frames(hspec) if hspec else ({}, None)
    rig = Rig(key)
    audit, deforming = weight_audit(rig)
    names = set(audit["deforming_bones"])
    delib = DELIBERATE.get(key, {})
    if key in PROCEDURAL:
        ranges = table_ranges(key)
        source = "procedural table"
        specs = make_specs(ranges, names)
        for sp in specs:
            tag = "proc:%s:%s%s" % (sp["bone"], sp["axis"], "+" if sp["value"] > 0 else "-")
            if sp["kind"] == "extreme" and tag in delib:
                sp["deliberate"], sp["src"] = True, tag
    else:
        ranges = clip_ranges(rig, set(rig.clips) - set(delib))
        source = "clips (%d actions sampled every 1/30 s; deliberate: %s)" % (len(rig.clips), ", ".join(sorted(delib)) or "none")
        specs = make_specs(ranges, names)
        if delib:
            d_ranges = clip_ranges(rig, set(delib))
            slot = {"r": ("rot", ROT_MOVES, 0.0), "t": ("loc", LOC_MOVES, 0.0), "s": ("scale", SCALE_MOVES, 1.0)}
            for sp in make_specs(d_ranges, names):
                if sp["kind"] != "extreme":
                    continue
                k, tol, rest = slot[sp["axis"][0]]
                lo, hi = ranges.get(sp["bone"], {}).get(k, {}).get(sp["axis"][1], (rest, rest))
                if sp["value"] > hi + tol or sp["value"] < lo - tol:
                    sp["deliberate"] = True
                    specs.append(sp)
    metrics = Metrics(rig)
    clip_poses = []
    for clip in rig.clips.values():
        best, best_f = -1.0, clip.start
        for f in clip.frames():
            tot = 0.0
            for bone, (loc, quat, sc) in clip.sample(f).items():
                tot += math.degrees(2 * math.acos(min(1.0, abs(quat[0]))))
            if tot > best:
                best, best_f = tot, f
        clip_poses.append({"bone": "*", "axis": "clip:" + clip.name, "value": round((best_f - clip.start) / clip.fps, 4),
                           "kind": "clip", "clip": clip.name, "frame": best_f, "rot_sum_deg": round(best, 2),
                           "deliberate": clip.name in delib})
    poses = []
    values_for = {}

    def run(spec, values, basis):
        Dw = rig.chain(basis)
        Vp = rig.skin(Dw)
        m = metrics.evaluate(Vp, Dw)
        rec = {k: spec[k] for k in ("bone", "axis", "value", "kind") if k in spec}
        for k in ("of", "clip", "frame", "rot_sum_deg", "src"):
            if k in spec:
                rec[k] = spec[k]
        rec["deliberate"] = bool(spec.get("deliberate"))
        ctx = spec.get("clip") if spec["kind"] == "clip" else (spec.get("src") if rec["deliberate"] else None)
        m = split_hits(m, key, ctx)
        rec.update(m)
        rec["flags"] = pose_flags(m, spec["kind"])
        rec["severity"], rec["worst_metric"] = severity(m, spec["kind"], rec["deliberate"])
        rec["severity"] = round(rec["severity"], 4)
        poses.append(rec)
        values_for[len(poses) - 1] = values
        return rec, Vp
    check = None
    for spec in clip_poses + specs:
        if spec["kind"] == "clip":
            clip = rig.clips[spec["clip"]]
            raw = clip.sample(spec["frame"])
            values = {b: v for b, v in raw.items() if b in rig.index}
            basis = {rig.index[b]: m for b, m in basis_of_named(rig, values).items()}
        else:
            values, basis = pose_values(rig, spec)
            basis = dict(basis)
        rec, Vp = run(spec, values, basis)
        if check is None:
            check = skin_check(rig, values, Vp)
    if check is None:
        check = {"skipped": "no poses"}
    flags = {}
    for p in poses:
        for f in p["flags"]:
            slot = flags.setdefault(f, {"count": 0, "worst": None, "bones": set()})
            slot["count"] += 1
            slot["bones"].add(p["bone"])
            base = f.replace("STRESS-", "").replace("DELIBERATE-", "")
            if f.startswith("DELIBERATE"):
                score = max([h["ratio"] for h in p["x_" + base.lower()]], default=0.0)
            else:
                score = {"COLLAPSE": collapse_ratio(p), "CLIP": p["clip_ratio"], "GAP": p["gap_ratio"]}[base]
            if slot["worst"] is None or score > slot["worst"][0]:
                slot["worst"] = (score, p)
    for f, slot in flags.items():
        score, p = slot["worst"]
        slot["bones"] = sorted(slot["bones"])
        slot["worst"] = {"pose": fmt_spec(p) if p["bone"] != "*" else p["axis"], "bone": p["bone"], "src": p.get("src"),
                         "area_min": p["area_min"], "edge_min": p["edge_min"],
                         "normal_flipped": p["normal_flipped"], "normal_flipped_visible": p["normal_flipped_visible"],
                         "clip_depth_mm": p["clip_depth_mm"], "clip_verts": p["clip_verts"], "clip_frac": p["clip_frac"],
                         "clip_thr_mm": p["clip_thr_mm"], "clip_open": p["clip_open"], "clip_pair": p["clip_pair"],
                         "clip_tri_pairs": p["clip_tri_pairs"],
                         "gap_mm": p["gap_mm"], "gap_frac": p["gap_frac"], "gap_thr_mm": p["gap_thr_mm"], "gap_pair": p["gap_pair"]}
    if audit["unweighted_vertices"]:
        flags["UNWEIGHTED"] = {"count": audit["unweighted_vertices"], "bones": audit["neutral_bones"],
                               "worst": {"pose": "rest", "bone": ",".join(audit["neutral_bones"]),
                                         "no_group": audit["unweighted_no_group"],
                                         "neutral_bone": audit["unweighted_neutral_bone"]}}
    deliberate_collapse = [{"pose": fmt_spec(p) if p["bone"] != "*" else p["axis"], "bone": p["bone"],
                            "area_min": p["area_min"], "edge_min": p["edge_min"], "flags": p["flags"]}
                           for p in poses if p["deliberate"] and any(f.endswith("COLLAPSE") for f in p["flags"])]
    hostc = host_clip(rig, frames, tris) if hspec else {}
    over = {c: h for c, h in hostc.items() if h["over"]}
    if over:
        c, h = max(over.items(), key=lambda kv: kv[1]["depth_mm"] / kv[1]["thr_mm"])
        slot = flags.setdefault("CLIP", {"count": 0, "bones": [], "worst": None})
        slot["count"] += len(over)
        slot["bones"] = sorted(set(slot["bones"]) | {x["part"] for x in over.values()})
        slot["worst"] = {"pose": "clip:%s t=%.3f" % (c, h["t"]), "bone": h["part"], "src": hspec["host"], "clip_depth_mm": h["depth_mm"],
                         "clip_thr_mm": h["thr_mm"], "clip_pair": "%s/%s" % (h["part"], hspec["host"]), "clip_open": True}
    seams = {}
    for cname in LOOPS.get(key, []):
        if cname not in rig.clips:
            seams[cname] = {"error": "clip not found", "clips": sorted(rig.clips)}
            continue
        seams[cname] = seam_check(rig, rig.clips[cname])
    result = {
        "glb": key + ".glb", "weights": audit, "bone_budget": bone_budget(),
        "bone_budget_note": ("assets/asset_budgets.json has no bone or joint budget; joint count reported"
                             if not bone_budget() else "see bone_budget"),
        "range_source": source, "skin_check": check,
        "ranges": {b: {"rot_deg": {k: [round(x, 3) for x in v] for k, v in r["rot"].items()},
                       "loc_m": {k: [round(x, 4) for x in v] for k, v in r["loc"].items()},
                       "scale": {k: [round(x, 4) for x in v] for k, v in r["scale"].items()}}
                   for b, r in ranges.items()},
        "git_head": GIT_HEAD, "pairs_untested": not metrics.pairs,
        "pair_note": ("no parent/child or touching-at-rest island pairs: CLIP and GAP between its own parts are untested, not clean"
                      + ("; measured against %s instead (host_clip)" % hspec["host"] if hspec else "")
                      if not metrics.pairs else None),
        "host_clip": hostc,
        "sibling_pairs": metrics.sibling_pairs, "sibling_capped": metrics.sibling_capped,
        "pose_count": len(poses), "contact_pairs": len(metrics.pairs),
        "rigid_islands": len(metrics.rigid), "blended_triangles": int(len(metrics.bt) - metrics.cross_bone_tris),
        "cross_bone_triangles": metrics.cross_bone_tris,
        "deliberate": delib, "deliberate_collapse": deliberate_collapse,
        "flags": flags, "seams": seams, "poses": poses,
        "seconds": round(time.time() - t0, 1),
    }
    if not a["no-render"]:
        render_rig(rig, a, key, poses, values_for, seams, sheet_rows, loop_rows, not metrics.pairs, hostc,
                   audit["unweighted_vertices"])
    summary = {
        "joints": audit["joints"], "deforming": audit["deforming_bone_count"], "verts": audit["vertices"],
        "unweighted": audit["unweighted_vertices"], "blended": audit["blended_vertices"],
        "max_influences": audit["max_influences"], "weight_sum_dev": audit["max_weight_sum_deviation"],
        "poses": len(poses), "parent_child_pairs": len(metrics.pairs), "blended_tris": int(len(metrics.bt) - metrics.cross_bone_tris), "cross_bone_tris": metrics.cross_bone_tris,
        "unweighted_neutral_bone": audit["unweighted_neutral_bone"], "skin_err_m": check.get("max_err_m"),
        "flags": {f: {"n": s["count"], "bones": s["bones"][:6], "worst": s["worst"]} for f, s in flags.items()},
        "deliberate_collapse": deliberate_collapse,
        "seam": {c: ("UNTESTED" if s.get("seam_untested") else s.get("failing_bones", s.get("error"))) for c, s in seams.items()},
        "pairs_untested": not metrics.pairs, "testable_pairs": len(metrics.pairs), "sibling_pairs": metrics.sibling_pairs,
        "host_clip": {c: (h["depth_mm"], h["t"], h["part"], h["over"], h["kit_in_body_mm"], h["body_in_kit_mm"]) for c, h in hostc.items()},
        "seam_worst": {c: max(((r["vel_jump"][k] / max(r["vel_limit"][k], 1e-9), b, k) for b, r in s["bones_detail"].items()
                               for k in range(3)), default=None) for c, s in seams.items() if "bones_detail" in s},
    }
    print("RIG_AUDIT %s %s" % (key + ".glb", json.dumps(summary)))
    sys.stdout.flush()
    return result


_NODE_PROP = re.compile(r'^(location|rotation_quaternion|rotation_euler|scale)$')


class NodeClip(Clip):
    """One action of a rigid-node rig: Blender 5 keeps one slot per animated object, so a
    channelbag's slot names the node. Evaluates like Clip, one 'bone' per node."""

    def __init__(self, action, fps):
        self.name = action.name.split("|")[-1]
        self.fps = fps
        self.tracks = {}
        lo, hi = math.inf, -math.inf
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    node = bag.slot.name_display
                    for fc in bag.fcurves:
                        if not _NODE_PROP.match(fc.data_path) or not len(fc.keyframe_points):
                            continue
                        self.tracks.setdefault(node, {}).setdefault(fc.data_path, {})[fc.array_index] = fc
                        lo = min(lo, fc.keyframe_points[0].co[0])
                        hi = max(hi, fc.keyframe_points[-1].co[0])
        self.start = 0.0 if lo == math.inf else lo
        self.end = self.start if hi == -math.inf else hi
        self.seconds = (self.end - self.start) / fps


class NodeRig:
    """What seam_check needs of a rig: clips, a name index and an identity rest per node."""

    def __init__(self, key):
        self.key = key
        reset_scene()
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, key + ".glb"))
        self.fps = bpy.context.scene.render.fps
        self.clips = {}
        for act in bpy.data.actions:
            clip = NodeClip(act, self.fps)
            self.clips[clip.name] = clip
        names = sorted({n for c in self.clips.values() for n in c.tracks})
        self.index = {n: i for i, n in enumerate(names)}
        self.rest = np.array([np.eye(4) for _ in names]) if names else np.zeros((0, 4, 4))


def audit_node_rig(key):
    t0 = time.time()
    rig = NodeRig(key)
    seams = {}
    for cname in LOOPS.get(key, []):
        seams[cname] = {"error": "clip not found", "clips": sorted(rig.clips)} if cname not in rig.clips \
            else seam_check(rig, rig.clips[cname])
    result = {"node_rig": True, "clips": {c: round(k.seconds, 4) for c, k in sorted(rig.clips.items())},
              "nodes": len(rig.index), "flags": {}, "seams": seams,
              "untested": "bone weights, collapse, clip and gap need an armature; this rig is rigid nodes",
              "git_head": GIT_HEAD, "seconds": round(time.time() - t0, 1)}
    summary = {"node_rig": True, "nodes": len(rig.index), "clips": len(rig.clips), "flags": {},
               "seam": {c: ("UNTESTED" if s.get("seam_untested") else s.get("failing_bones", s.get("error")))
                        for c, s in seams.items()}}
    print("RIG_AUDIT %s %s" % (key + ".glb", json.dumps(summary)))
    for c, sm in seams.items():
        print("SEAM_COVERAGE %s %s %s" % (key, c, "UNTESTED" if sm.get("seam_untested") or "error" in sm
                                          else "measured %d nodes, %s" % (sm["bones"], "FAIL" if sm["seam"] else "clean")))
    sys.stdout.flush()
    return result


def strict_failures(key, result):
    """Unexcused COLLAPSE, CLIP, GAP flags and failing seams of one rig; and stale excuses."""
    out = []
    for f, slot in result.get("flags", {}).items():
        if not f.startswith("DELIBERATE") and f.split("-")[-1] in ("COLLAPSE", "CLIP", "GAP"):
            out.append("%s %s x%s" % (key, f, slot.get("count")))
    for cname, seam in result.get("seams", {}).items():
        if seam.get("seam_untested"):
            out.append("%s seam %s UNTESTED: %s" % (key, cname, seam["seam_untested"]))
            continue
        failing = bool(seam.get("failing_bones")) or "error" in seam
        excuse = STRICT_EXCUSED.get((key, cname))
        if failing and not excuse:
            out.append("%s seam %s: %s" % (key, cname, seam.get("failing_bones") or seam.get("error")))
        elif excuse and not failing:
            out.append("%s seam %s is clean but still in STRICT_EXCUSED (%s)" % (key, cname, excuse))
    return out


def basis_of_named(rig, values):
    return {b: mat4(quat_matrix(q), l, s) for b, (l, q, s) in values.items()}


def skin_check(rig, values, Vp):
    """Max distance between this module's skinning and Blender's evaluated meshes."""
    rig.apply_blender(values)
    dg = bpy.context.evaluated_depsgraph_get()
    err = 0.0
    for o, off, n in rig.mesh_slices:
        eo = o.evaluated_get(dg)
        me = eo.to_mesh()
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        mw = np.array(o.matrix_world)
        co = co.reshape(n, 3) @ mw[:3, :3].T + mw[:3, 3]
        err = max(err, float(np.abs(co - Vp[off:off + n]).max())) if n else err
        eo.to_mesh_clear()
    return {"max_err_m": round(err, 6)}


def render_rig(rig, a, key, poses, values_for, seams, sheet_rows, loop_rows, pairs_untested=False, hostc=None,
               unweighted=0):
    stage = Stage(rig, a["size"], a["samples"])
    w, h = a["size"], int(a["size"] * 0.75)
    def pick(kinds, n):
        out, seen = [], set()
        for i in sorted((i for i in range(len(poses)) if poses[i]["kind"] in kinds), key=lambda i: -poses[i]["severity"]):
            p = poses[i]
            ident = (p["bone"], p["axis"], 1 if p["value"] > 0 else -1) if p["bone"] != "*" else (p["axis"],)
            if ident in seen:
                continue
            seen.add(ident)
            out.append(i)
            if len(out) == n:
                break
        return out
    chosen = pick(KINDS_GAME, 5) + pick(("stress",), 3)
    hw = max(hostc.values(), key=lambda h: h["depth_mm"]) if hostc else None
    bad = bool(hw) and any(h["over"] for h in hostc.values())
    note = ("OWN PAIRS UNTESTED" if pairs_untested else "RANKED BY DEFECT SEVERITY") if not hw else \
        "VS BODY %d CLIPS WORST %.0fMM %s" % (len(hostc), hw["depth_mm"], "OVER" if bad else "OK")
    tiles = [tile(stage.render({}), [key.split("/")[-1], "REST POSE" if not unweighted else "UNWEIGHTED %d VERTS" % unweighted,
                                     note], bad or bool(unweighted))]
    for i in chosen:
        p = poses[i]
        label = fmt_spec(p) if p["bone"] != "*" else "%s %.2fS" % (p["axis"], p["value"])
        flagtxt = " ".join(p["flags"]) if p["flags"] else ("OWN PAIRS UNTESTED" if pairs_untested else "NO FLAG")
        collapsed = any(f.endswith("COLLAPSE") for f in p["flags"])
        tiles.append(tile(stage.render(values_for[i]),
                          [label, "%s [%s%s]" % (p["worst_metric"], p["kind"], " DELIB" if p["deliberate"] else ""), flagtxt],
                          bool(p["flags"]) and not all(f.startswith("DELIBERATE") for f in p["flags"])))
        if collapsed and p.get("collapse_focus"):
            tiles.append(tile(stage.render(values_for[i], p["collapse_focus"], 3.0),
                              ["CLOSE-UP 3X " + p["bone"], p["worst_metric"], flagtxt], True))
    sheet_rows.append(hstack(tiles, w, tiles[0].shape[0]))
    for cname, seam in seams.items():
        if "error" in seam:
            continue
        clip = rig.clips[cname]
        mid = (clip.start + clip.end) / 2
        imgs = []
        for f in (clip.start, mid, clip.end):
            vals = {b: v for b, v in clip.sample(f).items() if b in rig.index}
            imgs.append(stage.render(vals))
        over = 0.5 * imgs[0] + 0.5 * imgs[2]
        tag = key.split("/")[-1] + " " + cname
        untested = bool(seam.get("seam_untested"))
        verdict = ("SEAM UNTESTED" if untested else ("SEAM " + ",".join(seam["failing_bones"][:3]) if seam["seam"] else "SEAM OK"))
        note = "NO BONE FCURVES (IMPORT)" if untested else ""
        note2 = "GODOT SEAM TEST COVERS IT" if untested else ""
        row = [tile(imgs[0], [tag, "FIRST FRAME %.1f" % clip.start, note]),
               tile(imgs[1], [tag, "MIDDLE %.1f" % mid, note2]),
               tile(imgs[2], [tag, "LAST FRAME %.1f" % clip.end, ""]),
               tile(over, [tag, "LAST OVER FIRST 50%", verdict], bool(seam["seam"]) or untested)]
        loop_rows.append(hstack(row, w, row[0].shape[0]))


def pad_rows(rows):
    width = max(r.shape[1] for r in rows)
    out = []
    for r in rows:
        if r.shape[1] < width:
            r = np.concatenate([r, np.zeros((r.shape[0], width - r.shape[1], 3), dtype=np.float32)], axis=1)
        out.append(r)
    return np.concatenate(out, axis=0)


def git_head():
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=SKETCH, capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


GIT_HEAD = git_head()


def footer(arr, text):
    band = np.zeros((22, arr.shape[1], 3), dtype=np.float32)
    band[:] = (0.05, 0.05, 0.06)
    draw_text(band, 4, 4, text, 2, (0.8, 0.85, 0.8))
    return np.concatenate([arr, band], axis=0)


def main():
    a = args()
    os.makedirs(a["out"], exist_ok=True)
    keys = [norm_key(a["glb"])] if a["glb"] else WORLDS[a["world"]]
    tag = a["world"] if a["world"] else "glb_" + os.path.basename(keys[0])
    sheet_rows, loop_rows, results = [], [], {}
    for key in keys:
        if not os.path.isfile(os.path.join(MODELS, key + ".glb")):
            raise SystemExit("rig_pose_audit: no such GLB " + key)
        results[key + ".glb"] = audit_node_rig(key) if key in NODE_RIGS else audit_rig(key, a, sheet_rows, loop_rows)
    path = os.path.join(a["out"], "rig_audit_%s.json" % tag)
    with open(path, "w") as f:
        json.dump({"world": tag, "git_head": GIT_HEAD, "thresholds": {
            "collapse_area": AREA_FLAG, "collapse_edge": EDGE_FLAG, "gap_rest_m": GAP_REST, "gap_pose_m": GAP_POSE,
            "seam_loc_mm": SEAM_LOC_MM, "seam_rot_deg": SEAM_ROT_DEG, "seam_scale": SEAM_SCALE,
            "seam_velocity_harsher": SEAM_HARSHER, "seam_floors": [SEAM_FLOOR_LOC_MM, SEAM_FLOOR_ROT_DEG, SEAM_FLOOR_SCALE],
            "clip_gap_min_m": MIN_DEPTH, "clip_gap_min_fraction": MIN_FRAC, "stress": STRESS}, "rigs": results}, f, indent=1, default=str)
    print("JSON", path)
    if sheet_rows:
        reset_scene()
        sp = os.path.join(a["out"], "pose_sheet_%s.png" % tag)
        save_png(footer(pad_rows(sheet_rows), "RIG_POSE_AUDIT %s POSES HEAD %s" % (tag, GIT_HEAD)), sp)
        print("SHEET", sp)
        if loop_rows:
            lp = os.path.join(a["out"], "loops_%s.png" % tag)
            save_png(footer(pad_rows(loop_rows), "RIG_POSE_AUDIT %s LOOPS HEAD %s" % (tag, GIT_HEAD)), lp)
            print("LOOPS", lp)

    if a["strict"]:
        bad = [m for key in keys for m in strict_failures(key, results[key + ".glb"])]
        for m in bad:
            print("STRICT_FAIL", m)
        print("STRICT %s: %d unexcused" % (tag, len(bad)))
        sys.stdout.flush()
        if bad:
            sys.exit(1)


main()
