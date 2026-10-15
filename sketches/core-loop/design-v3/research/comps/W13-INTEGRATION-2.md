# CS-02 and CS-03 into wave 13: what the plan does with each borrow

Integration memo for the coordinator, 10 October 2026, the counterpart of `W13-INTEGRATION.md` (the CS-01 memo, "the first memo" below) for the Gunfire Reborn pack (CS-02) and the Roboquest pack (CS-03). Base `b5342be` (the merge of CS-01 to CS-03 onto the alpha candidate). Nothing here is applied. Every proposal is a paste block the coordinator applies after Andrew's veto window; no design source, brief, budget file or forge pack was edited.

Path conventions are the first memo's (its line 5). Paths starting `src/`, `tools/`, `tests/`, `assets/` and `design-v3/` are under `sketches/core-loop/`, except `tools/asset-forge/`, which is at the repository root. `comps/` means `sketches/core-loop/design-v3/research/comps/`. `K-UNITS.md` and `P-UNITS.md` are the gitignored briefs at `artifacts/local/alpha/push/w13/design/` in the candidate checkout. `decisions.tsv:468c` is a row on the candidate after this base (this base's `docs/decisions.tsv` ends at line 467). Row numbers are the comps README borrow numbers (`comps/README.md:66-83`); a letter splits a row whose clauses get different dispositions.

