# Gunfire Reborn difficulty reference (comps note)

Evidence: shipped data tables re-extracted 2026-10-18, read by scripts under `~/scratch/game-study/difficulty-tools/gunfire/` (level 4: monsterdata, monsterpf, monsterflawdata, monsterrelicdata, roomchallengedata, levelchoosedata, levelconfigdata, weapondata, herodata, pvedata, phaseconfig; table root `~/scratch/game-study/gunfire/tables/raw/`, abbreviated `raw/` below). Boss health, tier multipliers, Reincarnation steps, phase thresholds and enemy-enhancement numbers come from the public wiki as summarised in `~/scratch/game-study/gunfire/reports/{enemies-elites-bosses,run-pacing-difficulty-economy,heroes-ascensions-talents,weapons-and-inscriptions}.md` (level 2, cited there as wiki file:line; the saved wiki folder is no longer on disk, so I could not re-open those pages and I label every such number `wiki (public)`). The shipped tables hold no monster health, damage, tell length or spawn waves (logic is native or server side), so every TTK, every burst share and every tell length below is either INFERRED or a stated gap. Wiki boss numbers use display units; I assume weapon damage uses the same units (`weapondata.AttDamage / 100` and `AttSpeed / 100` match the wiki's damage and rate columns exactly for the two weapons I checked, an injector example and a sniper example), which is INFERRED.

Mapping used throughout (INFERRED link): the tables do not join a boss level to a monster record. I matched them by the shared in-game name string and the act label inside the level's dev name, and matched wiki pages by name. Boss and enemy names appear only as evidence labels in Source columns (file names, ids).

## Bosses

### Where the bosses sit in a run

Source for the whole table: `raw/levelchoosedata_3001.txt` (rows 1001-1005: `Layer`, `FightLevelInfo`, `BossLevelList`), `raw/levelconfigdata.txt` (level `Name`/`DevName`).

| Position | Regular fight rooms before the boss | Boss pool entries (weight) | Notes |
|---|---|---|---|
| act 1 | 4 | 3 entries: 2 at weight 10, 1 at weight 0 | the weight-0 entry is a third boss never rolled in this mode (it is the boss of mode 3020, `raw/levelchoosedata_3020.txt` row 1001) |
| act 2 | 3 | 2 at weight 10 | one default, one alternate; roll is 1 in 2 per run (wiki (public) via enemies-elites-bosses.md, Structure section; page in the Source column of the HP table) |
| act 3 | 3 | 2 at weight 10 | same |
| act 4 | 2 | 4 at weight 10 | 2 bosses, each with a second "variant rule" entry, see Variants below |
| act 5 (present in data, absent from the wiki summary) | 2 (candidate pools 1 and 1, `raw/levelchoosedata_3001.txt` row 1005) | 1 at weight 10 | the one boss with 10 phase records; no HP number anywhere |

Fight rooms per act are 4/3/3/2/2 = 14 (rows' `FightLevelInfo` length); with one lobby and one boss level per layer that is 24 stage entries in the 5-layer mode, 20 without the fifth (matches the wiki's 16-or-20 inference in run-pacing-difficulty-economy.md). Each fight slot draws its room from a candidate pool of 11/8/19/17 (act 1), 12/17/19 (act 2), 8/17/15 (act 3), 14/15 (act 4) rooms (`FightLevelInfo.*.LevelConditions` key count; median 15; the 0/1 flag meaning is not documented).

### Boss health: base, scaling rule, computed ratios

Base health is a fixed number per boss; every tier multiplies it by one factor, and Reincarnation uses a per-act factor (ladder below). Computed from the wiki's four columns, the tier-2 ratio is 1.4 for six of seven bosses (one is 1.4625), the tier-3 ratio is 2.4 for six (one 2.28), and the top Reincarnation column equals 5.9x, 9.4x or 13.6x by act (my division of the cited figures; INFERRED only in that it checks the ladder endpoints, not a new fact).

| Position | Base HP (tier 1) | Second bar (base) | Tier 2 | Tier 3 | Top Reincarnation column | Source |
|---|---|---|---|---|---|---|
| act 1 default boss | 80,000 | shield 8,000, regen 20 %/s | 112,000 | 192,000 | 472,000 (5.9x) | wiki (public): Lu_Wu.txt:3-4, :8 via enemies-elites-bosses.md |
| act 1 second boss | not stated | weak spots take most damage | not stated | not stated | not stated | wiki (public): Golem.txt:17 (weak spot only) |
| act 2 pool, first entry | 131,340 | armor, same stated figure | 183,876 | 315,216 | 1,234,596 (9.4x) | wiki (public): Ichthyosaurus_Offspring.txt:3-4 (the scout labelled it act 1 alternate; the shipped layer-2 boss pool contains this boss, so I place it in act 2; armor bar equal to its health, enemies-elites-bosses.md:35) |
| act 2 pool, second entry | 245,168 | not stated | 343,236 | 558,404 | 2,304,580 (9.4x) | wiki (public): Wind_God.txt:3 |
| act 3 default | 320,000 | shield, break at 25/50/75 % HP | 448,000 | 768,000 | 4,352,000 (13.6x) | wiki (public): Yoruhime-Maru.txt:3, :20-29 |
| act 3 alternate | 640,000 | 4 heads, one bar, body hits reduced 95 % | 896,000 | 1,536,000 | 8,704,000 (13.6x) | wiki (public): Abyssal_Serpent.txt:3, :19, :23 |
| act 4 default | 1,440,000 | not stated | 2,106,000 | 3,456,000 | 19,584,000 (13.6x) | wiki (public): Pole_Monarch.txt:3, :30-36 |
| act 4 alternate | 1,800,000 | not stated | 2,520,000 | 4,320,000 | 24,480,000 (13.6x) | wiki (public): Gluttony.txt:3, :32-44 |

Growth across acts at base tier (my ratios from the column above): act 2 first/second entry are 1.64x and 3.06x the act 1 default; act 3 default is 2.44x the act 2 first entry; act 4 default is 4.5x the act 3 default; act 4 default is 18x the act 1 default; act 4 alternate is 2.8x the act 3 alternate. Median boss HP by act (mean where two are known): 80k, 188k, 480k, 1.62M, i.e. roughly x2.4, x2.6, x3.4 per act step. Boss HP is therefore the game's pacing meter across acts, not a within-act difficulty dial.

### Time to kill at an ordinary build (INFERRED)

Player DPS is not in any table. Model, with each assumption flagged:

1. Weapon base: 73 weapons in `raw/weapondata.txt`. Per weapon, damage = `AttDamage/100`, rate = `AttSpeed/100`, reload = `BulletInfo.0.FillTime/100`, magazine = `BulletInfo.0.MagazineCapacity`. Sustained DPS = damage / (1/rate + reload/magazine), the wiki's formula (Rate_of_Fire.txt:5 via weapons-and-inscriptions.md). Result over 73 weapons: min 44, p25 181, median 340, p75 523, p90 662, max 3,077 (single-pellet; 11 weapons fire several pellets, counting all pellets at close range lifts the median to 374). The start weapon every hero carries (`raw/herodata.txt` `StartGun` = 1202) is 145 x 3.0/s, magazine 9, reload 1.35 s: 435 burst, 300 sustained.
2. Weapon level multiplier: `raw/pvedata_3001.txt` `WeaponLevelInfo.<level>.Att.MulValue` = 1500 per level up to 15000 at level 10; I read it as +15 % per level, matching the wiki's +15 % per craftsman enhancement (Craftsman.txt:9). Weapon level by act (wiki stage table via comps weapons-and-inscriptions.md): act 1 boss level about 2, act 2 about 4, acts 3 and 4 range 5-10. Assumed boss-fight level: 2, 4, 6, 10, giving x1.30, x1.60, x1.90, x2.50.
3. Build multiplier (scrolls, ascensions, elements, crits, inscriptions): not in the data. ASSUMED 1.5, 3, 5, 8 for acts 1-4, a placeholder that makes the modeled act-by-act TTK stay in the same band. Treat the implied-multiplier column as the real finding.
4. Uptime (boss open and player on target): ASSUMED 0.6.

| Boss (position) | Modeled effective DPS | Modeled TTK, health bar only | DPS needed for 120 s / 180 s / 300 s | Build multiplier a 180 s kill implies (over weapon-level baseline, uptime 0.6) |
|---|---|---|---|---|
| act 1 default | 398 | 201 s (3.3 min), +20 s shield if never regenerated | 667 / 444 / 267 | 1.7 |
| act 2 first entry | 980 | 134 s on health only; its armor bar equals its health (enemies-elites-bosses.md:35), which at the 75 % non-corrosion damage rule roughly doubles it (INFERRED) | 1,094 / 730 / 438 | 2.2 |
| act 2 second entry | 980 | 250 s | 2,043 / 1,362 / 817 | 4.2 |
| act 3 default | 1,940 | 165 s | 2,667 / 1,778 / 1,067 | 4.6 |
| act 3 alternate | 1,940 | 330 s | 5,333 / 3,556 / 2,133 | 9.2 |
| act 4 default | 4,084 | 353 s | 12,000 / 8,000 / 4,800 | 15.7 |
| act 4 alternate | 4,084 | 441 s | 15,000 / 10,000 / 6,000 | 19.6 |

Sources: HP from the table above; DPS inputs `raw/weapondata.txt` AttDamage/AttSpeed/FillTime/MagazineCapacity, `raw/pvedata_3001.txt` MulValue; arithmetic in `difficulty-tools/gunfire/dps.py` and `ttk.py`. Reading: to hold a three-minute boss kill, build power outside the weapon must grow about 10x from the act 1 boss to the act 4 boss, so most of a Gunfire player's boss-killing power is stacked build, not weapon level. The act 1 shield regenerating 20 %/s of its 8,000 (1,600 per second, wiki (public)) would exceed the modeled act 1 DPS of 398 if it runs while the boss is under fire, in which case that DPS could not break it; the regen delay is not stated (gap). Hero skills add little sustained damage: of 16 heroes, the primary skill's `CommonProp.0.Atk`/100 is 0 to 800 per use at a cooldown field median 1500 (read as 15 s, INFERRED unit), and the grenade `Atk`/100 is 100 to 700 (median 500) (`raw/careerpfdata.txt`, `raw/throwdata.txt`, linked through `raw/herodata.txt` `Skill`).

### Boss records in the shipped data (act-tagged, level 4)

Source: `raw/monsterdata_3001.txt` (rows below), skill-name labels from `raw/monsterpf.txt`, execute cap from `raw/monsterflawdata.txt` via each row's `DataSID`.

| Position | Monster row id | Skill ids in `SkillLst` (named attacks) | `PhaseInfo` records | `HitActCD` ms | `MoveSpeed` | `CombatForce` | Execute-cap field |
|---|---|---|---|---|---|---|---|
| act 1 first pool entry | 39011 | 8 (6) | 3 | 1200 | 250 | 10 | 3333 |
| act 1 second pool entry | 39091 | 9 (7) | 4 | 1200 | 500 | 10 | 3333 |
| act 2 first entry | 39031 (variants 39131, 39141) | 14 (12) | 6 (5-6 in variants) | 1200 | 1200 (1800 in one variant) | 10 | 3333 |
| act 2 second entry | 39151 | 11 (9) | 3 | 1200 | 250 | 10 | 3333 |
| act 3 default | 39051 | 11 (8) | 7 | 1200 | 500 | 1.0 | 3333 |
| act 3 alternate | 39201 | 12 (9) | 3 | 1200 | 4000 | 1.0 | 3333 |
| act 4 default | 39241 (variant 39251) | 21 (11) / 22 | 6 | 1200 | 250 | 10 | 3333 |
| act 4 alternate | 39021 (variant 39024) | 19 (12) / 22 | 3 | 1200 | 250 | 0.0 | 3333 |
| act 5 | 39311 | 11 (9) | 10 | 1200 | 250 | 10 | none (no row for its DataSID) |

Medians across the 9 bosses: 11 skill ids, 4 phase records (range 3-10), `HitActCD` 1200 on all (normals 600 (a few 300), elites 600-900, `raw/monsterdata_3001.txt` Prop.0.HitActCD). Named-attack counts per boss run 6-12 (median 9); the rest are unnamed helper or phase-control skills. A keyword split of the names puts most bosses at 1-6 each of near-melee, ranged, area, summon and phase-control entries, which I do not publish as a table because the split is a keyword heuristic and overlaps.

Meaning of the fields (INFERRED, not documented):

- `HitActCD` (INFERRED meaning): the monster's own flinch cooldown, so a boss cannot be flinched more often than once per 1.2 s (normal 0.6 s, some 0.3 s). It is the only per-monster timing number in the tables; it is not a tell length.
- Execute cap: `KillLineUpLimit` is 10000 on 135 of 181 rows, 5000 on 34, 3333 on 12; mapped to monsters through `DataSID`, all 8 main bosses are 3333, elites are 5000 on 30 of 56 elite rows and 10000 on 26, normal tiers are 10000 on 149 of 157 rows and 5000 on 6, and 13 of the 20 boss-tier rows are 3333 (`difficulty-tools/gunfire/verify_numbers.py`). Reading: an effect that kills below a health line is capped at 100 % for normals, 50 % for most elites and 33.3 % for bosses. Note one room rule says a weak-spot hit from one weapon type kills outright, and another version of it deals 50 % of max health as true damage (`raw/roomchallengedata_3001.txt` rows 1104, 1129); the cap is the plausible reason bosses are exempt.
- `PhaseInfo`: counts do not equal the wiki's HP-threshold phases (act 3 default: 7 records vs 3 thresholds; act 4 default: 6 vs 3; act 4 alternate: 3 vs 3), so I read them as phase records for scripting or the health-bar UI, not the number of fight phases. The phase-icon id inside each record splits them into 1 group on seven bosses and 2 groups on two (act 3 default 4+3, act 4 alternate 1+2), which matches neither the wiki's thresholds nor the record counts, so no phase count is taken from the data (`raw/monsterdata_3001.txt` `PhaseInfo.*.PhaseIcon`).

### Phases and thresholds (wiki (public), via enemies-elites-bosses.md)

| Position | Thresholds (% HP) | What a threshold does | Source |
|---|---|---|---|
| act 3 default | 75, 50, 25 | each breaks a shield layer; 8 cannons in phase 1 | Yoruhime-Maru.txt:18-29 |
| act 4 default | 75, 40, 5 | each adds a mechanic; a damage-fed aura bar unlocks enhancements at fixed marks | Pole_Monarch.txt:16-18, :30-36 |
| act 4 alternate | 75, 40, 25 | each adds a mechanic | Gluttony.txt:32-44 |
| act 1 default and act 2/3/4 others | not stated in the summaries | | gap |

### Variants: a second pool entry changes the pattern, not the health

Act 4's pool has four weight-10 entries: two bosses and a second entry for each that exists under a "stronger enemies" rule (`raw/levelchoosedata_3001.txt` row 1004 `BossLevelList`; rule description in `raw/newpatternconfigdata.txt` row 1002, paraphrased: the snowy region's creatures are stronger). The variant monster rows keep the same `CombatForce`, `HitActCD` and speed and change only the skill list: act 4 alternate 39024 vs 39021 adds 5 skill ids and drops 2 (two of the added ones carry a variant label in their names), and act 4 default 39251 vs 39241 adds 3 and drops 2 (`raw/monsterdata_3001.txt` `SkillLst` set difference, `difficulty-tools/gunfire/boss_roles.py`). HP is not touched by the data difference (HP is not in the tables at all).

