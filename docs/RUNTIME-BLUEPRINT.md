# Runtime blueprint

5 September 2026. This document is the application-runtime blueprint that carries the expedition game on the current Three.js/Vite stack, sized so each piece can be scoped as an increment, with a disciplined engine decision gate at the end.

Everything below marked proposal awaits Andrew's approval. Designs that assume the Requisition premise, the five-rung campaign, three-stage expeditions, mass-as-currency, or the Scrapbook inherit their pending status from the 5 September audit (docs/DESIGN-AUDIT.md:3). The orchard runtime is the base to grow and the yard contributes its persistence layer; that reading follows the architecture audit (docs/DESIGN-AUDIT.md:74) and this blueprint builds on it.

## 1. Target module layout (proposal)

Text diagram. Every module names what it owns and the existing file that seeds it. Modules under `sim/` stay DOM-free and deterministic per ADR 0002 (docs/adr/0002-simulation-boundary.md:7).

```
src/
  app/
    boot.js          app shell, entry wiring, mode routing        seed: src/orchard/main.js:51-60 (canvas + game + scene wiring)
    expedition.js    the outer expedition state machine (sec 2)   seed: none; closest analog is the yard wave loop (src/game.js per audit worker-1:70)
    hud.js           DOM HUD, overlays, toasts                    seed: src/orchard/main.js:484-621 (updateHUD), :188-230 (overlay/guide)
    input.js         device-agnostic intent frames (sec 8)        seed: src/orchard/main.js:386-437 (controls)
    audio.js         one synthesized-audio engine (sec 9)         seed: src/audio.js:1 (class AudioEngine)
  sim/
    stage.js         one stage's deterministic sim: player,       seed: src/orchard/simulation.js:123-863 (class OrchardGame)
                     enemies, hazards, pickups, events
    combat.js        damage, counters, deflect resolution         seed: src/orchard/simulation.js:677-749 (_damage, _hurt)
    geometry.js      capsule math, committed tool geometry        seed: src/orchard/simulation.js:61-70, :76-121 (ADR 0003 boundary)
    envelope.js      carried-build envelope: create, validate,    seed: src/campaign.js:98-146 (allowlist pattern)
                     serialize (sec 2)
  registry/
    classes.js       class-kit descriptors (sec 3.1)              seed: src/game.js:35-78 (CLASSES table, per audit worker-1:50)
    enemies.js       enemy descriptors, admission grammar (3.2)   seed: src/orchard/simulation.js:8-48 (ENEMY_CONFIG)
    items.js         item/modifier descriptors (sec 3.3)          seed: src/orchard/simulation.js:774-781 (shear/brace effects)
    companions.js    chassis + module descriptors                 seed: src/orchard/simulation.js:304-315, :797-831 (single companion)
    stages.js        stage descriptors: a route of pocket         seed: src/orchard/scene.js:154-294 (buildEnvironment constants)
                     records, seed-indexed (sec 3.4)
  meta/
    campaign.js      pure progression functions, schema v2        seed: src/campaign.js:98-205
    progress-store.js race-safe receipt store, unchanged API      seed: src/progress-store.js:8-107
    scrapbook.js     entry admission, ledger, tab queries         seed: none; schema in sec 4
  present/
    presenter.js     renderer, camera rig, particles, effects     seed: src/orchard/scene.js:68-153 (constructor), :373-423
    stage-view.js    per-stage environment build/teardown         seed: src/orchard/scene.js:154-294, :734-746 (clear)
    models/          per-family model factories + pose functions  seed: src/orchard/models.js:120-143 (consolidate), :554-556 (factory map)
    hazards.js       committed-geometry rendering                 seed: src/orchard/scene.js:492-663
  qa/
    bridge.js        one QA bridge, sim-driving harness (sec 10)  seed: src/main.js:625-679, src/orchard/main.js:677-699
```

