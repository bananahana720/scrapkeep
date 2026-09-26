# Playtest log

Andrew's own play sessions, newest first. Only human play is recorded here. Automated or agent play is never feel evidence. Each entry names the build played, the commit, the verdict in Andrew's words, and the next action it drives.

## Waiting for play

Parked on 22 September 2026 when Andrew took a break (TRACKING EV-0482). Three sketches passed the coordinator's gate (`check:scope` reports `sketch`, a clean tree, and every `sketch:smoke` test passing). Each lives on its own branch and worktree and merges to `main` only after Andrew plays it. On 26 September 2026 Andrew played all three: the mobility kit (entry 3), Spillway Drop (entry 4) and Cable Bench (entry 5). The table below is kept as the record of what was asked; the merges followed (TRACKING EV-0578).

**Played: mobility kit v2** (entry 6) on `proto/mobility-kit-v2` at `f118321`, merged to `main` after play (TRACKING EV-0587). Next up for play: the core-loop prototype, built this round.

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

## 6. Mobility kit v2, first human play, and design principles

- **Date.** 26 September 2026, Phoenix time. Dictated, transcribed as spoken. Claude desktop crashed while the game was paused, which closed Godot with it; the feedback was given afterwards.
- **Build.** `sketches/mobility-kit/` on `proto/mobility-kit-v2` at `f118321`, launched with `scrapkeep mobility-kit-v2` after the launcher fix at `551c578`. The first launch before that fix opened the unchanged ball-lab and is not evidence for v2.
- **Verdict.** "I still really like the rigid physics versus the kinematics. I don't know. It just it feels too squishy. The kinematics one. The rigid one just feels good. It feels like my objects have weight." On the kit: "as notes for the mobility test, it operated great. It was interesting the way the the pylon thing worked. It needed to have the camera maybe kind of like. shift over um or if you can want to consider a snap to a more shoulder view because i couldn't really see anything like if i was supposed to be shooting i don't know if i was shooting or if i was like placing turrets or like yeah electrical uh pylons or something i don't know what the mecha the, the mechanics uh did and i would want some maybe sound feedback". And: "I like the gliding. I like the movement. Yeah. I think the movement is just more, um, arcadey in the rigid, I guess, maybe, and maybe that's what I'm looking for. I like that. Arcadey feel. I wouldn't want it to be too realistic. And yeah, I want it to be fun."
- **Decided by play.** Rigid physics again, now named for its arcade weight. Keep the mobility kit. The pylon needs a shoulder view and a legible purpose; every action needs sound feedback.
- **Direction and principles, same session, in Andrew's words.**
  - Momentum: "I think the whole point of this game is like like Katamari Damacy is just building momentum and rolling and, and growing" and "I wouldn't want to impact that momentum unless it's the player's performance in something like either like making a mistake or you know going going crazy or yeah hitting hitting objects collisions things should have weight things should have um, uh, should things shouldn't inhibit the player in un, unforeseen ways."
  - Restart: "if you were to fail, then you can kind of like uh, have easy access to just restart from uh, a specific either checkpoint or, you know, uh, home screen or selection screen, whatever, or yeah, just restart a run".
  - Layers: "maps could have events that could uh, occur that the player can participate in and win great rewards like key milestone rewards. Uh, on top of like maybe it overlapping with a boss mechanic".
  - Growth: "there has to be some sort of like growth and and trajectory and yeah, the ability to scale insanely like in any other roguelike", with Binding of Isaac and Gunfire Reborn as references.
  - Classes: "a pylon you stick to a pylon and then you act like a placeable turret and use the ter terrain to help you or another one could be just a guy who runs and guns", with items that make the runner "shoot in a cross or shoot in a spiral of bullets", "obviously with balance, you know, visually and not to overwhelm the player."
  - Music: "a just a fun, Uh, intense, like experience with music that uh, is at a high BPM and is like super like I don't know jazzy in terms of uh, like create creative like melodies but maybe more uh, like EDM".
  - Harmonizing: "things that seem like anti-patterns can be actually molded when certain aspects are broken down and and considered and harmonized together. So momentum-based versus like sticking to a wall and being a pylon, those can still be things", with actions "snappy or fluid" in animation, "to make yourself feel like a like a badass."
  - Process: "I would love to have some more gameplay mechanics, systems, and layers applied", "try to bridge and build extra nodes to bridge gaps", and "have a coordinated. agent team where, you know, we can paralyze where we can and have reviewers uh, review where it makes sense."