### Attack tells, active and recovery times, punish windows, burst damage: what exists

- Tell lengths, active and recovery frames, and punish windows: none in any table. Monster skills in `raw/skillinfo.txt` carry only `ForbidRule`, `BreakInRule`, `PassRule` and a `ShieldWarning` flag (set on 66 of 466 monster skill ids and on none of the 223 boss skill slots; meaning undocumented). `raw/phaseconfig.txt` holds timelines, not tells (see Mobs).
- Qualitative tell vocabulary (wiki (public) via enemies-elites-bosses.md, Structure section): red ground circles for bites and pillars, overlapping circles for artillery, a line before a lunge, a text warning on a devour; the wiki states a dodge for every attack; one shockwave lands sooner than its marker shows and the wiki treats that as a flaw. Source pages: Ichthyosaurus_Offspring.txt:50, :60; Golem.txt:49; Yoruhime-Maru.txt:49; Abyssal_Serpent.txt:37; Gluttony.txt:79.
- Player health to compare against: hero health pool (health + shield + armor, `raw/herodata.txt` `BaseAttr`/100) is 100 to 150 per hero, median 130 (16 heroes); health alone is 35 to 100 (median 55); wiki says base move speed 5.0-6.0 (Movement_Speed.txt:7-36 via heroes-ascensions-talents.md); the data adds one hero at 6.5 (`raw/herodata.txt:1112`).
- Contact damage and largest single hit as a share of that pool: not available; the damage numbers are not shipped. Tier 2 and 3 scale damage x1.4 and x1.8 (ladder), so any base share is multiplied by that.
- The only hard burst numbers are enemy-side scroll effects expressed as a share of player health, listed under Mobs.
- Time before the first dangerous attack, time to first stagger: not available.

