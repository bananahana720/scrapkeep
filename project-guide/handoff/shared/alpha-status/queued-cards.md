# Queued decision cards (coordinator)
Idea if the queue stays long when Andrew returns: one batch card 'Merge all gate-passed items?' listing each by name, with Merge all / Pick one by one.
Post when an open card slot frees (max three open).

## BRINDLE-HULL: now posted 10:07Z as the combined BOT-STAGE6 + BRINDLE-HULL card (one tap covers STAGE6, PR #34, BRINDLE-HULL, PR #30; branch scratch-brindle-merge @ 1d41c680). Earlier card was withdrawn 09:46Z; STAGE6 + #34 can't merge alone (Cannon drops to 2 of 4).

## HIVE-GRIND (from the wave thread, 07:20Z 17 Oct) — taste card
Queue order: CLASS-TILT (below) posts before this card.
Question: How fast should the stage-3 hive break under fire?
Context: its stagger bar fills slowly from shots and drains before it breaks, so runs time out. Bots clear it in 3 of 12 runs.
- A (recommended): shots fill the bar about 13x faster and it drains half as fast. Hoist, pulse warning and readability unchanged. Bots clear 7 of 12; Demolitions, Tally and Cannon seed 1 still late.
- A+: push shot fill to 30-40x so those three clear too; fight gets noticeably shorter and feels different.
- B: shorten the dwell instead; breaks 6 hive timing checks, no better than A.
- None: leave it for his playtest.
Default if untapped: A. Branches: A on worktree-agent-afd2c72b3d9a8542a (597718e1 + beed8c3a); B on hive-grind-b.
Machine now groups HIVE-GRIND with MIND-POSTURE and SINKHOLE-POSTURE as one posture family tuned under one rule; check with the wave thread before posting.

## Open cards 15:33Z: Close PR #21 (posted 15:32Z). Tapped Merge 15:30-15:32Z: BOT-STAGE6+BRINDLE-HULL, SOUND-INT (AUDIO-POOL folded in), CLASS-TILT, PR #13, SG2 #16, flaky-test timeout, earned cosmetics, pilot paint #17; SQ2 'Pack as one'. Next: posture family / HIVE-GRIND (asked wave thread 15:32Z), then #32, #29 after gate.

## CLASS-TILT merge (withdrawn again 10:07Z; repost first when a slot frees) — DONE (Merge tapped 15:30:02Z)
Question: Merge the enemy-tilt fix with new rows for Tarn, Tally and Cannon?
Context: tilt table was keyed wrong so it never matched; fix uses real pilot ids and adds Tarn contact, Tally weapon, Cannon heft. Still won't fire in a real run until the wave 17 nemesis work hooks it up. Branch worktree-agent-aea3f8bc9b58ded67 @ 541dad2d.
Options: Merge (recommended) / Merge, redo rows / Hold.

## SQ2 pack beat (PR #15) — queued 14:57Z, blocks #15 gate — DONE (Pack as one tapped 15:30:44Z)
Q: Should one enemy pack's warnings start together?
- Pack moves as one (recommended): a crew that arrives together winds up on the same beat, one tell per pack. Different packs and enemy types stay at least 0.2 s apart. Growing still pays off (Dig hive: grown 39 s, small 94 s).
- Every enemy apart: every warning, even inside one pack, stays 0.2 s from the next. A grown ball loses its edge in the Dig hive (46 s vs 87 s), breaking the growth-must-show rule; no other fix holds it.
Reason: a pack arriving together already reads as one threat, so sharing its beat keeps the 0.2 s reading time between threats, which is what the rule protects.
On tap: relay to "Build the attacker budget" thread (cmsg_01Q3o8RFpavsNskXDb46SG49BWEVPCyxSaZfynYrL7khrP). Option (a) is ready locally (~15 lines attack_budget.gd + pack tag from director.gd/world.gd); #15 currently at a7edeb83 (one-frame gap, not gate-eligible). Data: 8 seeds/arm; (a) 2.42x, (b) brace 1.83-1.87x.

