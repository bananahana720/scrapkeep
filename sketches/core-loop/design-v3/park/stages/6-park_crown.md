# Stage 6: Highdraft, the crown (`park_crown`)

**Status: storyboard draft, waiting for Andrew's approval.** Unit K-W3, wave 13, 10 October 2026. Nothing here is built. Every number marked "(start)" is a starting value to tune in play. The tables follow TADR-011 and PARK.md section 2 field for field. A schema check and a rough sight check ran on this draft; section 16 says how.

| Field | Value |
| --- | --- |
| Stage and world | 6, The Highdraft (world 3), the last stage before the Mind |
| Map id and display name | `park_crown`, "Highdraft: the crown" |
| Warden | `mind` (the Mind's hand) on `spires`, variant `choir` (kept, `src/core/alpha_defs.gd:120`) |
| Time of day | `dusk` (today a morning light, `src/presentation/world_look.gd:35`) |
| Kind sheet | `design-v3/wardens/mind.md` |
| Boards | stage board `park-6-park_crown` (panels p1 to p6); key art in the concept board `park-w3` |

## In one look

The run's last park. You drop off a butte at dusk under a building thunderstorm and ride a wide alluvial fan, the bajada, down into a valley of buttes, hoodoos and needle spires. Lightning picks out spires on the beat. At the far end the Crown Spire stands 330 m tall with three short perch spires round its foot, and the Mind's hand flies between them.

| Number | Value (start) |
| --- | --- |
| Drop-in | the Watch Butte's top, 200 m |
| The bajada | falls from 80 m at its head (z -400) to 0 m at its foot (z 330) |
| Buttes | 120 to 180 m above the ground they stand on, tops 158 to 200 m |
| The Crown Spire | 330 m, 50 m across at the base |
| The Warden | three perch spires 45 m from the Crown's axis, tops 12 m; the hand's lens at 18 m; the bowl floor at -12 m |
| Pilot lines, drop-in to engage | 1,519 to 1,978 m, 58 to 99 s at 20 to 26 m/s |
| Sight share (rough model) | 0.854 over 774 cells |

## 1. The Arizona landform and the society layer

**The real place.** The sandstone buttes and spires of the Colorado Plateau's monument country, with hoodoo fields, goosenecks, tight meanders that flash floods cut into the rock, and summer monsoon storms that build every afternoon. The park takes the forms and the weather, not a real name (PARK.md veto 18, `BIBLE.md:979`).

**The park disguise.** The bajada is one huge ramp: the whole stage falls 80 m toward the Crown. Buttes are banks and drops; hoodoo fields and needle fields are harpoon anchor fields (PARK.md:379); washes and the gooseneck are half-pipes; spires are swing posts. The animals' net returns once, slung between the two Gauntlet buttes.

**Who built what.**

| Society | Where on this stage | What it left | What it means in play |
| --- | --- | --- | --- |
| `none` (water and time) | the buttes, the bajada, the Turnstone, the hoodoos, the meander, the needles, the Crown and its bowl | strata, fulgurite, scour lines, balanced caps | almost the whole park: the ground is the ride |
| `ancestral_puebloan` (reference only) | one row: the alcove ledge in the Alcove Butte's south-east face | a small stone room in the alcove | a ledge you ride past; no home, no destructive event, a `ref_` fragment (PARK.md veto 17) |
| `fleet` | the signal masts and their wire; the lightning collector catwalk on the Crown Spire; the dropship's landing on the Gauntlet Shelf | a storm log, a collector tag | the line cutters' home, the industrial event, the Fleet landing |
| `ancient` | the lens spire west of the needles; the three perch spires; the Crown itself | a lens seat, perch wear, a count | the Mind's hands, the eruption, the Warden |
| the animals (no society id; filed under `none`) | the Gauntlet net and its balloon lift | net mends | the east fan's air route |

**The guardrail, checked.** `alcove_ledge` is the only `ancestral_puebloan` row. It has no `home`, its fragment is `ref_alcove_masonry`, and no event row names it as a site (PARK.md:230). The anchors for that stretch are the natural rock horns above the alcove (`alcove_horns`, society `none`); the masonry carries no hardpoint or post. In game the alcove builders are a fictional people; the reference fragment describes the building technique only.

**Material read.** Red-orange sandstone going violet as the light fails; pale hoodoo caps; wet slickrock that mirrors the lightning. The Fleet in brass and soot. The ancients only in dull petrol enamel with uranium-glass green (#9dff3c) seams (`src/combat/warden_kit.gd:8-9`), which glow brighter as the sky darkens.

## 2. The hero landmark and the Warden's mounting

**The Crown Spire.** A single sandstone spire, 330 m tall and 50 m across at its base, standing in a scoured slickrock bowl at the park's north end. A uranium-glass green beam rises from its tip (`light: "ancient_beam"`), and the storm's lightning prefers it. A Fleet lightning collector, a brass catwalk ringed with rods, clings to its south face at 64 m: the Fleet is harvesting the storm.

**Why 330 m and not PARK.md's 300 m.** The sight rule asks for 85% of open cells (PARK.md:474). The bajada is open, but the Alcove, Signal and Gauntlet buttes cast shadows. With the buttes turned so their long axes point at the Crown and slimmed to 90 to 120 m wide, a 300 m spire reached about 0.85 in my rough model and 330 m reached 0.854 over 774 cells. The margin is thin. If KD6's real test misses, the first fix is lowering the Signal Butte; the second is 360 m.

**The mounting, `spires`.** Three perch spires stand in the bowl, 45 m from the Crown's axis and 78 m from each other, their tops 12 m above the bowl rim (24 m above its floor). The hand perches on one, its lens at 18 m, and every 8 s it flies to the next (today's choir cycle, `src/combat/warden.gd:63`; PARK.md:429). The flight is a 3 s arc that peaks 15 m above the perches, so a latched ball is dragged at about 28 m/s, the blazing tier. The open lens seat is the current perch. A stagger stops the flight clock (`warden.gd:349`); a stagger in flight knocks the hand down to the bowl floor (kind sheet section 3.2) and braces the hand against the ball's top habit (`warden.gd:535-540`).

**The arena.** The bowl is 240 m across and 12 m deep. The engage ring (`reach_m` 120) covers it and the perches' 45 m path with room to spare (PARK.md:431). The perch spires and the Crown are anchor fields: from the bowl floor beside a perch, its top is 24 to 33 m away, inside the 45 m rope (`src/movement/tuning.gd:18`). The collector catwalk at 64 m is the high anchor for the drop finisher. The `crown_updraft` thermal rises 120 m on the bowl's west side for a pilot who glides.

**Gates and bay.** The Crown Apron, a slickrock shelf north of the bowl at 30 m. Gates at z 670 facing +z. Moss's bay docks at [0, 600], 70 m behind the gates and inside their 110 m hold (`src/world/bay.gd:21-23`).

**After the break.** The hand drops off its perch into the bowl and goes dark; the three lens seats go dark with it. The beam stays. No event starts in the next 20 s (PARK.md:311). The gates lead on to the Mind's own arena, which stays authored and small (PARK.md:381; `src/boss/mind.gd`), and after the Mind to the ending bowl (PARK.md veto 13).

## 3. Region sketch

The 1.6 km square, -800 to +800 m on both axes. The fall line runs up the page, from the drop-in at the south to the landmark at the north.

```
        -800 m (west)                                      +800 m (east)
z (m)
  750                       ap ap                     
  650                       ap GT                     
  550                    cb ap BY cb                  
  450              H4    cb C1 LM cb                  
  350  ba ba sb A1 sb H1 cb cb cb cb C6 ba ba ba ba ba
  250  ba ba sb sb sb C4 ne ne ga sh sh ga ga ba ba ba
  150  ba ba ba ba ba C8 C0 ne ga H2 C2 ga ga ba ba ba
   50  ba ba ba al al al al ba ga ga ga C5 ga ba ba ba
  -50  ba ba ba al al al ho ho C7 ea ea ea ba ba ba ba
 -150  ba ba ba al al al ho ho me ea ea ea ba ba ba ba
 -250  ba ba ba al al al ho ho me ea ea ea ba ba ba ba
 -350  ba ba ba ba ba ba ba C3 A2 ea ea ea ba ba ba ba
 -450  ba ba ba ba ba ba ba ba ba ba ba ba ba ba ba ba
 -550                    wb wb wb wb                  
 -650                    wb wb wb wb                  
 -750                    wb wb DI wb                  
```

Each cell is 100 m. North (+z, the landmark side) is up.

| Code | Region |
| --- | --- |
| `wb` | Watch Butte |
| `ba` | Bajada (open fan) |
| `al` | Alcove Butte |
| `ho` | Hoodoo Forest |
| `me` | Meander (gooseneck) |
| `ea` | East Wash |
| `ne` | Needles |
| `sb` | Signal Butte and masts |
| `ga` | Gauntlet |
| `sh` | Gauntlet Shelf |
| `cb` | Crown bowl and spires |
| `ap` | Crown Apron |

| Mark | What | At [x, z] |
| --- | --- | --- |
| `A1` | enemy_camp `camp_signal` | [-440, 320] |
| `A2` | cracked_cache `cache_turnstone` | [0, -315] |
| `A3` | hauler_bounty `bounty_gauntlet` | [250, 365] |
| `H1` | home `mast_cutters` (line_cutter) | [-269, 301] |
| `H2` | home `gauntlet_anchor_crew` (anchor_crew) | [171, 171] |
| `H3` | home `needle_kites` (kite_drone) | [-169, 181] |
| `H4` | home `spire_hands` (mind_hand) | [-329, 421] |
| `H5` | home `dropship_cutters` (line_cutter, dormant) | [221, 331] |
| `C0` | thermal `needle_updraft` | [-150, 150] |
| `C1` | thermal `crown_updraft` | [-80, 500] |
| `C2` | thermal `gauntlet_updraft` | [200, 110] |
| `C3` | cable `turnstone_wire` | [-15, -325] |
| `C4` | cable `signal_wire` | [-265, 300] |
| `C5` | lift `gauntlet_balloon_lift` | [330, 90] |
| `C6` | launcher `shelf_cannon` | [215, 335] |
| `C7` | cracked_wall `meander_wall` | [60, -10] |
| `C8` | barge `needle_barge` | [-210, 140] |
| `BY` | bay dock | [0, 600] |
| `GT` | reward gates | [0, 670] |
| `LM` | landmark `crown_spire` and the Warden | [0, 470] |
| `DI` | drop-in | [0, -720] |

Read it as three fans between four waymarks. The Watch Butte's drop ramp funnels every line onto the bajada at the Turnstone. The middle fan spreads four ways (the alcove west, the hoodoo forest, the meander, the east wash) and gathers at the split spire. The last fan spreads three ways (the needles and signal wire west, the crown ramp in the centre, the Gauntlet east) and ends in the bowl. The Signal Butte camp and the lens spire sit off the lines on the west flank; you see them, and you choose them.

## 4. `park_rows` draft

Conventions on this stage. `size` h of a stamped row is its height above the local ground: the bajada for most rows, the base plain at 0 m north of z 330. The `bajada` row is the ramp stamp everything else stands on. Rows that hang (the alcove ledge and horns, the Gauntlet net, the collector) carry an absolute `y`. These are 29 rows; KD6 grows them toward PARK.md 2.2's 40 to 70 with detail rows.

**Anchor cover.** The max anchor gap is 40 m (PARK.md:464), and walkable ground is not a target (`design-v3/TRAVERSAL.md:14`). The bajada is wide open, so `bajada_blocks` scatters fallen sandstone blocks 8 to 12 m tall on an 80 m jittered lattice across it: each block is a target, and no point on the fan is more than about 45 m from one. Elsewhere the hoodoos, needles, spires and butte faces carry the anchors. The blocks are what the buttes shed, so the anchors explain themselves.

| id | element / landform | society | at, y | size l x h x w, yaw | verb, ride fact | stamp, budget | routes | home | fragment |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `watch_butte` | sky_island / butte | none | [0, -640], null | 220 x 120 x 240 | drop, ride_drop | butte, landform | main, hoodoo, west, east, gauntlet, toppled |  | none_watch_butte_strata |
| `drop_ramp` | flow_line / slickrock | none | [0, -470], null | 160 x 120 x 100 | pump, ride_chute | ramp, landform | main, hoodoo, west, east, gauntlet, toppled |  |  |
| `bajada` | ground / dry_wash | none | [0, -35], null | 730 x 80 x 1500 | roll, (none) | ramp, landform | main, hoodoo, west, east, gauntlet, toppled |  | none_bajada_fan |
| `bajada_blocks` | anchor_field / slickrock | none | [0, -35], null | 730 x 10 x 1500 | swing, ride_grapple_line | none, detail | main, hoodoo, west, east, gauntlet, toppled |  |  |
| `turnstone` | bank / hoodoo_field | none | [0, -330], null | 40 x 45 x 40 | bank, ride_bowl | spire, landform | main, hoodoo, west, east, gauntlet, toppled |  | none_balanced_caps |
| `west_wash` | half_pipe / dry_wash | none | [-155, -262], null | 260 x 12 x 30, -73 deg | pump, ride_chute | wash, landform | west |  |  |
| `alcove_butte` | sky_island / butte | none | [-290, -60], null | 260 x 150 x 120, 35 deg | bank, ride_bowl | butte, landform | (none) |  |  |
| `alcove_talus` | bank / butte | none | [-300, -215], null | 80 x 20 x 40, 35 deg | bank, ride_bowl | ramp, landform | west |  |  |
| `alcove_ledge` | elevated_line / cliff_dwelling | ancestral_puebloan | [-236, -98], 80 | 200 x 6 x 10, 35 deg | roll, ride_ledge | none, landform | west |  | ref_alcove_masonry |
| `alcove_horns` | anchor_field / mesa_rim | none | [-246, -91], 120 | 200 x 6 x 6, 35 deg | swing, ride_grapple_line | none, landform | west |  |  |
| `hoodoo_forest` | anchor_field / hoodoo_field | none | [-80, -170], null | 240 x 60 x 160 | swing, ride_grapple_line | none, landform | hoodoo |  | none_hoodoo_spacing |
| `meander` | half_pipe / gooseneck | none | [110, -200], null | 260 x 18 x 40 | pump, ride_chute | wash, landform | main, toppled |  | none_meander_scour |
| `meander_bend` | bank / gooseneck | none | [90, -40], null | 140 x 18 x 140 | bank, ride_bowl | wash, landform | main, toppled |  |  |
| `east_wash` | half_pipe / arroyo | none | [260, -210], null | 280 x 12 x 30, 20 deg | pump, ride_chute | wash, landform | east, gauntlet |  |  |
| `east_ribs` | kicker / slickrock | none | [240, -50], null | 14 x 2.5 x 40, -50 deg | launch, ride_hop | ramp, landform | east |  |  |
| `split_spire` | anchor_field / spire | none | [0, 40], null | 24 x 120 x 24 | swing, ride_grapple_line | spire, landform | main, hoodoo, west, east, gauntlet, toppled |  | none_fulgurite |
| `needles` | anchor_field / spire | none | [-170, 180], null | 180 x 140 x 140 | swing, ride_grapple_line | none, landform | hoodoo, west | needle_kites | none_needle_count |
| `signal_butte` | sky_island / butte | none | [-460, 300], null | 180 x 180 x 160 | drop, ride_drop | butte, landform | (none) |  |  |
| `signal_masts` | anchor_field / mesa_rim | fleet | [-270, 300], null | 60 x 40 x 40 | swing, ride_grapple_line | ridge, landform | west | mast_cutters | fleet_storm_log |
| `lens_spire` | anchor_field / spire | ancient | [-330, 420], null | 30 x 130 x 30 | swing, ride_grapple_line | spire, landform | (none) | spire_hands | ancient_lens_seat |
| `gauntlet_west` | sky_island / butte | none | [170, 170], null | 180 x 140 x 90, -30 deg | bank, ride_bowl | butte, landform | gauntlet | gauntlet_anchor_crew |  |
| `gauntlet_east` | sky_island / butte | none | [390, 170], null | 180 x 160 x 90, -40 deg | drop, ride_drop | butte, landform | (none) |  |  |
| `gauntlet_net` | half_pipe / sky_island | none | [280, 175], 110 | 180 x 14 x 100, -35 deg | pump, ride_chute | none, landform | gauntlet |  | net_gauntlet_mends |
| `gauntlet_shelf` | ground / slickrock | none | [220, 330], null | 120 x 40 x 160 | roll, (none) | plateau, landform | east, gauntlet | dropship_cutters |  |
| `crown_ramp` | kicker / slickrock | none | [0, 310], null | 24 x 5 x 60 | launch, ride_hop | ramp, landform | main |  |  |
| `crown_bowl` | bowl / slickrock | none | [0, 470], null | 240 x 12 x 240 | bank, ride_bowl | bowl, landform | main, hoodoo, west, east, gauntlet, toppled |  | none_crown_scour |
| `perch_spires` | anchor_field / spire | ancient | [0, 470], null | 90 x 24 x 90 | swing, ride_grapple_line | none, landform | (none) |  | ancient_perch_wear |
| `crown_collector` | ledge / spire | fleet | [16, 470], 64 | 30 x 3 x 8, 90 deg | roll, ride_ledge | none, landform | (none) |  | fleet_collector_tag |
| `crown_apron` | ground / slickrock | none | [0, 660], null | 160 x 30 x 300 | roll, (none) | plateau, landform | (none) |  |  |

Row notes:

- `watch_butte` and `drop_ramp`: the drop-in. The ramp is a steep slickrock nose falling 120 m to the bajada's head; every line carves it as an S.
- `turnstone`: a balanced rock at the bajada's head and the first waymark, with the cracked cache at its foot. A wire runs from its cap down to the hoodoo forest.
- `alcove_butte`, `alcove_talus`, `alcove_ledge`, `alcove_horns`: the west fan. The butte turns 35 degrees so its long axis points at the Crown, which narrows its shadow. The ledge runs along its south-east face 33 m above the bajada; the horns above it are the anchors.
- `meander` and `meander_bend`: a gooseneck, a tight meander cut 18 m into the bajada (the river-scale horseshoe bend is stage 2's alone). The cracked wall on the bend's inside is a shortcut for a hard ram.
- `split_spire`: the second waymark. A 120 m spire with a lightning scar down its north side; the tier 2 strike drops its top as a ramp.
- `gauntlet_west`, `gauntlet_east`, `gauntlet_net`: two slim buttes turned toward the Crown with the animals' net slung between them at 110 m. A balloon lift at the net's south end lifts you onto it.
- `perch_spires` and `crown_collector`: the Warden's three perches and the Fleet's catwalk on the Crown.
- `crown_apron`: the gates' ground.

## 5. Routes, waymarks and activities

| route | via | open at start |
| --- | --- | --- |
| `main` | watch_butte, drop_ramp, bajada, turnstone, meander, meander_bend, split_spire, crown_ramp, crown_bowl | yes |
| `hoodoo` | watch_butte, drop_ramp, bajada, turnstone, hoodoo_forest, split_spire, needles, crown_bowl | yes |
| `west` | watch_butte, drop_ramp, bajada, turnstone, west_wash, alcove_talus, alcove_ledge, alcove_horns, split_spire, needles, signal_masts, crown_bowl | yes |
| `east` | watch_butte, drop_ramp, bajada, turnstone, east_wash, east_ribs, split_spire, gauntlet_shelf, crown_bowl | yes |
| `gauntlet` | watch_butte, drop_ramp, bajada, turnstone, east_wash, split_spire, gauntlet_west, gauntlet_net, gauntlet_shelf, crown_bowl | yes |
| `toppled` | watch_butte, drop_ramp, bajada, turnstone, meander, meander_bend, split_spire, crown_bowl | no, an event opens it |

Only `meander_flash_flood` closes routes (`main` and `toppled`, both of which run through the meander). `hoodoo`, `west`, `east` and `gauntlet` can never close, so "a route always open" holds under every overlap (PARK.md section 5).

| id | activity | site | at | pack | pay |
| --- | --- | --- | --- | --- | --- |
| `camp_signal` | enemy_camp | `signal_butte` | [-440, 320] | line_cutter, line_cutter, kite_drone | {"named": "rivet_plating"} |
| `cache_turnstone` | cracked_cache | `turnstone` | [0, -315] | (row default) | (row default) |
| `bounty_gauntlet` | hauler_bounty | `gauntlet_shelf` | [250, 365] | (row default) | (row default) |

Waymarks, in order: `drop_in`, `cache_turnstone`, `split_spire`, `landmark`.

The three activities are signposted from the drop-in. The cache is the first waymark, so every line passes it (as today's cache sits on the chain, `src/world/map_highdraft_crown.gd:89-93`). The camp sits on the Signal Butte off the west line; the bounty sits on the Gauntlet Shelf on the east lines.

## 6. `event_rows` draft

| id | kind (family) | site | trigger | lead s, form | live s | effect | routes | hold m, cooldown s, once | music cue |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `needle_strikes` | lightning (natural) | `needles` | clock_tier 1 | 3, lightning_mark | 20 | strike_m 8.0, damage 6.0 | none | 0, 40, false | riser_natural then drop_lightning |
| `split_spire_strike` | lightning (natural) | `split_spire` | clock_tier 2 | 6, lightning_mark | 0 | strike_m 10.0, damage 8.0, swap "spire_top_ramp" | opens toppled | 30, 0, true | riser_natural then drop_lightning |
| `meander_flash_flood` | flash_flood (natural) | `meander` | clock_tier 2 | 7, flood_rising | 30 | depth_m 1.0, fill_s 4.0, material "water" | closes main, toppled | 20, 90, false | riser_natural then drop_flood |
| `lens_spire_wakes` | machine_eruption (ancient) | `lens_spire` | clock_tier 2 | 9, ancient_stirring | 0 | miniboss "mind_hand", swap "spire_foot_crater" | none | 18, 0, true | riser_mind_quote then drop_mind_wrong |
| `gauntlet_dropship` | fleet_landing (fleet) | `gauntlet_shelf` | clock_tier 1 | 10, fleet_inbound | 0 | vessel "dropship", home "dropship_cutters", footprint_m [36, 16] | none | 25, 0, true | riser_fleet then drop_fleet_anvil |
| `collector_burst` | boiler_burst (industrial) | `crown_collector` | warden_phase chunk_2 | 5, boiler_pressure | 8 | hazard "arc_steam_cone", hazard_m [24, 10], damage 6.0, swap "collector_catwalk_ramp" | none | 14, 0, true | riser_industrial then drop_boiler |

What each one looks like in play:

- **`needle_strikes` (natural, from tier 1, repeats).** Three needles at a time light a crackling blue-white mark for 3 s; the bolt lands on the downbeat with an 8 m ring. Windows last 20 s and come back after 40 s. It changes no ground, so it uses the 3 s floor. The needle kites use the glare (their home row says so).
- **`split_spire_strike` (natural, tier 2, once).** A 6 s mark crawls up the split spire. The bolt shears off its top 40 m, which falls north and lies as a ramp from the spire's foot toward the Crown: the `toppled` route. It waits while you are within 30 m.
- **`meander_flash_flood` (natural, tier 2, repeats, three times as likely in the cloudburst).** A roar upstream for 7 s, then the gooseneck fills 1 m deep over 4 s and runs for 30 s. It closes the two meander routes and waits while you are within 20 m of the bend, so it never fills on top of you.
- **`lens_spire_wakes` (ancient, tier 2, weight 0.6).** The lens spire hums a wrong note for 9 s, then a larger Mind's hand bursts from its foot as a miniboss and leaves a crater. The spire's top stays the hands' home; the eruption is the thing under it. It is off every line on purpose.
- **`gauntlet_dropship` (Fleet, tier 1).** A Fleet dropship crosses the storm for 10 s (Brindle's anvil and brass, PARK.md:310) and lands on the Gauntlet Shelf. Its deck wakes the dormant `dropship_cutters` home. Its ramp is a kicker toward the Crown.
- **`collector_burst` (industrial, the Warden's second chunk).** The collector's whistle climbs for 5 s, then it blows an arcing steam cone 24 by 10 m for 8 s. Its catwalk falls and leans against the nearest perch spire as a ramp to the perch tops for the rest of the fight. This is stage 6's version of the boiler at the second chunk (PARK.md:383).

Timing. Tiers come every 45 s and stop at 2 today (`src/world/director.gd:83-84`); a spike adds 2 (`director.gd:164-165`). This stage uses no tier 3 or 4. Leads: 3 s for the needle strikes (no ground change), 6 s for the split spire, 7 s for the flood, 9 s for the eruption, 10 s for the dropship, 5 s for the collector. Each meets its floor (PARK.md:311) and rounds up to the next downbeat. Three rows change the ground (split spire, eruption, collector) and the flood fills a channel; the director's cap of two at once holds them apart.

New `WORLD_ROWS` forms this table needs (KE units): `lightning_mark`, `flood_rising`, `fleet_inbound`, `ancient_stirring`, `boiler_pressure`.

## 7. `home_rows` draft

| id | enemy | site (landform) | advantage | counter | reinforce: from tier, every s, max, pack | break: by, hp, scrap | stops kind | dormant |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mast_cutters` | line_cutter | `signal_masts` (mesa_rim) | The signal wire is the west fan's way into the Crown; cutters on the mast platforms throw across it as you leave the needles. | Drop off the wire early onto the bajada or glide under the arc; the mast feet stand on a 20 m rib, and a ram off the needles' north rim reaches them. | 1, 30, 3, `crown_cut` | ram, 130, 30 | true | false |
| `gauntlet_anchor_crew` | anchor_crew | `gauntlet_west` (butte) | Winch posts on the butte's rim hook a ball riding the Gauntlet net and reel it onto the deck. | Jump the cable lane before it fills, or ride the balloon lift high and slam the post from above. | 0, 35, 3, `crown_anchor` | slam, 150, 35 | true | false |
| `needle_kites` | kite_drone | `needles` (spire) | Storm updrafts between the needles hold them above ram reach, and lightning glare hides their dive marks. | Shoot them while they circle, or swing the needles and leave the mark; Kest climbs the same updraft. | 1, 25, 4, `crown_kites` | damage, 170, 30 | true | false |
| `spire_hands` | mind_hand | `lens_spire` (spire) | A spire top is a lens seat 130 m up: it has read your habit before you arrive. | Arrive on a verb it has not braced; its quote names the habit, so hit the open lens with another. | 2, 45, 2, `crown_hands` | smash, 180, 45 | true | false |
| `dropship_cutters` | line_cutter | `gauntlet_shelf` (slickrock) | The landed dropship's deck overlooks the shelf where the east lines leave for the Crown. | Its ramp is a kicker toward the Crown: take it at speed and the cutter's arc lands behind you. | 2, 30, 3, `crown_cut` | smash, 160, 40 | false | true |

Four homes use today's stage 6 packs (`src/core/alpha_defs.gd:116-120`). `spire_hands` names a new pack, `crown_hands` (`mind_hand`, `line_cutter`), because no stage 6 pack holds a Mind's hand and PARK.md 2.10 refuses a home whose pack is not in the stage's packs. KD0 adds it to the stage 6 row in `src/core/park_defs.gd`. The director's ancient pack (`src/world/director.gd:25`, `70`) still brings hands from the ring as today.

## 8. `contraption_rows` draft

| id | kind | site | recipe | spec keys (contraptions.gd) |
| --- | --- | --- | --- | --- |
| `needle_updraft` | thermal | `needles` | (primitive) | at [-150, 150], radius 6.0, height 200.0 |
| `crown_updraft` | thermal | `crown_bowl` | (primitive) | at [-80, 500], radius 6.0, height 120.0 |
| `gauntlet_updraft` | thermal | `gauntlet_west` | (primitive) | at [200, 110], radius 6.0, height 160.0 |
| `turnstone_wire` | cable | `turnstone` | (primitive) | from [-15, 120, -325], to [-80, 70, -60], radius 4.5, floor 18.0 |
| `signal_wire` | cable | `signal_masts` | (primitive) | from [-265, 62, 300], to [-100, 20, 430], radius 4.5, floor 18.0 |
| `gauntlet_balloon_lift` | lift | `gauntlet_west` | lift_platform | at [330, 90], radius 5.0, rise 90.0, charge 3.5, offset 0.0 |
| `shelf_cannon` | launcher | `gauntlet_shelf` | cannon | style "cannon", at [215, 335], radius 4.0, target [100, 0, 480], floor 30.0, min_flight 3.2, charge 2.5 |
| `meander_wall` | cracked_wall | `meander_bend` | (primitive) | at [60, -10], size [12, 6, 1.4], turn 0.0 |
| `needle_barge` | barge | `needles` | barge | a [-210, 120, 140], b [-130, 120, 220], size [14, 2, 14], travel 8.0, dwell 3.0, offset 0.0 |

Thermals are the only wind (PARK.md:188); in this storm they read as rain-lit updrafts. A cable rides one way, `from` to `to`, at an 18 m/s floor (`src/world/contraptions.gd:215-222`). The cracked wall opens only to a hard ram, so the floor line never needs it. The needle barge is a moving rock raft between two needles.

## 9. Weather and the fixed time of day

**Time: `dusk`.** The sun sits 3 degrees above the western horizon, under the storm's anvil, so the buttes' west faces burn orange while the sky above goes violet. Proposed `TIME_ROWS` row for KE7 (start): sun elevation 3 degrees, colour #ff8a5c, energy 0.55, ambient #4a4f7a at 0.5. Lightning adds 0.3 s fills. Today's crown light is the shared Highdraft morning (`src/presentation/world_look.gd:35`); PARK.md veto 2 moves it.

| id | kind | trigger | lead, live, gap s | fog | sky, sound, music layer | event odds |
| --- | --- | --- | --- | --- | --- | --- |
| `dusk_storm` | thunderstorm | always | 0, 0, 0 | 0.004, #6b5a6e | storm_build, storm_bed, (none) | none |
| `cloudburst` | monsoon | clock_tier 2 | 6, 45, 60 | 0.008, #4a4f63 | storm_build, rain_bed, layer_rain_hats | `meander_flash_flood` x3, `needle_strikes` x1.5 |

**The storm.** The thunderstorm is always on: it is what this stage is. From tier 2 the cloudburst adds rain and lower fog for 45 s, triples the flood's odds and raises the needle strikes' odds by half. Handling never changes (PARK.md 2.7). The beam on the Crown keeps the landmark readable through the rain.

## 10. Traversal lines

**The flow line.** A skater drops off the Watch Butte's north nose and carves the slickrock S down to the Turnstone. They pass the cache, cut east into the gooseneck and pump it round its bank. Then they swing past the split spire, run straight up the bajada's last stretch and launch the crown ramp into the bowl. That is the `floor` line: 1,291 m with no harpoon and no contraption. The pilot lines take a side fan in the middle or last segment, which gives them length, air and a second verb.

| line | fans taken (segment 1, 2, 3) | length m | straight m | ratio | segment lengths m | time at 20 to 26 m/s | segments at 20 m/s |
| --- | --- | --- | --- | --- | --- | --- | --- |
| sable | S, hoodoo, G | 1672 | 1070 | 1.56 | 490, 419, 763 | 64 to 84 s | 24 s, 21 s, 38 s |
| rivet | S, E, C | 1543 | 1070 | 1.44 | 490, 724, 329 | 59 to 77 s | 24 s, 36 s, 16 s |
| kest | S, meander, W | 1542 | 1070 | 1.44 | 490, 471, 580 | 59 to 77 s | 24 s, 24 s, 29 s |
| tarn | S, W, W | 1822 | 1070 | 1.7 | 490, 751, 580 | 70 to 91 s | 24 s, 38 s, 29 s |
| tally | S, E, G | 1978 | 1070 | 1.85 | 490, 724, 763 | 76 to 99 s | 24 s, 36 s, 38 s |
| cannon | S, meander, B | 1519 | 1070 | 1.42 | 490, 471, 557 | 58 to 76 s | 24 s, 24 s, 28 s |
| floor | S, meander, C | 1291 | 1070 | 1.21 | 490, 471, 329 | 50 to 65 s | 24 s, 24 s, 16 s |

Every pilot line sits inside PARK.md's ratio band of 1.3 to 2.0 (PARK.md:466). The floor line is held to its own bar: reach the Warden within twice the pilot median (PARK.md:467). Segments run 16 to 38 s at 20 m/s, inside 12 to 45 s; the shortest is the centre finish (329 m), which a fast Rivet runs in about 13 s. At 26 m/s the Cannon's and Kest's lines finish just under 60 s; if the bot averages that fast, the fix is a longer carve in the last fan.

**The tricks each line offers.**

- **Sable (vault and slingshot): hoodoo, then Gauntlet.** Vault from hoodoo cap to hoodoo cap down the forest; slingshot off the split spire. Then east: the balloon lift onto the Gauntlet net, pump it under the anchor crews' rim, drop to the shelf and take the shelf cannon into the bowl.
- **Rivet (sprint): east wash, then the centre.** Sprint the east wash, hit the east ribs and launch north-west to the split spire. Then flat out up the bajada's last stretch over the crown ramp: the stage's peak-speed line.
- **Kest (glide and rocket jump): meander, then west.** Pump the gooseneck and rocket-jump off its bank. Past the split spire, ride the needle updraft, glide over the needles and catch the signal wire down into the bowl's west wall. When the split spire has fallen, the toppled ramp is a rocket-jump launch.
- **Tarn (claw pull): west, then west.** The west wash, the talus and the alcove ledge, then claw off the rock horns above it. Past the split spire, claw through the needles and grab the signal masts for the wire into the bowl.
- **Tally (surge): east wash, then Gauntlet.** The longest line on the stage. A surge through the east wash and the Gauntlet net, where her surge breaks the anchor crews' timing.
- **The Cannon (recoil): meander, then the bajada east.** Recoil out of the bend and through its cracked wall with a recoil-boosted ram. Then across the bajada to the shelf and the shelf cannon. A cannon riding a cannon.

**Against the bands** (PARK.md:452-468), as designed and before any bot run:

| Band | How this park meets it |
| --- | --- |
| Time to engage, 60 to 120 s | 58 to 99 s at 20 to 26 m/s; see the note above |
| Segments, 12 to 45 s | 16 to 38 s at 20 m/s |
| Flow share at least 0.70 | the whole park falls 212 m from drop-in to bowl floor; nothing climbs except the balloon lift, a contraption |
| Airborne 0.25 to 0.60 | the drop ramp's lips, the east ribs launch, the crown ramp, the shelf cannon (at least 3.2 s), the two wires (rail time), the needle updraft glide, the Gauntlet's drop to the shelf. Estimate 0.25 to 0.40 (start); this is the tighter of the two Highdraft stages, and KD6 measures it first |
| Peak speed at least 26.6 m/s, 3 s at that tier | the drop ramp's 120 m fall; the east wash; a latched ride on the flying hand after engage does not count (the measure stops at engage) |
| Quiet stretch at most 20 s | the bajada's last stretch is the risk; the crown ramp, the needles and the shelf cannon break it |
| Max anchor gap 40 m | `bajada_blocks` (section 4), the hoodoos, needles and spires |
| Distinct verbs at least 3 | 4 to 6 per line |
| Distinct lines at least 3 | Sable, Rivet and Kest share no middle or last fan |

**`tools/park_lines/park_crown.json` draft.** Waypoints are [x, z] or a waymark id.

```json
{
 "map": "park_crown",
 "stage": 6,
 "pilots": {
  "sable": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [-60, -240], [-110, -150], [-60, -60], "split_spire", [150, 80], [330, 95], [228, 249], [220, 330], [100, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "rivet": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [180, -260], [300, -150], [240, -50], "split_spire", [-30, 150], [20, 250], [0, 310], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "kest": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [100, -280], [120, -170], [110, -80], [60, -20], "split_spire", [-120, 120], [-180, 200], [-270, 300], [-100, 430], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "tarn": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [-130, -255], [-300, -215], [-167, 13], [-90, 30], "split_spire", [-120, 120], [-180, 200], [-270, 300], [-100, 430], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "tally": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [180, -260], [300, -150], [240, -50], "split_spire", [150, 80], [330, 95], [228, 249], [220, 330], [100, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}},
  "cannon": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [100, -280], [120, -170], [110, -80], [60, -20], "split_spire", [180, 150], [215, 280], [220, 330], [100, 480], "landmark"], "bar": {"band": "PARK.md section 8", "airborne_share": [0.25, 0.6]}}
 },
 "floor": {"waypoints": ["drop_in", [-50, -620], [50, -520], [-30, -420], "cache_turnstone", [100, -280], [120, -170], [110, -80], [60, -20], "split_spire", [-30, 150], [20, 250], [0, 310], "landmark"]}
}
```

## 11. The music arc

The stage keeps today's music: theme 2 with the `highdraft_crown` ACE set (`src/core/alpha_defs.gd:111`; `src/presentation/music_rows.gd:13`). The arc follows the gem rules: keep the core, escalate on game-state thresholds, add layers and never swap them, and land the payoff on the gameplay moment (G11, `src/presentation/MUSIC-GEMS.md`). The storm is the stage's drummer: every lightning strike lands on a downbeat as a drop. The Mind never enters the band (`SOUND-STORY.md:280`).

| Where or what | What you hear | Rule |
| --- | --- | --- |
| Drop-in on the Watch Butte | the theme's intro over the storm bed, thunder far off | G1 |
| The drop ramp | the launch off the nose is the build, the bajada landing is the first drop | G9 |
| The meander or the east wash | the bass line's pump layer joins | G10, add a layer |
| Each needle strike | its land cue is a kick and crash on the bar the bolt lands on | G9, `on_bar` |
| The cloudburst | `layer_rain_hats`: sixteenth hats while it holds | weather `music_layer` |
| The Gauntlet, while a crew is live | the Fleet's anvil and brass | `SOUND-STORY.md:74` |
| The landmark approach | the landmark hum under the band; the beam's hum rises as you near | `src/core/event_kinds.gd:847` |
| Engage | the Warden pivot | G3 |
| Each charge | only the quote's wrong last note, held on sine for the 2 s charge; the occupied perch hums under it | kind sheet section 6 |
| A stagger | the quote again, now naming the habit it braced (the choir's brace) | `src/combat/warden.gd:535-540` |
| Half broken; three quarters | the key lift; the sinister break | G7 |
| The break | the unseal drop, then the rice-cooker clear | G2, G9 |

Event cues (proposed ids for KE8's `CUES` table): `riser_natural` into `drop_lightning` or `drop_flood`; `riser_fleet` into `drop_fleet_anvil`; `riser_mind_quote` into `drop_mind_wrong`; `riser_industrial` into `drop_boiler`.

## 12. Codex fragments from the society layer

Draft copy, one line each, in the voice of the lore lines (`SOUND-STORY.md:212-219`). Ids match the `fragment` fields.

| Id | Found at | Text (draft) |
| --- | --- | --- |
| `none_watch_butte_strata` | `watch_butte` | Read the butte bottom to top: river, dune, river, ash. Read it top to bottom and it is a countdown. |
| `none_bajada_fan` | `bajada` | A bajada is a hundred washes that forgot which one they were. Ride it like that. |
| `none_balanced_caps` | `turnstone` | The Turnstone has balanced longer than anyone has watched it. Someone left a cache under it anyway. |
| `ref_alcove_masonry` | `alcove_ledge` | Reference. Alcove masonry: shaped sandstone blocks in mud mortar, small chinking stones pressed into the joints, the room tucked under an overhang that keeps off the rain and the summer sun. |
| `none_hoodoo_spacing` | `hoodoo_forest` | Hoodoos stand about as far apart as their caps are wide. Your rope is longer than that. |
| `none_meander_scour` | `meander` | The bend floods in minutes and drains in hours. The outside wall is polished to the height of the last flood. |
| `none_fulgurite` | `split_spire` | Lightning glass in the sand at the split spire's foot. Fresh glass every storm, in the same place every storm. |
| `none_needle_count` | `needles` | Fleet survey: 41 needles. Second survey: 41. Third survey, after the storm: 40, and a ramp. |
| `fleet_storm_log` | `signal_masts` | Mast log, storm 3: collector full by dusk. The Admiral says the machines are inventory. The collector disagrees. |
| `ancient_lens_seat` | `lens_spire` | Every spire top here has a dish worn into it the exact width of a palm. |
| `net_gauntlet_mends` | `gauntlet_net` | Gauntlet net, mended nine times this season. Every tear faces the Crown. |
| `none_crown_scour` | `crown_bowl` | The bowl is scoured smooth by water falling straight off 330 m of rock. |
| `ancient_perch_wear` | `perch_spires` | Three perches, three wear marks, one rhythm: eight seconds. |
| `fleet_collector_tag` | `crown_collector` | Collector tag: INVENTORY. HANDLE AS STORM. |
| `ancient_crown_count` | the landmark | Carved round the Crown's foot: a tally of every ball that reached it. Yours is already there. |

Today's 3-2 lore lines (`src/core/lore_rows.gd:291-299`, "Tie your tools before the crown takes them" at `:295`) stay; the Crown is now literal.

## 13. What stays from today's stage

| Kept | Where it lives |
| --- | --- |
| Packs `crown_cut`, `crown_anchor`, `crown_kites` | `src/core/alpha_defs.gd:116-120` |
| Warden plating 190, health 1,400, posture curve 2.0 x 1.10, ram does not shatter | `alpha_defs.gd:114-115`, pressure row `alpha_defs.gd:65` |
| Variant `choir`: the open lens moves every 8 s and a stagger braces against the top habit | `alpha_defs.gd:120`; `src/combat/warden.gd:32-34`, `:63-65`, `:535-540` |
| Beacon seconds 25; scrap density 1.0; kill scrap 5 | `alpha_defs.gd:113` |
| Music theme 2, ACE `highdraft_crown` | `alpha_defs.gd:111`; `music_rows.gd:13` |
| The world 3 Warden band, 24.5 to 128 s | `tests/alpha_posture_bands_w23_test.gd:26-27` |
| The Mind boss and its arena | `src/boss/mind.gd` (its own choir Warden, `:58`) |

What changes: the map id (`highdraft_crown` to `park_crown`), the heading (today toward the middle island, `src/world/map_highdraft_crown.gd:52`; the park runs +z), the time of day, and `beacon_radius` 30 becomes the landmark's `reach_m` 120. The Warden stops being a clamp at a beacon and starts flying.

**Tests to re-pin, each with a dated header.**

| Test | What it pins today | After |
| --- | --- | --- |
| `tests/highdraft_crown_zone_test.gd` | slots, the net deck, islands at least NET_H + 24 (`:11`) | replaced by `tests/park_park_crown_test.gd` (KD6) |
| `tests/crown_warden_bot_test.gd` | the skipper breaks the stage 6 choir Warden (`:10`) | re-measured on `spires`: the Warden now moves |
| `tests/warden_mind_brace_test.gd` | the hand's brace is bounded (`:8`) | unchanged rule; add a case with the hand in flight |
| `tests/warden_variants_test.gd` | variants reach the Warden (`:7`) | `choir` stays on stage 6 only |
| `tests/alpha_posture_bands_w23_test.gd` | stage 6 inside the world 3 band | re-measured. PARK.md:444 lists stages 2, 3 and 5; the spires mounting changes stage 6's fight too, so add it |
| The ending fly-over | copies the Highdraft terrain and hides its grid floor (`src/ui/ending_sequence.gd:233-234`) | reads the park terrain; checked in KD7 |

## 14. Storyboard frames

Eight frames, in play order. Panels p1 to p6 of the stage board map onto frames 1 to 6; frames 7 and 8 are spares.

1. **Drop-in vista (p2_drop_in).** Dusk from the Watch Butte's north edge, 2 m above the rock, looking north. The bajada fans out below, studded with fallen blocks. The Turnstone balances at the ramp's foot. The hoodoo forest stands to the left, the gooseneck glints in the centre, the east wash runs right. On the skyline the Crown Spire with its green beam, three tiny perches at its foot, under a towering anvil cloud. A bolt strikes a needle on the left.
2. **First flow line (p3_line).** Chase camera behind the ball carving the drop ramp's S on wet slickrock, the bajada rushing up, first rain streaks, the Crown dead ahead.
3. **An enemy home (p4_home).** The needles from inside the field: kite drones circling in a rain-lit updraft above the spire tips, a dive mark on the ground half lost in a lightning flash. The counter is in frame: the updraft column Kest could ride.
4. **An event firing (p5_event).** The split spire strike in two beats: the blue-white mark crawling up the spire, then its top lying north as a ramp, fulgurite glowing at its foot.
5. **The landmark approach.** In the air off the crown ramp: the bowl below, three perch spires, the hand mid-flight between two of them, the Fleet's brass collector on the Crown's face, the beam going up into the storm.
6. **The Warden fight (p6_warden).** The ball on a harpoon line behind the flying hand, dragged in an arc over the bowl toward the next perch, where the open lens seat glows. The pulse ring follows the hand.
7. **The exit.** The hand dark in the bowl; the gates on the Crown Apron in the rain; Moss's bay docking above them; the beam still climbing into the storm.
8. **The alcove (spare).** The ball riding the alcove ledge past a small stone room tucked under the overhang, untouched; the rock horns above with a harpoon line on one.

p1_overhead is plotted from this park file by `tools/park_plot.py`, not generated.

## 15. Calls made here, and open questions

**Calls made under the creative charge (veto list).**

1. The Crown Spire is 330 m, not 300 m, for the sight rule; the margin is thin.
2. The Alcove and Gauntlet buttes turn so their long axes point at the Crown, and slim to 90 to 120 m wide, to narrow their shadows.
3. The bajada is one ramp stamp falling 80 m, with fallen blocks on an 80 m lattice as its anchors.
4. Perches 45 m from the axis and 78 m apart; a 3 s flight arc every 8 s, so a latched ball is dragged at about 28 m/s.
5. The Fleet's lightning collector on the Crown is the industrial event and the drop finisher's high anchor.
6. The split spire is the second waymark; its strike opens the `toppled` route.
7. The flash flood waits while you are within 20 m of the bend and never fills on top of you.
8. A new pack, `crown_hands`, for the Mind's-hand home (KD0).
9. Stage 6 is re-measured in the world 3 posture bands too.
10. The alcove ledge is the stage's one reference row; anchors there are the natural horns, never the masonry.

**Open questions for the coordinator.**

- The animals have no society id. Add `animal`, or keep `none`?
- The sight margin is thin (section 16). KD6's real test decides between 330 m, 360 m, or a lower Signal Butte.

## 16. Checks run on this draft

- Schema: a Python mirror of PARK.md 2.10's checks (enums, references, home landform equals site landform, packs in the stage row, lead floors by family, the society guardrail, `handling` "none", contraption keys per kind) passed. One note: `crown_hands` is not yet a stage 6 pack (section 7).
- Routes: with every closing event live, `hoodoo`, `west`, `east` and `gauntlet` stay open.
- Lines: lengths clipped at the engage ring, segment lengths between waymark passes.
- Sight: a 50 m grid over the play rect, eye 2 m above a box model of the stamped rows on the bajada ramp, ray sampled every 10 m: 0.854 over 774 cells.
- None of this ran in Godot. The traversal bands, the sight test and the density test run in KD6.

## Appendix: the park file draft

`src/world/park/park_crown.json`, as KD6 should start it. The tables above are generated from this same object.

```json
{
 "schema": "scrapkeep-park/1",
 "map": "park_crown",
 "size_m": 1600,
 "time_of_day": "dusk",
 "spawn": {"at": [0, -720], "heading_deg": 0},
 "play_rect": [-600, -780, 1200, 1520],
 "landmark": {
  "id": "crown_spire",
  "kind": "spire",
  "at": [0, 470],
  "size": [50, 330, 50],
  "yaw_deg": 0,
  "recipe": "landmark_spire",
  "budget": "hero_landmark",
  "sight_top": [0, 330, 470],
  "sight_share": 0.85,
  "beacon": [0, 470],
  "reach_m": 120,
  "warden": {"mounting": "spires", "anchor": [0, 18, 515], "path": [[0, 18, 515], [39, 18, 447.5], [-39, 18, 447.5]], "hardpoints": 3},
  "bay_dock": {"at": [0, 600], "facing_deg": 0},
  "gate_slots": [{"at": [-20, 670], "facing_deg": 0}, {"at": [0, 670], "facing_deg": 0}, {"at": [20, 670], "facing_deg": 0}],
  "light": "ancient_beam",
  "music": "landmark_hum",
  "fragment": "ancient_crown_count"
 },
 "waymarks": ["drop_in", "cache_turnstone", "split_spire", "landmark"],
 "routes": [
  {"id": "main", "from": "drop_in", "to": "landmark", "via": ["watch_butte", "drop_ramp", "bajada", "turnstone", "meander", "meander_bend", "split_spire", "crown_ramp", "crown_bowl"]},
  {"id": "hoodoo", "from": "drop_in", "to": "landmark", "via": ["watch_butte", "drop_ramp", "bajada", "turnstone", "hoodoo_forest", "split_spire", "needles", "crown_bowl"]},
  {"id": "west", "from": "drop_in", "to": "landmark", "via": ["watch_butte", "drop_ramp", "bajada", "turnstone", "west_wash", "alcove_talus", "alcove_ledge", "alcove_horns", "split_spire", "needles", "signal_masts", "crown_bowl"]},
  {"id": "east", "from": "drop_in", "to": "landmark", "via": ["watch_butte", "drop_ramp", "bajada", "turnstone", "east_wash", "east_ribs", "split_spire", "gauntlet_shelf", "crown_bowl"]},
  {"id": "gauntlet", "from": "drop_in", "to": "landmark", "via": ["watch_butte", "drop_ramp", "bajada", "turnstone", "east_wash", "split_spire", "gauntlet_west", "gauntlet_net", "gauntlet_shelf", "crown_bowl"]},
  {"id": "toppled", "from": "drop_in", "to": "landmark", "via": ["watch_butte", "drop_ramp", "bajada", "turnstone", "meander", "meander_bend", "split_spire", "crown_bowl"]}
 ],
 "park_rows": [
  {"id": "watch_butte", "element": "sky_island", "landform": "butte", "society": "none", "at": [0, -640], "y": null, "size": [220, 120, 240], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": "none_watch_butte_strata"},
  {"id": "drop_ramp", "element": "flow_line", "landform": "slickrock", "society": "none", "at": [0, -470], "y": null, "size": [160, 120, 100], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:flow_line", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": ""},
  {"id": "bajada", "element": "ground", "landform": "dry_wash", "society": "none", "at": [0, -35], "y": null, "size": [730, 80, 1500], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": "none_bajada_fan"},
  {"id": "bajada_blocks", "element": "anchor_field", "landform": "slickrock", "society": "none", "at": [0, -35], "y": null, "size": [730, 10, 1500], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "detail", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": ""},
  {"id": "turnstone", "element": "bank", "landform": "hoodoo_field", "society": "none", "at": [0, -330], "y": null, "size": [40, 45, 40], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "spire", "hole": false, "budget": "landform", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": "none_balanced_caps"},
  {"id": "west_wash", "element": "half_pipe", "landform": "dry_wash", "society": "none", "at": [-155, -262], "y": null, "size": [260, 12, 30], "yaw_deg": -73, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["west"], "fragment": ""},
  {"id": "alcove_butte", "element": "sky_island", "landform": "butte", "society": "none", "at": [-290, -60], "y": null, "size": [260, 150, 120], "yaw_deg": 35, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "alcove_talus", "element": "bank", "landform": "butte", "society": "none", "at": [-300, -215], "y": null, "size": [80, 20, 40], "yaw_deg": 35, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["west"], "fragment": ""},
  {"id": "alcove_ledge", "element": "elevated_line", "landform": "cliff_dwelling", "society": "ancestral_puebloan", "at": [-236, -98], "y": 80, "size": [200, 6, 10], "yaw_deg": 35, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:elevated_line", "stamp": "", "hole": false, "budget": "landform", "routes": ["west"], "fragment": "ref_alcove_masonry"},
  {"id": "alcove_horns", "element": "anchor_field", "landform": "mesa_rim", "society": "none", "at": [-246, -91], "y": 120, "size": [200, 6, 6], "yaw_deg": 35, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["west"], "fragment": ""},
  {"id": "hoodoo_forest", "element": "anchor_field", "landform": "hoodoo_field", "society": "none", "at": [-80, -170], "y": null, "size": [240, 60, 160], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["hoodoo"], "fragment": "none_hoodoo_spacing"},
  {"id": "meander", "element": "half_pipe", "landform": "gooseneck", "society": "none", "at": [110, -200], "y": null, "size": [260, 18, 40], "yaw_deg": 0, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main", "toppled"], "fragment": "none_meander_scour"},
  {"id": "meander_bend", "element": "bank", "landform": "gooseneck", "society": "none", "at": [90, -40], "y": null, "size": [140, 18, 140], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bank", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["main", "toppled"], "fragment": ""},
  {"id": "east_wash", "element": "half_pipe", "landform": "arroyo", "society": "none", "at": [260, -210], "y": null, "size": [280, 12, 30], "yaw_deg": 20, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "wash", "hole": false, "budget": "landform", "routes": ["east", "gauntlet"], "fragment": ""},
  {"id": "east_ribs", "element": "kicker", "landform": "slickrock", "society": "none", "at": [240, -50], "y": null, "size": [14, 2.5, 40], "yaw_deg": -50, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["east"], "fragment": ""},
  {"id": "split_spire", "element": "anchor_field", "landform": "spire", "society": "none", "at": [0, 40], "y": null, "size": [24, 120, 24], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "landform", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": "none_fulgurite"},
  {"id": "needles", "element": "anchor_field", "landform": "spire", "society": "none", "at": [-170, 180], "y": null, "size": [180, 140, 140], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "needle_kites", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": ["hoodoo", "west"], "fragment": "none_needle_count"},
  {"id": "signal_butte", "element": "sky_island", "landform": "butte", "society": "none", "at": [-460, 300], "y": null, "size": [180, 180, 160], "yaw_deg": 0, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "signal_masts", "element": "anchor_field", "landform": "mesa_rim", "society": "fleet", "at": [-270, 300], "y": null, "size": [60, 40, 40], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "mast_cutters", "recipe": "greybox:anchor_field", "stamp": "ridge", "hole": false, "budget": "landform", "routes": ["west"], "fragment": "fleet_storm_log"},
  {"id": "lens_spire", "element": "anchor_field", "landform": "spire", "society": "ancient", "at": [-330, 420], "y": null, "size": [30, 130, 30], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "spire_hands", "recipe": "greybox:anchor_field", "stamp": "spire", "hole": false, "budget": "landform", "routes": [], "fragment": "ancient_lens_seat"},
  {"id": "gauntlet_west", "element": "sky_island", "landform": "butte", "society": "none", "at": [170, 170], "y": null, "size": [180, 140, 90], "yaw_deg": -30, "verb": "bank", "ride_fact": "ride_bowl", "home": "gauntlet_anchor_crew", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": ["gauntlet"], "fragment": ""},
  {"id": "gauntlet_east", "element": "sky_island", "landform": "butte", "society": "none", "at": [390, 170], "y": null, "size": [180, 160, 90], "yaw_deg": -40, "verb": "drop", "ride_fact": "ride_drop", "home": "", "recipe": "greybox:sky_island", "stamp": "butte", "hole": false, "budget": "landform", "routes": [], "fragment": ""},
  {"id": "gauntlet_net", "element": "half_pipe", "landform": "sky_island", "society": "none", "at": [280, 175], "y": 110, "size": [180, 14, 100], "yaw_deg": -35, "verb": "pump", "ride_fact": "ride_chute", "home": "", "recipe": "greybox:half_pipe", "stamp": "", "hole": false, "budget": "landform", "routes": ["gauntlet"], "fragment": "net_gauntlet_mends"},
  {"id": "gauntlet_shelf", "element": "ground", "landform": "slickrock", "society": "none", "at": [220, 330], "y": null, "size": [120, 40, 160], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "dropship_cutters", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": ["east", "gauntlet"], "fragment": ""},
  {"id": "crown_ramp", "element": "kicker", "landform": "slickrock", "society": "none", "at": [0, 310], "y": null, "size": [24, 5, 60], "yaw_deg": 0, "verb": "launch", "ride_fact": "ride_hop", "home": "", "recipe": "greybox:kicker", "stamp": "ramp", "hole": false, "budget": "landform", "routes": ["main"], "fragment": ""},
  {"id": "crown_bowl", "element": "bowl", "landform": "slickrock", "society": "none", "at": [0, 470], "y": null, "size": [240, 12, 240], "yaw_deg": 0, "verb": "bank", "ride_fact": "ride_bowl", "home": "", "recipe": "greybox:bowl", "stamp": "bowl", "hole": false, "budget": "landform", "routes": ["main", "hoodoo", "west", "east", "gauntlet", "toppled"], "fragment": "none_crown_scour"},
  {"id": "perch_spires", "element": "anchor_field", "landform": "spire", "society": "ancient", "at": [0, 470], "y": null, "size": [90, 24, 90], "yaw_deg": 0, "verb": "swing", "ride_fact": "ride_grapple_line", "home": "", "recipe": "greybox:anchor_field", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": "ancient_perch_wear"},
  {"id": "crown_collector", "element": "ledge", "landform": "spire", "society": "fleet", "at": [16, 470], "y": 64, "size": [30, 3, 8], "yaw_deg": 90, "verb": "roll", "ride_fact": "ride_ledge", "home": "", "recipe": "greybox:ledge", "stamp": "", "hole": false, "budget": "landform", "routes": [], "fragment": "fleet_collector_tag"},
  {"id": "crown_apron", "element": "ground", "landform": "slickrock", "society": "none", "at": [0, 660], "y": null, "size": [160, 30, 300], "yaw_deg": 0, "verb": "roll", "ride_fact": "", "home": "", "recipe": "", "stamp": "plateau", "hole": false, "budget": "landform", "routes": [], "fragment": ""}
 ],
 "event_rows": [
  {"id": "needle_strikes", "kind": "lightning", "family": "natural", "site": "needles", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 3.0, "form": "lightning_mark", "on_bar": true}, "live_s": 20.0, "effect": {"strike_m": 8.0, "damage": 6.0}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 0.0, "cooldown_s": 40.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_lightning"}},
  {"id": "split_spire_strike", "kind": "lightning", "family": "natural", "site": "split_spire", "trigger": {"on": "clock_tier", "value": 2}, "weight": 1.0, "telegraph": {"lead_s": 6.0, "form": "lightning_mark", "on_bar": true}, "live_s": 0.0, "effect": {"strike_m": 10.0, "damage": 8.0, "swap": "spire_top_ramp"}, "route_change": {"closes": [], "opens": ["toppled"]}, "hold_clear_m": 30.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_natural", "land": "drop_lightning"}},
  {"id": "meander_flash_flood", "kind": "flash_flood", "family": "natural", "site": "meander", "trigger": {"on": "clock_tier", "value": 2}, "weight": 0.8, "telegraph": {"lead_s": 7.0, "form": "flood_rising", "on_bar": true}, "live_s": 30.0, "effect": {"depth_m": 1.0, "fill_s": 4.0, "material": "water"}, "route_change": {"closes": ["main", "toppled"], "opens": []}, "hold_clear_m": 20.0, "cooldown_s": 90.0, "once": false, "music_cue": {"telegraph": "riser_natural", "land": "drop_flood"}},
  {"id": "lens_spire_wakes", "kind": "machine_eruption", "family": "ancient", "site": "lens_spire", "trigger": {"on": "clock_tier", "value": 2}, "weight": 0.6, "telegraph": {"lead_s": 9.0, "form": "ancient_stirring", "on_bar": true}, "live_s": 0.0, "effect": {"miniboss": "mind_hand", "swap": "spire_foot_crater"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 18.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_mind_quote", "land": "drop_mind_wrong"}},
  {"id": "gauntlet_dropship", "kind": "fleet_landing", "family": "fleet", "site": "gauntlet_shelf", "trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0, "telegraph": {"lead_s": 10.0, "form": "fleet_inbound", "on_bar": true}, "live_s": 0.0, "effect": {"vessel": "dropship", "home": "dropship_cutters", "footprint_m": [36, 16]}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 25.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_fleet", "land": "drop_fleet_anvil"}},
  {"id": "collector_burst", "kind": "boiler_burst", "family": "industrial", "site": "crown_collector", "trigger": {"on": "warden_phase", "value": "chunk_2"}, "weight": 1.0, "telegraph": {"lead_s": 5.0, "form": "boiler_pressure", "on_bar": true}, "live_s": 8.0, "effect": {"hazard": "arc_steam_cone", "hazard_m": [24, 10], "damage": 6.0, "swap": "collector_catwalk_ramp"}, "route_change": {"closes": [], "opens": []}, "hold_clear_m": 14.0, "cooldown_s": 0.0, "once": true, "music_cue": {"telegraph": "riser_industrial", "land": "drop_boiler"}}
 ],
 "home_rows": [
  {"id": "mast_cutters", "enemy": "line_cutter", "site": "signal_masts", "landform": "mesa_rim", "advantage": "The signal wire is the west fan's way into the Crown; cutters on the mast platforms throw across it as you leave the needles.", "counter": "Drop off the wire early onto the bajada or glide under the arc; the mast feet stand on a 20 m rib, and a ram off the needles' north rim reaches them.", "reinforce": {"from_tier": 1, "every_s": 30.0, "max_alive": 3, "pack": "crown_cut"}, "break": {"by": "ram", "hp": 130.0, "scrap": 30}, "stops_kind": true, "dormant": false},
  {"id": "gauntlet_anchor_crew", "enemy": "anchor_crew", "site": "gauntlet_west", "landform": "butte", "advantage": "Winch posts on the butte's rim hook a ball riding the Gauntlet net and reel it onto the deck.", "counter": "Jump the cable lane before it fills, or ride the balloon lift high and slam the post from above.", "reinforce": {"from_tier": 0, "every_s": 35.0, "max_alive": 3, "pack": "crown_anchor"}, "break": {"by": "slam", "hp": 150.0, "scrap": 35}, "stops_kind": true, "dormant": false},
  {"id": "needle_kites", "enemy": "kite_drone", "site": "needles", "landform": "spire", "advantage": "Storm updrafts between the needles hold them above ram reach, and lightning glare hides their dive marks.", "counter": "Shoot them while they circle, or swing the needles and leave the mark; Kest climbs the same updraft.", "reinforce": {"from_tier": 1, "every_s": 25.0, "max_alive": 4, "pack": "crown_kites"}, "break": {"by": "damage", "hp": 170.0, "scrap": 30}, "stops_kind": true, "dormant": false},
  {"id": "spire_hands", "enemy": "mind_hand", "site": "lens_spire", "landform": "spire", "advantage": "A spire top is a lens seat 130 m up: it has read your habit before you arrive.", "counter": "Arrive on a verb it has not braced; its quote names the habit, so hit the open lens with another.", "reinforce": {"from_tier": 2, "every_s": 45.0, "max_alive": 2, "pack": "crown_hands"}, "break": {"by": "smash", "hp": 180.0, "scrap": 45}, "stops_kind": true, "dormant": false},
  {"id": "dropship_cutters", "enemy": "line_cutter", "site": "gauntlet_shelf", "landform": "slickrock", "advantage": "The landed dropship's deck overlooks the shelf where the east lines leave for the Crown.", "counter": "Its ramp is a kicker toward the Crown: take it at speed and the cutter's arc lands behind you.", "reinforce": {"from_tier": 2, "every_s": 30.0, "max_alive": 3, "pack": "crown_cut"}, "break": {"by": "smash", "hp": 160.0, "scrap": 40}, "stops_kind": false, "dormant": true}
 ],
 "contraption_rows": [
  {"id": "needle_updraft", "kind": "thermal", "site": "needles", "recipe": "", "at": [-150, 150], "radius": 6.0, "height": 200.0},
  {"id": "crown_updraft", "kind": "thermal", "site": "crown_bowl", "recipe": "", "at": [-80, 500], "radius": 6.0, "height": 120.0},
  {"id": "gauntlet_updraft", "kind": "thermal", "site": "gauntlet_west", "recipe": "", "at": [200, 110], "radius": 6.0, "height": 160.0},
  {"id": "turnstone_wire", "kind": "cable", "site": "turnstone", "recipe": "", "from": [-15, 120, -325], "to": [-80, 70, -60], "radius": 4.5, "floor": 18.0},
  {"id": "signal_wire", "kind": "cable", "site": "signal_masts", "recipe": "", "from": [-265, 62, 300], "to": [-100, 20, 430], "radius": 4.5, "floor": 18.0},
  {"id": "gauntlet_balloon_lift", "kind": "lift", "site": "gauntlet_west", "recipe": "lift_platform", "at": [330, 90], "radius": 5.0, "rise": 90.0, "charge": 3.5, "offset": 0.0},
  {"id": "shelf_cannon", "kind": "launcher", "site": "gauntlet_shelf", "recipe": "cannon", "style": "cannon", "at": [215, 335], "radius": 4.0, "target": [100, 0, 480], "floor": 30.0, "min_flight": 3.2, "charge": 2.5},
  {"id": "meander_wall", "kind": "cracked_wall", "site": "meander_bend", "recipe": "", "at": [60, -10], "size": [12, 6, 1.4], "turn": 0.0},
  {"id": "needle_barge", "kind": "barge", "site": "needles", "recipe": "barge", "a": [-210, 120, 140], "b": [-130, 120, 220], "size": [14, 2, 14], "travel": 8.0, "dwell": 3.0, "offset": 0.0}
 ],
 "weather_rows": [
  {"id": "dusk_storm", "kind": "thunderstorm", "trigger": {"on": "always"}, "lead_s": 0.0, "live_s": 0.0, "gap_s": 0.0, "fog": {"density": 0.004, "color": "#6b5a6e"}, "sky": "storm_build", "sound": "storm_bed", "music_layer": "", "event_odds": {}, "handling": "none"},
  {"id": "cloudburst", "kind": "monsoon", "trigger": {"on": "clock_tier", "value": 2}, "lead_s": 6.0, "live_s": 45.0, "gap_s": 60.0, "fog": {"density": 0.008, "color": "#4a4f63"}, "sky": "storm_build", "sound": "rain_bed", "music_layer": "layer_rain_hats", "event_odds": {"meander_flash_flood": 3.0, "needle_strikes": 1.5}, "handling": "none"}
 ],
 "activity_rows": [
  {"id": "camp_signal", "activity": "enemy_camp", "site": "signal_butte", "at": [-440, 320], "pack": ["line_cutter", "line_cutter", "kite_drone"], "pay": {"named": "rivet_plating"}},
  {"id": "cache_turnstone", "activity": "cracked_cache", "site": "turnstone", "at": [0, -315], "pack": [], "pay": {}},
  {"id": "bounty_gauntlet", "activity": "hauler_bounty", "site": "gauntlet_shelf", "at": [250, 365], "pack": [], "pay": {}}
 ]
}
```
