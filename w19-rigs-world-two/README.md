# Rigs and motion, world two (World-2, wave 19)

This is the output of `tools/blender/rig_pose_audit.py -- --world two`, run at 333d309a on `claude/happy-mayer-rtqcu5-rigs-w2` (Blender 5.2.2, Cycles CPU).

- **`pose_sheet_two.png`, `loops_two.png` and `rig_audit_two.json`** are the audit at 333d309a.
  - It covers the three world-two rigs: lamp_swarm, warden_swarm and warden_swarm_kit_drones. No non-stress, non-deliberate flag is left, and blended triangles are 0.
  - warden_swarm has ranges for all 173 bones and 2,471 poses, with stress tiles.
  - The kit is tested against the skinned hive in seven clips, in both directions. Kit inside the hive is 0 mm. Hive inside the kit peaks at 49.9 mm (stagger_open, Drone2): pinprick tips held inside the drone's slab.
- **`drones_side_before_after.jpg`** (kit tinted orange) and **`drones_out_before_after.jpg`** show idle t3.6 Drone7, idle t1.2 Drone0, active t2.73 Drone7 and hoist_ride t0.47 Drone4, at 3x. Top row is c4d5c0b6, bottom row is 333d309a.
  - Before, the drones hover clear of the shoulder.
  - After, all eight lie flat on the lower comb (`swarm.md:40`, `:130-131`).
- **`drones_far_20m.jpg` and `drones_far_60m.jpg`** show idle t1.2 at game distance, with an 85 mm lens.
- **`hive_cross_index_contacts.jpg`** shows the five cross-index pinprick contacts in `DESIGNED_PAIRS`: Seam7/Cell18, Cell14/Seam15, Cell16/Seam17, Cell26/Seam38 and Cell30/Seam42. They are shown at rest, idle −0.05, brood_dark −0.13 and stagger_open +0.07, at 4x. The pinprick dims into the neighbour's lip.
- **`hive_own_cell_shutters.jpg`** shows Cell1's shutter plates at the pulse, active and stagger_open angles. This is the round-1 render; the hive GLB is unchanged since then. It is why `Cell(\d+)/Shutter\1_\d` is a designed pair.
