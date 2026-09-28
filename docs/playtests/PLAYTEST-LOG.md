# Playtest log

Andrew's own play sessions, newest first. Only human play is recorded here. Automated or agent play is never feel evidence. Each entry names the build played, the commit, the verdict in Andrew's words, and the next action it drives.

## Waiting for play

Parked on 22 September 2026 when Andrew took a break (TRACKING EV-0482). Three sketches passed the coordinator's gate (`check:scope` reports `sketch`, a clean tree, and every `sketch:smoke` test passing). Each lives on its own branch and worktree and merges to `main` only after Andrew plays it. On 26 September 2026 Andrew played all three: the mobility kit (entry 3), Spillway Drop (entry 4) and Cable Bench (entry 5). The table below is kept as the record of what was asked; the merges followed (TRACKING EV-0578).

**Played: the core-loop demo** (entry 7) on `proto/core-loop-rc` at `525a46f`, merged to `main` after play (TRACKING EV-0588). Earlier: mobility kit v2 (entry 6, EV-0587). **Played 28 September 2026 (entry 8): not alpha; a loop redesign round follows.** It was the core-loop v2 alpha candidate on `proto/core-loop-v2` at `19fc173`, launched with `scrapkeep core-loop-v2`. It answers entry 7 (readability, iconography, what to press, transitions, mouse on menus, telegraph types, how to get stronger, soul). It adds three pilots, the upgrade trees, Moss's bay and shop, stage 2's Cable Reach gorge, W7's enemies and family Wardens, the music layers, pause and help, and the Codex Style A visual pass. Checks: `sketch:smoke` 171 green at 06be395 plus the keycap fix's UI tests, and rendered stills of three bot runs at 1920x1080 in that worktree's `artifacts/local/alpha-capture/`. Its verdict becomes entry 8.

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

## 8. Core-loop v2 alpha candidate, first human play

- **Date.** 28 September 2026. Dictated in the Claude desktop app after about 10 minutes of play.
- **Build.** `sketches/core-loop/` on `proto/core-loop-v2` at `19fc173`, launched with `scrapkeep core-loop-v2`. The run log (`user://runs.ndjson`) shows two runs.
  - **Runner-gunner (run 1790573499-910844): won the whole demo** with 0 deaths, 0 events won and 0 bonus cores.
    - Wardens broke at about 100, 108 and 117 s of stage time.
    - Exit heft was 1.34, 3.16 and 5.34.
    - Stage 2's gates gave Spiral Wave twice.
    - Brindle reached phase 4 and was routed.
  - **Demolitions caster (run 1790574209-662493):** abandoned in stage 1.
- **Verdict.** "the gameplay isn't very engaging. In terms of that, I could just go to the boss." On the Warden: "the boss mechanics don't make much sense to me in terms of the UI. And in terms of when and where I should be, to attack it". On the map: "the map doesn't really require me to engage with it. So I kind of don't see the point of staying in a map", and "the map itself kind of just funnels me it feels like towards a certain direction". On the look and interface: "The character design is better but still I guess sort of awkward the UI is very sparse and tightly knit". On class select: "I also don't know what I'm selecting the character what's their offering, there should be, I guess, some sort of like character card that succinctly and like visually engages you to want to play that character." On field notes: "the tab key overwhelms me with like a whole essay of text that I can't even parse through." Overall: "the gameplay loop isn't just isn't fun necessarily", "It just seems like um, a half-baked attempt", and "there should be another I guess set of waves or round of work that needs to be done to get this I guess even close to alpha."
- **Corroborating evidence the round already held.** The balance bots showed the same thing before play. The skipper beelines at the Warden and cleared every stage with no deaths, and the completionist broke Warden III only 1.6 to 2.9 times faster (DESIGN-NOTES, Feedback loop notes 7, 12, 13 and 17). Eight tuning passes moved the numbers but not the structure. The vision keeper's alignment pass judged coherence, not fun. The coordinator called the build alpha-ready on tests and stills, which cannot measure engagement.
- **Decided by play.** It is not alpha. The loop's structure fails, not its polish:
  - the Warden is the only must, and nothing in the map is needed to beat it;
  - the Warden's attack windows aren't legible;
  - the map funnels rather than invites;
  - class select doesn't sell a class;
  - the Tab notes are an essay.

  Keep: the v2 readability gains, the three pilots, and the sphere direction ("better").
- **Next action.** A core-loop redesign round, following the natural progression (sketch, storyboard, agents converge, back to Andrew, then build). Its questions:
  - what makes staying in the map necessary and rewarding;
  - how a Warden says when and where to hit it;
  - what a non-funnel stage looks like;
  - a class card that sells a pilot;
  - field notes as a picture, not an essay.

