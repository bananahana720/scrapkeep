# corpus-blind.json provenance

Card JL-04, lease JL-04-L1. Attempt JL-04-A1 wrote the corpus, and JL-04-A2 revised it after review. Both attempts were done by the same labeller on 2026-09-25 with the same inputs, so every case keeps `labeller: "scrapkeep-writer JL-04-A1"` and `prompt_epoch: "none-seen"`. The work sits on branch `wt/JL-04`, base `581f5f8d34c960e5feebbb913490e9165541263a`.

The labeller saw no player prompt, authored corpus, scorer or Jev output. Every label comes from the game's own design documents listed below.

## Inputs read

These are the only files opened. Every case's `inputs_seen` lists the same set.

| Input | Read at |
| --- | --- |
| `artifacts/local/tasks/JL-04/schema.md` (field names, types and option ids only) | coordinator-supplied, in the JL-04 worktree |
| `sketches/cable-bench/README.md` and `sketches/cable-bench/src/tuning.gd` | `proto/cable-bench` at `29dcbcf`, read from its worktree `/home/andrew/Projects/scrapkeep-worktrees/cable-bench`, which was clean for both files |
| `sketches/spillway-drop/README.md` and `sketches/spillway-drop/src/tuning.gd` | `proto/spillway-drop` at `af89c89`, read from its worktree `/home/andrew/Projects/scrapkeep-worktrees/spillway-drop`, which was clean for both files |
| `sketches/ball-lab/README.md` and `sketches/ball-lab/src/tuning.gd` | base `581f5f8` |
| `BIBLE.md` | base `581f5f8` |
| `BACKLOG.md`, section `### JL-04` only (lines 5326-5348) | base `581f5f8`; this is a disclosed input |

Two disclosures about `BACKLOG.md`:

- To find the JL-04 line I ran a heading-only `grep` over the file, and its output showed only the JL-04 heading.
- The JL-04 section gives the card's rules: at least 20 cases, at least 4 dominance cases, the list of forbidden inputs, and the burn rule. It contains no labels and no game rules.

The three `tuning.gd` files hold the same movement values: cruise 14, jump 13, gravity 26, air control 0.25, and a boost impulse of 11 with a 1.1 s cooldown. One case uses them directly. In `blind-cb-combat-ram-blazing`, a jump gives about 1.0 s of air, which at 28 m/s carries the ball about 28 m, past a chaser 15 m ahead.

## Wording rule

- **Options:** each option's `why` is one imperative sentence stating only what the action does in this situation, in the same form for every option.
- **Facts go in `state`:** the facts that decide a case are recorded in `state`, never in a `why`. These include HP, scrap held, a cache's price, speed, distances to other targets, how much charge is banked, and the ring or zone radius.
- **Where there is no schema field:** those facts go in `self.location`, `self.over` or `objective.kind` as plain text. For example, `over: "ground cache, price 99 scrap"` and `kind: "exit_charge, 20 of 60 s banked"`.
- **Test:** each case, including every dominance case, can be decided from `state` alone.

## Labelling rule per block

A case is labelled only when the documents settle it. `accept` lists every option a sound player could defend from the documents.

Severity:
- `severe` when the wrong choice plausibly ends the run or wastes the stage.
- `moderate` when it costs charge time, HP or a stalled objective.
- `minor` otherwise.

| Block | Rule |
| --- | --- |
| dominance | One option is plainly better from the state alone, because the alternative is certain death (a 12 HP cableway load at 10 HP), cannot succeed (a cache priced above the scrap held), or gains nothing while the 45 s tier clock runs (waiting to regenerate at 100 HP with no buffs, with scrap on the current line). |
| combat | Damage follows the READMEs' momentum rules. A stomp deals 26 and restores the air jump. A ram "above the fast tier" deals speed x 1.7, and no ram damage is stated at walk speed, so walk-speed rams are rejected. A jump is accepted only if its airtime (from `tuning.gd`) can land on the target. Moving off a telegraphed arc that targets the current position is accepted. |
| economy | Take a cache when the ball is already at it or close to it, it is affordable, and its price is at the low end: tier 1, the spillway hatch at 20, or the cable-bench horseshoe found early. Trading a higher-tier cache against the detour time is not labelled, because that is the open question the cable-bench sketch exists to test. |
| objective | While the exit charge runs, stay in the ring or zone: leaving banks nothing and the tier clock keeps running. When the charge is full, finish the exit. When nothing is affordable at the rig, start the charge (see below). |
| safety | Move off a telegraphed landing spot rather than hold still. During the charge, a move that stays inside the ring or zone keeps the charge running. When the klaxon sounds in the basin, head for the rim rather than the middle. This case is minor because no flood damage is stated. |
| traversal | The cable-bench kicker needs about 26 m/s, and about 9 m/s stalls. Take it at speed and skip it below that. |
| ordinary | With no threat present and 100 HP, keep moving along the scrap and route line the stage is built around. On the mid shelf, a basin klaxon does not change the ball's ground; this case is minor because the README states no water height. |

