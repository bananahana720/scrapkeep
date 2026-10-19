# Rigs and motion, world three (World-2, wave 19)

From `tools/blender/rig_pose_audit.py -- --world three` at f39a671d on `claude/happy-mayer-rtqcu5-rigs-w3` (Blender 5.2.2, Cycles CPU).

- `pose_sheet_three.png`, `loops_three.png`, `rig_audit_three.json`: the audit at f39a671d. The four skinned world-three rigs (anchor_crew, kite_drone, warden_mind, mind_hand) read unweighted 0, blended 0 and cross-bone 0, with no non-stress, non-deliberate flag left.
- `mind_lens_neck_final_quiet.png`: the LensMount neck at `final_quiet` from four views, before (left) and after (right) the stray Lens weight was removed.
- `mind_orphan_rebind_before_after.jpg`: Lens turn 30°, takeoff, takeoff palm and perch, before (top of each pair) and after the 224 neutral_bone vertices were bound to their island's bone. Before: white stretched sheets.
- `mind_lens_seat_before_after.jpg`: active, glide, knocked_down and Lens rX +17.2, before and after the iron lens seat was centred. Before: a dark slab through the hull's back.
- `anchor_crew_brace8_before_after.jpg`: CrewBrace rX +8 (the held pose), two angles, before (top) and after the hook housing was bound to the head.
