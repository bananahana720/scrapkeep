# Ambition brief: waves 17 to 21

Owner: the local coordinator. Written 2026-10-19 from Andrew's requests in the coordination session, reframed through [the ambition article](../handoff/shared/ways-of-working/rieseberg-ambition-article.md) (Altitude, Depth, Range, Speed) and building on [the ambition map](../handoff/shared/alpha-status/ambition-map.md). Every lane reads this with [LANE-BRIEF.md](LANE-BRIEF.md) and [GRAPH.md](GRAPH.md). Rulings stay in [DECISIONS.md](../handoff/DECISIONS.md); where this page and a ruling differ, the ruling wins.

## What Andrew asked for, in his words (19 Oct)

- Hardware is never the bottleneck. Sessions are their own coordinators and divide and conquer; the coordinator keeps the graph, the test dependencies and the waves in sync.
- One full playtest, at the end of wave 21, of the full alpha.
- Parks that are lived in or run down, with far more variety, a natural look, and critters or people. Detail up to about 20,000 triangles.
- Hard but fair, Souls-like. Bosses you learn and beat with your kit. A cracked build earns its steamroll, but skill still counts. Parks, mobs and events go up a notch, and the rest goes into a replay ladder.
- Mine the comps study (Isaac, Roboquest, Gunfire Reborn, RoR2) for tuning.
- Spend usage up front, keeping quality, depth and professionalism.

## Altitude: the outcome above the tasks

**By wave 21, Andrew sits down once and plays an alpha that feels like a finished game.** It is a hard-but-fair roguelite set in lived-in Soft toy parks. Mastering the kit is the path, and a cracked build is the reward. It launches from its own AppImage, holds 60 fps on his 4080, and has a replay ladder that keeps him coming back.

Beyond the alpha: a build he would hand to a friend without explaining anything first.

Every unit answers one question in its PR: **which of the 11 sitting areas does this move, and how would Andrew notice?**

## Depth: hard targets, real instruments, outside checks

A target only counts with a tool that measures it and a reviewer who did not build it. Targets already recorded in the ambition map and DECISIONS.md still hold. New ones:

| Facet | Hard target | Instrument | Outside check |
| --- | --- | --- | --- |
| Difficulty | The skill-band targets in DECISIONS.md section 5 (Novice, Learner, Expert; 0.6 s lethal tells; no Learner death in a boss's first 45 s) | Skill-band bots plus a band-table harness that runs every boss, Warden and park | The table before and after on every PR; a "Souls veteran" red-team pass |
| Encounter craft | Every boss attack has a frame-data row: tell, active, recovery, punish window, damage as a share of hull | Attack sheets generated from the code, not written by hand | The Study lane's comps numbers as reference ranges |
| Lived-in parks | No 10 s stretch of any ride line shows fewer than 3 distinct prop kinds from the player camera; 12 or more kinds per park, each with 2 or 3 variants | An in-view prop audit along ride lines (Dressing lane) | Contact sheets judged by a reviewer that did not place them |
| Ambient life | Every world has critters and locals that flee combat, use no enemy palette band and are capped per park | A palette-band check, pool-cap and flee tests | A "first look" red-team pass: is anything mistaken for a target? |
| Models | Hero assets up to about 20k triangles at LOD0 with LOD1 and LOD2; clean topology; consistent texel density; baked AO | A mesh audit in Blender headless: triangles, non-manifold edges, flipped normals, UV overlap, texel density, LOD ratios | The 4080 A/B per park, and stills compared side by side |
| Rigs and motion | Deforming characters pass extreme-pose tests with no candy-wrapper twists or volume loss; every loop is seamless; attacks show anticipation and follow-through | Pose-test renders at range-of-motion extremes; a loop seam check; a bone and weight audit | A pose contact sheet judged by a reviewer that did not rig it |
| Performance | Unchanged: p99 at most 16.7 ms and no frame over 33 ms on the 4080 at 1080p | GPU bench A/B (queue rows), PERF-NIGHT | GPU VERDICT on each PR |

## Range: the crew, by verb

Write the work as verbs, then ask what the professionals behind each verb actually do. **Each unit does the practice; nobody plays a role.** A lane brief names the practices its units use, and its reviewer checks that they were used.

| Verb | Practice (what professionals do) | Lane |
| --- | --- | --- |
| Make a fight learnable | Encounter designers write frame-data sheets for every attack, give every phase one new idea, leave a punish window after every big commit, and design tells for sight and sound together. Fights are tuned against measured win rates per skill level, not feel alone. | Challenge |
| Make a ladder worth climbing | Difficulty designers give each ladder step one named rule (Eclipse- and Ascension-style), check that no step only inflates numbers, and confirm every step can still be cleared at Expert. | Challenge |
| Make a place feel inhabited | Environment artists write a short story for each place (who lived here, what happened, what was left behind), then build vignettes along sightlines from the player camera. They cluster props, use the rule of thirds, and leave negative space where the action needs it. | Dressing |
| Make life read as harmless | Creature and AI designers give ambient life a separate shape and colour language, flee radii, a pool cap and combat behaviour, and test that nothing ambient can be mistaken for a target. | Life |
| Model a soft toy that holds up at 20k | Hard-surface and organic modellers and technical artists keep clean edge flow, size bevels to the object, cut LOD chains by screen size, and keep texel density, UV packing and AO bakes consistent, all checked by a mesh audit rather than by eye. | World, Dressing, Life |
| Make it move with weight | Riggers and animators weight-paint, run range-of-motion tests at extreme poses, and add corrective shapes where joints collapse. They key with anticipation, overlap and follow-through, keep loops seamless, and set bone budgets per class. | World, Life (pilots and enemies through their owning lanes) |
| Keep it at 60 | Performance engineers profile before changing anything, budget draw calls, triangles and shadow casters per scene, use MultiMesh and visibility ranges, and A/B on the target hardware. | Perf, GPU bench |
| Make every hit land | Sound designers drive sight and sound from one record, keep loudness to target, layer hits by weight, and keep the mix readable in the densest fight. | Music, owning lanes |
| Teach without telling | UX designers check that every required mechanic appears on screen before the first time it is required; first-time clarity is audited, not assumed. | Systems |
| Prove it doesn't break | QA and red teams run seeded sweeps, group crashes by signature, and run adversarial personas. | Gate |
| Ship it | Release engineers build one command that runs every alpha gate and prints one go/no-go page, and test a cold launch on a clean profile. | Gate (wave 21) |

### Red team personas (adversarial, every wave close)

Each persona is a set of checks a red-team bot or reviewer runs, not a character.

- **The Souls veteran:** looks for unavoidable damage, tells shorter than 0.6 s, missing punish windows, and fights a cracked build wins without a single read.
- **The cheese hunter:** looks for exploits: safe spots, AI that breaks against walls, ranged camping that trivialises a boss.
- **The impatient player:** looks for dead time, unclear goals and waits over 20 s between stages.
- **The art director:** looks for things that belong to another game: off-palette props, inconsistent bevels, mismatched texel density, ambient life that reads as an enemy.
- **The performance hawk:** measures frame cost in the densest scene of every park on the 4080.

## Speed

Unchanged from the article notes: one cloud lane per independent track, sub-units fanned out inside each lane, every long sweep split by seed, only GPU work waiting for the PC. Speed never skips proof. Every unit still ships with its instrument's receipt and an independent reviewer's verdict.

## How lanes use this

1. Before each unit, name the verb it serves and the practice it uses. Put both in the PR body.
2. Pick the instrument and the outside check from the Depth table. If none exists, building it is the first unit.
3. Fold this into work already in flight at the next natural break. Do not restart a running unit.
