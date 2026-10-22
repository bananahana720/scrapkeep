# Roadmap, waves 18 to 21

Written 20 Oct 2026 after the [baseline](BASELINE-2026-10-20.md). It is linked from [GRAPH.md](GRAPH.md), which stays the live board. The goal and acceptance are in [DECISIONS.md](../handoff/DECISIONS.md) section 1. Andrew plays once at the end of wave 21. The sitting passes with 11 areas marked and none "Not yet", no open blocker, frame times in budget and zero placeholders.

## Budget

- **Two sources (corrected 21 Oct).** The weekly limit reset on 21 Oct at 19:00Z, earlier than this plan assumed, and resets weekly after that (next 28 Oct 19:00Z). It is the main fuel. Extra usage (credits) stood at $38.37 of the $50 monthly cap, so about $11.60 is left this month for urgent fixes only. The app shows no balance that matches the earlier "about $100", so plan on $11.60. Pacing: weekly % used stays at or below the share of the week gone plus 10 points. Above that, no new lanes start.
- **Calibration.** Wave 17's five Opus lane threads cost about $115 in one night (Perf $28, Systems B $36, Challenge $23, World-2 $13, parent $15).
- **Model mix (Andrew, 20 Oct).** Use Sonnet 5.5 everywhere it can go. Opus 5.5 medium is only for the stage promotion gate. A Sonnet lane costs an estimated one third of an Opus lane, so a five-lane wave runs about $35 to $45. ASSERTED (unverified). Measure it with `get_session` usage at the end of wave 18 and correct this line.
- **Rule.** A wave that would spend extra usage stops and asks before it starts a lane on credits.

## Carry-over into wave 18 (from the baseline)

