# Playtest log

Andrew's own play sessions, newest first. Only human play is recorded here. Automated or agent play is never feel evidence. Each entry names the build played, the commit, the verdict in Andrew's words, and the next action it drives.

## Waiting for play

Parked on 22 September 2026 when Andrew took a break (TRACKING EV-0482). Three sketches passed the coordinator's gate (`check:scope` reports `sketch`, a clean tree, and every `sketch:smoke` test passing). None has been played. Each lives on its own branch and worktree and merges to `main` only after Andrew plays it.

| Sketch | Branch and head | Question it answers |
| --- | --- | --- |
| Mobility kit (ball lab plus five augments) | `proto/mobility-kit` at `1d11db6` | Which of grapple (right mouse), air dash (Shift in air), glide (hold Space falling), slam (Ctrl in air) and mag-cling (hold E at a wall) earn their place? Keys 1-5 toggle them. Ground boost and air dash share one 1.1 s cooldown; split them if the dash feels starved. |
| Spillway Drop | `proto/spillway-drop` at `af89c89` | Do stacked shelves, sluice chutes and a slow bypass ramp create route choice? It also has a 90 s basin flood that reveals a secret hatch. |
| Cable Bench | `proto/cable-bench` at `29dcbcf` | Does a 45 s difficulty clock with rising cache prices make looting versus leaving a real choice? It also has kicker-gated benches and cableway hazards. |

Launch any of them with the pinned binary. The mobility kit's README and each stage's README list controls and "what to try first".

```sh
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path /home/andrew/Projects/scrapkeep-worktrees/mobility-kit/sketches/ball-lab
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path /home/andrew/Projects/scrapkeep-worktrees/spillway-drop/sketches/spillway-drop
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path /home/andrew/Projects/scrapkeep-worktrees/cable-bench/sketches/cable-bench
```

If a worktree is gone, recreate it with `git worktree add /home/andrew/Projects/scrapkeep-worktrees/<name> proto/<name>`.

After play: log the verdict here, merge the played branches, graft the kept augments into the chosen stage, then plan the Bible amendment (BIBLE.md:519 still describes compact levels).

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
