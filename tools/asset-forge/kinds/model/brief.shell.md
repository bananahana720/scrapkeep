## Shell (pilot mecha ball) rules

This asset is a hero shell: the rolling glass ball a pilot rides in. The game loads it by node
name, so these rules are hard, and they replace the prop rules on facing and grounding.

- **Facing and pivot.** +Y is forward (the game turns `Pod` to face the heading), +Z is up.
  The root origin is the centre of the ball, not the floor. Nothing touches z = 0 on purpose.
- **Size.** Every vertex stays within 0.985 m of the origin. The ball is the `Core` sphere of
  radius 0.98 and everything else fits inside it.
- **Required nodes**, exact names, all under one root empty:
  - `Core`: the glass sphere, `glass` slot, radius 0.98, at the origin. It rolls with the ball.
  - `Pod`: the cockpit body inside the sphere, built from `paint`, `rubber`, `class_accent` and
    `ancient_enamel`. It yaws to face the heading and stays upright.
  - `Dome`: an identity-transform empty parented to `Pod` (the pilot seat reference).
  - Optional nodes the game drives if present: `Gyro` (a ring under `Pod`, spun from speed),
    `VaneL` / `VaneR` (under `Pod`, tilted when gliding). Do not make a `Pilot` node; the
    animated pilot is a separate file seated at runtime.
- **Sockets.** Hardpoints are empties under `Pod` made with `common.empty(name, loc, pod)`,
  rotated so their +Y points along the action (a muzzle points out). Use names like
  `LaneMuzzle`, `Grip.R`, `Grip.L` when the prompt asks for them.
- **Slots.** Keep to five or fewer: `paint`, `ancient_enamel`, `rubber`, `class_accent`, `glass`.
  `class_accent` is recoloured per pilot at runtime, so use it where the class colour belongs.
- **Budget.** The shell class allows the triangles, vertices and draw calls in `params.json`
  (`band`, `max_vertices`, `max_draw_calls`). Each material is one draw call.
- **Not here.** Pilots (rigged, 25 bones, seven clips) are not made by this kind.

Build order that works: `Core` sphere, then the `Pod` silhouette, then `Gyro` and sockets, then
detail. Check the preview from above and from the side: the `Pod` must read through the glass.
