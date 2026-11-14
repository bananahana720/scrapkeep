# Ambition brief: waves 17 to 21

> **History.** This is the waves 17 to 21 brief of the local coordinator. Live state is in [STATE.md](../handoff/STATE.md); coordination is ruled by dh in [DECISIONS.md](../handoff/DECISIONS.md).

Owner: the local coordinator. Written 2026-10-19 from Andrew's requests in the coordination session, reframed through [the ambition article](../handoff/shared/ways-of-working/rieseberg-ambition-article.md) (Altitude, Depth, Range, Speed) and building on [the ambition map](../handoff/shared/alpha-status/ambition-map.md). Every lane reads this with [LANE-BRIEF.md](LANE-BRIEF.md) and [GRAPH.md](GRAPH.md). Rulings stay in [DECISIONS.md](../handoff/DECISIONS.md); where this page and a ruling differ, the ruling wins.

## What Andrew asked for, in his words (19 Oct)

- Hardware is never the bottleneck. CPU-only work runs in the cloud by default (22 Oct), and the PC keeps 4080 timing, 3060 renders and local-state checks. Sessions are their own coordinators and divide and conquer; the coordinator keeps the graph, the test dependencies and the waves in sync.
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

A target only counts with a tool that measures it and a reviewer who did not build it. Targets already recorded in the ambition map and DECISIONS.md still hold, with two readings fixed by the 19 Oct ruling:
- The ambition map's bot win rates ("every pilot beats each boss in at least 3 of 4 seeds") are measured at the **Expert** band with an ordinary build. Where the 19 Oct ruling sets a higher bar (Expert wins 85% or more against bosses and Wardens), the higher bar wins.
- Warden stagger timing follows DECISIONS.md section 5 per Warden: 45-70 s in general, 60-85 s for the hive Warden.

Difficulty levers are fixed by DECISIONS.md section 5. Allowed: boss damage, attack patterns, combos, punish windows, extra phases, mob aggression and elite affixes. Frozen: stagger timing, attacker caps, the 0.2 s warning gap and the growth ratios. **Difficulty never raises enemy health** (Older rulings, DECISIONS.md), and that applies to every ladder step too.

New targets:

| Facet | Hard target | Instrument | Outside check |
| --- | --- | --- | --- |
| Difficulty | The skill-band targets in DECISIONS.md section 5 (Novice, Learner, Expert; 0.6 s lethal tells; no Learner death in a boss's first 45 s) | Skill-band bots plus a band-table harness that runs every boss, Warden and park | The table before and after on every PR; a "Souls veteran" red-team pass |
| Replay ladder | Each step adds one named rule and no enemy health; at the top step, Expert with an ordinary build wins about 50% | Band-table harness run per ladder step | The table on the ladder PR, reviewed by a reviewer that did not tune it |
| Encounter craft | Every boss attack has a frame-data row: tell, active, recovery, punish window, damage as a share of hull | Attack sheets generated from the code, not written by hand. The generator writes its own report; attack ids and ATTACK_ROWS stay with the Gate lane's fold | A reviewer that did not write the sheets, using the Study lane's comps numbers as reference ranges |
| Lived-in parks | Along every ride line, every 150 m of track has at least 3 distinct prop kinds visible within 60 m of the player camera. Exempt: boss and Warden arenas, telegraph zones, and spaces a ruling keeps open (for example the flume butte gap). 12 or more kinds per park, each with 2 or 3 variants | An in-view prop audit along ride lines, by distance with a visibility range (Dressing lane) | Contact sheets judged by a reviewer that did not place them |
| Ambient life | Every world has critters and locals that flee combat, use no enemy palette band, and are capped at 24 active per park (the Life lane may set a lower cap) | A palette-band check, pool-cap and flee tests | A "first look" reviewer pass: is anything mistaken for an enemy, a pickup or a target? |
| Models | Hero assets up to about 20k triangles at LOD0, with LOD1 at about 50% and LOD2 at about 15%; small props 300 to 3,000; no non-manifold edges or flipped normals; texel density within 2x of its class where textures are used; AO baked where the pipeline uses it | A mesh audit in Blender headless: triangles, non-manifold edges, flipped normals, UV overlap, texel density, LOD ratios | The 4080 A/B per park, and stills compared side by side |
| Scene budget | Each park PR states its triangles in view, draw calls and shadow casters before and after, and adds no shadow casters on scatter; the 3060-class lower preset still holds its target | Counts from the in-view audit, and the existing presets | The 4080 A/B; a red goes back to the owning lane |
| Rigs and motion | New or reworked deforming rigs pass extreme-pose tests with no visible candy-wrapper twist or collapse; every loop is seamless; attacks show anticipation and follow-through (judged by eye). Ruled exemptions stand: Tarn and Cannon skip the pose-test rework of their first-pass animations, and the antics ruled on 17 Oct still ship | Pose-test renders at range-of-motion extremes; a loop seam check; a bone and weight audit | A pose contact sheet judged by a reviewer that did not rig it |
| Performance | Unchanged: p99 at most 16.7 ms and no frame over 33 ms on the 4080 at 1080p. Headroom is thin (dense fights leave 5-6 ms; the stage 6 Mind fight is over budget), so Perf fixes keep priority | GPU bench A/B (queue rows), PERF-NIGHT | GPU VERDICT on each PR |

## Range: the crew, by verb

Write the work as verbs, then ask what the professionals behind each verb actually do. **Each unit does the practice; nobody plays a role.** A lane brief names the practices its units use, and its reviewer checks that they were used.

| Verb | Practice (what professionals do) | Lane |
| --- | --- | --- |
| Make a fight learnable | Encounter designers write frame-data sheets for every attack, give every phase one new idea, leave a punish window after every big commit, and design tells for sight and sound together. Fights are tuned against measured win rates per skill level, not feel alone. | Challenge |
| Make a ladder worth climbing | Difficulty designers give each ladder step one named rule (Eclipse- and Ascension-style), check that no step only inflates numbers, and confirm every step can still be cleared at Expert. | Challenge |
| Make a place feel inhabited | Environment artists write a short story for each place (who lived here, what happened, what was left behind), then build vignettes along sightlines from the player camera. They cluster props, use the rule of thirds, and leave negative space where the action needs it. | Dressing |
| Make life read as harmless | Creature and AI designers give ambient life a separate shape and colour language, flee radii, a pool cap and combat behaviour, and test that nothing ambient can be mistaken for a target. | Life |
| Model a soft toy that holds up at 20k | Hard-surface and organic modellers and technical artists keep clean edge flow, size bevels to the object, cut LOD chains by screen size, and keep texel density, UV packing and AO bakes consistent, all checked by a mesh audit rather than by eye. | World, Dressing, Life |
| Make it move with weight | Riggers and animators weight-paint, run range-of-motion tests at extreme poses, and add corrective shapes where joints collapse. They key with anticipation, overlap and follow-through, keep loops seamless, and set bone budgets per class. | World (enemies, Wardens, pilots), Life (critters and locals) |
| Keep it at 60 | Performance engineers profile before changing anything, budget draw calls, triangles and shadow casters per scene, use MultiMesh and visibility ranges, and A/B on the target hardware. | Perf, GPU bench |
| Make every hit land | Sound designers drive sight and sound from one record, keep loudness to target, layer hits by weight, and keep the mix readable in the densest fight. | Music, owning lanes |
| Teach without telling | UX designers check that every required mechanic appears on screen before the first time it is required; first-time clarity is audited, not assumed. | Systems |
| Prove it doesn't break | QA and red teams run seeded sweeps, group crashes by signature, and run adversarial personas. | Gate |
| Ship it | Release engineers build one command that runs every alpha gate and prints one go/no-go page, and test a cold launch on a clean profile. | Systems (AppImage and cold launch), Gate (the one-command RC gate) |

### Reviewer checklists (in addition to the red-team tool)

The red-team tool keeps its own bot personas (`scripts/redteam`, run by the Gate lane at every stage head and wave close). These checklists are separate: a reviewer that did not build the work runs them. They are not `--persona` ids. The Gate lane may propose new tool personas on the Wave board.

- **Souls veteran** (Challenge's reviewer): unavoidable damage, lethal tells under 0.6 s, missing punish windows. A cracked build winning without a read is reported for information only; a fix must never weaken the build (Overpowered pays).
- **Cheese hunter** (Challenge's reviewer): safe spots, AI that breaks on walls, ranged camping that trivialises a boss.
- **Impatient player** (Gate's wave-close review): dead time, unclear goals, waits over 20 s between stages.
- **Art director** (World's and Dressing's reviewers): off-palette props, mismatched bevels or texel density, ambient life that reads as an enemy or a pickup.
- **Performance hawk** (GPU bench queue): frame cost in each park's densest scene on the 4080.

## Speed

Unchanged from the article notes: one cloud lane per independent track, sub-units fanned out inside each lane, every long sweep split by seed, only GPU work waiting for the PC. Speed never skips proof. Every unit still ships with its instrument's receipt and an independent reviewer's verdict.

## How lanes use this

1. Before each unit, name the verb it serves and the practice it uses. Put both in the PR body.
2. Pick the instrument and the outside check from the Depth table. If none exists, building it is the first unit.
3. Fold this into work already in flight at the next natural break. Do not restart a running unit.
