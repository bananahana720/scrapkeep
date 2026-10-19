# Rigs and motion, world one (World-2, wave 19)

From `tools/blender/rig_pose_audit.py -- --world one` at 533f1c27 on `claude/happy-mayer-rtqcu5-rigs-w1` (Blender 5.2.2,
Cycles CPU, since EEVEE and Workbench need libEGL, which the headless box lacks).

- `pose_sheet_one.png`: one row per rig. The rest pose comes first, then the five poses with the worst defect, each
  labelled with its bone, axis, value and metric. Every pose uses one three-quarter camera per rig, framed on the
  rest bounds.
- `loops_one.png`: each looped clip's first, middle and last frames, plus the last frame laid over the first at 50%.
- `rig_audit_one.json`: the bone and weight audit, the ranges of motion (taken from the clips and from the procedural
  pose scripts), every pose's metrics (area and edge ratios on blended triangles, penetration depth and gaps between
  parent and child parts and between sibling islands that touch at rest), and the loop seams. A rig with no touching
  pair reads PAIRS UNTESTED. Poses in the audit's DELIBERATE table (keyed by clip and part pair, with builder cites) are
  marked DELIB and rank below every real defect. warden_reactor's idle animates mesh nodes, not skin bones, so the
  Blender import has no bone fcurves for it; `tests/rig_loop_seam_test.gd` covers its seam in Godot.
- `brute_shoulder.png`: the Plated Brute shoulder blend at rest, at the pad plant (SlamPad tY -0.47) and at BruteRear rX -30, 3x from three angles, opaque and with a ghost body (inverted strip triangles in magenta, all enclosed by the torso).