## Mobs and events

### Room structure and threat weight

- Rooms: see the table above. The exit opens when every enemy in a room is dead (wiki (public): Enemies.txt:5 via enemies-elites-bosses.md). Wave counts and enemy counts per room are not in the tables (gap).
- Threat weight: every monster record has `CombatForce` (`raw/monsterdata_3001.txt`, 243 rows): normal tier ids (20xxx-24xxx, 157 rows) take 0 to 2.0 (median 0.75; 4 rows are 0), elite-tier ids (30xxx-34xxx, 56 rows) take 10 for 42 rows, 5 for 6 rows and 1-1.5 for 8 rows, the 9 main-boss ids are 10 on six, 1.0 on two and 0.0 on one. One elite at weight 10 equals about 13 median normals. Whether the director budgets by this number is INFERRED; the number is not scaled by act (same-name monsters with different weights number 6 of 70 repeated names).
- Move speed (`MoveSpeed`/100; hero base 5.0-6.5 in the data): normals median 1.5, p25 1.2, p75 1.8, p90 3.5, max 10; elites median 1.8, p75 2.3, max 3.0; bosses median 3.25 (the 40 m/s outlier is a multi-limb boss and is not a walking speed). So a median normal moves at about 0.27x a hero. Seven rows (the bonus-chase event creatures) carry three speed rows 10.0/9.5/9.0 (`Prop.0-2`), selected by an undocumented index.
- Skills per monster: normals median 4 (max 12), elites 7.5 (max 14), bosses median 11 (max 22) (`SkillLst`).
- Flinch cooldown `HitActCD` (INFERRED meaning): normals 600 ms (a few fast ones 300), elites 600 or 900, bosses 1200.
- Stage-level mob counts per act and elite rate growth: not in the tables. Proxies: gallery counts 12/19/16/8 normal and 3/6/6/2 elite per act (wiki (public): the four act pages via enemies-elites-bosses.md), and, in the shipped room-rule table for the 5-layer mode (168 rows), 66 rows (39 %) involve elites: 17 elite-after-clear, 30 elite-invasion, 19 elite-swarm (`raw/roomchallengedata_3001.txt`, categories counted by me from the `Name` field; the 3008 and 3020 tables are 71 and 107 rows).

