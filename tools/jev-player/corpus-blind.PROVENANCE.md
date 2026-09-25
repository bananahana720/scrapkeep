# corpus-blind.json provenance

This is card JL-04. The corpus went through three attempts, each on its own lease:

| Attempt | Lease | What it did |
| --- | --- | --- |
| JL-04-A1 | JL-04-L1 | wrote the corpus |
| JL-04-A2 | JL-04-L2 | revised the option wording and notes after review |
| JL-04-A3 | JL-04-L3 | removed the remaining text-only cues after re-review |

The same labeller did all three attempts on 2026-09-25 with the same inputs. Every case therefore keeps `labeller: "scrapkeep-writer JL-04-A1"` and `prompt_epoch: "none-seen"`. The work is on branch `wt/JL-04`, base `581f5f8d34c960e5feebbb913490e9165541263a`.

The labeller saw no player prompt, no authored corpus, no scorer and no Jev output. Every label comes from the game's own design documents listed below.

## Inputs read

These are the only files opened, and every case's `inputs_seen` lists this same set.

| Input | Read at |
| --- | --- |
| `artifacts/local/tasks/JL-04/schema.md` (field names, types and option ids only) | supplied by the coordinator, in the JL-04 worktree |
| `sketches/cable-bench/README.md` and `sketches/cable-bench/src/tuning.gd` | `proto/cable-bench` at `29dcbcf`, from its worktree `/home/andrew/Projects/scrapkeep-worktrees/cable-bench` (both files clean) |
| `sketches/spillway-drop/README.md` and `sketches/spillway-drop/src/tuning.gd` | `proto/spillway-drop` at `af89c89`, from its worktree `/home/andrew/Projects/scrapkeep-worktrees/spillway-drop` (both files clean) |
| `sketches/ball-lab/README.md` and `sketches/ball-lab/src/tuning.gd` | base `581f5f8` |
| `BIBLE.md` | base `581f5f8` |
| `BACKLOG.md`, section `### JL-04` only (lines 5326-5348) | base `581f5f8`; disclosed input |

Two things about the `BACKLOG.md` input:
- I found the JL-04 line with a `grep` that printed only headings, and its output showed just the JL-04 heading.
- The JL-04 section supplies the card's rules: at least 20 cases, at least 4 dominance cases, the forbidden inputs and the burn rule. It contains no labels and no game rules.

The three `tuning.gd` files hold the same movement values: cruise 14, jump 13, gravity 26, air control 0.25, and boost impulse 11 with a 1.1 s cooldown. One case depends on them. In `blind-cb-combat-ram-blazing`, a jump stays in the air about 1.0 s, which carries the ball about 28 m at 28 m/s, past a chaser 15 m ahead.

## Wording rule

- **Bare actions.** Each option's `why` is one imperative sentence naming a bare action: where the ball goes or what it presses. Examples: "Roll east.", "Press E to open this cache.", "Stop and wait here.", "Jump toward the chaser."
- **What a `why` never says.** It never names the telegraph (marked spot, lamp, disc, arc) or says whether a move stays inside the ring or zone. It never states the action's purpose or result ("to land on", "up to the cache", "for regeneration"), and never gives a fact that decides the case.
- **Decisive facts live in `state`.** These include HP, scrap held, cache price, speed and time since the last hit. They also include distances, whether a target lies inside or outside the ring, charge banked, ring or zone radius and distance to its edge, and `targets_current_position`. Where the schema has no field for a fact, it goes in `self.location`, `self.over` or `objective.kind` as plain text.
- **Dodges share the form of other moves.** A dodge is a bare compass move. So are some losing moves, such as steering away while a chaser is below. That way the phrase alone does not mark the dodge.
- **Option order is shuffled.** The builder shuffles options with a fixed seed per case id, so list position carries no label. After the shuffle, the accepted option comes first in 12 of 31 cases. In A2 it came first in 24 of 29.
- **Every case can be decided from `state` alone**, including all five dominance cases.

## Labelling rule per block

A case is labelled only when the documents settle it. `accept` lists every option a sound player could defend from the documents.