## SG2 fusion rows merge (from wave thread 08:14Z; post after CLASS-TILT, before HIVE-GRIND) — POSTED 15:31Z — DONE (Merge 15:31:37Z)
Question: Merge element fusions?
Context: three element pairs now fuse, each with its own colour mix and card text. Arc + frost locks everything nearby in place; arc + heavy hit sets off an overload burst; frost + heavy hit grinds. Elites and bosses never lock and take a tenth of the grind (keeps his "Keep it" ruling). Fusion strikes don't trigger items. All six pilots' clear times over 4 seeds match the current build. Heads-up: Storm Front and Live Wire fuse on every slam.
Options: Merge (recommended) / Hold.
PR #16 head 993294a0, branch worktree-agent-a644dbfed48fae4a7, gate merge 3188b733. Gate PASS+NOTES; 3 smoke failures not this PR's.
## Pilot paint merge (from wave thread 09:24Z; post after SG2) — DONE (Merge 15:32:14Z)
Question: Merge pilot paint?
Context: pilot paint jobs now work in the game. Old saves with Kest's retired rigger outfit switch to the matching rigger paint, so no save loads with a missing look. All 795 smoke tests pass on today's candidate, five paint tests pass, placeholders drop by 6 to 1,436. How it looks on screen is for his play sitting.
Options: Merge (recommended) / Hold.
PR #17 with fix 3d99a130, branch worktree-agent-ad21b42d5a936fd40, merge 8df181ce. Gate PASS level 4.
## Flaky-test timeout merge (from wave thread 09:37Z; low stakes, batch with other merges at the back) — DONE (Merge 15:32:12Z)
Question: Merge the flaky-test timeout fix?
Context: the test that checks effects don't use up the game's random numbers has failed on and off since wave 15; the game isn't at fault, the test's 65 s limit is too short on a busy machine. Limit goes to 180 s, nothing else changes. Passed 3 of 3 on the candidate.
Options: Merge (recommended) / Hold.
Branch worktree-agent-a53580978219f3812, head c393f4f3, on cand/alpha-w16 2fce8953. Gate PASS level 4.
## Earned cosmetics merge (from wave thread 12:03Z; covers PRs #18 and #19 + wiring) — DONE (Merge 15:32:13Z)
Question: Merge 13 earned cosmetics?
Context: now visible and equippable. Hats: Welding Hood (Rivet), Eyeshade (Tally), Steady Cap (Tarn). Companion skin: Till Bell. Trails: Swarf, Punch Tape, Claw Marks, Downbeat, Recital, Fuse Smoke, Cable. Decals: Curtain Call, Sable Spool. Eyeshade garters on both arms; Hood clip swings with the ult windup. Art had shipped hidden; now wired. Placeholders drop by 13. Look in motion is for his sitting.
Options: Merge (recommended) / Hold.
Branch worktree-agent-a1cd72610cf8d239c @ 38d831c1, merges cleanly onto cand/alpha-w16 2fce8953. Gate PASS+NOTES level 4.
## Close PR #21 (low priority, behind the merges; from wave thread 13:41Z) — POSTED 15:32Z
Question: Close the old audio workaround PR?
Context: the music and sound merge fixes the 4-core audio hang at its root; the three tests #21 worked around now pass on 4 cores without it, plus all 20 audio tests. If cloud audio tests hang again after the merge, reopen it. (Only checked on the machine's 4-core-limited run, not a real cloud container.)
Options: Close #21 (recommended) / Keep open.
Status only: #22 headless loader undecided (frame-time checks flake under load, re-judge on a quiet machine). #15: see the SQ2 pack beat card and the roll-up line.
## Roll-up lines (no card)
- PR #15 SQ2 attacker budget failed the gate at level 4 (13:41Z): the 2x failure was traced to the 0.2 s gap staggering pack mates; it now waits on the SQ2 pack beat card.
## Later merge cards: PR #32 placeholder rule, PR #29 sinkhole ring+basin after gate.
## Queued 2026-10-17 16:36Z
(a) Lore: "How many lore notes should each park hold?" Options: "Collect over runs" (recommended; 7-17 notes per zone, about seven found per run, codex fills over several runs like Hades) / "Seven per zone" (one run fills the codex; cuts about 37 notes). Tap goes to the "Port the park lore" thread.
(b) "Where should game code be written and merged?" Options: "Cloud writes and gates" (recommended; cloud edits src/ and assets/ on branches and gates in the cloud, PC keeps only GPU checks and the merge) / "Cloud writes, PC gates" / "Keep as is". This changes his rule, so on tap he must also type one line in the project chat, and then the coordinator updates the project instructions' standing-approval paragraph.