### Elite affixes (wiki (public): Enemy_Enhancements.txt:5-58 via enemies-elites-bosses.md)

- Count and stacking: each enhanced enemy has exactly one primary effect and one secondary effect; the primary is an added attack or aura, the secondary a stat or behaviour change; the data table lists 22 affix ids (`raw/monsterafdata.txt`), the wiki about 14 primaries and 4 secondaries.
- Stat multipliers: armored +50 % health and shield or armor; the four secondary effects add +200 %, +100 %, +200 %, +300 % health; one defensive effect takes -40/-50/-60 % damage by act; one shielding effect gives 10/20/30 % of max health by act.
- Radii and timers: auras 10 m, chains 15 m; one invulnerability fuse 5 s; one heal tick 10 s; one clone effect makes 2.
- Availability: enhancements begin at tier 2 and are not on tier 1 (Difficulty.txt:12, :29).
- Elites on tier 1 also have a regen rule worth copying: shield regenerates 10 %/s after 5 s on most normals, but 2 %/s after 10 s on two elites (wiki (public) via enemies-elites-bosses.md, Structure section; Source pages Elite_Arsonist.txt:7, Elite_Hermit.txt:7).

### Enemy-side modifier rows (171 monster scrolls, level 4)

`raw/monsterrelicdata.txt` holds 171 effects that can be handed to enemies (the mode where the player takes extra scrolls and enemies take matching ones is `raw/newpatternconfigdata.txt` row 1004, paraphrased). Four quality tiers: 63 / 56 / 33 / 19, the last tier being handicaps that make the enemy weaker. Counts by effect (regex over the effect text; heuristic, overlapping):