## 7. Core-loop demo, first human play

- **Date.** 27 September 2026. Dictated in the Claude desktop app, transcribed as spoken, over four messages in one session.
- **Build.** `sketches/core-loop/` on `proto/core-loop-rc` at `525a46f`. The run log (`user://runs.ndjson`) shows one run as the Runner-gunner at about 10:27 to 10:32: the stage 1 Warden broke at tick 16367 (about 3 minutes at 90 Hz), with one part (`tread_plating`), heft 1.52 and no events won, then the run was abandoned early in stage 2.
- **Verdict.** What works: "I think the gunning feels great. Um, the running gunner and the, a pylon person can stay the same." On difficulty: "It was good. It was well-tuned, and I loved like like the risk of rain aspect of staying longer and getting things a little bit harder". On self-challenge: "fun to you know challenge myself and and do it where I use as little resources as possible, or I have as little gear as possible. Um, or yeah, if there's a time component to it." What does not: "The UI is visually like overwhelming. There's so much words and I can't really tell what to press. I mean, I could figure it out and, and sit, uh, stop and look, but um, I think that defeats the whole purpose of the game." On telegraphs: "I have no idea the if it's an AOE, if it's a wave-based AOE that will be like that has you know velocity that I would have to time, or if it's more of a projectile". On growth: "I wasn't really sure how I could get more powerful in the game either. And yeah, what am I like searching for?"
- **Asked for, in his words.**
  - Clarity: "there has to be like clear visual indicators on like what to press and um, like maybe just more iconography, some symbolism", "trace outlines to show uh, objects and where they're intended to like hit more clearly", "not overwhelm the player with information by timing it when it needs to be communicated", "some transitions", and "allow me to use mouse input as well to like navigate the menus".
  - Look: "custom assets that uh, have visual coherence with the theme and the, and the, the plot of the, of the game and the essence of the game", "more soul and character", and "a side path to like start with start building out and and and defining the the the looks and the visual".
  - Mechanics: "more of a bowling ball type of aspect to the gameplay. So it can still be like a run and gun shooter, but it should be like also like smash and smash and grab and smash and uh, like rebound off of enemies"; "you can like jump to a wall and then use like doubling the momentum, you can jump right off of it basically, kind of like pole vault yourself off of it"; "similar to League of Legends skill shots. So like there could be an indicator where you can hold the key, hold, press and and hold to like gauge and then release".
  - Characters: "let's just do three characters", with "the pylon guy can also be a guy that can like, like like to boom and bounce around but also like take point and turret things and another person's the running gun and then another one could be more of a casting like explosive or electric", "skill shot oriented and and more of a hiding and and and uh fast type of damage dealer". Movement split: "a person, an individual can have a grapple that has like you know clear visual indication and sound", "one could have a gliding ability and then maybe another person can have a like blink ability or sort of like speed up ability like an unstoppable ability", "everyone could have the ground smash that can have maybe its own flavor for the character".
  - Cooldowns and loot: "fast cooldown but cooldowns where still you have to time your stuff", items to "store charges in their certain skills and start like stockpiling if it's off cooldown", "more geared towards like maybe procedurally generated loot", with "that aspect of binding of Isaac, risk of rain, gunfire reborn".
  - Robustness: "making sure we do things in a standardized manner so we wouldn't have any unforeseen bugs or hidden glitches or exploits", "But also exploits can be fun too if they're accidental in a fun way."
  - Maps: "more exploratory and less square in terms of map layout", "there could be underground areas and aerial type of things to interact with or whatever like floating something if it's like a floating hovercraft".
  - Process: "keep like working on like the, the engine and and the performance of the game. as well as like the mechanics", and a research swarm, "the haiku can be for web research or whatever and sonnet can be for just idea generation".
- **Choices made by AskUserQuestion.** The caster is explosive demolitions (electric stays the engineer's). Hold-gauge-release skill shots apply to the caster and to the specials and launches of the other two. The look track starts with a style sheet, then icons, then hero assets.
- **Decided by play.** Keep the gunning, both existing classes and the difficulty tuning. The interface, telegraph types and growth legibility must change before more content.
- **Next action.** Core-loop v2 (TRACKING EV-0588): research and ideation, then readability, three characters and a visual language, then loot, assets, audio, a vertical stage and performance. The approved plan is retained at `/home/andrew/.claude/plans/synchronous-weaving-crystal.md`.

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
