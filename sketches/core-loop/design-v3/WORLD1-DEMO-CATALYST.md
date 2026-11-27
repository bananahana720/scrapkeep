# World 1 Demo Catalyst Spec: Appeal, Art Style, Maps, Living Universe & Souls-Like Mastery

**Status:** Approved World 1 catalyst direction (21 November 2026, ruling `ei` in [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md)), written against `stage/alpha-w45` (`b4730b585`; note ruling `ep` subsequently unparked Worlds 2 & 3 for the full alpha and adopted flat `main`).  
**Scope:** World 1 ("The Spillway" — Title, Camp, Dam, Flume, Slag Bowl) ahead of Andrew's 11-area World 1 Sitting (extended to Worlds 1–3 by ruling `ep`). At the time of ruling `ei`, Worlds 2 & 3 were parked (`at`), Cobalt was the ordinary item ceiling (`bn`), Patch stayed parked (`dl`, later partially wired visually while its playable kit remains unbuilt), unfinished promise rows stay `report` (`ef`), and heightfield terrain deformation stays refused ([Q-P22](../../../BACKLOG.md#q-p22), ruling `eh`).

Read with: [STORY-MAP.md](STORY-MAP.md), [TONE-BIBLE.md](TONE-BIBLE.md), [SIGHT-PERSONA.md](SIGHT-PERSONA.md), [LEGIBILITY.md](LEGIBILITY.md) section 13, [ABILITY-MUTATIONS.md](ABILITY-MUTATIONS.md), [HEFT-DESTRUCTIBLES.md](HEFT-DESTRUCTIBLES.md), [FIRST-HOUR.md](FIRST-HOUR.md), [map-audit.md](../../../project-guide/handoff/shared/world1/map-audit.md), [visual-assets-audit.md](../../../project-guide/handoff/shared/world1/visual-assets-audit.md), [gameplay-critique.md](../../../project-guide/handoff/shared/world1/gameplay-critique.md), and [transitions-audit.md](../../../project-guide/handoff/shared/world1/transitions-audit.md).

---

## 1. The Iron Law: Souls-Like Difficulty Scaling, Creative Outsmarting & Clutch Play

Every single creative catalyst in this spec serves **two simultaneous goals**: maximizing joy, spectacle, and universe charm **while preserving and sharpening Scrapkeep's Souls-like skill ceiling** (ruling `cu`, 19 Oct skill-band ruling, HARD ladder rungs 1–5).