| Effect family | Rows | Detail | Source |
|---|---|---|---|
| attack interval cut | 18 | 14 rows at -30 %, 3 at -50 %, 1 at -70 % with self-damage on a miss; 3 rows raise the interval (handicaps) | `raw/monsterrelicdata.txt` `RelicDescInfo.1.Desc` |
| damage increase | 28 | extracted values 1-80 %, 10 of 26 values are +50 %; also several conditional or stacking (full-health +25 %, +75 % above half health, 10 stacks of +10 % reset on hit) | same |
| 300 % hit chance / 200 % window | 4 | 10 % chance of 300 % (two rows), 80 % chance of +150 %, +200 % for 3 s after being hit | same |
| move speed increase | 11 | +20 to +50 % | same |
| elite-reduction clause | 12 | self-heal, shield and heal effects are cut 80-95 % (or 25-50 % for shield rows) on elites | same |
| percent-of-player-health damage | 9 | true damage of 10 % max health per hit; 33 % of the shield cap per hit (1 s cooldown); 15 % of max health on shield break within 12 m; 10 % of current total within 5 m per attack (3 s cooldown); 20 % of current total on death (25 % chance, 5 m); bleed 5 %/s for 5 s; -4 % max health per hit, stacking to 10 | same |
| execute | 1 | kills a player below 15 % health | same |
| summon / on-death hazard | 3 / 4 | summon needs charged energy (10 per attack, at 20 or 30); death leaves fire, corrosion or lightning ground | same |
| invulnerability or shield-block | 5 | one block every 10 s; 0.5 s after each attack; 1 s after every third attack | same |

Reading (INFERRED): the common aggression dial is "attack interval x0.7" (about +43 % attack rate); stronger dials (x0.5, x0.3) come with a cost to the enemy. Percent-of-health damage is bounded by cooldowns (1 to 3 s) and radii (5 to 12 m), not by a cap on the percent.

### Challenge rooms and event rules

- Structure (wiki (public) via run-pacing-difficulty-economy.md and enemies-elites-bosses.md): wave events run 4-5 waves; an elite gathering brings 2-5 elites by player count (Challenge_Events.txt:107); guardian elites come after the room clears and, at tier 3, invasions can arrive mid-room (Challenge_Events.txt:24; Difficulty.txt:47); "at most one event per act in the base ladder" is unverified (no on-disk source; the nearest is one challenge event per act at the top Reincarnation level, occult-scrolls.md:47 as reported in the scout notes).
- Shipped rule rows for the 5-layer mode (168): death transform 15, elite-after-clear 17, death hazard 2, all enemies one type 13, timed or escort 7, elite invasion 30 (incl. endless-loop variants), seal defence 3, bonus chase 7, all-enhanced 2, elite swarm 19, rule modifiers 53 (`raw/roomchallengedata_3001.txt` `Name`, my categories).
- Numbers inside rule rows come in pairs of two strengths for early/late use: heal-back 60 % vs 80 % of damage within 4 s (rows 1053, 1081, 1125); close-range damage bonus +50 % vs +20 % with 1 damage beyond 16 m (rows 1101, 1128); weak-spot execute vs 50 % max-health true damage (rows 1104, 1129). Sixteen late rows (1152-1167) are templates with placeholders, so their values are supplied elsewhere.
- Pulse pacing: `raw/phaseconfig.txt` has 4 timelines of 3 blocks; two rows' blocks sum to 42/42/36 s, the others to 60/60/60 s. Entries run 0.2 s to 30 s (median 3 s) and the gaps between steps grow within a block (row 1001: 0.2, 0.3, 1.5, 2, 2.5, 3, 5.5, 3, 4, 5, 6, 9 s; row 1002: 1.5, 2, 2.5, 3, 3, 6, 12, 12, 18 s). The row's `Screen` ids equal the mode-3020 level ids in `raw/levelchoosedata_3020.txt`, so I read these as wave-step timers for that mode; semantics INFERRED.

### How readability is kept (wiki (public) via enemies-elites-bosses.md; shipped tables carry no cap)

- Health, shield and armor are three visibly different bars with one damage-type table (150 % / 100 % / 75 %): armor does not regenerate, shield does.
- Ground markers carry the attack; text warnings carry rare devours; the dodge is stated for each attack.
- No attacker cap, spacing rule or concurrent-warning limit was found in the tables (gap).

