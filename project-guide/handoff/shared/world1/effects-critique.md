# World 1 effects critique (12 Nov 2026)

Andrew asked on 12 November 2026 for a deep and wide design critique of world 1 (the Spillway), split into silos. This page is the effects silo: hit and kill feedback, sound words, warnings, projectiles and abilities, Brindle's phases, the world's water, steam and light, screen effects and how they line up with sound. Gameplay and visual assets have their own critiques in sibling threads. Transitions between stages are already audited in [transitions-audit.md](transitions-audit.md) and are only cross-referenced here.

Read at `stage/alpha-w38` 46de0578 and re-checked on `stage/alpha-w39` 7811fa5d (no effect file changed between them). Each finding is judged clarity first (does the effect say what happened and what to do, without hiding the ball or a threat), then delight (melodramatic comic, Scott Pilgrim, the 2010 look of ruling cr). The buildable rows (FX-01 to FX-25) are in [BACKLOG.md](../../../../BACKLOG.md#world-1-effects-critique-rows-12-november-2026); this page keeps the evidence.

## The short version

The warning language is the strongest part of the game's effects. Hostile marks are one red, drawn above everything the player makes, and no player effect can cover them (`threat_grammar.gd:57-66`, `player_fx.gd:29-31`). The rest has three real weaknesses for the sitting.

1. **A kill looks like a bigger hit.** The kill uses the same copper star as an ordinary hit, a ninth larger than a hard hit's, and its particle pop is nearly invisible. The game's most frequent payoff has no punctuation of its own.
2. **Hit and stun feedback disappear on the Spillway's sand.** Copper sparks on sandstone have little contrast, and the stun halo, the only sign a pack enemy is stunned, draws a few dozen pixels.
3. **Brindle's phase turns do not show the new rule.** The words were rightly cut (PF-26), but nothing took over their job, and the last turn, to the scooter chase, has no beat at all. The rout's blasts go off at the empty ship, not at the scooter the player just caught.

Below those sit colour overloads (amber, mint and ancient green each carry several meanings), a hostile landing with no impact, a hit-taken cue that fades to almost nothing under Reduced motion, and environment effects that are silent and static. Worlds 2 and 3 inherit two particle libraries, six word stampers and no single budget table.

## How it was judged

| Source | What it can settle | What it cannot |
| --- | --- | --- |
| Code on the stage, read by four read-only inventory agents (one per bucket), then the key claims re-read by hand | what draws, when, in which colour, and with which sound | how it looks |
| Cloud stills on the stage head: `tools/fx_capture.gd` at 0.1, 0.35, 0.6 and 0.85 of life, and at 0.35 with Reduce flashes | size, placement, presence over time, and the `drawn_px` and `contrast` numbers relative to each other on one machine | final colour, glow and frame cost (llvmpipe, Compatibility renderer) |
| The wave 37 first-timer film (cand/w37 ca6daa8b, cloud) | clutter and layout as a stranger met it | anything fixed since (PF-26 hit words, PR 796) |
| The GPU first-timer film of cand/w40 6b9cb42e on the 4080 at 1080p (the visual critique's PC job) | look and placement in play | sound, and the effect strips over life |
| PC strips, reel and Brindle stills, queued on the board thread for the same head | look, glow, frame time | see "Owed" |

One inventory claim was wrong and is not a finding: a near miss sends no hit-stop on purpose, because the ball's motion keeps its momentum (`juice.gd:42-48`, `event_kinds.gd:425`). Its unused `stop_ms` row (`event_kinds.gd:258`) is dead data.

## Inventory

The tables are summarised by family here. The findings below cite file and line for each effect they judge.

| Family | Effects | Owner files | Paired sound |
| --- | --- | --- | --- |
| Hits and kills | hit glyph and sparks, crit, hit-stop, shake, kill pop and debris, multi-kill ring, kill-chain pips, damage numbers, glance | `vfx.gd`, `juice.gd`, `damage_numbers.gd`, `fx_library.gd` | hit_thwack, crit_ping, kill_pop by chain rung, clank; all on the same frame except a kill pop held by density |
| Player moments | sound words (15 plus pilot voices), BWAP, impact frame, overdrive burn, carve sparks, growth column, aura motes | `player_fx.gd` | only BWAP (the on-beat sax stab); the other words are silent by design (PLAYER-FX.md "Open") |
| Status and armour | daze halo, KRNK, interrupted star, DENT and ZZAP!, armour icon | `machine_fx.gd`, `status_marks.gd`, `armour_marks.gd` | stagger chord on bosses; none on pack enemies |
| Hit taken | edge flash toward the source, number, wince | `juice.gd:687-703`, `edge_flash.gd` | hurt |
| Warnings | ground ring, wedge, lane, wave front, shell and landing ring, landing flash, live scorch, danger diamond, wind-up poses | `threat_grammar.gd`, `telegraph_record.gd`, `windup_poses.gd`, `danger_mark.gd` | threat_tick, hum, whistle, whoosh |
| Abilities | aim and charge shapes, bolts, harpoon cable, pilot rings and arcs, ultimates, item rings | `indicator.gd`, `effects.gd`, `line_view.gd`, each pilot's kit, `ultimate.gd`, `actives/` | per verb |
| Brindle | arrival (rise, glance, inset, card, slow motion), crane sweep, slag rings, charge lane, phase bursts and captions, crowd and ledger, stagger, eject, rout, Tarn sign-on | `flourish_rows.gd`, `flourish_cues.gd`, `boss.gd`, `machine_fx.gd`, `arena_bowl_yard.gd` | boss_arena_in, boss_telegraph, ratchet cue, boss_phase, phase anthems, stinger_boss_defeated |
| World | mist, midges, falls, wake and splash, steam and soot, flood foam, dam curtain, penstock vent, water surface, landmark beam, fog and grade | `world_fx_specs.gd` (one data table), `spillway_fx.gd`, `spill_water.gdshader`, `landmark_beam.gd` | none on any of them |
| Screen | launch swipe, flourish words and cards, edge flash, impact frame | `launch_take.gd`, `flourish_player.gd` | launched whoosh, stings |

## Findings, ranked by how much they change the sitting

### E1. A kill has no punctuation of its own (clarity and delight, major)

What the code does. A hit draws a copper `burst` star of 0.4 to 1.6 m for 0.14 s (`vfx.gd:602-607`). A kill draws the same copper `burst` star of 0.6 to 1.8 m for 0.3 s, a pop and debris (`vfx.gd:924-931`); the two rows share colour and shape (`event_kinds.gd:57`, `:77`). A hard hit's star is nine tenths the size of a kill's. The kill debris uses the colour of lost scrap (`vfx.gd:931`), so a win is drawn in the loss colour. Under a dense fight, kills within 120 or 200 ms merge into one pop on purpose (`density.gd:32-39`, FEEL-READABILITY.md section 1.2), but each kill's sound plays at once (`audio.gd:3334`), so the sound can land before its pop. The star is copper for every pilot, though VISUAL-LANGUAGE.md section 2 says a kill pop takes the class colour.

What the stills show, and what they do not. `tools/fx_capture.gd` shoots the particle layers, not the star glyphs. On the sand, at 0.1 of life, the kill's pop draws 63 changed pixels and by 0.35 it draws 2; an ordinary hit's core and halo draw 3,614 and the crit 8,778 (cloud, same machine, same ground; see [the strip](effects-critique/kill-vs-hit.jpg)). The tool fires 24 hit sparks where the game fires 16 (`fx_capture.gd:150`, `event_kinds.gd:233`), so the game's hit is about a third smaller than the strip, still well above the kill's pop. Of the kill's particles only the debris (1,684 px) is seen, as small orange crumbs. The PC strip on the RTX 3060 (branch `scratch/fx-critique-w38` 9c942544, same head) agrees: at 0.1 of life the kill's pop draws 40 px and its debris 930, a hit's core and halo 1,470 and a crit 4,635; at 0.35 the pop draws 0. The star itself is not in the strip; the PC sight reel's death clips show it in play.

Why it matters. Killing is the beat the run repeats most. The TONE-BIBLE gives a downed machine a "shift over" gag, and the mission promises Isaac-style payoff. Today a kill is told apart from a hit by the enemy's own death clip and a sound, not by the effect layer.

Direction. A kill-only look and timing, owned by `vfx.gd`'s kill pop: still a starburst (VISUAL-LANGUAGE.md section 3 gives the kill pop that shape), but ink-outlined and two-tone so it does not read as the hit star, a one-frame white body flash, then the body's own shards (`shell_shards`, already the strongest-reading spec at contrast 117), in the class colour. Merging stays; the kill sound waits for its merged pop, so sight and sound land together. This is a taste pick with candidates (see "For Andrew").

### E2. Hit sparks and the stun halo vanish on the Spillway's ground (clarity, major)

Kinetic hit sparks, the commonest kind, are copper (`b77843`) on sandstone (`c6a274`) (`juice.gd:546`). On the cloud strip the hit core draws 748 px at contrast 62 at 0.35 of life; the stun halo (`daze_halo`, `fx_library.gd:88`) draws 40 px at contrast 35, and the fuse sputter 9 px. The sight thread's PC effect strips of 10 November (method in `design-v3/SIGHT-PERSONA.md` section 7) measured the same: `daze_halo` 23 px and `fuse_sputter` 4 of 256,000. It was left for after the sitting. The PC strip of this critique (3060, `scratch/fx-critique-w38` 9c942544) reads `daze_halo` 17 px at 0.1 and 11 at 0.35, and the hit core's contrast 45 and 52. The halo is the only sign a pack enemy is stunned, and a stun is a window the player is meant to spend. Damage numbers are copper too, with a 1.5 px shadow and no outline (`damage_numbers.gd:159`); VISUAL-LANGUAGE.md section 2 already says copper text on charcoal needs bold 18 px or a lighter tint; on sand it has less contrast still.

Direction. The 2010 comic finish is ink: give hit sparks a dark ink core under the bright one so they read on pale and dark ground alike, make the stun a ring of ink stars at about twice the size circling the head, and give damage numbers an ink outline. Pass line: on the PC strip at 0.35, the stun halo draws at least four times today's pixels and the hit core keeps contrast 60 or more on sand; the sight reel shows both on the dam's concrete.

### E3. Brindle's phase turns do not show the new rule; the chase has no turn at all (clarity, major)

Phase two and three now carry one caption each (`flourish_rows.gd:151-168`), a joke in Brindle's voice. The PF-26 fix rightly removed FURNACE LIT, ARMOUR OFF and KA-CHUNK, and named the plates, ring and melt as the carriers of the turn. Those carriers say "something changed", not "what to do now": the slag rings and the charge lane appear for the first time as live attacks. The turn into the scooter chase (`boss.gd:1103`, phase 4) has no flourish row, only an EJECT word and a chunk burst (`machine_fx.gd:743-745`), though the goal flips from hitting the hull to catching the scooter. The TONE-BIBLE asks for a one-second comic panel at each phase turn.

The PC film confirms it ([stills](effects-critique/pc-brindle-w40.jpg); GPU first-timer film of cand/w40 6b9cb42e, RTX 4080, 1080p, pictures 120, 125 and 144). At phase two the screen shows BWAP, a target tag and the caption, and nothing of the slag rings to come. At the chase turn the camera looks into the ship's dark hull: the goal line says "Ram the Admiral's scooter", and the scooter is not on screen.

Direction, by ruling cx's carrier order (shape and motion before words). In the 2.0 s phase beat, while no attack can commit (`src/combat/fight_phases.gd:28`, `boss.gd:331`, `:722`), the next phase's signature mark draws once as a harmless preview: the slag ring as a bone dashed outline where it will stand, the charge lane as a dashed lane from the ship's nose. The chase gets its own beat: a short glance that follows the scooter's arc and a target tag on it. Shape lives in `threat_grammar.gd`'s harmless style, which exists (`threat_grammar.gd:34`, `:208-213`, `:345`), so no new look is invented; any motion added to the preview (a fill or a sweep) would be a new mark and goes through LEGIBILITY review.

### E4. The rout's blasts go off at the empty ship (clarity and delight, minor)

`_defeat` hides the scooter (`boss.gd:1165-1167`) before `boss_defeated` is published, and `_brindle_at` returns the scooter only while it is visible (`machine_fx.gd:731-733`), so the five fall blasts and the ring play at the abandoned ship, while the player is at the scooter they just stomped. Read from code; the PC Brindle stills will show whether the ship is in view. Direction: the fall plays where the catch happened, by passing the place with the event (the event bus already carries `at:` for announced events since PR 798).

### E5. A hostile landing does not land (clarity, minor)

When a ring or lane goes live, it flashes a flat fill for 0.22 s and leaves a scorch (`threat_grammar.gd:76`, `:151-152`, `:1334-1359`). There is no ink crack, dust kick or kick on the attacker, so a hit taken has no visible cause at its moment; PF-16's reader could not say what hit them on the dam. Wind-ups are mild: at most a 32 degree yaw, a 0.80 to 1.14 squash in the wind-up and 1.18 at release (`windup_poses.gd:12-35`). Direction: a short ink crack ring and dust kick at the mark's edge when it goes live, and a one-frame hazard flash on the attacker's body at release, so cause and effect sit on the object, as DECISIONS.md's standing rule asks: "Every mechanic shows its cause on the object before you act and its effect when it lands." This feeds the safe-side work in "Show safe side on yard telegraphs" (W1-05); it does not repeat it.

### E6. One colour, several meanings (clarity, minor)

| Colour | Meanings today | Evidence |
| --- | --- | --- |
| Amber `e5a044` | scrap and world rewards, near miss, stun halo, panel pop, kill-chain top rung, part pickup, Kest's class colour, a batted shell, the silo and quake item rings (drawn with the hostile threat code at hostile priority) | `event_kinds.gd:48-50,159`, `fx_library.gd:89`, `projectile.gd:124`, `silo_battery.gd:97`, `class_def.gd` |
| Mint `8bf0d3` | "live" (your verb works now), Sable, every ultimate cue, Kest's ride rings, a bet won, and the jolt layer's fallback coil, an enemy part | `palette.gd:33`, `kest_kit.gd:349`, `vfx.gd:259`, `jolt_layer.gd:67` |
| Ancient green `9dff3c` | ancient machines and ancient light (ruled), and also the player's frost damage numbers, motes and part fountains, and the Cannon's ultimate ring | `damage_numbers.gd:24`, `player_fx.gd:45`, `ultimate.gd:1110` |
| Rust `9b513a` | Fleet body paint, "you lost something", Tarn's class colour and rings | `lobber.gd:19`, `tarn_claw.gd:370` |
| Copper `b77843` | Rivet's class colour, and every pilot's hit and kill star | `event_kinds.gd:57,77` |

VISUAL-LANGUAGE.md forbids mint on enemy parts (`:46`) and reserves ancient green (`:51-54`). The fix is not a repaint pass; it is a meaning table the code reads, and a test that fails an effect using a reserved colour outside its meaning (row FX-20). Then each overload is one row change.

### E7. Under Reduced motion the hit-taken cue nearly disappears (clarity, accessibility, minor)

Damage taken never shakes the camera (ruled), so the edge flash is the hit's only direction cue. Its alpha is 0.65 times 0.6 to 1.0, times `min(flash_scale, ...)`, where `flash_scale` is 0.25 under Reduced motion and 0.55 under Reduce flashes (`juice.gd:703`, `edge_flash.gd:33`): about 0.1 for a light hit under Reduced motion. On the PC, Reduce flashes alone halves the flash's brightness rise (p99 0.123 off, 0.063 on, `flash/peak.txt` on `scratch/fx-critique-w38`). Direction: keep the dimming for the flash, but hold a steady carrier that is not a flash (an ink notch at the screen edge toward the source for 0.4 s) at full strength in every mode.

### E8. Words come from six stampers with six rules (clarity, minor; scaling)

Player sound words (`player_fx.gd`) keep a screen-share size, a warning gap of 24 px and a repeat budget. Armour words DENT and ZZAP! (`armour_marks.gd:67-140`) each stamp once per armour class per run, so they are rare, but they have none of the placement rules: a fixed 0.86 m world size, no clamp, no warning avoidance, no render priority, stacked with the stagger word, the interrupted star and the armour icon inside about one metre above the enemy. KRNK and EJECT (`machine_fx.gd`), the panel pop (`panel_fx.gd`), the flourish words (`flourish_player.gd`) and the damage numbers each place themselves, and two of them test "dense" differently (`player_fx.gd:689` max > 0.7, `machine_fx.gd:351` value >= 0.7). PF-26 was this problem seen from the player's chair, and the PC film still shows it at the rout: the flourish's FWOOMP stamps across the player's WHUMP (picture 147, in [the stills](effects-critique/pc-brindle-w40.jpg)). Direction: one module owns placement, size, priority, warning avoidance and the word budget; the others ask it for a slot (deep module, one small call).

### E9. The rout is named four times in ten seconds (words, minor)

The ROUTED stamp (`flourish_rows.gd:175`), the BRINDLE ROUTED card (`worlds.gd:24`), and "Admiral routed" again on the `spillway_clear` card and captions; the in-run arrival card repeats the title intro's card word for word (`flourish_rows.gd:140`, `title_intros.gd:45`). Ruling cx: one name for one thing. Direction: the stamp is the rout; the card says what the player won.

### E10. The world's effects are silent and the water is still (delight, after the sitting)

No splash, falls, steam, vent or flood foam has a sound (the SPLOSH word is drawn, not heard). The water shader takes no time input, so the spill sheets do not move (`spill_water.gdshader`). Spillway steam is alpha 0.85 up to 6.3 m and its anchors skip the 7 m clear zone around the ball (`world_fx_specs.gd:164`). Midges are near-black specks at ball height at full alpha (`world_fx_specs.gd:54`), which could read as a pickup or a mine; that one needs the PC still. Direction: the sounds go to the sound thread as gaps; moving water and the steam's clear zone are one row after the sitting, with a PC cost read first.

### Looks the gameplay critique needs

The gameplay critique (`gameplay-critique.md` in this folder, [PR 856](https://github.com/bananahana720/scrapkeep/pull/856)) has three rows whose look belongs here, and they should be built with these carriers rather than new ones. W1-61 (Brindle reels and sheds scrap when a chunk breaks early) uses the phase-turn burst and the dropped-scrap trail Brindle already has. W1-68 (the plating lesson on the first deflected strike) needs the glance to read apart from a hit: today a glance is a slate `burst`, the hit's shape, for 0.15 s (`vfx.gd:297-301`), so FX-01's rule (hit, glance and kill each get their own silhouette) covers it. W1-74 (a paid chain of three or more drops a scrap burst stepped by combo) rides the kill-chain pips and the scrap sparkle (`vfx.gd:991-1017`, `:641`), which use amber and so join FX-20's colour table.

### Checked and fine

- Hostile warnings always draw above player effects, and the impact frame skips any wedge that would cross a warning (`threat_grammar.gd:57-66`, `player_fx.gd:29-31`). The ART-MISTAKES row of 22 October (hit bursts never drawn with warnings) is closed in code.
- BWAP now repeats at most every 4 s, words keep 24 px off warnings and never name the foe they cover (`player_fx.gd:104-118`, PR 796). The w37 film predates this.
- Hit-stop is bounded (90 ms onset gap, 60 ms per 300 ms, 100 ms per second, 60 ms cap) and never fires on the ball's own motion.
- Hit sparks, kill pop and sounds fire on the same frame except the density-held pop (E1).
- Docs disagree with code on hit-stop for ordinary hits (VISUAL-LANGUAGE.md:371 says none; code gives 12 to 40 ms) and on the hit-taken look (FEEL-READABILITY.md:208 says an iron-oxide vignette for 0.25 s; code draws a hazard edge flash for 0.4 s). Code is what was tuned and played; the docs are corrected in row FX-25.

## How the effects system scales to worlds 2 and 3

| Today | Cost when a world is added |
| --- | --- |
| World air, landmarks and anchors are rows in one table, `world_fx_specs.gd` (446 lines), on generic modules (`world_fx.gd`, `world_fx_kit.gd`, `world_fx_anchor.gd`, `world_fx_grain.gd`) | cheap: a world adds rows |
| `dig_fx.gd` (288 lines) and `highdraft_fx.gd` (309 lines) are hand-written on a second particle library (`fx_library.gd`, 486 lines), each with its own preset hookup, low-quality halving, reduced-motion handling and colour constants | a fourth world copies a fifth file |
| Ceilings live as constants pinned by tests (ambient 330, anchors 760, fx_library 752, machine 876); bursts, the landmark beam and water cards sit outside them; there is no budget table | nobody can say a world's total effect cost |
| One warning grammar for all worlds (ruled); boss phase bursts share one table (`machine_fx.gd:88-97`) | cheap |
| Only Brindle has in-run flourish rows; the Waking and the Mind have none | each boss needs rows and its own phase preview (E3) |
| Six word stampers (E8) | each new word source repeats placement rules |

The scaling rows (FX-20 to FX-25) fold the two world files onto the one table, put every ceiling in one budget table with a test, encode the colour meanings, and make the phase preview a property of `src/combat/fight_phases.gd` so every boss gets it from rows.

## For Andrew (taste picks)

One pick is real taste: what a kill looks like (E1). It goes to Andrew as one page with candidates, a measured pass line and a PC check (ruling cq), built by the E1 row's thread, with the recommended default first: (A) ink-outlined starburst plus white body flash plus shards in the class colour; (B) the same plus, on elites only, the TONE-BIBLE's downed-machine gag drawn as a clock-out card stamp and a sigh of steam, with no word (ruling cx, LEGIBILITY pattern S6); (C) keep today's look; or none of these. Everything else here is clarity, decided by the builder within the rulings and logged as an overturnable assumption.

## Owed

- The stress frame times on an idle 4080 (`tools/stress_capture.gd` S1 to S3), queued on the board thread. The PC strips, flash peaks, sight reel and Brindle stills landed on `scratch/fx-critique-w38` 9c942544 and agree with E1, E2 and E7.
- A live human film only Andrew can give; the sitting watch list carries the feel questions.
