# Difficulty reference: summary for the Challenge lane

Purpose: give the Challenge lane reference numbers to tune Scrapkeep's skill bands against, taken from the four games Andrew rates. The ruling is in `project-guide/handoff/DECISIONS.md` section 5 (19 Oct 01:58, two rows, on `main`): hard but fair, Souls-like bosses, cracked builds still steamroll, parks and mobs a notch harder, extra hardness moved into a replay ladder.

Files: [isaac.md](isaac.md), [gunfire.md](gunfire.md), [roboquest.md](roboquest.md), [ror2.md](ror2.md). Each has the same sections: Bosses, Mobs and events, Difficulty ladder, Why it works, Patterns for Scrapkeep's skill bands, What it must not copy, Gaps.

## How to read these numbers

- **Source paths** in the game files are relative to `~/scratch/game-study/` on the coordinator PC (for example `isaac/extracted/resources/entities2.xml`, `ror2/decomp/RoR2/Run.cs`, `roboquest/tables/DT_Difficulty.csv`, `gunfire/tables/raw/monsterdata_3001.txt`). Those study copies live outside the repository and are deleted when this pack is accepted, per the comps posture in [../README.md](../README.md). From the repository alone every number is level 2 (a pointer). At the time of extraction, values a script read or computed were level 4.
- **Fresh extraction, 18 Oct 2026.** Isaac resources were unpacked again with the game's own extractor (the install is Afterbirth+, not Repentance, so there are no Tainted or alternate-path tiers). RoR2.dll was decompiled again with ILSpy, and 932 attack-timing override assets were read from the bundles with UnityPy. The asset values win over the code defaults, and the RoR2 file uses them. Roboquest's 60 tables were dumped again from the archive. Gunfire's 234 data tables were re-extracted, but its game logic is encrypted, so Gunfire has no tell, HP or damage data and its boss HP comes from the wiki via the earlier study's reports.
- **INFERRED** marks anything computed under an assumption. Every time-to-kill (TTK) number is INFERRED, because none of the games stores player DPS at a point in the run. Each file states its DPS model before its TTK table.
- **Win rates.** None of the four games has win-rate or skill-band data in its files. The skill-band targets themselves can only be calibrated by the Challenge lane's bots. These comps give the shape of fights (length, tell, window, hit size, ladder steps), not the percentages.
- **Checks.** Each file was drafted by a Sonnet 5.5 extractor and checked by an Opus 5.5 reviewer. Across the four files the reviewers spot-checked over 120 numbers against source and recomputed the arithmetic. All four first drafts failed, on 3 wrong counts plus labelling, overclaims and names in prose. All corrections were applied and spot-checked again by the coordinator.

```mermaid
flowchart LR
    subgraph Base tier, ordinary build
      T[Boss TTK 50-90 s<br/>Warden 90-150 s] --> W[Tells: heavy >= 1.0 s<br/>lethal-class >= 1.5 s]
      W --> P[Punish: 0.5-1.0 s per attack<br/>one 5-8 s window per cycle]
      P --> H[Hits: 4-7 to die<br/>no one-shot from full]
    end
    subgraph Replay ladder, 8 steps
      L1[damage to 1.3x cap] --> L2[aggression +40%]
      L2 --> L3[recovery -30%, healing x0.5]
      L3 --> L4[+1 phase or desperation move]
      L4 --> L5[elites and variants]
    end
    H --> L1
```

## Suggested ranges

Each row is a recommendation for the Challenge lane, traced to the source rows that support it. These are not rulings. The comps disagree in places, and the reconciliation is stated in each row.

