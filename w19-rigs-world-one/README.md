# Rigs and motion, world one (World-2, wave 19)

From `tools/blender/rig_pose_audit.py -- --world one` at f36ef60f on `claude/happy-mayer-rtqcu5-rigs-w1` (Blender 5.2.2,
Cycles CPU, since EEVEE and Workbench need libEGL, which the headless box lacks).

- `pose_sheet_one.png`: one row per rig. The rest pose comes first, then the five poses with the worst defect, each
  labelled with its bone, axis, value and metric. Every pose uses one three-quarter camera per rig, framed on the
  rest bounds.
- `loops_one.png`: each looped clip's first, middle and last frames, plus the last frame laid over the first at 50%.
- `rig_audit_one.json`: the bone and weight audit, the ranges of motion (taken from the clips and from the procedural
  pose scripts), every pose's metrics (area and edge ratios on blended triangles, penetration depth and gaps between
  parent and child parts), and the loop seams.
