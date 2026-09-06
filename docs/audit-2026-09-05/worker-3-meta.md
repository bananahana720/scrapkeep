# Worker 3 — Meta-progression design report (Scrapkeep)

Session date: 2026-09-05. Read-only pass over /home/andrew/Projects/test-game-2. All file:line citations were observed in this session. Everything under a "Proposal" label is design work, not an observed fact. No repo files were written.

## Grounding: what is confirmed vs. candidate

Observed constraints this design must respect:

- Expedition structure is confirmed: themed stages, each with exploration, combat and defense encounters, optional branches, and a boss; a successful expedition takes about 30–45 minutes (docs/DISCOVERY.md:33; docs/project/REQUIREMENTS.md:17, R11).
- Between-run progression is confirmed as "unlock new classes, items, companion parts and challenges; rebuild combat power during each run," explicitly settling permanent combat-stat progression as out (docs/DISCOVERY.md:35; docs/project/REQUIREMENTS.md:18, R12).
- R12 adds: "Do not inherit baseline progression automatically" (docs/project/REQUIREMENTS.md:18).
- The notebook's five-level dungeon structure and the pick-one-of-two boss reward are candidates, not commitments (docs/HANDWRITTEN-NOTES.md:50-54, 79-80; docs/DISCOVERY.md:45,71).
- Notebook rule: items are MEANINGFUL — they add visual components, gameplay mechanics, or modifiers (docs/HANDWRITTEN-NOTES.md:55-57).
- Open publisher questions 5 and 6 cover how far rare items may rewrite a class and what stage count/cadence fits 30–45 minutes (docs/DISCOVERY.md:196-197).
- The working expedition flow proposal already carries the run build across stages and treats the pick-one-of-two as the boss reward candidate (docs/DISCOVERY.md:63-71).
- Isaac's item philosophy is the strongest stated combination reference (docs/DISCOVERY.md:19), with Brimstone/Mom's Knife named (docs/DISCOVERY.md:21).

Market complaints this design must dodge (all from purposive, non-representative samples — prompts for testing, not prevalence):

- The 28-review sample across Roboquest, Risk of Rain 2, and Deathtrap "surfaced questions about progression grind, constrained builds, readability and co-op reliability" (docs/DISCOVERY.md:159).
- Go Mecha Ball: "Two of five negatives and one of five positives discuss repetition or delayed diversity" (docs/MARKET-SOURCES.md:29); MARKET-RESEARCH.md:55 summarizes this as "delayed variety/repetition."
- Rock of Ages 3: one negative "objects to progression requiring repetition" (docs/MARKET-SOURCES.md:30).
- Katamari: negatives describe disrupted rolling and repetition/thematic distribution (docs/MARKET-SOURCES.md:31).

---

## 1. Expedition skeleton (proposal)

### Cadence comparison

| Criterion | Model A: 3 stages × ~12–13 min | Model B: 5 stages × ~7 min + interstitials (notebook literal reading, docs/HANDWRITTEN-NOTES.md:51) |
| --- | --- | --- |
| Pacing in 30–45 min | Each stage fits a full explore → fight → defend → boss arc with room for one optional branch. Slack absorbs player skill variance. | ~7 min per stage forces cutting either exploration or the defense encounter; 5 interstitials add ~4–5 min of non-play overhead. |
| Defense-encounter requirement (REQUIREMENTS.md:17 requires defense encounters per the confirmed structure) | One full defense encounter per stage, three per run, each themed differently. | Either five thin defenses (repetition risk, the exact Go Mecha Ball complaint at MARKET-SOURCES.md:29) or defenses skipped in some stages, weakening R11. |
| Boss anticipation | 3 bosses per run; each boss carries a pick-one-of-two reward, so each is a genuine event. Matches the existing three-sector arc the codebase already proved paces well (src/campaign.js:22-44,83-85: three SECTORS over 15 waves) and the three-stage escalation imagery in MARKET-RESEARCH.md:90-94. | 5 bosses per run shows 10 reward options per run — the reward pool depletes faster and each boss matters less; boss production cost rises 66%. |
| Notebook fidelity | Reinterprets the notebook "5" as five beats per stage (below). | Literal, but the notebook describes an earlier game concept (docs/HANDWRITTEN-NOTES.md:5) and the five-level count is explicitly not committed scope (docs/HANDWRITTEN-NOTES.md:79). |

**Recommendation: Model A — three themed stages, five fixed beats per stage.** The notebook's "5 levels, each with an end-level boss" survives as five beats inside each stage rather than five stages; the boss-per-level idea maps to boss-per-stage. This keeps R11's full encounter mix intact three times per run, reuses the proven three-sector pacing shape, and makes every boss a pick-one-of-two event.

### Minute-by-minute sketch (proposal; mid-skill run ≈ 38 min)

