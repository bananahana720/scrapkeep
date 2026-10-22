# Alpha handoff: checkpoint 1 passed, 3 October 2026

> **Historical handoff log (3 to 10 Oct).** The live handoff is [project-guide/coord/GRAPH.md](../../../project-guide/coord/GRAPH.md); rulings are in [project-guide/handoff/DECISIONS.md](../../../project-guide/handoff/DECISIONS.md). Retry and run-length lines below predate the 22 Oct rulings (no free retry; three worlds, 30 to 45 minutes).

**Checkpoint 1 passed** (playtest entry 12, EV-0624). Andrew: "really fun", "getting really close", boss "much, much more refined"; difficulty 2, pacing 3, clarity 4; all seven calls kept. He asked for the full three-world alpha for a multi-hour sitting: "full-send it to complete the game." The hard gate is open: Dig and Highdraft may be built. The coordinator role is back with the Claude session that recorded EV-0623 and EV-0624; Codex owns the Sol asset lane only.

## Wave 11 landed (2026-10-09, 306bc4d = merge of cand/alpha-w11 054eb92); wave 12 seeded

proto/alpha went a412d6e to 306bc4d (a merge, because two record commits sat on proto/alpha after the candidate's base 39c20a0). Thirteen units on Claude plus three fix rounds: GP1 world-three sites (9a3ad34), GP2 six parts and four synergies, GP3 pressure rows with Breath as a gameplay multiplier (GP3F made hard the authored baseline; KESTFIX flattened stage 1 and 2 pack_scale to 1.03 and 1.04 because 1.05 or more rounds the crowd cap up one step and Kest never reaches Brindle's core, so the pressure climb now starts at the Dig), GP4 Mind escape corridor, GP5 pilot locks with the schema 3 migration (fresh profile opens Sable only; Fable save review PASS+NOTES in `push/w11/GP5/fable-review.md`), GP7 bot slice and six-pilot win tests, COV1 coverage warnings, UI1 first and last screens, VX1 Highdraft light (grid floor gone, warm key, cloud deck), VX4 states (Luna trial, finished by Claude), VX7 actor poses, VX8 false telegraphs (Luna trial, finished by Claude), SMK heartbeat slot pool. Gate round 1 had 15 reds, all attributed and fixed (`push/w11/GATE/round1-attribution.md`): 4 real defects (Highdraft relief mesh crash in the ending flyover, Kest card key-row overflow from a mid-word wrap, Kest's Brindle stall, locked greybox gate outside the cage), the rest stale pins the briefs failed to name as forced neighbours. Gate round 2 on 054eb92: 562 runs, 0 failed, 1 skipped (`gate-7eedcc52c24c-2026-10-09T01-04-40-303Z.json`). Opus read: HOLD on two preconditions, both met (cannon seed 11 proof on this head from the export; GP5 Fable review); ADMIT PASS+NOTES in `push/w11/GATE/verdict.md`, notes carried to `push/w12/SEEDS.md`.

**Export.** 054eb92: `artifacts/local/core-loop-export/scrapkeep-core-loop-054eb92.tar.gz` in the main checkout (sha256 44a1dd58c51f157e...), 101.4 MiB, 234 sidecar stems. Three win proofs: Rivet skipper seed 1 won at stage 6, 40565 ticks; cannon seed 11 won, 34002 ticks; Tally seed 1 won, 37696 ticks.

**Fix round 3 (Waking Vulkan crash, 2eae727, proto/alpha ca3f9ba).** The wave 11 capture replay found that entering the Waking arena segfaulted under Vulkan Forward+ on 054eb92 (5 of 5 runs; clean on wave 10 and on OpenGL; invisible to the headless gate and the bot proofs). Bisect at level 4: `CacheRimLight`, one OmniLight3D per cracked cache, freed with the cache at the stage clear, then the next `enter_boss` trips the engine's light-unpair bug, the same hazard class as the wave 9 per-cage light. Fix 2eae727 replaces every per-cache light with an emission overlay on the cache's own mesh (the cache shader has no emission uniform, so a duplicated material could not carry it); `device_props_asset_test` hash re-pinned for one line in `crumble()`, `cache_waking_pylon_lit_test` light record set to zero lights, dated notes. Proof: 3 of 3 Vulkan arw2 runs clean, wired smoke green, full gate 562 runs 0 failed (`gate-b82f862822da-2026-10-09T02-48-42-319Z.json`), export 2eae727 with the same three win proofs (Rivet 40565, cannon 34002, Tally 37696). Tarball `scrapkeep-core-loop-2eae727.tar.gz` in the main checkout, sha256 6f1de7bbbab9d05a... Open: why wave 10 did not trip with the same light (the VX8 `LANE_OFFSET` move is the likely trigger, unverified); `WardenCoolFill` is the same hazard class, untouched; two unpair errors remain at quit teardown. Wave 12 seed: a GPU boss-entry smoke per boss in the export step. Record: `push/w11/GATE/attribution.md`, round 3.

**UAT.** First-minutes on the export (`push/w11/uat/first-minutes-w11.md`): steps 1 to 6 pass by frame (Moss's spare-seal bubble beside the Cannonball/Beachhead pick in frame 006); step 7 found one small defect, a Tab tap in the PAUSED menu does nothing because `pause_menu.gd` `_menu_key` has no KEY_TAB case while the row shows a Tab keycap (w12 UI-PAUSE-TAB).

**Judges on the wave 10 build** (`push/w11/judge/`): screens, actors, devices, Highdraft, arenas filed; the worlds judge overflowed on 118 frames and was split four ways (note for wave 12: about 20 frames per judge). Their lists and the research adoptions (headless route proof, fixed-tick screenshot diff, silhouette-difference assertions, dead-frame capture check, the six course rules, editor MCP measured and not adopted) are in `push/w12/SEEDS.md` and `push/w12/briefs/COMMON.md`.

**Owner veto list (wave 11).** Kest free to returning v2 profiles; stage 1 and 2 pack pressure flat; Dig lamps and plate daylight removed; remnant hit height lowered 1.1 m; altar floor ring gone; 9 px clipped key words on Kest's card; Luna trial scored writer-attributed on both units.

**Next.** Andrew plays the 2eae727 export (the Waking-crash fix) end to end on a fresh profile and brings notes. Wave 12 cuts from SEEDS after his read, smaller than wave 11, judged on wave 11 captures first.

## Wave 10 landed (2026-10-08, a412d6e); wave 11 gating

proto/alpha went 0e527c0 to a412d6e by fast-forward of `cand/alpha-w10`: twelve units on Claude (Sol refused on the logged-in account, P-R24). ST1 field notes unlock one per lore moment (d136ded); ST2 Warden and boss intro lines once per run and zone (698e136); ST3 ending copy as a world-keyed dictionary with the credits (e9d09ce, screens consumer re-wired by the coordinator); ST4 codex covers every spawning kind plus the three Highdraft world tricks, with live detectors (27db7ab); ST5 prologue cards at class select and pilot-reward beats (9d96ceb, the shipped code is round 1 plus coordinator wiring); ST6 Dig and Highdraft lore on the approved sample lines (64a88de); MOT1 pilot reactions on bus signals (15cc839); SAFE1 Continue refuses a changed-on-disk or ended save by name, no save over a refused file (907b19a); AU2 new sounds baked, not yet routed (e71f64a); GP6 enemy idle, death and wind-up rows (110136c, landed from staged patches after a worktree hook blocked its writer); VX2 net bowl (e714256); VX3 Waking pit and cracked cache lit (7912b83). Coordinator wiring: content pins re-pinned with dated notes; the grown Warden break re-pinned 37.9 to 32.5 s because the new codex detectors pay the discovery burst during the tuning fight (design, confirmed by stubbing the discover calls); ten ACE stem packs copied under `assets/music_ace`; posture bands test declares its 360 s smoke cap.

**Gate.** `npm run sketch:gate` on be6043a: 546 runs, 0 failed on code, 1 skipped (audio_worlds_test headless), 1 missing verdict (alpha_posture_bands_test at the 180 s cap under load; passed alone on the same tree and on a412d6e, 13 checks). Receipt `scrapkeep-wt-dress-cand-w10/artifacts/local/receipts/gate-a09a8bf160e3-2026-10-08T19-57-51-717Z.json`. Opus read ADMIT PASS+NOTES (`artifacts/local/alpha/push/w10/GATE.md`): no gameplay constant changed; SAFE1 has no loss, reset or crash path at level 3; ST5, ST3, ST2 and GP6 are gate-covered, not per-unit reverified. Notes N1 to N9 seeded into `push/w12/SEEDS.md`.

**Export.** a412d6e: `scrapkeep-wt-dress-cand-w10/artifacts/local/core-loop-export/scrapkeep-core-loop-a412d6e.tar.gz` 101.4 MiB, all eleven ACE packs. Win proofs: Rivet skipper seed 1 won at stage 6, 31348 ticks, 116.4 s wall (wave 9: 33695); cannon seed 11 won at stage 6, 34887 ticks (wave 9: 47861; the seed is not repeatable, judged on the win).

**UAT.** The A stack `uat` runner drives the build on a hidden display with Haiku 5.5 (`push/w10/uat/`). First-minutes flow on a412d6e: title, prologue (E advances), Sable chosen under the prologue, Spillway with Moss's exchange and the opening part pick, W moves the ball, pause menu; no black screen, no overlap, no error text; $0.011. Two scenario errors fixed (Tab is a hold; prologue uses E).

**Wave 11.** `cand/alpha-w11` (`/home/andrew/Projects/scrapkeep-wt-dress-cand-w11`) holds eleven admitted units (GP1 world-three sites, GP2 six parts and four synergies, GP4 escape corridor, GP5 pilot locks with the schema 3 migration, COV1 coverage warnings, UI1 first and last screens, VX1 Highdraft light, VX7 actor poses, VX8 false telegrams, VX4 states, SMK heartbeat slot pool) plus the wave 10 fixes; dig_rescue_test re-wired to the class row unlock label. GP3 pressure curve and GP7 bot slice are in their lane. Next: merge them, compile check, wired smoke, full gate, Opus read, export. The Luna trial (two units, three rounds each, both finished by Claude) is scored in `push/w11/VX4/verdict-round4.md`.

**Wave 11 merge reds (2026-10-08 23:05).** The merged candidate (c9c4b75) had three reds in its wired smoke. The slice elite one is wired away (slice row elite_rate 0.0, slice test feeds its row). The other two come from the pressure unit alone, measured by running cannon seed 1 on three sibling trees: the states and bot-slice trees win on identical ticks, the pressure tree stalls at Brindle phase 3 with the hull on 2 HP and 252 slag hits; the cause is the authored PRESSURE rows multiplied by the default hard Breath. GP3F (brief `artifacts/local/alpha/push/w11/briefs/GP3F.md`) makes hard the authored baseline, gentle the ease, re-measures the posture pins and must win the cannon on 3 of seeds 1 to 4. Full story: `artifacts/local/alpha/push/w11/GP3/attribution.md`.

## Wave 9 landed (2026-10-08, 0e527c0); refine push opened

proto/alpha went cafd32e to 17e9e6a by fast-forward of `cand/alpha-w9` (DETC 43d5de3 crush order in scene-tree order; FUA d905b67 five filed review findings from waves 6 to 8; FUB cedd7a0 malformed model files fall back instead of crashing; cagelight 6381f5c cages glow through their signal; smoke-runner head marker 6012890 raising one test's cap, bounded at 360 s; 17e9e6a tracks the generated .uid files), then 0e527c0 (coordinator tools and rulings P-R21 to P-R24).

**Gate.** `npm run sketch:gate` on the exact tree 17e9e6a: 528 runs, 0 failed, 1 skipped (audio_worlds_test, headless), 28 solo, 2087 s, clean tree; receipt `scrapkeep-wt-dress-cand-w9/artifacts/local/receipts/gate-6ab0e74302eb-2026-10-08T17-10-26-108Z.json`, log `.../push/w9/gate3.log`. The earlier gate on 075b3f1 had two solo timeouts at 188 s (posture bands, bot_run_end) that passed here and in a named rerun. Opus gate read (scrapkeep-reviewer-medium, Opus 5.5): ADMIT, PASS+NOTES, level 2 from the diff files and receipt. Notes: FUB turned the plated_brute missing-paint error and the ramp_flipper paint assert into warnings and `dress_coverage_test` counts errors only, so a half-broken paint slot could pass coverage (follow-up unit COV2: coverage fails on those warnings or each asset test asserts the slot); `alpha_posture_bands_test` keeps the 180 s cap; one green two-run comparison does not prove the cannon seed 11 drift closed.

**Export.** 0e527c0: `scrapkeep-core-loop-0e527c0.tar.gz` 101.3 MiB (all eleven ACE packs; earlier tarballs from the main checkout carried only Spillway stems, so the full stem set was copied into the main checkout's and this worktree's `assets/music_ace`, gitignored). Win proofs: Rivet skipper seed 1 won at stage 6, 33695 ticks, 118.98 s wall (wave 8: 34027; DETC moves crushes to end of frame, so a one-time shift was expected); remembered cannon skipper seed 11 won at stage 6, 47861 ticks, 202.62 s wall (wave 8 range 33386 to 36378; still not repeatable, judged on the win). Copied to `artifacts/local/alpha/export/0e527c0/`.

**Refine push.** Plan `/home/andrew/.claude/plans/let-s-plan-and-see-moonlit-adleman.md` (approved 2026-10-08). Rulings P-R21 (pilot locks), P-R22 (Breath normal toward 3 of 5), P-R23 (Codex cap 4 fast, drop to standard at 60%), P-R24 (the logged-in ChatGPT account refuses Sol and Astra; wave 10 runs on Claude). Wave 10 is in flight on twelve Claude writers (briefs `artifacts/local/alpha/push/w10/briefs/`).

## Dress push waves 1 to 3 landed (2026-10-06, a6b75ea)

The dress push (plan `/home/andrew/.claude/plans/let-s-plan-an-agent-dazzling-shamir.md`, board [DRESS-MANIFEST](DRESS-MANIFEST.md), resume note [PUSH-RESUME](PUSH-RESUME.md), rulings P-R1 to P-R11 in `docs/decisions.tsv`) replaces placeholder art with real models. proto/alpha went c91b28f to a6b75ea through merge 7cc63e9 of `cand/alpha-w3`.

**What changed for the player.** 48 of 52 tracked subjects now render real models (27 placeholders at the start; left: miniboss, swarm_remnant, vault, Brindle's pickup). Every enemy kind, the three bosses and the Mind's hands, Tarn, Tally and the remembered cannon with their own shells, Warden mantles on stages 3 to 6, and a SPIL-9 body that hovers beside the ball. The Dig has cut faces, carts, lamp lines, two landmarks and drum skins on all eight breach covers; the Highdraft has skinned islands, bridges, barges, thermals, net deck and anchors, props and a far sky. Ten new ACE tracks are rendered but not yet wired (`artifacts/local/alpha/push/w1/D8/out/renders/`).

**Units.** Wave 1: eight Sol direction sheets (D1 to D8). Wave 2: 27 Sol model and port units plus REG (registry, ratchet 27 to 16). Wave 3 (Claude Sonnet 5.5 medium after the Codex limit, P-R8): WHE pilots and mantles, WBO bosses, WCO companion, WDG Dig scenery, WHD Highdraft scenery, all PASS+NOTES at level 4.

**Evidence.** Gate on cand/alpha-w2 5105e06: 453 runs, 0 reds, 2078 s. Gate on cand/alpha-w3 a8d6925: 458 runs, 0 reds, 1832 s, receipt `artifacts/local/receipts/gate-da6e45484efd-2026-10-06T20-35-00-477Z.json` in that worktree. Opus gate read (scrapkeep-reviewer-medium): FAIL on two items; the smoke-lock rule was fixed (718f6a0, red then green) and silent loader fallbacks were waived because dress_coverage_test fails the gate on any returning placeholder (P-R10). After the merge the export's win proofs drifted (Rivet 34066, cannon 37304); bisected to WDG's boot-time `geometry_root` call, which changes physics body creation order with no scenery built. a6b75ea builds the Dig on first entry (P-R11).

### Export

At a6b75ea: tarball scrapkeep-core-loop-a6b75ea.tar.gz 46.4 MiB, ACE_CHECK ready clips=8 streams=24. Win proofs: Rivet skipper seed 1 won at stage 6, 38208 ticks, 99.26 s wall; remembered cannon skipper seed 11 won at stage 6, 34249 ticks, 117.22 s wall. Both equal waves 18 to 20. Copied to `artifacts/local/alpha/export/a6b75ea/`. Log `artifacts/local/alpha/push/w3/export2.log`.

### Next

Pacing: Claude was at 96 to 97% of its week (resets Thu 22:00) and Codex is out until 2026-10-11, so no writer wave was started after this. The next wave: the four remaining placeholders, the cosmetics runtime (CUS, lost to the Codex limit; superseded 2026-10-16: paint tints landed in wave 14 as cosmetics-paint dd359b6, and the eight-slot model, `CosmeticWear.worn`, shell variants and outfits are in the code, per [research/PAINT-TRACE-2026-10-16.md](research/PAINT-TRACE-2026-10-16.md)), music rows for the ten new tracks, GPU captures from each unit's `artifacts/local/dress-capture/<unit>.md` plus the blind judge, then animation and effects. Follow-ups from P-R9 and P-R10.

## Wave 20 landed (2026-10-06, d03422d)

The wave 20 candidate cand/alpha-w20 landed as d03422d (proto/alpha went 40d7f5a to the wave 20 records commit; one unit, 3 commits over base by `git rev-list --count 40d7f5a..d03422d`). Branches are deleted. Coordinator commits on the candidate: the merge and the records commit.

**Milestone:** M4 (alpha) bot evidence: the bot driver recovers from confinement during the Warden charge, so the three solo-reproduced soak stalls (Kest 2, Kest 14, Tarn 15) now break their Warden and advance. This is a tool change only; no game code moved.

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| charge-recover | wt/alpha-w20-charge-recover | 56e5167 | opus (astack:worker) | PASS+NOTES after one fix round | bounded lack-of-progress watch in the charge phase (6 s window, 2 m), escape by back-off and jump or a rim climb when the target is below, cap 3 per stage; bot_charge_recover_test 21 checks incl. seven synthetic pit cases; baseline held on all four pinned recipes before the edit |

Round 1 FAIL (writer): the first escape left Kest 2 and Kest 14 stalled with three recoveries spent and the Warden unbroken; the fix added the rim-climb branch for a ball below the rim and stopped the per-target reset from clearing the cap. Round 2 PASS+NOTES.

**Run table after the change (pinned pilots, fresh dirs, 600 s cap):** Kest 2 broke the stage 3 Warden at 186.3 s and won at stage 6 (103882 ticks, one recovery). Kest 14 broke the stage 4 Warden at 182.9 s (one recovery) and stalled at stage 5. Tarn 15 broke the stage 4 Warden at 229.6 s (three recoveries, the cap) and stalled at stage 5. Sable skipper 12 (control) won with two recoveries. Rivet skipper 1 won in exactly 38208 ticks with zero recoveries (the export win proof is untouched). Tarn 3 and the cannon 5 won. Posture bands exact at 78.4 and 37.9.

**Open from the notes:** the stage 5 stalls for Kest 14 and Tarn 15 end in "fight warden charge climb"; the progress watch returns early while climbing (bot_driver.gd:1411), so a stuck climb is unwatched. The short-room back-off branch has no test. `_face_ahead` casts on layer 1 without exclusions and may read an enemy as a wall.

### Sol lane (Codex gpt-6.1-sol high)

Idle this wave. The wave 19 diagnosis (W19-R5) supplied the mechanism and the baseline recipe this unit used.

### Gate

Candidate cand/alpha-w20. Gate 1 ran on d03422d: 424 runs, 8 at a time, 25 solo, 0 reds, 1802 s, 7 environment skips (music stems not packaged in the worktree, no audio headless); receipt artifacts/local/receipts/gate-37293b0febe1-2026-10-06T05-51-36-250Z.json records head d03422d. No merge after the gate; the records commit is docs only. Gate read (d03422d): ADMIT, PASS+NOTES, level 2 by the reviewer's reads of the gate log, receipt, git captures, export log and the writer's run artifacts (Opus 5.5, scrapkeep-reviewer-medium; two files in the wave, no src/ change, alpha_defs posture rows curve 2.0 and ram_shatters false at every stage, watchdog constants STAGE_LIMIT 240 and BOSS_LIMIT 420 untouched; the three stall runs were recorded on the uncommitted fix tree later committed unchanged as 56e5167, same driver mtime). proto/alpha is fast-forwarded to the wave 20 records commit by the coordinator.

### Export

At d03422d: tarball scrapkeep-core-loop-d03422d.tar.gz 41.1 MiB, ACE_CHECK ready clips=8 streams=24, stems from the main checkout. Two win proofs on one pack: Rivet skipper seed 1 won at stage 6, 38208 ticks, 124.74 s wall; remembered cannon skipper seed 11 won at stage 6, 34249 ticks, 146.41 s wall. Both tick counts equal waves 18 and 19. Copied to artifacts/local/alpha/export/d03422d/. Log artifacts/local/alpha/wave20/export1.log.

### Rulings (coordinator, 2026-10-06; recorded in docs/decisions.tsv at the wave 20 records commit)

- W20-R1 charge-recover admitted after one fix round; stage 5 climb stall and the two untested branches go to wave 21.

### Open after wave 20: wave 21 concerns

1. Extend the charge progress watch to the climbing case (Kest 14, Tarn 15 at stage 5); baseline on those two pinned recipes first.
2. Test the short-room back-off branch; exclude non-terrain bodies from `_face_ahead`.
3. A fourth soak on the new head would show the aggregate effect of the recovery (expected: two or three more completionist wins).
4. The Mind's lane attack rarely fires against bots (W19-R4); Andrew's call (hands item 34).
5. Carried: tree_bot_test watch, roster R11 natural-width formula, unlock_live phase skip, Godot test run folders (1.8 GB), old Codex job worktrees and the wave 7 Highdraft probe worktree.

### Hands checklist (never blocks; items 13-34 carry over)

35. Watch a completionist bot run as Kest on seed 2 (tools/bot_run.gd --policy=completionist --seeds=2 --pilot=demolitions_caster --trace=1) if you want to see the recovery: the ball backs off and jumps out of the Dig cache pocket around 180 s.

## Wave 19 landed (2026-10-06, e908ece)

The wave 19 candidate cand/alpha-w19 landed as e908ece (proto/alpha went cd4b6f8 to the wave 19 records commit; two units plus the soak note, 6 commits over base by `git rev-list --count cd4b6f8..e908ece`). Branches are deleted. Coordinator commits on the candidate: cd1cbc6 (Sol soak note committed), the merges and the records commit.

**Milestone:** M4 (alpha) acceptance evidence, continued: the fresh-profile unlock is now proven on the live path (a real Brindle kill, real emit order, Tarn opens), the roster's card cap check can fail, and the third soak records load per run and gives the first direct Mind coverage table.

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| tidy | wt/alpha-w19-tidy | db5983b | sonnet (astack:hand) | PASS+NOTES | class_def.gd starter comment matches the data (Sable and Rivet start open); roster_test R11 at 3200x1800 pins all six cards to CARD_MAX, red under two mutants |
| unlock-live | wt/alpha-w19-unlock-live | e60d697 | opus (astack:worker) | PASS+NOTES (verifier on Sonnet 5 high via router, W19-R3) | unlock_live_brindle_test 34 checks in 12 s: real arc strikes and a smash chunk, boss.jump_to_phase(4) to the eject, real catch strike kills Brindle; observed bus order enemy_killed(brindle) then boss_defeated; Tarn selectable after the summary and after reload; skip-the-catch mutant fails 11 of 34 |
| soak-w19 | wt/alpha-w19-soak | cd1cbc6 | Codex Sol (gpt-6.1-sol high), coordinator commit | n/a (evidence) | 72 runs on cd4b6f8 at concurrency 2: 42 wins, 30 stalls (24 camper by design), 0 crashes, 0 SCRIPT ERROR; load per run; six solo reruns: four repro, two env; Mind coverage table |

Cause of each review red: none this wave.

**Mind coverage (first direct measurement, 43 stage-6 runs):** split_lane commits in 40 of 43 fights, rush in 39, plate in 42, lane in 5. Lane is a phase 1 attack and most bot fights take the first chunk within the 3 s introduction, so lane rarely gets a slot. This is a design observation for Andrew's veto list, not a defect: the Mind's opening is short against a skipper.

**Stalls that reproduce solo (W19-R4):** Kest completionist 2 (stage 3), Kest 14 (stage 4) and Tarn 15 (stage 4) all end on "fight warden charge"; Sable skipper 12 ends on Brindle "charge short". Sol's read-only diagnosis of the common mechanism is running; the wave 20 driver unit, if any, runs the four solo commands as its baseline first.

### Sol lane (Codex gpt-6.1-sol high)

Two lanes: the soak (writer, 1 h 50 min at two processes) and the Warden-charge diagnosis (read-only, opened at the wave's end).

### Gate

Candidate cand/alpha-w19. Gate 1 ran on e908ece (all units and the soak note): 423 runs, 8 at a time, 25 solo, 0 reds, 1869 s, 7 environment skips (music stems not packaged in the worktree, no audio headless); receipt artifacts/local/receipts/gate-fa2194465dd1-2026-10-06T04-13-38-669Z.json records head e908ece. No merge after the gate; the records commit is docs only. Gate read (e908ece): ADMIT, PASS+NOTES, level 2 by the reviewer's reads of the gate log, receipt, git captures, the soak note against its TSV and the export log (Opus 5.5, scrapkeep-reviewer-medium; fences clean, union equals the wave stat; no SCRIPT ERROR, ERROR or FAIL lines; the class_def hunk was confirmed comment-only by the coordinator). proto/alpha is fast-forwarded to the wave 19 records commit by the coordinator.

### Export

At e908ece: tarball scrapkeep-core-loop-e908ece.tar.gz 41.1 MiB, ACE_CHECK ready clips=8 streams=24, stems from the main checkout. Two win proofs on one pack: Rivet skipper seed 1 won at stage 6, 38208 ticks, 129.34 s wall (the gate ran alongside); remembered cannon skipper seed 11 won at stage 6, 34249 ticks, 149.19 s wall. Both tick counts equal wave 18. Copied to artifacts/local/alpha/export/e908ece/. Log artifacts/local/alpha/wave19/export1.log.

### Rulings (coordinator, 2026-10-06; recorded in docs/decisions.tsv at the wave 19 records commit)

- W19-R1 wave 19 opened: soak-w19 and tidy.
- W19-R2 tidy admitted; unlock-live opened (no faked bus events allowed).
- W19-R3 unlock-live admitted; verifier ran on Sonnet via the router after the workflow skipped it.
- W19-R4 soak read: four solo-reproduced stalls; Warden-charge diagnosis opened; repro is two-sample consistency, not determinism.
- W19-R5 Sol diagnosis: the three Warden stalls are confinement (cache pocket, western pit) with a charge routine that never times out; Sable 12 is separate; batch and solo traces identical, so load is cleared as a cause. Wave 20 unit charge-recover opened (driver only, baseline first).

### Open after wave 19: wave 20 concerns

1. Warden-charge stall (Kest 2, Kest 14, Tarn 15): unit charge-recover running on the four-recipe baseline (W19-R5). Sable's Brindle openings (skipper 12) are a separate contact problem; a diagnosis waits on Andrew's interest.
2. The Mind's lane family rarely fires against bots (5 of 43); Andrew to say whether the opening should hold longer (ram racks posture ruling stands).
3. roster_test R11 recomputes the natural width with a hardcoded six-card formula (0.7 px off); precondition only.
4. unlock_live skips Brindle phases 2-3 via the dev hook; a full-pacing variant would take about 85 s.
5. Carried: tree_bot_test watch, bot nondeterminism (W16-R8), Godot test run folders (1.8 GB), four old Codex job worktrees and the wave 7 Highdraft probe worktree.

### Hands checklist (never blocks; items 13-33 carry over)

34. Fight the Mind as any pilot and watch for the lane attack in the opening seconds: the bot almost never sees it. Say whether the opening should hold longer.

## Wave 18 landed (2026-10-06, a718fdb)

The wave 18 candidate cand/alpha-w18 landed as a718fdb (proto/alpha went ce300c7 to the wave 18 records commit; three units, 7 commits over base by `git rev-list --count ce300c7..a718fdb`). Two further units were retired on their baselines without a code change (brindle-cap, W18-R3) or closed by a Sol diagnosis that overturned the premise (Mind families, W18-R2). Branches are deleted. Coordinator commits on the candidate: 95d72d5 (run_log_boss_attacks_test hazard count pinned), the merges and the records commit.

**Milestone:** M4 (alpha) acceptance evidence: the exported build now proves a Rivet win and a remembered-cannon win on the same pack, the fresh-profile unlock sequence is pinned end to end, and the run record counts the Mind's attack commitments by family. Camp recreation (five stations, skee-ball, pet/toys, ghost/medals, enemy sandbox) is recorded as cut for the alpha (W18-R1).

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| mind-coverage | wt/alpha-w18-mind-coverage | 95d72d5 | sonnet (astack:hand) + coordinator test pin | PASS+NOTES | `boss_attacks` on the run record (one count per `_commit_attack`, split_lane counts once); run_log_boss_attacks_test 4 checks, two mutants red |
| unlock-seq | wt/alpha-w18-unlock-seq | bd1c21b | opus (astack:worker) | PASS+NOTES | profile_unlock_sequence_test 121 checks: fresh profile, Rivet starter, Tarn after Brindle, Kest after the Dig rescue, cannon after the Mind, Tally after the third leaf, save/reload each step; Mind-first mutant fails 12 of 44 |
| cannon-proof | wt/alpha-w18-cannon-proof | a04f317 | opus (astack:worker), coordinator-verified | coordinator-verified (W18-R4) | `--win-proof` plays seed 1 (Rivet) then seed 11 pinned to remembered_cannon on the same proof pack, either loss fails the export; sketch-export.test.mjs 27 pass |
| brindle-cap (retired) | none | ec61233 | opus (astack:worker) | FAIL on premise | Tally skipper seed 16 won stage 6 in all three pinned-code baselines; the w17 soak stall ran the same driver bytes at concurrency 3; no change (W18-R3) |
| Mind families (Sol, read-only) | none | ce300c7 | Codex Sol (gpt-6.1-sol high) | verdict d | the Mind fires all four families against bots; codex rows record only dodged attacks; wave 13 note corrected below |

Cause of each review red: brindle-cap, brief (a soak stall under load used as a driver-defect premise). The cannon-proof workflow lost both the writer's and the verifier's results (null); the coordinator verified it directly.

**Correction to the wave 13 record:** the line "Mind codex rows (lane, split_lane, rush) fired 0 times in the win proof; only forced tests prove them" read codex discoveries as attack counts. The codex detector records lane, split_lane and rush only when an aimed attack is dodged (mind.gd `_step_attacks`), so landed attacks never produced a row. In the wave 17 re-soak, 42 winners show family damage or codex rows for lane (6), split_lane (39), rush (38) and plate (42). From wave 18 the `boss_attacks` field shows commitments directly.

### Sol lane (Codex gpt-6.1-sol high)

One read-only diagnosis (Mind attack families, verdict d, no combat change). The lane was otherwise idle this wave; the two bot-driver diagnoses from wave 17 both failed their pinned baselines, so bot-driver work from soak data now needs a solo reproduction before a brief is written.

### Gate

Candidate cand/alpha-w18. Gate 1 ran on a718fdb (all three units): 422 runs, 8 at a time, 25 solo, 0 reds, 1817 s, 7 environment skips (music stems not packaged in the worktree, no audio headless); receipt artifacts/local/receipts/gate-8fca6401a1ad-2026-10-06T01-38-42-944Z.json records head a718fdb. No merge after the gate; the records commit is docs only. Gate read (a718fdb): ADMIT, PASS+NOTES, level 2 by the reviewer's reads of the gate log, receipt and git captures (Opus 5.5, scrapkeep-reviewer-medium; fences clean, union equals the wave stat; no SCRIPT ERROR, ERROR or FAIL lines; no test pins the run record's key set; the second proof reuses the pack with its own state folder). proto/alpha is fast-forwarded to the wave 18 records commit by the coordinator.

### Export

At a718fdb: tarball scrapkeep-core-loop-a718fdb.tar.gz 41.1 MiB, ACE_CHECK ready clips=8 streams=24, stems from the main checkout. Two win proofs on one proof pack: Rivet skipper seed 1 won at stage 6, 38208 ticks (same as waves 16 and 17), 99.87 s wall; remembered cannon skipper seed 11 won at stage 6, 34249 ticks, 117.14 s wall. Copied to artifacts/local/alpha/export/a718fdb/. Log artifacts/local/alpha/wave18/export1.log.

### Rulings (coordinator, 2026-10-06; recorded in docs/decisions.tsv at the wave 18 records commit)

- W18-R1 camp recreation stays cut for the alpha; ROADMAP row says optional; captures/frame times and the cold launch parked to hands.
- W18-R2 Mind families: verdict d, no combat change; wave 13 line corrected; mind-coverage evidence unit.
- W18-R3 brindle-cap retired on its baseline; load-dependent soak stalls are classed env.
- W18-R4 cannon-proof coordinator-verified after the workflow lost its reports.

### Open after wave 18: wave 19 concerns

1. Soak runner: record load and concurrency per run; a stall that does not reproduce solo is classed env in the soak note.
2. unlock-seq drives the bus from class select; the in-run emit sites (Brindle enemy_killed then boss_defeated order) are unproven by it.
3. class_def.gd comment "Sable is the only starter" contradicts Rivet starter:true; fix the comment.
4. `boss_attacks` counts come back from JSON as floats; soak readers compare as ints.
5. Carried: tree_bot_test watch, narrow-card roster check, bot nondeterminism (W16-R8), 1.8 GB of Godot test run folders, four old Codex job worktrees and the wave 7 Highdraft probe worktree.

### Hands checklist (never blocks; items 13-30 carry over)

31. Fresh profile: start a new save and confirm only Sable and Rivet are selectable, then beat Brindle and see Tarn open.
32. Play the exported build as the remembered cannon after a Mind kill: the export now proves that run wins for the bot; see whether the lane and split lane read at human speed.
33. (Replaces 30) Fight Brindle as Tally: the bot's stall did not reproduce solo, so this is a feel check, not a bug hunt.

## Wave 17 landed (2026-10-06, 86dbf59)

The wave 17 candidate cand/alpha-w17 landed as 86dbf59 (proto/alpha went ec61233 to the wave 17 records commit; four units plus the re-soak note, 11 commits over base by `git rev-list --count ec61233..86dbf59`). Before the wave, the coordinator wrote the canonical M4 program record on proto/alpha (ec61233: TRACKING EV-0625 for waves 1-16, ROADMAP current state; W17-R1). Branches are deleted. Coordinator commits on the candidate: af35a2a (tally_look preview check tightened, class_preview header), 3179330 and 5ceb86b (Sol lanes committed), the merges and the records commit.

**Milestone:** M4 (alpha) follow-through: the wave 16 concerns (preview missing-glb test, CARD_MAX literal, Tally's preview move, portraits for Tarn, Tally and the cannon), the re-soak that confirms the Sable climb fix, and two Sol stall diagnoses (one rejected unit, one carried to wave 18).

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| preview-glb | wt/alpha-w17-preview-glb | ef09360 | sonnet (astack:hand) | PASS+NOTES | hero_assets_missing_glb_test covers a missing pilot glb in the preview: placeholder stays, no AnimatedPilot, one warning |
| card-max | wt/alpha-w17-card-max | d2b1294 | sonnet (astack:hand) | PASS+NOTES | roster_test reads Screens.CARD_MAX; verifier notes the narrow-card check cannot fail at the test's screen sizes |
| tally-pose | wt/alpha-w17-tally-pose | af35a2a | opus (astack:worker) + coordinator test tightening | PASS+NOTES | Tally's preview move: three ledger plates in a climbing stair, flywheel spin-up, stamp slam; tally_look_test 73 |
| portraits | wt/alpha-w17-portraits | 3179330 | Codex Sol (gpt-6.1-sol high), coordinator commit | coordinator-verified (54-check test, icons-diff 0) | cls_tarn, cls_tally, cls_cannon; Icons.class_icon_id; class_card uses the SVG with the shape fallback kept |
| soak (re-soak) | wt/alpha-w17-soak | 5ceb86b | Codex Sol (gpt-6.1-sol high), coordinator commit | n/a (evidence) | 72 runs on 4f267f3: 42 wins, 30 stalls (24 camper by design), 0 crashes, 0 wall caps, 0 script errors; Sable stage 6 cluster gone |
| burst-align (rejected) | scratch/alpha-w17-burst-align-rejected | 7f03369 | opus (astack:worker) | FAIL x2, fixer BLOCKED | aim guard on Shift for aim-directed pilots: premise did not reproduce with pinned pilots, guarded Kest 20 still stalled, posture bands fell outside tolerance (66.2/32.1 vs 78.4/37.9); not merged (W17-R4) |

Cause of each review red: burst-align, brief (seed-mapped soak runs do not transfer to pinned pilots) plus diagnosis inference.

### Sol lane (Codex gpt-6.1-sol high)

Five lanes: the re-soak (writer), portraits (writer), and three read-only diagnoses: the Rivet 1 / Tarn 15 / Kest 20 Warden-charge stalls (mixed verdict; led to the rejected burst-align), the Tally skipper seed 16 Brindle phase 2 stall (driver: posture branch bypasses the vent-cap routine; became wave 18 unit brindle-cap), and, in wave 16, the Sable climb. Diagnoses that rest on seed-mapped soak runs now require a pinned-pilot baseline before any edit (lesson from burst-align).

### Gate story

Candidate cand/alpha-w17. Gate 1 ran on 761cc6d (four units): 420 runs, 8 at a time, 25 solo, 0 reds, 1947 s, while the Sol re-soak held three processes; receipt artifacts/local/receipts/gate-ed9094d45f5d-2026-10-06T00-38-26-962Z.json records head 761cc6d. After the gate one merge (86dbf59) added only design-v3/soak-2026-10-05-w17.md; no second full gate. Candidate check cand1.log: eleven targeted tests, icons-diff 0, lint 0. Gate read (86dbf59): ADMIT, PASS+NOTES, level 2 by the reviewer's own reads of the gate log, receipt and git captures (Opus 5.5, scrapkeep-reviewer-medium; file-level fences clean; no SCRIPT ERROR or ERROR lines; tree_bot_test passed once, keep watching). proto/alpha is fast-forwarded to the wave 17 records commit by the coordinator.

### Export

At 86dbf59: tarball scrapkeep-core-loop-86dbf59.tar.gz 41.1 MiB, ACE_CHECK ready clips=8 streams=24, stems from the main checkout. Win proof won at stage 6, 38208 ticks (same as wave 16), 110.76 s wall, skipper seed 1. Copied to artifacts/local/alpha/export/86dbf59/. Log artifacts/local/alpha/wave17/export1.log.

### Rulings (coordinator, 2026-10-06; recorded in docs/decisions.tsv at the wave 17 records commit)

- W17-R1 canonical M4 record on proto/alpha; no BACKLOG card for the alpha program (light play lane).
- W17-R2 Sol diagnosis of the three Warden-charge stalls opened burst-align (tool-only).
- W17-R3 wave 17 Claude units and Sol lanes as listed.
- W17-R4 burst-align rejected; head kept on scratch/alpha-w17-burst-align-rejected; the re-soak decides whether those stalls recur (they did not: Rivet 1 and Kest 20 won).
- W17-R5 re-soak read: Sable fix confirmed in bot play; remaining non-camper stalls are singletons except Tally skipper seed 16.
- W17-R6 Tally Brindle diagnosis opened brindle-cap as the first wave 18 unit, baseline before edit mandatory.

### Open after wave 17: wave 18 concerns

1. brindle-cap (running): low-punch Brindle phase 2 routes to the vent cap for posture hulls.
2. Rivet seed 1's relic-cache wedge (Sol: inside the Highdraft Crown cache pocket) did not recur in the re-soak; keep as a watch item, no unit.
3. tree_bot_test flaked once on the rejected head (Kest seed 2 died at 44.5 s); watch on the next gates.
4. The narrow-card roster check cannot fail at the test's screen sizes (card-max note): add a wide-screen case or drop the check.
5. Bot run nondeterminism (W16-R8) stands; the re-soak could not isolate the Sable fix from the other wave 16 code.
6. Hands items 23-27 from wave 16 and 28-30 below remain unplayed.
7. Housekeeping: ~/.local/share/godot/app_userdata/core-loop test run folders (1.8 GB).

### Hands checklist (never blocks; items 13-27 carry over)

28. Class select: Tarn, Tally and the cannon show their own portraits (crossed claws, clipped ledger with the stair stamp, barrel with the split lane) at the card's icon size.
29. Open Tally's card: the preview lays three plates in a stair, hops them, spins up and stamps.
30. Fight Brindle as Tally once the wave 18 fix lands: the bot's stall was on the Furnace phase vent cap; see whether a human finds the cap reachable.

## Wave 16 landed (2026-10-05, f7f0098)

The wave 16 candidate cand/alpha-w16 landed as f7f0098 (proto/alpha went 91e36c6 to f7f0098; eight units plus a soak note, 21 commits over base by `git rev-list --count 91e36c6..f7f0098`). Heads are the unit heads in git; verdicts are the verifiers' and the coordinator's, 2026-10-05. Branches are deleted. Coordinator commits on the candidate: cedd6b2 (harpoon test helpers, W16-R1), b5d49d5 (kick rows, icons README), 6deebef (preview test tightening), c0d6b5a (empty --pilot), the merges, and the records commit. Codex Sol (gpt-6.1-sol high) wrote tally-look, cannon-look, the soak and two read-only reviews; the coordinator committed its files.

**Milestone:** M4 (alpha) follow-through: the wave 15 concerns list (camera kick leak, band coverage, test gaps), Tally's and the cannon's own look and sound, the six-pilot soak and its first stall fix, and the preview-pilot regression Sol found.

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| test-gaps-w15 | wt/alpha-w16-test-gaps-w15 | dbc4e4c | sonnet (astack:hand) | PASS+NOTES (W16-R4) | tally echo test; _exposed/_clamped clears; stale comments; _check_rows split into _row_measures |
| aim-rest (W16-1) | wt/alpha-w16-aim-rest | cedd6b2 | opus (astack:worker) + coordinator fix | FAIL (harpoon_line 4, harpoon_canon 62 red: test helpers posed the lens only), then admitted under W16-R1/R2/R3 | shots aim from chase_camera.aim_origin() (the lens rest); kick and shake no longer reach the simulation; camera_aim_rest_test 23 |
| tally-look | wt/alpha-w16-tally-look | 9339e9b | Codex Sol (gpt-6.1-sol high), coordinator commit | PASS | motif D4 E4 F4 G4 D5, release/ready/break, seven icons, square shape, Ledger Cream reads +0.094 luminance over TALLY_COLOR; tally_look_test 61 |
| cannon-look | wt/alpha-w16-cannon-look | ebb6608 | Codex Sol (gpt-6.1-sol high), coordinator commit | PASS | motif B E G D (Mind quote, four notes), lane shape, Old Verdigris; cannon_look_test 92 |
| band-pilot-pins (W16-2) | wt/alpha-w16-band-pilot-pins | c0d6b5a | opus (astack:worker) + coordinator fix | PASS+NOTES (W16-R8) | band tests name the pilot per seed; bot_run --pilot; mutants 1-3 red; w23 table re-recorded with Sable and the cannon rows; empty --pilot= rejected (c0d6b5a) |
| preview-pilot (W16-R5) | wt/alpha-w16-preview-pilot | 6deebef | opus (astack:worker) + coordinator test tightening | PASS+NOTES | HeroAssets.fit_pilot_into shared by gameplay and ClassPreview; Tally shows Rivet, the cannon shows Kest; class_preview_pilot_test 27 |
| sable-climb (W16-R7) | wt/alpha-w16-sable-climb | 1ff6714 | opus (astack:worker) | FAIL (seed 24 still stalled: stale plant face), then PASS+NOTES after round 2 | engineer plant yields to the fight climb and drops its seek to idle; seeds 6/12/18/24 win stage 6, controls 3/5 win; bot_plant_climb_test 6 |
| soak-six | wt/alpha-w16-soak-six | d300eca | Codex Sol (gpt-6.1-sol high), coordinator commit | n/a (evidence) | 72 runs on 91e36c6: 39 wins, 32 stalls, 1 wall cap, 0 crashes, 0 script errors; design-v3/soak-2026-10-05-six.md; evidence under artifacts/local/alpha/soak/2026-10-05-six |

Cause of each review red: aim-rest, brief (AS BUILT said the harpoon tests were unaffected by D3); sable-climb round 1, writer (guard left a stale plant face steering); Sol look review FAIL (preview pilot), pre-existing design gap exposed by the new shell/pilot pairings, counted as writer for tally-look/cannon-look's missing preview assertion.

### Sol lane (Codex gpt-6.1-sol high, headless `codex exec`)

Four lanes ran beside the Claude units: tally-look and cannon-look (writers), a read-only cross-unit look review over 91e36c6..ebb6608 (FAIL: the preview-pilot finding above, the icons README count, and an audio_board sandbox write denial read as env), and the six-pilot soak. A fifth read-only lane diagnosed the soak's Sable stage 6 cluster (hypothesis a, bot driver; the plant routine overrode the climb steer) and proposed the guard the sable-climb unit shipped. Sol's reviews cite path:line and were checked by the coordinator before acting.

### Gate story

Candidate cand/alpha-w16. Gate 1 ran on f52fb01 (every unit merged): 419 runs, 8 at a time, 25 solo, 0 reds, 7 skips (ACE package absent in the worktree, headless audio), 1818 s; receipt artifacts/local/receipts/gate-db1a3a12a4d8-2026-10-05T23-03-12-264Z.json records head f52fb01, tree db1a3a12. After the gate one merge (f7f0098) added only design-v3/soak-2026-10-05-six.md, so there is no second full gate. The pre-merge candidate check (cand1.log, b5d49d5) ran 19 targeted tests, icons-diff 0 and lint 0. Gate logs under artifacts/local/alpha/wave16/. Gate read (f7f0098): ADMIT, PASS+NOTES, level 4 (Opus 5.5, scrapkeep-reviewer-medium; file-level fence check clean across all 54 changed files, line-level fences not checked; no SCRIPT ERROR or ERROR lines in the gate log). proto/alpha is fast-forwarded to the wave 16 records commit by the coordinator.

### Export

At f7f0098: tarball scrapkeep-core-loop-f7f0098.tar.gz 41.1 MiB, pack 78.6 MiB embedded, ACE_CHECK ready clips=8 streams=24, stems from the main checkout. Win proof won at stage 6, 38208 ticks, 102.11 s wall, skipper seed 1 (wave 15 was 34170 ticks; aim-rest moved the shots). Copied to artifacts/local/alpha/export/f7f0098/. Log artifacts/local/alpha/wave16/export1.log.

### Rulings (coordinator, 2026-10-05; recorded in docs/decisions.tsv at the wave 16 records commit)

- W16-R1 aim-rest: test-only fence extension; the three harpoon test _cam helpers pose the mount (lens rest), hold the SpringArm3D and reset the lens.
- W16-R2 aim-rest a2: shake-only picture check accepted; kick scaling is covered by presentation_comfort_test.
- W16-R3 posture_bands small/grown ratio 2.07 against a floor of 2.0 accepted after the aim change moved the grown median 14.5 percent.
- W16-R4 test-gaps: _check_rows split into _row_measures accepted; the 420.0 literal (screens.gd CARD_MAX) stays a follow-up.
- W16-R5 Sol look review FAIL opened the preview-pilot unit inside wave 16 instead of holding the look units.
- W16-R6 soak: camper 0/24 at stage 1 is the policy holding position, not a defect; the Sable stage 6 cluster went to a Sol diagnosis and then a unit; Kest seed 14 wall cap, Tally seed 16 Brindle phase 2 stall and the drill_crew 'adds' classifier warning are wave 17 follow-ups.
- W16-R7 sable-climb is a tool-only fix; game sources, posture numbers and "Keep ram racks posture" untouched.
- W16-R8 band-pilot-pins notes: bot runs are not fully deterministic (world 2 seed 7 Tarn gave three stage-time sets across three runs); the posture_sweep.md seed 7 row is one sample.
- Kick rows for Tally's cards and cannon_lane were added by the coordinator (b5d49d5) once aim-rest made a kick unable to move a shot.

### Open after wave 16: wave 17 concerns

1. Canonical M4 record (ALPHA-PLAN, BACKLOG, TRACKING, ADR) still reads wave 13 state; the HANDOFF holds waves 14-16.
2. screens.gd CARD_MAX 420.0 literal in test-gaps (W16-R4).
3. Soak follow-ups: the Warden charge stall is not Sable-only (Rivet seed 1 stage 6, Tarn seed 15 stage 6 climb, Kest seed 20 stage 5 climb; the sable-climb guard is gated on _engineer() and cannot touch them); Kest completionist seed 14 wall cap at stage 6 "two-hook second"; Tally skipper seed 16 Brindle phase 2 stall; combat.gd:686 drill_crew counted under 'adds' 4918 times in 72 runs.
4. Bot run nondeterminism (W16-R8): stage 5 w23 has two of six runs just over the 128 s band top (median 109); if the band trips, widen or re-record rather than retune.
5. Preview path has no missing-pilot-glb test; the preview seats bones at rest where gameplay also resets reactions.
6. Only Sable, Rivet and Kest have generated cls_* portraits; Tarn, Tally and the cannon use the procedural class-row shape (Sol look review).
7. Tally has no signature-move arm in ClassPreview._pose() (carried forward).
8. Re-soak on the wave 16 head to measure the sable-climb effect across all policies; the 54 percent win rate above is on 91e36c6.
9. Housekeeping: ~/.local/share/godot/app_userdata/core-loop holds about 220 pid-suffixed test run folders, 1.8 GB.

### Hands checklist (never blocks; items 13-22 carry over from wave 15)

23. Pick Tally and the cannon on class select: the preview seat shows Rivet's and Kest's pilots, not Sable's.
24. Fire any pilot's shot while the camera shakes: the shot lands where the reticle rests, not where the shake put the lens.
25. Hear Tally's climbing cards cash out and the cannon's B E G D chime; judge whether Tally still confuses with Sable.
26. Eye Ledger Cream against Tally's accent (it is a lighter cream, separation by value only).
27. Play Sable completionist-style to the stage 6 Warden shelf: the climb should hold without plant detours.

## Wave 15 landed (2026-10-05, cfb0a51)

The wave 15 candidate cand/alpha-w15 landed as cfb0a51 (proto/alpha went 6fb7366 to cfb0a51; eleven units, 37 commits over base by `git rev-list --count 6fb7366..cfb0a51`). Heads below are the unit heads in git; verdicts are the verifiers' and the coordinator's, 2026-10-05. Branches are deleted. Coordinator commits on the candidate: 28faf37, 7251802, 8c4cfcc, 4eaef7c, cfb0a51; f625173 was written by the tally-kit worker under rulings R1-R5; e24042f (tree_bot header) is a coordinator commit on the wave 15 base.

**Milestone:** M4 (alpha) work: the Tarn chain (kit, tree, verify, look), Tally kit and tree, the remembered cannon kit and tree, six pilots on class select, the slice sweep seeds and the wave 14 follow-ups.

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| w14-followups | wt/alpha-w15-w14-followups | 8f4341e | sonnet (pstack-hand) | PASS | title-row check reads real button rects; _primed/_prow_until pruned on death; cold-launch page on b9f9712 with Camp; OUTSIDE_RUN comment |
| tarn-kit (pil-G1, held from wave 14) | wt/alpha-w14-tarn-kit | c14b7a5 | opus (pstack-worker) | PASS (round 2) | claw 32 dmg, no plating claim; 'claw clamp' label; _clamped erased on death |
| tarn-tree (pil-G2) | wt/alpha-w14-tarn-tree | 3f05e7f | opus (pstack-worker) | PASS | 30 nodes, 6 relics, tree_bot seed 3 |
| tarn-verify (pil-G4) | wt/alpha-w14-tarn-verify | ae40c9f | opus (pstack-worker) | FAIL (two-fact liveness vacuous), then PASS after refinement | dead-offer and fourth-pilot proofs; kit-agnostic proc exemption pinned narrow |
| tarn-look (pil-G3) | wt/alpha-w15-tarn-look | 9e1b5e6 | opus (pstack-worker) | PASS+NOTES | own motif, sound and icons; exposed a pre-existing camera-kick-to-sim leak (juice.gd claw_sweep row) |
| slice-sweep-seeds | wt/alpha-w15-slice-sweep-seeds | 6e686b0 | sonnet | verifier re-verify lost to API 529; coordinator reran: posture_bands_test PASS (9), unit_suite PASS | sweep plays seeds 0, 1, 2 (Sable, Rivet, Kest at any roster size); medians re-recorded small 80.6 / grown 33.1 |
| tally-kit (pil-G7) | wt/alpha-w15-tally-kit | b443cc1 | opus (pstack-worker) | FAIL (no starter paint; Shift burst), then PASS (round 2 under R1-R5) | Ledger Cream paint; Harpoon.burst_ready answers every pilot burst; expired plate spends nothing |
| tally-tree (pil-G8) | wt/alpha-w15-tally-tree | 28faf37 | opus (pstack-worker) + coordinator fix | FAIL (tree_apply plain-slot cap vs pressure), then admitted with coordinator fix 28faf37 | _is_plain reads the row's pressure; _tick_echo re-checks can() |
| cannon-kit (pil-G10) | wt/alpha-w15-cannon-kit | 7251802 | opus (pstack-worker) + coordinator fix | FAIL (no starter paint), then admitted with coordinator fix 7251802 | Old Verdigris paint; PENDING_PILOTS []; LANE_DAMAGE 38 to 30; exposure scales dealt |
| cannon-tree (pil-G11) | wt/alpha-w15-cannon-tree | d698536 | opus (pstack-worker) | PASS | brief re-authored against the shipped kit; 30 nodes, rate-only pattern rows, tree_bot seed 5 |
| roster (pil-G12) | wt/alpha-w15-roster | 8c4cfcc | opus (pstack-worker) + coordinator fix | FAIL x2 (six cards overflow, brief D4 math wrong; then R-A premise wrong), then admitted with coordinator fix 8c4cfcc | six cards in one row; _fit_cells, role tag wraps, preview gives up overflow; MIN_ICON_SIDE 28 |

Cause of each review red: tarn-kit round 1, brief (full-landing claim unreachable); tally-kit round 1, brief (cosmetics read-only, Shift burst unaddressed); tally-tree, brief (tree_apply read-only); cannon-kit, brief (cosmetics read-only); roster round 1, brief (D4 keycap arithmetic); roster round 2, owner (R-A premise); tarn-verify, writer (vacuous liveness check).

### Gate story

Candidate cand/alpha-w15. Gate 1 ran on 4eaef7c: 414 runs, 3 reds. audio_board_test was real (the RELEASE table lacked tarn); fixed in cfb0a51, cause brief (the tarn-look fence omitted tools/audio_board.gd). presentation_chain 'chain sings' and find_in_fight 'seen only now' were read as load flakes (8 of 8 green in an 8-way stress, 3 of 3 solo in the gate read; find_in_fight flaked once in wave 6; the kill streak uses wall-clock ms). No second full gate. Gate logs under artifacts/local/alpha/wave15/. Gate read (cfb0a51): ADMIT, PASS+NOTES, level 4. proto/alpha is fast-forwarded to cfb0a51 by the coordinator.

### Export

At cfb0a51: tarball 41.1 MiB, ACE_CHECK ready clips=8 streams=24. Win proof won at stage 6, 34170 ticks, 95.21 s wall. Copied to artifacts/local/alpha/export/cfb0a51/.

### Rulings (coordinator, 2026-10-05; recorded in docs/decisions.tsv at the wave 15 records commit)

- tally-kit R1: fence widens to cosmetics.gd and content_registry.gd; Tally gets its own starter paint, 'Ledger Cream'; cosmetics.ROWS golden re-pinned.
- tally-kit R2: fence widens to harpoon.gd; Harpoon.burst_ready answers every pilot burst, so Shift and B fire Tarn's claw pull and Tally's flywheel surge; a keyboard-path check is added.
- tally-kit R3: deviations kept (check 10i smash landing; plate_return adds the enemy hull; Gather plants at _floor_at(point + UP)).
- tally-kit R4: the plate_return can guard re-checks the live plate at gauge release; an expired plate spends nothing.
- tally-kit R5: posture_bands_test belongs to the slice sweep unit; report its line, do not count it against tally-kit.
- roster R-A: the preview column gives up the row's largest overflow, one uniform value per row, floor 160 px. Amended after fix round 2: the shrink applies at every card count, because the base already overflowed at four cards (key cells to y 822 against a card bottom of 807; preview 260 to 227).
- roster R-B: D4 amended; at five or more cards keycaps scale down evenly (_fit_cells, 5 percent steps), the role tag wraps at the card's inner width, icons never below 28 px.
- roster R-C: class_card.gd is owned whole for this unit.
- roster R-D: no 1 px tolerance on the name check.
- roster R-E: red WIP commit 4940c48 may stay under a green commit; no squash.
- roster R-F: w23 band seeds stay [1,2,3,4]; the cannon's band gap is recorded here, not fixed.
- cannon-kit edited harpoon.gd (burst_ready plus RECOIL) outside its fence; accepted as an extension of R2.
- audio_board one-line fix (RELEASE tarn line, cfb0a51); the two load flakes are read as flakes and there is no second full gate.
- Coordinator fixes: tally-tree 28faf37 (_is_plain reads pressure; _tick_echo re-checks can()), cannon starter paint Old Verdigris 7251802, roster 8c4cfcc (floor(room) off-by-one, MIN_ICON_SIDE 28 floor, honest comments).

### Open after wave 15: wave 16 concerns

1. The camera kick reaches the simulation, against the event_kinds JUICE "camera and shell only" promise: juice.gd:554 kick, chase_camera.gd:239, aim_origin :170, context.gd:72, combat.gd:1029 Hitscan.aim. Shake jitter and the comfort "shake" setting move hits too. Affects every pilot with a kick row. Also decide, with it, the missing shot_fired kick rows for ledger_reader and cannon_lane.
2. Band coverage: no band seed plays the cannon (w23 SEEDS [1,2,3,4]); record new medians with seed 5 as its own unit. Since Tally joined, bot seed 4 plays Tally (seed % 6), so alpha_posture_bands_w23_test [1,2,3,4] plays Rivet, Kest, Tarn and Tally and Sable has no w23 band run.
3. Roster: no test asserts the key rows' bottom edge or the preview floor directly; the first class-select frame draws unshrunk cards for one process_frame (the slide-in likely hides it; needs a human eye).
4. Tally's Ledger Cream tint equals TALLY_COLOR and may read as no paint.
5. The tally plate_return echo gap is fixed by the can() re-check and needs a test.
6. Cannon _exposed is never pruned on stage entry.
7. tarn-kit _clamped is re-added when the clamp itself kills.
8. The icons README header flips on regeneration (79 vs 83 ids).
9. The _burst_pilot comment at player_ball.gd:483 names three bursts; the code covers five.

README.md:25 "cannon not in this alpha" was concern 8 in the packet; the roster unit resolved it.

Cost: brief workflow 8 agents, 1.48M tokens, 21 min; w14-followups 2 agents, 0.17M; Tarn chain 6 agents, 0.59M, 87 min; chain A (look, sweep) 12 agents, 1.44M, 144 min; chain B (tally) 6 agents, 0.71M, 88 min; cannon kit 4 agents, 0.58M, 75 min; cannon tree and roster 6 agents, 0.67M, 71 min; roster fix round 2: 2 agents, 0.23M, 37 min; brief re-authors 2 agents, about 0.37M.

### Hands checklist (never blocks; items 13-16 carry over from wave 14)

13. Open the Camp (K on title) and the Companion panel.
14. Look at the title row with a saved run, companion piece and Breath (two rows).
15. Read the Tally spec veto list in DESIGN-V3.
16. Try the Mind's plate attack.
17. Pick Tarn, Tally and the cannon on class select: six cards in one row; check the key rows and that the 28 px Kest icons read.
18. Play Tarn's claw pull, clamp ring and rend slam.
19. Run Tally's three cards and roll to refill pressure.
20. Fire the cannon's lanes and watch the Mind brace.
21. Hear Tarn's new motif and sound.
22. Eye the Redjaw Ash, Ledger Cream and Old Verdigris paints.

## Wave 14 landed (2026-10-05, b9f9712)

The wave 14 candidate cand/alpha-w14 landed as b9f9712 (proto/alpha went 53dc109 to b9f9712; sixteen units, 28 commits over base). Heads below are the unit heads in git; verdicts are the verifiers' and the coordinator's, 2026-10-05. tarn-kit was held out after the gate; the candidate was reset to b9f9712 without it.

**Milestone:** M4 (alpha) work: second and third companion families and the Companion panel, camp menu, cannon unlock, Tally ledger row, paint cosmetics, achievements, Mind plate reachable, nightly export, cold-launch steps and the wave 13 follow-ups.

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| tarn-kit (pil-G1) | wt/alpha-w14-tarn-kit | c14b7a5 | opus (pstack-worker) | PASS after one ruling fix round, but HELD OUT: breaks posture_bands_test (slice sweep seed 3 plays Tarn) | lands in wave 15 with tarn-tree and tarn-verify once the bands are tuned or re-recorded |
| cannon-unlock (pil-G9) | wt/alpha-w14-cannon-unlock | 6599335 | opus (pstack-worker) | PASS | PENDING_PILOTS allowance; no class row |
| tally-ledger-row (pil-G6) | wt/alpha-w14-tally-ledger-row | 405fa8c | opus (pstack-worker) | PASS | boss win settles ledger.found.N; world_fact 'ledger_returned' fires on the Moss hand-in (progress.gd return_leaves) |
| cosmetics-paint (prog-G2) | wt/alpha-w14-cosmetics-paint | dd359b6 | opus (pstack-worker) | PASS | paint tints only |
| achievements-fill (prog-G3 + C9) | wt/alpha-w14-achievements-fill | 4acec09 | opus (pstack-worker) | PASS | 16 achievements, 16 cosmetics |
| progression-asserts (prog-G10) | wt/alpha-w14-progression-asserts | e6b3882 | sonnet (pstack-hand) | PASS | |
| companion-second-family (C2) | wt/alpha-w14-companion-second-family | 738ab43 | opus (pstack-worker) | PASS | conductive primer |
| companion-third-family (C3) | wt/alpha-w14-companion-third-family | 1226739 | opus (pstack-worker) | PASS | ram brace prow/spring |
| companion-panel (C6) | wt/alpha-w14-companion-panel | a073f7e | opus (pstack-worker) | PASS | |
| camp-menu (C7) | wt/alpha-w14-camp-menu | 90db5ce | opus (pstack-worker) | FAIL x2 (title row overflow, Camp dropped), then PASS after the wrap ruling | ui_companion_panel_test row check now passes by construction (wave 15 follow-up) |
| tally-spec (pil-G5) | wt/alpha-w14-tally-spec | 8897154 | opus (pstack-worker) | PASS | design doc; veto list in DESIGN-V3 |
| mind-plate-reachable (prog-G1) | wt/alpha-w14-mind-plate-reachable | 1b0ad90 | opus (pstack-worker) | PASS | Mind plate commits in the real fight; bands held |
| nightly-export (P6) | wt/alpha-w14-nightly-export | 7ab11a2 | sonnet (pstack-hand) | PASS | |
| cold-launch-steps (P10) | wt/alpha-w14-cold-launch-steps | 3772620 | sonnet (pstack-hand) | PASS | SITTING.md numbered page |
| w13-followups | wt/alpha-w14-w13-followups | 9bcf181 | sonnet (pstack-hand) | FAIL (skipped base-coverage check), then PASS on the same head | WAKING/MIND pins, field_notes line, sound_ready guard, export proof-before-tarball |
| tarn-tree (pil-G2) | none | none | none | not delivered: brief author returned a summary | moves to wave 15 with tarn-verify and pil-G3 |

tarn-verify (pil-G4) never started; wave 15.

### Gate story

Candidate cand/alpha-w14. Gate 1 ran on 5d25460 (b9f9712 plus the tarn-kit merge): 410 runs, 1 red (posture_bands_test, the slice-table sweep: small 58.3 s vs recorded 82.4, grown 33.1 s vs 39.2). Bisect: FAIL on the tarn-kit worktree alone, PASS on the companion chain. Ruling: tarn-kit held out of wave 14 (lands in wave 15 with the Tarn tree and tuning); candidate reset to b9f9712; posture_bands_test, unit_suite (634), char_kits, attack_rows, ui_class_card, companion_ram and lint rerun green on b9f9712. Cause of the red: brief (tarn-kit's ACCEPTANCE named the alpha bands but not the slice sweep). Gate log: artifacts/local/alpha/wave14/gate1.log. Opus gate read (b9f9712): ADMIT (PASS+NOTES, level 4). proto/alpha fast-forwarded to b9f9712.

### Export

At b9f9712: tarball 41.0 MiB, ACE_CHECK ready clips=8 streams=24. Win proof won at stage 6, 34170 ticks, 87.48 s wall. Copied to artifacts/local/alpha/export/b9f9712/.

### Rulings (coordinator, 2026-10-05; recorded in docs/decisions.tsv at the wave 14 records commit)

- Tarn's claw sweep stays at 32 damage; the "lands in full on world-one plating" claim is dropped (stage-1 plating is 90, so it chips like a gun); test 8d becomes "highest per-hit weapon"; Tarn plating tuning belongs to the Tarn verification unit; card label "claw clamp" accepted.
- A crowded title row never drops a button; it wraps onto a second centred row at 22 px font. Camp sits after Companion on title and summary; the Companion button closes the camp first, then opens the panel.
- Leaf source for Tally's ledger: a world's leaf is found when its boss is beaten (world_fact 'ledger_balanced'), no pickup, no new bus row; hand-in in Moss's shop. Tally ships three fixed starting cards; finds and swapping deferred.
- Beating the Mind records remembered_cannon in the profile through Achievements.PENDING_PILOTS; no cannon class card until wave 15 (pil-G10).
- Cosmetics are paint tints on existing models; Tarn's starter paint is "Redjaw Ash" (tiger, Redjaw Workshops), not badger.
- The Tarn tree and Tarn verification move to wave 15 with the Tarn look; the wave 14 gate runs once on seventeen units.
- tarn-kit held out of wave 14 after the posture_bands_test red; the Tarn chain (kit, tree, verify with tuning) lands together in wave 15.

### Wave 15 queue

Tarn chain (kit c14b7a5 held, tree, verify), Tally kit/tree (pil-G7, G8), cannon kit/tree (pil-G10, G11), roster pil-G12, Tarn look pil-G3 (Sol models), plus the concern list below.

### Open after wave 14: wave 15 concerns (Opus gate read)

1. The Tarn chain must pass posture_bands_test (add to briefs).
2. _clamped stale entry when the clamp kills (combat.gd ~1157: write before _hit or skip when dead); no test for the death-time erase.
3. Re-resolve tarn-kit's combat.gd conflict with C2/C3 on the new base and re-pin IMPACT.
4. Tarn species badger->tiger lands with tarn-kit; check the 'Redjaw Ash' copy.
5. ui_companion_panel_test.gd:76-78 row check passes by construction (point it at button rects).
6. Summary/dead/victory rows share the wrapping container; visual check.
7. Cold-launch page: tarball path is inside the proto/alpha worktree; step 5 button list predates Camp.
8. Stale OUTSIDE_RUN comment in workshop.gd.
9. Optional prune of _primed and _prow_until.
10. Remove remembered_cannon and tally from PENDING_PILOTS when pil-G10 and pil-G7 add ClassDef rows.

Cost: wave workflow 36 agents, 3.36M subagent tokens, 101 min wall; round 2 workflow 8 agents, 0.59M tokens, 17 min; brief workflow 18 agents, 2.70M tokens, 18 min.

### Hands checklist additions (never blocks; Tarn items move to wave 15)

13. Open the Camp (K on title) and the Companion panel.
14. Look at the title row with a saved run, companion piece and Breath (two rows).
15. Read the Tally spec veto list in DESIGN-V3.md.
16. Try the Mind's plate attack.
17. Look at the death screen and the run summary with a companion piece owned (and Replay on the death screen after an arena death): each action row wraps onto a second centred row when crowded, and no button overlaps the stats or the title or runs off screen. The victory screen shows no buttons.

## Wave 13 landed (2026-10-05, 01aa202)

The wave 13 candidate cand/alpha-w13 landed as 01aa202 (proto/alpha went a1593a3 to 01aa202; 21 commits over base: b6232f3 plus the coherence-test fix). Heads below are the unit heads in git; verdicts are the verifiers' and the coordinator's, 2026-10-05. ending-copy 2066e13 was committed directly onto the candidate (parent 3730d73); its branch points at the same commit.

**Milestone:** M4 (alpha) work: ending screen and copy, title and summary music, companion drops and cues, help page, README and the first packaged export with a win proof.

| unit | branch | head | writer | verdict | note |
|---|---|---|---|---|---|
| boss-codex-rows | wt/alpha-w13-boss-codex-rows | c83558b | opus (pstack-worker) | PASS, level 3 | mind_plate force-only (BLOCKED, ruling: defer to wave 14); waking final-floor row ships as a plain kill row |
| ending-screen | wt/alpha-w13-ending-screen | e22053e | opus (pstack-worker) | PASS with notes, level 4 | verifier ran the brief's own mutant, red on the brindle-at-stage-2 check |
| ending-copy | wt/alpha-w13-ending-copy | 2066e13 | gpt-6.1-sol high (codex exec) | coordinator reran 3 acceptance tests: PASS 39/-/45 | committed by the coordinator (Sol sandbox had a read-only index.lock); tone awaits Andrew |
| title-summary-music | wt/alpha-w13-title-summary-music | 3ab6290 | opus (pstack-worker) | PASS, level 4 | menu tracks keep LEAD on non-PLAY mode (low) |
| export-stems-path | wt/alpha-w13-export-stems-path | 203ba9f | sonnet (pstack-hand) | PASS, level 4 | --stems-from default is the main checkout music_ace |
| export-win-proof | wt/alpha-w13-export-win-proof | 178cf90 | opus (pstack-worker) | PASS, level 4 | won at stage 6, 34189 ticks, 92.3 s wall, deterministic across two runs |
| export-package | wt/alpha-w13-export-package | c263e37 | sonnet (pstack-hand) | PASS, level 4 | tarball named by sha7 only (overwrites per commit, low) |
| help-page | wt/alpha-w13-help-page | d413ba4 | sonnet (pstack-hand) | PASS, level 4 | page omits boss names (ruling: accepted) |
| companion-drops | wt/alpha-w13-companion-drops | f1517c4 | opus (pstack-worker) | PASS, level 4 | same-entry double-pay guard lacks live coverage (low) |
| companion-cues | wt/alpha-w13-companion-cues | e3c1e7a | opus (pstack-worker) | PASS, level 4 | audio.play not asserted by test (low); pip colour VERDIGRIS eye check parked |
| readme-alpha | wt/alpha-w13-readme-alpha | 3a1769f | sonnet (pstack-hand) + coordinator wording fix | FAIL after fix round on 2 wording claims; coordinator fixed 4 lines; grep, links, controls, lint, prettier PASS | field_notes.gd TESTING still says "three stages" (outside fence, wave 14 note) |

### Gate story

Candidate cand/alpha-w13. Gate 1 on the b6232f3 tree: 403 runs, 1 red (loop_coherence_test: the new Waking and Mind codex rows read from BossCodex.ENTRIES only), fixed test-only in 01aa202; targeted rerun PASS, lint 0. No second full gate (the Opus gate read judged that defensible). Opus gate read: ADMIT (PASS+NOTES, level 4). proto/alpha fast-forwarded to 01aa202.

### Export

At 01aa202: tarball 41.0 MiB, pack 78.5 MiB, ACE_CHECK ready clips=8 streams=24. Win proof won at stage 6, 34170 ticks, 86.65 s wall (skipper seed 1). Copied to artifacts/local/alpha/export/01aa202/.

### Rulings (coordinator, 2026-10-05; recorded in docs/decisions.tsv at the wave 13 records commit)

- M4 done-when is "exported build launches cold and a run can be won"; Tarn, Tally and the cannon are wave 14+.
- P1 first export by the coordinator on d300a77 (78.5 MiB Linux build, 300 headless frames, ACE ready, 24 sidecar stems).
- Stems found through --stems-from (default: the main checkout); never regenerated.
- Alpha cuts: C4, prog-G2 trail and topper, C8 wardrobe, bespoke Tarn/Tally/cannon models, camp recreation C10-C13.
- mind_quieted unlocks the remembered cannon (id remembered_cannon); Tally gets an achievement row for the three ledger leaves; the ledger hand-in lives in Moss's shop.
- Ending: world-3 win gets its own screen and crew-log copy; tone is Andrew's to approve.
- Title and summary music: one unit on the synth engine.
- Companion: C1 and C5 in wave 13; C2/C3 and C6 in wave 14.
- README describes the alpha as built: three playable pilots, the rest locked.
- mind_plate codex row stays force-only (deferred to wave 14 boss tuning).
- Waking final-floor codex row ships as a plain "killed the Waking" row.
- Help page names the run loop but not the three bosses (accepted).
- Companion ready pip uses Palette.VERDIGRIS; eye check parked.
- readme-alpha may fix the two "three stages" lines outside its fence.

### Open after wave 13: wave 14 concerns (Opus gate read)

1. content_registry pins only BossCodex.ENTRIES (Brindle); add WAKING/MIND (or all()) to TABLES and GOLDEN_HASHES; sweep ENTRIES-only readers.
2. field_notes.gd:25 TESTING still says "three stages ... Admiral Brindle" (outside every wave 13 fence).
3. Run the 7 stems-dependent music tests with stems present against the title/summary music change (gate worktrees have no stems, so they skipped).
4. sketch-export: run the win proof before building the tarball or delete the tarball on a failed proof; add -dirty to the tarball name; record the proof in BUILD.txt; the tarball overwrites per commit.
5. Mind codex rows (lane, split_lane, rush) fired 0 times in the win proof; only forced tests prove them. (Corrected 2026-10-06, W18-R2: codex rows record only dodged attacks; the Mind does fire all four families against bots. See wave 18.)
6. Won-summary menu_theme call lacks the sound_ready guard the lost and idle branches have (audio.gd ~1902).
7. mind_plate is reachable only when forced (ruling: wave 14 boss tuning).
8. companion-drops same-entry double-pay guard has no live test; companion-cues never asserts audio.play; menu tracks keep LEAD on non-PLAY mode.
9. Companion pieces drop unequipped so the indicator stays hidden until assembly; hud.companion_state_of parses the document every frame.
10. Win-proof tick count moved 34189 (178cf90) to 34170 (01aa202); the new number is recorded above.

Cost: phase A workflow 18 agents, 1.48M subagent tokens, 24.4 min wall; readme workflow 4 agents, 0.36M tokens, 10.6 min; Sol ending-copy one codex exec.

### Hands checklist additions (never blocks)

9. Read the ending page copy (RETURN TRIP ENTERED, five log lines, "Filed by the bay crew.") and the three new epitaphs.
10. Hear the title and summary synth themes.
11. Cold-launch the new export tarball (01aa202): the numbered steps are in [SITTING.md](../SITTING.md#cold-launch-the-exported-alpha).
12. Eye-check the companion ready pip colour.

## Wave 12 landed (2026-10-05, d300a77)

The wave 12 candidate cand/alpha-w12 landed as d300a77 (proto/alpha went 9b86eb7 to d300a77). Heads below are the unit heads in git; verdicts are the coordinator's, 2026-10-05.

**Milestone:** M3 (worlds two and three greybox and dressed) is complete in bot play: every skipper seed 1-4 clears all six stages and kills the Mind; posture bands hold for worlds 2 and 3.

- relics-sable-spread (wt/alpha-w12-relics-sable-spread, 058f243): pit_coil and storm_crater as crater_slam swaps; the duplicate is accepted. Verdict: PASS+NOTES.
- run-prev-backup (wt/alpha-w12-run-prev-backup, 6703777 then fix 8eac257): the verifier failed four data-loss probes (P2-P5); all four are fixed with a check each. Verdict: PASS.
- bot-stalls-w3 (wt/alpha-w11-w23-posture-bands, c4b5328): combined stage5-gate-stall-seed2 and stage6-stall-seeds-2-4. Both stalls were bot steering: _to_gate climbs when the arch is above, the climb route keeps to ramp middles, and climb hysteresis. Verdict: PASS+NOTES.
- w23-posture-bands (wt/alpha-w11-w23-posture-bands, b40b05f): admitted from hold. Verdict: PASS (14 checks); stage 6 medians [56.06, 45.08, 54.2, 87.49], Mind [12.99, 10.85, 11.46, 12.92].

### Gate story

Candidate cand/alpha-w12. Gate 1 at d300a77: 397 runs, 0 reds, 1733 s. No fix rounds against the gate.

### Rulings (coordinator, 2026-10-05; recorded in docs/decisions.tsv at the wave 12 records commit)

- wave 12: units 3 and 4 merged into one unit (bot-stalls-w3) on wt/alpha-w11-w23-posture-bands; Sable later relics duplicate crater_heart on the smash slot, accepted for alpha 2026-10-05.

### Open after wave 12

- M4 (alpha): Tarn claw kit, Tally kit, remembered cannon, assembled companion, camp, cosmetics, full achievements, discoveries, ending, title/summary music, Linux package, README, how-to-play. Wave 13 scouted now.

### Hands checklist (never blocks)

1. Play the title to RUN COMPLETE through all three worlds.
2. Hear the world stingers and the boss music sections.
3. Read the cog and mass glyphs.
4. Try the Highdraft ramps after a fall.
5. Paste a second soak brief to Bing Bong on d300a77.
6. Physical gamepad.
7. Cold launch of the exported build.
8. Cold-launch the export once scripts/sketch-export.mjs produces a build on d300a77.

### Lessons for briefs

- Bot repro commands must carry --fixed-fps 90 (ChildRuns adds it); without it runs are not deterministic.

## Wave 11 landed (2026-10-05, 9b86eb7)

The wave 11 candidate carries three worlds and six named zones end to end. Heads below are the unit heads in git; verdicts are the coordinator's, 2026-10-05, and the gate story is below. proto/alpha went fe5d013 to 9b86eb7.

**Milestone:** the full six-stage skipper seed 1 run won in 382.6 s game time, with the Mind defeated in 12.1 s. This is the first end-to-end three-world bot win.

- table-swap-second-zones (wt/alpha-w11-table-swap-second-zones, 40c9c27): rows 4 and 6 run on dig_deep and highdraft_crown. Verdict: PASS+NOTES.
- terrain-lazy-perf (wt/alpha-w11-terrain-lazy-perf, ee65af6): map-identity checks; perf test baselined. Verdict: PASS+NOTES (after the lint carve-out fix round; the perf test is in the L1 baseline).
- tree-depth-by-world-redo (wt/alpha-w11-tree-depth-by-world-redo, a6b5abb): offers a fresh depth-3/4 pair after the world-one Face Runner. Verdict: PASS.
- mind-arena-bound (wt/alpha-w11-mind-arena-bound, 8e0bf6f): every Mind hazard and escape point bound to the stub pad. Verdict: PASS+NOTES.
- highdraft-fragment-unlock (wt/alpha-w11-highdraft-fragment-unlock, 25a7756): mind_quieted, Tally's third fragment, earned once on beating the Mind. Verdict: PASS.
- snd-zone-entry-cue (wt/alpha-w11-snd-zone-entry-cue, cfff8c3): world stinger on the beat when a world is entered. Verdict: PASS.
- boss-music-sections (wt/alpha-w11-boss-music-sections, 016339b, Sol): boss music sections per boss id for the Waking and the Mind. Verdict: PASS.
- w23-lore-final (wt/alpha-w11-w23-lore-final, e0cc629, Sol): final world 2 and 3 lore rows in the approved crew-log voice. Verdict: PASS (Path A voice approved by owner).
- relics-per-world (wt/alpha-w11-relics-per-world, 3890562): six relics per world, one relic cache on each world-2 and world-3 map. Verdict: PASS+NOTES (Sable slot ruling).
- run-save-worlds (wt/alpha-w11-run-save-worlds, 6d97612): resume at worlds 2 and 3, restart parity across three ways back. Verdict: PASS+NOTES (New-run .prev ruling).
- ui-worlds-three (wt/alpha-w11-ui-worlds-three, 84c09f7): worlds 2 and 3 cards, victory and summary on the default table. Verdict: PASS+NOTES.
- highdraft-choir-stall (wt/alpha-w11-highdraft-choir-stall, ed6d02a): Highdraft beacon ramps on the bridge-mouth shoulders so a fallen ball can climb back; the bot runup fix is d78217f. Verdict: PASS+NOTES.
- pin-step-weight (wt/alpha-w11-pin-step-weight, 522dd54, the cherry-pick of 5599f71 that is in the candidate): _pin_step skips a victim with no weight (Brindle targets). Verdict: PASS+NOTES.
- bot-soak (wt/alpha-w11-bot-soak, 4d2e3b6, Codex desktop agent): 48-run soak findings in design-v3/soak-2026-10-05.md. Admitted as docs.
- w23-posture-bands (wt/alpha-w11-w23-posture-bands, 8e4a313): held on its branch: stage 6, the crown Warden, never breaks and the world 3 boss is unreached; wave 12 unit crown-stall traces it.
- contracts-and-handoff (this unit, ff587b8, fix round in progress): CONTRACTS.md boss, breach, net deck, row-level pack, table-row and relic sections; DESIGN-V3 built-versus-planned table; this section; warden_look.gd comment.

### Rulings (coordinator, 2026-10-05; recorded in docs/decisions.tsv at the wave 11 records commit)

- highdraft-ramp: ruling (a), the net deck gets a ramp back onto the beacon island in map_highdraft.gd; the bot runup fix d78217f stays. A dead-end deck a human Sable or Rivet also hits is a map defect (momentum is sacred, quick restart). Coordinator, 2026-10-05.
- highdraft-ramp placement: on both shoulders of the bridge mouth, not away from it (stalls cluster at both mouth corners; the radial try left a pocket). A seed 2 gate stall after the Warden break is a separate bot defect, logged for wave 12.
- relics: Sable world-2 and world-3 relics all sit on the special slot; accepted for alpha. A wave 12 unit spreads two onto the smash slot as swap rows.
- save: New run at the title replaces a Continue-able save with no confirm; a wave 12 unit keeps the replaced run as run.json.prev, with no confirm dialog (quick restart is sacred).
- relic cache builds one frame deferred so pedestals read the new terrain; accepted.
- Owner ruling carried: the Warden's "ram racks posture" default stays (Andrew, 2026-10-04); revisit only after he plays both.

### Open after wave 11

- Gate story: candidate cand/alpha-w11. Gate 1 at 047c51c: 393 runs, 7 reds (audio_worlds stinger row, build_gate_props parked-stage colliders, run_resume_worlds deferred lambda ERROR, world_table placeholder pin, bot_stub_boss 120 s budget against the real Waking, bot_run_end crown stall, highdraft_warden_bot relic cache in runup). Fix rounds: crown-stall 2c3a8ef and e8fdbef (Opus), fixa a82fb32 (Sonnet), fixb bb073c7 (Opus), handoff fix 229582b (Sonnet). Gate 2 at 1ea5cb7: 394 runs, 1 red (spine_event_kinds priority-3 wording), fixed as 9b86eb7 with six targeted reruns; no third gate.
- Soak: Bing Bong (Codex desktop) ran 48 runs on 08e12a4: skipper 5/16, completionist 3/16, camper 0/16 by design.
- Wave 12 landed; see above.
- Stage 6 (the crown) is unbroken by the skipper bot on every seed; the world 3 boss is unreached in bot runs. Traced in wave 12 unit crown-stall. The w23 posture bands test is held on its branch until then.
- Wave 12: spread two Sable relics onto the smash slot; keep the replaced run as run.json.prev; the seed 2 stall after the Warden break (bot defect).
- Soak findings: design-v3/soak-2026-10-05.md.

### Hands checklist (never blocks)

1. Play the title to RUN COMPLETE through all three worlds.
2. Hear the world stingers and the boss music sections.
3. Read the cog and mass glyphs.
4. Try the Highdraft ramps after a fall.
5. Paste a second soak brief to Bing Bong on 9b86eb7.
6. Physical gamepad.
7. Cold launch of the exported build.

### Lessons for briefs

- A gate red whose cause is a parked stage's collider still standing for one physics tick: exclude other stages' colliders in physics sweeps (build_gate_props, wave 11).
- A unit that adds a bus row's sound must edit event_kinds.gd in the same commit; a priority-3 flow row carries HUD or objective wording (spine_event_kinds).

## Wave 10 landed (2026-10-04, fe5d013)

Twelve units merged (nine Claude, three Sol) and one held back, plus four coordinator commits. proto/alpha went 08e12a4 to fe5d013. Gate 1 at 9b8a2a3: 383 runs, 1 red (alpha_posture_bands_test killed at the 180 s cap under load); two-seed cut, test rerun solo 117 s PASS. Verifier verdicts per unit; no Opus gate read this wave, the Fable main read the verifier reports itself.

- waking-fight (2245c0e, Opus): the real Waking fight; objective names the Waking before its floor.
- mind-fight (7379dd8, Opus): the Mind fights with its four attack families, a choir Warden and hands.
- w2-dig-deep-map (ba4e73e, Opus): the deep Dig map, a third tier below the Dig, and the Dig's side content.
- w3-highdraft-crown-map (a072ce5, Opus): Highdraft crown zone map, its test, and Highdraft side content.
- breach-attack-and-cue (3134b79, Opus): a slam through a breach plate strikes the tier below and is heard.
- enemy-codex-detectors (25c0d5c, Opus): six codex detectors live; LS-3 waits up to 120 frames for the wave front to reach the parked ball.
- w2-dig-rescue (f895aba, Sonnet): Kest rescue pinned end to end on the default table.
- meltdown-slag-telegraph (fd01c39, Sonnet): the meltdown slag lane is telegraphed for SLAG_WARN before it burns.
- release-gate-pending-lists (f014f63, Sonnet): the release gate fails on pending detectors and side content.
- bot-breach-and-lift (17e4dd1, Sol): the brake hand slams Dig breach plates and rides the Highdraft lift.
- alpha-bot-sweep-default (4d14f7e, Sol): alpha_bot_sweep_test runs five bot_run children on the default table.
- posture-sweep-full (c00f273, Sol): full 16-cell posture sweep rerun with the wave 9 bot driver.
- tree-depth-by-world (6d8e7e3, Sonnet): HELD BACK. Verifier FAIL: the retry conflicts with the tree_depth_cap_test guard and allows a duplicate pick; redone in wave 11 as tree-depth-by-world-redo.
- Coordinator: 25c0d5c LS-3 wait fix (verifier-approved); 9b8a2a3 WORLD_ROWS golden hash re-pin (breach_opened row); merges 68372fc and 40da5bf resolved the pending lists (SIDE_CONTENT_PENDING [] in pending_content.gd, activities pin [1,4,3,2]); a7403ab alpha_posture_bands_test two seeds.

### Gate story

One red in gate 1: alpha_posture_bands_test, killed at the 180 s cap under load. Cause: wall cap, not a defect. The fix was a two-seed cut of its seed list; the test then passed solo in 117 s. There was no gate 2: the only change was that test's seed list and the full-sweep data, whose reader posture_bands_test was rerun PASS.

### Rulings (docs/decisions.tsv)

- Owner: the Warden default stays "ram racks posture" (110 / curve 2 / ram_shatters false) although the full sweep's pick rule now favours ram_shatters true; both pass every band; revisit only after Andrew plays both (Andrew, 2026-10-04).
- Boss fight tests pace their own hits; module_harness stays unpaced.
- The Waking's floors are module discs for now; a map overlay is the recommended later form.
- The Mind's hazards are bounded to the pad (PAD_RADIUS 36), not Arena.FLOOR_R 44: wave 11 mind-arena-bound.
- Greybox side-content pending lists live in src/core/pending_content.gd and the release gate reads them; both are empty after wave 10.
- alpha_posture_bands_test runs two seeds in the gate (wall cap), same rule as bot_run_end_test.
- tree-depth-by-world held back; a retry must never offer an id already held, and the retained world-one id maps to its base slot.
- Sol units commit through the coordinator when the codex sandbox cannot write git metadata; the trailer names the coordinator model, the message names gpt-6.1-sol.

### Open after wave 10

Wave 11 is in flight from fe5d013 (thirteen units). Step 1: terrain-lazy-perf, tree-depth-by-world-redo, mind-arena-bound, highdraft-fragment-unlock, snd-zone-entry-cue (Claude); boss-music-sections, w23-lore-final (Sol). Step 2: table-swap-second-zones. Step 3: relics-per-world, run-save-worlds, ui-worlds-three, w23-posture-bands, contracts-and-handoff.

- The soak: wt/alpha-w11-bot-soak (Bing Bong, the Codex desktop agent) runs a 48-run three-world soak outside the waves; 17 done at last report, skipper seed 1 won all six stages in 137 s, beacon stalls seen at stage 5 on some seeds.
- The owner's ram-shatters question is parked until Andrew plays both Wardens.

### Hands checklist (never blocks; carry forward)

1. Play the title to RUN COMPLETE across three worlds.
2. The Waking floor drops and the Mind brace by feel.
3. Dig breach slam and Highdraft lift by hand.
4. Music in fights.
5. Cog versus mass glyph read.
6. Hot-wire cues by ear.
7. Physical gamepad.
8. Cold launch of the exported Linux build.
9. Ram-racks versus ram-shatters Warden comparison in the lab.

### Lessons for briefs

- A boss fight test must pace its hits, or the harness kills the Warden before the fight shows its behaviour.
- Brief-author workflows must dedupe unit ids before the checker runs; three copies of one brief slipped through in wave 10.

## Wave 9 landed (2026-10-04, aec5d2e)

Thirteen units merged (eleven Claude, two Sol) and one retired, plus fix rounds F and G and three coordinator commits. proto/alpha went 62a0dd4 to aec5d2e. Gate 1 had 6 reds; gate 2: 373 runs, 0 fail; Opus gate read PASS+NOTES.

- enemy-burrower (9d8f68f, Sonnet): the world 2 burrower, hidden marker, lane burst and slam kill.
- enemy-drill-crew (c810d17, Sonnet): a plated rig that bores where the ball will be.
- enemy-lamp-swarm (4e7e27d, Sonnet): a lure bloom that bends a slow ball toward three lamps.
- enemy-line-cutter (7632a48, Sonnet): a thrown disc that severs a hooked harpoon line.
- enemy-anchor-crew (f0f1968, Sonnet): the deck winch.
- enemy-kite-drone (30ebd02, Sonnet): hovers above the ball, marks and dives, bat at cruise.
- table-swap-first-zones (f14bd6e, Sonnet): stages 3 and 5 move onto the Dig and Highdraft maps.
- placeholder-release-gate (171bf12, Sonnet): release gate for placeholder stage rows.
- breach-system (0b03d69, Opus): Dig breach plates break on a slam landing.
- highdraft-lift-specs (31069b7, Opus): the Lift as data, with a headless lift test.
- warden-family-variants (d04c692, Opus): stage-row warden_variant reaches the Warden.
- nightly-alpha-table (66d1631, Sol): fake-fixture receipt passes; smash row ungated without baseline, watch rows do not block.
- enemy-codex-and-sounds (0458c2a, Sol): codex entries and warn cues for the six world-two and world-three enemies.
- w23-bot-seed-run (Sol): retired, not written; the wave 8 Sol bot unit (f73dc8e) covered it.
- Fix round F (9a14cef, Sonnet): five tests updated for Dig, Highdraft and the six new enemies.
- Fix round G (c827108, Opus): re-pin posture_bands_test and refresh the picked-cell sweep row.
- Coordinator: f9372c3 world-one hill/kit/ring checks apply to world-one rows only; 171b3c5 chain-guard patch (delta of cand/alpha-w8 14be04a..48e4e74, Opus fix of the Sol bot unit); DETECTOR_PENDING list in codex_entries.gd plus the combat_codex_test skip (inside 0458c2a).

### Gate story

Gate 1 reds and causes: build_gate_props (index 2 on fewer than 3 gate slots: test); side_content_roster and activities (Dig and Highdraft greybox lack side content: SIDE_CONTENT_PENDING skip, wave 10 map units own its removal); threat_sites (six new enemy files plus the warden slag LANE: pin); bot_run_end (189 s over the 180 s cap under load: one seed child per world); posture_bands (bot_driver changes moved the medians: picked cell re-swept, small 73.75 to 82.4, grown 24.66 to 39.2, bands unchanged; full 16-cell sweep owed to wave 10 posture-sweep-full).

### Rulings (docs/decisions.tsv)

- world_stages_test's landing hill, momentum kit and event-ring checks are world one's grammar; worlds 2 and 3 pin their own via zone tests.
- Greybox zones may be non-placeholder rows while SIDE_CONTENT_PENDING names them; the release gate must read the pending lists before export.
- Codex entries may ship with DETECTOR_PENDING until wave 10; the gate must fail on a non-empty list at release.
- bot_run_end_test runs one seed child per world in the gate; the nightly matrix is the breadth.
- Posture bands: the fight did not change, the bot did; re-pin accepted, full sweep owed; a grown-ball median near 43 s would fail the 2x band (owner's eye).
- The haul-guard input erasure stays on for skipper and camper everywhere and for every policy in a boss fight; the completionist chain hand is exempt outside boss fights.
- The Meltdown slag lane needs its own telegraph and attack phase; the lamp_swarm lure must gate hit_player on the committed wave's contains().
- w23-bot-seed-run retired.

### Open after wave 9

Wave 10 landed at fe5d013; see its section above. The units below were owed after wave 9 and are done except tree-depth-by-world (redo in wave 11).

Owed:

- The full 16-cell posture sweep (posture-sweep-full).
- The release gate reading the pending lists (SIDE_CONTENT_PENDING, DETECTOR_PENDING) before export (release-gate-pending-lists).
- Detectors for the six new enemies' codex entries (enemy-codex-detectors).
- The Meltdown slag telegraph and attack phase (meltdown-slag-telegraph).
- The lamp swarm lure gating hit_player on the committed wave's contains() (inside enemy-codex-detectors).

### Hands checklist (never blocks; carry forward)

1. Play the title to RUN COMPLETE across three worlds.
2. Music in fights.
3. Cog versus mass glyph read.
4. Hot-wire cues by ear.
5. Physical gamepad.
6. Cold launch of the exported Linux build.
7. The Dig and Highdraft greybox feel: floor drops, barge carries, thermals.

### Lessons for briefs

- A test that pins world-one map grammar must key on the row's world, not "every non-opening stage".
- When a bot driver changes, the posture sweep pins move: rerun the picked cell before the gate, not after.
- A unit brief written before its base's fix round should say the base is "candidate after fix round", and the writer re-reads cited lines.

## Wave 8 landed (2026-10-04, aa1b56e)

Nine units merged, one held, plus fix round A. Gate 1 at aa1b56e: 360 pass, 0 fail; eight adversarial verifiers PASS+NOTES, no fence breach.

- director-row-packs (a1bf49c): a stage row may carry its own packs, elite and elite_arrival.
- warden-posture-point-and-brace (f8dd3a1): name the family weak point everywhere it opens; pin the Mind brace.
- module-harness (33ef0b4): module harness drives any BossContract module to victory.
- net-deck-fall (f5f9ecd, Sonnet): a fall below a declared net deck lands on the deck at half speed.
- roster-world-rows (431b1e8): the world 2 and 3 kinds as roster, fleet and wind-up rows; the wave's single ROWS_HASH writer (E19-E24).
- w2-dig-map (1fd7d17): greybox Dig zone map with two tiers, breach plates and Kest's cage.
- w3-highdraft-map (a218262): greybox Highdraft zone map and its zone test.
- waking-floors-rule (a0acc42): waking_floors, the Waking's floor-by-floor rule on the posture contract.
- w23-codex-entries (d65fa29, Sol): W23 codex entries for the Dig, the Highdraft, the Waking and the Mind.
- bot-run-to-run-ended (f73dc8e, Sol, held): skipper seeds 1 and 2 win a full six-stage run (384 simulated s) but regress bot_chain_hand_test (0/16 seeds reach the two-hook chain); fix round B on cand/alpha-w8.
- Fix round A (aa1b56e, Sonnet): dig and highdraft in Terrain.MAPS, map_dig overlays id+_before, guard posture pin to family_point, roster unbuilt check derives from script existence.

### Open after wave 8

- The bot unit's chain-hand regression (fix round B in flight).
- The thermal glide rule (wave 9 lift unit).
- The module harness's own damage path is not distinguishable from other damage (boss tests assert hits == 2 * CHUNKS).
- windup_rows_test would pass for a reskinned counter; each wave 9 enemy test asserts its own E-id attack phase.
- No release-gate check on placeholder names yet (wave 9 unit).
- World 2's placeholder maps are near-identical until the wave 9 table swap.
- Nothing played by a human yet.

## Wave 7 landed (2026-10-04, 0a18382)

Fourteen units merged and one probe kept unmerged, plus five fix rounds and two coordinator commits. Gate 1 at 5690d47: 8 reds (5 two-stage pins, 3 unit regressions); gate 2 at f758211: 350 pass, 1 flake (world_cache relic rarity) fixed test-only; Opus gate read PASS+NOTES, no blockers.

- w23-tests-derive (955201d): stage-count tests read the table, stay green on six stages.
- alpha-retry-continue-test (7899f7b): one retry per world and Continue on the default table.
- burst-pays-cogs (f4fb4c5): the first-discovery burst pays cogs beside mass.
- snd-achievement-rescue (1e086f2): hear achievement_earned and rescue_completed.
- w23-table (254db18): six-stage default table across three worlds on the surviving maps.
- w23-boss-files (7300f19): the Waking and the Mind get their own module files.
- probe-dig-floor-drop (fe3ac52): Dig floor drop probe, an overlay floor parks under the ball (PASS).
- mind-attack-families (fb67a4c): four attack families as pure rules with a tested escape guarantee.
- alpha-e2e-flow (29b943b): walk the default table end to end, title to tombstone.
- explorer-camp-wedge (ea09f8c): the explorer climbs the dive ramp to the Reach camp.
- mass-icon-split (431b00f): mass gets its own heap icon; the cog means money alone.
- spill-pays-cogs (aebfa62): spill and drone-kill pickups pay cogs; the crane trail pays mass only.
- w23-zone-rows (6d0125d, Sol): W23 zone rows, music for 2-1 to 3-2, Waking and Mind tracks, placeholder lore and tone sample.
- probe-highdraft-island-net (279e25d, not merged): measured FAIL kept as evidence, a free ball falls off a moving island (drift 15.6 m); islands become barge-carry bodies, thermals need a glide-rule change (wave 9 lift unit).
- Fix rounds A-E: A generic posture-boss bot path (2edf8ae); B four table tests (397eee8); C cogs_collected on bursts, rescue once-guard test, music theme per row (f8dd282); D five two-stage pins repointed (d29e169); E audio_worlds, reach_secret, hud words, then count-by-id and burst pin (b7e0b46, 60a8e70). Coordinator commits: a07d989 golden hashes, 0a18382 world_cache relic rarity.

### Open after wave 7

- The Brindle full-run bot stall: fixed on the bot side in f73dc8e (held for the chain regression, fix round B).
- Continue is proven on world 1 only on the default table (wave 11 run-save-worlds).
- No release-gate check on placeholder names yet.
- target_material no longer covers lazily built later worlds.
- World 2's two placeholder maps (gorge, reach) are near-identical terrains.
- Andrew approved the lore voice as written on 2026-10-04: dry work-crew notes and shift logs with a quiet wrong thing underneath. All 48 world 2 and world 3 lore rows use that voice. Music remains synth pending listening approval.
- Nothing has been played by a human yet.

## Wave 6 landed (2026-10-04, f1f753b)

Eighteen units merged plus four fix rounds and two coordinator commits; gate 3 at 1fe63fd: 340 pass, 1 red fixed as f1f753b (test-only), quarantine build_power_curve; Opus gate read PASS+NOTES after fix B.

- HW2: hot-wired Fit / Recycle screen in play.
- META-6: companion assembly screen on the death screen (--companion-stub).
- META-7: RS4 settle-once ledger for one-time grants.
- IN2+IN3+IN4: aim assist, pad rebind rows and paged settings.
- F7: the stub boss fight reads like a fight (plate, ring, chord).
- META-3: world-one rescue quest, a caged runner on the Spillway.
- EV1: two evolutions: Wrecking Ball and Pinwheel become Evolved parts.
- RL1+RL2: relics found in cracked caches, held per slot in the run.
- RS4+RS5: run_save_interrupt_test, interrupted run-save transitions.
- REC: wave 5 records (ledger rows, decisions, handoff).
- B3: balance report and checkpoint bands for the alpha table (Sol).
- C6: tile check tool for texture tiling (Sol).
- C8b: audio routes stage music through music_rows (Sol).
- BS1: tree safe picks, no dead-end offers (Sol).
- SC2+SC3: Reach secret and side-content roster (Sol).
- T1b: smoke runner tags and per-test timing (Sol).
- T5: content registry with fixtures and unit case (Sol).
- T7a: presentation tests on the alpha table, lint baseline (Sol).
- ZS-E: structure rows test for the second zone (Sol).
- Fix rounds A-D (A, B Sonnet; C, D Opus) and two coordinator commits (1fe63fd hot-wire mount, f1f753b growth test).

### Open after wave 6

- Plating retirement landed at 656fded (gate 2 green after one env timeout rerun).
- Worlds two and three as real build tracks, per Andrew's ruling that the alpha is three worlds plus the final boss. The track started in wave 7 (six-stage table, boss files, probes) and continues in wave 8.
- The field-note collection triggers: none is unlockable in play.
- The hero relic and evolved toppers are still mapped to rare_plus.
- The explorer bot wedges on the Reach camp path.
- Tally and the remembered cannon are out of this candidate.
- Nothing has been played by a human yet.

## Wave 5 landed (2026-10-04, b927aec)

Twelve units merged; gate 3 receipt `artifacts/local/alpha/wave5/gate3.log`, Opus gate read, fix rounds A-D.

- F2b: Brindle plate, ring and chord.
- RS3+RS6: the run save lives in the run flow, one retry per world, Continue on the title.
- CG2: cogs shown everywhere, plus a cog tick.
- META-1+2: Tarn, Sable and Rivet open, locked cards tell the truth, rescue_completed signal.
- HW1: hot-wired offer API and Spark Tread.
- F5: stub boss per world row.
- META-5: companion escape window.
- SC1: enemy camps.
- C2: topper glb.
- IN1: look settings.
- D2: archive sweep.
- ZS-D2: the default table is the alpha ruleset.

### Open after wave 5

- The hot-wire choice has no screen (HW2, wave 6).
- The stub boss has no plate or chord (landed in wave 6 as F7).
- Nothing emits rescue_completed (landed in wave 6 as META-3).
- The companion has no pickups or panel (META-6) and is not persisted (META-7).
- Death, then quit, then Continue costs no retry (owner call).
- The explorer bot wedges at (63,28.5,3) walking to the Reach camp (driver pathing).
- The cog icon still means mass in the armour gauge (icon decision).
- Discovery burst and boss spill pay no cogs.
- music_rows is not routed by audio (landed in wave 6 as C8b).
- Plating-fight code is still present (F6, wave 6).
- The build_power_curve quarantine is still open (F6).

## Wave 4 landed (2026-10-04, aee2242)

Eleven units merged; gate 2 receipt `artifacts/local/alpha/wave4/gate2.log`, then the Opus gate read. Default table swap (D2) was pulled from the candidate and re-queued as ZS-D2 in wave 5 with its gate-1 failure list. Wave 5 landed at b927aec (see above).

- F2a: Brindle's hull is a posture body on the boss contract.
- RS2: run store on disk with a tombstone on clear and a stale-save refusal (cause run_ended).
- CG1: the cog wallet; shop and fabricators spend cogs, scrap raises mass only.
- F4: world-one Warden fights tested on real maps.
- B1: smash damage per fight in the run log.
- ZS-C: zone schema and test-time zone slots for world-one maps.
- ZS-D: the Weir retired from the alpha table path (default swap itself is ZS-D2).
- C5: lore wiring; zone-entry exchanges advance on interact only.
- C8: music rows and a pack resolver (data layer).
- B2: the explorer bot's two-hook hand.
- TR1: tree depth cap follows the stage table's world index.

### Open after wave 4

- Shop UI still says scrap (CG2, wave 5).
- Brindle has no plate/arc/chord read and emits no posture signal (F2b).
- A stagger does not cancel a Brindle charge in flight (design call, open).
- Hero gate toppers for relic and evolved map to Topper_rare_plus until tools/blender/reward_gate.py is regenerated.
- run_seed is unused by offers.
- No field note can be unlocked in play (lore collection triggers).
- music_rows.gd is not routed by audio.gd (landed in wave 6 as C8b).
- TR1's world.gd:610 stage schedule and the Sable route migration.
- Default table swap re-queued as ZS-D2 with its failure list.
- B2 explorer chain band unmet (5/16 seeds reach combo 2).

### Lessons for briefs

- Name every suite-wide invariant (bus signal rows plus the ROWS_HASH re-pin, pinned sets, has_method guards on enemy calls, the verdict line format, the per-test 180 s cap) and ask writers to run the sibling tests their fence can break.
- Name which table a test runs on (the default table is now the alpha ruleset; legacy FirstWorld holds the full catalogue). Any test asserting counts of sites, pilots, trees or parts must derive them from the table.
- A modal that pauses the tree must check game.bot_driven.
- A deferred add_child on the game leaks at exit when a test frees the game the same frame.
- A gem's part can complete an evolution, so count parts by id.
- A brief's file:line citations drift when the base moves; say so in the header.
- A smoke test runs without --fixed-fps, so a physics-stepped test runs near real time against the 180 s cap.
- A golden hash in content_registry.gd is a second pin beside ROWS_HASH; the coordinator re-pins it once on the candidate.
- A brief's acceptance that contradicts a golden hash or registry check must name the re-pin.
- When several authors write one unit, the coordinator settles the design in an amendment before launch.
- A verifier that must stay read-only applies mutants in a scratch copy.

## Wave 3 merged (4 October, proto/alpha 13fe55a)

Twelve units merged after two gate runs; gate 2 passed except the quarantined build_power_curve_test. Receipts: `artifacts/local/alpha/wave3/gate1.log` and `gate2.log`; ledger rows in `tools/coordinator/lane-ledger.tsv`, design calls in `DESIGN-NOTES.md`, rulings in `docs/decisions.tsv`. Units: F1 boss contract, ZS-B alpha table, RS1 entrance document, RR1 rarity ladder, META-4 companion model, C3 wind-up rows, C4 lore rows, F3b guard-rack burst, C1 hero asset guards, ZS-A Spillway zone 1-1, T8 nightly runner, D1 DESIGN-V3.

**Wave 4 ran** from base 13fe55a (landed at aee2242, see above): Claude units F2a, RS2, CG1, F4, B1; Sol units ZS-D, ZS-C, D2, C5, C8, B2, TR1.

**Wave 5 candidates:** F5, F6, RS3, RS6, CG2, META-1..3, HW1, EV1, RL1, RL2, SC1..3, C2, C6, C7, T1b, T5, T6, T7a/b, IN1..4.

### Open after wave 3

- spine_crush_test and spine_heft_test still drive from (-110,-120) across the new causeway and strike slower; they pass, but it is no longer flat ground.
- No test runs the alpha swarm Warden end to end through flow; the rack's proximity-scatter path is untested.
- T8 has had no real nightly run (dry-run only).
- DESIGN-V3 needs a line per later wave.
- The entrance document, cogs, companion and run_seed have no consumer yet.
- shop.gd fallback once minted old-id recipes (fixed in the review round).
- Playtest entry 12 lacks Andrew's hand label; `npm test` fails on it. Pre-existing, Andrew's.

## Wave 2 merged (3 October, proto/alpha fbd6bc6)

HC2 (readout) and HC3 (chain log and codex card) are in: gate 2 on tree 0f36041, 295 runs, 0 unquarantined failures; receipts in `artifacts/local/alpha/wave2/`. The hook chain is complete as specified; Andrew has not played it. Open after this wave: a still of combo 4 with its rings and counter (needs the GPU and workspace 10), the bot band after HC3 (skipper smash damage per fight up no more than 10%; explorer best_combo median ≥ 2 over 16 seeds with a two-hook script), and the HC2 debt in the ledger. Next per ALPHA-PLAN: M2 world one, Spillway as zone 1-1, both Wardens on the posture contract, Brindle, rescue progression, run save. Performance claims wait for a GPU-free measurement.

## Wave 1 merged (3 October, proto/alpha 8601e9e)

HC1, AS and RL are in. Gate 3 on tree d67fc25: 293 runs, 0 unquarantined failures; receipts and the Opus gate's findings in `artifacts/local/alpha/wave1/RECEIPT.md`, ledger rows in `tools/coordinator/lane-ledger.tsv`, design calls in `DESIGN-NOTES.md`. Three brief-caused gate failures taught the invariants every wave 2+ brief now names: a verdict line `name: PASS|FAIL`, a ROWS row plus `GRAMMAR_SIGNALS` and an `attack_rows_test` hash re-pin for every new bus signal, the `legibility_rows_case` LINE_ROWS set and the `objectives_case` walk. Wave 2 is HC2 (readout) and HC3 (chain log and codex card) on `wt/alpha-w2-hc2` and `wt/alpha-w2-hc3`, dispatched 3 October. Veto list for Andrew: the plate says "Find an activity" until every site is done; a rewind press is not a miss; the combo pays the chained enemy only.

## First wave of the full-send round (historical, briefed and merged)

| Unit | Spec | Owner files | Tier |
| --- | --- | --- | --- |
| HC1 hook chain state and rule | [HOOK-CHAIN.md](HOOK-CHAIN.md) | `src/combat/chain.gd` (new), `src/movement/player_ball.gd`, `src/core/event_kinds.gd` chain rows | medium (worker), alone and first |
| AS activity signposting | scout read, 3 Oct: `ui/edge_markers.gd:43-55` `targets()` returns Warden else beacon only; `core/objectives.gd:15-27` has no activity row; the sites are `ctx.activities.sites` with `done` flags (`world/activities.gd:119-133`) | `src/ui/edge_markers.gd` (one amber marker per unfinished site, from drop-in, hidden while the Warden fight is engaged), `src/core/objectives.gd` (nearest-activity row before the Warden row) | medium (worker) |
| RL run-log instrumentation | scout reads, 3 Oct: `prompts_shown` is initialised at `run_log.gd:160` and never incremented; `key_glyphs.gd` has no hook; `packs` appends the faction at `run_log.gd:283`, kinds are in the signal | `src/core/run_log.gd`, `src/ui/key_glyphs.gd` (rising-edge `prompt_shown(verb)` on `game.events`), `src/core/game_events.gd`, tests `spine_run_log_test.gd:96`, `traversal_measure_test.gd:164` | easy (hand) |

HC2 and HC3 (readout, miss cost and log) follow HC1 in one wave. Then M2 world one per ALPHA-PLAN: Spillway as zone 1-1, both Wardens on the posture contract, Brindle, rescue progression, run save. Performance must be re-measured with the GPU free before any perf claim: the sitting ran beside a GPU research loop and the ACE ring ran dry three times.

Housekeeping owed when no agent is live: 69 worktrees, 112 unmerged branches (most `codex/job-*` of 2 October), 23 untracked `.uid` files on `main`.

## Recovery record (historical, 3 October)

Continue the existing [alpha plan](ALPHA-PLAN.md) and [roadmap](ROADMAP.md). The old v3 resume queue is historical at Git base 619b8f4 and in the recovery evidence; its music, performance and ledger work has already been integrated or given a recorded disposition. Do not restart those units.

## Current authority and location

- Integration: proto/alpha in /home/andrew/Projects/scrapkeep/.claude/worktrees/game-completion-plan-75f776. Recovery started at 619b8f43c60ef1033825815f5661d48c05af434f; main remains f5848c7 until the human checkpoint.
- Andrew approved implementation of the refined completion plan on 3 October. Three worlds, six pilots, modular SPIL-9, between-run camp, 30-to-45-minute run, one death retry per world, free unfinished-zone quit/crash replay. Mind ends the campaign.
- Hard gate: Andrew plays the checked Cable Reach before any Dig/Highdraft map or encounter is constructed. Existing concepts and probes are reusable evidence, not complete worlds.
- Dirty owner edits to Bible, decision list, persistence ADR and sitting sheet were copied and hashed under artifacts/local/alpha/recovery-2026-10-03/owner-baseline.json before reconciliation. The untracked verifier configuration is preserved.

## Immediate recovery queue

| Work | Exact source | Disposition |
| --- | --- | --- |
| Gamepad through menus | codex/job-522d27958f71f23dce5a-83d4eaf1db at 286327f | Fresh source review and clean executable gate passed; fast-forwarded into proto/alpha. Final combined tree qualification is recorded in the recovery record. Physical controller still pending |
| Shared beds on probe pieces | codex/job-2ec11c941dc3cff32a9a-6326a97874 at 515f919 | Reuse selected shader/material method after scoped admission; old probe game.gd must not replace current routing |
| Sculpted rock round four | codex/job-6ed433780b1c4b65e634-93e2af44ab at f14cb70 | Preserve recipes and assets; look and collision/integration still need their own evidence |
| DEM Reach probe | codex/job-f5d2ad54607f25e58070-f7b5ee946f at e24de55 | Throwaway terrain experiment; reuse feasibility findings, not whole-branch gameplay |

The three visual branches share older base a56959e; their changed assets and probe paths differ from current alpha. No new look rounds before the sitting, per the existing decision trail.

## Next dependency-ready work

1. Freeze the combined recovery tree, finish its exact-tree gate and Cable Reach checkpoint, then record the sitting status in artifacts/local/alpha/recovery-2026-10-03/RECOVERY.md. The 286327f source gate already passed; documentation reconciliation changes the final tree and requires another gate.
2. Ask for the existing five sitting answers. A miss allows at most ten corrective units and one more sitting; further misses require a re-plan.
3. After the verdict, finish world one while reusing the six new-kit probes. Build Tarn, Tally and cannon; a weak probe refines the required kit.
4. Settle durable run continuity and companion assembly before freezing world rewards. Then build the later-world greybox, dress the campaign, finish camp and export.

## Verification and limits

Use the approved sketch:gate and sketch:checkpoint commands and source-bound receipts. The one known build_power_curve_test quarantine belongs to the M2 Warden conversion; do not loosen its bands. Physical gamepad, current alpha fun, look/audio in play and mid-tier hardware remain unqualified. A full cold exported campaign is not yet available.

The reviewed 286327f gate ran 289 checks with zero unquarantined failures, one expected headless audio skip and the existing power-curve quarantine. Documentation checks passed after reconciliation. Eight dependency-hash mismatches predate recovery; their baseline comparison is retained rather than repinning old contract claims. Final integrated checks and the exact launch candidate are in the recovery record.

Use current runtime capabilities and pinned model roles. Historical claims that Codex cannot use Git or must run only in a visual clone are superseded. Native windows stay off Andrew's workspace; GPU work takes the existing lock. Preserve both browser proofs and all unrelated owner changes.
