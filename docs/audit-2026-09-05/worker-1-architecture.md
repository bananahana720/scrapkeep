# Scrapkeep architecture audit

Session-scoped audit. All claims cite `file:line`, a command run in this session, or are explicitly labeled `[inference]`. Repo root: `/home/andrew/Projects/test-game-2`.

## 0. Environment note

`git status`/`git log` fail with "not a git repository" (checked this session: `git status` in the repo root returns exit 128, "fatal: not a git repository ... Stopping at filesystem boundary"). `ls /home/andrew/Projects/test-game-2/.git` returns an empty listing — the directory exists but is inert. This matches the project's own documentation: `CONTRIBUTING.md:62` ("This environment currently exposes an unusable read-only `.git` placeholder") and `docs/project/BACKLOG.md:8` (item T01, "no writable Git metadata"). No further git commands were attempted, per task instructions.

---

## 1. Module map

### Yard (`src/`)

| Concern | File:line | Shape |
| --- | --- | --- |
| Core simulation class | `src/game.js:241-903` (`class Game`) | Single class owning mode/time/wave/score/player/weapons/enemies/projectiles/pickups/events as plain-object arrays, all mutated in one `update(dt, input)` method. |
| Content tables | `src/game.js:35-78` `CLASSES`, `:79-118` `WEAPONS`, `:119-202` `UPGRADES` | Flat exported objects/arrays — data, but consumed via `if`/lookup-object dispatch, not polymorphic behavior. |
| Enemy/­wave data | `src/game.js:446-491` `spawnEnemy()`, inline literals e.g. `{bug:27,runner:18,tank:92,boss:460}` at `:462`, `:473`, `:477` | Per-type stat tables are inlined as anonymous object literals at each call site rather than a single table. |
| Path/geometry | `src/game.js:2-28` `PATH`, `WALLS` (`:29-34`) | Fixed-arena, single-map geometry; no per-stage or per-map abstraction. |
| Progression/meta | `src/campaign.js:1-257` | Pure functions: `HEROES`, `SECTORS`, `MODIFIERS` tables (`:2-82`), `createProfile`/`parseProfile`/`settleRun`/`masteryFor` (`:98-205`). Cleanest data-driven module in the yard. |
| Persistence | `src/progress-store.js:8-107` (`createProgressStore`) | Functional factory; per-run "receipts" merged into an aggregate profile to survive concurrent tabs/writes (tested in `tests/progress-store.test.js`). |
| Rendering | `src/world.js:31-614` (`class World`) | Three.js scene owner. `entityMaps`/`syncEntities` (`:72-76`, `:383-401`) is a generic id-keyed reconciler reused for pickups/enemies/weapons — the one place the yard already has a reusable abstraction. |
| Event bus | `src/game.js:364-371` `emit`/`drainEvents`; consumed at `src/world.js:305-368` `event(e)` | Simulation emits typed events, renderer/audio consume by string-switch. Decoupled, already event-driven. |
| Character art | `src/heroes.js:55-211` `createHeroModel(classId)` | One function, per-class geometry built via `if (id === "scavenger") ... else if (id === "engineer") ... else` branches (`:105-209`). Adding a class means editing this function's body. |
| UI orchestration | `src/main.js:1-681` | 680-line file: DOM template strings, input polling, HUD, wiring `Game`+`World`+`Collection`+`AudioEngine`. |
| Meta/lead-capture UI | `src/collection.js:25-320` (`class Collection`) | Mastery display, lead-capture form validation, and `fetch` calls to `/api/config`/`/api/leads` all in one class. |
| Server | `server/index.js` (routes, `createLeadServer` at `:102`), `server/store.js` (`openLeadStore` at `:6`), `server/validation.js:1-123` (`parseLead`, allowlist-based) | Simple Node HTTP server, JSON-file-backed lead store, defensive input validation. |

### Orchard (`src/orchard/`)