| # | Quantity | Suggested range for Scrapkeep | What the comps show | Source rows |
|---|---|---|---|---|
| 1 | Boss TTK, base tier, ordinary build (mid bosses and park bosses) | **50 to 90 s** | Isaac early and mid bosses 37 to 63 s (low to high build 23 to 90 s). Roboquest non-final bosses 42 to 88 s, median 55 s. RoR2 about 40 s per cost-600 boss with item power held flat, falling to 15 to 28 s with items; the pot buys 2 to 3 bosses per event at stages 3 to 5, so per event about 40 to 46 s. Gunfire 2.2 to 7.3 min is the outlier (a looter-shooter whose bosses are HP sponges). All INFERRED. | isaac.md, Bosses: DPS and TTK assumption, Early and Mid tables; roboquest.md, Bosses: Player damage and TTK; ror2.md, Bosses: Early boss slot, and Patterns; gunfire.md, Bosses: TTK at an ordinary build |
| 2 | Warden TTK, base tier, ordinary build | **90 to 150 s**, across 2 to 3 stagger cycles | Scrapkeep already holds Wardens 45 to 70 s to first stagger (hive 60 to 85 s), so a kill takes about 2 cycles. That sits between the comps' ordinary bosses (row 1) and their finals: Isaac stage-10 end boss 114 s; Roboquest final 147 s for both forms; RoR2 final about 44 s per form across two scaled forms plus a squad form and a short last form. Isaac's optional and secret finals run 160 to 500 s and suit the ladder, not the base tier. | isaac.md, Late bosses; roboquest.md, Per-boss detail (final); ror2.md, Final boss (four forms); DECISIONS.md section 5 stagger rows |
| 3 | Tell before a heavy hit (25% or more of pilot health) | **1.0 s minimum, 1.5 to 2.5 s median** | RoR2 heavy attacks (17 attacks costing 25% or more of base HP; tell = skill start to first damage): median 2.3 s, max 6.0 s, min 0.2 s. Without the three final-boss rows: min 1.0 s, median 2.15 s. The 0.2 s outlier is the final boss's ultimate, whose damage comes as 3 s projectile lines, so travel is the real warning. RoR2 does not tie the biggest hits to the longest tells: hits above 50% sit behind 0.2 to 6.0 s. Isaac wind-up clips have a median of 0.87 s, and 91% are 0.6 s or more. | ror2.md, Bosses: heavy-tell table; isaac.md, Aggregate attack timings |
| 4 | Tell before a light hit (15% or less) | **0.6 s floor kept**. Below 0.6 s only when the hit visibly travels or is cooldown-gated | Roboquest boss tells: median 0.75 s, min 0.2 s. 18 of 34 campaign boss rows are under 0.6 s, but the 13 of those that hit for 24 to 26 deal 12 to 13% of base HP each. Beams, floor plates and large areas carry 0.65 s or more. Isaac's trigger-timed releases have a median of 0.33 s, but most sit behind a longer visible wind-up. Read this as: the 0.6 s rule binds lethal and heavy hits hardest, and light hits need either 0.6 s or visible travel. | roboquest.md, Boss attack grammar, and Patterns (tell row); isaac.md, Patterns (tell row) |
| 5 | Lethal tell minimum on the ladder | **Never under 0.6 s for any hit above 15%**. Ladder steps shorten recovery and cooldowns, not tells | RoR2's top steps halve enemy cooldowns (step 7 of 8 hard rules) and raise enemy speed x1.4 (step 4), but no step shortens a wind-up. Roboquest's top steps raise boss speed +12.5%, which shortens animation-timed tells by about 11% (INFERRED). | ror2.md, Difficulty ladder; roboquest.md, Difficulty ladder |
| 6 | Punish window after an ordinary boss attack | **0.5 to 1.0 s** | Roboquest recovery median 0.5 s, p75 1.0 s, max 1.5 s. Isaac rests 0.67 to 0.8 s and a flinch of 0.5 s. | roboquest.md, Patterns (punish row); isaac.md, Mid bosses punish table |
| 7 | Punish window after a heavy attack | **1.5 to 4.5 s** | RoR2's slow-fist boss has about 4.7 s of dead time after its fist. Isaac has a dizzy chain of 1.73 s. Roboquest boss staggers last 0.7 to 1.25 s. | ror2.md, Cost-600 A; isaac.md, Mid bosses punish table; roboquest.md, Patterns (punish row) |
| 8 | Long scripted window | **one per boss cycle, 5 to 8 s** (Scrapkeep's stagger is this window) | Roboquest has an 8 s low-health self-stun and 8 s weak-point exposure cycles. These are the only long windows in the four games' data. | roboquest.md, Per-boss detail |
| 9 | Ordinary boss hit, share of pilot health | **15 to 25%** (4 to 7 hits to die at base) | Roboquest single hits are 5 to 14% (about 7 hits at base, 5 at the top step). Isaac is about 33% per hit (3 hits, INFERRED). RoR2 boss single hits are 25 to 36% at parity levels (3 to 4 hits). A Learner winning 15 to 35% on a first try fits a death on the fourth or fifth mistake, not the first. | roboquest.md, Burst damage; isaac.md, Patterns (burst row); ror2.md, Single-hit and burst damage |
| 10 | Heavy or special hit, share of pilot health | **30 to 50%**, and **no single hit kills from full at base tier** | RoR2 specials are 50 to 118% of base HP, but a one-shot guard caps any one server update's damage at 90% of full health, and a triggered guard grants 0.1 s of immunity. Roboquest salvos have ceilings of 26 to 420% if every shot lands, answered by travel time. Scrapkeep can adopt the guard at base tier and thin it on the ladder, as RoR2's top step does (one 30% hit at the top step removes it for the run, INFERRED arithmetic). | ror2.md, Single-hit and burst damage, and Difficulty ladder; roboquest.md, Burst damage |
| 11 | Opening grace (no Learner death in the first 45 s) | **3 to 8 s spawn intro**, then **only phase-1 patterns with hits of 25% or less** until 45 s. Check it as simulated unavoided damage per second times 45 s against Learner health, not as a timer | None of the comps has a 45 s timer. RoR2 boss intros are 4 to 8 s, and the slow-fist boss's first hit lands about 5.5 s after spawn. Isaac's appear clips have a median of 0.67 s. Roboquest has 1 to 10 s waits on three bosses. Each game protects the opening with hit buffer and low early damage instead. | ror2.md, Cost-600 A; isaac.md, Patterns (first 45 s row); roboquest.md, Time before the first dangerous attack |
| 12 | Phases | **2 at base for a Warden (gate at 50 to 60%), 3 for a world finale (75 / 40)**. The ladder adds one phase or a desperation move gated at 25% or less | Isaac: most bosses 1 phase, finals 2 to 3. Gunfire wiki thresholds 75/50/25 or front-loaded 75/40/5 and 75/40/25. RoR2 1 to 2 gates per ordinary boss, median 75%, range 25 to 95%; its room-wide nova (118%) is gated to 25% boss HP or less. Roboquest: one boss with thresholds at 85/75/70/25/20%. | isaac.md, Late bosses; gunfire.md, Phases and thresholds; ror2.md, Bosses; roboquest.md, Boss attack grammar |
| 13 | Pattern count and signature share | **4 to 6 weighted patterns per boss**, signature move about **30%** of picks | Roboquest bosses have 4 to 6 weighted patterns, and the signature move's weight share is 20 to 55% (median 32%). Gunfire boss rows carry 6 to 12 named attacks (median 9), and its act-4 variants keep the stats and swap 3 to 5 skills. | roboquest.md, Boss attack grammar; gunfire.md, Variants |
| 14 | Mob density growth over a run | **Keep the attacker budget (6 to 12, a 2x span)**. Raise pressure through aggression and elite share, not count | Isaac enemies per room stay flat at 3.6 to 4.3; the top room class is x1.2 to x1.7 the count of the easy class. Roboquest counts are fixed at 4 to 10 per encounter and 26 to 47 per level, and difficulty swaps in variants and elites. RoR2 director income grows 3.6x over five stages, but each spawn series caps at 6 bodies. | isaac.md, Room spawn budget and Room difficulty classes; roboquest.md, Mobs and events; ror2.md, Mobs and events |
| 15 | Aggression dial per step | **attack interval x0.85 to x0.7**, at most two stacked; x0.5 only on a ladder step that also gives the player something | Gunfire enemy-side rows cut attack interval on 18 rows, 14 of them by 30%. Roboquest's aggression (token refill) runs to +40% at the top step. RoR2 halves enemy cooldowns at its seventh hard step and raises enemy speed x1.4 at its fourth. | gunfire.md, Enemy-side modifier rows; roboquest.md, Difficulty ladder; ror2.md, Difficulty ladder |
| 16 | Elite rate | **0 to 1 elite per park at base, 2 to 3 at the top ladder step**. Elite HP stays within Scrapkeep's 1.6x cap | Roboquest has 0 elites at base and about 2.9 per level at the top step, plus 50% of regular enemies swapped for variants. Isaac boss recolors have HP x1.25 median (range 0.45 to 2.0). RoR2 elites have HP x3 to 4 median and damage x2, picked by credit, so they grow with the run. Gunfire adds enemy enhancements only from its second tier. | roboquest.md, Difficulty ladder; isaac.md, Elites; ror2.md, Mobs and events; gunfire.md, Elite affixes |

## A replay ladder in the comps' shape

The ruling asks for a HARD ladder where an Expert with an ordinary build wins about half the time at the top. Three of the four games converge on the same shape. They hold durability nearly flat and stack rules. RoR2's eight hard steps raise no boss HP or damage coefficient. Roboquest caps boss HP at +35% from its seventh row while damage keeps rising. Gunfire freezes stats after its seventh level and adds rule rows. Scrapkeep already forbids difficulty raising enemy health, so it lands in the same place.

The proposed ladder below is INFERRED. Each step borrows one comp rule with its number. The Challenge lane should treat the order and the sizes as the first bot-tuning pass.

| Step | Adds | Number | Comp row it borrows |
|---|---|---|---|
| 1 | Boss and mob damage | x1.1 | Roboquest steps add 5 to 10 points of damage each (roboquest.md, Difficulty ladder) |
| 2 | Aggression | attack interval x0.85, token refill +15% | Gunfire's attack-interval rows; Roboquest's token speed (gunfire.md, Enemy-side modifier rows; roboquest.md, Difficulty ladder) |
| 3 | Elites appear in parks | 1 per park | Roboquest elites start above its standard tier (roboquest.md, Mobs and events) |
| 4 | Enemy move speed | x1.15 (RoR2 uses x1.4) | RoR2 hard step 4 (ror2.md, Difficulty ladder) |
| 5 | Healing and recovery | pilot healing x0.5 | RoR2 hard step 5 (ror2.md, Difficulty ladder) |
| 6 | Damage to cap, punish windows shorter | x1.3 (run-tier cap); boss recovery x0.75 | Roboquest top damage +40% (roboquest.md); Scrapkeep cap from DECISIONS.md |
| 7 | One extra phase or a desperation move gated at 25% or less | +1 phase per Warden | RoR2's low-HP nova gate; Gunfire's late thresholds (ror2.md, Bosses; gunfire.md, Phases and thresholds) |
| 8 | Elites and variants dense; cooldowns shorter; one-shot guard removed | 2 to 3 elites per park, 50% variants, boss cooldowns x0.7 | Roboquest top row; RoR2 hard step 7 (cooldowns x0.5) and its top step's guard erosion (roboquest.md, Difficulty ladder; ror2.md, Difficulty ladder) |

Gunfire's ladder is the counter-example: tier 2 is HP and damage x1.4, tier 3 is HP x2.4 and damage x1.8, and Reincarnation 7 reaches HP x5.9 to x13.6 by act (the middle levels are interpolated, INFERRED). Scrapkeep cannot copy that axis. The lesson it does carry is that stat ladders end in rule ladders (gunfire.md, Difficulty ladder).

## Where the comps do not reach

- **Win rates and skill bands**: no data in any game. The 85%, 15 to 35%, 60% and 97% targets are calibrated only by the Challenge lane's bots.
- **Tell on screen vs tell in data**: Isaac's numbers are animation-file timings, Roboquest's are a data timer (`PreshootDuration`, longer at close range on 10 of 34 campaign rows), and RoR2's are entity-state durations from assets. None is a measured on-screen telegraph. Scrapkeep's tell should be measured in its own build, from the first visible cue to the damage frame.
- **Gunfire timing**: no tell, punish, HP or damage data. Gunfire contributes ladder structure, phase thresholds and aggression dials only.
- **Phase thresholds in Isaac and most of Roboquest** live in code that was not decoded.
- **The first-45 s guard** has no counterpart in any game's data. Row 11 is a design proposal.

## Lab measure

For each Warden at base tier with the ordinary-build bot, report TTK, tell length for every attack that can deal more than 15% of pilot health, recovery after each attack, the largest single-update damage as a share of pilot health, and damage taken in the first 45 s by the Learner bot. Compare each against rows 2 to 11 above. A Warden outside a row's range is either retuned or carries a recorded reason.