Stage themes borrow the escalation table (Salvage Spillway → Stormglass Foundry → Walking Orchard, docs/MARKET-RESEARCH.md:90-94) as placeholders.

| Time | Beat |
| --- | --- |
| 0:00–1:00 | Embark: class select, one-line stage brief, roll-in. No loadout screens beyond class (combat power rebuilds in-run, DISCOVERY.md:35). |
| 1:00–5:00 | Stage 1 explore/collect: open pocket, first items and companion parts, visible ball growth. |
| 5:00–8:00 | Combat pockets + optional branch (risk/reward affecting current build, per DISCOVERY.md:66). |
| 8:00–10:30 | Defense encounter: deploy-while-moving infrastructure fight (DISCOVERY.md:67). |
| 10:30–12:30 | Stage 1 boss; pick one of two rewards; the unpicked one is logged (Section 3). |
| 12:30–13:00 | Interstitial: carry ball, items, companions forward (DISCOVERY.md:70); one breath, no shop. |
| 13:00–26:00 | Stage 2, same five beats, +1 min exploration, defense gets a twist (e.g., two lanes), branch offers a companion chassis. |
| 26:00–38:00 | Stage 3: compressed exploration (the build is online), the biggest defense encounter, finale boss ~4 min with spectacle scale (DISCOVERY.md:37), results. |

Skipping branches lands near 30 min; full-clearing both branches plus a cautious finale lands near 45. The baseline demo's own evidence that a full run took ~915 simulation seconds (~15 min, docs/RETENTION-VERIFICATION.md:20-23) confirms the new 30–45 min expedition is a different product target, not a retuning of the yard.

---

## 2. Unlock architecture (proposal)

### What unlocks, on what triggers

