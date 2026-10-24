# Roadmap, waves 18 to 21

Written 20 Oct 2026 after the [baseline](BASELINE-2026-10-20.md), refreshed 22 Oct. It is linked from [GRAPH.md](GRAPH.md), which stays the live board. The goal and acceptance are in [DECISIONS.md](../handoff/DECISIONS.md) section 1. Andrew plays once at the end of wave 21. The sitting passes with 11 areas marked and none "Not yet", no open blocker, frame times in budget and zero placeholders.

## Pacing

- **Fuel.** The weekly limit is the main fuel. Pacing: weekly % used stays at or below the share of the week gone plus 10 points. Above that, no new lanes start. A wave that would spend extra usage stops and asks before it starts a lane on credits.
- **Model mix (Andrew, 20 Oct).** Use Sonnet 5.5 everywhere it can go. Opus 5.5 medium is only for the stage promotion gate. See AGENTS.md for the pins.
- **Test pace and CPU placement (22 Oct).** Focused tests per PR and one full gate per promotion; CPU-only work runs in the cloud by default. See the Test pace and CPU placement rulings in [DECISIONS.md](../handoff/DECISIONS.md) section 10.

## Carry-over into wave 18

The baseline carry-over is on the wave 18 lane rows in [GRAPH.md](GRAPH.md), and current heads and holds are in [STATE.md](../handoff/STATE.md). The 20 Oct list and findings are in the repository history.

## Waves

**World 1 first (Andrew, 23 Oct 19:29-19:31Z; DECISIONS.md section 1).** All effort goes to a 100% finished world 1 (Spillway: dam and flume) and early progression, played at a world 1 sitting: a 10-15 min average run, about 30 min for a completionist, repeatable. The sitting's timing is a card (recommended: end of wave 19, in place of the dropped feel check). Worlds 2 and 3 finish the work already running and start nothing new until world 1 is done. Afterwards the game scales out with layered, repeatable variety (stage variants, run modifiers) as design seeds of our own. Read the table below in that order: its world 1 units come first, and its worlds 2 and 3 units wait. Wave 19 also carries the fight phases (#391), the rogue crane (#385, #388) and the item panel core (#392); wave 20 the item rung table and cobalt guarantees.

Wave 19 leads with gameplay, map and music (DECISIONS.md section 10, 22 Oct). In-flight wave 18 park kits and dressing finish first. Asset work happens only where a gameplay unit needs it.

| Wave | Must land | Lanes (Sonnet writers) | Gate extra |
| --- | --- | --- | --- |
| 18 | Carry-over on the GRAPH rows. SR10 director cards. SI3 stage modifiers. Launch shell (AppImage, `.desktop`). Title-intro wiring. Dressing A. Anchor fields. Dense fights and stage entry perf. | Gate, Systems B, Challenge, Perf | Base reds on `scratch/base-red-w16` |
| 19 | Random terrain-driven mini-bosses per stage. Risk-versus-reward lines. The earned retry item and the death-to-rolling restart time. Music in play. Linker behaviour. Boss freeze. Pilot motion fixes. Landmark GLBs, P4 to P6 and the headframe only where a gameplay unit needs them. Ambient life starts. | Gate, Systems, Challenge, World, Perf | Placeholder counts per lane |
| 20 | HELP and ACHIEVEMENTS refresh. FLASH-COMFORT. Bug bar. Remaining landmark and dressing work. Placeholder burn-down to zero. PERF-NIGHT on the 4080 after the radio renders. | Gate, Systems, World, Content | Frametime gate |
| 21 | ALPHA-RC AppImage. Last art holes. Final 4080 pass. Sitting Kit page. | Gate, World, Perf | RC gate with `--win-proof` four proofs and five personas |

If a wave closes short, the cut candidates below go first.

## Cut candidates, in order

Each one would need Andrew's call. None is cut yet.

1. **Ambient life (critters and locals).** It adds feel and is not on the 11-area acceptance list. Cost to the sitting: parks feel emptier.
2. **Dressing beyond hero props.** One prop kit per park instead of 12 or more kinds. Cost: less lived-in parks.
3. **Gamepad polish.** Already optional per ruling.

