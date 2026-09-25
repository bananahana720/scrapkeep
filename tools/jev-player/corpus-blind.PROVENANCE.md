# corpus-blind.json provenance

Card JL-04, attempt JL-04-A1, lease JL-04-L1. Labeller: `scrapkeep-writer JL-04-A1`, 2026-09-25, `prompt_epoch: none-seen`. Base `581f5f8d34c960e5feebbb913490e9165541263a`, branch `wt/JL-04`.

The labeller saw no player prompt, authored corpus, scorer or Jev output. Every label comes from the game's own design documents listed below.

## Inputs read

These are the only files opened, and every case's `inputs_seen` lists the same set.

- `artifacts/local/tasks/JL-04/schema.md` (field names, types and option ids only)
- `/home/andrew/Projects/scrapkeep-worktrees/cable-bench/sketches/cable-bench/README.md`
- `/home/andrew/Projects/scrapkeep-worktrees/cable-bench/sketches/cable-bench/src/tuning.gd`
- `/home/andrew/Projects/scrapkeep-worktrees/spillway-drop/sketches/spillway-drop/README.md`
- `/home/andrew/Projects/scrapkeep-worktrees/spillway-drop/sketches/spillway-drop/src/tuning.gd`
- `sketches/ball-lab/README.md`
- `sketches/ball-lab/src/tuning.gd`
- `BIBLE.md`
- `BACKLOG.md`, section `### JL-04` only (lines 5326-5348). A heading-only `grep` located the line; its output showed just the JL-04 heading.

The three `tuning.gd` files hold identical movement values: cruise 14, jump 13, gravity 26, boost impulse 11 with a 1.1 s cooldown. They inform the speed context but decide no label on their own.

## Labelling rule per block

A case is labelled only when the documents settle it. `accept` lists every option a sound player could defend from the documents. Severity is `severe` only when the wrong choice plausibly ends the run or wastes the stage, `moderate` when it costs charge time, HP or a stalled objective, and `minor` otherwise.

| Block | Rule |
| --- | --- |
| dominance | One option is plainly better under any wording, because the alternative is certain death (a 12 HP cableway load at 10 HP), cannot succeed (a cache that costs more scrap than is held), or gains nothing while the 45 s tier clock runs (idling at full HP with scrap on the current line). |
| combat | Damage follows the READMEs' momentum rules. A stomp deals 26 and restores the air jump. A ram damages only above the fast tier, at speed x 1.7. Rams at walk speed are rejected; stomps and rams at blazing speed are accepted; moving off a telegraphed arc is accepted where the arc targets the current position. |
| economy | Take a cache when the ball is already at it (no detour), it is affordable, and the cost sits at the low end of the curve: tier 1, the spillway hatch at 20, or the cable-bench horseshoe found early. Higher-tier cache-versus-time trades are not labelled; they are the open question the cable-bench sketch exists to test. |
| objective | While the exit charge runs, stay in the ring or zone: leaving banks nothing and the tier clock keeps rising. When the charge is full, finish the exit. When nothing is affordable at the rig, start the charge, since delay only raises cost and enemy strength. |
| safety | Move off a telegraphed landing spot or out of the flooding basin, and never stand still under an arc. During the charge, a move that stays inside the ring or zone keeps the charge running. |
| traversal | The cable-bench kicker needs about 26 m/s; about 9 m/s stalls. Take it at speed, and skip it below that. |
| ordinary | With no threat present and full HP, keep moving along the scrap and route line the stage is built around. On the mid shelf, a basin klaxon does not change the ball's ground. |

## Dropped candidates: 6

These were drafted and dropped because the documents do not settle them:

1. Cable bench: low HP with a chaser pack closing, retreat or fight. Chaser speed and hit damage per tier are not stated.
2. Spillway drop: in the basin, return to the top shelf by pumping up a chute or taking the bypass. README "What to try first" #3 leaves this open.
3. Spillway drop: start the exit charge at once with no buffs. README #6 frames it as a pressure test, not a recommendation.
4. Cable bench: open an affordable tier-3 cache that costs a detour. README L87-90 names this as the question the sketch asks.
5. Spillway drop: sweep basin scrap underwater during the flooded phase. README #4 leaves open whether the flood is a threat or an annoyance, and no flood damage is stated.
6. Cable bench: engage or avoid the exit-charge miniboss. It has no stated stats.

## Counts

29 cases: cable-bench 16, spillway-drop 13. Blocks: dominance 5, combat 6, economy 4, objective 5, safety 4, traversal 2 (cable bench only, because the spillway README gives no speed gate), ordinary 3. Severity: severe 1, moderate 10, minor 18.

Spillway-drop cases never use `hit_kicker`, because that stage has no kicker. Each `stage.time_s` is consistent with a tier that starts at 1 and rises every 45 s. Spillway flood timing follows its 90 s cycle, and the hatch is only open after 90 s.

## Burn rule

A case the prompt author sees is burned. It moves to the authored set and is removed from this blind corpus. Blind results reach the prompt author only as aggregates (JL-04 boundary). Replacement blind cases must be labelled by someone who has not seen the prompt, using the same inputs and rules.

## Reproduce

The scripts live under the gitignored `artifacts/local/tasks/JL-04/` in the JL-04 worktree, beside their saved outputs. They are local evidence and are not committed. From the worktree root:

```bash
node artifacts/local/tasks/JL-04/build-corpus.mjs      # regenerates corpus-blind.json
node artifacts/local/tasks/JL-04/validate-corpus.mjs   # schema fields and vocabularies, parsed from schema.md
```