The yard entry (`src/game.js`, `src/world.js`, `src/heroes.js`, `src/art.js`) stays live per ADR 0001 until consolidation is an explicit decision (docs/adr/0001-two-playable-entries.md). Its turret weapon tables do not carry into this layout; its `campaign.js` and `progress-store.js` do (docs/DESIGN-AUDIT.md:74). Vite keeps multi-entry builds; today it names `main` and `orchard` inputs (vite.config.js:17-24) and a third `expedition` input slots in the same way.

## 2. Expedition state machine (proposal)

The orchard's flat mode field is `ready/playing/paused/won/lost` set inline (src/orchard/simulation.js:130, :226-242, :724, :745-746). One arena is the whole run (src/orchard/main.js:154-172, :467-483). The expedition machine wraps stage sims; it never reaches inside one.

States: `HANGAR`, `BRIEFING`, `STAGE_LOADING`, `STAGE_ACTIVE`, `INTERSTITIAL`, `DEBRIEF`.

| From | Event | To | Effect |
| --- | --- | --- | --- |
| HANGAR | launch(classId, routeId, seed) | BRIEFING | create envelope v2, persist it |
| BRIEFING | confirm | STAGE_LOADING | build stage sim + view from stage descriptor |
| STAGE_LOADING | loaded | STAGE_ACTIVE | start stage sim |
| STAGE_ACTIVE | stage won, stages remain | INTERSTITIAL | capture sim deltas into envelope, persist; offer pick-one-of-two |
| STAGE_ACTIVE | stage won, final stage | DEBRIEF | capture deltas, settle run receipt as victory |
| STAGE_ACTIVE | player dead | DEBRIEF | settle receipt as gameover; Scrapbook entries observed so far still merge |
| STAGE_ACTIVE | abandon (quit confirm) | DEBRIEF | settle receipt as abandoned |
| INTERSTITIAL | reward chosen | STAGE_LOADING | append ledger row, preload next stage |
| DEBRIEF | done | HANGAR | envelope discarded; profile updated via progress store |

Pause is a stage-sim concern (src/orchard/simulation.js:231-237), not an expedition state. A tab closed mid-run leaves the last persisted envelope; on next boot HANGAR offers resume from the last interstitial or settle as abandoned. Contested choice: resume versus always-abandon. Recommendation: resume from the last interstitial only, never mid-stage, because interstitials are the only points where the envelope is complete and the sim seed can restart a stage cleanly.

### Carried-build envelope, concrete sketch

Plain JSON, validated by the allowlist style proven in parseProfile (src/campaign.js:111-146). Field types in prose.

```js
{
  version: 2,                    // integer
  expeditionId: "run-...",       // string, same charset rule as run ids (src/campaign.js:171)
  seed: 0,                       // uint32, one seed; stage sims derive sub-seeds by index
  classId: "grapple",            // string, key into the class registry
  routeId: "spillway-standard",  // string, key into the stage registry
  stageIndex: 0,                 // integer, 0..route.length-1
  pilot: {                       // numbers, captured at each interstitial
    hp: 74, maxHp: 100, scrap: 23, mass: 0.4   // mass is the growth fraction m from the combat proposal (docs/DESIGN-AUDIT.md:54)
  },
  items: [ { id: "shear-linkage", stacks: 2 } ],           // array of {string, integer}
  companion: { chassisId: "roller", moduleIds: ["shear"] } // or null
  ledger: [                      // pick-one-of-two record, one row per offer
    { offered: ["item-a", "item-b"], took: "item-a", stage: 0 }
  ],
  scrapbookSeen: [ "enemy.sluiceback", "counter.pruner" ], // entry ids observed this run, merged into the profile at settle
  seenNotTaken: [                // ids seen but not collected, from any source
    { id: "item-b", source: "offer" },                       // interstitial pick-one-of-two (docs/DESIGN-AUDIT.md:44)
    { id: "companion.chassis-roller", source: "sighting" },  // branch-mouth sighting (LEVEL-DESIGN.md:124)
    { id: "item.override-bolt", source: "declinedDrop" }     // declined veteran field drop (ENEMY-ROSTER.md:208)
  ],
  stageEffects: [                // expedition-persistent world effects, persisted at interstitials with the rest of the envelope
    { id: "trellis-row-3", scope: "expedition" }             // trellis pins hold gate rows open for the rest of the expedition (LEVEL-DESIGN.md:257)
  ],
  stats: { shots: 0, hits: 0, counters: 0, collected: 0, damageTaken: 0, damageDealt: 0 }  // same shape as the sim stats (src/orchard/simulation.js:179-186)
}
```