Everything unlocked widens the option space; nothing raises permanent combat stats (hard constraint from DISCOVERY.md:35 and the baseline's own precedent — "Mastery grants titles and collectible cards without changing combat power," docs/BASELINE-GUIDE.md:38).

| Unlock type | Content | Trigger (milestone, not currency) |
| --- | --- | --- |
| Classes | Grapple (starter), hover mortar, cyborg laser, lightning (roster from DISCOVERY.md:17) | Named milestones: kill the stage-2 boss once → class 2; win any expedition OR reach 6 cumulative boss kills → class 3; complete a defense encounter untouched OR 12 boss kills → class 4. Dual triggers mean a skilled player and a persistent player both progress; nobody replays content they've beaten purely to refill a bar. |
| Items (pool entries) | New shared items and class-item interactions enter the run drop pool | "Witnessed" unlocks: seeing an item combo fire, full-clearing a branch, or finishing a boss with a signature skill shot adds a related item to the pool. The pool widens because of what happened in play. |
| Companion parts | Chassis and behavior modules (assembly concept at DISCOVERY.md:125) | Assemble N distinct companions across runs; rescue-triggered parts unlock after a companion clutch-save actually occurs (DISCOVERY.md:119). |
| Challenges | Hazard contracts (evolving the baseline hazardous route: +80% HP / +25% speed for +50% points, docs/BASELINE-GUIDE.md:36), seeded friend challenges and a daily seed (mechanisms already built: src/campaign.js:206-256) | First expedition win unlocks contracts; contracts thereafter unlock by attempting, not grinding. |

One optional soft lever: boss kills drop a single "keepsake cog" the player may spend to choose WHICH pending unlock resolves next. Cogs never buy power and never accumulate as a grind wall; they only reorder the queue. This preserves anticipation while giving agency.

### Why this dodges the cited complaints

- Progression grind (docs/DISCOVERY.md:159) and "progression requiring repetition" (docs/MARKET-SOURCES.md:30): no unlock requires repeating cleared content to farm currency. Every trigger is a thing you do while playing normally, with dual paths so a wall never forms.
- Constrained builds (docs/DISCOVERY.md:159): a class is complete at unlock — "A grapple class should have a useful grapple before any lucky drop" (docs/DISCOVERY.md:51). Unlocks only ADD pool entries; the starting kit is never a gutted version of a later kit. There are no meta-upgrades standing between the player and a functional build.
- Delayed variety (docs/MARKET-SOURCES.md:29): the first-10-hours plan below guarantees at least one new class, item family, companion part, or challenge type lands roughly every session.

### First ~10 hours, session by session (proposal; ~40 min/session ≈ 15 sessions)

| Session | Expected state |
| --- | --- |
| 1 | Grapple class; likely defeat at stage 2. ~8 discovery-log entries open. Results screen previews "Stage 2 boss falls → new pilot arrives." |
| 2 | Stage-2 boss killed → class 2 (hover mortar) unlocks. First companion assembled. |
| 3–4 | Mortar runs; witnessed unlocks add 4–6 items; first hazard contract after first win (session 3 or 4). |
| 5 | Class 3 (laser) via win-or-6-bosses dual trigger. |
| 6–8 | Companion chassis #2 and #3; branch-specific item families; first daily-seed and friend-challenge play (ported mechanisms, src/campaign.js:206-256). |
| 9–10 | Class 4 (lightning) via untouched-defense-or-12-bosses. All four class fantasies live before hour 7. |
| 11–15 | Contract tiers, stage-variant branches, deep item interactions revealed by discovery count (e.g., 20 logged items → "volatile" item family enters the pool). Ledger sits near 60% — visibly unfinished on purpose. |

Rule of thumb enforced by the unlock table: no session in the first ten hours ends without a new ledger entry or unlock.

---

## 3. Discovery-as-progression (proposal)

The primary anticipation engine is not a power curve — it is "what does THIS do?", per the confirmed Isaac item-philosophy reference (docs/DISCOVERY.md:19) and the notebook's items-are-MEANINGFUL rule (docs/HANDWRITTEN-NOTES.md:55-57).

Three curiosity loops:

1. **Item mystery.** Undiscovered items drop as silhouetted scrap with a two-word flavor name only. The full entry — what it does, what it combined with — is written by play: the log fills in AFTER the effect fires. An Echo Canister-style item (docs/DISCOVERY.md:77) gets four sub-entries, one per class interaction, so even a "known" item stays partially unknown across the roster.
2. **First-encounter enemy reveals.** New enemies enter with a readable commitment (required by docs/DISCOVERY.md:135 and R03, docs/project/REQUIREMENTS.md:9) and a log entry that records observed behaviors, not stat sheets: counters the player has actually performed get checkmarks. The proposed enemy taxonomy families (referenced at docs/DISCOVERY.md:43) give the log its chapter structure.
3. **Pick-one-of-two boss rewards — "the one that got away."** The notebook's candidate reward format (docs/HANDWRITTEN-NOTES.md:53; docs/DISCOVERY.md:68) becomes the single strongest return hook: the unpicked reward is logged as *seen, not taken*, greyed with its name visible. The ledger literally accumulates reasons to run again. Both options at a boss are drawn so at least one is undiscovered whenever the pool allows it.

**The Scrapbook (in-game discovery log).** One screen, five tabs: Pilots (classes + mastery titles), Salvage (items, with per-class interaction sub-entries and a "seen, not taken" shelf), Companions (chassis × module combinations actually assembled), Foes (behavior checkmarks), Expeditions (stage themes, branches found, bosses, best results). Completion percentages per tab feed the witnessed-unlock triggers in Section 2, so browsing the Scrapbook doubles as reading your own unlock map. This is the expanded-game descendant of the baseline's field-card unlock feedback ("field card unlocks at 150 mastery," src/collection.js:186; src/campaign.js:139-141).

---

## 4. Collection layer (proposal grounded in observed code)

### What the yard demo actually tracks

- Per-class profile: `{ xp, runs, wins, bestScore, bestWave }` for each of three heroes, plus `settled` run IDs and earned `blueprints` (src/campaign.js:98-110).
- Five mastery badges from "New wheels" (0 xp) to "Orchard legend" (700 xp) (src/campaign.js:89-95); xp awarded at 10/wave + 50 for victory (src/campaign.js:186); a field-card blueprint unlocks at 150 xp (src/campaign.js:195-198).
- The Collection dialog renders a figurine shelf per hero with tabs, mastery track, a downloadable SVG field card, and the optional figurine-interest signup (src/collection.js:171-225; field-card SVG generator at src/collection.js:305-319). Menu copy: "The classes you play become the figurines you keep" (src/collection.js:177).
- Heroes exist as both procedural 3D models (src/heroes.js:55-211) and 2D SVG portraits (src/heroes.js:213-222) — i.e., the pipeline from playable character to displayable collectible object already exists in miniature.
- Persistence is idempotent run receipts that survive cross-tab and storage failure (src/progress-store.js:17-34, 78-104; behavior verified in docs/RETENTION-VERIFICATION.md:28,42).

### Evolution into the expanded game

- **The shelf becomes a diorama.** Instead of three static portraits, the collection screen renders the actual 3D models (the src/heroes.js:55 pattern, extended) of every unlocked class, named companion assembly, and defeated boss — posed on a shelf. Because companion assemblies are player-made combinations (docs/DISCOVERY.md:123-125), a player's shelf is partly unique to them.
- **Field cards generalize.** The per-hero SVG card (src/collection.js:305-319) becomes the card format for every Scrapbook entry class — pilots, companions, bosses — keeping the free, no-signup download rule (docs/RETENTION-VERIFICATION.md:42: "No signup gates gameplay, mastery, or field-card downloads").
- **Mastery stays cosmetic.** Class titles and badge tiers (src/campaign.js:89-95) carry forward as paint finishes/poses on the shelf model — visual progression aligned with play, per the notebook ("visual and skill upgrade progress that aligns in design," docs/HANDWRITTEN-NOTES.md:48), never combat stats (R12).
- **Physical figurines feed back into digital design.** The planned figurine line (docs/DISCOVERY.md:15; the shelf copy at src/collection.js:177) means the digital collection should be designed as a product catalog the player curates: each class and each named companion chassis is a plausible SKU; the diorama pose IS the figurine pose. The existing honesty rule carries over — art is "a game concept rather than a photo or print-ready model of the sold figurines" (docs/RETENTION-VERIFICATION.md:36) — and the signup remains optional and separate (src/collection.js:219-223 disables submission when capture is off).

---

## 5. Return hooks, ranked (build-cost vs. retention impact; solo premium PC; no dark patterns)

1. **"The one that got away" ledger** (low cost, highest impact). A results-screen line and a Scrapbook shelf listing boss rewards seen but not taken. Builds on the notebook pick-one-of-two candidate (docs/HANDWRITTEN-NOTES.md:53) and the Scrapbook (Section 3). Pure anticipation; nothing decays, nothing expires.
2. **Seeded friend challenges** (near-zero cost — already built). Encode/decode/URL and clipboard share exist and are versioned (src/campaign.js:222-256; src/collection.js:154-169); the format's `1.` prefix (src/campaign.js:230) leaves room for expedition-format v2. Informal, client-side, no leaderboard pressure (docs/RETENTION-VERIFICATION.md:40).
3. **Next-unlock preview on results** (low cost, high impact). "One more stage-2 boss reveals the next pilot." settleRun already returns an `unlocks` array to render (src/campaign.js:193-204); this extends it to *pending* milestones. Transparent goal-setting, not a timer.
4. **Daily seed as a shared puzzle, not an appointment** (near-zero cost — src/campaign.js:206-221 exists). Everyone who plays today rolls the same expedition. Crucially: no reward, no streak, no expiry-based loss — miss a day and you have missed nothing but a conversation. This keeps it inside the no-FOMO constraint.
5. **Mastery titles and shelf finishes** (medium cost, medium impact). Extends badges (src/campaign.js:89-95) and the diorama (Section 4). Long-tail collectors' hook; cosmetic only.

All five survive absence unpunished: nothing resets, decays, or expires, consistent with the baseline's own posture (mastery kept on defeat — "CORE OFFLINE / MASTERY KEPT," src/collection.js:149).

## 6. Reuse-or-retire verdict on the baseline yard's retention build

**Verdict: reuse the architecture, retire the content and tuning.** Evidence level: strong for the code claims (read this session), design-level for the recommendations.

Reuse:
- `progress-store.js` wholesale — idempotent run receipts, cross-tab settlement, storage-failure degradation (src/progress-store.js:17-104) — independently reviewed and corrected against stale-tab mastery loss (docs/RETENTION-VERIFICATION.md:28).
- The pure-campaign-module pattern (progression rules with no DOM, src/campaign.js throughout; pattern noted at docs/RETENTION-BUILD.md:33) and its validation discipline (src/campaign.js:166-177).
- Challenge/daily seed mechanisms (src/campaign.js:206-256) with a v2 payload for the expedition format.
- Collection-dialog UX patterns: field cards, no-signup gating, honest storage messaging (src/collection.js:149,186; docs/RETENTION-VERIFICATION.md:42).
- The hero-model→collectible pipeline (src/heroes.js:55-222).

Retire:
- The 15-wave/3-sector/5-modifier structure (src/campaign.js:1,22-88) — superseded by the stage-based expedition (R11).
- XP thresholds, badge curve, blueprint-at-150 constants (src/campaign.js:89-95,139-141) — R12 explicitly forbids inheriting baseline progression automatically (docs/project/REQUIREMENTS.md:18).
- The three-hero roster as content (src/campaign.js:2-21) — replaced by the four class fantasies (docs/DISCOVERY.md:17); Pip/Rivet/Moss remain candidates for cameo/figurine reuse only.
- Lead capture stays parked as an optional, separately-configured module (its operating limits at docs/RETENTION-VERIFICATION.md:38) — not part of the retention loop proper.

## Open items for the parent

- Whether the "keepsake cog" order-picker is wanted at all, or milestones alone suffice (touches open question 5, docs/DISCOVERY.md:196).
- Stage count is recommended, not settled: 3×5-beat answers open question 6 (docs/DISCOVERY.md:197) but should be validated by the P01 human playtest path (docs/project/BACKLOG.md:7).
- How far a pick-one-of-two reward may rewrite a class remains the interview question at docs/DISCOVERY.md:196 and docs/DISCOVERY.md:79.