- **Choices made by AskUserQuestion.** Arc caster weapon with the pylon as an arc turret; three stages then a summary; synthesized SFX plus adaptive music; hand him the playable at the end.
- **Next action.** Build the core-loop prototype under these principles (TRACKING EV-0587); carry the principles into a heavy-lane Bible amendment.

## 5. Cable Bench, first human play

- **Date.** 26 September 2026, Phoenix time. Dictated, transcribed as spoken.
- **Build.** `sketches/cable-bench/` on `proto/cable-bench` at `29dcbcf`, launched with `scrapkeep cable`. Unchanged since the EV-0482 gate.
- **Verdict.** "I think Scrap Cable was the weakest experience just because I don't know what the heck was going on. I, I saw that I was collecting scraps and difficulty was increasing, but I had no buffs and the cable mechanic was just weird and the map just felt awkward to play and I don't know what the heck I was doing really." Also: "I feel like there should be ways to clearly communicate. I guess what I'm supposed to be doing in the game, maybe UI would be beneficial to help and um, a way to pause so I can also like kind of get a bearing of what I'm supposed to be doing." And: "like hold, press to hold, like hold down to press and view, like maybe some notes for myself, but then that will also be, that could also be something for video game play reasons."
- **Decided by play.** Cable Bench is the weakest of the three sketches. Its question (does the tier clock make "one more cache" a decision) went unanswered because the player could not tell what the stage wanted or what caches gave.
- **Requests.**
  - Every sketch says what the player is doing: an objective and what scrap buys, on screen.
  - A pause.
  - A hold-to-view overlay (Tab was suggested; Tab is the physics toggle today) that shows playtest notes now and can grow into the in-game dashboard.
  - Several ways to power up the character, from the Bible's build design.
- **Next action.** Park Cable Bench's layout. Add pause and a hold-to-view objective overlay to the sketches before the next play, and re-ask the tier-clock question only once a stage explains its economy.

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
- **Added after the Cable Bench play, same session.** "the air air dash was, was really fun too. I did really like that. And, um, I would, I, I do like the ability to to move and then uh, redirect my camera." On skill and control: "I would want it to be skill based. This video game, but I would want to have some considerations for quality of life or momentum based, like considerations where it might be hard for the player to like aim appropriately. control appropriately which is why I like the rigid versus the kinematic physics because it was just shaking so much where I felt like I couldn't really aim my grapple hook too well or see if it was in reach to connect to a wall". On the rope: "the grapple cable doesn't have any physical object permanence or properties so I guess it looks awkward when it's cutting through other objects" and a wish for the rope to wrap around what it passes, "moving in one direction, grappling perpendicular to your direction of movement and then kind of like spinning like a uh, like a ride".
- **Also decided.** Keep the air dash. Skill-based control with momentum-aware aim assistance: the player must be able to see whether the grapple is in reach.
- **Also requested.** A grapple reach indicator; a rope that collides and wraps around geometry, so a perpendicular grapple swings the ball around it like a ride.
- **Not answered.** Whether boost and air dash sharing one 1.1 s cooldown starves the dash. Class versus item for each augment.
- **Next action.** Sketch the slam anchor, a winch reel (the current reel only shortens the rope's maximum length, so it does nothing while the rope is slack) and a grapple reach indicator on the mobility kit, and prototype the pylon mount as the replacement for mag-cling. Rope wrapping is a separate, larger sketch.

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