1. **Difficulty scales honestly — never flat, never cheap.**
   - **In-run escalation:** Pressure climbs cleanly from the Dam → Flume → Slag Bowl (closing the Wave 39 critique's "Dam peak followed by four valleys" problem). Brindle's worst minute must hit at least as hard as the Dam Warden's (`brindle-worst-minute`), and a stopped ball in the Slag Bowl pays at least double (`brindle-stop-tax` ≥ 2.0).
   - **Replay scaling:** Clearing Brindle opens **HARD Rung 1** (scaling through **HARD Rungs 1–5** via [run_tier.gd](../src/core/run_tier.gd) and [challenge_dials.gd](../src/core/challenge_dials.gd) — never bloating enemy HP per ruling `al`, always scaling aggression, cadence, crowd/elite pressure, and top-rung regen discipline) plus unlockable **Shift Variants & Run Modifiers** (`dam_night_shift`, `overtime`, `crew_short`).
2. **Every creative toy rewards outsmarting the encounter — never softening it.**
   - **Environmental mastery is double-edged:** Kickable sluice valves, pressurized tanks, high-line grapple dunk alleys, and chain-reaction destructibles reward a pilot who reads geometry, timing, and physics to flush a locked yard crew or crack a Warden faster — and any machine's live work cycle or blast zone turns on a parked, careless ball just as ruthlessly (ruling `cu`, `W1-142`).
   - **God-builds feel ecstatic *without* turning bosses into punching bags:** Overflow damage past Brindle's phase floors (`W1-61`) triggers a visceral scrap/cog/ultimate shower, **paired strictly with ruling `ed`** (Brindle keeps attacking, slowed, while reeling) and **`MG-11`** (line-leading charges/sweeps via [pack_pressure.gd](../src/combat/pack_pressure.gd)).
   - **Clutch runs are always earned:** Every lethal attack honours the ≥0.6 s readable tell floor and 0.2 s pack warning gap. Because hull regenerates only at cruise speed or above, Mend Wards cost live resources, and Keeper's Gambles trade hull for power, a skilled pilot at 15% HP can genuinely *clutch* a Warden or Brindle through crisp movement, verb counters (interrupting chasers in wind-up, snapping hooker tethers on a second post, carving Flume slag hops, dunking weak points), build mutations, and environmental timing.
3. **Final difficulty calibration always runs last (ruling `cy`).**
   - After Wave 45's power additions (`ShotBits`, kit swaps, verb items, evolutions, destructibles) and Wave 46's five catalysts land, a dedicated calibration pass on the RTX 4080 (`ahana`) re-tunes World 1 dials so every ruling-`cu` band holds: Novice ≤20% Dam / ≤15% Flume / ≤5% whole world (≥60% deaths, not time caps), Learner attempt 5 at 30–60%, Expert ≥85% per fight / ≥70% whole world in one attempt.

---

## 2. The Five Approved Creative Catalysts (`W46-C1` to `W46-C5`)

### Catalyst 1 (`W46-C1`): 2010 Vinyl/Album-Cover Visual Pop & Living Gig-Poster Title

**Goal:** Make Dot Marrow's creed (*"If a hand made it, you can see how it comes apart. If the Foreman made it, you cannot"*) unmistakable in any 3-second screenshot or clip.

- **2010 Finish & Material Contrast ([SIGHT-PERSONA.md](SIGHT-PERSONA.md) §5–6):**
  - Extend [bake_look.gd](../src/presentation/bake_look.gd) so convex edges on **Keeper** and **Fleet** paint lift cleanly toward brushed bone (with dark ink crease occlusion), while **Old Works** castings and Wardens keep `edge = 0` spotless enamelled shells with uranium-green seams (`#9dff3c`).
  - Add a subtle sky-tinted rim lift on hostile Fleet bodies in dawn shade so rust paint never drops near-black against warm sandstone (`visual-assets-audit.md` #8) while strictly obeying the colour law (`HAZARD` reserved for live wind-ups/danger).
  - Unify satin brass onto one shared material slot/recipe so horn bells, tags, and Brindle plating read consistently in dawn and daylight.
  - Resolve the PC linear-vs-sRGB vertex-colour contrast on the 7 code-drawn player marks (`bolts`, `effects`, `trail`, `speed lines`, `aura`, `cable arcs`, `aim`) using `tools/vertex_colour_probe.gd` stills on RTX 4080.
- **Three-Act Album-Cover Colour Story Across World 1:**
  - **The Dam:** Cool Desert Dawn — long violet-indigo canyon shadows, warm low apricot rim light, electric uranium-green Old Works seams glowing in shade.
  - **The Flume:** Blazing Morning Terracotta & Turquoise — bright sunlit sandstone chutes flashing with vivid turquoise sluice water and crisp foam.
  - **The Slag Bowl:** Smoky Furnace Gold — deep amber stadium floodlights, rising ember haze, gleaming brass plating, high-contrast silhouette readability.
- **Living 2010 Gig-Poster Title Screen ([title_stage.gd](../src/presentation/title_stage.gd), [screens.gd](../src/ui/screens.gd), `W1-47`):**
  - Replace plain debug-deck framing with a kinetic 2010 gig-poster composition: active pilot perched on their gyrosphere overlooking the Spillway skyline, thick-ink halftone wordmark pulsing on the 172 BPM grid, and a seamless Play drop straight into the camp gate with zero dead air.

**Acceptance & Proof:** `prim_census_test` (zero code stand-ins), `colour_cvd_test`, `models-render` receipt, RTX 4080 chase-camera stills of Dam/Flume/Slag Bowl, locked 60 fps (`frames` gate row), and taste-pick sheet (ruling `cq`).

---

### Catalyst 2 (`W46-C2`): Playable Flow, Postcard Districts, Concave Flume Basin & Brindle Horizon Continuity

**Goal:** Elevate World 1 from "good skate-park heightfield" to three geographically connected, interactive industrial playgrounds where reading the map is a genuine Souls-like combat advantage.

- **Three Memorable "Postcard Districts" Per Park ([park_dam.json](../src/world/park/park_dam.json), [park_flume.json](../src/world/park/park_flume.json)):**
  - *The Dam:* **Intake Catwalks** (high-line grapple dunk alleys, `W1-135`) → **Spillway Apron** (broad half-pipe plunge into the concave Warden bowl) → **Sunken Pump Yard** (hard steel cover, breakable shanties, pressurized tank chain-reactions).
  - *The Flume:* **Weir Bobsled** (water-boosted flow channels) → **Trestle Span** (elevated gantry lines where smart knockbacks pitch Fleet crews into the gorge) → **Headhouse Overlook** (unobstructed cliff sightline straight to Brindle's Slag Bowl smoke column).
- **Playable "Flow" & Double-Edged Interactive Works ([contraptions.gd](../src/world/contraptions.gd), [destructibles.gd](../src/world/destructibles.gd), `W1-142`):**
  - Add hydro-boost slicks / active spillway channels on key Flume & Dam lines that reward line mastery with clean speed above cruise.
  - Place 1–2 kickable / scrap-activated **Sluice Valves or Pressurized Tank Cascades** per park: hitting or activating them mid-fight triggers a committed, telegraphed surge or debris domino that flushes enemy packs or cracks a shortcut — and damages/tosses a stalled ball just like any hazard (ruling `cu`, `Q-P22` respected: props/contraptions only, zero heightfield deformation).
- **Concave Flume Warden Basin ([map-audit.md](../../../project-guide/handoff/shared/world1/map-audit.md) Point 8a):**
  - Upgrade the Flume Warden fight floor from flat (`-0.41 m`, previously `OWED`) into a true ≥2.0 m banked concave bowl so carving around Flume slag hops keeps full pinball momentum (`park_fight_bowl_test` green on Dam, Flume, and Slag Bowl).
- **Geographical Horizon Continuity ([transitions-audit.md](../../../project-guide/handoff/shared/world1/transitions-audit.md) T1–T6, [launch.gd](../src/world/launch.gd), [launch_take.gd](../src/presentation/launch_take.gd), [landmark_impostor.gd](../src/presentation/landmark_impostor.gd)):**
  - Place **Brindle's towering furnace smoke column & amber glow** on the Flume's east horizon along the launch rail's aim line.
  - Ensure Dam → Flume and Flume → Slag Bowl launches carry velocity and align heading under the directed comic swipe onto glowing landing rings with zero yaw snap (`handover_rows_test` green).

**Acceptance & Proof:** `snag_sweep` 0 snags standing & broken, `park_landmark_sight_test` ≥0.85, `park_fight_bowl_test` ≥2.0 m on all three arenas, `park_feature_census_test`, `handover_rows_test`, and paired ruling-`cu` band read confirming environmental mastery rewards skilled play without making Novice easier.

---

### Catalyst 3 (`W46-C3`): Slapstick Worker Roster, Brindle True Boss Duel & Moss's Last Call

**Goal:** Give every fight distinct tactical questions, unmistakable dark-comedy personality, and a World 1 boss climax worthy of both a god-run and a razor-thin clutch.

- **Tactical Diversity & Working-Class Slapstick ([lock_rows.gd](../src/world/lock_rows.gd), [enemy_motion.gd](../src/presentation/enemy_motion.gd), `W1-65`, `W1-66`, `W1-83`, `W1-85`):**
  - Ensure lock rings and pack compositions ask more than "are you fast?" — mixing jump asks (jolt mats), carve asks (boom tender sweeps), and grapple-counter asks (hooker tug-of-war snaps) without violating the lock ring's no-holding rule.
  - Accentuate worker personality: Shift Boss `"Quick sync."` horn snaps nearby chasers into tight formation; lamp eyes flare from bone to `HAZARD` through wind-ups; downed machines pop crisp **"shift over"** gags (steam sigh, spinning brass tag, grounded bounce scatter) with zero gore or screen clutter.
- **Admiral Brindle — True Souls-Like Boss Climax ([boss.gd](../src/boss/boss.gd), [arena.gd](../src/boss/arena.gd), [boss_rules.gd](../src/boss/boss_rules.gd), [pack_pressure.gd](../src/combat/pack_pressure.gd)):**
  - Land **`MG-11`** (`PackPressure.lead_aim` on straight-rolling balls, zero penalty on turning/carving balls) + **ruling `ed`** (Brindle keeps attacking, slowed, while reeling instead of standing helpless).
  - Pair with **`W1-61`** (overflow shatter past phase floors triggers an ecstatic scrap/cog/ultimate shower so monster builds feel thunderously rewarded while still dodging slowed follow-ups).
  - Add crisp **visual tell twins** for Brindle's follow-up ring and hook turn (`W1-105`, `W1-106`, decision A11), **Slag Bowl stand crew bodies** (uniformed stuffed-animal spectators cheering, waving clipboards, reacting to combos and phase turns — never targets), a **1-second phase-turn comic clash beat** synced to the +10/+20 BPM anthem drops with 2-frame armor-break impact freeze, and polish on his **scooter defeat wink**.
  - Wire the Warden form onto the synth band and Brindle (historical [design-v3/ROADMAP.md](ROADMAP.md) Item 7; live roadmap is [project-guide/handoff/ROADMAP.md](../../../project-guide/handoff/ROADMAP.md)).
- **Moss's Last Call at the Slag Bowl Mouth ([shop.gd](../src/build/shop.gd), `W1-73`):**
  - Dock Moss once right before Brindle so leftover cogs (1,300–2,000+ previously dying unspent) buy one final strategic spike: a shelf slot biased toward completing the player's nearest **Maker Set or Evolution**, plus one cog-fed boss tactical consumable.

**Acceptance & Proof:** `boss_lead_line_test`, `brindle-worst-minute` ≥ Dam Warden's, `brindle-stop-tax` ≥ 2.0, `warden-fairness`, `strong-build-shows`, `brindle-phases`, `brindle-length`, `offer_weights_test`, and RTX 4080 Slag Bowl stills.

---

### Catalyst 4 (`W46-C4`): Living Universe — Purple Foreman's Kindness, 1-Second Sight Gags, Cute Babble Call-Ins & Living Camp

**Goal:** Put Scrapkeep's hilarious, heartfelt world directly in front of the player at 35 m/s with zero lore walls and zero UI slop (ruling `cx`).

- **The Theme Made Physical — Foreman's Kindness vs. Keeper's Gamble ([stake_devices.gd](../src/world/stake_devices.gd), ruling `ci`):**
  - Give **Foreman's Kindness** its seamless cast-metal kiosk body wearing World 1's **only flat purple glow** (`hue 300–330`) and polite on-the-grid chime (*"A small efficiency fee. You're welcome."*) right across from the bolted, chalk-scrawled **Keeper's Gamble** shrine (*"Nobody makes you."*).
- **1-Second Environmental Sight Gags on Main Sightlines ([park_dam.json](../src/world/park/park_dam.json), [park_flume.json](../src/world/park/park_flume.json)):**
  - Place 3–4 unmistakable visual jokes right along main Dam & Flume views: pristine typeset Foreman billboards (*"ALL WATER IS NOW INVENTORY"*, *"ZERO UNPLANNED FUN SINCE DAY 1,402"*) defaced by crooked Keeper chalk (*"Tell the river."*) or a ball-shaped dent; looping non-hostile Old Works cranes/pistons doubling as live moving grapple points; empty shift tables with neatly laid-out giant cast gloves.
- **Live Comic Call-Ins with Cute Babble Voices ([STORY-MAP.md](STORY-MAP.md) §3, [caller_tile.gd](../src/ui/caller_tile.gd), [audio.gd](../src/presentation/audio.gd), [lore_rows.gd](../src/core/lore_rows.gd), `W1-75`):**
  - Bring animated corner comic call-in cards (face + name + ≤12 words) with *Animal Crossing*-style cute babble synth voices for Moss, site crews, freed pilots, and Brindle — juxtaposed against the Foreman's sterile, perfectly-on-the-grid corporate chime memos on **every** stage card (including seeded "conditions nominal" lines) and on the run-over death screen (*"We are sunsetting this pilot. Thank you for your contributions."*, with Moss/crew always getting the last word).
  - **Strict Legibility Guardrails (ruling `cx`):** One voice at a time, never pauses the ball, never overlaps a telegraph, reticle, or reward-gate name, off headless so zero bot/band drift.
- **A Living, Growing Camp ([camp_hub.gd](../src/world/camp_hub.gd), [shift_board.gd](../src/core/shift_board.gd), `W1-72`):**
  - Freed pilots (Rivet, Tarn, etc.) physically hang out in Camp and fire a 1-line babble quip when you roll past.
  - Found B-side radio tapes appear as physical 2010 vinyl sleeves on Moss's jukebox shelf; cleared runs slap physical `HIRED` stamps onto the Shift Board and clearly show the next chase rung + Spillway secrets counter on the run summary.

**Acceptance & Proof:** `sketch:lint`, `words-on-screen`, `ui_text_floor_test`, `shift_board_test`, `sound-own-recipes`, `sound-levels` (same-build real-Ogg check), and blind first-timer film read (`first-timer-read` with zero new UI clutter findings).

---

### Catalyst 5 (`W46-C5`): Replay Addiction Engine — *Dam Night Shift*, Rotating Sites & Escalating Mastery

**Goal:** Turn a 15-minute World 1 clear into a 10-hour obsession where Run 5 feels shockingly alive and HARD rungs reward true Souls-like mastery.

- **Unlockable World 1 Shift Variants ([FIRST-HOUR.md](FIRST-HOUR.md) `ShiftBoard.SEEDS`, [shift_board.gd](../src/core/shift_board.gd), [stage_modifier.gd](../src/world/events/stage_modifier.gd)):**
  - Wire **`dam_night_shift`** (unlocked on *Brindle Routed*): reuses the exact proven Dam geometry (zero new snag risk!) under a dramatic twilight sky, blazing sodium floodlights, and glowing uranium-green Old Works seams — giving players an instant *"Wait, what just unlocked?!"* second-run thrill.
  - Wire **`overtime`** (unlocked on *Warden Breaker*) and **`crew_short`** (unlocked on *Sable's Mark*) run modifiers so beating milestones actively widens and escalates the World 1 sandbox.
- **Per-Run Encounter & Voice Variety ([activities.gd](../src/world/activities.gd), [lore_rows.gd](../src/core/lore_rows.gd), `W1-70`, `W1-71`):**
  - Allow authored Dam & Flume activity sites to roll from 2–3 distinct seeded alternatives (relay, ambush altar, gamble/rogue pairing) so players actively scout the skyline every run instead of memorizing one fixed loop.
  - Give World 1 call-in rows 2–3 rotating text variants so lines stay fresh across repeated runs.
- **Clean Progression Without Crutches:**
  - Keep **HARD Rungs 1–5** ([run_tier.gd](../src/core/run_tier.gd)) + 3-hole Time Card + Brindle pilot completion marks intact — zero persistent stat buffs, 100% skill-and-sandbox growth.

**Acceptance & Proof:** `park_variety_test`, `shift_board_test`, `run_tier_test`, `rewards-banked-once`, `EarnedSave.tla` live TLC invariant intact, and RTX 4080 Night Shift frame-time capture within 60 fps budget.

---

## 3. Master Sequencing & Working-Backwards Verification Contract

Working backwards from `npm run sketch:world1-bands -- --sitting --head <sha>` printing **`READY`** across all **35 active `gate` rows** (ruling `ef`):

| Phase | Owner / Branch | Exact Deliverables | Hard Exit Criteria |
| --- | --- | --- | --- |
| **1. Close Wave 45** *(now)* | Gate (`stage/alpha-w45`) | Finish `P5` (revert `OFF_SHELF` 1.06), `P6`, `P3`, `P7` (YL-1/YL-2/ES-1), `FV-3` (`DeferredEffects.tla` + 8/8 TLC PASS). Run **`ahana` RTX 4080 gap-detector** (GPU Test F2, P4/W45-C occlusion stills, post-Wave-45 ruling-`cu` bands, `MG-03` Linux pins). Promote to `main`, cut `stage/alpha-w46`. | 100% TLC PASS, `sketch:fast` green, Wave 45 promoted cleanly. |
| **2. Wave 46A — Spine + Catalysts** | Gate + parallel writers (`stage/alpha-w46`) | **Spine (`W46-S1` part 1):** fix `PF-48` & `PF-49` stalls, close open World 1 `PLAY-FINDINGS.tsv` (`PF-01`, `14`, `19`, `21`, `28`, `40`, `47`), `MG-09`/`MG-10` (<100 ms press response), retarget ready promise drafts (`PRs 1144–1158`, ruling `ef`). **Catalysts:** build `W46-C1` through `W46-C5` with disjoint file fences, focused tests + Gemini 4 Neon (`high`) reviews on every unit (ruling `ej`). | Zero World 1 stalls, every catalyst passes its focused test, lint, and Gemini 4 Neon (`high`) review. |
| **3. Wave 46B — Souls-Like Calibration & Release Cut** *(last, ruling `cy`)* | Gate + `ahana` RTX 4080 | Re-tune World 1 dials against full Wave 45+46 power (`cu`, `ed`, `MG-11`, Flume grown median, `park_reactor_fight_test` seed 21). Run idle RTX 4080 frame capture (including Night Shift & heavy mutations), real-Ogg loudness/seam check, **whole-run First-Timer Release Film** (closing 10 `ruling dz` rows), full **Release Gate** (`tally.mjs`, zero deferred shards, zero overdue `KNOWN-FAILING.tsv`), packed Linux export (`core-loop.x86_64`), `scrapkeep-verify-build`, Sitting Kit refresh, rollback-safe install. | `npm run sketch:world1-bands -- --sitting --head <sha>` prints **`READY` (35/35 gate rows)**. |
| **4. Andrew's World 1 Sitting** | Andrew (`--profile=sitting-earned`) | Play Title → Camp → Dam → Flume → Brindle → Dam Night Shift / HARD Rung 1; grade all 11 sitting areas on the Sitting Kit. | Sitting verdicts lock World 1 Demo & open Phase 2 (fixes → Worlds 2 & 3). |

---

## 4. North-Star Release Blog Post (What the Finished World 1 Demo Promises)

> *Every claim below is an explicit acceptance target for Waves 45–46. Nothing ships as marketing copy that the running World 1 Demo does not deliver.*

### Welcome to the Spillway: Roll Out in the World 1 Demo of SCRAPKEEP

> *"The Spillway is now four per cent more aligned. No action is required from you."*  
> — Memo from the Foreman

**SCRAPKEEP** is a high-speed 3D action roguelite about a crew of loose cannons — bulls in the Foreman's china shop — taking their world back from an AI that genuinely believes life can be run perfectly.

The **World 1 Demo: The Spillway** is a complete, fiercely replayable first world built around one belief: **a roguelite shouldn't just hand you bigger numbers — it should turn a sunlit sandstone canyon into a physical pinball playground, bolt the wreckage straight onto your chassis, test your mastery like a Souls-like duel, blast a 2010 festival sax-and-EDM anthem as you launch off a concrete weir at 45 m/s, and film the whole thing like the last episode of an anime that knows it's a little corny.**

- **A Pinball Machine With a Pendulum — Built for Skill & Clutch Runs:** Carve sandstone half-pipes, grip canyon walls above cruise speed, swing or flail enemies by weight on your harpoon line, and bank air slams into reel-in **Dunks** straight onto a titan's core. Your hull only regenerates while rolling at cruise or faster; park in one place and **silt boils** erupt beneath you; hold a lazy line and Fleet chasers and bosses lead your roll. Every lethal hit is cleanly telegraphed so a sharp pilot at 15% hull can outsmart the arena, exploit the terrain, and clutch the run.
- **Heft I–V Smash-Through & Playable Flow:** Vacuum scrap to climb from Class I to Class V without bloating your collision outline. Bowl straight through fodder you outweigh, shatter crates, barricades, tanks, and shortcut slabs *before contact* (+1 tier on slams/explosives) to send lethal debris through enemy squads, kick open sluice valves to flush yards, and ride hydro-boost channels from the **Intake Catwalks** through the **Weir Bobsled** toward **Brindle's glowing smoke plume** on the horizon.
- **Scrap Becomes Your Build:** Combine uncapped **Grey Panels**, **Mint Field Kits**, **Cobalt Verb Rewriters** (*Slag Pike*, *Halo Rig*, *Backwash*, *Barbed Reel*, *Faultline Cap*, *Second Bell*, *Long Leash*), **Live ShotBits** (*Pierce, Bounce, Split, Pull, Heat* with 10 pairwise rules), **Maker Sets**, **Verb-Changing Evolutions** (*Grapeshot Press*, *Hoar Barrel*, *Fault Hammer*), **9 World 1 Kit-Swap Relics**, **SPIL-9**, and **Moss's Last Call** right before the boss — with **Keeper's Gambles** daring you across from the **Foreman's Kindness** (the one eerie flat-purple kiosk in World 1).
- **Six Loose Cannons & a Living 2010 Comic World:** Fly **Sable**, **Rivet**, **Kest**, **Tarn**, **Tally**, or **The Cannon** across three distinct album-cover palettes (Cool Desert Dawn → Terracotta & Turquoise Morning → Smoky Furnace Gold). Hear your crew trade cute-babble comic call-ins over the Foreman's sterile corporate memos, meet freed pilots hanging out at **Moss's Camp**, collect hidden **Pilot Radio** B-sides, and face **Admiral Brindle** in a roaring, spectator-packed Slag Bowl climax set to an escalating +10/+20 BPM Eurodance anthem.
- **Beat Brindle Once, and the Demo Cracks Wide Open:** Stamp your `HIRED` mark on the Shift Board, punch your 3-hole Time Card on every shift (zero stat-grind), climb **HARD Rungs 1–5**, and drop straight into **Dam Night Shift** under blazing sodium floodlights and uranium-green seams while **The Dig** and **The Highdraft** wait beyond the Bowl.

*The Foreman entered your return trip and asked you to leave the time blank. Roll out, break the schedule, and fill in the time yourself.*