What the Scrapbook and ledger need persisted: during a run, `scrapbookSeen` (ids), `seenNotTaken`, `ledger` rows, and `stageEffects` live in the envelope. At DEBRIEF the Scrapbook fields merge into the profile through the run receipt so the race-safe store keeps its single write path (src/progress-store.js:78-104); `stageEffects` dies with the expedition. The seen-not-taken ledger (docs/DESIGN-AUDIT.md:44) is wider than the offer rows: branch-mouth sightings register entries (LEVEL-DESIGN.md:124) and declined Override Bolt field drops feed it (ENEMY-ROSTER.md:208), so `seenNotTaken` carries those ids with their source. Offer-sourced rows still derive from `offered` minus `took`.

## 3. Registry interfaces (proposal)

All registries are frozen data-plus-functions tables consulted by the sim, replacing string-keyed branches. One registration means one new file touch.

### 3.1 Class kits

Hooks and where today's code already fires each one:

- `stats` (topSpeed, accel, dashCooldownBase): consumed where the servo reads constants 7.4 and 25 (src/orchard/simulation.js:323, :329) and the dash formula (src/orchard/simulation.js:300).
- `chargeAttack(state, charge, aim)`: fires where `_shoot` runs on release (src/orchard/simulation.js:316, :633) with charge accrued at src/orchard/simulation.js:319. This is the aimed-skill-shot hook.
- `onDash(state)`: fires at the dash trigger (src/orchard/simulation.js:291-303).
- `deploy(state)`: fires at the deploy trigger (src/orchard/simulation.js:304-315). Quick deployment while moving; no build screen, per pillar.
- `heroModel()` / `heroPose(group, player, dt, time)`: consumed where the scene creates and updates the hero (src/orchard/scene.js:118-119, :425).

Worked registration:

```js
registerClass({
  id: "grapple",
  stats: { topSpeed: 7.4, accel: 25, dashCooldownBase: 1.45 },
  chargeAttack(sim, charge, aim) {          // skill shot: hook line, then reel
    const hit = sim.raycastEnemies(aim, 24 + 10 * charge);
    if (hit) sim.pullToward(hit, 14);       // movement verb lives in the kit, not in _step
  },
  onDash(sim) { /* default burst */ },
  deploy(sim) { sim.placeAnchor(sim.player); },   // thrown anchor, placed while rolling
  heroModel: createGrappleHero,
  heroPose: poseGrappleHero,
});
```

### 3.2 Enemy descriptors

The descriptor carries the numeric config, an `attacks[]` array, the two functions and the copy that are branched by kind today, and the seven admission-grammar fields as data. Per-attack fields follow the enemies lane's registry field list (ENEMY-ROSTER.md:238), because every attack carries exactly one deflect grade and one body can carry several attacks (ENEMY-ROSTER.md:7, :67). Call sites the registry replaces:

- Numeric lookup `ENEMY_CONFIG[enemy.kind]` (src/orchard/simulation.js:387).
- Tool geometry branches in `toolSegments` (src/orchard/simulation.js:88-118).
- Telegraph copy branches in `_transition` (src/orchard/simulation.js:366-374).
- Reach/worker-gating branches in `_updateEnemies` (src/orchard/simulation.js:405-423).
- Model factory map and pose branches (src/orchard/models.js:554-556; updateEnemy branches at src/orchard/models.js:576-695 per docs/audit-2026-09-05/worker-1-architecture.md:94).
- HUD label strings (src/orchard/main.js:563-567, :598, :618).