| Concern | File:line | Shape |
| --- | --- | --- |
| Core simulation class | `src/orchard/simulation.js:123-863` (`class OrchardGame`) | `reset/start/pause/resume/update/snapshot/drainEvents`. Fixed 120 Hz step via accumulator (`:50`, `:277-281`), distinct from the yard's 60 Hz loop (`src/game.js:625` clamp, `src/main.js:583-590`) — this divergence is intentional per ADR 0002 (`docs/adr/0002-simulation-boundary.md:9`). |
| Enemy content table | `src/orchard/simulation.js:8-48` `ENEMY_CONFIG` (frozen object keyed by kind: `snipcart`, `spreadleg`, `pruner`) | A real data table, better than the yard's inline literals — but behavior is still branched by `enemy.kind` string in `toolSegments()` (`:76-121`), `_transition()` text (`:366-374`), and `_updateEnemies()` reach/worker logic (`:405-423`). |
| Per-enemy state machine | `src/orchard/simulation.js:357-436` `_transition`, phase computation | Each enemy already carries `state` (idle/approach/windup/active/recovery/dead) and `phase` (0..1) — closer to a real state machine than the yard's enemies, which only have ad hoc `hit/slow/freeze/ram` timers (`src/game.js:718-724`). |
| Player/hero state | `src/orchard/simulation.js:132-150` (reset) | Single hardcoded hero; `shear`/`brace` are two ad hoc counters threaded directly into formulas (dash cooldown `:300`, ram damage `:612`, hurt damage `:734`) rather than a generic modifier list. |
| Companion | `src/orchard/simulation.js:797-831` `_updateCompanion` | One hardcoded companion type/behavior (`companion = {x,y,z,yaw,active,cooldown,flash}`), created at `:304-315`. |
| Committed-geometry contract | `src/orchard/simulation.js:76-121` `toolSegments`, `:21` hazard shape in `docs/FIRST-BUILD-CONTRACT.md` | Damage hitboxes and telegraph/preview geometry share one function — this is ADR 0003's explicit boundary (`docs/adr/0003-authoritative-attack-geometry.md`) and is a genuinely good pattern. |
| Models | `src/orchard/models.js:1-820` | `createHero`, `createEnemy(kind)` (factory map `:549-557`), `createPickup(kind)`, `createCompanion`, `createGreenhouse`. Uses a `consolidate()` geometry-merge pass (`:120-143`) to hit draw-call budgets named in `docs/FIRST-BUILD-CONTRACT.md:37`. More disciplined than the yard's `art.js`/`heroes.js`. |
| Rendering | `src/orchard/scene.js:68` `class OrchardScene` | Consumes `hazards[]`/`segments` from the simulation per ADR 0003; not fully read this session beyond exports. |
| UI orchestration | `src/orchard/main.js:1-699` | DOM templates, input (keyboard/mouse/touch/gamepad polling `:403-419`), HUD, event→toast/sound wiring (`:438-465`), inline synthesized-audio `sound()` (`:83-110`). |

---

## 2. Extensibility assessment

### Class kits (confirmed: 4 classes, distinct kits)

- **Today's shape:** Yard `CLASSES` (`src/game.js:35-78`) is a data table for stats (speed/magnet/damage/cooldown) but the *behavior* of each class's ability is a hardcoded `if (this.classId === "scavenger") ... if (this.classId === "engineer") ... if (this.classId === "warden")` chain in `ability()` (`:544-559`). Hero models branch the same way in `src/heroes.js:105-209`. World swaps the hero mesh via `if (this.heroClass !== game.classId)` (`src/world.js:438-444`).
- **What breaks:** The confirmed classes (grapple, hover/mortar, cyborg laser, lightning) are not "more turret classes" — they imply per-class movement/attack *verbs* (swing/pull, indirect-fire targeting, beam/redirect, chain/charge-through-conductors) that don't fit the current `ability()` shape of "one cooldown, one canned AoE effect." Every new class today means adding another `if` branch in at least 3 files (`game.js` ability, `heroes.js` model, `world.js` hero-swap), with no compiler/test guarantee all three were touched.
- **Seam:** `src/game.js:539-562` (`ability()`), `src/heroes.js:55` (`createHeroModel`), `src/orchard/simulation.js` has *no* class concept yet (single hardcoded hero, `reset()` at `:129-195`) — the orchard is a blanker but cleaner slate for this.

