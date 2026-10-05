# Alpha handoff: checkpoint 1 passed, 3 October 2026

**Checkpoint 1 passed** (playtest entry 12, EV-0624). Andrew: "really fun", "getting really close", boss "much, much more refined"; difficulty 2, pacing 3, clarity 4; all seven calls kept. He asked for the full three-world alpha for a multi-hour sitting: "full-send it to complete the game." The hard gate is open: Dig and Highdraft may be built. The coordinator role is back with the Claude session that recorded EV-0623 and EV-0624; Codex owns the Sol asset lane only.

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
5. Mind codex rows (lane, split_lane, rush) fired 0 times in the win proof; only forced tests prove them.
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
