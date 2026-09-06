# Scrapkeep design audit and development push

5 September 2026. A coordinated four-lane audit swarm plus a coordinator playfeel probe, run at Andrew's request to push the game design and architecture. The four working papers are in [docs/audit-2026-09-05/](audit-2026-09-05/): [architecture](audit-2026-09-05/worker-1-architecture.md), [combat](audit-2026-09-05/worker-2-combat.md), [meta-progression](audit-2026-09-05/worker-3-meta.md), and [universe/art](audit-2026-09-05/worker-4-universe.md). This document is the curated synthesis. Everything below labeled proposal is design work awaiting Andrew's judgment. Nothing here changes committed scope.

## Evidence basis

- Architecture lane ran the checks. `node --test tests/*.test.js` passed 73/73 and `npm run check:project` passed this session.
- The coordinator drove the orchard simulation directly through `game.update` at its own 120 Hz step, via the `?qa=1` bridge in a live browser tab. That is fixture evidence by the project's own rule ([play guide](FIRST-BUILD-PLAYGUIDE.md), scope section). It measures handling and rule behavior. It does not measure human feel, which stays a playtest question (BACKLOG P01).
- Design lanes cite `file:line` for every claim about existing material and label their designs proposals. Their full evidence limits are in the working papers.

## Coordinator playfeel probe

The desk's standing question is whether rolling and recovery counters feel good enough to support the class/item layer ([design desk](DESIGN-INDEX.md), production checkpoint). The probe gives a split answer.

**The counter grammar works.** The state cycle measured live matches `ENEMY_CONFIG` exactly (Snipcart approach 0.25 s, windup 1.15 s, active 0.48 s, recovery 1.85 s). Counters landed in the recovery window paid out the 2.1x multiplier and dropped scrap, once per cycle, as documented. The commit-telegraph-counter loop is real, legible in code, and worth building on.

**Rolling is not yet a decision.** Measured at the simulation step, from rest:

| Measure | Value | Source |
| --- | --- | --- |
| Time to ~85% of top speed | 0.25 s | probe; `simulation.js:329` (accel 25) |
| Top roll speed | 7.4 u/s | `simulation.js:323` |
| Speed 0.25 s after releasing input | 1.15 u/s (from 7.4) | probe; the servo targets zero velocity |
| 90 degree velocity realign at speed | 0.30 s (0.14 s braking) | probe |

Movement is a velocity servo. Release the stick and the ball stops in about half a second. No mass term exists anywhere in handling. Growth changes the collision radius only, which makes the player a bigger target and eases ram counters (`simulation.js:611`) but buys nothing else. A hovercraft with this tuning would play identically. The Katamari identity, mass and momentum as the point of rolling, is currently absent from the handling model. That is the single most important gap this audit found, and it is cheap to test (see increment 1).

One readability note from the visual checkpoints. The world-space threat banner ("AHEAD - SHEARS CLOSING") carries most of the warning load. The windup pose itself is subtle at chase-camera distance. Worth one deliberate look in the human playtest.

## The keystone: make mass real

Three lanes converge on the same move.

- The probe shows mass does nothing in handling.
- The combat paper proposes mass as the four-way combat currency (ram damage and deflect armor up, steering and burst cadence down, hitbox already the cost) and resolves the open defensive-rhythm question with the Roll-Through deflect. Crossing a committed stroke at burst speed (19 u/s against a 9.5 threshold) converts the hit to chip damage. No new inputs. Spacing stays the floor answer for every attack. See [worker 2, sections 1 and 2](audit-2026-09-05/worker-2-combat.md).
- The architecture paper's item/modifier pipeline is the seam where mass scaling, deflect grades, and later items all plug in without new if-chains. See [worker 1, move 2](audit-2026-09-05/worker-1-architecture.md).

Together these make rolling, collecting, and bumping the tactical layer, which is the confirmed central appeal (DISCOVERY.md, publisher direction). The combat paper flags the deflect chip economy as its highest-risk number and asks for the Sluiceback basin experiment before other systems build on it. I agree, and increment 1 below is that experiment.

## High-impact areas, ranked

1. **Mass in handling plus Roll-Through deflect.** Small change to `_step` and `_hurt` in `src/orchard/simulation.js`, large identity payoff. Gate everything else on how it feels.
2. **Enemy admission grammar as a registry.** The combat paper's seven-field fill-in table (telegraph, commitment, locked geometry, recovery, weak point, counter reward, contested resource) becomes a data table the code reads. The architecture paper found the same kind-string branching duplicated across three files. One structure fixes both, and every future enemy inherits the discipline.
3. **Expedition skeleton and the Scrapbook.** Three themed stages, five beats each, 30 to 45 minutes. Pick-one-of-two boss rewards log the unpicked option as seen, not taken. The ledger accumulates reasons to run again with no timers and no decay.
4. **The Requisition premise and the biome ladder.** The Furnace Fleet stays the antagonist. Its requisition bolts conscript each region's own working machines, so every enemy family is local occupational equipment and both existing visual families become canon at once. Seven-rung ladder, five-rung first campaign.
5. **Class kits on a registry plus the modifier pipeline.** Four kit skeletons exist on paper with signature skill shots, quick deploys, ult charge rules, and one transformative item each. The architecture moves make them addable without touching the core loop.
6. **Version control.** `.git` is inert (BACKLOG T01). Everything above is about to multiply the amount of work worth protecting. Fix this first or in parallel with increment 1.