The following do not cut, because the acceptance gate needs them: zero placeholders, frame times in budget, the AppImage launch, all six dressed parks playable title to end, and the 81 radio takes. Since 21 Oct the difficulty work does not cut either: the skill-band targets in all six stages (3 worlds of 2 stages) and the HARD tier replay ladder. Andrew said the game must reach the challenge he expects. Challenge A owns stages 1 to 3, and Challenge B owns stages 4 to 6 and the ladder.

## Lanes added 21 Oct (Andrew: keep churning, split by discipline)

Cloud: Lighting, Grading, Animation, Effects, Challenge B, and Modeling (the wave 17 World Blender session, reused). PC: a render bench on the RTX 3060 for art stills, while the 4080 keeps perf. That makes 11 cloud lanes, the cap, on Andrew's 21 Oct words (the old cap was 7). Pacing still applies.

## Board grounding cards (22 Oct)

From the [board grounding](../../docs/art/reference/GROUNDING.md): ideas the approved boards suggest that nothing in the game or the roadmap yet carried. Each card cites its boards and follows the reference-before-making rule.

| Wave | Lane | Card | Scope | Depends on |
|---|---|---|---|---|
| 19 | Challenge | Resolve plate_press packs and place ballast_heavy where an edge is reachable | Fix the plate_press_draft/crown wall (board-241:308-334, 616-643), then place ballast_heavy in the Highdraft elite pack per WORLD-ROSTERS.md:80 so ring-out is a real answer. Tell the enemies board the heavy panel is valid only for the elite pack. Boards: Highdraft enemies / Wind | Challenge B ownership of stages 4 to 6 |
| 19 | Effects | Pilot-neutral dunk and speed-cap cues from one record | Extend the existing dunk/soft-cap effects (player_fx.gd, contact.gd SOFT_CAP_SPEED 60, GRAPH SPEED-SOFTCAP card) so the stored-charge cue is a coil collar glow in the pilot's class colour with a ring or pip shape (no chevron, no mint for non-Sable), and the past-60 m/s trail keeps the heat ramp on rim/flecks with a class-colour rearward streak beneath. Sound and visuals read the same record. Keep mint to Sable and ancient green off the player. Boards: pilots-hardware-grapple-reel-dunk-moodboard, fx_ui-dunk-moodboard, fx_ui-speed-moodboard | Owner/coordinator ruling on trail look (default: heat ramp plus class streak); Systems dunk card |
| 19 | Gate/Docs | Fix VISUAL-LANGUAGE war-machine wording (rulings landed 22 Oct) | The machine-lore, Mind's reach and era rulings are in DECISIONS (done). What is left is `sketches/core-loop/VISUAL-LANGUAGE.md`: the 'ancient human war machine' line near the top becomes utility fleet, and the Cherenkov blue wording for the ANCIENT colour becomes uranium green (see Older rulings in DECISIONS: ancient light). Docs only. Boards: all six era boards, highdraft-arena-moodboard, hierarchy-chain-of-command, hierarchy-rogues-moodboard, fx_ui machine panels | none |
| 19 | Gate/Docs | Board correction pass: reference limits and REVIEW lines | One edit pass over BOARDS.md files adding do-not-copy lines: glass bubble canopy on pilot (ROSTER-LOOK.md:106), mast/winch positions (ROSTER-LOOK.md:419,519), unstriped INSTANT annulus, calm-water/plain-tier sinkhole, gatling mech, brood pod (follow honeycomb stage card), wide rectangular cave-in (draw three 4 m discs and 6 m bore per waking_attacks.gd:37-44), reel/dunk captions on Waking board (retitle; backdrop is Dig not Spillway), Cuff vs hand override, charged-reel armoured seam as look-only, lens placement deferred to the weak-points board, chevron on Mind hand lens, haul truck/tipper/lift relabelled as skin of the single pit incline skip, tall long-necked local as reference only, purple cloaked creature reference-only. No code. Boards: style-character-sable-reference, style-materials-moodboard, style-telegraphs-moodboard, style-lighting-moodboard, style-palette-moodboard, style-setpiece-reel-dunk-reference, dig-arena-waking-moodboard, dig-arena-waking-carve-drop, dig-landmarks-moodboard, bosses-world-boss-mind, bosses-weak-points-moodboard, highdraft-arena-moodboard, hierarchy-looping-workers-moodboard | none |
| 19 | Lighting/Dressing | Landmark readability and lighting-rule checks | Wave 19 lab checks: sinkhole always shows glazed wall band and cinder floor tell (Sinkhole rulings in DECISIONS section 8); flume intake silhouette legible at speed with no new indicator unless it fails; dam water sheet brighter than the green beacon at dawn; Waking aperture daylight added to the Dig lighting spec once confirmed. Wave 20 fix only for failed checks. Boards: style-lighting-moodboard (AFTERNOON/SINKHOLE), spillway-landmarks-flume-carry, spillway-landmarks-dam-face, bosses-world-boss-waking | Owner confirm of Waking aperture (default yes) |
| 19 | Systems | Splitter ruling: ram-to-split | Apply the coordinator ruling consistently across splitter.gd:10-11, roster_specials.gd:21, POLES-FLAILS.md:110, MACHINE-VFX.md:29,32 and tools/priority_proof.md:99,114; or label the board. Default: keep code rule, label board. Boards: Kill-first specials | Coordinator ruling |
| 19 | World | Prop crew placement check | Add a plan-check row for prop_crew debris footprint versus ride line, same shape as the 30 m line-distance tier, with planted control. Spare supports stay outside the ride line. Boards: Prop crew reference | Dressing line-distance tier (board-241 ~2231) |
| 20 | Animation | Kite dive wind-up and ballast heavy brace clips | Two tells fitted to anim_tell_fit_test, plus a gameplay-distance legibility still for small ancient seams. Full set post-alpha. Boards: Highdraft Mind panel; Dig ancient | Animation wave 19 list (board-241:2024) |
| 20 | Dressing | Static vignettes and silhouette props using existing kits | Haul trucks as static terrace props at the Dig pit (no motion); closed furnace mouths and heat shields (nonemissive); bowl-exterior seized stock as brass-tagged non-colliding props; second keeper and rest alcove via park prop kit; Fleet devotion shrine as non-interactive prop named differently from blood_shrine; distant tether/collector skyline backdrops (no collider); two hero props per park (server farm, robotaxi) with purpose notes. Cut-first group. Boards: style-lighting-moodboard (NOON/DIG), spillway-combat-moodboard, spillway-crews-moodboard, hierarchy-fleet-devotion-moodboard, highdraft-props-moodboard, era-titans-scale-moodboard, era-cheerful-dystopia-moodboard | #269 dressing kit; purpose notes (Purpose before making ruling); Perf budget #235 |
| 20 | Effects | Telegraph clearance gate: no dust/sparks/hit bursts inside live threat footprints | Gate hit-burst, dust and spark emitter spawns in telegraph.gd/juice.gd against live threat footprints (VISUAL-LANGUAGE.md:126 rule). Test plants a footprint and expects zero emitter points inside, plus a positive control. Lighting writes it if Effects stays parked. Boards: style-telegraphs-moodboard (FIGHT) | Lighting draw-order work (board-241 6329414841) |
| 20 | Gate/Grading | Green-isolation harness check | The Cannon seam exception is recorded in DECISIONS (Boards are grounded, item f) and in VISUAL-LANGUAGE (done). What is left is a harness check that green seams appear on no other player part. Boards: pilots-reference-cannon-heft-study | none |
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

- 21 Oct, about 21:00Z. Wave 18 lanes started.
- End of wave 21. Andrew's one sitting.
- Both sittings: play fullscreen on the ultrawide (DP-1). VRR is on there only for fullscreen windows, which matches players' adaptive-sync screens; the HDMI monitor has no VRR.