## Difficulty ladder

Positional labels only. Multipliers are on enemy health plus shield or armor ("HP") and on enemy damage ("Dmg"). Reincarnation values are wiki endpoints (levels 1 and 7, from run-pacing-difficulty-economy.md citing Reincarnation.txt:23-35) with the middle levels INFERRED by linear interpolation: only levels 1 and 7 are sourced (interpolated steps: act 1 HP +0.5, act 2 HP +1.0, acts 3-4 HP +1.6, act 1 Dmg +0.3, act 2 Dmg +0.2). The boss infobox top column (5.9x, 9.4x, 13.6x) reproduces from base HP and confirms level 7, not the middle. "Product" is HP x Dmg, the factor on total damage taken in a fight at constant player DPS (INFERRED, not stated).

| Step | Rule it adds | Numeric effect | Cumulative effect | Source |
|---|---|---|---|---|
| 0 base tier | none | HP 1.0, Dmg 1.0 | product 1.00 | wiki (public): Difficulty.txt:3-5 |
| 1 tier 2 | one multiplier pair; enemy affixes begin; traps and challenge events; soul rewards up | HP 1.4, Dmg 1.4; soul drop chance +10 %; 14 soul per elite; boss soul 45-90 | HP 1.4, Dmg 1.4, product 1.96 | wiki (public): Difficulty.txt:20-29 |
| 2 tier 3 | larger pair; more traps and events; invasions arrive mid-room | HP 2.4, Dmg 1.8; soul +20 %; 18 per elite; boss soul 60-105 | HP 2.4, Dmg 1.8, product 4.32 | wiki (public): Difficulty.txt:38-47 |
| 3 Reincarnation 1 | per-act table replaces the pair; higher soul rate; soul prices discounted 45 % | act 1 HP 2.9 / Dmg 2.1; act 2 HP 3.4 / Dmg 2.0; acts 3-4 HP 4.0 (Dmg not stated in the summaries) | act 1 product 6.1; act 2 product 6.8 | wiki (public): Reincarnation.txt:17, :23-35 |
| 4 Reincarnation 2 | steps up | act 1 HP 3.4 / Dmg 2.4; act 2 4.4 / 2.2; acts 3-4 HP 5.6 | act 1 product 8.2; act 2 9.7 | INFERRED interpolation |
| 5 Reincarnation 3 | steps up | act 1 3.9 / 2.7; act 2 5.4 / 2.4; acts 3-4 HP 7.2 | act 1 10.5; act 2 13.0 | INFERRED |
| 6 Reincarnation 4 | steps up | act 1 4.4 / 3.0; act 2 6.4 / 2.6; acts 3-4 HP 8.8 | act 1 13.2; act 2 16.6 | INFERRED |
| 7 Reincarnation 5 | steps up | act 1 4.9 / 3.3; act 2 7.4 / 2.8; acts 3-4 HP 10.4 | act 1 16.2; act 2 20.7 | INFERRED |
| 8 Reincarnation 6 | steps up | act 1 5.4 / 3.6; act 2 8.4 / 3.0; acts 3-4 HP 12.0 | act 1 19.4; act 2 25.2 | INFERRED |
| 9 Reincarnation 7 | last stat step | act 1 5.9 / 3.9; act 2 9.4 / 3.2; acts 3-4 HP 13.6 | act 1 product 23.0; act 2 30.1 | wiki (public): Reincarnation.txt:23-35 |
| 10 Reincarnation 8 | rules, not stats: more challenge events per act (the count, and a guaranteed boss-stage event, are unverified: the nearest on-disk statement is occult-scrolls.md:47); enemy-side resistance challenges (elemental -15 % per effect, max -45 %; damage -8 % per stack, max -80 %); +10 soul per completed event | stats stay at step 9 (boss infobox column equals 5.9x/9.4x/13.6x) | unchanged stats | wiki (public): Reincarnation.txt:45-49, :85-87, :95, :117 |
| 11 Reincarnation 9 | unlocks the endless loop; no soul discount | endless: timer 10 min, +35-40 s per cleared stage; health scaling turns additive after stage 55; damage resistance capped at 95 %; scroll cap 60 | stats unchanged on entry | wiki (public): Reincarnation.txt:137-151 |
| 12 Reincarnation 10 (if it exists) | pages disagree on 8 vs 10 levels | "significantly boost" with no number | not computable | wiki (public): Difficulty.txt:3 vs Reincarnation.txt:3, :21 |

Boss health in the tier columns: at act 1 default, base 80,000 becomes 112,000 / 192,000 / 232,000 (R1, 2.9x) / 472,000 (R7, 5.9x); for the two act 4 bosses, a modifier is noted as 2.1x per level instead of 1.6x (wiki (public) via enemies-elites-bosses.md:42; Source pages Pole_Monarch.txt:93, Gluttony.txt:86), whose meaning is unresolved; the 1.6 it names equals the interpolated acts 3-4 HP step, which is partial support for the interpolation, still INFERRED. Multiplayer adds more health by player count (stated as +300 %/+500 %/+700 % for 2/3/4 players, wording ambiguous, Multiplayer.txt:14). Damage multipliers for acts 3 and 4 at Reincarnation are not in my sources (gap).