### Run items that modify attacks, devices, companions (confirmed: Isaac-style transformative items)

- **Today's shape:** Yard `UPGRADES` (`src/game.js:119-202`) are flat, permanent-for-the-run stat multipliers, applied via an id-keyed `if` chain in `chooseUpgrade()` (`:576-581`), and per-weapon-type bonuses are looked up inline in the projectile-damage formula: `{bolt:0.45,pipe:0.3,coil:0.25,cactus:0.35}[w.type]` (`:792`), and again for splash (`:823`) and chain (`:833`). Orchard's two items (`shear`, `brace`) are even more ad hoc: two counters on the player object, read directly inside `dash` cooldown math (`:300`), ram damage (`:612`), and hit-mitigation (`:734`).
- **What breaks:** None of this is a modifier/effect system. "Transformative" items that change an attack's *shape* (e.g., Brimstone-style beam instead of projectile) have nowhere to plug in — every consumer of damage/cooldown/targeting would need new bespoke branches, and there is no shared hook that a device or companion could also read (DISCOVERY.md's "shared items across weapons and structures" hypothesis, `docs/DISCOVERY.md:92-94`, has zero code support today).
- **Seam:** `src/game.js:789-796` (damage formula), `:576-589` (`chooseUpgrade`); `src/orchard/simulation.js:633-675` (`_shoot`), `:677-729` (`_damage`), `:731-749` (`_hurt`) — these are the insertion points for a generic modifier list.

### Companion assembly from loot (confirmed: assemble companions from run loot)

- **Today's shape:** Only the orchard has a companion, and it's a single hardcoded type: fixed shape `{x,y,z,yaw,active,cooldown,flash}` created at `src/orchard/simulation.js:304-315`, with one behavior (`_updateCompanion`, `:797-831`: follow player, auto-engage nearest enemy in range, prime). Model is one fixed mesh (`src/orchard/models.js:723-751` `createCompanion`).
- **What breaks:** Everything — there is no chassis/module concept, no companion registry, no loot table feeding it. "Assemble different companions from run loot" (confirmed direction, `docs/DISCOVERY.md:29`, `:123-125`) requires a genuinely new data structure (e.g., chassis + slotted modules, each module contributing a behavior hook), not an extension of the current single object.
- **Seam:** `src/orchard/simulation.js:797` (companion update entry point) and `src/orchard/models.js:723` (companion model factory) are the only existing anchors; everything else is new construction.

### Multi-stage runs carrying the build (confirmed: 30–45 min expeditions, exploration/combat/defense/branches/boss)

- **Today's shape:** Yard's `Game` already does one useful thing here: `upgradeRanks`/`buffs` (`src/game.js:317-323`, mutated at `:566-589`) persist across all 15 waves *within one continuous match* (`TOTAL_WAVES=15`, `src/campaign.js:1`) — i.e., "carrying a build across encounters" already works, just scoped to "waves in one arena," not "stages as separate scenes." Orchard has no wave/stage concept at all: `mode` is a flat `ready/playing/paused/won/lost` (`src/orchard/simulation.js:130`, `:226-242`), and `main.js`'s `start()`/`finish()` (`src/orchard/main.js:154-172`, `:467-483`) assume one arena is the entire run.
- **What breaks:** Neither runtime has an "expedition" concept above a single arena. Getting to themed multi-stage runs needs an outer state machine that instantiates/tears down arena instances and passes a serializable build envelope between them — this doesn't exist in either codebase.
- **Seam:** The wave loop inside `Game.update()` (`src/game.js:706-717`, clear/upgrade handling `:851-901`) is the closest existing analog and the shape to generalize from arena-internal to expedition-external.