Severity:
- `severe` when the wrong choice plausibly ends the run or wastes the stage.
- `moderate` when it costs charge time, HP or a stalled objective.
- `minor` otherwise.

| Block | Rule |
| --- | --- |
| dominance | One option is plainly better from the state alone, because the alternative is one of these: <br>- certain death (a 12 HP cableway load at 10 HP) <br>- something that cannot succeed (a cache priced above the scrap held) <br>- something that gains nothing while the 45 s tier clock runs (waiting at 100 HP with no buffs while scrap lies on the current line) |
| combat | Damage follows the READMEs' momentum rules. A stomp deals 26 and restores the air jump. A ram "above the fast tier" deals speed x 1.7, and no ram damage is stated at walk speed, so walk-speed rams are rejected. A jump is accepted only when its airtime (from `tuning.gd`) can land it on the target. Moving away from a telegraphed arc that targets the current position is accepted. |
| economy | Take a cache when the ball is at it or close to it, can afford it, and the price is at the low end: tier 1, the spillway hatch at 20, or the cable-bench horseshoe found early. Higher-tier caches that cost a detour are not labelled, because that trade-off is the open question the cable-bench sketch tests. |
| objective | While the exit charge runs, stay in the ring or zone, because leaving banks nothing and the tier clock keeps running. When the only option that stays is to wait, waiting is accepted (see below). When the charge is full, finish the exit. When nothing is affordable at the rig, start the charge. |
| safety | Move away from a telegraphed landing position rather than hold still; a few metres keeps the ball well inside the ring or zone, as `state` shows. When the klaxon sounds in the basin, head for the rim rather than the middle. That case is minor because no flood damage is stated. |
| traversal | The cable-bench kicker needs about 26 m/s, and about 9 m/s stalls. Take it at speed; skip it below that. |
| ordinary | With no threat present and 100 HP, keep moving along the scrap and route line the stage is built around. On the mid shelf, a basin klaxon does not change the ball's ground. That case is minor because the README states no water height. |

**Why `blind-cb-obj-start-exit-nothing-affordable` is settled but dropped candidate 3 is not.** In the kept case the ball is at the rig at tier 3 with 20 scrap. Every cache costs 99 or more, and the next tier costs about 141, so nothing done before the charge can buy a buff at current prices. Meanwhile each 45 s raises both cache cost and foe strength (cable-bench README L65-69), so delay only adds difficulty. Candidate 3 starts the charge at the opening of the stage, when caches are affordable and scrap lies ahead. Delay buys buffs there, and the README presents an early start as the stage's pressure test (spillway-drop L98-99), not as advice.

**When waiting (`retreat_regen`) is correct.** The sources give regen only as "regenerating slowly five seconds after you were last hit" (cable-bench L73) and "slow regen five seconds after the last hit" (spillway-drop L78). They state no rate, and every 45 s raises the tier. So they never make waiting-to-heal the better choice on its own merits. That is a gap in the sources.

The two cases that accept `retreat_regen` (`blind-cb-obj-wait-in-ring-low-hp` and `blind-sd-obj-wait-in-zone-low-hp`) rest on the charge rule instead. The exit charge is running, there are no threats, and every other option leaves the ring or zone, where time "banks nothing". Waiting is the only option that keeps the charge going, and regen is a side benefit. No case accepts waiting outside a running charge.

## Dropped candidates: 6

These were drafted and dropped because the documents do not settle them. No case was dropped in A2 or A3.

1. Cable bench: at low HP with a chaser pack closing, retreat or fight. Chaser speed and hit damage per tier are not stated.
2. Spillway drop: from the basin, return to the top shelf by pumping up a chute or by the bypass. README "What to try first" #3 leaves this open.
3. Spillway drop: start the exit charge at once with no buffs. README #6 frames this as a pressure test, not a recommendation.
4. Cable bench: open an affordable tier-3 cache that costs a detour. README L87-90 names this as the question the sketch asks.
5. Spillway drop: sweep basin scrap underwater during the flooded phase. README #4 leaves open whether the flood is a threat or an annoyance, and no flood damage is stated.
6. Cable bench: engage or avoid the exit-charge miniboss. It has no stated stats.

