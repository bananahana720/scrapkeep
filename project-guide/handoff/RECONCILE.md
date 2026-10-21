# Reconcile: older decision records against the current record

Written 2026-10-17 by the "Reconcile past decisions" thread. Read-only pass; nothing in Andrew's local folder or in [DECISIONS.md](DECISIONS.md) was changed.

**Rule used:** the newer ruling stands by default. Only a true contradiction with no later ruling, or an item that is still open and only Andrew can settle, goes to him.

## What was read

| Record | Where | Notes |
| --- | --- | --- |
| Decision log, 1,000 rows, 5 Sep to 17 Oct | `docs/decisions.tsv` (origin/main = cand/alpha-w16) | Every row read. Line numbers below are file lines. |
| Bible decisions, decision register | `BIBLE_DECISIONS.md`, `docs/project/DECISION-REGISTER.md`, `BIBLE.md` | Read in full; Bible scanned for pillars, tone, music. |
| Design docs | `sketches/core-loop/design-v3/` OWNER-INTERVIEW-2026-10-02, ALPHA-PLAN, ROADMAP, DESIGN-V3, PARK, PILOTS, CUSTOMIZE, STRATEGY-SPINE, AUDIO-V3, LOOP-REDESIGN; `SITTING.md`; storyboard DECISIONS.md (PR #14) | Priority files in full; the rest by owner-ruling sections. |
| Local-only files | `artifacts/local/core-loop-playtest-veto.md` (R-22 veto list), `docs/project/PROJECT-MEMORY.md` (uncommitted snapshot, 16 Oct ~21Z), `artifacts/local/power-curve.tsv` | Only these differ from GitHub. |
| Current record | project memory (all files), `project-guide/handoff/DECISIONS.md` (19:55Z), `alpha-status/` scope and card queue | |

**About the local folder:** `/home/andrew/Projects/scrapkeep` is checked out at an older main (cd46b126, 16 Oct) and is a strict subset of origin/main, apart from the uncommitted memory snapshot and the gitignored `artifacts/local/`. So the old decision records are the same files that are on GitHub; nothing is stranded only on his PC except the R-22 veto list and the stale snapshot.

---

## 1. Needs Andrew's call (4)

True contradictions or open calls with no later ruling. Card text is ready in section 5.

| # | Topic | Older record | Current record | Why it is his |
| --- | --- | --- | --- | --- |
| Q1 | Time of day across a run | Two rival old calls: register D19 "one fixed time-of-day keyframe per biome" (DECISION-REGISTER:42, Sep, Open) vs PARK veto 2/11 "one day across a run; the Highdraft gives up its approved morning light" (PARK.md:629, 676, 10 Oct) | None | Look call that the dressing waves 18-19 need before they light the parks. |
| Q2 | Pilot unlocks at the sitting | P-R21 "fresh profile starts with Sable only; Rivet at the world-one rescue, Kest at the Dig rescue, Tarn by beating Brindle, Tally by three leaves to Moss, the Cannon by beating the Mind" (decisions.tsv:344, 8 Oct, in force; OWNER-INTERVIEW:26). Row 442 adds `--profile=sitting` with all six open. | Sitting = outside tester, Play leads to pilot select. Unlocks never mentioned. | Decides what he sees in his first hour and whether the sitting can judge all six pilots. |
| Q3 | Ending at Meteor Crater | PARK veto 6: "Meteor Crater is a camera set at the end of the ending sequence, not a playable lap; veto to make it a 60 s free roll" (PARK.md:671, 10 Oct) | Only "theme C scores the ending" | Taste call on the last minute of the game; never put to him. |
| Q4 | Codex / GPT lane | "Codex with gpt-6.1-sol is a standing lane beside each Claude wave" (decisions.tsv:115, 2 Oct; 323 P-R2 up to 8 Sol writers); "use GPT heavily" (679, 12 Oct); "Claude-first with Codex Sol parallel on 2-3 units" (852, 14 Oct) | All work runs in Claude cloud threads; no Codex lane | His own standing direction that current practice silently dropped. **Resolved:** retired by his tap 17 Oct 20:02 (DECISIONS.md Replaced rulings). |

---

## 2. Newer ruling stands (records to correct)

No question for Andrew. These old records still read "in force" or are still loaded by agents, so someone will trip on them.

| Topic | Old (date, where) | Newer ruling (date) | Fix |
| --- | --- | --- | --- |
| Five first-time players | Alpha goal "five first-time players reach the end of world one unaided" (decisions.tsv:947, 950, 16 Oct) | "Drop it": the 11-area sitting is the only gate (17 Oct 16:35Z tap, 16:38Z typed) | **Project memory `alpha-goal.md` still states the old goal**; also `grill-alpha-scope-2026-10-16.md` and the local snapshot. Update memory. |
| Main menu entries | Play, Camp, Settings, Help, Achievements (decisions.tsv:957, 16 Oct) | Same; memory `alpha-goal.md` lists only "Play, Settings" | Memory is incomplete, not a change. Fix `alpha-goal.md`. |
| Warning gap inside a pack | "Two warnings never start within 0.2 s" (decisions.tsv:992, 17 Oct 00:47Z) | "Pack as one" (17 Oct 15:30Z) | Add a superseding row. |
| Camp cut | W18-R1 cut camp recreation (decisions.tsv:263, 314; ROADMAP:15) | Camp back in (16 Oct grill-me); hub ring (22:36Z) | Mark superseded. The camp kit on `claude/camp-hub-model` already carries the lockers, skee-ball, pet, ghost trial, sandbox and settings console, so the interview's camp contents (OWNER-INTERVIEW:30) are not lost. |
| Cosmetics as tints, bespoke pilot models cut | decisions.tsv:263, 278 (5 Oct) | P-R7 trails, decals, companion paint (328); 18 cosmetics (16 Oct) | Mark superseded. |
| Direction sheets are a veto window, builds start | P-R3 (decisions.tsv:324, 6 Oct) | Storyboards first; all five calls tapped (16 Oct) | Mark superseded. |
| Dig landmarks are non-colliding scenery | P-R6 (decisions.tsv:327) | Headframe legs solid, sinkhole full ring, 20 m bowl (16-17 Oct) | Mark superseded. |
| Bot-driver work stops | P-R1 (decisions.tsv:322) | MIND-ROUTE "fix the bot route" (16 Oct 23:37Z) | Mark superseded. |
| One fix round per wave; a second needs Andrew | decisions.tsv:82, 96 (2 Oct) | Claude owns engineering; standing merge authority (17 Oct 19:41Z) | Mark superseded. |
| Andrew plays each wave before merge (light play lane) | decisions.tsv:412-413, 877, 917 ("waiting on Andrew"); **AGENTS.md** still requires it for sketches | "No per-wave play asks before the sitting" (949, 16 Oct); merge authority (17 Oct 19:41Z) | Close 877 and 917; reword the AGENTS.md line. |
| Worlds 2-3 and title music as synth placeholders | decisions.tsv:220, 266 | Full ACE score; picks by ear | Mark superseded. |
| Three playable pilots | decisions.tsv:260, 268 | Six required (174) | Mark superseded. |
| FLUX is the only picture engine, per-picture clicks | decisions.tsv:364 | Astra for detailed subjects (418, 428); blanket approval (433) | Mark superseded. |
| Model pins | decisions.tsv:852 "Opus writers" (14 Oct) | AGENTS.md pins Sonnet writers (28 Sep trial) | The log and AGENTS.md disagree; Q4 settles the Codex part, the coordinator should pick one for Claude writers. **Resolved 18 Oct:** Sonnet writers, Opus gate, Fable consequential review, as AGENTS.md pins. |
| Scrap-bot crew replaces the companion | decisions.tsv:467 "Accepted", Bible §6 on main | "One SPIL-9 for the alpha, crew after" (468, 476); "Grow SPIL-9" (17 Oct) | Mark 467 deferred; Bible §6 should say post-alpha. |
| Speed vs "momentum is sacred" | decisions.tsv:119, 251; ROADMAP:66, 300 | Speed soft cap past 60 m/s (17 Oct 07:17Z) | Record the soft cap as a deliberate exception. |
| Growth: shell grows, collider fixed | Bible pillar (BIBLE.md:65); DESIGN-V3:41; R-22 item 5 | "Presence, centre clear": burst size unchanged (17 Oct 17:28Z) | Consistent if "1.5-2x area is OK" means the aura, not the collider. Confirm on PR before anyone grows the collider. |
| Boss tempo 129, held-172 on F6 | R-22 item 6 (Andrew "love, love, loved" warden_spillway) | Eurodance 140-150 in bosses' final phase only (17 Oct 01:45Z) | Wardens and earlier boss phases stay 129. |
| Bible music and tone | BIBLE.md:751 and BD-17 "dry rhythm, restrained synth pulses"; BIBLE.md:76 humour | Steampunk-cyberpunk, house, jazz; Scott Pilgrim melodrama (16-17 Oct) | Bible §8 and tone section should point to SOUND-BIBLE and TONE-BIBLE. |
| Gamepad after world one | ALPHA-PLAN:40 | Gamepad optional (16 Oct) | Stale doc. |
| Coordinator commits straight to main; playbook tables | Local PROJECT-MEMORY.md:23, :12 | Candidate branch, merge authority; Sitting Kit page | The local snapshot (uncommitted, 16 Oct) is stale; CLAUDE.md on his PC still points agents at it. Refresh or delete it on his next pull. |
| Pilot leitmotifs | SOUND-EXTRAS "All four" (decisions.tsv:993, 01:36Z) | "Current tracks are the picks; no new themes" (15:59Z); "variations from current motifs" (17:10Z) | Build leitmotifs as variations of current motifs. No conflict then. |
| Two new enemy behaviours per wave | ENEMY-SPLIT (decisions.tsv:989, 00:47Z typed) | Speed pillar; specials built in parallel cloud threads (16:33Z, 17:16Z) | Read as a cap on what lands per wave candidate, not on build pace; coordinator's call. |
| "Level-ups" in the scaling rule vs "no XP curve" | decisions.tsv:489 | "Difficulty scales with items, level-ups, growth" | Level-ups read as heft class-ups; no XP curve. No conflict. |
| Wave 15 close hash | decisions.tsv:1001 says 1292b4b2 | Memory says origin main cf63e622 | cf63e622 is the record commit on top; cite cf63e622 for main. |
| PR #2 "he merges himself" | Local snapshot :32 | Merged as 77b99de5 | Done. |

---

## 3. Older owner rulings still in force but missing from the register

Nothing contradicts these; they were just never carried into the cloud record. Default: **they still stand.** The library thread should fold them into DECISIONS.md, and design threads should get the ones in their area. Andrew only needs to hear about one if a thread wants to change it.

**Run shape and difficulty**
- Three worlds in a row, every run starts in world one, one retry per world, 30-45 minutes, only unlocks carry over (decisions.tsv:153 interview; 176 only death spends the retry; 213 Continue after a quit stays free).
- First win in three to five attempts (BIBLE.md:475; OWNER-INTERVIEW:14). Breath normal tuned toward 3 of 5, Breath hard steeper (decisions.tsv:345).
- Difficulty never raises enemy health (472, default with veto); run tier caps health 1.6x, damage 1.3x, Wardens excluded (805, 820). Now sits beside power scaling and the attacker budget; the SQ2 thread should confirm all three layers agree.
- Specials and the budget: Foreman and Linker take no slot; Dispatcher chasers and Splitter pieces spend slots (992).
- A fall below a map's net deck lands on the deck, never death (231).

**Movement and feel**
- Movement belongs to the pilot: shared parts change what a verb does, never how far or fast the ball moves (727, 896, 903). Touches counter items, grip, the soft cap and poles/flails.
- Events never stop the ball: no drag, stun, hold or slow; weather never changes handling (PARK.md:357, 635). **Send to the "Enemy auras and pilot cast times" thread:** the new "electrical field that interrupts" motif should interrupt abilities, not stun the ball, or come back as a card.
- A kicker is met only from its ramp face (682). Shortcuts stay optional; a ground route stays open (218, 140). Skill-test areas should stay off the critical path (PARK.md:639, floor line).
- Abilities must have snap and fire while moving (ALPHA-PLAN:38; BIBLE.md:52). Tension with the new cast-time motif; any long cast goes to Andrew as a card.
- Every action has impact and weight, visual paired with audio, for pilots, packs and Wardens (565; audit 570 found a drone kill and a miniboss kill look the same, no stagger punch, boss defeat reuses the pack pop).
- Every mechanic shows its cause on the object before you act and its effect when it lands (78). Should govern the new motifs.
- Damage taken never shakes the camera (DESIGN-V3:296). Check it survives the melodrama camera pass.
- Harpoon spam stays legal, with a combo counter and miss cost, a skill-shot window, and deflector or counter-ram enemies from world two (180, 183; PARK.md:667 no deflector in world one).

**Enemies, Wardens and bosses**
- Park Wardens fight on their set pieces; the sheet ram is the only shatter (798, 882).
- Warden default "ram racks posture" (110 / curve 2), "revisit after Andrew plays both" (243, 258). The posture-family timing (45-70 s, confirmed 19:42Z) should say whether it replaces the old grown-ball Warden band of 25-45 s (689, 745) or covers only big tough enemies.
- One global warning grammar; no per-world telegraph palettes (338). Compatible with world-themed enemy mechanics if the theme is mechanical, not colour.
- Enemy homes are a breakable side goal (154 interview).

**World, look and camp**
- Ancient light is uranium-glass green 9dff3c, not Cherenkov blue (350, 429).
- Pilots are Hoberman-sphere mechas (417, 433).
- Look targets: Sol keyframes for worlds two and three; Arizona sandstone for world one (116, 155, 158); Southwest finish for parks; branching fans stay readable (466, 481).
- Look bar: "80 to 90% of the concept art" (ROADMAP:124, 28 Sep). The 16 Oct goal says zero placeholders; the sitting's "look" area is where he judges the bar.
- Mid-tier performance: a lower preset holds 60 fps on an RTX 3060-class card (ROADMAP:124-132; register D28 open). Current checks only run on his 4080.
- Activities are signposted from drop-in (181, 184).
- Tally's ledger hand-in is at Moss's shop; Tally's card finds stay deferred (264, 276). Recheck now that the camp exists.
- Enemy meshes may start from CC0 or CC-BY bases with the licence recorded; ripped meshes banned (474).

**Items, pilots and story**
- Hot-wired parts with a real downside (ROADMAP:177). Synergies that chain and visibly change the world (OWNER-INTERVIEW:21). Each pilot has at least two play identities in the kit tree (ROADMAP:195). Treasure-find ceremony with four tiers (ROADMAP:136). Pilot reactions to wins and failures (ROADMAP:149).
- Comps borrows from Gunfire Reborn and Roboquest are alpha scope (473, 475, 489: 44 adopt-now, 140 next push). Check how many landed.
- Story stays short and skippable (OWNER-INTERVIEW:13); intro cards should stay skippable.
- Music never freezes: pause and the calm bay keep the band playing (764, 777).
- Scrapped-together HUD: roughness on the frame, never on the information (ROADMAP:100). The HUD 25-word budget test (79, 120) should exclude comic and growth words or be retired.

---

## 4. Old open items (for the sitting or the coordinator, not cards)

- **R-22 veto list** (local only, `artifacts/local/core-loop-playtest-veto.md`): "every item goes to him when the demo is handed over". The 16 Oct "Keep all" taps covered wave 13-15 items, not these. Still live: ground probe, hint cards read literally, launch-rail speed gift, crush pass-through at cruise, Engineer F and hit shove, flush slag crust, slam needs a fresh press, pattern-part guarantee, "does growth still feel like Katamari", reward gates clear of props. Superseded by the posture fight: chip 20%, held HP floors, shred. **Default: fold the live ones into Sitting Kit prompts** rather than cards.
- **Other veto lists** never shown answered: about 30 rows "on Andrew's veto list" (decisions.tsv:184-234), PILOTS §6 (12 items), Tally D1-D15, CUSTOMIZE §11 (18), PARK §11/§13 (30). Same default: kept unless the sitting flags one. The coordinator can confirm against PLAN-w16-plus.md on the machine, which holds the 16 Oct list.
- **Feel checks deferred to his play:** dam fight timed by hand (827, 841); late take-or-skip pick (910); near-miss slow-motion off (500); skill-shot window timing (DESIGN-V3:94); shield reads as unreachable in slate (507); petrol Wardens beside petrol balls (430); Highdraft net hover (343). Add to Sitting Kit prompts.
- **Pilot animation hold-outs:** Sable's 11 new clips held out, Rivet and Tally clip misses (670). The 16 Oct tap covered Tarn and Cannon only. Sable is the starting pilot; the coordinator should schedule or accept.
- **Approval gates from the old process:** enemy and boss keyframe sheets before final models (ALPHA-PLAN:343, 365); ten-line lore tone sample per world (ALPHA-PLAN:342); ending text read by Andrew (265). Default: one look card when the four specials' final models are ready (wave 19); fold the lore sample into the lore-port card.
- **Frame budget:** the alpha keeps the about-70 ms stage-swap hitch against a 33 ms target (939, 959); SWAP-HITCH-6 is in no wave and #22 headless loader is undecided. Schedule it or accept it before "frame times in budget" is judged.
- **Park numbers left for dressing:** islands, crown and dam ratios (775, 780, 810, 924); sinkhole bake fix (961, 981), probably absorbed by PR #29's bowl.
- **Economy:** shop price-to-income 0.015-0.061 against a 0.5-2.0 band (545); cog payouts (214). Coordinator call.
- **Brindle plating 110** kept until the sitting (907, 982); check whether BRINDLE-HULL (merge tapped 17 Oct 15:30Z) changed it and record that.
- **Housekeeping on his PC:** 22 dirty worktrees (857), 317 G of model caches (855). Low; ask when he is at his desk.
- **Post-sitting story pass:** Brindle sincere or lying (D33), pilot bark budget (D18), secret-recipe details (BD-14).

---

## 5. Card text for the coordinator

1. **Should the light change over a run?**
   - "One day per run" (recommended): dawn in Spillway to dusk at the Mind; the Highdraft loses its approved morning light. Gives the run an arc.
   - "Fixed per world": each world keeps its own approved light; simpler to dress.
   - Reason: the run-as-a-journey matches the melodrama arc; decide before parks are lit in waves 18-19.
2. **How should pilots unlock for your sitting?**
   - "Ladder, sitting opens all" (recommended): new players start with Sable and earn the others; your sitting profile has all six so you can judge them.
   - "Ladder for you too": you play exactly as a stranger would.
   - "All open": no ladder in the alpha.
3. **How does the game end?**
   - "Camera on the crater" (recommended): the ending sequence closes on a Meteor Crater camera shot.
   - "60 s free roll": a last playable lap round the crater.
4. **Keep a Codex (GPT) lane beside Claude?**
   - "Retire it" (recommended): everything runs in Claude cloud threads, as now.
   - "Keep 2-3 units": Codex takes a few parallel units per wave on your PC.