### Between-run persistence and unlocks (confirmed: unlock classes/items/companion parts/challenges; rebuild power in-run)

- **Today's shape:** This is the most mature axis in the codebase. `src/campaign.js:98-146` (`createProfile`/`parseProfile`) defines a strict, allowlist-validated schema (`classes: {xp,runs,wins,bestScore,bestWave}`, `settled[]`, `blueprints[]`), and `src/progress-store.js:8-107` merges per-run "receipts" into that profile in a way that's race-safe across tabs/writes (tested: `tests/progress-store.test.js` — "stale tabs retain both run receipts...", "record never overwrites the aggregate...").
- **What breaks:** The schema only models per-class XP/mastery/blueprint-unlock. It has no fields for unlocked items, companion parts, or challenges. Orchard has no persistence at all — every session starts from `reset()` with no memory.
- **Seam:** `src/campaign.js:98-110` (`createProfile`'s schema) is exactly where new unlock categories would be added, reusing the same allowlist-validation style already proven at `:111-146`.

---

## 3. Top 5 architectural moves, ranked by leverage

1. **Class-kit registry (polymorphic behavior object, not just a stats table).**
   Domain structure: a registry of class descriptors, each supplying `{stats, ability(state), deploy(state), attack(state), heroModel}` — replacing string-keyed `if` dispatch with a lookup + method call.
   Current seam: `src/game.js:35-78` (`CLASSES`) + `:539-562` (`ability()` if-chain); `src/heroes.js:55-211`.
   Unlocks: adding grapple/mortar/laser/lightning without touching `Game.update()`'s core loop, and gives the (currently classless) orchard hero a home for the same interface.

2. **Item/modifier effect pipeline.**
   Domain structure: a list of typed modifier objects on player/game state, each with lifecycle hooks (`onFire`, `onHit`, `onKill`, `onPickup`, stat multipliers), consulted by weapon-fire/ability/companion code instead of id-keyed `if` chains.
   Current seam: `src/game.js:119-202` (`UPGRADES`) + `:576-589` (`chooseUpgrade`) + inline lookups at `:789-792, 813, 823, 833`; `src/orchard/simulation.js`'s `shear`/`brace` fields threaded through `:300, 329, 612, 734`.
   Unlocks: Isaac-style transformative items (R08), and — per the shared-item hypothesis in `docs/DISCOVERY.md:92-94` — the same hooks can later be reused by devices and companions.

3. **Data-driven enemy/entity registry + shared per-kind behavior descriptor.**
   Domain structure: one table per enemy kind holding not just numbers (already true for `ENEMY_CONFIG`, `src/orchard/simulation.js:8-48`) but references to its attack-geometry function and pose function, so adding a kind touches one new table row instead of three files.
   Current seam: kind-string branching duplicated across `src/orchard/simulation.js:76-121` (`toolSegments`), `:366-374` (`_transition` text), `:405-423` (`_updateEnemies` reach/worker logic), and `src/orchard/models.js:576-695` (`updateEnemy`).
   Unlocks: the enemy-family expansion already proposed in `docs/ENEMY-TAXONOMY.md` without the current three-file edit-in-lockstep risk.

4. **Expedition/stage state machine with a serializable carried-build envelope.**
   Domain structure: an outer state machine (menu → stage → reward → stage → boss → results) that owns a build snapshot (weapons/upgrades/companion/hp-scale) handed to each stage's arena instance on entry and re-captured on exit.
   Current seam: none exists as a wrapper; the closest analog is the wave loop inside `Game.update()` (`src/game.js:706-717, 851-901`), which is arena-internal only.
   Unlocks: confirmed 30–45 minute multi-stage expeditions (R11) and within-run power rebuilding (R12).

5. **Generalized unlock/progression schema, extending the existing profile store.**
   Domain structure: widen `createProfile`'s schema (`src/campaign.js:98-110`) to carry unlocked classes/items/companion-parts/challenges, reusing the allowlist-validation pattern already proven there and the race-safe receipt-merge in `src/progress-store.js:78-104`.
   Unlocks: between-run unlocks (R12) without re-solving the concurrent-localStorage-write problem that `progress-store.js` already solved and tested.

---

## 4. Yard-vs-orchard duplication and divergence

This split is a **documented, deliberate interim state**, not unowned drift: ADR 0001 (`docs/adr/0001-two-playable-entries.md`) explicitly keeps both entries live "to avoid an engine migration during the proof" and names a revisit trigger ("when the next approved production scope makes consolidation ... necessary"). `docs/project/REQUIREMENTS.md:11` (R05) and `AGENTS.md:6` reiterate "preserve both entries ... until consolidation is an explicit decision." The list below is what that consolidation would need to reconcile.

- **Two fixed-step loops, different rates.** Yard clamps and steps at 60 Hz inside `Game.update` (`src/game.js:625`, driven from `src/main.js:583-590`); orchard runs a 120 Hz accumulator (`src/orchard/simulation.js:50, 277-281`). ADR 0002 states this is intentional ("Its timing is not an orchard convention," `docs/adr/0002-simulation-boundary.md:9`) but a merged codebase would need one convention.
- **Two seeded RNGs, different constants.** `seededRandom` (`src/game.js:205-211`, LCG with constants `1664525/1013904223`) vs. `OrchardGame._random` (`src/orchard/simulation.js:751-754`, same LCG form but different usage pattern/state field name). Same concept, not shared.
- **Two procedural-model toolkits.** `src/heroes.js` + `src/art.js` (yard) vs. `src/orchard/models.js` (orchard). Orchard's is more disciplined: it has an explicit geometry-merge pass (`consolidate()`, `src/orchard/models.js:120-143`) targeting draw-call budgets named in `docs/FIRST-BUILD-CONTRACT.md:37` (hero <70, worker <35, arm <65, greenhouse <80 draw calls); the yard toolkit has no equivalent batching discipline. **Candidate to promote:** orchard's modeling pattern. **Candidate to retire:** yard's `heroes.js`/`art.js` once class kits are unified (move 1 above), rather than maintaining two rigs.
- **Two audio approaches.** `src/audio.js` (`class AudioEngine`, dedicated file) vs. an inline `sound()` function reimplementing raw Web Audio oscillators directly in `src/orchard/main.js:83-110`. Same synthesized-audio approach, duplicated rather than shared.
- **Two persistence states.** Yard has a full, tested profile/mastery system (`src/campaign.js`, `src/progress-store.js`); orchard has none. **Candidate to promote:** the yard's persistence layer is the piece worth carrying forward, not orchard's (currently absent) equivalent — see move 5.
- **Two QA-bridge installations, same shape.** `src/main.js:625-680` installs `window.__scrapkeep` + dynamically imports `tests/browser-runner.js`; `src/orchard/main.js:677-698` installs `window.__orchard` + imports `tests/orchard-browser-runner.js`. Structurally identical, copy-pasted rather than shared.
- **What the orchard demonstrates that the yard doesn't, worth promoting:** config-driven per-enemy state machines (`ENEMY_CONFIG` + `state`/`phase`, `src/orchard/simulation.js:8-48, 357-436`) vs. the yard's ad hoc per-enemy timers (`hit/slow/freeze/ram`, `src/game.js:718-724`) and inline stat literals (`:462, 473, 477`). The yard's turret/auto-fire combat model (`WEAPONS` table, fixed mount angles in `addWeapon`/`mount`, `src/game.js:79-118, 372-408`) is architecturally a tower-defense/auto-fire model, while the confirmed class fantasies (grapple, mortar, laser, lightning) and the orchard's aimed charge-release attack (`_shoot`, `src/orchard/simulation.js:633-675`) point toward a skill-shot model — `[inference]` the yard's weapon-mount system likely does not carry forward into the confirmed direction and is a retirement candidate, while its wave/persistence logic (campaign.js) is a promotion candidate.

---

## 5. Engine question

**Worth keeping (grounded in code observed this session):**
- The Three.js/Vite toolchain already produces two working, tested runtimes: 73/73 tests pass (`node --test tests/*.test.js`, run this session), and `npm run check:project` passes (39 Markdown files, 208 file links, run this session).
- `World` in `src/world.js:122-144` runs a real post-processing pipeline (EffectComposer + GTAO + UnrealBloom) and batches particles/projectiles/health bars via `InstancedMesh` (`:84-107`, `:489-593`) — this is a competent, hand-rolled renderer for particle-heavy 2.5D combat, not a toy.
- Orchard's `consolidate()` geometry-merge pass (`src/orchard/models.js:120-143`) against named draw-call budgets (`docs/FIRST-BUILD-CONTRACT.md:37`) shows real performance discipline already in the asset pipeline.
- The deterministic, DOM-free simulation classes (`Game`, `OrchardGame`) with seeded RNG are engine-agnostic by construction — this determinism (ADR 0002) is the most portable, highest-value part of the codebase regardless of what renders it.

**What pushes toward a production-engine migration:**
- The project's own discovery doc already names this as an open question, not something this audit is introducing: `docs/DISCOVERY.md:163-171` states "the engine decision for a larger native production remains open" and records that Godot was researched (via Context7) as a candidate specifically for "character movement, spring-arm camera collision, and scene import," "at the cost of porting existing systems."
- `[inference]` The confirmed scope (4 classes with distinct kits, loot-assembled companions, multi-stage runs, controller support) stresses parts of a hand-rolled engine that off-the-shelf engines solve directly: no animation/rig import pipeline exists — ADR 0004 explicitly scopes this out ("Revisit when an imported-asset increment is approved," `docs/adr/0004-procedural-prototype-assets.md:11`) — and all character/enemy geometry today is hand-authored procedural code (`heroes.js`, `art.js`, `orchard/models.js`), which does not obviously scale to "4 classes × several enemy families × companions × multi-stage environments."
- `[inference]` No physics engine is present; collision is hand-rolled capsule/AABB math in both runtimes (`src/game.js:663-687` wall collision, `src/orchard/simulation.js:61-70, 603-631` capsule distance/body contact). The publisher direction's central "Katamari-like ... chaotic collisions" appeal (`docs/DISCOVERY.md:15`) would likely need more physics investment than either runtime currently has, whether that investment happens in Three.js or after a migration.
- `[inference]` Gamepad/controller input is hand-polled per entry point (`src/orchard/main.js:403-419`; no equivalent yet in `src/main.js`) rather than provided by an engine input layer — workable at current scope, added maintenance burden as controls grow.
- Counter-consideration: migrating now would discard the deterministic-simulation/tested-checkpoint discipline (ADR 0002, ADR 0003, 73 passing tests) that is a genuine, rare strength of this codebase; `docs/DISCOVERY.md:201` itself frames the engine question as still open rather than decided, and a migration is a large, separately-scoped bet.

---

## 6. Risks and debt

- **No real version control.** `.git` is an inert placeholder (confirmed this session; see §0). Already flagged as `BACKLOG.md` item T01 ("high" priority). All work here is unrecoverable if the working tree is lost.
- **`Game.update()` is a single ~280-line method** (`src/game.js:623-902`) handling movement, wall collision, pickups, wave spawning, enemy AI, weapon targeting/firing, projectile physics, splash/chain damage, and wave-clear/upgrade-offer logic inline. Any of the Top-5 moves above will need to carve seams out of this method before it can be extended safely.
- **Per-class and per-weapon-type behavior is scattered.** Repeated `if (this.classId === "x")` / object-literal type lookups appear at `src/game.js:319, 462, 473, 477, 512, 521, 731, 792, 815, 823, 833` — no single place enumerates "everywhere a new class or weapon type must be registered," so it's easy to add a type and miss a site.
- **Enemy-kind branching is duplicated across three files in the orchard** (`src/orchard/simulation.js:76-121, 366-374, 405-423` and `src/orchard/models.js:576-695`), tied together only by the numeric `ENEMY_CONFIG` table — same lockstep-edit risk as above, one runtime earlier in its life.
- **`collection.js` mixes concerns:** mastery/profile display, lead-capture form validation, DOM templating, and `fetch` calls to `/api/config`/`/api/leads` all live in one 320-line class (`src/collection.js:25-320`). This is the only place unlock/profile UI renders today, so extending the profile schema (move 5) will need to extend this file too.
- **No physics/asset-import pipeline** (see §5) — procedural-only art authoring (ADR 0004) is a known, accepted limitation for the current proof scope, not yet a defect, but doesn't scale past a couple of archetypes without much more hand-written code per character.
- **No stage/expedition concept anywhere** — both runtimes assume "one arena = one run." This is a structural gap for R11/R12, not a small task.
- **Test coverage, checked this session** (`node --test tests/*.test.js`): 73/73 pass, covering `game.test.js` (14 tests), `orchard.test.js` (24 tests), `campaign.test.js` (10), `progress-store.test.js` (6), `leads.test.js` (13), `orchard-renderer.test.js` (2), `tooling.test.js` (2), and the two lead-browser startup tests. `npm run check:project` also passes (39 Markdown files, 208 links).
  - **Coverage gaps relative to the confirmed direction** (expected, not defects, since the systems don't exist yet): no tests for any class beyond the current 3 turret-classes; no tests for an item/modifier system beyond the flat `UPGRADES` list; no tests for companion assembly beyond the single hardcoded orchard companion (`tests/orchard.test.js:336` "optional companion requires collected shear..."); no tests for multi-stage/expedition continuity beyond within-single-arena wave progression (`tests/campaign.test.js:26`, `tests/game.test.js:75`); no tests for unlock categories beyond XP/mastery/blueprint. Each of the Top-5 moves will be greenfield-tested rather than retrofitted, which should be planned for.
- **Backlog already names adjacent risks** worth cross-referencing: `docs/project/BACKLOG.md` P02 ("Precise input cleared all enemies in about 37 seconds without damage" — ranged pacing), P04 ("Scope the next class/item/deployment increment" — explicitly unscoped decision), T02 (QA bridge packaging before release), T04 (asset/licensing review before external release).

---

## Files read this session (for reference)

`src/game.js`, `src/world.js`, `src/campaign.js`, `src/progress-store.js`, `src/collection.js`, `src/heroes.js`, `src/main.js`, `src/orchard/simulation.js`, `src/orchard/models.js`, `src/orchard/main.js`, `server/validation.js`, `scripts/verify.mjs`, `package.json`, `docs/DISCOVERY.md`, `docs/adr/0001-0004`, `docs/project/REQUIREMENTS.md`, `docs/project/BACKLOG.md`, `CONTRIBUTING.md`, `AGENTS.md`, `docs/FIRST-BUILD-CONTRACT.md`, `docs/decisions.tsv` (tail), plus `grep`/`wc -l` passes over `src/art.js`, `src/audio.js`, `src/orchard/scene.js`, `server/index.js`, `server/store.js`, and test-name enumeration over `tests/*.test.js`.

**Not fully read** (time-boxed): `src/art.js` (883 lines, grepped only), `src/orchard/scene.js` (753 lines, exports grepped only), `server/index.js` full route bodies, `docs/FIRST-BUILD-PLAYGUIDE.md`, `docs/FIRST-BUILD-SWARM.md`, `docs/FIRST-BUILD-VERIFICATION.md`, enemy-taxonomy and combat-design docs beyond what DISCOVERY.md summarizes.
