---
name: stills-camera-terrain3d
description: "Scratch stills tools must hand every free Camera3D to Terrain3D, or far terrain rings draw as fake \"raw bands\""
metadata:
  node_type: memory
  type: feedback
  originSessionId: 2826d805-0150-4140-b0eb-e70cf1ff765f
  modified: 2026-11-14T12:10:17.957Z
---

In any scratch stills tool, right after making a free still camera current, call
`for t in root.find_children("*", "Terrain3D", true, false): t.set_camera(cam)`.
`tools/clip_dump.gd` in the repo already does this.

**Why:** Terrain3D keeps its detail rings around the camera it was given (the play camera). A free still camera
elsewhere sees the coarse far rings, which looked like a dark "raw band" on PR 957's bowl wall in jobs BB and BB2
(14 Nov 2026); the coordinator traced it, so that finding was the tool's, not the map's.

**How to apply:** every overview, side, close-up or distance camera in a scratch capture tool (w41_stills.gd,
bf_stills.gd, lobber_look.gd and their successors). Before reporting a terrain artefact from a free camera,
check the tool does this. Related: [[pc-gpu-rules]].