## Counts

- **Cases:** 31, of which 17 are cable-bench and 14 spillway-drop.
- **Blocks:** dominance 5, combat 6, economy 4, objective 7, safety 4, traversal 2, ordinary 3. Traversal is cable-bench only, because the spillway README gives no speed gate.
- **Severity:** 1 severe, 11 moderate, 19 minor.
- **Option balance:** every option id offered is accepted at least once. For example, `retreat_regen` is offered 9 times and accepted 2 times, and `evade_hazard` is offered 14 times and accepted 8 times.

Consistency rules:
- Spillway-drop cases never use `hit_kicker`, because that stage has no kicker.
- Each `stage.time_s` agrees with a tier that starts at 1 and rises every 45 s, and all cases stay within tiers 1-3.
- Spillway flood timing follows its 90 s cycle: 57 s dry, 5 s klaxon, 6 s rising, 14 s flooded, 8 s draining. The hatch is open only after 90 s.

## Validation rules

The scripts that apply these rules stay local to the labeller's worktree and are not committed.

**Schema.** The file is valid JSON of the form `{note, cases}`, and the validator reads its vocabularies from `schema.md` itself. For each case:
- `id` is unique and starts with `blind-`.
- `block`, `severity`, the stage name, the speed tier and every option id are in the schema's vocabularies.
- There are 2 to 5 options, with unique ids, and each has a `why`.
- `accept` is a non-empty subset of the offered ids that leaves at least one out.
- `stage.tier` is an integer from 1 to 3.
- The `self`, `objective`, `scrap`, `buffs` and `threats` fields match the schema's names and types.
- The provenance fields are present.

The corpus must have at least 20 cases and at least 4 dominance cases. As a negative control, a copy with seven planted faults must fail on all seven.

**Neutrality.** A `why` fails the scan if it contains any of the following:
- loaded words, such as "safe", "free", "cheapest" or "only"
- outcome facts: HP, scrap held, a price, a speed, the absence of a threat, timing ("before", "arrives"), results ("clears", "stalls") or affordability
- telegraph and target words: "marked", "spot", "target", "lamp", "disc", "arc" or "klaxon"
- ring or zone membership, such as "inside the ring" or "within 30 m"
- the clause "while the charge runs"
- intended landings: "land on", "onto" or "the landing"
- intended results: "up to", "to reach" or "to clear"
- purpose clauses: "for regeneration" or "for its scrap"
- hazard-relative escapes, such as "off the"
- "toward the ... cache" on a losing option

Each `why` must also be a single imperative sentence. The scan flags 45 items in the A2 corpus, which serves as its negative control, and passes A3. Any `why` with digits is listed for manual review; the ones left are place names such as "bench-0" and "x=-130".

**Text-only baseline.** A script picks an option from the `why` strings and list position alone, never reading `state`. Results on A3:

| Picker | Correct | Rate |
| --- | --- | --- |
| Uniform chance (expected) | 14.8 of 31 | 48% |
| Keyword rules I would write without state (act rather than wait, open caches, attack, finish at the rig, dodge anything naming a danger) | 19 of 31 | 61% |
| Always the first option | 12 of 31 | 39% |
| Always the last option | 17 of 31 | 55% |
| Shortest `why` | 19 of 31 | 61% |
| A bare compass move when one is offered | 13 of 31 | 42% |

The same keyword rules scored 22 of 29 (76%) on A2, and always choosing the first option scored 24 of 29 (83%).

What is left above chance on A3 comes from the game's own design rather than from wording. The sources say standing still is punished, stomps and rams at speed deal damage, and finishing the exit clears the stage. Across the options, no word of support 4 or more is always or never accepted, apart from "of" (in "the cache east of the apron" and "stretch of siding"), which never is.

## Burn rule

A case the prompt author sees is burned: it moves to the authored set and comes out of this blind corpus. Blind results reach the prompt author only as aggregates, which is the JL-04 boundary. Any replacement blind case must be labelled by someone who has not seen the prompt, using the same inputs and rules.