| Unit | Lane | What it needs |
| --- | --- | --- |
| #175, #184, #207, #217, #232, #238 (Systems B w18 chain) | Systems B | Gate each head, then re-record `run_tier_test` pins once on the stage after #214 lands |
| Sable hard cell (#149) | Systems B | Rerun the capped rows at about 120 s; author no pack until that reads |
| #234 Warden spawn ring and the ruling 15 c′ mobs-connect half | World-2, Challenge | #234 alone makes the `posture_bands_swarm` camper break the hive and slows grown past 45 s; land it with the Warden-fight packs and re-pin the swarm bands once |
| #191, #208, #209, #237 (skill bands to Spillway) | Challenge | Gate #191 and #208, re-gate #209, then stack #237 |
| #220, #235 (dressing foundation, entry frames) | Dressing, Perf | Gate #220, then stack #235 |
| #204, #206, #224 | World, Gate | Re-gate on the current stage (their PASS names an older SHA) |
| #173, #222, #223, #225 to #228, #230 | Gate | Fast lane plus an independent reviewer, then stack |
| #214, #219 islands rows and flush liners | World | `audio_bake_cancel` FX-2 re-entry sees the bake already finished; make the test independent of park bake timing, or ask why the liners finish it early, then stack |
| #231 item-fuzz speed cap | Systems | Spawned enemies entering physics where they stand pushes Tally's `bot_brindle_short` heft from 1.30 to 1.36 (limit 1.30); fix or re-pin with a ruling, then stack |
| #137 Rivet slope budget | Perf, GPU bench | Waits on #73's 4080 carve check; rebase onto the stage then |
| ParkProps timing and the 4080 run | GPU bench | Queue rows for #235 and #236 |
| `scratch/local-*` branches | Coordinator | Triage from the PC inventory |

## Waves

| Wave | Must land | Lanes (Sonnet writers) | Gate extra | Est. credits |
| --- | --- | --- | --- | --- |
| 18 | Carry-over above. SR10 director cards. SI3 stage modifiers. Launch shell (AppImage, `.desktop`). Title-intro wiring. Dressing A. Anchor fields. Dense fights and stage entry perf. | Gate, Systems B, Challenge, Perf (4) | Base reds on `scratch/base-red-w16` | $0 to $20 (weekly limit first) |
| 19 | Camp hub follow-through. Linker behaviour. Six landmark GLBs. P4 to P6. Headframe. Boss freeze. Ambient life starts. | Gate, Systems, World, Perf (4) | Placeholder counts per lane | $0 to $25 |
| 20 | HELP and ACHIEVEMENTS refresh. FLASH-COMFORT. Bug bar. Placeholder burn-down to zero. PERF-NIGHT on the 4080 after the radio renders. | Gate, Systems, World, Content (4) | Frametime gate | $10 to $30 |
| 21 | ALPHA-RC AppImage. Last art holes. Final 4080 pass. Sitting Kit page. | Gate, World, Perf (3) | RC gate with `--win-proof` four proofs and five personas | $10 to $25 |

The total is $20 to $100. It fits only if each wave's first half runs on the weekly limit. If a wave closes short, the cut candidates below go first.

## Cut candidates, in order

Each one would need Andrew's call. None is cut yet.

1. **Ambient life (critters and locals).** It adds feel and is not on the 11-area acceptance list. Cost to the sitting: parks feel emptier.
2. **Dressing beyond hero props.** One prop kit per park instead of 12 or more kinds. Cost: less lived-in parks.
3. **Gamepad polish.** Already optional per ruling.

The following do not cut, because the acceptance gate needs them: zero placeholders, frame times in budget, the AppImage launch, all six dressed parks playable title to end, and the 81 radio takes. Since 21 Oct the difficulty work does not cut either: the skill-band targets in all six worlds and the HARD tier replay ladder. Andrew said the game must reach the challenge he expects. Challenge A owns worlds 1 to 3, and Challenge B owns worlds 4 to 6 and the ladder.

## Lanes added 21 Oct (Andrew: keep churning, split by discipline, CPU work on the cloud)

Cloud: Lighting, Grading, Animation, Effects, Challenge B, and Modeling (the wave 17 World Blender session, reused). PC: a render bench on the RTX 3060 for art stills, while the 4080 keeps perf. That makes 11 cloud lanes, over the old cap of 7, on Andrew's 21 Oct words. Pacing still applies: weekly % used stays at or below the share of the week gone plus 10 points. At 22:00Z, 3 hours in, it was 6%.

## Board grounding cards (22 Oct)

From the [board grounding](../../docs/art/reference/GROUNDING.md): ideas the approved boards suggest that nothing in the game or the roadmap yet carried. Each card cites its boards and follows the reference-before-making rule.

| Wave | Lane | Card | Scope | Depends on |
|---|---|---|---|---|
| 19 | Challenge | Resolve plate_press packs and place ballast_heavy where an edge is reachable | Fix the plate_press_draft/crown wall (board-241:308-334, 616-643), then place ballast_heavy in the Highdraft elite pack per WORLD-ROSTERS.md:80 so ring-out is a real answer. Tell the enemies board the heavy panel is valid only for the elite pack. Boards: Highdraft enemies / Wind | Challenge B ownership of worlds 4 to 6 |
| 19 | Effects | Pilot-neutral dunk and speed-cap cues from one record | Extend the existing dunk/soft-cap effects (player_fx.gd, contact.gd SOFT_CAP_SPEED 60, GRAPH SPEED-SOFTCAP card) so the stored-charge cue is a coil collar glow in the pilot's class colour with a ring or pip shape (no chevron, no mint for non-Sable), and the past-60 m/s trail keeps the heat ramp on rim/flecks with a class-colour rearward streak beneath. Sound and visuals read the same record. Keep mint to Sable and ancient green off the player. Boards: pilots-hardware-grapple-reel-dunk-moodboard, fx_ui-dunk-moodboard, fx_ui-speed-moodboard | Owner/coordinator ruling on trail look (default: heat ramp plus class streak); Systems dunk card |
| 19 | Gate/Docs | Land and cite the machine-lore and era rulings in DECISIONS; fix VISUAL-LANGUAGE war-machine wording | Confirm whether the 22 Oct machine-lore/era rulings (board-241 comment 6329943362, #277) exist on a newer stage. If not, write them into DECISIONS.md (utility fleet, Mind as foreman, looping workers, rogue permission). Then update VISUAL-LANGUAGE.md:19 ('ancient human war machine'), :57/:481 (Cherenkov blue to uranium green per DECISIONS.md:265) and :495. Re-point board citations that name DECISIONS:245/247 to lines that exist. Docs only. Boards: all six era boards, highdraft-arena-moodboard, hierarchy-chain-of-command, hierarchy-rogues-moodboard, fx_ui machine panels | Coordinator check of the newer stage branch for the rulings |
| 19 | Gate/Docs | Board correction pass: reference limits and REVIEW lines | One edit pass over BOARDS.md files adding do-not-copy lines: glass bubble canopy on pilot (ROSTER-LOOK.md:106), mast/winch positions (ROSTER-LOOK.md:419,519), unstriped INSTANT annulus, calm-water/plain-tier sinkhole, gatling mech, brood pod (follow honeycomb stage card), wide rectangular cave-in (draw three 4 m discs and 6 m bore per waking_attacks.gd:37-44), reel/dunk captions on Waking board (retitle; backdrop is Dig not Spillway), Cuff vs hand override, charged-reel armoured seam as look-only, lens placement deferred to the weak-points board, chevron on Mind hand lens, haul truck/tipper/lift relabelled as skin of the single pit incline skip, tall long-necked local as reference only, purple cloaked creature reference-only. No code. Boards: style-character-sable-reference, style-materials-moodboard, style-telegraphs-moodboard, style-lighting-moodboard, style-palette-moodboard, style-setpiece-reel-dunk-reference, dig-arena-waking-moodboard, dig-arena-waking-carve-drop, dig-landmarks-moodboard, bosses-world-boss-mind, bosses-weak-points-moodboard, highdraft-arena-moodboard, hierarchy-looping-workers-moodboard | none |
| 19 | Lighting/Dressing | Landmark readability and lighting-rule checks | Wave 19 lab checks: sinkhole always shows glazed wall band and cinder floor tell (DECISIONS.md:199-201); flume intake silhouette legible at speed with no new indicator unless it fails; dam water sheet brighter than the green beacon at dawn; Waking aperture daylight added to the Dig lighting spec once confirmed. Wave 20 fix only for failed checks. Boards: style-lighting-moodboard (AFTERNOON/SINKHOLE), spillway-landmarks-flume-carry, spillway-landmarks-dam-face, bosses-world-boss-waking | Owner confirm of Waking aperture (default yes) |
| 19 | Systems | Splitter ruling: ram-to-split | Apply the coordinator ruling consistently across splitter.gd:10-11, roster_specials.gd:21, POLES-FLAILS.md:110, MACHINE-VFX.md:29,32 and tools/priority_proof.md:99,114; or label the board. Default: keep code rule, label board. Boards: Kill-first specials | Coordinator ruling |
| 19 | World | Prop crew placement check | Add a plan-check row for prop_crew debris footprint versus ride line, same shape as the 30 m line-distance tier, with planted control. Spare supports stay outside the ride line. Boards: Prop crew reference | Dressing line-distance tier (board-241 ~2231) |
| 20 | Animation | Kite dive wind-up and ballast heavy brace clips | Two tells fitted to anim_tell_fit_test, plus a gameplay-distance legibility still for small ancient seams. Full set post-alpha. Boards: Highdraft Mind panel; Dig ancient | Animation wave 19 list (board-241:2024) |
| 20 | Dressing | Static vignettes and silhouette props using existing kits | Haul trucks as static terrace props at the Dig pit (no motion); closed furnace mouths and heat shields (nonemissive); bowl-exterior seized stock as brass-tagged non-colliding props; second keeper and rest alcove via park prop kit; Fleet devotion shrine as non-interactive prop named differently from blood_shrine; distant tether/collector skyline backdrops (no collider); two hero props per park (server farm, robotaxi) with purpose notes. Cut-first group. Boards: style-lighting-moodboard (NOON/DIG), spillway-combat-moodboard, spillway-crews-moodboard, hierarchy-fleet-devotion-moodboard, highdraft-props-moodboard, era-titans-scale-moodboard, era-cheerful-dystopia-moodboard | #269 dressing kit; purpose notes (DECISIONS.md:239); Perf budget #235 |
| 20 | Effects | Telegraph clearance gate: no dust/sparks/hit bursts inside live threat footprints | Gate hit-burst, dust and spark emitter spawns in telegraph.gd/juice.gd against live threat footprints (VISUAL-LANGUAGE.md:126 rule). Test plants a footprint and expects zero emitter points inside, plus a positive control. Lighting writes it if Effects stays parked. Boards: style-telegraphs-moodboard (FIGHT) | Lighting draw-order work (board-241 6329414841) |
| 20 | Gate/Grading | Cannon seam exception and green-isolation harness check | Recorded in VISUAL-LANGUAGE and DECISIONS on 22 Oct (this PR); what is left is the harness check. Record the Cannon ancient-green seam exception in VISUAL-LANGUAGE.md and DECISIONS; add a harness check that green seams appear on no other player part. Boards: pilots-reference-cannon-heft-study | none |
| 20 | Modeling | Clear inner cockpit sphere | Make the pod's Dome (ROSTER-LOOK Pod > Dome) a clear or semi-opaque sphere that stays level, per Andrew's 22 Oct lore and the ROSTER-LOOK Inner cockpit sphere row. The lattice stays the outline; husk growth is visual overhang inside the radius-1.0 collider. Check the pilot's head still reads at 147 px chase size through it. Boards: pilots-balls-heft-moodboard, pilots-cockpits-roster-moodboard | none |
| 20 | UI | Tally spent-window state check | Tally's clip is 3 (PILOTS.md:17), so there is no fourth slot. Check that each spent window of the three reads by shape plus colour in the HUD; fix only if missing. Boards: pilots-reference-tally-ledger-controls | none |
| post-alpha | Challenge | Brindle hatch weak point (stretch) | One hatch reusing weak_points.gd that opens on a named tell and removes the crane attack family; only if U4 for the Waking and Mind lands at dial 1. Boards: bosses-world-boss-brindle | U4 weak-point rule object landing; owner ask |

## Pilot ball motion fixes (22 Oct)

From the [motion spec](../../docs/art/reference/MOTION-SPEC.md). Each fix keeps the physics as it is and changes only what the ball draws.

| Wave | Lane | Card | Owner call |
|---|---|---|---|
| 19 | Systems | Take the cockpit out of the juice transform | no |
| 19 | Systems | Stop the heft inflation (shell size 1.0 on Hoberman shells) | yes, default in the spec |
| 20 | Animation | Replace the jelly squash with a lattice-only clench | no |
| 19 | Animation | Drive the gimbal rings from the carrier's bank, not the lattice's tumble | no |
| 20 | Systems | Bank the carrier off steep faces (a sideways twin of rule 6) | no |
| 19 | Systems | The rope leaves the collar fairlead, never the centre | no |
| 20 | Systems | Keep the spin through mid-air velocity sets | no |
| 20 | Systems | Couple the cableway ride to the cable | no |
| 20 | Animation | Pod yaw rules: clamp to the camera, face the anchor, slow the reversals | no |
| 20 | Effects | Wagon-wheel strobe treatment | no |
| 20 | Modeling | Inner cockpit sphere: place it in the ladder or cut it | yes, default in the spec |
| 20 | Modeling | Record the radius ladder and pin it | no |
| 20 | Effects | Dunk charge on the level carrier, in class colour | no |
| 19 | Systems | Motion capture tooling for real frames | no |
| 19 | Effects | Check that the placeholder glide wings hide on hero shells | no |
| post-alpha | Systems | Ceiling rolls and low gravity stay as proposals | yes, default in the spec |

## Fixed dates

- 21 Oct, 19:00Z. The weekly limit reset; wave 18 lanes started about 21:00Z. Next reset 28 Oct 19:00Z.
- End of wave 21. Andrew's one sitting.