Worked registration (the basin experiment enemy the audit asks for, docs/DESIGN-AUDIT.md:85). Behavior, stats, and grades follow the enemies lane's roster row, which is authoritative for enemy design (ENEMY-ROSTER.md:67):

```js
registerEnemy({
  id: "sluiceback",
  tier: "miniboss",
  config: { hp: 380, radius: 1.5, wake: 13, speed: 1.6, spacing: 3.2 },   // hp per the roster (ENEMY-ROSTER.md:67); radius/wake/speed/spacing are placeholders pending the enemies lane
  grammar: {                                  // the seven-field admission table, enforced as data
    telegraph: "brace plant; a second charge only after a separate visible preparation",
    commitment: "braced charge across the banked basin, lane locked at the plant",
    lockedGeometry: "one straight charge capsule across the basin",
    recovery: "skid at the end of the charge, 2.6 s",
    weakPoint: "plating; removed plates stay removed",
    counterReward: "scrap + Valve Wheel",
    contestedResource: "the basin lanes",     // placeholder; the roster row names none (ENEMY-ROSTER.md:67)
  },
  attacks: [   // one grade per attack (ENEMY-ROSTER.md:7); grades deflectable | heavy | grab (docs/DESIGN-AUDIT.md:53); fields per the registry list (ENEMY-ROSTER.md:238)
    { name: "braced charge", grade: "heavy", geometry: { /* charge capsule */ },
      damage: 26, windup: 1.7, active: null, recovery: 2.6 },   // active s unspecced in the roster row
    { name: "brace plant", grade: "deflectable", geometry: { /* plant stroke */ },
      damage: 14, windup: null, active: null, recovery: null }, // timings unspecced in the roster row
  ],
  toolSegments(enemy, attack, phase, preparing) { /* returns capsules, same contract as src/orchard/simulation.js:76 */ },
  copy: { windup: "Charge incoming", recovery: "Skid exposed", label: "SLUICEBACK" },
  model: createSluiceback,
  pose: poseSluiceback,
});
```

ADR 0003 survives intact: the descriptor's `toolSegments` stays the single authoritative geometry both collision and rendering read (docs/adr/0003-authoritative-attack-geometry.md). It now resolves per attack: the sim passes the committed `attacks[]` entry, and `toolSegments` returns that attack's capsules.

### 3.3 Item/modifier pipeline

A modifier list on the player, consulted at named hooks, replacing the shear/brace counters threaded into formulas. Hook names and today's call sites:

- `statMods` (accel, dashCooldown, topSpeed, mass): dash cooldown reads brace at src/orchard/simulation.js:300; accel reads brace at src/orchard/simulation.js:329.
- `onRam(sim, enemy, damage) -> damage`: ram damage reads shear at src/orchard/simulation.js:612.
- `onShoot(sim, shot) -> shot`: shot damage formula at src/orchard/simulation.js:673. Transformative items rewrite `shot.kind` here (beam, arc, chain) instead of adding branches.
- `onHurt(sim, amount) -> amount`: mitigation reads brace at src/orchard/simulation.js:734.
- `onPickup(sim, pickup)`: pickup effects branch by kind at src/orchard/simulation.js:774-781.
- `onKill(sim, enemy)`: death handling at src/orchard/simulation.js:702-728.