Rules this memo follows. Names from the four games are evidence labels only; nothing from them (code, text, layout, art) enters the repo. The alpha companion ruling is (a): BD-15 stands, one SPIL-9 hover chassis with two sockets, and the scrap-bot crew is post-alpha (`decisions.tsv:468c`; `BIBLE_DECISIONS.md:44`; `BIBLE.md:570`), so no row builds on the crew. The Bible and accepted ADRs win every conflict; where a borrow meets one, the conflict is named and amendment text is proposed. Movement stays out of generic pick pools (Andrew's three-characters principle). The asset-forge deltas wait for the per-character triangle sum and land as a forge pack change proposal, not a budget edit.

One citation fix the coordinator should carry. The packet and two CS-03 notes cite the three-characters movement principle at `docs/playtests/PLAYTEST-LOG.md` line 83 (`comps/roboquest/movement-and-feel.md:62`, `classes-and-perks.md:62`). In this tree line 83 is the alpha scope decision; the movement split Andrew dictated ("one could have a gliding ability and then maybe another person can have a like blink ability") is at `PLAYTEST-LOG.md:128`.

## 1. Disposition table

**Already landed by the first memo (one line each, no new row).**

- Pocket count 3 to 8 and the detour placement rules, including "no guaranteed pocket on the shortest route" (Gunfire row 18's count, Roboquest rows 27 to 29's lab lines): CS-01 row 5, now `design-v3/PARK.md:254-271` and KB8's `park_pockets_test` (`K-UNITS.md:127-144`).
- The committed telegraph as the hit geometry, a marker before the hit, and a timing probe against a reaction floor (Gunfire row 25's marker vocabulary and its lab measure at `comps/gunfire/enemies-and-bosses.md:89`; Roboquest row 31's "checked against the reaction floor"): CS-01 row 11, now `design-v3/LEGIBILITY.md:58` and KF2 to KF4 (`K-UNITS.md:382-397`).
- A ceiling curve for any counted payout and a hard cap on spend steps (Gunfire row 21's cap, Roboquest row 34's price cap): CS-01 row 7, the PC common stacking rule (`P-UNITS.md:237`).
- Difficulty adds pressure without changing the route; the dial never touches health (Gunfire row 20's "same map", Roboquest row 30's first clause): CS-01 row 3, `PARK.md:363` ("The dial") and KE6 (`K-UNITS.md:286-300`).
- Forge bands held against the budget classes until the PD units report per-character sums (the first memo's row 16, `W13-INTEGRATION.md:30`): rows 26 and 35c below carry that trigger out.
- A coarse per-enemy cost for director budgets (Gunfire row 25's threat rating): CS-01 row 2, KE9's card `cost` (`K-UNITS.md:324-338`, next wave).

**New rows.** Fit values: `already_done`, `new_unit` (lands this wave as a new unit), `extends_in_flight_unit` (lands this wave as lines in a defined unit), `next_wave`, `park`, `reject`, `owner` (Andrew's call).

| Row | Borrow in six words | Scrapkeep today | Fit | Wave 13 disposition | The one measurable |
| --- | --- | --- | --- | --- | --- |
| 18 | Fixed pocket slots draw from pools | Four authored pockets per stage in the park file, no draw (`PARK.md:256`, `:269`); the first memo parked the library (its row 6) | park | Until a replay-variety card exists and the six greyboxes pass; a drawn interior would bypass the per-stage storyboard gate (`decisions.tsv:448`, `:466`) | At least 8 distinct pocket sets per stage template over 1,000 seeds (`comps/gunfire/stage-anatomy.md:114`, start) |
| 19a | Visible trigger, caused opening, announced | The hidden pocket is a `valve` or `cracked_wall` with a visible tell (`PARK.md:256`); single player, so "announced to all" has no counterpart | already_done | None | None |
| 19b | Pocket kind sets reward tier | Every activity pays 180 scrap plus one part, rolled `common` or `rare` (`src/world/activities.gd:27-28`, `:32`, `:36`, `:40`, `:45`), except that the `enemy_camp` RULES row names `hot_rivets` (`activities.gd:32`) and `_finish` pays a named part whenever the table offers it (`activities.gd:378-382`); the alpha table offers it (`src/core/alpha_defs.gd:35`), so the camp's `pay.rarities` is never read today, and Hot Rivets is `common` (`parts.gd:25`) only by accident; a park row's `pay` override is merged for `enemy_camp` only (`activities.gd:154-158`); `surge_run` has no rule, so a row naming it builds nothing (`activities.gd:13-15`). PARK.md says "the farther a pocket pulls you off the line, the more it holds" (`PARK.md:256`), which no code backs | new_unit | KD8 (section 3b): pay follows the detour ladder. The credit price ladder (1x to 2.5x, `comps/gunfire/stage-anatomy.md:95`, start) is parked: pockets are authored, not bought | `park_pockets_test`: on every stage file the larger-detour off-line pocket's rarities are `["rare"]` and the on-line activity's are `["common"]`; where a row has `pay.named`, the test reads the rarity of the named part, not the field |
| 20a | One major event per world | Up to two ground-changing events live at once, `once` rows, 20 s calm after a break (`PARK.md:352`, `:140-141`) | reject | Bible: events "ebb and flow to create local pressure and release" (`BIBLE.md:519`, which also leaves overlap limits open, Q-P24 and Q-P38); a once-per-world cap starves that. The bounded-overlap rule is Scrapkeep's form | None |
| 20b | Pocket hazards switch off on clear | No hazard inside a pocket: the 40 m clear ring bars contraption hazards at each door (`PARK.md:266`); the crew-repair use (`comps/gunfire/stage-anatomy.md:97`) is post-alpha | park | Until a pocket carries a hazard of its own | None |
| 20c | Health and damage on tier curves | Enemy health comes from the stage threat only; the clock adds packs, never toughness (`src/world/director.gd:7-8`, `:168-170`); Breath eases pressure keys, not health (`director.gd:106-110`) | reject | The director honesty rule (`src/world/director.gd:7-8`, `:168-170`) keeps health off the clock; any such axis would be an opt-in setting for Andrew | None |
| 21 | Burden items paid by count | Hot-wired parts: one upside, one stated downside, at most one held (`src/build/parts.gd:187-196`, `:288-302`) | park | The visible-downside half exists. A payout that counts burdens needs more than one held, which the one-held rule forbids; revisit after play of hot-wired parts | Burden sweep, 0 to 10 burdens: payout under its cap with steps that never grow, net power at most 3x (`comps/gunfire/scrolls-and-synergies.md:86`, start) |
| 22 | Milestone slots, partner shown missing | Tree depth opens by world: depth 2 in world one, 3 and 4 later (`BIBLE.md:432`, `:538`); a synergy's hint card shows the missing ingredient (`parts.gd:374-382`). The bot-as-partner clause needs the crew | already_done | None in wave 13; the bot partner is post-alpha under ruling (a) | None |
| 23 | Status marks, fusion grid, named pools | Cannon Plate exposes enemies to contact strikes only (`src/combat/combat.gd:240-245`, `:573`); elements meet materials through one default-deny table (`src/build/elements.gd:3-15`); the element pool is open (`BIBLE.md:359`; Q-P13 is in `BACKLOG.md`) | park | Until Q-P13 picks the element pool; any fusion must then be a row of the TADR-009 table, resolved once (`BIBLE.md:493` says attack geometry is resolved once) | Both orders of each pair give one effect; preview at least 12 frames before damage (`comps/gunfire/elements-and-fusion.md:85`, start) |
| 24a | Three levels, higher replaces lower | Parts stack as copies under `STACK_RULES`; the tree replaces by depth (`BIBLE.md:432`) | reject | Conflicts with CS-01 row 7, which landed stacking families for parts | None |
| 24b | Movement stays out of generic pools | 5 of the 18 parts the alpha table offers every pilot are `mobility` family with no `class_id` (Grip Tread, Live Line, Vent Baffle, Spring Shims, Drop Weight: `parts.gd:55-74`; `src/core/alpha_defs.gd:25-38`); the Bible leaves "class versus item" open for the Mobility slot (`BIBLE.md:535`) | extends_in_flight_unit | Now: a PC common rule bans new generic movement parts. Next wave: PC-POOL re-points the five (section 3e). Owner: the Bible row amendment (section 5) | Offers from `offer_pool` for every pilot hold zero `class_id` "" parts with a movement mod (today 5 of 18 listed) |
| 24c | Forced-or-skip late offer | Tree offers open at safe grounded moments (`BIBLE.md:538`) | park | No late-world offer type exists to make forced; revisit with depth-4 content | None |
| 25a | Elite affix named on enemy | The elite is an authored pack, once at `elite_arrival`, repeating at 0.1 x `elite_rate` (`director.gd:99-101`, `:288-292`); every roster row owns one mechanic, no reskins (`src/combat/roster.gd:12-15`) | park | An affix layer is a new enemy feature and needs the no-reskins rule restated first | None |
| 25b | Boss phases at thresholds, one read | Warden phases are triggers: `engaged`, `stagger`, `chunk_1` to `chunk_3`, `broken` (`PARK.md:365`), with posture bands per kind (KF2 to KF4) | already_done | None | None |
| 26 | Second budget point, stylized game | Enemy class cap 1,100 tris, 3 draws, set from Scrapkeep's own members (`assets/asset_budgets.json:3-8`); the pack's rig at `tools/asset-forge/packs/core-loop.toml:166` is the 25-bone pilot rig, so static enemy meshes are implied by the model kind, not stated there | park | Delta 4 waits for the per-pilot sum (row 35c); its proposal is section 3f | None until the sum reports |
| 27 | Closable entrance sockets per zone | No zone library, no builder; stages are authored park files; live route changes come from event rows (`PARK.md:138`, `:350`) | park | Only matters if stages assemble from zones at run time; would change an approved journey | Re-roll under 10% and at most half the fixed-entrance rate (`comps/roboquest/stage-anatomy.md:125`, start) |
| 28 | Fixed content bundle per kind | Each activity kind already has one rule: what starts it, what finishes it, what it pays (`activities.gd:29-46`). The trade-pocket bundle carries TADR-011's crew workbench | already_done | The workbench is rejected for the alpha under ruling (a) | None |
| 29a | World pool, secret map tint | Pockets authored per stage; no map UI (the HUD pointers are edge markers, `src/ui/edge_markers.gd:8-12`) | park | Pool: as row 18. Tint: no map exists; if wanted, an amber edge marker inside the 240 m `sight_ok` range (`PARK.md:265`), never the 60 m comps value | None |
| 29c | Full-visit walking ratio | KB8's report prints per-pocket `d_spawn`, `d_landmark` and detour, no tour (`K-UNITS.md:138`); `maps-compared.md:53` leaves optional walking time open | extends_in_flight_unit | KB8 report column `full_visit_ratio`, reported not gated (section 3a) | Shortest tour through all four doors to the beacon over the spawn-to-beacon path, at most 3.0 (`comps/roboquest/stage-anatomy.md:125`, start) |
| 30a | Elites capped per stage | No cap: after the first elite, each arrival may be the elite again at 0.1 x `elite_rate`, never twice running (`director.gd:99-101`, `:288-292`); PC-PACK raises `elite_rate` to 1.50 and 1.70 on stages 5 and 6 (`P-UNITS.md:328`) | extends_in_flight_unit | KE6 reports elite arrivals per stage on the park table; a cap of 3 is built only if the report exceeds it (section 3c) | Elite arrivals per stage, 20 seeds x 30 stepped minutes; build the cap only if any seed exceeds 3 (`comps/roboquest/stage-anatomy.md:110`, start) |
| 30b | Scattered marks as optional objective | The Warden posture fight is the stage objective (`PARK.md:455-492`); what an exit requires is Q-P38's (`adr/TADR-010-open-stages-and-event-director.md:63`) | park | Q-P38 owns it | None |
| 31a | Fast wind-up bands by class | Boss hazards warn at least 1.0 s (`src/boss/hazard.gd:19`); Warden pulse 2.0 s (`src/combat/warden.gd:52`) | reject | The note calls 0.25 to 0.75 s study bands (`comps/roboquest/enemies-and-telegraphs.md:104`); readability first keeps Scrapkeep's longer warnings | None |
| 31b | Correct the pack-kind timing text | `LEGIBILITY.md:58` says pack kinds "stay at 1.0 to 1.1 s"; code has seven kinds under 1.0 s: bola thrower 0.5 (`src/combat/bola_thrower.gd:34`), chaser 0.6 (`chaser.gd:12`), line cutter 0.6 (`line_cutter.gd:36`), kite drone 0.8 (`kite_drone.gd:40`), swatter 0.8 (`swatter.gd:33`), deflector 0.9 (`deflector.gd:52`), lamp swarm 0.9 (`lamp_swarm.gd:44`); the longest is mind hand 1.4 (`mind_hand.gd:26`) | extends_in_flight_unit | LEGIBILITY text corrected to the code (section 3d); KF2's `telegraph_timing_test` reports every pack kind's warn time, not gated | The report lists all pack kinds with warn seconds; the text and the report agree on every kind |
| 31c | Recovery and cooldown on record | Recovery and rest are per kind (`src/combat/counter.gd:46-48`; chaser RECOVER `chaser.gd:16`; Warden cycle 6.0 s, `warden.gd:51-52`); no test reads the tail | extends_in_flight_unit | KF2 to KF4 report recovery and cooldown beside charge length, not gated (section 3d) | Each Warden attack's recovery and cooldown printed per run; no universal 0.75 s value |
| 31d | Budget on simultaneous attackers | Alive count capped at `HARD_CAP` 24 (`director.gd:90`, `:173-175`); each enemy attacks on its own rest timer (`counter.gd:144`); packs arrive together (`director.gd:20-21`) | next_wave | KE9's lab spawner arm logs the peak count in WARN or LIVE (section 3c); a token cap only if the peak passes a threshold the lab sets. The budget size is not decoded in the source (`enemies-and-telegraphs.md:22`) | Peak simultaneous WARN or LIVE enemies per seed, both director modes; suggested trigger more than 6 (assumption, not a cited number) |
| 31e | One universal stagger window | Warden stagger 4.0 s (`src/combat/boss_posture.gd:17`), pinned by posture bands; counters interruptible by knock speed (`counter.gd:151`) | park | Would move the posture bands KF1b is still settling (`decisions.tsv:451`, `:454`) | A logged knock that should interrupt and did not |
| 31f | Elite as flat stat tier | Health from stage threat only (`director.gd:7-8`) | reject | Director honesty rule | None |
| 31g | Wind-up, size, damage as separate dials | Each kind sets warn, shape and damage as separate constants; nothing derives warn from size (`src/combat/telegraph.gd:6-10`; `warden.gd:67-71`) | already_done | None | None |
| 32a | Families by chassis, bands per family | Roster sorted by owned mechanic and role, 19 rows (`roster.gd:10-30`); enemy class cap set from Scrapkeep members (`asset_budgets.json:3-8`) | park | A chassis column is doc-only and waits for a new enemy batch; per-family bands from the whole-asset numbers cannot move a per-asset cap (`comps/roboquest/production-budgets.md:142-146`) | None |
| 32c | Free base-mesh shortlist | The forge writes original procedural geometry, "No external assets" (`tools/asset-forge/forge.py:310`); one downloaded asset, the CC0 sky, with Andrew's approval (`assets/registry.json:3001-3009`) | owner | Andrew decides whether any enemy starts from a free base; each download needs his yes | If yes, one base reshaped and measured against the 1,100-tri enemy cap |
| 32d | Provenance recipe for fetched bases | `docs/project/ASSETS.md:17` asks for source, creator, license evidence, transformations and use; no SHA-256, no saved license page, no pre-ship re-check; `tests/asset_registry_test.gd` reads no provenance | next_wave | PD-PROV (section 3g), before any external base is fetched | A shipped asset with neither a recipe nor the provenance fields fails the registry test |
| 32e | No ripped mesh, even resculpted | Written in `docs/project/ASSETS.md:23` and `comps/README.md:40`; forge stamps original geometry (`forge.py:310`) | already_done | PD-PROV's check makes it testable | None |
| 33a | Speed bank, refunds, uptime, speed ratios | Movement is per pilot (the Shift column, `design-v3/PILOTS.md:11-18`); no frame counts exist for the source (`comps/roboquest/movement-and-feel.md:81`) | park | Owed a 60 fps capture session; the 1.2 to 1.3 burst ratio, 25 to 75% uptime and 1 to 2 s refunds are proposals (`movement-and-feel.md:64-68`, start) | Three pilots' speed traces differ in shape, not only scale (`movement-and-feel.md:83`) |
| 33b | Shared floor, distinct mobility verb | Shared roll, jump, harpoon and slam; each pilot's own Shift (`PILOTS.md:11-18`), tested in `tests/char_movement_test.gd` | already_done | None | None |
| 34 | Two-layer build, envelopes, weighted offers | Alpha build is Path, Relic and Parts (`BIBLE.md:432`); one fixed weapon per pilot (`PILOTS.md:11-18`); offers already filter class mods (`parts.gd:399-415`) | park | A weapon-local layer has no object while each pilot has one weapon; revisit if weapons become finds | Class-weighted share 60 to 80% over 200 draws per pilot (`comps/roboquest/classes-and-perks.md:82`, start) |
| 35a | 2,048 character texture ceiling | Every texture capped at 2,048, all are 512 or 1,024 today (`asset_budgets.json:100-102`) | already_done | None | None |
| 35b | 4,096 texture by exception | Characters are flat colour per slot (`core-loop.toml:3`) | reject | No texture to size; the note calls the exception weak (`comps/roboquest/production-budgets.md:148`) | None |
| 35c | Check the per-character triangle sum | Caps are per asset; no tool sums a pilot (shell 11,000, layer 1,500, pilot 4,600: `asset_budgets.json:39-50`, `:92-98`); neutral shell 6,476 tris (`decisions.tsv:447`); draw cap raised to 16 for Hoberman shells (`decisions.tsv:458`) | extends_in_flight_unit | PD fix round 2 reports a per-pilot sum (section 3f); this releases row 26 and the forge proposal for review | Per pilot at class V: shell + four layers + pilot body tris and draws; worst case by caps 6,476 + 4 x 1,500 + 4,600 = 17,076 tris (own arithmetic) |

Counts, 38 rows: already_done 8 (rows 19a, 22, 25b, 28, 31g, 32e, 33b, 35a), new_unit 1 (19b), extends_in_flight_unit 6 (24b, 29c, 30a, 31b, 31c, 35c), next_wave 2 (31d, 32d), park 14 (18, 20b, 21, 23, 24c, 25a, 26, 27, 29a, 30b, 31e, 32a, 33a, 34), reject 6 (20a, 20c, 24a, 31a, 31f, 35b), owner 1 (32c).

## 2. What lands this wave

| Row | Lands in | Kind |
| --- | --- | --- |
| 19b | KD8 Pocket pay (new, K-D wave, before the greyboxes); one KD1 to KD6 acceptance line; one KB8 report column; PARK.md 2.12 sentences | new unit plus lines |
| 24b | P-UNITS section 2 common rules (one bullet) | line in PC-SABLE to PC-CANNON |
| 29c | KB8 report (`full_visit_ratio`) | line |
| 30a | KE6 acceptance (elite arrivals reported) | line |
| 31b | `LEGIBILITY.md:58` text (the wrong text started in the first memo's row 11, `W13-INTEGRATION.md:209`); KF2 acceptance (pack-kind warn report) | text plus line |
| 31c | KF2 to KF4 acceptance (recovery and cooldown reported) | line |
| 35c | P-UNITS PD common rules (per-pilot sum in the REPORT) | line in the PD fix round 2 packets |

**KD8 brief** (paste block in section 3b). It is small and touches one file outside every KD unit's SCOPE, so it is its own unit rather than a KD line.

**In-flight check.** Of the units above only the six PD pilot units are live: held on their branches for fix round 2 (`decisions.tsv:457`). Line to send with their fix-round packet: "Your REPORT adds a per-pilot sum table at classes I, III and V: base shell, each heft layer, pilot body, totals of tris and draws, from your Common VERIFY step (2) inspect calls; report only, no cap changes." KB8, KD1 to KD6, KE6 and KF2 to KF4 have not started (KB8 is not in any merge row through `decisions.tsv:467`; KF2 to KF4 start after KF1b, `decisions.tsv:454`), so their briefs are amended before dispatch. No proposal moves a posture band, a traversal band or a budget class.

## 3. Paste blocks

### 3a. Row 29c and row 19b, the KB8 report

**Target: `K-UNITS.md` KB8 ACCEPTANCE, replace the bullet that begins `  - The report prints nodes, edges, bytes,`.**

```markdown
  - The report prints nodes, edges, bytes, the spawn-to-beacon share of the longest path, and per pocket its `d_spawn`, `d_landmark`, detour, `sight_ok` and `pay.rarities`; per stage it prints `full_visit_ratio`, the shortest path from `spawn.at` through all four pocket doors in any order to `landmark.beacon`, over the spawn-to-beacon path (reported, not gated; start target at most 3.0, `comps/roboquest/stage-anatomy.md:125`).
  - `park_pockets_test` also holds the pay ladder of PARK.md 2.12: the off-line pocket with the larger detour has `pay.rarities` `["rare"]`, the on-line activity `["common"]`; a row with `pay.named` is judged by the rarity of the named part, because `named` wins over `rarities` in `_finish` (`activities.gd:378-382`, today the on-line camp's Hot Rivets, `common`); a planted fixture row that swaps the tiers turns the test red.
```

### 3b. Row 19b, pay follows the detour

**Target: `design-v3/PARK.md` section 2.12, line 256. Replace the sentence `One activity sits on the line, an `enemy_camp` or `surge_run`, usually a waymark.` with:**

```markdown
One activity sits on the line, an `enemy_camp`, usually a waymark; a `surge_run` qualifies once `src/world/activities.gd` has a rule for it (today it has none, so a park row naming it builds nothing, `activities.gd:13-15`).
```

**Same line. Replace the sentence `Detour is the price: the farther a pocket pulls you off the line, the more it holds, and a player who skips every pocket loses only the detour.` with:**

```markdown
Detour is the price, and the pay follows it. The on-line activity's part is `common` only (the camp's named Hot Rivets already is, and a named part wins over the roll, `activities.gd:378-382`); the off-line pocket with the smaller detour rolls `common` or `rare`, today's roll (`activities.gd:27`); the one with the larger detour, which this section makes the reward, rolls `rare` only (start). Scrap stays 180 on every activity (`activities.gd:28`), so the heft pace does not move and no price is set (BIBLE.md:513). Each activity row carries its `pay.rarities` in the park file. A player who skips every pocket loses only the detour.
```

**Target: `K-UNITS.md`, a new block after KD7 (insert before the `---` line that precedes `## Wave K-E, dynamics`).**

```markdown
### KD8 Pocket pay

- **GOAL.** Every activity kind takes its pay rarities from its park row, so each stage authors PARK.md 2.12's pay ladder, and a park row naming a kind with no rule is caught.
- **SCOPE.** `src/world/activities.gd` (`_build` merges `pay.rarities` and `pay.named` from the site spec for every kind; `pack` stays `enemy_camp` only), `tests/activities_pay_test.gd` (new).
- **CONTEXT.** PARK.md 2.12 (the ladder sentence); `activities.gd:27-46` (RULES and pay), `:150-158` (today's merge, `enemy_camp` only), `:13-15` (a kind with no rule builds nothing). Scrap is not authorable: `PAY_SCRAP` 180 drives the heft pace (`activities.gd:22`).
- **ACCEPTANCE.**
  - A `cracked_cache`, an `ambush_altar` and a `hauler_bounty` site given `pay.rarities` `["rare"]` each pay a rare part over 20 seeds; given `["common"]`, a common one.
  - A site with no `pay` key pays exactly as today; `activities_test`, `activities_camp_test` and `bot_explorer_activities_test` green and unchanged.
  - A spec `pay.scrap` is ignored: every kind pays `PAY_SCRAP`.
  - A site with `pay.named` pays that part when the table offers it, and `named` wins over `pay.rarities`; the ladder test reads the paid part's rarity, so an `enemy_camp` paying `hot_rivets` passes as `common` and a named part of the wrong tier fails.
  - The test lists every `activity_rows` kind in `src/world/park/*.json` that has no RULES row, and fails if one appears (today `surge_run` has none).
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'activities_pay_test' --test 'activities_test' --test 'activities_camp_test' --test 'bot_explorer_activities_test'` (4 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Changing `PAY_SCRAP`, `PAY_RARITIES` or any RULES row's default pay; adding a `surge_run` rule (a design unit of its own).
- **Depends on.** Nothing. **Shares files with.** None. Must merge before the KD greyboxes.
```

**Target: `K-UNITS.md` KD1 to KD6 ACCEPTANCE, after the bullet that begins `  - `tools/park_graph.gd` run on the stage;`.**

```markdown
  - Each activity row carries `pay.rarities` per PARK.md 2.12's ladder (on-line `["common"]`, smaller-detour off-line `["common", "rare"]`, larger-detour off-line `["rare"]`), and no row uses a kind without an `activities.gd` rule.
```

**Target: `K-UNITS.md` KD1 to KD6 Depends, replace `- **Depends on.** KB4, KB7, KB8, KC0, KD0,` with `- **Depends on.** KB4, KB7, KB8, KD8, KC0, KD0,`.**

**Target: `K-UNITS.md` dependency graph, line 438.** Change `KB4 + KB7 + KB8 + KC0 + KD0 + storyboard n ─> KDn greybox (n = 1..6)` to `KB4 + KB7 + KB8 + KD8 + KC0 + KD0 + storyboard n ─> KDn greybox (n = 1..6)`.

**Target: `K-UNITS.md` dispatch table, wave 4 (line 453).** Replace `KC9` with `KD8` in the units cell (still 8 units) and add "KD8 needs nothing and must merge before the greyboxes" to its "Why now". The wave 5 "Why now" cell (`K-UNITS.md:454`), which lists KB4, KB7, KC0 and KD0, also gains KD8. Wave 6 (KE1 alone) gains KC9, which depends only on KC0 (`K-UNITS.md:188`).

### 3c. Rows 30a and 31d, the director reports

**Target: `K-UNITS.md` KE6 ACCEPTANCE, after the bullet that begins `  - Over 30 stepped minutes on `--table=park`, 20 seeds:`.**

```markdown
  - The same run reports elite arrivals per stage per seed on `--table=park` (reported, not gated). If any seed exceeds 3 (start, `comps/roboquest/stage-anatomy.md:110`), the coordinator opens a cap unit; KE6 adds no cap.
```

**Target: `K-UNITS.md` KE9 ACCEPTANCE (next wave), after the bullet `  - The lab spawner arm (section 6) reported, both modes.`.**

```markdown
  - The spawner arm also reports, per seed and mode, the peak count of enemies in WARN or LIVE at once, at the park table's highest tier (reported, not gated). A shared attacker budget is built only if the lab sets a threshold and a peak passes it; such a budget would live in combat, asked where the counter decides to attack (`src/combat/counter.gd:144`, before `_warn` at `:175`), with the Warden and its posture fight exempt.
```

### 3d. Rows 31b and 31c, telegraph timing

**Target: `design-v3/LEGIBILITY.md` line 58. Replace the sentence `An enemy attack warns for at least 1.0 s (`src/boss/hazard.gd:19`); pack kinds stay at 1.0 to 1.1 s, and a charge longer than 3 s belongs to a Warden or a miniboss.` with:**

```markdown
A boss hazard warns for at least 1.0 s (`src/boss/hazard.gd:19`). Pack kinds set their own warning, 0.5 to 1.4 s today: seven sit under 1.0 s (bola thrower 0.5, chaser 0.6, line cutter 0.6, kite drone 0.8, swatter 0.8, deflector 0.9, lamp swarm 0.9; for example `src/combat/bola_thrower.gd:34`, `src/combat/chaser.gd:12`), and the longest is the mind hand at 1.4 (`src/combat/mind_hand.gd:26`). A charge longer than 3 s belongs to a Warden or a miniboss. Warning time is a per-kind choice read against these numbers, never derived from an attack's size or damage.
```

**Target: `K-UNITS.md` KF2 to KF4 ACCEPTANCE, replace the bullet that begins `  - `tests/telegraph_timing_test.gd`, the kind's own attacks:`.**

```markdown
  - `tests/telegraph_timing_test.gd`, the kind's own attacks: over 20 runs per attack, the cue starts within one physics tick of the charge, the charge length is within one tick of its row, zero damage lands outside the live window, and 30 hits in 3 s keep shake under the camera row's cap. The report prints each attack's recovery and cooldown seconds beside its charge length (reported, not gated).
  - KF2 only: the report also prints every pack kind's warn seconds as its script sets them (reported, not gated), so LEGIBILITY section 2's list can be checked against code.
```

### 3e. Row 24b, movement out of the generic pool

**Target: `P-UNITS.md` section 2 common rules, after the bullet that begins `- **Stacking and composition (comps rows 7 and 8).**`.**

```markdown
- **Movement stays with the pilot (comps row 24).** A part, relic or tree node the unit adds that changes a movement knob (a `Tuning.SPECS` movement key, a boost or dash cooldown, the Shift) carries the pilot's `class_id` or lives in the pilot's own tree; nothing the unit adds to the shared pool (`class_id` "") moves the ball differently. The unit's own test asserts it for every row it adds.
```

**Target: `P-UNITS.md`, a new block after PC-PACK (insert before `## 3. Wave P-D: bodies and mechas`), marked next wave.**

```markdown
### PC-POOL: movement out of the shared pool (next wave)

- **GOAL.** No part every pilot can be offered changes how the ball moves; the five shared movement parts keep their ids, tags and evolution roles and change what their verb does instead of how fast it moves.
- **Writer.** Sonnet.
- **SCOPE.** `src/build/parts.gd` (rows `grip_tread`, `live_line`, `vent_baffle`, `spring_shims`, `drop_weight` only), `tests/parts_pool_movement_test.gd` (new); dated re-pins only of tests that pin those five rows' numbers.
- **CONTEXT.** `parts.gd:52-74` (the five rows, added in wave 11 GP2 as one part per verb); `alpha_defs.gd:25-38` (the 18 listed parts); `live_line` and `drop_weight` are the second ingredients of two evolutions (`alpha_defs.gd:29-30`); Andrew's three-characters principle (`docs/playtests/PLAYTEST-LOG.md:128`); `comps/gunfire/heroes-and-ascensions.md:66`, `:71`.
- **ACCEPTANCE.** Each of the five becomes either a class part (`class_id` of the pilot whose Shift or line skill it deepens) or a shared part whose mod is not a movement knob (for example slam damage instead of slam speed); ids and tags unchanged; both evolutions still complete for every pilot; `offer_pool` for each of the six pilots returns zero `class_id` "" parts with a movement mod; each pilot still wins at least 3 of seeds 1 to 4.
- **VERIFY.** compile; lint; smoke(`parts_pool_movement_test`, `bot_six_pilots_test`, `posture_bands_test`, `alpha_posture_bands_test`, plus every test that names one of the five ids): count stated in the REPORT; fence.
- **TIMEBOX.** 2 hours.
- **FORBIDDEN.** Removing a part from `alpha_defs.gd` PARTS; changing a pilot's Shift; any part outside the five.
- **DEPENDS ON.** PC-PACK merged; Andrew's answer on the Bible's Mobility row (section 5).
- **SHARES.** `parts.gd` with any PC unit's part rows (merge after them).
```

### 3f. Rows 35c and 26, the per-pilot sum and the forge pack proposal

**Target: `P-UNITS.md` PD common rules, after the bullet that begins `- **C5, budgets.**`.**

```markdown
- **C5b, per-pilot sum (comps rows 26 and 35).** The REPORT carries one table per pilot at classes I, III and V: base shell, each heft layer present, pilot body, and the totals of tris and draws, read from Common VERIFY step (2)'s inspect calls and the pilot row in `assets/asset_budgets.json` (`:45-50`). Report only: no cap or class changes.
```

**Target: `tools/asset-forge/packs/core-loop.toml`, insert before the line `# Real-world size sanity per category: longest bounding-box edge in metres, [low, high].`. A forge pack change proposal for the forge owner, inert as comments; it becomes live keys only under its condition.**

```toml
# PROPOSED (comps rows 26 and 35, W13-INTEGRATION-2.md section 3f), not applied.
# Condition: apply only after every PD pilot unit has reported its C5b per-pilot sum and the
# forge owner has read it. assets/asset_budgets.json wins every conflict: its class caps replace
# these bands whenever the checkout has it (budgets = ... above), and nothing here edits it.
# 1. hero: replace [3000, 6500] with [low, high] taken from the measured class V sums
#    (shell + four heft layers + pilot body); the band predates the Hoberman shell
#    (neutral shell 6,476 tris, decisions.tsv:447).
# 2. Character textures: a 2,048 px ceiling on the longer side, no exception
#    (asset_budgets.json texture max_side already 2,048; flat colour per slot, line 3).
# 3. kit [800, 1500] stays: the enemy class cap is 1,100 tris from Scrapkeep's own members,
#    and the study's whole-asset enemy numbers cannot move a per-asset cap.
# 4. Bones and clip caps: none for enemies (static meshes, no rigs); pilots keep the 25-bone
#    pilot-v1 rig, under the proposed 80-bone hero ceiling.
# If any class V sum exceeds the 16,000-tri pod ceiling (asset_budgets.json:43), stop: the
# shell class is the problem, not this band.
```

### 3g. Row 32d, provenance (next wave)

**Target: `P-UNITS.md`, a new block after PD-INT (insert before `## 4. Wave P-E: clips`), marked next wave.**

```markdown
### PD-PROV: provenance fields and their check (next wave)

- **GOAL.** Every shipped model or texture has either a tracked recipe or a complete provenance record, and the registry test fails one that has neither.
- **Writer.** Sonnet.
- **SCOPE.** `docs/project/ASSETS.md` (line 17 only), `tests/asset_registry_test.gd` (a provenance check), `tests/asset_provenance_test.gd` (new, planted rows).
- **CONTEXT.** `ASSETS.md:17` (today's fields), `:23` (the comps study posture and Andrew's private archive exception; the test must never read that archive); the CC0 sky row as the one downloaded example (`assets/registry.json:3001-3009`); `comps/roboquest/enemy-design-grammar.md`, the provenance paragraph under "Base mesh sources".
- **ACCEPTANCE.** `ASSETS.md:17` adds three fields: SHA-256 per downloaded file, a saved copy of the license line, and a re-check date before a build ships. The registry test fails a planted asset with no recipe and no provenance, and a planted download missing its hash; every current asset passes unchanged.
- **VERIFY.** compile; lint; smoke(`asset_registry_test`, `asset_provenance_test`): 2 files; fence.
- **TIMEBOX.** 2 hours.
- **FORBIDDEN.** Fetching any file; editing a budget class.
- **DEPENDS ON.** Nothing; must merge before any external base is fetched.
- **SHARES.** `asset_registry_test.gd` with any PD unit (merge after them).
```

## 4. Next wave and parked

**Next wave.**

| Row | Unit | Why not now |
| --- | --- | --- |
| 24b (the five shared parts) | PC-POOL (3e) | Changes offers the wave 11 bots were tuned on; waits for PC-PACK and Andrew's answer on the Bible's Mobility row |
| 31d | KE9 line (3c) | KE9 itself is next wave (first memo, row 2) |
| 32d | PD-PROV (3g) | No external file is fetched this wave |

**Parked, with the trigger that reopens each.**

| Row | Reopen when |
| --- | --- |
| 18, 29a | A replay-variety card exists and the six greyboxes pass (first memo's row 6, same reason) |
| 20b | A pocket carries a hazard of its own |
| 21 | Play of the two hot-wired parts says a second burden is wanted; the one-held rule changes first |
| 23 | Q-P13 picks the element pool |
| 24c | Depth-4 tree content exists |
| 25a | A new enemy batch is authorized and the no-reskins rule says how an affix differs from a reskin |
| 26 | Every PD pilot reports its C5b sum (3f) |
| 27 | Stages assemble from zones at run time |
| 30b | Q-P38 decides what an exit requires |
| 31e | A playtest logs a knock that should interrupt and did not |
| 32a | A new enemy batch is authorized (then a doc-only chassis column first) |
| 33a | A 60 fps capture session of the source exists (`comps/roboquest/movement-and-feel.md:81`) |
| 34 | Weapons become finds rather than a fixed pilot weapon |

Optional and not proposed: a KB8 test that no pocket door gates the route (the comps anti-pattern at `comps/roboquest/stage-anatomy.md:116`). KE1's route test varies events, not pockets; add it only if a stage page puts a pocket on the line that must be cleared.

## 5. Veto list for Andrew

Two calls only you can make go first.

1. **Free base meshes for enemies.** Whether any Scrapkeep enemy starts from a free CC0 model reshaped to our look, or every enemy stays built from scratch as today. Default: stay built from scratch. Each download would need your yes.
2. **The Bible's Mobility row.** The Bible leaves "class versus item" open for mobility (`BIBLE.md:535`). Proposed amendment text, replacing that sentence: "Movement that changes how a pilot moves belongs to that pilot: its own tree, its Shift and parts bound to it. Shared parts may change what a verb does, never how far or fast the ball moves. Optional transformative items keep the exception in Movement, camera and active aim." Default: adopt it.

Calls this memo makes under the creative charge. Each is a default you can strike.

3. Pay follows the detour. The farther side pocket always pays a rare part, the nearer one common or rare, the pocket on the main line common only. Scrap stays 180 each, so growth pace does not change.
4. Surge runs stay off the stage files until they have a rule; the activity on the main line is an enemy camp.
5. From this wave, new parts that change movement belong to one pilot. Next wave, the five shared movement parts (Grip Tread, Live Line, Vent Baffle, Spring Shims, Drop Weight) change what their verb does instead of how fast it is, keeping their names and their roles in two evolutions.
6. The telegraph text is corrected to the code. The seven pack attacks that warn in under a second (0.5 to 0.9 s) keep their timing this wave and are measured, not raised.
7. No single recovery time or stagger time for every enemy; each kind keeps its own.
8. The study's fast wind-ups (0.25 to 0.75 s) are not adopted.
9. Elites per stage are counted on the parks first; a cap of three is built only if the count goes higher.
10. Enemies attacking at once are measured before any limit is built.
11. Drawn pockets, closable entrances, a map tint for secrets and a scattered-target objective are parked.
12. Hot-wired parts stay one at a time; items that pay per downside held are parked.
13. Nothing built on the scrap-bot crew: no bot partner for paired parts, no crew workbench in a pocket (your ruling for the alpha).
14. Forge budget bands change only after each pilot's summed triangles report; no 4,096 textures.
15. Difficulty never raises enemy health or adds a flat elite stat tier.

## 6. Lab arms

The arms run on the core-loop headless tools, as in the first memo's section 6. Each is report-first; the pass line says when it gates.

| Arm | Where it runs | Measure | Pass line |
| --- | --- | --- | --- |
| Full visit | `tools/park_graph.gd` on the six stage files (KB8 report, after each KD greybox) | `full_visit_ratio` per stage | At most 3.0 on every stage (start); report-only in wave 13 |
| Pay ladder | `park_pockets_test` on the six stage files | Each pocket's `pay.rarities` against its detour rank | Larger-detour pocket `["rare"]`, on-line `["common"]` on every stage; gated from KD1 |
| Elite count | KE6's 30 stepped minutes, 20 seeds, `--table=park` | Elite arrivals per stage per seed | Report; a cap unit opens if any seed exceeds 3 (start) |
| Attacker peak | KE9's spawner arm, both modes, highest park tier | Peak enemies in WARN or LIVE at once | Report; a budget is built only past a threshold the lab sets first (6 is an assumption to start the discussion) |
| Telegraph tail | `telegraph_timing_test` (KF2 to KF4) | Recovery and cooldown per Warden attack; KF2: warn seconds per pack kind | Report; the pack-kind list equals LEGIBILITY section 2's text |
| Shared-pool movement | `parts_pool_movement_test` (PC-POOL), 200 offer draws per pilot | Shared parts with a movement mod among offers | Zero after PC-POOL (5 of 18 listed parts today) |
| Per-pilot sum | PD fix round 2 inspect calls (C5b) | Class I, III and V tris and draws per pilot | Report; feeds the forge proposal; stop if a class V sum passes 16,000 tris |

Parked arms, named so they are not lost: the burden sweep (`comps/gunfire/scrolls-and-synergies.md:86`), the fusion pairing test (`comps/gunfire/elements-and-fusion.md:85`), the slot growth sweep (`comps/gunfire/weapons-and-inscriptions.md:93`), the movement trace shapes (`comps/roboquest/movement-and-feel.md:83`), the closable-socket re-roll arm (`comps/roboquest/stage-anatomy.md:125`) and the 1,000-seed pocket jitter arm the first memo specified (its section 6), which no unit owns yet.