```mermaid
flowchart LR
    B[Base tier] -->|HP 1.4, Dmg 1.4, affixes begin| T2[Tier 2]
    T2 -->|HP 2.4, Dmg 1.8, mid-room invasions| T3[Tier 3]
    T3 -->|per-act table: HP 2.9..13.6, Dmg 2.1..3.9| R[Reincarnation 1-7]
    R -->|stats freeze, many events + boss-stage event| R8[Level 8]
    R8 --> R9[Level 9: endless loop, scaling goes additive after stage 55]
```

## Why it works

- Two dials with different slopes. Across levels 1-7 (per-level steps INFERRED, linear between endpoints), act 1 HP rises x2.0 and damage x1.9, almost the same, so act 1 gets longer and deadlier together; act 2 HP rises x2.8 against damage x1.6 and acts 3-4 HP x3.4, so only there do fights get longer more than lethal. Damage per hit, not HP, is what a player feels as danger; the early steps (1.4 to 1.8) raise it by 29 % in one step.
- Steeper steps in later acts. Per-level HP steps are 0.5 / 1.0 / 1.6 in act 1 / act 2 / acts 3-4 (INFERRED, linear between endpoints), so one number cannot be read across acts and the late game separates builds that already beat the early game.
- Rules take over where stats stop. At step 9 the stats freeze and the game adds events, resist challenges and an endless loop; the top of the ladder is mostly new situations, not bigger numbers.
- An execute cap by tier (100 % normals, about 50 % elites, 33.3 % bosses; reading INFERRED) keeps instant-kill effects out of boss fights without special-casing each boss, and a per-monster threat number exists but does not behave as one threat scale: the act 3 bosses read 1.0 and the act 4 alternate 0.0, against 10 on six other main bosses, so I do not rely on it as a budget unit. One boss row (DataSID 3926, `raw/monsterflawdata.txt:494-496`) also carries the only `ImmuneKill` flag set in 181 rows.
- Same boss, different pattern. The act 4 variant entries keep every stat and swap 3-5 skills, so replay value comes from re-learning, not from re-tuning.
- Bosses are the pacing meter. Base boss HP grows 18x from act 1 to act 4 while weapon level contributes about 1.9x (INFERRED: rests on my assumed boss-fight weapon levels 2 and 10), so the rest must come from the build; that makes build quality, not the ladder step, the main difficulty swing.

## Patterns for Scrapkeep's skill bands

Scrapkeep never raises enemy health with difficulty, so the HP column below is for reading the Gunfire pattern, not for copying.

| Scrapkeep target | What Gunfire's numbers suggest | Source rows |
|---|---|---|
| Boss beats Novice, Learner 15-35 % first attempt, Expert at least 85 % | No skill-band data exists. The hook is length: at an ordinary build the modeled fight is 2.2-7.3 min per boss (INFERRED), so a 45-second no-kill rule covers 10-35 % of the fight, and a Learner has several attack cycles to read tells before the HP race matters | TTK table above (INFERRED) |
| Every lethal attack has a tell of at least 0.6 s | No tell length in the data. The wiki's flaw note is a marker that lies about when a hit lands; require marker geometry and timing to equal damage geometry and timing (already Scrapkeep policy). Boss flinch cooldown 1.2 s, normals 0.6 s (INFERRED meaning of `HitActCD`; it is the monster's own flinch cooldown, not a tell length) | `raw/monsterdata_3001.txt` HitActCD; Ichthyosaurus_Offspring.txt:60 |
| Difficulty from damage, patterns and aggression, not HP | Use a pattern-swap variant tier: same stats, 3-5 skills swapped (act 4 variants). Use one aggression dial, attack interval x0.7, as the common step, at most two stacked, with x0.5 reserved for tier steps that carry a drawback | `raw/monsterdata_3001.txt` SkillLst diff; `raw/monsterrelicdata.txt` (18 rows) |
| Damage multiplier ladder (Scrapkeep caps 1.3x) | Gunfire's first damage step is 1.4x and its second 1.8x; its Reincarnation steps add 0.2-0.3x per level (INFERRED from the level 1 and 7 endpoints). A cap of 1.3x is below Gunfire's smallest step, so Scrapkeep's top tier should be reached by pattern layers, not stat steps | Difficulty.txt:21, :39; Reincarnation.txt:33-35 |
| Hard tier becomes a replay ladder (Expert + ordinary build wins about half at the top) | Gunfire ends its stat ladder at step 9 and then adds situational rules (events, resist challenges, an endless loop). Pattern: freeze stats, then add rule rows | Reincarnation.txt:45-49, :95, :137-151 |
| Phase count and thresholds | Bosses carry 3 to 7 scripted phase records; the wiki's thresholds are evenly spaced (75/50/25) or front-loaded (75/40/5, 75/40/25). Use 3 thresholds at 75/50/25 as the readable default and make one fight the late-threshold exception | `raw/monsterdata_3001.txt` PhaseInfo; Yoruhime-Maru.txt:20-29; Pole_Monarch.txt:30-36 |
| Boss stagger gating (big enemies first stagger in 45-70 s) | Gunfire gates by tier: an execute effect's health line is capped at 100 % on normals, about half on elites, one third on bosses (INFERRED reading of the field). Whether the same cap applies to stagger is not known; Scrapkeep could scale its stagger threshold by heft class in the same spirit | `raw/monsterflawdata.txt` KillLineUpLimit via DataSID |
| Mob budget (6, +1 per heft class, +2 per world, cap 12) | Gunfire's per-monster threat field runs 0.75 (median normal) to 10 (most elites, six of nine main bosses), about x13, but two act 3 bosses read 1.0 and one act 4 boss 0.0, so it is not a clean budget unit (INFERRED meaning). Gunfire's ratio is far steeper than Scrapkeep's +1 per heft class, so treat it as a ceiling on how much heavier a top enemy can weigh than a fodder one, and keep the weights independent of act as Gunfire does | `raw/monsterdata_3001.txt` CombatForce |
| Elite rate growth | Elite-involving room rules are 39 % of the 168-row rule set; the wiki gallery lists 3/6/6/2 elites per act (act 4 is smaller, so the roster does not simply grow). A staged introduction (affixes only from tier 2) keeps the first tier readable | roomchallengedata counts; Difficulty.txt:12 |
| Percent-of-health attacks and executes | Gunfire bounds them with 1-3 s cooldowns and 5-12 m radii, and offers a single "kill below 15 %" row. Cap any percent-of-health attack in Scrapkeep and leave out executes on players | `raw/monsterrelicdata.txt` 9 + 1 rows |
| Parks: Novice reaches the world boss in at most 50 % of runs, Learner at least 80 % | Gunfire resets attrition at each act start (full heal, revive, save-and-quit from act 2; Acts.txt:5) and prices heal items by stage (55, 105, 155, 205 copper at stage 1 of each act; Peddler.txt:18-44), so run failure concentrates in the stages between checkpoints. Place the Novice failure mass in the stage just before each checkpoint | Acts.txt:5; Peddler.txt:18-44 via run-pacing-difficulty-economy.md |
| Learner improves by the fifth attempt | Gunfire's between-run improvement is character power (talent levels to 208, 17,800 soul for the full tree; Talents.txt:111-113), not skill. Do not copy it into the Challenge lane, which must measure skill across attempts | Talents.txt:111-113 via heroes-ascensions-talents.md |