## What the lanes recommend, condensed

### Combat (proposals; full spec in worker 2)

- Defensive rhythm resolved: Roll-Through momentum deflect. Deflectable versus heavy versus grab grades on every attack, telegraphed by stroke rendering, never color alone. Timed brace/parry rejected because it costs an input channel and fights the spinning-shell readability problem the combat workshop already flagged.
- Mass trades: ram damage x(0.75 + 0.5m), steering accel 25 - 7m, burst cooldown +0.15m s, deflect chip 30% - 10%m, with m the growth fraction. Shed Vent (brake + burst) ejects scrap to shrink, refund the burst, and bait collector enemies.
- Anticipation chain: prime, deflect, pip, counter at 2.73x (the implemented 2.1 x 1.3 stack), scrap on the exit line, offcut ram-return. Each link is an implemented or confirmed system doing double duty.

### Meta and retention (proposals; full spec in worker 3)

- Unlocks by milestone dual-triggers (skill path or persistence path), never farmed currency. All four classes live before hour 7. No session in the first ten hours ends without a new entry or unlock.
- The Scrapbook, five tabs, written only by observed play. Completion feeds the witnessed-unlock triggers.
- Reuse verdict on the yard retention build: keep `progress-store.js` wholesale, the pure campaign-module pattern, and the daily-seed and friend-challenge mechanisms. Retire the 15-wave structure, XP curve, and the three-hero roster as content per R12.
- Return hooks stay absence-safe. Nothing resets, decays, or expires.

### Universe and art (proposals; full spec in worker 4)

- Premise B, The Requisition, with a one-page canonical fiction drafted for approval. Pilots are keepers, the region's maintenance crews. Machines are workers, not monsters.
- Ladder: Yard Commons, Spillway Works, Iron Orchard, Foundry Crown, Furnace City as the five-rung first campaign, with Windworks and Harvest Roads pre-designed as expansion rungs. Escalation rides machine scale, architecture scale, and consequence scale while the ball keeps fitting the service roads.
- Ball rules: no radial symmetry, cockpit invariant, parts keep provenance liveries, silhouette states the build, a never-absorbed list, honest wear. The ball is the run's diary.
- Pip is canonically a hamster. The study-01 fox becomes the hover-mortar pilot. Five figurine-readiness rules; the accumulated ball, Plowback, and Spreadleg pass today.
- Art pipeline next five steps, ordered by de-risking: ball build-state turnaround, Snipcart Blender blockout, Pip capsule sheet, biome palette keyframes, figurine test blockout.

### Architecture (findings; full detail in worker 1)

Top five moves by leverage: class-kit registry, item/modifier effect pipeline, data-driven enemy descriptor registry, expedition state machine with a serializable build envelope, widened profile schema on the existing race-safe store. The orchard is the cleaner base to grow. The yard contributes `campaign.js` and `progress-store.js`. The yard's turret/auto-fire weapon system is a retirement candidate. Defer the engine decision. The deterministic DOM-free simulation is the portable asset either way, and the mass-handling experiment will tell us more about physics needs than any comparison document.

## Coordinator reconciliation

Two lane outputs overlap and need one reading. The meta lane maps the notebook's five to five beats per stage inside a three-stage expedition. The universe lane maps it to five biomes in the first campaign. These compose rather than conflict. Proposal: the campaign owns five biomes, a standard expedition runs three stages (early, mid, finale) routed through them, and each stage runs the five-beat arc. Different biome triples across runs become a variety mechanism the retention plan can use. This needs Andrew's read before either paper's number hardens.

## Proposed build sequence

Each increment ends in a verification gate before the next starts. All of this awaits Andrew's scope approval; none of it is authorized by this audit.

1. **Feel experiment (small).** Mass in handling, Roll-Through deflect, Shed Vent, in the orchard sim behind the existing fixture tests. Gate: Andrew plays it and the desk question gets a real answer. Restore version control alongside (T01).
2. **Enemy grammar (small-medium).** Enemy descriptor registry consolidating the three-file branching, admission table enforced in data, one new admitted enemy (Sluiceback as the basin experiment the combat paper asks for). Gate: new enemy ships without touching simulation branching, fixtures pass.
3. **Systems spine (medium).** Modifier pipeline, class-kit registry, grapple as the first new class, six to eight items including one transformative per class. Gate: a class and an item each added by registry entry alone.
4. **Expedition and Scrapbook (medium-large).** Stage state machine with the carried-build envelope, widened profile schema, Scrapbook v1 with the seen-not-taken ledger, pick-one-of-two boss rewards. Gate: a full three-stage run persists correctly across restart, absence-safe.

The art track runs in parallel with its own five acceptance-tested steps and never blocks the increments.

## Evidence limits

The probe is synthetic input at the simulation layer in a live page, not a human playthrough, and the browser pane's frozen frame loop means DOM HUD behavior went unobserved this session. No fun, balance, or performance claim follows from any paper here. The market complaints cited by the meta lane come from purposive, non-representative review samples. All numbers in proposals are tuning sketches.
