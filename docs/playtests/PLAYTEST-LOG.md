# Playtest log

Andrew's own play sessions, newest first. Only human play is recorded here. Automated or agent play is never feel evidence. Each entry names the build played, the commit, the verdict in Andrew's words, and the next action it drives.

## 2. Ball lab, first human play

- **Date.** 22 September 2026, Phoenix time. TRACKING [EV-0481](../../TRACKING.md).
- **Build.** `sketches/ball-lab/` at `dc94b2c`, merged to `main` at `090c0a9`. `npm run sketch:smoke` passes.
- **Verdict.** "DUDE this feels so amazing and fun in the movement and traversal. wow im really happy with this - its already so fun to move and explore around. I would want augments or abilities that can class or item or whatever driven to make it even more fun like a grapple hook or maneuverability in the air or other things. well done." Also: "rigid body felt best, and I didn't do any fine tuning, I was already lost in the game having a blast".
- **Decided by play.** Rigid-body mode (Jolt `RigidBody3D` driven by torque) over the hand-rolled kinematic ball.
- **Tuning played, all defaults from `sketches/ball-lab/src/tuning.gd`.** Drive accel 34, cruise 14 m/s, air control 0.25, gravity 26 m/s², jump speed 13 m/s, restitution 0.35, rolling resistance 0.30, rigid torque 220, physics at 90 Hz.
- **Request.** Mobility augments or abilities, driven by class or items: a grapple hook, air maneuverability, and more.
- **Next action.** Greybox Spillway Drop and Cable Bench on the rigid ball. In parallel, add a mobility augment kit to the ball lab.

## 1. Orchard increment 01, first human play

- **Date.** 22 September 2026, Phoenix time. TRACKING [EV-0479](../../TRACKING.md).
- **Build.** `/orchard.html`, lightning caster increment 01, source unchanged since commit `aef51fe` (5 September 2026).
- **Verdict.** "the implementation was off and not very good, wasnt very inspiring. it was a static room like level - looking for more of a exploring, more open world to play a rougelite in"
- **Target named.** Risk of Rain 2 open stages combined with a momentum playground. Open 3D stages to roam, loot, secrets and an exit trigger, on terrain built for rolling, with combat in the world rather than in rooms.
- **Sacred.** Rolling scrap mech, scrap becomes your build, the roguelite run, steam-cyberpunk Southwest art direction.
- **Next action.** A square-one review of design, feel, technology and process, followed by greybox open-stage prototypes that Andrew plays.