## What it must not copy

- Boss, enemy and affix designs, names, arenas and mechanics as written (cannons, multi-head boss, aura bar, summoned enemies) and every game text string, including the room-rule wording.
- The absolute numbers: boss HP, tier multipliers, Reincarnation steps, the 171-row scroll table, the 22 affix ids, and the 0/1 flag grid in the room pools. Scrapkeep tunes its own from the lab.
- HP scaling as a difficulty dial (the whole HP column of the ladder), build-multiplier-driven boss power, and the instant-kill-below-threshold enemy rule on players.
- The ladder's level count (8 vs 10 is unresolved) and the endless loop's rules.

## Gaps

- Monster health, damage, speed units beyond `MoveSpeed`, attack ranges, projectile speeds: absent from the shipped tables (logic is native or server side). Boss HP comes only from the wiki summaries; the act 1 second boss and the act 5 boss have no HP.
- Tell, active and recovery durations, punish windows, time to the first dangerous attack, burst damage as a share of player health, contact damage: none stated anywhere on disk. The `ShieldWarning` flag and `phaseconfig` timelines are the nearest data and are not tells.
- Player DPS is modeled (weapon table + level multiplier + assumed build multiplier 1.5/3/5/8 + assumed uptime 0.6 + assumed units match). Change the assumptions and the TTK moves proportionally; the implied-multiplier column does not depend on the build multiplier.
- Reincarnation middle levels are INFERRED by linear interpolation; only levels 1 and 7 are sourced; damage for acts 3-4, and the meaning of the 2.1x-per-level act-4 note, are unresolved. Level count 8 vs 10 is contradicted between wiki pages. The saved wiki folder is gone, so none of the wiki numbers were re-read from the source pages in this pass.
- The `KillLineUpLimit`, `HitActCD`, `PhaseInfo`, `CombatForce` and `phaseconfig` meanings are inferred from names and value shapes, not documented; the boss rows contradict reading `CombatForce` as a threat weight (act 3 bosses 1.0, act 4 alternate 0.0). The tier map by monster id prefix (2xxxx normal, 3xxxx elite, 39xxx boss) and the link between boss level and monster row are my name-matching.
- Mob budget growth per stage, enemies per room and wave, elite counts per room: not in the tables; only slot counts, candidate-pool sizes and room-rule categories are.
- The scroll effect counts are regex counts over effect text and overlap; the room-rule categories are my grouping of the `Name` field.
- The tier counts, speed percentiles, threat weights and boss ratios are reproduced by `verify_numbers.py`; the saved scripts are `verify_numbers.py`, `census.py`, `mon1.py`, `mon2.py`, `levels.py`, `boss_skills.py`, `boss_roles.py`, `dps.py`, `weap.py`, `ttk.py` in `~/scratch/game-study/difficulty-tools/gunfire/`.