Worked registration (today's brace, expressed in the pipeline):

```js
registerItem({
  id: "adjustable-brace",
  stacks: true, max: 3,
  statMods: (s) => ({ dashCooldown: -0.22 * s, accel: 4 * s }),   // the formulas at simulation.js:300 and :329
  onHurt: (sim, amount, s) => amount * (1 - Math.min(0.3, s * 0.15)),  // simulation.js:734
});
```

The same hook set is what companion modules and deployed devices consume, which is the shared-item direction the discovery record hypothesizes (docs/audit-2026-09-05/worker-1-architecture.md:57).

### 3.4 Stage descriptors

The levels lane owns the spatial grammar; the stage descriptor applies its Model C shape. A stage descriptor is a route: an ordered list of pocket records, each carrying id, type, footprint, mouths, enemy admission list, wake exclusion zones, and vertical profile (LEVEL-DESIGN.md:104-118). Each mouth carries a lane id, consumed by the per-lane windup gate (sec 6), and its anchor sockets, at least one per class per lane on defense rings (LEVEL-DESIGN.md:144-151). The layout seed indexes typed slots into the biome's pocket library per the Model C seed mapping, so the same seed reproduces the same arrangement through the existing LCG (LEVEL-DESIGN.md:118; src/orchard/simulation.js:751-754).

## 4. Save schema v2 (proposal)

Extends the createProfile allowlist pattern (src/campaign.js:98-110) and keeps parseProfile's stance: unknown fields dropped, invalid entries dropped individually, always return a valid profile (src/campaign.js:111-146).

```js
{
  version: 2,
  classes: { [classId]: { xp: 0, runs: 0, wins: 0, bestScore: 0, bestStage: 0 } },
  unlocks: { classes: [], items: [], companionParts: [], challenges: [] },  // string id arrays, same charset rule as settled ids (src/campaign.js:132-135)
  scrapbook: { [entryId]: { runs: 1, checks: ["counter-on-drain"], epithet: "Nibbles" } },
      // observed-only entries, five tabs derive from id prefixes (docs/DESIGN-AUDIT.md:60);
      // checks holds behavior ids, each filled only when the player performs the counter (CHARACTER-BIBLE.md:194);
      // epithet exists on companion-prefix entries only, appended after a logged deed (CHARACTER-BIBLE.md:153)
  ledger: [ { offered: ["a","b"], took: "a", expeditionId: "run-..." } ],
  settled: [],                              // unchanged, powers the receipt store (src/progress-store.js:70)
}
```

No field in v2 raises a permanent combat stat; unlocks are content admission only, per the bounded-growth pillar. Migration rule from v1: parseProfile v2 accepts `version === 1` input, maps each class's `xp/runs/wins/bestScore` across, maps `bestWave` to `bestStage` capped as before (src/campaign.js:123), carries `settled` so existing receipts never double-settle, initializes the new fields empty, and writes `version: 2`. The strict reject at src/campaign.js:115 (`data.version !== 1` returns fresh) becomes a two-arm switch; anything else still returns a fresh profile. `createProgressStore` keeps its API; only its aggregate-shape check (src/progress-store.js:44-49) learns the second version.

## 5. Scene and asset lifecycle (proposal)

Today OrchardScene builds its environment once in the constructor (src/orchard/scene.js:117, :154-294) and `clear()` resets only dynamic state (src/orchard/scene.js:734-746). Stage-based play splits that:

- `Presenter` (persistent): renderer, camera rig, particle InstancedMesh pool (src/orchard/scene.js:142-150), effect materials (src/orchard/scene.js:128-140). Created once per session.
- `StageView` (per stage): environment group, blockers, instanced vegetation, signs; built from a stage descriptor; on teardown, traverse and dispose geometries and materials exactly as hazard removal already does (src/orchard/scene.js:654-662), then drop the group.
- Model pools: pickups are pooled already (src/orchard/scene.js:747-752); extend the pool to enemy models keyed by kind so repeated families across stages reuse meshes.

Loading inside the interstitial beat: all environments are procedural (ADR 0004), so a stage build is main-thread geometry work. Budget the build at 200 ms; if a descriptor exceeds it, build in slices across interstitial frames. Start the next StageView build when the reward choice appears, not after it is taken. No network fetches exist to hide.

Draw-call budgets, extended from the first-build contract numbers (hero <70, worker <35, arm <65, greenhouse <80, docs/FIRST-BUILD-CONTRACT.md:37):

| Bucket | Budget | Basis |
| --- | --- | --- |
| Stage environment (batched + instanced) | <150 calls | orchard env uses batch() and InstancedMesh today (src/orchard/scene.js:38-59, :250-273) |
| Live enemies (5 to 8 on field) | <350 calls | worker <35 and arm/boss <65-90 per model |
| Hero + companion + pickups + hazards + effects | <150 calls | pooled and instanced |
| Whole frame, desktop reference | <700 calls | yard stress measured 784 calls at 60 fps median 16.7 ms on an RTX 4080 (artifacts/performance-stress-final.json) |
| Whole frame, low tier (`?low` path) | <350 calls | low path already halves pixel ratio and shadow size (src/orchard/scene.js:76-78, :102) |

Memory plan: shared geometry and material dictionaries per family (the models module already shares G and M tables, src/orchard/models.js:11-46); dispose per-stage merges on teardown; the 16 MB-class concern of asset streaming does not exist while ADR 0004 holds, and the budget table is re-baselined at the imported-asset increment.

## 6. Physics plan for mass and deflect

What the hand-rolled math already covers, all on the ground plane:

- Point-to-capsule distance for strokes (src/orchard/simulation.js:61-70) and swept-capsule offcuts that prevent tunneling (src/orchard/simulation.js:556-583).
- Circle-versus-circle body contact with push-out and velocity projection (src/orchard/simulation.js:603-631).
- Arena AABB clamps (src/orchard/simulation.js:346-355) and a height field via groundHeight (src/orchard/simulation.js:57-59).
- Committed tool capsules shared with rendering (src/orchard/simulation.js:76-121, ADR 0003).

What mass-in-handling actually requires: a mass scalar derived from collected parts (the inputs already exist at src/orchard/simulation.js:774-781), mass terms in the accel/top-speed/dash formulas (src/orchard/simulation.js:300, :323-333), a deflect check comparing player speed against a threshold during the existing active-stroke overlap test (src/orchard/simulation.js:494-505), and a knockback impulse on deflect. Every one is a formula change inside the existing servo and overlap code; the audit's proposed numbers are exactly such terms (docs/DESIGN-AUDIT.md:54). Enemy knock-around from heavy rams, if adopted later, is one more push-out with an impulse, still circle math.

Does a physics library earn its place now: no. The mechanics are kinematic 2D-plane capsule tests the sim already implements deterministically with a seeded LCG (src/orchard/simulation.js:751-754). A rigid-body engine would add solver nondeterminism risk across platforms and an integration surface, and buys nothing the deflect needs. [inference] WASM-based engines such as Rapier would also complicate the DOM-free Node test path; not verified against current docs this session. Recommendation: keep the hand-rolled capsule math through the mass experiment and the expedition increments; open a physics-library question only if a design lands that needs stacked dynamic debris, ragdolls, or vertical physics.

Two further increments the levels lane flags as load-bearing, adopted here as named work items:

- Per-lane windup gates. The one-windup rule serializes worker strokes globally today (src/orchard/simulation.js:406-413). The single stagger gate becomes a map keyed by lane id, one gate per mouth, seam included (LEVEL-DESIGN.md:161). Acceptance test from the levels lane: two lanes in the stage-1 defense arena each hold an active windup at the same time, and neither suppresses the other (LEVEL-DESIGN.md:161).
- Pocket-resolved groundHeight. groundHeight samples z only today (src/orchard/simulation.js:57-59). The call keeps its groundHeight(x, z) signature and resolves per pocket, through a local height sample in the pocket record or a heightmap keyed by pocket id (LEVEL-DESIGN.md:300). Acceptance test from the levels lane: each of stage 1's five pockets reports correct height at its own ramp band, with no cross-pocket bleed (LEVEL-DESIGN.md:300).

## 7. Input consolidation (proposal)

Gamepad polling is duplicated inside the orchard entry: once in `controls()` for play (src/orchard/main.js:403-419) and once in `frame()` for menus (src/orchard/main.js:631-644), both writing the shared `padPrevious` edge state (src/orchard/main.js:385, :418, :643). The yard entry has no gamepad path at all (checked this session: `grep -n getGamepads src/*.js src/orchard/*.js` matches only the two orchard lines).

Plan: one `app/input.js` module that polls keyboard, pointer, touch, and gamepad once per frame and emits an intent frame `{ move, aim, fire, dash, deploy, brake, pause, confirm }`. The sim keeps its own edge handling (src/orchard/simulation.js:268-275), so the module only normalizes devices. Menus and play consume the same frame; the duplicated menu poll disappears. The touch stick and buttons (src/orchard/main.js:348-384) move in unchanged.

## 8. Audio consolidation (proposal)

Two implementations exist: the yard's `AudioEngine` class (src/audio.js:1, consumed at src/main.js:11, :452, :595) and the orchard's inline `sound()` oscillator function (src/orchard/main.js:83-110). Same synthesis approach, duplicated (docs/audit-2026-09-05/worker-1-architecture.md:115).

Plan: promote `AudioEngine` to `app/audio.js` as the single engine and express the orchard's per-event settings table (src/orchard/main.js:87-96) as a preset map passed at construction. Each entry keeps its own preset map; event names stay the routing key as both entries already do (src/main.js:452; src/orchard/main.js:441). Estimated as a half-day move with no sim contact.

## 9. Test and QA strategy (proposal)

### Fixtures

Node fixtures stay the base layer per ADR 0002: deterministic sims driven step by step without a browser (docs/adr/0002-simulation-boundary.md:7; today's suite is tests/orchard.test.js and peers, 73/73 passing per docs/DESIGN-AUDIT.md:7). ADR 0003 model checks continue verifying geometry and pose together (tests/orchard-models.mjs, docs/adr/0003-authoritative-attack-geometry.md). Extensions for expeditions:

- Envelope fixtures: run the expedition machine headless through scripted stage outcomes; assert the envelope validates, persists, and round-trips at every interstitial, and that DEBRIEF produces exactly one receipt.
- Registry conformance fixtures: for every registered enemy, assert the seven grammar fields are present, `toolSegments` returns capsules for all phases, and windup preview sampling matches the active stroke, generalizing the existing per-kind tests.
- Balance scripts stay artifact-writers, not tests, following tests/expedition-balance.mjs and the verify stage list (scripts/verify.mjs:12-19).

### QA bridge v2

Both entries install copy-pasted bridges (src/main.js:625-679; src/orchard/main.js:677-699). The audit probe had to drive `game.update` by hand at its own 120 Hz because the page loop is rAF-driven and its helpers wait on wall-clock time (src/orchard/main.js:646-657; tests/orchard-browser-runner.js:22-35; docs/DESIGN-AUDIT.md:8). Make that bypass a first-class harness:

- One shared `qa/bridge.js` exposing `drive(seconds, script)`: steps the sim at the fixed 120 Hz STEP (src/orchard/simulation.js:50) with scripted intent frames, decoupled from rAF, then calls one presentation sync so captures reflect the driven state (the runner already syncs views manually at tests/orchard-browser-runner.js:193).
- `snapshot()` and `performance()` keep their shapes (src/orchard/main.js:683-691).
- Gate the bridge behind `import.meta.env.DEV` in both entries. The yard already does (src/main.js:674-679); the orchard installs on `?qa` alone (src/orchard/main.js:677), which is the substance of BACKLOG T02 (docs/project/BACKLOG.md:11).

### Performance measurement closing T03

T03 wants a sustained baseline with named hardware and budgets (docs/project/BACKLOG.md:12). Gap observed this session: the orchard `performance()` reports mean fps and instantaneous draw calls only (src/orchard/main.js:684-691), while the yard reports median and p95 frame and render times (src/main.js:632-651). Plan:

- Port the yard's percentile sampling into the shared bridge.
- Scripted 60-second stress via `drive()` on the heaviest stage descriptor: full enemy roster awake, max hazards, max pickups.
- Named budgets to adopt: median frame <= 16.7 ms and p95 <= 25 ms on the named mid-tier machine; render median <= 8 ms; draw calls within the section 5 table; sim step mean <= 1.5 ms so four catch-up steps fit one frame.
- Save the artifact next to artifacts/performance-stress-final.json with the hardware string the way that file records it, on hardware Andrew names (the existing sample is an RTX 4080, which is not a mid-tier baseline).

## 10. Engine decision gate (proposal)

The engine question is open in the discovery record, not new here (docs/audit-2026-09-05/worker-1-architecture.md:131).

Measurable criteria that would trigger a Godot migration review. Any one suffices:

1. An approved increment requires imported rigged characters or animation clips, the exact ADR 0004 revisit trigger (docs/adr/0004-procedural-prototype-assets.md:11). Godot imports glTF 2.0 `.glb` scenes with animations natively (Context7 /websites/godotengine_en_4_7, gltfstate and first_3d_game import pages).
2. The named mid-tier machine misses the section 9 p95 budget after two optimization passes that already applied batching and instancing.
3. An approved design needs real rigid-body dynamics (stacked debris, ragdoll, vertical physics). Godot ships the Jolt physics engine built in, default for new projects (Context7 /websites/godotengine_en_4_7, using_jolt_physics and upgrading_to_godot_4.6 pages), where Three.js has no physics at all and this codebase hand-rolls its collision (section 6).
4. A console or native-distribution decision lands.

What ports cheaply versus what rewrites:

| Subsystem | Port cost | Why |
| --- | --- | --- |
| Deterministic stage sim | medium | DOM-free by construction (ADR 0002) but a language rewrite; the fixture suite is the spec and the LCG (src/orchard/simulation.js:751-754) reproduces exactly |
| Registries and data tables | small | plain data; grammar tables and configs copy across |
| campaign.js / schema v2 | small | pure functions (src/campaign.js), storage backend swaps behind the same API |
| Balance and envelope fixtures | small-medium | rerun against the ported sim as acceptance |
| Scenes and environments | large | rewrite; 753 lines of Three.js scene code (src/orchard/scene.js) becomes editor scenes |
| Procedural models | large, but intentionally discarded | 819 lines (src/orchard/models.js) plus yard rigs; the migration trigger is wanting authored assets, so this is replacement, not porting. Godot's built-in CharacterBody3D `move_and_slide` also replaces the hand camera/character glue (Context7 /websites/godotengine_en_4_7, characterbody3d class page) |
| DOM HUD, input, audio | medium | rebuilt in engine UI; the intent-frame input module (section 7) is the porting seam |
| QA browser bridge | medium | rebuilt on the engine's own headless/CI story |

Contested choice: decide the engine now versus at the gate. Deciding now would discard working, tested runtimes to chase asset-pipeline needs no approved increment has yet, and the audit's increments 1 to 4 (docs/DESIGN-AUDIT.md:84-88) touch sim, data, and persistence, which are the cheap-to-port layers anyway. Deferring costs little because every increment in this blueprint deepens the portable layers, not the Three.js-bound ones. Recommendation: stay on Three.js through the four audit increments, and run this gate as a one-session review when the first imported-asset increment is scoped, with criteria 1 to 4 evaluated in writing.

## Evidence limits

- All code claims come from files read or grepped this session in /home/andrew/Projects/test-game-2; line numbers cite the working tree of 5 September 2026, which has no usable git history (docs/project/BACKLOG.md:8, T01).
- src/game.js, src/world.js, src/heroes.js, and src/collection.js were not re-read this session; claims about them cite docs/audit-2026-09-05/worker-1-architecture.md with its own line cites. src/orchard/models.js was read to line 200 plus targeted greps.
- Godot capability claims cite Context7 library /websites/godotengine_en_4_7 (resolved this session via `npx ctx7@latest library "Godot"`; three queries total). No Three.js docs were fetched; Three.js claims rest on code observed in this repository, and the one Rapier/WASM remark is labeled inference.
- The performance numbers quoted are one machine's yard stress sample (artifacts/performance-stress-final.json); no new measurement ran this session, and every budget in sections 5 and 9 is a proposal pending T03's named-hardware baseline.
- No design here was played or profiled. Envelope, registry, and schema sketches are shapes for scoping, not tuned values, and everything marked proposal awaits Andrew's approval.
