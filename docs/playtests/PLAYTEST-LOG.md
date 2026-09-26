# Playtest log

Andrew's own play sessions, newest first. Only human play is recorded here. Automated or agent play is never feel evidence. Each entry names the build played, the commit, the verdict in Andrew's words, and the next action it drives.

## Waiting for play

Parked on 22 September 2026 when Andrew took a break (TRACKING EV-0482). Three sketches passed the coordinator's gate (`check:scope` reports `sketch`, a clean tree, and every `sketch:smoke` test passing). Each lives on its own branch and worktree and merges to `main` only after Andrew plays it. On 26 September 2026 Andrew played the mobility kit (entry 3) and Spillway Drop (entry 4); Cable Bench is in play. The merge waits for all three verdicts.

| Sketch | Branch and head | Question it answers |
| --- | --- | --- |
| Mobility kit (ball lab plus five augments) | `proto/mobility-kit` at `1d11db6` | Which of grapple (right mouse), air dash (Shift in air), glide (hold Space falling), slam (Ctrl in air) and mag-cling (hold E at a wall) earn their place? Keys 1-5 toggle them. Ground boost and air dash share one 1.1 s cooldown; split them if the dash feels starved. |
| Spillway Drop | `proto/spillway-drop` at `af89c89` | Do stacked shelves, sluice chutes and a slow bypass ramp create route choice? It also has a 90 s basin flood that reveals a secret hatch. |
| Cable Bench | `proto/cable-bench` at `29dcbcf` | Does a 45 s difficulty clock with rising cache prices make looting versus leaving a real choice? It also has kicker-gated benches and cableway hazards. |

Launch any of them with the `scrapkeep` launcher, which finds sketches across every
worktree. The mobility kit's README and each stage's README list controls and "what to
try first".

```sh
scrapkeep                 # list what is playable, with branch, head and the question it asks
scrapkeep mobility        # play the mobility kit
scrapkeep spillway        # play Spillway Drop
scrapkeep cable           # play Cable Bench
scrapkeep test            # headless import, boot and tests/*.gd for every sketch in every worktree
```

`npm run play` is the same tool from inside the repo. It reads the pinned binary from
`scripts/sketch-smoke.mjs`; set `GODOT_BIN` to override it and `SCRAPKEEP_ROOT` to point the
wrapper at a different checkout. The long form still works:

```sh
/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path /home/andrew/Projects/scrapkeep-worktrees/mobility-kit/sketches/ball-lab
```

If a worktree is gone, recreate it with `git worktree add /home/andrew/Projects/scrapkeep-worktrees/<name> proto/<name>`.

After play: log the verdict here, append its line to [verdicts.ndjson](verdicts.ndjson) (checked by `node scripts/lab/verdicts.mjs`), merge the played branches, graft the kept augments into the chosen stage, then plan the Bible amendment (BIBLE.md:519 still describes compact levels).

## 4. Spillway Drop, first human play

- **Date.** 26 September 2026, Phoenix time. Dictated, transcribed as spoken.
- **Build.** `sketches/spillway-drop/` on `proto/spillway-drop` at `af89c89`, launched with `scrapkeep spillway`. Unchanged since the EV-0482 gate.
- **Verdict.** "Spillway is great. I love random events or uh, environmental changing events. And I like how they can like ebb and flow or happen in different areas or can be unique to the map. These are like mechanics that are more than just gimmicks." Also: "they're exciting when you have uh, events happening with maybe also a mini boss that's just spawned or uh, is over in a a randomly spawned location uh, when you you know discover something" and "it just makes the world alive you know and chaotic I love I love the chaos and then having the ability for the player to weave in and out of the chaos, whether that's environmental or enemy or weather or special event." And: "I like how the player can use them to their advantage as well. Like, let's say if there's water, then a person can freeze it and, and, and have that mechanic or If there's I don't know lava then you could use water to to to make platforms for yourself if you had a character or the ability or an item to do that".
- **Decided by play.** Environmental events (the basin flood) stay as a core stage mechanic, not a gimmick.
- **Direction named.** Events that ebb and flow, vary by area and are unique to each map, layered with enemy spawns such as a miniboss at a random location and weather or special events. The player weaves through the chaos and turns it to advantage: abilities and items interact with the event's material (freeze water into a surface, cool lava into platforms).
- **Not answered.** The sketch's own question, whether shelves, chutes and the bypass make route choice, and the shelf heights and chute pitch. Bot finding S1 (stomps cost HP) was not commented on.
- **Next action.** Card the event layer: an event director that composes stage events with enemy spawns, and an ability-meets-material interaction on the flood as the first test. Ask the route-choice question at the next Spillway play.

## 3. Mobility kit, first human play

- **Date.** 26 September 2026, Phoenix time. Dictated, transcribed as spoken.
- **Build.** `sketches/ball-lab/` on `proto/mobility-kit` at `1d11db6`, launched with `scrapkeep mobility`. Unchanged since the EV-0482 gate.
- **Verdict.** "the gameplay feels great. I still like the rigidity physics because the kinematics is just really shaky in terms of my screen." Grapple and reel: "the grapple's great. The reel isn't as good in terms of that I It's not intuitive in terms of the way it reels. I think it kicks in the reel after leaving the ground or I guess approaching the grapple hook". Mag-cling: "The mag cling was confusing" and "a cling could be like For to think about it from the perspective of the world, it could be like someone sticking in a pylon into the wall so they can mount themselves. And it could be a form of like mounting your ball onto a surface to like start shooting or doing abilities or getting a breather from being surrounded." Glide, momentum and slam: "The gliding is really fun. The speed and momentum is really fun. The slam is really fun. I would want the slam to um, anchor the character for a second. So to have a little bit more weight to the slam and not have the ability to just slam onto the ground, but then just continue rolling off uh, like normal."
- **Decided by play.** Rigid physics confirmed again; kinematic mode reads as screen shake. Keep grapple, glide and slam. Rework the reel and mag-cling.
- **Requests.**
  - Reel: make it read and respond predictably; today it seems to engage only once the ball leaves the ground or nears the hook.
  - Mag-cling becomes a **pylon mount**: grapple to a surface, drive a pylon in and mount the ball there, as a firing or ability platform and a breather when surrounded.
  - Slam: anchor the ball for a beat on landing, for weight, without stunning the player afterwards.
- **Not answered.** Air dash, and whether boost and air dash sharing one 1.1 s cooldown starves the dash. Class versus item for each augment.
- **Next action.** Sketch the slam anchor and a reel rework on the mobility kit, and prototype the pylon mount as the replacement for mag-cling.

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