**Why `blind-cb-obj-start-exit-nothing-affordable` is settled but dropped candidate 3 was not.** In the kept case the ball is at the rig at tier 3 with 20 scrap. Every cache costs 99 or more, and the next tier costs about 141. So nothing done before the charge can buy a buff at current prices. Meanwhile each 45 s raises both cache cost and foe strength (cable-bench README L65-69), so waiting only adds difficulty. Candidate 3 starts the charge at the opening of the stage, when caches are affordable and scrap lies ahead. There, delaying buys buffs, and the README presents an early start as the stage's pressure test (spillway-drop L98-99), not as advice.

## Dropped candidates: 6

These were drafted and dropped because the documents do not settle them. No case was dropped in A2.

1. Cable bench, low HP with a chaser pack closing: retreat or fight. Chaser speed and hit damage per tier are not stated.
2. Spillway drop, in the basin: return to the top shelf by pumping up a chute or by taking the bypass. README "What to try first" #3 leaves this open.
3. Spillway drop, start the exit charge at once with no buffs. README #6 frames it as a pressure test, not a recommendation.
4. Cable bench, open an affordable tier-3 cache that costs a detour. README L87-90 names this as the question the sketch asks.
5. Spillway drop, sweep basin scrap underwater during the flooded phase. README #4 leaves open whether the flood is a threat or an annoyance, and no flood damage is stated.
6. Cable bench, engage or avoid the exit-charge miniboss. It has no stated stats.

## Counts

- **Cases:** 29 in total, 16 cable-bench and 13 spillway-drop.
- **Blocks:** dominance 5, combat 6, economy 4, objective 5, safety 4, traversal 2, ordinary 3. All traversal cases are cable-bench, because the spillway README gives no speed gate.
- **Severity:** 1 severe, 9 moderate, 19 minor.

Consistency rules:
- Spillway-drop cases never use `hit_kicker`, because that stage has no kicker.
- Each `stage.time_s` agrees with a tier that starts at 1 and rises every 45 s, and every case stays within tiers 1-3.
- Spillway flood timing follows its 90 s cycle: 57 s dry, a 5 s klaxon, 6 s rising, 14 s flooded, 8 s draining. The hatch is open only after 90 s.

## Validation rules

The scripts that apply these rules stay local to the labeller's worktree and are not part of this commit.

- **Schema:** the file is valid JSON of the form `{note, cases}`. The vocabularies are read from `schema.md` itself, not copied into the script. For each case:
  - `id` is unique and starts with `blind-`.
  - `block`, `severity`, stage name, speed tier and every option id are in the schema vocabularies.
  - There are 2 to 5 options with unique ids, and each has a `why`.
  - `accept` is a non-empty subset of the offered ids and excludes at least one of them.
  - `stage.tier` is an integer from 1 to 3.
  - The `self`, `objective`, `scrap`, `buffs` and `threats` fields have the schema's names and types.
  - The provenance fields are present: the labeller string, an ISO date, a non-empty `inputs_seen` and `prompt_epoch: "none-seen"`.
- **Totals:** at least 20 cases and at least 4 dominance cases.
- **Negative control:** a copy with seven planted faults must fail on all seven.
- **Neutrality:** no `why` may contain loaded words (for example "safe", "free", "cheapest", "only"). No `why` may contain an outcome fact: an HP value, scrap held, a price or cost, a speed, a claim that no threat is present, a timing claim such as "before" or "arrives", an outcome claim such as "clears" or "stalls", or affordability. Every `why` must be a single imperative sentence. A `why` containing digits is listed for manual review; the ones left are place names such as "bench-0" and "x=-130".

## Burn rule

A case the prompt author sees is burned. It moves to the authored set and is removed from this blind corpus. Blind results reach the prompt author only as aggregates (the JL-04 boundary). Replacement blind cases must be labelled by someone who has not seen the prompt, using the same inputs and rules.
