# Scrapkeep execution backlog

Edition 2 · Updated 6 September 2026 · Existing cards remain revision 1; PUB-01 revision 2 includes the completed repository-local workflow package

Use **an in-repo board in [TRACKING.md](TRACKING.md)** to keep assignments, evidence and integration history beside the work. This board was selected while the checkout was local-only and remains the sole execution board after private GitHub publication.

This file turns the approved planning into bounded work. It contains no live execution status. [TRACKING.md](TRACKING.md) owns task/question state and recorded answers; [ORCHESTRATOR.md](ORCHESTRATOR.md) owns assignment, review and integration. The [Bible](BIBLE.md) remains product authority and the [accepted ADRs](adr/README.md) remain architecture authority. A historical proposal never overrides either.

Godot 4.7.2 standard, typed GDScript, explicit hybrid/session ownership, native Resource/scene content, JSON aggregate saves and offline solo are settled. The approved art direction and 1/2/4/8 branching trees are settled. Old engine-open, matte-only and fan-shaped-tree references do not reopen them.

The initial authorization covered preparation documents. Andrew subsequently authorized the bounded private publication in PUB-01. The foundation sprint below is proposed for Andrew's review. TECH_BIBLE.md and its full AUDIT_REPORT.md remain future outputs; no engine, asset, game or sprint work accompanies this delivery.

## Navigation

- [Proposed first sprint](#proposed-first-sprint)
- [Task catalogue](#task-catalogue) and individual cards
- [Open questions](#open-questions)
- [Source dispositions](#source-dispositions)
- [Source inventory](#source-inventory)

## Task contract

The original cards retain revision 1 from preparation handoff. PUB-01 is a separate revision-2 publication card. S means one bounded deliverable; M means coupled changes with one acceptance boundary. L is a nonassignable parent and must be split before admission. There are no assignable L cards here. Card revisions are immutable when pinned to an attempt; retain old revisions in the admitted source snapshot and record changes in TRACKING.

All workers read BIBLE.md, accepted ADRs, this card, ORCHESTRATOR.md, TRACKING.md and CONTRIBUTING.md. Sources below give the exact additional sections and prerequisites. The coordinator supplies these files and accepted dependency evidence in a self-contained packet; no worker must recover conversation history. A dependency output is a future input until its producer is done. A listed output path is permitted scope, not an existing file or a live lease.

For documentation cards, completion means a reviewed, source-cited contract, not a running implementation. Every output identifies sources, unresolved question IDs, procedure actually performed and evidence limits. Store verification receipts under the card's explicit artifacts/local/tasks/ID/ directory. Workers return disjoint section drafts; the coordinator admits shared documents serially. An independent reviewer report is itself reviewed for coverage by a different reviewer before it is accepted.

Native implementation cannot yet receive complete atomic cards: the production ownership map and system/schema contracts are future inputs, and the selected qualification/content scope is missing. Q-E01 and the affected product questions explicitly gate that work. After their closure, the coordinator creates scoped implementation cards with exact paths and measurable behavior. Contract completion never closes the corresponding production behavior by implication.

The LG cards apply only to the maintained browser proofs/player. They require a separately admitted work wave. Existing browser code, both entries, profiles and named evidence remain intact. Physical-device availability or required Andrew feedback must be confirmed before the applicable card becomes ready.

## Proposed first sprint

Ten foundation-contract cards form one closed dependency set. HF-01 and HF-02 have no predecessors; every other predecessor is inside this sprint. None needs an unanswered external product value to produce its specified documentation. Unknown values remain named and gate later implementation.

| ID | Outcome | Dependencies | Owner / size |
| --- | --- | --- | --- |
| [HF-01](#hf-01) | Specify production paths and contribution conventions | None | Conventions / M |
| [HF-02](#hf-02) | Create constraints and evidence register | None | Verification / S |
| [HF-03](#hf-03) | Specify module ownership and dependency interfaces | [HF-01](#hf-01) | Runtime / M |
| [HF-04](#hf-04) | Specify tick, pause and scene lifecycle | [HF-03](#hf-03) | Runtime / M |
| [HF-05](#hf-05) | Specify stable content identity and admission | [HF-03](#hf-03) | Content / M |
| [HF-06](#hf-06) | Map content schemas to persistence coverage | [HF-05](#hf-05) | Content / M |
| [HF-07](#hf-07) | Specify save envelope and durable commit boundaries | [HF-04](#hf-04), [HF-06](#hf-06) | Persistence / M |
| [HF-08](#hf-08) | Specify save failure and conservative recovery | [HF-07](#hf-07) | Persistence / M |
| [HF-09](#hf-09) | Specify schema and gameplay-content migration | [HF-06](#hf-06), [HF-07](#hf-07) | Persistence / M |
| [HF-10](#hf-10) | Review the complete foundation contract | [HF-01](#hf-01), [HF-02](#hf-02), [HF-03](#hf-03), [HF-04](#hf-04), [HF-05](#hf-05), [HF-06](#hf-06), [HF-07](#hf-07), [HF-08](#hf-08), [HF-09](#hf-09) | Independent review / M |

Schedule HF-01 and HF-02 first; then HF-03; then HF-04 and HF-05; then HF-06; then HF-07; then HF-08 and HF-09; finally HF-10. These are dependency waves, not promises of duration. A reviewer uses one of the three delegate slots. Early completed work may proceed through review while the other writer runs if ownership is disjoint.

HF-10 produces a scoped foundation review. It does not stand in for all per-system designs, the assembled TECH_BIBLE.md or TH-31's final architecture audit. That later audit must separate paper schema consistency from unperformed native roundtrip qualification.

## Task catalogue

HF covers foundation contracts; PD covers production-facing briefs; TH covers later engineering sections and assembly; SC splits authored schema families; LG preserves bounded browser/player work. Numeric ordering does not override dependencies.

| ID | Concrete outcome | Role | Size |
| --- | --- | --- | --- |
| [PUB-01](#pub-01) | Publish SCRAPKEEP privately and record the session handoff | Coordinator | M |
| [HF-01](#hf-01) | Specify production paths and contribution conventions | Conventions | M |
| [HF-02](#hf-02) | Create constraints and evidence register | Verification | S |
| [HF-03](#hf-03) | Specify module ownership and dependency interfaces | Runtime | M |
| [HF-04](#hf-04) | Specify tick, pause and scene lifecycle | Runtime | M |
| [HF-05](#hf-05) | Specify stable content identity and admission | Content | M |
| [HF-06](#hf-06) | Map content schemas to persistence coverage | Content | M |
| [HF-07](#hf-07) | Specify save envelope and durable commit boundaries | Persistence | M |
| [HF-08](#hf-08) | Specify save failure and conservative recovery | Persistence | M |
| [HF-09](#hf-09) | Specify schema and gameplay-content migration | Persistence | M |
| [HF-10](#hf-10) | Review the complete foundation contract | Independent review | M |
| [PD-01](#pd-01) | Write the production art acceptance brief | Technical art | M |
| [PD-02](#pd-02) | Specify production interface states and acceptance | Rendering/input/UI | M |
| [PD-03](#pd-03) | Write the sound and feel event brief | Audio | M |
| [TH-01](#th-01) | Specify the complete run loop | Runtime | M |
| [TH-02](#th-02) | Specify movement, camera and aim | Runtime | M |
| [TH-03](#th-03) | Specify committed attack geometry | Runtime | M |
| [TH-04](#th-04) | Specify ability and ultimate contracts | Runtime | M |
| [TH-05](#th-05) | Specify collection and growth contracts | Runtime | M |
| [TH-06](#th-06) | Specify encounters and enemy scheduling | Runtime | M |
| [TH-07](#th-07) | Specify progression and special respec | Runtime | M |
| [TH-08](#th-08) | Specify inventory and effective-build reconstruction | Runtime | M |
| [TH-09](#th-09) | Specify loot and fixed secret evaluation | Runtime | M |
| [TH-10](#th-10) | Specify device and companion ownership | Runtime | M |
| [TH-11](#th-11) | Specify run routing and lifecycle | Runtime | M |
| [TH-12](#th-12) | Specify interface state and settings contracts | Runtime | M |
| [TH-13](#th-13) | Specify chaos outcome commitment | Runtime | M |
| [TH-14](#th-14) | Specify randomness and generated-level interfaces | Runtime | M |
| [TH-15](#th-15) | Specify collision-query and physical-world qualification | Runtime | M |
| [TH-16](#th-16) | Specify rendering and effect integration | Rendering/input/UI | M |
| [TH-17](#th-17) | Specify audio integration and cue ownership | Audio | M |
| [TH-18](#th-18) | Specify input-device and focus integration | Rendering/input/UI | M |
| [TH-19](#th-19) | Specify source-asset import and export admission | Content | M |
| [TH-20](#th-20) | Reconcile the authored schema catalogue | Content | M |
| [TH-21](#th-21) | Draft save projection schemas and codec examples | Persistence | M |
| [TH-22](#th-22) | Specify content and persistence verification strategy | Verification | M |
| [TH-23](#th-23) | Specify gameplay and native interaction verification | Verification | M |
| [TH-24](#th-24) | Specify platform and performance qualification | Verification | M |
| [TH-25](#th-25) | Specify offline operation and release checks | Verification | M |
| [TH-26](#th-26) | Specify tooling, debug commands and evidence | Tooling | M |
| [TH-27](#th-27) | Review cross-system invariants and permissions | Runtime | M |
| [TH-28](#th-28) | Compile engineering decisions and qualification gaps | Verification | M |
| [TH-29](#th-29) | Prepare the native implementation qualification handoff | Conventions | M |
| [TH-30](#th-30) | Assemble the complete technical Bible | Coordinator | M |
| [TH-31](#th-31) | Audit the full technical architecture | Independent review | M |
| [SC-01](#sc-01) | Specify character and progression definitions | Content | M |
| [SC-02](#sc-02) | Specify attack and effect definitions | Content | M |
| [SC-03](#sc-03) | Specify item and recipe definitions | Content | M |
| [SC-04](#sc-04) | Specify enemy and encounter definitions | Content | M |
| [SC-05](#sc-05) | Specify world and level definitions | Content | M |
| [SC-06](#sc-06) | Specify device and companion definitions | Content | M |
| [SC-07](#sc-07) | Specify presentation definitions | Content | M |
| [SC-08](#sc-08) | Specify narrative and discovery definitions | Content | M |
| [LG-01](#lg-01) | Record Andrew lightning playtest feedback | Verification | M |
| [LG-02](#lg-02) | Qualify physical capture and controller on browser proof | Rendering/input/UI | M |
| [LG-03](#lg-03) | Establish player comparison scenarios and baseline | Tooling | M |
| [LG-04](#lg-04) | Correct the two confirmed player visual false positives | Tooling | M |
| [LG-05](#lg-05) | Measure bounded player control profiles | Tooling | M |
| [LG-07](#lg-07) | Add explicit equipment menu editing | Tooling | M |

<a id="pub-01"></a>

### PUB-01: Publish SCRAPKEEP privately and record the session handoff

**Card revision:** 2 · **Owner:** Coordinator · **Size:** M · **Lane:** Repository publication

**Source and inputs:**

- [Andrew's exact publication scope](artifacts/publication-2026-09-06/AUTHORIZATION.md), [Q-E07](#q-e07) and [TRACKING](TRACKING.md).
- Existing checkout at `dc72a02cd7a0fbe1f00b3ce71d36448364f93294`, branch `codex/lightning-playtest`, plus the completed uncommitted Bible/preparation package. The publication baseline manifest pins these existing files before editing.
- [Completed concurrent workflow package](artifacts/publication-2026-09-06/concurrent-package.json): repository-local instructions admitted unchanged from its frozen manifest; its unverified Claude runtime checks remain explicitly pending.
- [Contribution gates](CONTRIBUTING.md#handoff-and-version-control), [swarm manual](ORCHESTRATOR.md#serial-integration-and-completion), and retained preparation evidence.

**Dependencies:** None. **Blocking questions:** [Q-E07](#q-e07), satisfied by Andrew's recorded destination/visibility/branch authorization before dispatch.

**Files touched:** `README.md`; `BIBLE.md`; `BACKLOG.md`; `TRACKING.md`; `CONTRIBUTING.md`; `docs/project/README.md`; `docs/decisions.tsv`; `artifacts/publication-2026-09-06/`; `artifacts/local/publication-2026-09-06/`. Existing approved uncommitted files are admitted unchanged from the publication baseline, except the separately completed repository-local instruction package pinned by concurrent-package.json. Those instruction files are admitted as delivered, not edited by this card. Git index, local branch/upstream configuration and authorized remote refs are permitted publication operations.

**Definition of done:**

1. The completed project snapshot and reachable history have been inspected for credentials/local contact records; excluded paths stay untracked and no existing history is rewritten.
2. README identifies SCRAPKEEP and its canonical references. Active Bible image/document links resolve within the repository; its approved prose, prompt text, art direction and image bytes remain intact.
3. Independent review accepts the publication candidate; applicable document checks pass on the integrated result. Historical receipts remain unchanged and new publication evidence identifies the checked revision.
4. `bananahana720/scrapkeep` is private, `main` is its default branch, and `main` plus `codex/lightning-playtest` match their intended local commits after publication. Experimental branches remain local.
5. The verified publication receipt and session checkpoint are committed and pushed; the final remote tip is independently queried and the working tree is clean. The foundation sprint remains awaiting review.

**Verification and evidence:**

- Redacted content/path scan of the candidate and reachable history; `git diff --check`; `npm run check:project`; portable root-document links/images and source-preservation checks.
- Fresh independent review of the actual candidate; GitHub owner/privacy/default-branch API checks and `git ls-remote` versus local SHAs.
- Retain reports under `artifacts/publication-2026-09-06/`. Record the confirmed first publication SHA before the closeout commit; verify that later closeout tip outside its own self-referential content and report it at handoff.

**Boundary:** No gameplay, runtime assets, dependencies or historical receipts are edited. No build, engine installation, asset production, new license, deployment, second board, sprint dispatch or automation.

<a id="hf-01"></a>

### HF-01: Specify production paths and contribution conventions

**Card revision:** 1 · **Owner:** Conventions · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)
- [CONTRIBUTING.md § Editing conventions](CONTRIBUTING.md#editing-conventions)
- [BIBLE.md § Architecture and implementation handoff](BIBLE.md#architecture-and-implementation-handoff)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-01-production-conventions.md`; `artifacts/local/tasks/HF-01/`.

**Definition of done:**

1. Define future production directory, file naming, typed GDScript boundary, scene/Resource ownership and review conventions without modifying the browser layout.
2. Specify contribution rules for source assets, generated imports, validation and documentation ownership; preserve both browser entries and data.
3. List exact implementation path families that later scoped cards may own.
4. State repository layout, naming, code style, commit/PR rules and definition of done; convention changes cannot create a remote or authorize publication.

**Verification and evidence:**

- Review path map for overlap with both browser entries and historical evidence.
- Check every convention against accepted engine/content ADRs and existing contribution requirements.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-02"></a>

### HF-02: Create constraints and evidence register

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Later qualification and reconsideration](adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration)
- [docs/LIGHTNING-VERIFICATION.md § Sustained rendered load](docs/LIGHTNING-VERIFICATION.md#sustained-rendered-load)
- [adr/TADR-004-persistence.md § Consequences](adr/TADR-004-persistence.md#consequences)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-02-constraints-evidence.md`; `artifacts/local/tasks/HF-02/`.

**Definition of done:**

1. Separate approved constraints, proposed budgets, historical browser measurements and unmeasured native requirements.
2. Define units, workload, target identity, sampling method and owner required to admit frame, memory, load and asset budgets.
3. Record Q-E03/Q-E04 without inventing hardware, renderer or numeric limits.

**Verification and evidence:**

- Trace each claimed measurement to exact retained evidence and identify its method/version limits.
- Review all budget cells for explicit units and proposed or measured classification.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-03"></a>

### HF-03: Specify module ownership and dependency interfaces

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [BIBLE.md § Architecture and implementation handoff](BIBLE.md#architecture-and-implementation-handoff)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)

**Dependencies:** [HF-01](#hf-01). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-03-module-map.md`; `artifacts/local/tasks/HF-03/`.

**Definition of done:**

1. Define named modules, owned mutable records, allowed imports and command/result interfaces under one session authority.
2. Assign collision queries, encounter timing, run/profile mutation, persistence, content admission and presentation to explicit owners.
3. Draw dependency directions and forbid hidden gameplay mutation through signals or rendering.

**Verification and evidence:**

- Walk an attack, an equipment change and an encounter replacement through only allowed interfaces.
- Inspect the dependency graph for cycles and duplicate mutation authority.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-04"></a>

### HF-04: Specify tick, pause and scene lifecycle

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)

**Dependencies:** [HF-03](#hf-03). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04-runtime-lifecycle.md`; `artifacts/local/tasks/HF-04/`.

**Definition of done:**

1. Define fixed-tick phases, command admission, collision synchronization, published result lifetime and overload policy with unresolved rates labeled.
2. Separate release of held input, cancellation of prepared actions, solo pause and resume.
3. Define encounter replacement and scoped connection teardown while run/profile ownership survives.
4. Name the game-loop, state-machine, scoped signal/message and scene-lifecycle patterns. Include a minimal typed GDScript sketch and when not to use each; document time/tick ownership and event ordering.

**Verification and evidence:**

- Tabletop start, focus loss during preparation, pause/resume, slow frame and scene replacement; identify each owner and order.
- Check no path permits a second tick owner, replayed held action or stale scene callback.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-05"></a>

### HF-05: Specify stable content identity and admission

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-03](#hf-03). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-05-content-admission.md`; `artifacts/local/tasks/HF-05/`.

**Definition of done:**

1. Define stable domain IDs, catalogue/content revisions, immutable Resource definitions and fresh session records.
2. Describe import, structural validation, semantic validation, admission and failed reload retention at safe boundaries.
3. Define missing-ID diagnostics and active-run content pinning without silent remapping.

**Verification and evidence:**

- Trace one draft, admitted definition, rejected reload and pinned active run through the proposed state transitions.
- Check identity remains independent of display name, file path and engine Resource ID.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-06"></a>

### HF-06: Map content schemas to persistence coverage

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Later qualification and reconsideration](adr/TADR-003-content-pipeline.md#later-qualification-and-reconsideration)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)

**Dependencies:** [HF-05](#hf-05). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-06-schema-coverage.md`; `artifacts/local/tasks/HF-06/`.

**Definition of done:**

1. Inventory every character, attack, tree/node, item, recipe, encounter, world/generation, device and companion authored type. Also cover audio/visual references, interface preferences, narrative/glossary definitions, events, secrets and permanent discovery/unlock content, or give an explicit representation/exclusion rationale.
2. Map each mutable runtime projection to JSON saving or an explicit transient/reconstructed exclusion.
3. For each row name an authoring codec, save projection, example producer and future executable proof; immutable Resources are not serialized as live engine objects.

**Verification and evidence:**

- Cross-check every Core Systems noun against the matrix, including preferences and permanent discoveries.
- Check every row has an owned definition and either a persistence roundtrip requirement or a reasoned exclusion.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-07"></a>

### HF-07: Specify save envelope and durable commit boundaries

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision)
- `docs/tech/sections/HF-04-runtime-lifecycle.md` from [HF-04](#hf-04) (must be admitted before assignment)
- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-04](#hf-04), [HF-06](#hf-06). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-07-save-envelope.md`; `artifacts/local/tasks/HF-07/`.

**Definition of done:**

1. Describe the versioned aggregate envelope, profile, checkpoint, lifecycle facts, generation/content/transaction identity and separate preferences record.
2. Specify ordering and acknowledgements for level completion, reward/offer resolution, revival use and terminal settlement.
3. Keep unresolved revival/interruption product choices explicit and preserve nonduplication under every allowed policy.

**Verification and evidence:**

- Tabletop duplicate completion, revival with an older spatial checkpoint, terminal defeat and stable offered choice restore.
- Review that only a validated committed generation can be acknowledged as durable.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-08"></a>

### HF-08: Specify save failure and conservative recovery

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Consequences](adr/TADR-004-persistence.md#consequences)
- `docs/tech/sections/HF-07-save-envelope.md` from [HF-07](#hf-07) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-07](#hf-07). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-08-save-recovery.md`; `artifacts/local/tasks/HF-08/`.

**Definition of done:**

1. Define single-writer protocol, write/flush/commit ordering and OS-specific qualification questions without claiming rename alone proves durability.
2. Specify failed critical transition handling and user-visible retry/recovery states.
3. Preserve corrupt or ambiguous files and refuse rollback to a living/unspent generation when lifecycle continuity cannot be established.

**Verification and evidence:**

- Construct an interruption matrix at every proposed commit stage for rewards, revival and terminal facts.
- Review corrupt newest generation, unknown version, full disk and retry cases for false success or silent data loss.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-09"></a>

### HF-09: Specify schema and gameplay-content migration

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Consequences](adr/TADR-003-content-pipeline.md#consequences)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision)
- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/HF-07-save-envelope.md` from [HF-07](#hf-07) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-06](#hf-06), [HF-07](#hf-07). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-09-schema-migration.md`; `artifacts/local/tasks/HF-09/`.

**Definition of done:**

1. Define supported schema/content compatibility, migration chaining, validation and original preservation until new commit.
2. Specify missing ID, incompatible content and newer-format handling without rerolling, losing discoveries or adding active effects.
3. Separate preservation of browser profiles from an undecided import/retirement policy in Q-E05.

**Verification and evidence:**

- Walk one compatible migration, rejected future version, missing recipe and repeated load through the proposed rules.
- Review that no migration implicitly imports or overwrites existing browser storage.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-10"></a>

### HF-10: Review the complete foundation contract

**Card revision:** 1 · **Owner:** Independent review · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md](adr/TADR-001-engine-language-platforms.md)
- [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md)
- [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md)
- [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md)
- [adr/TADR-005-networking-scope.md](adr/TADR-005-networking-scope.md)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- `docs/tech/sections/HF-02-constraints-evidence.md` from [HF-02](#hf-02) (must be admitted before assignment)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-04-runtime-lifecycle.md` from [HF-04](#hf-04) (must be admitted before assignment)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/HF-07-save-envelope.md` from [HF-07](#hf-07) (must be admitted before assignment)
- `docs/tech/sections/HF-08-save-recovery.md` from [HF-08](#hf-08) (must be admitted before assignment)
- `docs/tech/sections/HF-09-schema-migration.md` from [HF-09](#hf-09) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-01](#hf-01), [HF-02](#hf-02), [HF-03](#hf-03), [HF-04](#hf-04), [HF-05](#hf-05), [HF-06](#hf-06), [HF-07](#hf-07), [HF-08](#hf-08), [HF-09](#hf-09). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-10-foundation-review.md`; `artifacts/local/tasks/HF-10/`.

**Definition of done:**

1. Produce an independent report with required fixes, notes, evidence level and exact reviewed draft identities.
2. Check module boundaries, tick ownership, content/persistence coverage, transition order and unresolved parameter gates.
3. Reviewer reports only; coordinator owns canonical admission and corrective assignments.

**Verification and evidence:**

- Read all nine foundation outputs together and reproduce their paper scenarios.
- Check author/reviewer independence and distinguish source review from future native qualification.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="pd-01"></a>

### PD-01: Write the production art acceptance brief

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** Art

**Source and inputs:**

- [BIBLE.md § 7. Art Direction](BIBLE.md#7-art-direction)
- [COHESION_REPORT.md § Contradictions, persistent outliers and limits](COHESION_REPORT.md#contradictions-persistent-outliers-and-limits)
- [docs/project/ASSETS.md § Asset and tool provenance](docs/project/ASSETS.md#asset-and-tool-provenance)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)

**Dependencies:** [HF-01](#hf-01). **Blocking questions:** None.

**Files touched:** `docs/product/sections/PD-01-art-acceptance.md`; `artifacts/local/tasks/PD-01/`.

**Definition of done:**

1. Map AD-01 through AD-11 to observable review checks for pilot protection, working tool, material wear, regional ecology, collection, fabrication and readable combat.
2. Define required production evidence for rolling articulation, attachment dimensions, growth states and route clearance without asserting that concept images prove those properties.
3. Specify consistent comparison views and provenance fields, and list unresolved asset scope/budget questions Q-P01 through Q-P07 and Q-P22/Q-P26/Q-P27/Q-P29/Q-P33/Q-P34.
4. Record all completed image corrections as closed concept work; no redraw request is created by a retained concept limitation.

**Verification and evidence:**

- An independent reader traces each acceptance row to BIBLE Section 7 or a named cohesion limitation.
- Check every local input link and confirm every unselected scope/value is identified by question ID.

**Boundary:** Documentation only. Does not choose assets, budgets, figurine dimensions or production motion, and does not authorize art generation.

<a id="pd-02"></a>

### PD-02: Specify production interface states and acceptance

**Card revision:** 1 · **Owner:** Rendering/input/UI · **Size:** M · **Lane:** UX

**Source and inputs:**

- [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings)
- [BIBLE.md § Four slots and milestone progression](BIBLE.md#four-slots-and-milestone-progression)
- [BIBLE.md § Inventory, equipment and transformations](BIBLE.md#inventory-equipment-and-transformations)
- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves)
- [docs/LIGHTNING-VERIFICATION.md § Result and limits](docs/LIGHTNING-VERIFICATION.md#result-and-limits)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/product/sections/PD-02-interface-states.md`; `artifacts/local/tasks/PD-02/`.

**Definition of done:**

1. Enumerate combat HUD, character, equipment, companion, map and settings views with entry/exit, focus and pause requirements. Refer unresolved lifecycle mechanics to the engineering contract rather than selecting them.
2. Specify locked slot, unavailable upgrade, equipped/acquired item, eligible swap, special respec, two-world offer, available/spent revival and terminal states without selecting missing limits.
3. Describe keyboard/controller focus restoration and pointer recapture requirements so navigation cannot cast accidentally.
4. Give a review scenario for each state and expose Q-P11/Q-P12/Q-P14/Q-P15/Q-P16/Q-P18/Q-P19/Q-P30/Q-P32 wherever an answer is required for production.

**Verification and evidence:**

- Walk every state transition on paper against BIBLE Section 6, identifying expected visible feedback and unavailable actions.
- Confirm that current prototype screenshots/input tests are labeled historical and no production viewing-distance or controller claim is made.

**Boundary:** One interface documentation artifact. Layout, hardware mappings, visual production and runtime implementation require separately selected scope.

<a id="pd-03"></a>

### PD-03: Write the sound and feel event brief

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** Audio

**Source and inputs:**

- [BIBLE.md § 8. Audio & Feel](BIBLE.md#8-audio--feel)
- [BIBLE_DECISIONS.md § Sound and presentation proposal](BIBLE_DECISIONS.md#sound-and-presentation-proposal)
- [docs/project/ASSETS.md § Asset and tool provenance](docs/project/ASSETS.md#asset-and-tool-provenance)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/product/sections/PD-03-sound-feel-events.md`; `artifacts/local/tasks/PD-03/`.

**Definition of done:**

1. Map attraction, fabrication, rolling/jump/rebound, weapon/device/ultimate, enemy warning, UI, revival/defeat and discovery to proposed physical sources and trigger meanings.
2. Separate proposal cues from synthesized browser proof and identify the accepted threats-first mix invariant versus unselected artistic details.
3. Define a future audition matrix for starting kit, dense ordinary fight and exceptional build at quiet playback and with sound disabled; record method and evidence needed for long-session fatigue.
4. List Q-P13/Q-P17/Q-P20/Q-P28/Q-P31/Q-P32 blockers for sound production and tuning, without inventing asset counts or recording scope.

**Verification and evidence:**

- Independent source review checks every event meaning against BIBLE Sections 6 and 8.
- Verify distinct collection/fabrication and revival/companion-rescue meanings, and inspect that dangerous events never wait for music timing.

**Boundary:** Documentation only. No score, sound generation, recordings, controller tests or audition claims.

<a id="th-01"></a>

### TH-01: Specify the complete run loop

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § The complete loop](BIBLE.md#the-complete-loop)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-01-complete-loop.md`; `artifacts/local/tasks/TH-01/`.

**Definition of done:**

1. Define encounter, intermission, world transition and terminal states with carried state and owner.
2. Map four-world target, rebuild-each-run power and permanent discoveries without inventing levels, routes or duration tuning.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Walk one successful route and one terminal route at contract level.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-02"></a>

### TH-02: Specify movement, camera and aim

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Movement, camera and active aim](BIBLE.md#movement-camera-and-active-aim)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-02-movement-camera-and-active-aim.md`; `artifacts/local/tasks/TH-02/`.

**Definition of done:**

1. Define camera-relative intent, movement/physical-world boundary, growth clearance and optional transformation integration.
2. Separate prototype double-jump/rebound evidence from candidate production tuning and hardware feel.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Trace obstructed aim, side contact, descending rebound and maximum ordinary growth through owned interfaces.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-03"></a>

### TH-03: Specify committed attack geometry

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md`; `artifacts/local/tasks/TH-03/`.

**Definition of done:**

1. Define provisional preview, weapon-origin obstruction, commitment, height-aware geometry, targets and emitted presentation records.
2. State enemy preparation/commit/execute/recovery and once-only chaos outcome requirements.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Compare damage and visual consumers for the same blocked, low, tall and changed-at-commit attack descriptors.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-04"></a>

### TH-04: Specify ability and ultimate contracts

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Abilities, ultimates and combat rhythm](BIBLE.md#abilities-ultimates-and-combat-rhythm)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md`; `artifacts/local/tasks/TH-04/`.

**Definition of done:**

1. Define action availability, cooldown, class-contribution charge and effect lifetime responsibilities.
2. Keep exact triggers, effects and slot mapping as Q-P11/Q-P13 content inputs; distinguish prototype charge from universal rules.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Walk charge, unavailable action, ultimate activation and effect expiry without idle progression or duplicate charge.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-05"></a>

### TH-05: Specify collection and growth contracts

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Electromagnetic collection, recycling and growth](BIBLE.md#electromagnetic-collection-recycling-and-growth)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md`; `artifacts/local/tasks/TH-05/`.

**Definition of done:**

1. Define recoverable metal admission, collection ownership, visual intake/fabrication messages and physical growth constraints.
2. Separate material presentation from milestone/economy policy; name Q-P10 as missing production values.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Walk one pickup twice, a milestone upgrade and ordinary maximum growth without duplicate progress or implied mass sacrifice.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-06"></a>

### TH-06: Specify encounters and enemy scheduling

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-06-encounters-waves-and-enemies.md`; `artifacts/local/tasks/TH-06/`.

**Definition of done:**

1. Define encounter/wave objectives, arrival, attack admission and recovery responsibilities.
2. Represent authored commitment budgets and defense rules as unresolved inputs, without copying old global caps or boss-per-level assumptions.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.
5. Separate unanswered attack admission Q-E10 from objective completion/failure Q-P38.

**Verification and evidence:**

- Walk overlapping commitments and level completion with Q-E10 admission choices explicitly gated.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-07"></a>

### TH-07: Specify progression and special respec

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Four slots and milestone progression](BIBLE.md#four-slots-and-milestone-progression)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md`; `artifacts/local/tasks/TH-07/`.

**Definition of done:**

1. Define four tree selections, slot unlocking, milestones, respec authorization and derived-build updates.
2. Require 15 nodes, 14 edges, eight endpoints, binary children and a connected lineage per slot; retain Q-P10/Q-P11 for costs/effects and special opportunity details.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Retain Q-P18 special respec scope, frequency and refund decisions.
5. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Review malformed tree, illegal crosspath, world-one unlock and special respec scenarios; no fake final kit values.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-08"></a>

### TH-08: Specify inventory and effective-build reconstruction

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Inventory, equipment and transformations](BIBLE.md#inventory-equipment-and-transformations)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-08-inventory-equipment-and-transformations.md`; `artifacts/local/tasks/TH-08/`.

**Definition of done:**

1. Separate acquired items, equipped selections and rebuilt effective effects.
2. Define compatibility and invalidation interfaces for player, device and companion effects; keep inventory limits and transformation mechanics open.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Retain Q-P19 inventory capacity/equipment slot decisions.
5. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Walk equip/remove/re-equip, load and transformation replacement; stale effects and recursive duplicate application must be excluded.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-09"></a>

### TH-09: Specify loot and fixed secret evaluation

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Themed loot, attunement and fixed secrets](BIBLE.md#themed-loot-attunement-and-fixed-secrets)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md`; `artifacts/local/tasks/TH-09/`.

**Definition of done:**

1. Separate random world-themed acquisition, deterministic endpoint recipes and permanent discovery knowledge.
2. Define recipe eligibility/rebuild/discovery interfaces and stable resolved rewards; leave exact recipes and disclosure to Q-P14.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Walk repeated grant, discovery, reload, re-equip and lost eligibility; bonus occurs once and discovery persists.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-10"></a>

### TH-10: Specify device and companion ownership

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Devices and one main companion](BIBLE.md#devices-and-one-main-companion)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-10-devices-and-one-main-companion.md`; `artifacts/local/tasks/TH-10/`.

**Definition of done:**

1. Define autonomous action ownership, compatible effects and one main assembled companion.
2. Identify caps, recall, lifetime, parts and cross-level persistence as Q-P15 inputs; rescue cannot add a standard revival.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.
5. Keep chassis-type epithets separate from assembled-instance identity; Q-P29 supplies the selected naming rule.

**Verification and evidence:**

- Walk deployment, effect replacement, scene exit and support rescue with no invented conductor cap or component model.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-11"></a>

### TH-11: Specify run routing and lifecycle

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md`; `artifacts/local/tasks/TH-11/`.

**Definition of done:**

1. Define level/world identities, onward exit/world-choice distinction and stable offered options across saves.
2. Connect first death, spent revival, terminal run and completed-level checkpoint contracts without choosing Q-P12/Q-P16 values.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Walk clear-before-choice, world offer, first/second death and resume with durable facts from HF-07/HF-08.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-12"></a>

### TH-12: Specify interface state and settings contracts

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)
- `docs/product/sections/PD-02-interface-states.md` from [PD-02](#pd-02) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10), [PD-02](#pd-02). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-12-hud-dashboard-and-settings.md`; `artifacts/local/tasks/TH-12/`.

**Definition of done:**

1. Define HUD data snapshots and dashboard states for locked slot, unavailable upgrade, equipment swap, special respec and route choice.
2. Specify settings ownership, focus restoration and input clearing; treat mockups as layout studies.
3. Name every accessed module and tie all commands, records and events to HF-03 permissions.
4. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Tabletop keyboard/controller navigation, scale change, modal close and resume; no queued action may escape.
- Check every required product parameter is either sourced or explicitly unresolved; paper traces are not executable evidence.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-13"></a>

### TH-13: Specify chaos outcome commitment

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows)
- [docs/RUNTIME-BLUEPRINT.md § 3.5 Chaos magician](docs/RUNTIME-BLUEPRINT.md#35-chaos-magician)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)

**Dependencies:** [TH-03](#th-03), [TH-04](#th-04). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-13-chaos-outcomes.md`; `artifacts/local/tasks/TH-13/`.

**Definition of done:**

1. Define when randomness resolves and how intended preview, resolved geometry and harmful outcomes relate.
2. Retain Q-P13 element/warning/severity decisions as content dependencies; no instability meter or always-random kit.
3. Include explicit sections for interfaces, owned data, algorithms/update order, edge cases, failure modes and tunable parameters; each parameter is sourced or has a question ID. Check all module access against HF-03.

**Verification and evidence:**

- Trace one intended and one harmful outcome with a single authoritative draw/result and no presentation reroll.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-14"></a>

### TH-14: Specify randomness and generated-level interfaces

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [docs/RUNTIME-BLUEPRINT.md § 3.4 World, level and randomness definitions](docs/RUNTIME-BLUEPRINT.md#34-world-level-and-randomness-definitions)
- [adr/TADR-002-runtime-model.md § Consequences](adr/TADR-002-runtime-model.md#consequences)
- `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` from [TH-06](#th-06) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-06](#th-06), [TH-11](#th-11). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-14-randomness-generation.md`; `artifacts/local/tasks/TH-14/`.

**Definition of done:**

1. Define independent route/layout/loot/miscast random responsibilities and saved resolved choices.
2. Specify level-generation request/result, collision/clearance and validation contracts without selecting Q-P23 technique.
3. State repeatability limits across engine/OS/timing and separate stored outcomes from seeds.

**Verification and evidence:**

- Walk altered cosmetic randomness, resumed offers and rejected level candidate without changing unrelated random outcomes.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-15"></a>

### TH-15: Specify collision-query and physical-world qualification

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Later qualification and reconsideration](adr/TADR-002-runtime-model.md#later-qualification-and-reconsideration)
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` from [TH-02](#th-02) (must be admitted before assignment)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-02](#th-02), [TH-03](#th-03). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-15-physics-query-contract.md`; `artifacts/local/tasks/TH-15/`.

**Definition of done:**

1. Define query order, synchronized collision-world snapshot, coordinate conversions and contact interpretation.
2. Specify controlled engine fixtures for obstruction, floor separation, jump/rebound and growth clearance.

**Verification and evidence:**

- Review fixture expected observations against both movement and attack pages; label all engine-hosted trials unexecuted.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-16"></a>

### TH-16: Specify rendering and effect integration

**Card revision:** 1 · **Owner:** Rendering/input/UI · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § AD-08. Composition, scale and interface](BIBLE.md#ad-08-composition-scale-and-interface)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` from [TH-05](#th-05) (must be admitted before assignment)
- `docs/tech/sections/TH-10-devices-and-one-main-companion.md` from [TH-10](#th-10) (must be admitted before assignment)
- `docs/product/sections/PD-01-art-acceptance.md` from [PD-01](#pd-01) (must be admitted before assignment)

**Dependencies:** [TH-03](#th-03), [TH-05](#th-05), [TH-10](#th-10), [PD-01](#pd-01). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-16-rendering-integration.md`; `artifacts/local/tasks/TH-16/`.

**Definition of done:**

1. Define committed-result consumption, interpolation, scene disposal, reusable effect resources and definition-to-view mapping.
2. Specify telegraph readability and silhouette/clearance qualification against approved art without choosing renderer or budgets.

**Verification and evidence:**

- Trace attack, fabricated upgrade and level unload; check presentation cannot mutate geometry, rolls or run state.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-17"></a>

### TH-17: Specify audio integration and cue ownership

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § 8. Audio & Feel](BIBLE.md#8-audio--feel)
- [docs/RUNTIME-BLUEPRINT.md § 8. Audio and character expression](docs/RUNTIME-BLUEPRINT.md#8-audio-and-character-expression)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)
- `docs/product/sections/PD-03-sound-feel-events.md` from [PD-03](#pd-03) (must be admitted before assignment)

**Dependencies:** [TH-04](#th-04), [TH-12](#th-12), [PD-03](#pd-03). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-17-audio-integration.md`; `artifacts/local/tasks/TH-17/`.

**Definition of done:**

1. Define committed cue source, voice lifetime, scene/pause behavior and separate preference volume controls.
2. Link threat-priority and build feedback needs to Q-P17 direction without authoring music/assets or deciding bark scope.

**Verification and evidence:**

- Trace pause, repeated result delivery and scene replacement for duplicated or stale audio; record future listening proof.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-18"></a>

### TH-18: Specify input-device and focus integration

**Card revision:** 1 · **Owner:** Rendering/input/UI · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)
- [docs/adr/0005-caster-input-and-dashboard.md](docs/adr/0005-caster-input-and-dashboard.md)
- `docs/tech/sections/HF-04-runtime-lifecycle.md` from [HF-04](#hf-04) (must be admitted before assignment)
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` from [TH-02](#th-02) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-04](#hf-04), [TH-02](#th-02), [TH-12](#th-12). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-18-input-integration.md`; `artifacts/local/tasks/TH-18/`.

**Definition of done:**

1. Map physical device actions to gameplay/UI intents and define device loss, focus/modal clearing and prepared cancellation.
2. Define full keyboard/mouse and controller gameplay/menu coverage and record unqualified hardware.

**Verification and evidence:**

- Tabletop disconnect during aim, controller modal navigation and focus return; identify future native physical tests per transition.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-19"></a>

### TH-19: Specify source-asset import and export admission

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision)
- [docs/project/ASSETS.md](docs/project/ASSETS.md)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-05](#hf-05), [TH-16](#th-16). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-19-asset-import-export.md`; `artifacts/local/tasks/TH-19/`.

**Definition of done:**

1. Define source provenance, import settings, generated-output handling, scene/Resource references and export manifest validation.
2. Separate concept images from production asset admission and retain required notices from Q-E06.

**Verification and evidence:**

- Follow one source asset to exported reference and one missing reference through rejection; no production asset is generated here.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-20"></a>

### TH-20: Reconcile the authored schema catalogue

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/schemas/SC-01.md` from [SC-01](#sc-01) (must be admitted before assignment)
- `docs/tech/schemas/SC-02.md` from [SC-02](#sc-02) (must be admitted before assignment)
- `docs/tech/schemas/SC-03.md` from [SC-03](#sc-03) (must be admitted before assignment)
- `docs/tech/schemas/SC-04.md` from [SC-04](#sc-04) (must be admitted before assignment)
- `docs/tech/schemas/SC-05.md` from [SC-05](#sc-05) (must be admitted before assignment)
- `docs/tech/schemas/SC-06.md` from [SC-06](#sc-06) (must be admitted before assignment)
- `docs/tech/schemas/SC-07.md` from [SC-07](#sc-07) (must be admitted before assignment)
- `docs/tech/schemas/SC-08.md` from [SC-08](#sc-08) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-06](#hf-06), [SC-01](#sc-01), [SC-02](#sc-02), [SC-03](#sc-03), [SC-04](#sc-04), [SC-05](#sc-05), [SC-06](#sc-06), [SC-07](#sc-07), [SC-08](#sc-08). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-20-authored-schemas.md`; `artifacts/local/tasks/TH-20/`.

**Definition of done:**

1. Produce one index mapping every HF-06 authored row to its admitted SC-01–SC-08 definition and example.
2. Identify cross-family reference/type conflicts and return corrections to the owning card; do not rewrite all schemas in this card.
3. Confirm no content type is orphaned and every save projection or explicit exclusion reaches TH-21.

**Verification and evidence:**

- Compare matrix, family rows and reference names one for one; follow a character/tree/item/recipe chain and an area/enemy/attack chain.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-21"></a>

### TH-21: Draft save projection schemas and codec examples

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-004-persistence.md § Later qualification and reconsideration](adr/TADR-004-persistence.md#later-qualification-and-reconsideration)
- `docs/tech/sections/HF-08-save-recovery.md` from [HF-08](#hf-08) (must be admitted before assignment)
- `docs/tech/sections/HF-09-schema-migration.md` from [HF-09](#hf-09) (must be admitted before assignment)
- `docs/tech/sections/TH-20-authored-schemas.md` from [TH-20](#th-20) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-08](#hf-08), [HF-09](#hf-09), [TH-20](#th-20). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-21-save-schemas-codecs.md`; `artifacts/local/tasks/TH-21/`.

**Definition of done:**

1. Document envelope, profile, lifecycle, checkpoint and preferences field contracts and labeled JSON examples.
2. Map every authored schema to its mutable projection or explicit reconstruction/immutable exclusion.
3. Write paper codec/migration examples for selections, companion, offered choices and terminal facts without claiming runnable serialization.

**Verification and evidence:**

- Compare each example before/after paper encoding and migration to HF-06 coverage and source schemas.
- Review derived-effect rebuild and preserved unknown/corrupt source behavior.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-22"></a>

### TH-22: Specify content and persistence verification strategy

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Later qualification and reconsideration](adr/TADR-003-content-pipeline.md#later-qualification-and-reconsideration)
- [adr/TADR-004-persistence.md § Later qualification and reconsideration](adr/TADR-004-persistence.md#later-qualification-and-reconsideration)
- `docs/tech/sections/TH-20-authored-schemas.md` from [TH-20](#th-20) (must be admitted before assignment)
- `docs/tech/sections/TH-21-save-schemas-codecs.md` from [TH-21](#th-21) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-20](#th-20), [TH-21](#th-21). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-22-content-persistence-tests.md`; `artifacts/local/tasks/TH-22/`.

**Definition of done:**

1. Assign future executable Resource/scene and JSON roundtrip checks to every matrix row.
2. Specify mutation-isolation, invalid-ID, reload-retention, migration and fault-injection cases with expected outcomes and retained evidence.

**Verification and evidence:**

- Trace each ADR qualification obligation to a concrete planned fixture and observation; identify missing mechanisms rather than claiming tests pass.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-23"></a>

### TH-23: Specify gameplay and native interaction verification

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [docs/RUNTIME-BLUEPRINT.md § 9. Validation strategy](docs/RUNTIME-BLUEPRINT.md#9-validation-strategy)
- [CONTRIBUTING.md § Verification](CONTRIBUTING.md#verification)
- `docs/tech/sections/TH-01-complete-loop.md` from [TH-01](#th-01) (must be admitted before assignment)
- `docs/tech/sections/TH-13-chaos-outcomes.md` from [TH-13](#th-13) (must be admitted before assignment)
- `docs/tech/sections/TH-15-physics-query-contract.md` from [TH-15](#th-15) (must be admitted before assignment)
- `docs/tech/sections/TH-18-input-integration.md` from [TH-18](#th-18) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` from [TH-02](#th-02) (must be admitted before assignment)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` from [TH-05](#th-05) (must be admitted before assignment)
- `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` from [TH-06](#th-06) (must be admitted before assignment)
- `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` from [TH-07](#th-07) (must be admitted before assignment)
- `docs/tech/sections/TH-08-inventory-equipment-and-transformations.md` from [TH-08](#th-08) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- `docs/tech/sections/TH-10-devices-and-one-main-companion.md` from [TH-10](#th-10) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)

**Dependencies:** [TH-01](#th-01), [TH-13](#th-13), [TH-15](#th-15), [TH-18](#th-18), [TH-02](#th-02), [TH-03](#th-03), [TH-04](#th-04), [TH-05](#th-05), [TH-06](#th-06), [TH-07](#th-07), [TH-08](#th-08), [TH-09](#th-09), [TH-10](#th-10), [TH-11](#th-11), [TH-12](#th-12). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-23-gameplay-native-tests.md`; `artifacts/local/tasks/TH-23/`.

**Definition of done:**

1. Map each core-system contract to future rule, controlled-engine, native-device and human-play evidence.
2. Preserve independent evidence for controller feel, full-run duration, growth clearance and readable combat.

**Verification and evidence:**

- Review coverage against every Core Systems page and all eight blueprint validation scenarios; browser checks cannot certify Godot.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-24"></a>

### TH-24: Specify platform and performance qualification

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Later qualification and reconsideration](adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration)
- `docs/tech/sections/HF-02-constraints-evidence.md` from [HF-02](#hf-02) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- `docs/tech/sections/TH-19-asset-import-export.md` from [TH-19](#th-19) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-02](#hf-02), [TH-16](#th-16), [TH-19](#th-19). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-24-platform-performance.md`; `artifacts/local/tasks/TH-24/`.

**Definition of done:**

1. Define clean-machine Windows/Linux export, graphics/backend, frame-time, memory, load and representative-growth encounter measurement plans.
2. Record Q-E03/Q-E04 target and budget decisions as unresolved until approved/measured; retain historical RTX 4080 browser result only as reference.

**Verification and evidence:**

- Check each claimed requirement has machine identity, workload, metric, sampling and decision owner.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-25"></a>

### TH-25: Specify offline operation and release checks

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-005-networking-scope.md § Later qualification and reconsideration](adr/TADR-005-networking-scope.md#later-qualification-and-reconsideration)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)
- `docs/tech/sections/TH-18-input-integration.md` from [TH-18](#th-18) (must be admitted before assignment)
- `docs/tech/sections/TH-21-save-schemas-codecs.md` from [TH-21](#th-21) (must be admitted before assignment)
- `docs/tech/sections/TH-24-platform-performance.md` from [TH-24](#th-24) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-18](#th-18), [TH-21](#th-21), [TH-24](#th-24). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-25-offline-release.md`; `artifacts/local/tasks/TH-25/`.

**Definition of done:**

1. Define offline start/play/save/resume/finish checks and absence of account/service dependencies.
2. Define release checklist inputs for licensing, export templates, notices and supported save/content compatibility without authorizing distribution.

**Verification and evidence:**

- Tabletop offline lifecycle and release evidence review; every unmet release decision stays explicit.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-26"></a>

### TH-26: Specify tooling, debug commands and evidence

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Carry-forward map](docs/project/AGENT-PLAYTEST-ENGINEERING.md#carry-forward-map)
- [adr/TADR-002-runtime-model.md § Consequences](adr/TADR-002-runtime-model.md#consequences)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- `docs/tech/sections/TH-23-gameplay-native-tests.md` from [TH-23](#th-23) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-03](#hf-03), [TH-14](#th-14), [TH-23](#th-23). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-26-tooling-debug.md`; `artifacts/local/tasks/TH-26/`.

**Definition of done:**

1. Define production diagnostic command access, scenario/config identity, logs, replay limits and exact candidate evidence.
2. Separate browser QA bridge/native player reuse candidates from a future Godot automation adapter; no adapter compatibility is assumed.
3. State player-facing versus test-build diagnostics and surface Q-E13 instrumentation policy.
4. Specify debug overlays, cheats/test commands, inspectors, content validators and profiling hooks with ownership, release-access policy and captured evidence for each.

**Verification and evidence:**

- Trace a failure from build/config identity through planned capture and reproduction report; reject synthetic success as physical proof.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-27"></a>

### TH-27: Review cross-system invariants and permissions

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md)
- [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md)
- [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md)
- `docs/tech/sections/TH-13-chaos-outcomes.md` from [TH-13](#th-13) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- `docs/tech/sections/TH-15-physics-query-contract.md` from [TH-15](#th-15) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- `docs/tech/sections/TH-17-audio-integration.md` from [TH-17](#th-17) (must be admitted before assignment)
- `docs/tech/sections/TH-18-input-integration.md` from [TH-18](#th-18) (must be admitted before assignment)
- `docs/tech/sections/TH-21-save-schemas-codecs.md` from [TH-21](#th-21) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)
- `docs/tech/sections/TH-01-complete-loop.md` from [TH-01](#th-01) (must be admitted before assignment)

**Dependencies:** [TH-13](#th-13), [TH-14](#th-14), [TH-15](#th-15), [TH-16](#th-16), [TH-17](#th-17), [TH-18](#th-18), [TH-21](#th-21), [TH-01](#th-01). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-27-cross-system-contracts.md`; `artifacts/local/tasks/TH-27/`.

**Definition of done:**

1. Reconcile shared attack/effect, scene lifetime, build reconstruction and durable transition records across system pages.
2. Produce module-access table per system and list concrete contract corrections for their owning cards.

**Verification and evidence:**

- Walk equipment-change-to-render/save and level-clear-to-choice/load sequences; flag mismatched fields or forbidden access.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-28"></a>

### TH-28: Compile engineering decisions and qualification gaps

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md](adr/TADR-001-engine-language-platforms.md)
- [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md)
- [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md)
- [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md)
- [adr/TADR-005-networking-scope.md](adr/TADR-005-networking-scope.md)
- `docs/tech/sections/TH-22-content-persistence-tests.md` from [TH-22](#th-22) (must be admitted before assignment)
- `docs/tech/sections/TH-23-gameplay-native-tests.md` from [TH-23](#th-23) (must be admitted before assignment)
- `docs/tech/sections/TH-24-platform-performance.md` from [TH-24](#th-24) (must be admitted before assignment)
- `docs/tech/sections/TH-25-offline-release.md` from [TH-25](#th-25) (must be admitted before assignment)
- `docs/tech/sections/TH-26-tooling-debug.md` from [TH-26](#th-26) (must be admitted before assignment)
- `docs/tech/sections/TH-27-cross-system-contracts.md` from [TH-27](#th-27) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-22](#th-22), [TH-23](#th-23), [TH-24](#th-24), [TH-25](#th-25), [TH-26](#th-26), [TH-27](#th-27). **Blocking questions:** None.

**Files touched:** `ENGINEERING_DECISIONS.md`; `artifacts/local/tasks/TH-28/`.

**Definition of done:**

1. Produce the engineering decisions list with source question IDs, settled choices, open mechanisms, missing product values and future qualification gates.
2. Reference authoritative BACKLOG questions and TRACKING answers rather than creating a second live decision-state ledger.

**Verification and evidence:**

- Cross-check every explicit unknown in sections against a named question or engineering producer; no implied build authorization.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-29"></a>

### TH-29: Prepare the native implementation qualification handoff

**Card revision:** 1 · **Owner:** Conventions · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Later qualification and reconsideration](adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/TH-22-content-persistence-tests.md` from [TH-22](#th-22) (must be admitted before assignment)
- `docs/tech/sections/TH-23-gameplay-native-tests.md` from [TH-23](#th-23) (must be admitted before assignment)
- `docs/tech/sections/TH-24-platform-performance.md` from [TH-24](#th-24) (must be admitted before assignment)
- `docs/tech/sections/TH-25-offline-release.md` from [TH-25](#th-25) (must be admitted before assignment)
- `docs/tech/sections/TH-26-tooling-debug.md` from [TH-26](#th-26) (must be admitted before assignment)
- `ENGINEERING_DECISIONS.md` from [TH-28](#th-28) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-22](#th-22), [TH-23](#th-23), [TH-24](#th-24), [TH-25](#th-25), [TH-26](#th-26), [TH-28](#th-28). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-29-native-handoff.md`; `artifacts/local/tasks/TH-29/`.

**Definition of done:**

1. Define admission prerequisites and exact future scope/path inputs needed to turn selected native qualification into runnable cards.
2. Separate engine installation/export setup, controlled mechanics, persistence qualification and physical device proof; do not invent build cards while scope or paths are missing.
3. Record Q-E01 and remaining product-dependent implementation gates for Andrew review.

**Verification and evidence:**

- Check all future implementation inputs have accepted producer paths and qualification criteria; no production code or install starts.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-30"></a>

### TH-30: Assemble the complete technical Bible

**Card revision:** 1 · **Owner:** Coordinator · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/README.md](adr/README.md)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- `docs/tech/sections/HF-02-constraints-evidence.md` from [HF-02](#hf-02) (must be admitted before assignment)
- `docs/tech/sections/HF-03-module-map.md` from [HF-03](#hf-03) (must be admitted before assignment)
- `docs/tech/sections/HF-04-runtime-lifecycle.md` from [HF-04](#hf-04) (must be admitted before assignment)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/HF-07-save-envelope.md` from [HF-07](#hf-07) (must be admitted before assignment)
- `docs/tech/sections/HF-08-save-recovery.md` from [HF-08](#hf-08) (must be admitted before assignment)
- `docs/tech/sections/HF-09-schema-migration.md` from [HF-09](#hf-09) (must be admitted before assignment)
- `docs/tech/sections/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)
- `docs/tech/sections/TH-01-complete-loop.md` from [TH-01](#th-01) (must be admitted before assignment)
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` from [TH-02](#th-02) (must be admitted before assignment)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` from [TH-05](#th-05) (must be admitted before assignment)
- `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` from [TH-06](#th-06) (must be admitted before assignment)
- `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` from [TH-07](#th-07) (must be admitted before assignment)
- `docs/tech/sections/TH-08-inventory-equipment-and-transformations.md` from [TH-08](#th-08) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- `docs/tech/sections/TH-10-devices-and-one-main-companion.md` from [TH-10](#th-10) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)
- `docs/tech/sections/TH-13-chaos-outcomes.md` from [TH-13](#th-13) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- `docs/tech/sections/TH-15-physics-query-contract.md` from [TH-15](#th-15) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- `docs/tech/sections/TH-17-audio-integration.md` from [TH-17](#th-17) (must be admitted before assignment)
- `docs/tech/sections/TH-18-input-integration.md` from [TH-18](#th-18) (must be admitted before assignment)
- `docs/tech/sections/TH-19-asset-import-export.md` from [TH-19](#th-19) (must be admitted before assignment)
- `docs/tech/sections/TH-20-authored-schemas.md` from [TH-20](#th-20) (must be admitted before assignment)
- `docs/tech/sections/TH-21-save-schemas-codecs.md` from [TH-21](#th-21) (must be admitted before assignment)
- `docs/tech/sections/TH-22-content-persistence-tests.md` from [TH-22](#th-22) (must be admitted before assignment)
- `docs/tech/sections/TH-23-gameplay-native-tests.md` from [TH-23](#th-23) (must be admitted before assignment)
- `docs/tech/sections/TH-24-platform-performance.md` from [TH-24](#th-24) (must be admitted before assignment)
- `docs/tech/sections/TH-25-offline-release.md` from [TH-25](#th-25) (must be admitted before assignment)
- `docs/tech/sections/TH-26-tooling-debug.md` from [TH-26](#th-26) (must be admitted before assignment)
- `docs/tech/sections/TH-27-cross-system-contracts.md` from [TH-27](#th-27) (must be admitted before assignment)
- `ENGINEERING_DECISIONS.md` from [TH-28](#th-28) (must be admitted before assignment)
- `docs/tech/sections/TH-29-native-handoff.md` from [TH-29](#th-29) (must be admitted before assignment)
- `docs/tech/schemas/SC-01.md` from [SC-01](#sc-01) (must be admitted before assignment)
- `docs/tech/schemas/SC-02.md` from [SC-02](#sc-02) (must be admitted before assignment)
- `docs/tech/schemas/SC-03.md` from [SC-03](#sc-03) (must be admitted before assignment)
- `docs/tech/schemas/SC-04.md` from [SC-04](#sc-04) (must be admitted before assignment)
- `docs/tech/schemas/SC-05.md` from [SC-05](#sc-05) (must be admitted before assignment)
- `docs/tech/schemas/SC-06.md` from [SC-06](#sc-06) (must be admitted before assignment)
- `docs/tech/schemas/SC-07.md` from [SC-07](#sc-07) (must be admitted before assignment)
- `docs/tech/schemas/SC-08.md` from [SC-08](#sc-08) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-01](#hf-01), [HF-02](#hf-02), [HF-03](#hf-03), [HF-04](#hf-04), [HF-05](#hf-05), [HF-06](#hf-06), [HF-07](#hf-07), [HF-08](#hf-08), [HF-09](#hf-09), [HF-10](#hf-10), [TH-01](#th-01), [TH-02](#th-02), [TH-03](#th-03), [TH-04](#th-04), [TH-05](#th-05), [TH-06](#th-06), [TH-07](#th-07), [TH-08](#th-08), [TH-09](#th-09), [TH-10](#th-10), [TH-11](#th-11), [TH-12](#th-12), [TH-13](#th-13), [TH-14](#th-14), [TH-15](#th-15), [TH-16](#th-16), [TH-17](#th-17), [TH-18](#th-18), [TH-19](#th-19), [TH-20](#th-20), [TH-21](#th-21), [TH-22](#th-22), [TH-23](#th-23), [TH-24](#th-24), [TH-25](#th-25), [TH-26](#th-26), [TH-27](#th-27), [TH-28](#th-28), [TH-29](#th-29), [SC-01](#sc-01), [SC-02](#sc-02), [SC-03](#sc-03), [SC-04](#sc-04), [SC-05](#sc-05), [SC-06](#sc-06), [SC-07](#sc-07), [SC-08](#sc-08). **Blocking questions:** None.

**Files touched:** `TECH_BIBLE.md`; `artifacts/local/tasks/TH-30/`.

**Definition of done:**

1. Assemble ten sections: Constraints & Budgets; Module Map; Runtime Patterns; Data Model & Content Pipeline; System Designs; Persistence; Rendering, Audio, Input Integration; Tooling & Debug; Testing Strategy; Conventions.
2. Keep one page per core system and include approved ADR/Bible citations, rejected-choice references, schemas/examples and qualification limits.
3. Reconcile field names, cross references and ownership while preserving unresolved authoritative questions.

**Verification and evidence:**

- Verify section inventory, link/anchor resolution and source-to-section coverage.
- Compare assembly against admitted draft identities and report any unresolved integration conflict.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-31"></a>

### TH-31: Audit the full technical architecture

**Card revision:** 1 · **Owner:** Independent review · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- `TECH_BIBLE.md` from [TH-30](#th-30) (must be admitted before assignment)
- `ENGINEERING_DECISIONS.md` from [TH-28](#th-28) (must be admitted before assignment)
- [adr/TADR-001-engine-language-platforms.md](adr/TADR-001-engine-language-platforms.md)
- [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md)
- [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md)
- [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md)
- [adr/TADR-005-networking-scope.md](adr/TADR-005-networking-scope.md)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [TH-30](#th-30). **Blocking questions:** None.

**Files touched:** `AUDIT_REPORT.md`; `artifacts/local/tasks/TH-31/`.

**Definition of done:**

1. Report exact reviewed identity, evidence level, required fixes and notes for the assembled technical Bible.
2. Check module cycles, all systems covered, each design only accessing permitted modules and at least two rejected options per ADR.
3. Audit every schema against its documented codec/save projection and planned executable roundtrip; paper examples cannot close native runtime proof.

**Verification and evidence:**

- Independently reproduce dependency and coverage checks against the final assembly.
- Review all five ADRs, per-system access table and schema matrix with no self-approval.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="sc-01"></a>

### SC-01: Specify character and progression definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` from [TH-07](#th-07) (must be admitted before assignment)
- [BIBLE.md § 4. Characters](BIBLE.md#4-characters) (characters, class kits, four slots, binary trees and milestone nodes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-04](#th-04), [TH-07](#th-07). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-01.md`; `artifacts/local/tasks/SC-01/`.

**Definition of done:**

1. Cover only characters, class kits, four slots, binary trees and milestone nodes; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-02"></a>

### SC-02: Specify attack and effect definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-13-chaos-outcomes.md` from [TH-13](#th-13) (must be admitted before assignment)
- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows) (committed attacks, hit geometry, telegraphs, abilities, ultimates and chaos outcomes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-03](#th-03), [TH-04](#th-04), [TH-13](#th-13). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-02.md`; `artifacts/local/tasks/SC-02/`.

**Definition of done:**

1. Cover only committed attacks, hit geometry, telegraphs, abilities, ultimates and chaos outcomes; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-03"></a>

### SC-03: Specify item and recipe definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-08-inventory-equipment-and-transformations.md` from [TH-08](#th-08) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- [BIBLE.md § 5. Weapons & Items](BIBLE.md#5-weapons--items) (items, equipment, modifiers, transformations, attunement and fixed recipes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-08](#th-08), [TH-09](#th-09). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-03.md`; `artifacts/local/tasks/SC-03/`.

**Definition of done:**

1. Cover only items, equipment, modifiers, transformations, attunement and fixed recipes; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-04"></a>

### SC-04: Specify enemy and encounter definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` from [TH-06](#th-06) (must be admitted before assignment)
- [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies) (enemy archetypes, attack references, waves, bosses, encounter admission and objective records)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-06](#th-06). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-04.md`; `artifacts/local/tasks/SC-04/`.

**Definition of done:**

1. Cover only enemy archetypes, attack references, waves, bosses, encounter admission and objective records; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-05"></a>

### SC-05: Specify world and level definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- [BIBLE.md § 3. Maps & Areas](BIBLE.md#3-maps--areas) (regions, areas, level modules, routes, generation constraints, events and secrets)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-11](#th-11), [TH-14](#th-14). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-05.md`; `artifacts/local/tasks/SC-05/`.

**Definition of done:**

1. Cover only regions, areas, level modules, routes, generation constraints, events and secrets; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-06"></a>

### SC-06: Specify device and companion definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-10-devices-and-one-main-companion.md` from [TH-10](#th-10) (must be admitted before assignment)
- [BIBLE.md § Devices and one main companion](BIBLE.md#devices-and-one-main-companion) (devices, companion chassis, interchangeable components and command capabilities)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-10](#th-10). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-06.md`; `artifacts/local/tasks/SC-06/`.

**Definition of done:**

1. Cover only devices, companion chassis, interchangeable components and command capabilities; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-07"></a>

### SC-07: Specify presentation definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- `docs/tech/sections/TH-17-audio-integration.md` from [TH-17](#th-17) (must be admitted before assignment)
- [BIBLE.md § 8. Audio & Feel](BIBLE.md#8-audio--feel) (audio cues, visual references and interface settings)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-12](#th-12), [TH-16](#th-16), [TH-17](#th-17). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-07.md`; `artifacts/local/tasks/SC-07/`.

**Definition of done:**

1. Cover only audio cues, visual references and interface settings; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="sc-08"></a>

### SC-08: Specify narrative and discovery definitions

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06-schema-coverage.md` from [HF-06](#hf-06) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- [BIBLE.md § 9. Glossary](BIBLE.md#9-glossary) (dialogue, glossary entries, discoveries and permanent unlock definitions)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06](#hf-06), [TH-09](#th-09), [TH-11](#th-11). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-08.md`; `artifacts/local/tasks/SC-08/`.

**Definition of done:**

1. Cover only dialogue, glossary entries, discoveries and permanent unlock definitions; identify its HF-06 matrix rows and referenced foreign definitions.
2. For each type specify fields, types, identity/version rules, references, validation diagnostics and one labeled illustrative authored record.
3. Document the mutable save projection or explicit immutable/transient exclusion, with paper roundtrip expectations and an executable qualification obligation.
4. Keep unchosen content and numeric values symbolic and linked to question IDs; examples must not become production canon.

**Verification and evidence:**

- Compare covered matrix rows to the family scope with no orphan type; trace valid, missing-reference and invalid-record cases through admission.
- Review illustrative encode/decode for field and reference preservation. This is schema documentation, not an executed codec.

**Boundary:** One schema-family draft only. No Resources, game code, runtime content or production assets are created.

<a id="lg-01"></a>

### LG-01: Record Andrew lightning playtest feedback

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** legacy browser

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md)
- [docs/LIGHTNING-PLAYGUIDE.md](docs/LIGHTNING-PLAYGUIDE.md)
- [docs/project/INCREMENT-01-lightning-playtest.md](docs/project/INCREMENT-01-lightning-playtest.md)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/project/playtests/lightning-human-feedback.md`; `artifacts/local/tasks/LG-01/`.

**Definition of done:**

1. Record tested revision/device, reward-break and Ground Loop/Echo observations, plus keep/tune decisions on controls, rebounds, density and readability.
2. Distinguish Andrew observation from scripted and native-agent evidence.

**Verification and evidence:**

- Andrew plays the normal orchard through a reward break and records specific behavior; unresolved feedback remains explicit.

**Boundary:** Existing browser proof or maintained player only. Requires a separately admitted work wave; it does not implement the Godot production game. Preserve exact game/controller evidence identity. Andrew supplies play observations; the Verification worker prepares and records the bounded evidence. Lack of participation blocks completion.

<a id="lg-02"></a>

### LG-02: Qualify physical capture and controller on browser proof

**Card revision:** 1 · **Owner:** Rendering/input/UI · **Size:** M · **Lane:** legacy browser

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md)
- [docs/LIGHTNING-VERIFICATION.md § Result and limits](docs/LIGHTNING-VERIFICATION.md#result-and-limits)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/project/playtests/browser-input-hardware.md`; `artifacts/local/tasks/LG-02/`.

**Definition of done:**

1. Record actual device/browser/source identity and outcomes for capture, movement, aim, every caster action, pause/recovery and restart.
2. Record failed/unavailable paths without a controller support claim.

**Verification and evidence:**

- Exercise real mouse capture and selected physical controller through normal menus/gameplay; DOM injection is insufficient.

**Boundary:** Existing browser proof or maintained player only. Requires a separately admitted work wave; it does not implement the Godot production game. Preserve exact game/controller evidence identity.

<a id="lg-03"></a>

### LG-03: Establish player comparison scenarios and baseline

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** legacy browser

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/project/playtests/agent-comparison-protocol.md`; `artifacts/local/agent-comparison-baseline/`; `artifacts/local/tasks/LG-03/`.

**Definition of done:**

1. Pin supported game/controller/configuration/scenario identities and accepted terminal/failure categories.
2. Record repeated current-policy timing, survival, clear time, damage, ability use, stalls and observation/input latency; document metrics unavailable to pixel-only play.

**Verification and evidence:**

- Run focused player checks, project verification and bounded native baseline with fresh leased identities.
- Verify result/config hashes and distinguish ordinary seed 42 from deterministic replay.

**Boundary:** Existing browser proof or maintained player only. Requires a separately admitted work wave; it does not implement the Godot production game. Preserve exact game/controller evidence identity.

<a id="lg-04"></a>

### LG-04: Correct the two confirmed player visual false positives

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** legacy browser

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md)
- `docs/project/playtests/agent-comparison-protocol.md` from [LG-03](#lg-03) (must be admitted before assignment)

**Dependencies:** [LG-03](#lg-03). **Blocking questions:** None.

**Files touched:** `tools/agent-player/vision.py`; `tools/agent-player/tests/test_vision.py`; `tools/agent-player/tests/fixtures/`; `artifacts/local/tasks/LG-04/`.

**Definition of done:**

1. Reproduce conductor-foot and warm-notification false detections from preserved receipts, then prevent these classifications without losing known worker cues.
2. Retain failed examples and compare bounded candidate trials against LG-03.

**Verification and evidence:**

- Focused detector checks use the actual positive and negative captures; run project verification and native matching-scenario comparison.

**Boundary:** Existing browser proof or maintained player only. Requires a separately admitted work wave; it does not implement the Godot production game. Preserve exact game/controller evidence identity.

<a id="lg-05"></a>

### LG-05: Measure bounded player control profiles

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** legacy browser

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md)
- `docs/project/playtests/agent-comparison-protocol.md` from [LG-03](#lg-03) (must be admitted before assignment)

**Dependencies:** [LG-03](#lg-03), [LG-04](#lg-04). **Blocking questions:** None.

**Files touched:** `tools/agent-player/policy.py`; `tools/agent-player/combat.py`; `tools/agent-player/tests/test_policy.py`; `tools/agent-player/tests/test_combat.py`; `docs/project/playtests/player-profiles.md`; `artifacts/local/tasks/LG-05/`.

**Definition of done:**

1. Define bounded strategy differences with unchanged game/controller identities and compare repeated supported scenarios.
2. Report survival, clear time, damage, action use, stalls and latency; keep novice/ordinary/skillful names provisional until human validation.

**Verification and evidence:**

- Run focused/project checks and repeated native baseline/candidate matrix; retain regressions and nonterminal failures rather than selecting only wins.

**Boundary:** Existing browser proof or maintained player only. Requires a separately admitted work wave; it does not implement the Godot production game. Preserve exact game/controller evidence identity.

<a id="lg-07"></a>

### LG-07: Add explicit equipment menu editing

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** legacy browser

**Source and inputs:**

- [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks)
- [tools/agent-player/README.md](tools/agent-player/README.md)
- [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md)
- `docs/project/playtests/agent-comparison-protocol.md` from [LG-03](#lg-03) (must be admitted before assignment)

**Dependencies:** [LG-03](#lg-03). **Blocking questions:** None.

**Files touched:** `tools/agent-player/flow.py`; `tools/agent-player/tests/test_flow.py`; `tools/agent-player/README.md`; `artifacts/local/tasks/LG-07/`.

**Definition of done:**

1. Support equipment checkbox editing through fresh unique semantic targets; preserve existing configured reward selection behavior.
2. Refuse stale/ambiguous observations and preserve neutral cleanup when focus/modal state changes.

**Verification and evidence:**

- Focused menu tests and native equip/unequip/reward/pause paths on exact game build; no assumed auto-equipped state.

**Boundary:** Existing browser proof or maintained player only. Requires a separately admitted work wave; it does not implement the Godot production game. Preserve exact game/controller evidence identity.

## Open questions

These records define missing information and closure evidence. Their live states and answers exist only in TRACKING. They do not ask Andrew to revisit settled architecture or style. Candidate names, A/B/C selections and content quantities explicitly left open by the Bible still require a production selection.

An affected documentation card can record an unknown where its DoD explicitly allows that. The same unknown blocks any future implementation that needs its value. No question below is silently answered by a prototype default or an illustrative schema example. Exact production file ownership is supplied by HF-01/HF-03 and Q-E01 before implementation cards are created.


<a id="q-e01"></a>

### Q-E01: First native qualification scope and paths

**Source:** [adr/TADR-001-engine-language-platforms.md § Later qualification and reconsideration](adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration); [BIBLE.md § Architecture and implementation handoff](BIBLE.md#architecture-and-implementation-handoff)

**Missing information:** Which bounded native qualification slice is approved after the technical handoff, with HF-01/HF-03 path ownership, exact observable acceptance and explicit go?

**Decision owner:** Andrew, with coordinator scope proposal

**Affected work:** TH-29; future native implementation

**Evidence needed to close:** An approved scope record identifies producer-backed files, evidence methods and a separate implementation go; the engine choice remains settled.

<a id="q-e03"></a>

### Q-E03: Hardware, OS support details and budgets

**Source:** [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D28); [adr/TADR-001-engine-language-platforms.md § Later qualification and reconsideration](adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration)

**Missing information:** Which representative Windows/Linux hardware, distributions/drivers and controller devices define qualification, and which measured frame, memory, loading and asset budgets are accepted?

**Decision owner:** Andrew, with Verification measurement proposal

**Affected work:** HF-02; TH-24; future platform qualification

**Evidence needed to close:** Named targets, workloads, measurement protocol and budget rulings exist; unmeasured proposals remain labeled.

<a id="q-e04"></a>

### Q-E04: Renderer and backend qualification

**Source:** [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)

**Missing information:** Which Godot renderer/backend should the first native slice qualify against the approved art and target hardware?

**Decision owner:** Runtime/Rendering recommendation, Andrew scope decision

**Affected work:** HF-02; TH-16; TH-24; future rendering implementation

**Evidence needed to close:** The backend choice and fallback qualification scope are recorded with evidence requirements; no engine/language reevaluation is implied.

<a id="q-e05"></a>

### Q-E05: Browser retention and save import policy

**Source:** [adr/TADR-001-engine-language-platforms.md § Consequences](adr/TADR-001-engine-language-platforms.md#consequences); [adr/TADR-004-persistence.md § Consequences](adr/TADR-004-persistence.md#consequences); [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D27)

**Missing information:** Should any browser profile or discovery data be imported into production, or only preserved as historical proof, and when if ever may either browser entry be retired?

**Decision owner:** Andrew

**Affected work:** HF-09; TH-29; future migration or consolidation

**Evidence needed to close:** An explicit versioned compatibility/retention policy names records and rollback boundaries; both existing entries/data remain preserved meanwhile.

<a id="q-e06"></a>

### Q-E06: Project licensing and distribution terms

**Source:** [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D32); [docs/project/BACKLOG.md](docs/project/BACKLOG.md) (T04); [docs/project/ASSETS.md](docs/project/ASSETS.md)

**Missing information:** Which project license and intended distribution scope apply, and which shipped source assets/dependencies require notices or replacement before release?

**Decision owner:** Andrew with release inventory support

**Affected work:** TH-19; TH-25; future external release

**Evidence needed to close:** Andrew selects project terms and a concrete shipped inventory has verified notices/dispositions; documentation preparation grants no publication authority.

<a id="q-e07"></a>

### Q-E07: Remote publication authorization

**Source:** [docs/project/DECISION-REGISTER.md § Tier A: historical sequence and remaining delivery decisions](docs/project/DECISION-REGISTER.md#tier-a-historical-sequence-and-remaining-delivery-decisions) (D04); [docs/project/BACKLOG.md](docs/project/BACKLOG.md) (T01)

**Missing information:** Which remote, visibility and branches, if any, may receive this local checkout?

**Decision owner:** Andrew

**Affected work:** future repository publication

**Evidence needed to close:** An exact destination and push authorization are recorded before any upload.

<a id="q-e08"></a>

### Q-E08: Browser QA release packaging

**Source:** [docs/project/DECISION-REGISTER.md § Tier A: historical sequence and remaining delivery decisions](docs/project/DECISION-REGISTER.md#tier-a-historical-sequence-and-remaining-delivery-decisions) (D05); [CONTRIBUTING.md § Verification](CONTRIBUTING.md#verification)

**Missing information:** If either browser proof is distributed, should its mutable QA hooks be development-only, part of a separate test build, or explicitly present in release?

**Decision owner:** Andrew with build recommendation

**Affected work:** future browser distribution

**Evidence needed to close:** A packaging ruling identifies both entry bundles and normal/test paths plus their verification before release.

<a id="q-e09"></a>

### Q-E09: Permanent discovery write timing

**Source:** [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D26); [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision)

**Missing information:** Which discovery facts become durable immediately and which wait for a completed-level or terminal commit?

**Decision owner:** Andrew for retention behavior; Persistence for protocol

**Affected work:** HF-07; TH-09; TH-21; future discovery implementation

**Evidence needed to close:** Explicit discovery scenarios name loss/retention behavior and integrate with the single save aggregate without duplicate awards.

<a id="q-e10"></a>

### Q-E10: Encounter attack admission policy

**Source:** [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D15 and D21); [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies)

**Missing information:** For the first selected encounter, what readable overlapping-attack admission policy and pressure limits apply? Completion and objective rules belong to Q-P38.

**Decision owner:** Andrew with encounter designer recommendation

**Affected work:** TH-06; future encounter implementation

**Evidence needed to close:** Andrew approves the attack-overlap and pressure rules for a named encounter fixture, with observable rejection/admission cases.

<a id="q-e11"></a>

### Q-E11: Browser tooling comparison work-wave scope

**Source:** [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks) (Orders 4 and 5); [CONTRIBUTING.md § Handoff and version control](CONTRIBUTING.md#handoff-and-version-control)

**Missing information:** Which browser/tooling work wave and temporary regression fixture may be used for the development comparison, with exact game-file ownership and cleanup criteria?

**Decision owner:** Coordinator scope proposal, Andrew priority/go

**Affected work:** future browser regression-comparison card; future browser tuning

**Evidence needed to close:** A bounded work-wave record supplies exact fixture paths, unchanged baseline identities and regression removal evidence; the Godot production path stays separate.

<a id="q-e12"></a>

### Q-E12: Additional desktop tool coverage

**Source:** [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Ordered work and completion checks](docs/project/AGENT-PLAYTEST-ENGINEERING.md#ordered-work-and-completion-checks) (Order 6)

**Missing information:** Which concrete game-development operation is blocked by missing Godot/editor/Qt/compositor control, if any?

**Decision owner:** Coordinator, Andrew for expanded scope

**Affected work:** future desktop adapter work

**Evidence needed to close:** A reproduced operation identifies the missing toolkit capability and a bounded identity/capture/input/stop qualification; no generic parity programme is implied.

<a id="q-e13"></a>

### Q-E13: Production diagnostics admission

**Source:** [adr/TADR-002-runtime-model.md § Consequences](adr/TADR-002-runtime-model.md#consequences); [adr/TADR-005-networking-scope.md § Decision](adr/TADR-005-networking-scope.md#decision); [docs/project/AGENT-PLAYTEST-ENGINEERING.md § Carry-forward map](docs/project/AGENT-PLAYTEST-ENGINEERING.md#carry-forward-map)

**Missing information:** Which local Godot diagnostic commands and observation paths may future tests use, and which must be absent from distributed builds?

**Decision owner:** Tooling with release review

**Affected work:** TH-26; future native automation adapter

**Evidence needed to close:** An explicit command/access and build-packaging contract distinguishes instrumented diagnostics, native input and player-facing evidence while keeping offline scope.

<a id="q-p01"></a>

### Q-P01: Sable construction

**Source:** [BIBLE_DECISIONS.md § Character direction picks](BIBLE_DECISIONS.md#character-direction-picks)

**Missing information:** If Sable enters the selected production scope, which construction should its production brief use: compact paired winches, offset crane arch, or crescent collar, or an explicitly described revision?

**Decision owner:** Andrew

**Affected work:** Sable model, rig, mounted equipment and animation cards

**Evidence needed to close:** Andrew records the selected construction or removes this candidate from the relevant scope. The working role and protected pilot remain intact.

<a id="q-p02"></a>

### Q-P02: Kest construction

**Source:** [BIBLE_DECISIONS.md § Character direction picks](BIBLE_DECISIONS.md#character-direction-picks)

**Missing information:** If Kest enters the selected production scope, which construction should its production brief use: guarded fans, hoop rotor, or distributed ducts, or an explicitly described revision?

**Decision owner:** Andrew

**Affected work:** Kest model, rig, mounted equipment and animation cards

**Evidence needed to close:** Andrew records the selected construction or removes this candidate from the relevant scope. The working role and protected pilot remain intact.

<a id="q-p03"></a>

### Q-P03: Tarn construction

**Source:** [BIBLE_DECISIONS.md § Character direction picks](BIBLE_DECISIONS.md#character-direction-picks)

**Missing information:** If Tarn enters the selected production scope, which construction should its production brief use: paired piston claws, dominant braced claw, or folding talons, or an explicitly described revision?

**Decision owner:** Andrew

**Affected work:** Tarn model, rig, mounted equipment and animation cards

**Evidence needed to close:** Andrew records the selected construction or removes this candidate from the relevant scope. The working role and protected pilot remain intact.

<a id="q-p04"></a>

### Q-P04: Fuse construction

**Source:** [BIBLE_DECISIONS.md § Character direction picks](BIBLE_DECISIONS.md#character-direction-picks)

**Missing information:** If Fuse enters the selected production scope, which construction should its production brief use: pressure stack, switchboard collar, or cable hoop, or an explicitly described revision?

**Decision owner:** Andrew

**Affected work:** Fuse model, rig, mounted equipment and animation cards

**Evidence needed to close:** Andrew records the selected construction or removes this candidate from the relevant scope. The working role and protected pilot remain intact.

<a id="q-p05"></a>

### Q-P05: Rivet construction

**Source:** [BIBLE_DECISIONS.md § Character direction picks](BIBLE_DECISIONS.md#character-direction-picks)

**Missing information:** If Rivet enters the selected production scope, which construction should its production brief use: optical bench, split yoke, or mirror tower, or an explicitly described revision?

**Decision owner:** Andrew

**Affected work:** Rivet model, rig, mounted equipment and animation cards

**Evidence needed to close:** Andrew records the selected construction or removes this candidate from the relevant scope. The working role and protected pilot remain intact.

<a id="q-p06"></a>

### Q-P06: Playable cast and first production character

**Source:** [BIBLE_DECISIONS.md § Character direction picks](BIBLE_DECISIONS.md#character-direction-picks)

**Missing information:** Which candidates, species and roles enter the initial production scope, and which character supplies the first complete kit? Does that scope retain an animal-only cast?

**Decision owner:** Andrew

**Affected work:** Character production, node content, rigs, expressions, class devices and voice

**Evidence needed to close:** A named bounded roster and first character are recorded, including disposition of Sable, Kest, Tarn, Fuse, Rivet and older Pip/Vane mappings.

<a id="q-p07"></a>

### Q-P07: World catalogue and first production region

**Source:** [BIBLE_DECISIONS.md § World and fiction choices](BIBLE_DECISIONS.md#world-and-fiction-choices)

**Missing information:** Which of the five Bible regions enter production, which older candidates remain available, and which region is built first?

**Decision owner:** Andrew

**Affected work:** Region, enemy, loot, environment, music and level-production cards

**Evidence needed to close:** A named candidate catalogue and first production region are selected without implying route order or catalogue size from the four-world run.

<a id="q-p08"></a>

### Q-P08: Conflict and antagonist canon

**Source:** [BIBLE_DECISIONS.md § World and fiction choices](BIBLE_DECISIONS.md#world-and-fiction-choices)

**Missing information:** Which proposed repair-history and Furnace Fleet premise, motive and antagonist details become canon?

**Decision owner:** Andrew

**Affected work:** Narrative scenes, faction signs, Brindle and boss fiction

**Evidence needed to close:** Andrew accepts or revises the named premise and antagonist, and records whether any finale fiction is selected.

<a id="q-p09"></a>

### Q-P09: Civilization names and relationships

**Source:** [BIBLE_DECISIONS.md § World and fiction choices](BIBLE_DECISIONS.md#world-and-fiction-choices)

**Missing information:** Which Switchback Enclaves, Highdraft Roosts and Redjaw Workshops names, practices and relationships become canon?

**Decision owner:** Andrew

**Affected work:** Culture-specific content and character writing

**Evidence needed to close:** Selected names, practices and relationships are recorded. Species personality and mandatory home biomes remain unconstrained.

<a id="q-p10"></a>

### Q-P10: Material conversion and milestone supply

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** How does recovered material support earned upgrades: what costs, supply guarantees and visible mass changes apply, if any?

**Decision owner:** Andrew

**Affected work:** Economy tuning, fabrication, milestone rewards and content budgets

**Evidence needed to close:** An explicit material rule and supply policy support opening-world slot access and all four endpoints by the final boss without elapsed-time gates.

<a id="q-p11"></a>

### Q-P11: Character node content and input-to-slot mapping

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** For the first selected character, what effects belong to its four trees, what node costs and milestones apply, and how do the prototype two combat abilities and devices map into the four slots?

**Decision owner:** Andrew

**Affected work:** Character kit and four separate tree-content cards

**Evidence needed to close:** The selected character has an approved slot/action mapping and node-effect scope. Any unchosen costs and milestones remain separately gated. Binary topology is retained.

<a id="q-p12"></a>

### Q-P12: Route policy and final encounter placement

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** What starting-world, repeat and destination-eligibility rules, levels-per-world allocation and final-encounter placement apply?

**Decision owner:** Andrew

**Affected work:** Run routing, level content budgets and final encounter

**Evidence needed to close:** A route policy specifies legal starting and subsequent worlds, repeat handling, level counts and whether world four boss is the finale. Four worlds and two destination offers remain fixed.

<a id="q-p13"></a>

### Q-P13: Chaos elements and miscast limits

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** Which elements and effects can the chaos kit produce, which actions can miscast, and what frequency, severity and warning rules bound harmful or inconvenient failures?

**Decision owner:** Andrew

**Affected work:** Chaos outcomes, warnings, audio, safety of mobility and kit tuning

**Evidence needed to close:** The pool, eligibility, outcome limits and warning policy are explicit. Directed attacks normally work as intended and no instability meter is inferred.

<a id="q-p14"></a>

### Q-P14: Loot attunement and fixed secret recipes

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** Which item and endpoint combinations are eligible, what fixed bonuses or harmful tradeoffs apply, and what does the player learn before and after discovery?

**Decision owner:** Andrew

**Affected work:** Item compatibility, recipe content, discovery UI and profile knowledge

**Evidence needed to close:** An initial bounded item/recipe set and eligibility/disclosure rules are recorded. Recipe results stay fixed and active bonuses require the current eligible build.

<a id="q-p15"></a>

### Q-P15: Companion assembly and device lifecycle

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** What companion chassis/components, autonomous support and commands apply, and what device capacity, lifetime, recall, resource and cross-level persistence rules apply?

**Decision owner:** Andrew

**Affected work:** Companion and device content, lifecycle and dashboard controls

**Evidence needed to close:** One main companion remains the anchor. Assembly, commands, recall and persistence rules are explicit without inheriting prototype caps.

<a id="q-p16"></a>

### Q-P16: Revival and unfinished-level interruption

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** What health and placement follow the single standard revival, and what happens when the player quits or crashes inside an unfinished level?

**Decision owner:** Andrew

**Affected work:** Revival presentation, run checkpoint behavior and interrupted-level recovery

**Evidence needed to close:** Health, placement and interrupted-level policy are recorded without replenishing spent revival or duplicating rewards. Completed-level resume remains the next entrance.

<a id="q-p17"></a>

### Q-P17: Production music state and transition details

**Source:** [BIBLE_DECISIONS.md § Sound and presentation proposal](BIBLE_DECISIONS.md#sound-and-presentation-proposal)

**Missing information:** Within the approved dry physical instrumentation, workshop percussion, restrained synthesis and regional direction, which music states, transition triggers and interruption rules should the first production score support?

**Decision owner:** Andrew

**Affected work:** Music state content, transitions and TH-17 integration; the approved sound palette remains fixed.

**Evidence needed to close:** Andrew approves a bounded music-state and transition list tied to the first production scope; Q-P31 separately fixes the asset batch and audition method.

<a id="q-p18"></a>

### Q-P18: Respec opportunity rules

**Source:** [BIBLE.md § Four slots and milestone progression](BIBLE.md#four-slots-and-milestone-progression)

**Missing information:** What grants respec access, how often can it occur, which branches can change, and what refund and presentation rules apply?

**Decision owner:** Andrew

**Affected work:** Respec gameplay, resource policy and dashboard states

**Evidence needed to close:** The opportunity, scope, frequency and refunds are explicit. Between-fight equipment swaps do not grant tree respec.

<a id="q-p19"></a>

### Q-P19: Inventory limits and equipment replacement

**Source:** [BIBLE.md § Inventory, equipment and transformations](BIBLE.md#inventory-equipment-and-transformations)

**Missing information:** What inventory capacity, equipped-item limits, replacement rules and stacking compatibility should the initial item system use?

**Decision owner:** Andrew

**Affected work:** Inventory content, equipment UI and derived-effect rules

**Evidence needed to close:** Capacity, equip limits, replacement behavior and effect composition are specified separately from the four progression slots.

<a id="q-p20"></a>

### Q-P20: Class cadence and ultimate earning

**Source:** [BIBLE.md § Abilities, ultimates and combat rhythm](BIBLE.md#abilities-ultimates-and-combat-rhythm)

**Missing information:** For the first selected kit, what useful actions charge the ultimate, and what cooldown, charge, duration and recovery targets need tuning?

**Decision owner:** Andrew

**Affected work:** Ability and ultimate content and playtest acceptance

**Evidence needed to close:** The first kit has explicit charge events and measurable provisional cadence targets with playtest criteria, without universalizing prototype numbers.

<a id="q-p21"></a>

### Q-P21: Production movement and defensive rhythm

**Source:** [docs/DISCOVERY.md § Publisher direction](docs/DISCOVERY.md#publisher-direction)

**Missing information:** Which class movement interactions and baseline defensive responses belong in the first production kit, and what observations establish acceptable handling and camera comfort?

**Decision owner:** Andrew

**Affected work:** Movement, focused aim, defense, jumping, rebounds and physical controller playtests

**Evidence needed to close:** A bounded movement/defense scope and human acceptance procedure are recorded. Existing rolling, ordinary movement and active aim remain established.

<a id="q-p22"></a>

### Q-P22: Physical growth envelope and transformative scope

**Source:** [BIBLE.md § Movement, camera and active aim](BIBLE.md#movement-camera-and-active-aim)

**Missing information:** What ordinary growth envelope must production routes accommodate, and which optional movement or attack transformations enter the first content scope?

**Decision owner:** Andrew

**Affected work:** Route clearance, chassis growth, camera, mounted tools and transformation assets

**Evidence needed to close:** Ordinary bounds and admitted transformations are explicit. Literal giant forms and terrain alteration are either selected with bounds or parked.

<a id="q-p23"></a>

### Q-P23: Procedural level technique and encounter scope

**Source:** [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D08); [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves); [docs/LEVEL-DESIGN.md § Procedural generation technique (open)](docs/LEVEL-DESIGN.md#procedural-generation-technique-open)

**Missing information:** Which seeded generation technique and initial spatial/content module set should the production generator use? Name the approved encounter/terrain fixtures that establish correctness.

**Decision owner:** Andrew, with runtime/level recommendation

**Affected work:** Generator implementation, authored layouts and terrain kits

**Evidence needed to close:** Andrew selects the initial technique and bounded content set against clearance, readable encounters and replay variety. Fixed historical pocket sequences are not inherited.

<a id="q-p24"></a>

### Q-P24: World terrain and consequence mechanics

**Source:** [BIBLE.md § 3. Maps & Areas](BIBLE.md#3-maps--areas)

**Missing information:** For the first selected region, which proposed water, grip, rail, dune, destructible and terrain-changing encounter interactions enter production?

**Decision owner:** Andrew

**Affected work:** Environment interaction, destructibles, navigation and arena content

**Evidence needed to close:** Selected interactions, non-selected proposals and route-preservation requirements are recorded for a named region.

<a id="q-p25"></a>

### Q-P25: Enemy and boss production roster

**Source:** [docs/ENEMY-ROSTER.md § World library and encounter rewards](docs/ENEMY-ROSTER.md#world-library-and-encounter-rewards)

**Missing information:** Which named workers, pressure roles, veterans, minibosses and complete bosses enter the first production region, and which proposed defensive grades or immunity rules apply?

**Decision owner:** Andrew

**Affected work:** Enemy cards, boss phases, attacks, loot and occupational-reference qualification

**Evidence needed to close:** A bounded named roster and accepted attack/defense grammar are recorded. One implemented Pruner arm does not select the complete Grand Pruner or historical build order.

<a id="q-p26"></a>

### Q-P26: Production art batch and runtime budgets

**Source:** [COHESION_REPORT.md § Contradictions, persistent outliers and limits](COHESION_REPORT.md#contradictions-persistent-outliers-and-limits)

**Missing information:** Which selected pilot, chassis, mounted tools, growth states, enemies and environment modules form the first authored asset batch, and what measured budget constrains it?

**Decision owner:** Andrew

**Affected work:** Models, textures, rigs, attachment sizing, material/lighting work and import checks

**Evidence needed to close:** A bounded asset manifest, review views, target budget source and allowed output paths are recorded before production assets become runnable cards.

<a id="q-p27"></a>

### Q-P27: Rolling articulation and fabrication motion

**Source:** [BIBLE.md § Make fabrication visible](BIBLE.md#make-fabrication-visible)

**Missing information:** Which motion treatment should the selected mech use for the irregular rolling core, stable cockpit, retracting equipment and visible intake-to-fabrication sequence?

**Decision owner:** Andrew

**Affected work:** Rig, animation, mounting geometry and upgrade transitions

**Evidence needed to close:** A selected motion brief identifies moving and stable parts, required action phases and ordinary route clearance. Still-art tread forms do not decide articulation.

<a id="q-p28"></a>

### Q-P28: Supporting cast and narrative content budget

**Source:** [docs/CHARACTER-BIBLE.md § Supporting cast and the Scrapbook voice](docs/CHARACTER-BIBLE.md#supporting-cast-and-the-scrapbook-voice); [BIBLE.md § 4.6 Supporting cast and relationships](BIBLE.md#46-supporting-cast-and-relationships)

**Missing information:** Which supporting characters, optional exchanges, Scrapbook author, entries, barks and interstitials enter the initial scope, with what text and voice budgets?

**Decision owner:** Andrew

**Affected work:** Moss/Brindle/overseer art, dialogue, bark variants and narrative UI

**Evidence needed to close:** A named supporting cast and bounded writing/voice inventory replace old four-pilot, five-overseer and fixed-campaign assumptions.

<a id="q-p29"></a>

### Q-P29: Companion appearance and naming

**Source:** [docs/CHARACTER-BIBLE.md § Companions](docs/CHARACTER-BIBLE.md#companions)

**Missing information:** For the selected main companion assembly, which chassis personality, module silhouettes, naming and expression conventions are approved? Distinguish a chassis-type epithet from an assembled-instance name so UI and saves identify each consistently.

**Decision owner:** Andrew

**Affected work:** Companion turnaround, module-swap animation, naming and UI content

**Evidence needed to close:** Selected appearance and naming rules accompany the assembly contract. SNIP-3/Nibbles and three old module states remain proposals.

<a id="q-p30"></a>

### Q-P30: Production HUD, input and accessibility scope

**Source:** [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings)

**Missing information:** What production viewing distances, target display sizes, controller mappings, remapping and accessibility settings must the initial interface support?

**Decision owner:** Andrew

**Affected work:** HUD/dashboard layout, settings, focus, text, input and hardware acceptance

**Evidence needed to close:** Targets and acceptance methods are explicit, including keyboard/controller navigation, accidental-cast prevention, UI scale, sound and motion settings.

<a id="q-p31"></a>

### Q-P31: Audio asset and audition scope

**Source:** [BIBLE.md § 8. Audio & Feel](BIBLE.md#8-audio--feel)

**Missing information:** Which music states, regional arrangements, action cues and ambience comprise the first sound batch, and what source method, voice policy, duration and audition setup apply?

**Decision owner:** Andrew

**Affected work:** Audio generation/recording, licenses, mix, transitions and fatigue review

**Evidence needed to close:** A bounded sound manifest and listening procedure are selected, including starting kit, dense combat, exceptional build, quiet playback and sound-disabled warnings.

<a id="q-p32"></a>

### Q-P32: Camera response and mix settings

**Source:** [BIBLE.md § Spectacle that leaves room to play](BIBLE.md#spectacle-that-leaves-room-to-play)

**Missing information:** What bounds should impact response, shake, recoil, overlap priority, reduced motion and dynamic range use in the first feel pass?

**Decision owner:** Andrew

**Affected work:** Camera and audio tuning, settings and comfort review

**Evidence needed to close:** Provisional limits and observable threat-readability/comfort criteria are recorded for the selected kit and target setup.

<a id="q-p33"></a>

### Q-P33: Regional lighting, weather and wayfinding

**Source:** [docs/WORLD-ENVIRONMENTS.md § Shared world systems](docs/WORLD-ENVIRONMENTS.md#shared-world-systems)

**Missing information:** For admitted regions, which lighting/weather behavior, civic signs, faction notices and route landmarks enter production?

**Decision owner:** Andrew

**Affected work:** Lighting keyframes, weather effects, signs and environment props

**Evidence needed to close:** A per-region bounded brief follows approved Southwest ecology and readable workshop instrumentation. Historical matte palette and numbered fixed-campaign signs are not inherited.

<a id="q-p34"></a>

### Q-P34: Figurine companion-product scope

**Source:** [docs/audit-2026-09-05/worker-4-universe.md § 5. Figurine-readiness](docs/audit-2026-09-05/worker-4-universe.md#5-figurine-readiness)

**Missing information:** Should figurine work remain parked or receive a bounded design scope, and if selected which character, size, parts, material and physical validation method apply?

**Decision owner:** Andrew

**Affected work:** Print master, part separation, biome base, tolerances and physical test

**Evidence needed to close:** Andrew parks the product or selects one figure and review/physical acceptance scope. Old 60 mm Pip, 3 mm features and runtime/print shared-source claims remain proposals.

<a id="q-p35"></a>

### Q-P35: Next player and demand evidence

**Source:** [docs/MARKET-RESEARCH.md § Research team and next evidence](docs/MARKET-RESEARCH.md#research-team-and-next-evidence)

**Missing information:** Which next evidence question merits a bounded study: human movement/camera comfort, long-run readability and pacing, solo device workload, or prospective-player demand?

**Decision owner:** Andrew

**Affected work:** Participant plan, prototype playtest and market study

**Evidence needed to close:** Andrew selects a named decision, audience, method and scope. No outreach, purchase or demand claim follows from the dated review sample.

<a id="q-p36"></a>

### Q-P36: Occupational-reference qualification scope

**Source:** [docs/ENEMY-ROSTER.md § Evidence limits](docs/ENEMY-ROSTER.md#evidence-limits)

**Missing information:** Which admitted inference-only or ungrounded enemy additions need occupational-reference qualification? Reconcile the admitted names rather than inheriting the old contradictory count of 13.

**Decision owner:** Andrew

**Affected work:** Source qualification and grounded enemy content

**Evidence needed to close:** The selected named enemy list has dated primary occupational sources or explicit inference labels; reconcile the roster-count discrepancy and any missing grounding tag before admission.

<a id="q-p37"></a>

### Q-P37: Permanent option and challenge content

**Source:** [docs/DISCOVERY.md § Defeat, saving and permanent progression](docs/DISCOVERY.md#defeat-saving-and-permanent-progression)

**Missing information:** Which classes, items, companion parts, discoveries and challenges unlock between runs, and what initial eligibility and discovery presentation apply? Specify which offers, sightings, declined drops and demonstrated behaviors create discovery facts; Q-E09 owns their durable write timing.

**Decision owner:** Andrew

**Affected work:** Profile content, unlock conditions, Scrapbook and run-entry options

**Evidence needed to close:** A bounded permanent-option inventory and unlock rules are recorded. Combat power still resets and permanent stat advantage is excluded.

<a id="q-p38"></a>

### Q-P38: Events, secrets and defense objective content

**Source:** [docs/LEVEL-DESIGN.md § Defense arena patterns (proposal)](docs/LEVEL-DESIGN.md#defense-arena-patterns-proposal)

**Missing information:** Which event, secret-room, branch and defense-objective types enter the first region, and what completion, failure, reward and reconfiguration boundaries apply?

**Decision owner:** Andrew

**Affected work:** Event and defense encounters, reward content, branch layouts and intermission UI

**Evidence needed to close:** Each selected type has an explicit objective/reward boundary and required route accessibility. Historical timers and counter-only entry requirements remain proposals.

## Source dispositions

The following cross-reference preserves every P/T/R/D/BD identifier, plus unnumbered planning obligations, core-system headings, selected concept-art receipts and the requested engineering sections. “Completed” means only the specific historical decision, concept correction or version-qualified proof described in that row. It grants no new task completion, native support claim or implementation authorization.

Source identity is retained in the [preparation manifest](artifacts/swarm-prep-2026-09-06/verification.json). Named proof reports remain authoritative for their own source/configuration and method. The [old backlog](docs/project/BACKLOG.md) is dated history; its original body is preserved. Duplicate and parked rows retain their reason so a future worker does not recreate old work.

### Historical identifiers

| Source ID | Record | Disposition | Task/question reference | Scope and evidence |
| --- | --- | --- | --- | --- |
| P01 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | completed | None | docs/project/INCREMENT-01-lightning-playtest.md records Andrew original orchard play and concrete control/physics/UI feedback. No duration was recorded; this does not close the new P10 playtest. |
| P02 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [LG-01](#lg-01) | Retain encounter pacing/circling assessment inside Andrew current lightning feedback. Any tuning needs a separate scoped browser wave; 41.96-second scripted clear in docs/LIGHTNING-VERIFICATION.md is not human balance. |
| P03 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [LG-02](#lg-02) | Physical hardware qualification remains distinct from synthetic DOM and native-agent input evidence. |
| P04 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | completed | None | docs/project/INCREMENT-01-lightning-playtest.md records the approved increment and docs/LIGHTNING-VERIFICATION.md records executed local/browser checks. Approval/completion is limited to the lightning prototype. |
| P05 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | parked | None | adr/TADR-001-engine-language-platforms.md excludes mobile from initial Windows/Linux production scope. Revisit only for new approved platform scope. |
| P06 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-P06](#q-p06), [Q-P07](#q-p07), [Q-P08](#q-p08), [Q-P09](#q-p09) | Current Bible candidate cast/world/fiction decisions replace automatic admission of older research candidates. Product lane owns precise candidate follow-ups. |
| P07 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-P23](#q-p23), [Q-P07](#q-p07), [Q-P12](#q-p12) | Seeded procedural levels are accepted; technique and selected production world/route remain separate decisions. |
| P08 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [TH-23](#th-23), [TH-26](#th-26) | Generated-level telemetry becomes a production verification/tooling contract. Old browser telemetry implementation cannot run without a selected generated-level scope and Q-E01 handoff. |
| P09 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | parked | None | D02 mass/deflect foundation was not adopted. docs/audit-2026-09-05/worker-2-combat.md retains the Sluiceback experiment if a future deflect increment is explicitly selected. |
| P10 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [LG-01](#lg-01) | Current human feedback remains open; docs/LIGHTNING-VERIFICATION.md separates technical proof from controls, density and readability judgments. |
| P11 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [TH-07](#th-07) | Bounded progression contract has Q-P10/Q-P11 product gaps; binary tree topology is settled. Product design values remain missing, not implemented by a technical page. |
| P12 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [TH-11](#th-11), [TH-14](#th-14), [HF-07](#hf-07), [HF-08](#hf-08) | Run/route/save design decomposes into explicit contracts. Q-P12/Q-P16 and Q-P23 retain missing product/generation rules. |
| P13 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [TH-08](#th-08), [TH-09](#th-09) | Inventory/loot/fixed recipe contracts are separate; Q-P14 retains eligibility/recipe/disclosure choices. |
| P14 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [TH-13](#th-13) | Chaos commitment contract is separate from Q-P13 tuning and Q-P06 production cast selection. Creative notebook inventions remain product scope. |
| T01 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-E07](#q-e07) | Local Git history exists; no remote publication is authorized by preparation. CONTRIBUTING.md records baseline 4db9b31 and explicit remote gate. |
| T02 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-E08](#q-e08) | Browser QA packaging remains relevant only to distribution of the two browser proofs; it is separate from production Godot diagnostics. |
| T03 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [HF-02](#hf-02), [TH-24](#th-24) | Record measured browser RTX 4080 evidence and design named-hardware native qualification. Q-E03 retains target/budget choice; existing sixty-second result is not full-world proof. |
| T04 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-E06](#q-e06) | A source license and concrete shipped-asset notices remain release inputs; local metadata alone is insufficient. |
| T05 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [HF-06](#hf-06), [HF-07](#hf-07), [HF-08](#hf-08), [HF-09](#hf-09), [TH-21](#th-21) | Split checkpoint/profile work into coverage, commit, recovery, migration and schema examples; browser data preservation remains mandatory and import policy is Q-E05. |
| T06 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-E10](#q-e10) | Old browser lane-aware implementation has no selected defense encounter. TH-06 owns native design once its encounter context is supplied. |
| T07 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-P23](#q-p23), [Q-E01](#q-e01) | Old z-only browser groundHeight task is not a known Godot code task. TH-15 owns collision qualification; selected terrain/production paths must precede implementation. |
| T08 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-P36](#q-p36) | The admitted inference-only or ungrounded enemy additions need dated occupational sources or inference relabeling before admission; product lane owns candidate source-grounding inventory. |
| T09 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | parked | [Q-P06](#q-p06), [Q-E05](#q-e05) | Existing browser portrait keep/redraw work depends on selected cast and whether browser proofs remain product-facing. Preserve existing assets until that scope is selected. |
| T10 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [TH-16](#th-16), [TH-24](#th-24) | Readability qualification follows approved Bible art and selected renderer/hardware. Historical Furnace City floor test is not automatically a production content task. |
| T11 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | question | [Q-P23](#q-p23), [Q-E01](#q-e01) | Reusable orchard browser pockets depend on old generation assumptions. Native generation/content contracts must establish actual assets and paths before implementation. |
| T12 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | superseded | [Q-P17](#q-p17), [TH-17](#th-17) | BIBLE.md Audio & Feel now supplies a concrete sound direction proposal. Product decision Q-P17 and engine integration TH-17 retain remaining work; no recorded sound/mix is proven. |
| T13 | [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | task | [LG-03](#lg-03), [LG-04](#lg-04), [LG-05](#lg-05), [Q-E11](#q-e11), [LG-07](#lg-07), [Q-E12](#q-e12) | docs/project/AGENT-PLAYTEST-ENGINEERING.md and artifacts/agent-recovery-2026-09-06/README.md establish runner, semantic flow, versioned evidence and bounded recovery. Profiles, known perception errors, arbitrary equipment and regression comparisons remain. Three terminal trials do not establish human skill or Godot compatibility. |
| D01 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | [LG-01](#lg-01) | Implemented lightning increment superseded the mass-first four-increment sequence; later build still needs scoped go. Source: docs/project/DECISION-REGISTER.md row D01. |
| D02 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Mass penalties, Roll-Through and Shed Vent were not adopted; retained combat paper is historical research. Source: docs/project/DECISION-REGISTER.md row D02. |
| D03 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-02](#th-02), [TH-08](#th-08) | BIBLE.md Movement and Inventory retain playful movement and optional transformations. This completes direction only, not production mechanics. Source: docs/project/DECISION-REGISTER.md row D03. |
| D04 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E07](#q-e07) | Exact remote and upload authorization remain open. Source: docs/project/DECISION-REGISTER.md row D04. |
| D05 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E08](#q-e08) | Separate historical browser QA packaging from future production diagnostics. Source: docs/project/DECISION-REGISTER.md row D05. |
| D06 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P07](#q-p07), [Q-P08](#q-p08) | Approved Bible retains candidate catalogue and Furnace Fleet premise choices; fixed campaign order is superseded. Source: docs/project/DECISION-REGISTER.md row D06. |
| D07 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-01](#th-01), [TH-11](#th-11) | BIBLE.md Complete loop and Runs retain four-world 60–75 minute target. No full run or human timing proof exists. Source: docs/project/DECISION-REGISTER.md row D07. |
| D08 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P23](#q-p23) | Seeded procedural direction remains settled; generation technique is unresolved. Source: docs/project/DECISION-REGISTER.md row D08. |
| D09 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P12](#q-p12) | Catalogue/repeat/first-world/final-encounter choices remain under current Bible. Source: docs/project/DECISION-REGISTER.md row D09. |
| D10 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P07](#q-p07), [Q-E01](#q-e01) | Next authored kit must be chosen from current production catalogue and scoped implementation; old paper recommendation is not selection. Source: docs/project/DECISION-REGISTER.md row D10. |
| D11 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Glassjaw/Old Ironroot Yard Commons placement was never accepted. Current BIBLE.md area catalogue does not canonize those historical moves; reopen only with selected enemy content. Source: docs/project/DECISION-REGISTER.md row D11. |
| D12 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Kiln Strider/Harvest Roads association belongs to an older unselected world candidate; retain ENEMY-ROSTER.md proposal. Source: docs/project/DECISION-REGISTER.md row D12. |
| D13 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Jettling admission is an old Spillway roster proposal, not selected production content; retain ENEMY-ROSTER.md grounding requirement. Source: docs/project/DECISION-REGISTER.md row D13. |
| D14 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Furnace City reprise/native mix depends on a world absent from the current five-area comparison set. No old increment-2 implementation is authorized. Source: docs/project/DECISION-REGISTER.md row D14. |
| D15 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E10](#q-e10) | No universal concurrency cap is selected; evaluate explicit readable encounter admission. Source: docs/project/DECISION-REGISTER.md row D15. |
| D16 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Graftmender device-binding extension is an unadopted roster mechanic, not an existing engine defect. Source: docs/project/DECISION-REGISTER.md row D16. |
| D17 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P06](#q-p06) | Creative development is delegated; production cast/species selection remains explicit. Source: docs/project/DECISION-REGISTER.md row D17. |
| D18 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P17](#q-p17), [Q-P31](#q-p31) | Current Audio & Feel proposal does not settle bark count, recorded voice or combat text; product audio decision must preserve this residual detail. Source: docs/project/DECISION-REGISTER.md row D18. |
| D19 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P33](#q-p33) | Approved place-based lighting style does not by itself select fixed keyframes versus dynamic weather/day-night. Product lane must retain this residual presentation choice. Source: docs/project/DECISION-REGISTER.md row D19. |
| D20 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | task | [TH-16](#th-16), [TH-24](#th-24) | Approved Art Direction supersedes the older grim/matte palette premise; actual dark-ground threat readability still requires rendering/hardware qualification. Source: docs/project/DECISION-REGISTER.md row D20. |
| D21 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E10](#q-e10) | Timed-defense completion depends on selected encounter scope. Source: docs/project/DECISION-REGISTER.md row D21. |
| D22 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | [Q-P24](#q-p24), [Q-P25](#q-p25) | Rowkeeper trellis/miniboss and persistent arena alteration are older unselected encounter proposals. No current save schema silently adopts persistent terrain effects. Source: docs/project/DECISION-REGISTER.md row D22. |
| D23 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | [Q-P37](#q-p37), [Q-P38](#q-p38) | Scrapbook-only branch gating is a historical optional-content proposal, not an accepted route rule. Source: docs/project/DECISION-REGISTER.md row D23. |
| D24 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [HF-07](#hf-07), [TH-11](#th-11) | BIBLE.md Runs explicitly fixes completed-level next-entrance resume. This ruling does not prove save implementation. Source: docs/project/DECISION-REGISTER.md row D24. |
| D25 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P14](#q-p14) | Reward counts/cadence and seen/declined discovery ledger detail remain part of loot/disclosure design. Source: docs/project/DECISION-REGISTER.md row D25. |
| D26 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E09](#q-e09) | Aggregate ownership does not settle publisher discovery retention timing. Source: docs/project/DECISION-REGISTER.md row D26. |
| D27 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | task | [HF-06](#hf-06), [HF-07](#hf-07), [HF-08](#hf-08), [HF-09](#hf-09), [TH-21](#th-21) | Production schema/compatibility work is decomposed; Q-E05 separately gates any browser import or retirement. Source: docs/project/DECISION-REGISTER.md row D27. |
| D28 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E03](#q-e03) | Historical RTX 4080 browser sample is not an accepted native minimum or budget. Source: docs/project/DECISION-REGISTER.md row D28. |
| D29 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | [HF-01](#hf-01) | Accepted TADR-001 settles Godot 4.7.2 standard/typed GDScript and Windows/Linux intent. Older engine-open trigger is stale; qualification remains future. Source: docs/project/DECISION-REGISTER.md row D29. |
| D30 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | [TH-15](#th-15) | Accepted TADR-002 uses engine-native physical world with one collision-query owner. No browser physics-library or extra dependency evaluation is currently scoped. Source: docs/project/DECISION-REGISTER.md row D30. |
| D31 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Accepted TADR-001 excludes mobile from initial production scope; touch is outside current browser increment. Source: docs/project/DECISION-REGISTER.md row D31. |
| D32 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-E06](#q-e06) | Project/source-asset redistribution terms and notices require explicit release review. Source: docs/project/DECISION-REGISTER.md row D32. |
| D33 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P08](#q-p08) | Fleet motive and antagonist truthfulness remain a fiction choice; current premise does not select the old binary wording. Source: docs/project/DECISION-REGISTER.md row D33. |
| D34 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [Q-P06](#q-p06) | D57 delegates labeled creative treatment of the unclear sketch. Transcription and automatic roster admission are not established. Source: docs/project/DECISION-REGISTER.md row D34. |
| D35 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | First Stoker Damper defection is an older unselected Furnace City narrative beat. Preserve as research until that content is requested. Source: docs/project/DECISION-REGISTER.md row D35. |
| D36 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | [Q-P06](#q-p06), [Q-P13](#q-p13) | Accepted notebook interpretation replaces earlier lightning-only keep/adapt/park framing. No compulsory learning service or drone role. Source: docs/project/DECISION-REGISTER.md row D36. |
| D37 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Furnace City crew-rescue finale remains an older candidate beat; current Bible does not select a fixed finale. Source: docs/project/DECISION-REGISTER.md row D37. |
| D38 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | None | Old Windworks mint exception is tied to superseded matte/palette assumptions and an unselected world. Current BIBLE.md approved Art Direction owns production styling. Source: docs/project/DECISION-REGISTER.md row D38. |
| D39 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | parked | None | Harvest Roads cargo destruction/protection remains an older unselected-world narrative/mechanical proposal. Source: docs/project/DECISION-REGISTER.md row D39. |
| D40 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | None | DECISION-REGISTER.md Current rulings explicitly says D40 does not block approved Bible art. Browser palette remains historical until scoped change. Source: docs/project/DECISION-REGISTER.md row D40. |
| D41 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | superseded | None | DECISION-REGISTER.md Current rulings explicitly says D41 does not block approved Bible art. Matte-only premise is superseded. Source: docs/project/DECISION-REGISTER.md row D41. |
| D42 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-02](#th-02), [TH-05](#th-05), [TH-16](#th-16) | BIBLE.md Movement and Growth require ordinary route clearance and readable growing machinery; no universal giant transformation or mass gate is implied. Physical qualification remains future. Source: docs/project/DECISION-REGISTER.md row D42. |
| D43 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P15](#q-p15) | Cooldown/two-conductor limit is implemented only in lightning; production capacity/resource/ownership remains the explicit device lifecycle gap. Source: docs/project/DECISION-REGISTER.md row D43. |
| D44 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P15](#q-p15) | Lifetime, replacement, recall and cross-level device persistence remain open. Source: docs/project/DECISION-REGISTER.md row D44. |
| D45 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-04](#th-04), [TH-10](#th-10) | BIBLE.md Abilities retains useful moving combat and quick autonomous support without a stationary build screen. Exact class triggers and automation remain content work. Source: docs/project/DECISION-REGISTER.md row D45. |
| D46 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-08](#th-08) | BIBLE.md Inventory accepts full optional transformations and safe effective-build reconstruction. Exact item behaviors remain open. Source: docs/project/DECISION-REGISTER.md row D46. |
| D47 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P15](#q-p15) | One main companion is settled; component assembly, commands and lifecycle remain open. Prototype primer is limited proof. Source: docs/project/DECISION-REGISTER.md row D47. |
| D48 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-06](#th-06) | BIBLE.md Abilities and Encounters retains earned dominance and readable spatial challenge. Enemy counts/counterplay and final balance remain unqualified. Source: docs/project/DECISION-REGISTER.md row D48. |
| D49 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-11](#th-11) | D49 and BIBLE.md Runs settle two eligible destination offers and reference boundaries. Catalogue/route policy remains Q-P12. Source: docs/project/DECISION-REGISTER.md row D49. |
| D50 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-07](#th-07), [TH-20](#th-20) | BIBLE.md Four slots settles four trees and 1/2/4/8 binary topology. No final character/node catalogue is implemented. Source: docs/project/DECISION-REGISTER.md row D50. |
| D51 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-07](#th-07) | BIBLE.md Four slots settles weapon/mobility entry access, world-one hero/ultimate unlock and gameplay milestones. Costs/supply remain Q-P10/Q-P11. Source: docs/project/DECISION-REGISTER.md row D51. |
| D52 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-07](#th-07), [TH-08](#th-08), [Q-P18](#q-p18) | BIBLE.md separates special tree respec from between-fight equipment freedom. Special opportunity scope/refund/frequency remain product design. Source: docs/project/DECISION-REGISTER.md row D52. |
| D53 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-09](#th-09) | BIBLE.md Loot settles world-themed random acquisition and attunement direction; exact items and compatibility remain Q-P14. Source: docs/project/DECISION-REGISTER.md row D53. |
| D54 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [TH-09](#th-09) | BIBLE.md fixed-secret eligibility is deterministic from selected endpoints. Recipes/disclosure remain Q-P14 and executable behavior remains absent. Source: docs/project/DECISION-REGISTER.md row D54. |
| D55 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [HF-07](#hf-07), [HF-08](#hf-08), [TH-11](#th-11) | BIBLE.md Runs fixes one standard revival, terminal second death and rebuild-each-run power. No production durability proof exists. Source: docs/project/DECISION-REGISTER.md row D55. |
| D56 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P13](#q-p13), [TH-13](#th-13) | Directed fire, automatic short field and occasional harmful multi-effect miscasts are accepted; tuning and warning design remain unresolved. Source: docs/project/DECISION-REGISTER.md row D56. |
| D57 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | completed | [Q-P06](#q-p06) | D57 and BIBLE.md approval delegate labeled creative development without automatic production roster or learning-system approval. Source: docs/project/DECISION-REGISTER.md row D57. |
| D58 | [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | question | [Q-P16](#q-p16) | Revival health/placement and unfinished-level interruption policy remain explicit, while no-reroll/no-duplicate invariants are settled. Source: docs/project/DECISION-REGISTER.md row D58. |
| BD-01 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P01](#q-p01) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-02 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P02](#q-p02) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-03 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P03](#q-p03) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-04 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P04](#q-p04) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-05 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P05](#q-p05) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-06 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P06](#q-p06) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-07 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P07](#q-p07) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-08 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P08](#q-p08) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-09 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P09](#q-p09) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-10 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P10](#q-p10) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-11 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P11](#q-p11) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-12 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P12](#q-p12) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-13 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P13](#q-p13) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-14 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P14](#q-p14) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-15 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P15](#q-p15) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-16 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P16](#q-p16) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| BD-17 | [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | question | [Q-P17](#q-p17) | The approved Bible preserves this explicit content choice. No answer is inferred from illustrations or product approval. |
| R01 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P21](#q-p21), [Q-P22](#q-p22), [Q-P26](#q-p26), [Q-P27](#q-p27) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R02 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P21](#q-p21), [Q-P22](#q-p22), [Q-P30](#q-p30) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R03 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P21](#q-p21), [Q-P25](#q-p25), [Q-P38](#q-p38) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R04 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P10](#q-p10), [Q-P11](#q-p11), [Q-P26](#q-p26), [Q-P27](#q-p27) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R05 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | completed | None | Preservation is established only for the existing browser entries. docs/adr/0001-two-playable-entries.md and docs/LIGHTNING-VERIFICATION.md record both entries; this does not consolidate or prove a future production game. |
| R06 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | parked | [Q-P35](#q-p35) | Offline solo is settled; enjoyment evidence and later co-op remain separate. Mapped questions retain the production work that remains before bounded implementation cards can be written. Offline solo is settled by TADR-005; no multiplayer/social scope is active. |
| R07 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P01](#q-p01), [Q-P02](#q-p02), [Q-P03](#q-p03), [Q-P04](#q-p04), [Q-P05](#q-p05), [Q-P06](#q-p06), [Q-P11](#q-p11), [Q-P20](#q-p20) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R08 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P19](#q-p19), [Q-P22](#q-p22) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R09 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P15](#q-p15), [Q-P29](#q-p29) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R10 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P20](#q-p20) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R11 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P07](#q-p07), [Q-P12](#q-p12), [Q-P23](#q-p23), [Q-P38](#q-p38) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R12 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P37](#q-p37) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R13 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P22](#q-p22), [Q-P24](#q-p24), [Q-P25](#q-p25) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R14 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P26](#q-p26), [Q-P31](#q-p31), [Q-P34](#q-p34), [Q-P35](#q-p35) | Free/local tooling and explicit external-service decisions remain an execution constraint; docs/project/ASSETS.md records only current assets. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R15 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P18](#q-p18), [Q-P19](#q-p19), [Q-P30](#q-p30) | Bounded orchard implementation is recorded in docs/LIGHTNING-VERIFICATION.md and docs/LIGHTNING-PLAYGUIDE.md; human feel and full-game scope remain unproved. Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R16 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P10](#q-p10), [Q-P11](#q-p11) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R17 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P18](#q-p18) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R18 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P14](#q-p14), [Q-P19](#q-p19), [Q-P37](#q-p37), [Q-P38](#q-p38) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R19 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P16](#q-p16), [Q-P37](#q-p37) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |
| R20 | [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | question | [Q-P11](#q-p11), [Q-P13](#q-p13) | Mapped questions retain the production work that remains before bounded implementation cards can be written. |

### Unnumbered requirements, systems and evidence

| Source requirement / evidence | Record | Disposition | Task/question reference | Scope and evidence |
| --- | --- | --- | --- | --- |
| CORE: The complete loop | [BIBLE.md](BIBLE.md) | task | [TH-01](#th-01) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Movement, camera and active aim | [BIBLE.md](BIBLE.md) | task | [TH-02](#th-02) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: A committed attack means what it shows | [BIBLE.md](BIBLE.md) | task | [TH-03](#th-03) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Abilities, ultimates and combat rhythm | [BIBLE.md](BIBLE.md) | task | [TH-04](#th-04) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Electromagnetic collection, recycling and growth | [BIBLE.md](BIBLE.md) | task | [TH-05](#th-05) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Encounters, waves and enemies | [BIBLE.md](BIBLE.md) | task | [TH-06](#th-06) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Four slots and milestone progression | [BIBLE.md](BIBLE.md) | task | [TH-07](#th-07) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Inventory, equipment and transformations | [BIBLE.md](BIBLE.md) | task | [TH-08](#th-08) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Themed loot, attunement and fixed secrets | [BIBLE.md](BIBLE.md) | task | [TH-09](#th-09) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Devices and one main companion | [BIBLE.md](BIBLE.md) | task | [TH-10](#th-10) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Runs, regions, exits and saves | [BIBLE.md](BIBLE.md) | task | [TH-11](#th-11) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: HUD, dashboard and settings | [BIBLE.md](BIBLE.md) | task | [TH-12](#th-12) | Dedicated system contract page; implementation and physical validation remain separate. |
| CORE: Architecture and implementation handoff | [BIBLE.md](BIBLE.md) | task | [HF-01](#hf-01), [HF-03](#hf-03), [TH-29](#th-29) | Foundation owns paths/interfaces; later handoff owns scoped native qualification readiness. Accepted TADRs supersede engine-open wording. |
| T13.order-1 | [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | completed | None | artifacts/agent-player-2026-09-06/README.md and artifacts/agent-recovery-2026-09-06/README.md record maintained runner and cleanup; exact dated configurations only. |
| T13.order-2 | [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | task | [LG-07](#lg-07) | Core flow and three terminal runs have artifacts/agent-recovery-2026-09-06/README.md evidence; arbitrary equipment editing remains unsupported. |
| T13.order-3 | [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | task | [LG-03](#lg-03), [Q-E11](#q-e11) | Versioned evidence exists, but comparisons and reproducibility classification still need bounded acceptance; native timing prevents deterministic-replay claim. |
| T13.order-4 | [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | task | [LG-03](#lg-03), [LG-04](#lg-04), [LG-05](#lg-05) | Measured profiles and known detector errors remain; general human-like tactics are not established. |
| T13.order-5 | [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | question | [Q-E11](#q-e11) | Baseline/candidate integration must detect then remove a scoped regression. |
| T13.order-6 | [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | question | [Q-E12](#q-e12) | Broader app coverage is need-driven, not a standing platform-expansion task. |
| TECH.section: Constraints & Budgets | [adr/README.md](adr/README.md) | task | [HF-02](#hf-02), [TH-24](#th-24) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Module Map | [adr/README.md](adr/README.md) | task | [HF-03](#hf-03), [TH-27](#th-27) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Runtime Patterns | [adr/README.md](adr/README.md) | task | [HF-04](#hf-04), [TH-14](#th-14), [TH-15](#th-15) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Data Model & Content Pipeline | [adr/README.md](adr/README.md) | task | [HF-05](#hf-05), [HF-06](#hf-06), [TH-19](#th-19), [TH-20](#th-20) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: System Designs | [adr/README.md](adr/README.md) | task | [TH-01](#th-01), [TH-02](#th-02), [TH-03](#th-03), [TH-04](#th-04), [TH-05](#th-05), [TH-06](#th-06), [TH-07](#th-07), [TH-08](#th-08), [TH-09](#th-09), [TH-10](#th-10), [TH-11](#th-11), [TH-12](#th-12), [TH-13](#th-13) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Persistence | [adr/README.md](adr/README.md) | task | [HF-07](#hf-07), [HF-08](#hf-08), [HF-09](#hf-09), [TH-21](#th-21) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Rendering, Audio, Input Integration | [adr/README.md](adr/README.md) | task | [TH-16](#th-16), [TH-17](#th-17), [TH-18](#th-18) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Tooling & Debug | [adr/README.md](adr/README.md) | task | [TH-26](#th-26) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Testing Strategy | [adr/README.md](adr/README.md) | task | [TH-22](#th-22), [TH-23](#th-23), [TH-24](#th-24), [TH-25](#th-25) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| TECH.section: Conventions | [adr/README.md](adr/README.md) | task | [HF-01](#hf-01), [TH-29](#th-29) | Ten-section structure from accepted engineering handoff request; root supplied exact heading contract. ADR index supplies the planned deliverable and evidence boundary. |
| BIBLE-useful-starting-kit | [BIBLE.md](BIBLE.md) | question | [Q-P06](#q-p06), [Q-P11](#q-p11), [Q-P20](#q-p20), [Q-P21](#q-p21) | Starting weapon and mobility must work before rare loot. Final kit content and feel still need a selected scope. |
| BIBLE-collect-recycle-fabricate | [BIBLE.md](BIBLE.md) | question | [Q-P10](#q-p10), [Q-P26](#q-p26), [Q-P27](#q-p27) | Accumulation and fabrication are approved; material policy, authored mechanisms and movement evidence remain open. |
| BIBLE-branch-node-effects | [BIBLE.md](BIBLE.md) | question | [Q-P11](#q-p11) | Binary topology is settled; node effects and prototype action mapping are not. |
| BIBLE-respec-scope-frequency-refunds | [BIBLE.md](BIBLE.md) | question | [Q-P18](#q-p18) | Respec permission is settled; opportunity content and refund rules remain unselected. |
| BIBLE-inventory-capacity-replacement | [BIBLE.md](BIBLE.md) | question | [Q-P19](#q-p19) | Four progression slots do not establish inventory/equipment capacity. |
| BIBLE-ultimate-cadence | [BIBLE.md](BIBLE.md) | question | [Q-P20](#q-p20) | Useful class-action charging is settled; formulas and timing require a selected kit. |
| BIBLE-device-lifecycle | [BIBLE.md](BIBLE.md) | question | [Q-P15](#q-p15) | Capacity, lifetime, recall, resources and cross-level persistence require explicit rules. |
| BIBLE-companion-assembly-support | [BIBLE.md](BIBLE.md) | question | [Q-P15](#q-p15), [Q-P29](#q-p29) | One main assembled companion is settled; parts, controls and appearance remain open. |
| BIBLE-fixed-secret-eligibility-disclosure | [BIBLE.md](BIBLE.md) | question | [Q-P14](#q-p14) | Fixed effects and persistent knowledge are settled; exact recipes and presentation remain content work. |
| BIBLE-revival-health-placement-interruption | [BIBLE.md](BIBLE.md) | question | [Q-P16](#q-p16) | One revival and next-entrance completed-level resume stay fixed; unfinished-level behavior is unresolved. |
| BIBLE-permanent-options | [BIBLE.md](BIBLE.md) | question | [Q-P37](#q-p37) | Option/challenge unlocks persist; the initial catalogue and conditions are not specified. |
| BIBLE-mounted-equipment-scale | [BIBLE.md](BIBLE.md) | question | [Q-P22](#q-p22), [Q-P26](#q-p26) | E01/E02 relative D comparisons do not establish mounted dimensions or route clearance. |
| BIBLE-rolling-articulation | [BIBLE.md](BIBLE.md) | question | [Q-P27](#q-p27) | M01/M05/E02 tread and support forms do not prove irregular-core rolling articulation. |
| BIBLE-growth-upgrade-visual-states | [BIBLE.md](BIBLE.md) | question | [Q-P11](#q-p11), [Q-P26](#q-p26), [Q-P27](#q-p27) | Meaningful hardware/effect changes are required, but selected character states and production assets need scope. |
| BIBLE-material-and-lighting-production | [BIBLE.md](BIBLE.md) | question | [Q-P26](#q-p26), [Q-P33](#q-p33) | Grease/material and Southwest light direction is approved. Runtime material fidelity, detail budget and selected regional lighting need production work. |
| BIBLE-interface-layout-production | [BIBLE.md](BIBLE.md) | question | [Q-P30](#q-p30) | U01/U02 illustrate states; production layout, view distances and hardware evidence remain open. |
| BIBLE-audio-production | [BIBLE.md](BIBLE.md) | question | [Q-P17](#q-p17), [Q-P31](#q-p31), [Q-P32](#q-p32) | F01 is a concept sheet. Music, samples, mix, motion, long-session listening and controller comfort remain untested. |
| BIBLE-character-arcs-supporting-scenes | [BIBLE.md](BIBLE.md) | question | [Q-P08](#q-p08), [Q-P09](#q-p09), [Q-P28](#q-p28) | Arcs, optional exchanges, Moss and Brindle are proposals. No dialogue inventory or launch supporting cast is selected. |
| BIBLE-weapon-device-candidates | [BIBLE.md](BIBLE.md) | question | [Q-P06](#q-p06), [Q-P11](#q-p11), [Q-P15](#q-p15) | Hook-driver/winch, mortar/nest, claw/clamp, emitter/post and laser/prism remain qualitative candidates. |
| BIBLE-regional-loot-candidates | [BIBLE.md](BIBLE.md) | question | [Q-P07](#q-p07), [Q-P14](#q-p14) | Coupling, regulator, linkage, exchanger and vane bearing are theme proposals, not a drop table. |
| BIBLE-Yard-Commons-content | [BIBLE.md](BIBLE.md) | question | [Q-P07](#q-p07), [Q-P24](#q-p24), [Q-P25](#q-p25), [Q-P33](#q-p33), [Q-P38](#q-p38) | Rocky washes, service aprons, handlers and depot encounters need selected regional production scope. |
| BIBLE-Spillway-Works-content | [BIBLE.md](BIBLE.md) | question | [Q-P07](#q-p07), [Q-P24](#q-p24), [Q-P25](#q-p25), [Q-P33](#q-p33), [Q-P38](#q-p38) | Water handling, pump encounters, basin changes and maintenance chambers remain proposed. |
| BIBLE-Iron-Orchard-content | [BIBLE.md](BIBLE.md) | question | [Q-P07](#q-p07), [Q-P24](#q-p24), [Q-P25](#q-p25), [Q-P33](#q-p33), [Q-P38](#q-p38) | Full generated region, seedhouse defense and terrain-changing Grand Pruner remain proposed beyond the bounded arm. |
| BIBLE-Foundry-Crown-content | [BIBLE.md](BIBLE.md) | question | [Q-P07](#q-p07), [Q-P24](#q-p24), [Q-P25](#q-p25), [Q-P33](#q-p33), [Q-P38](#q-p38) | Cableway loads, mountain encounters and platform consequences remain proposed. Mass-gated rails were not adopted. |
| BIBLE-Pale-Basin-content | [BIBLE.md](BIBLE.md) | question | [Q-P07](#q-p07), [Q-P24](#q-p24), [Q-P25](#q-p25), [Q-P33](#q-p33), [Q-P38](#q-p38) | Dune handling, excavation encounters and terrain change remain proposed; image relief does not change the dry-dune identity. |
| DISCOVERY-remaining-design-decisions | [docs/DISCOVERY.md](docs/DISCOVERY.md) | duplicate | [Q-P10](#q-p10), [Q-P11](#q-p11), [Q-P12](#q-p12), [Q-P13](#q-p13), [Q-P14](#q-p14), [Q-P15](#q-p15), [Q-P16](#q-p16), [Q-P18](#q-p18), [Q-P19](#q-p19), [Q-P22](#q-p22), [Q-P23](#q-p23) | The numbered remaining list duplicates retained questions; its tree-shape wording is superseded by the accepted binary rule. |
| DISCOVERY-coop-later | [docs/DISCOVERY.md](docs/DISCOVERY.md) | parked | None | Offline solo production remains settled. Later co-op and player collision fantasy does not authorize networking. Offline solo is settled by TADR-005; no multiplayer/social scope is active. |
| DISCOVERY-notebook-character-sketches | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | parked | [Q-P06](#q-p06) | Bomb drone, elongated elemental being, body shifter, gunslinger and uncertain Jib/bing-bong/ghost sketches remain creative alternatives outside a selected roster. |
| CHARACTER-older-roster-staging | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | superseded | [Q-P06](#q-p06), [Q-P08](#q-p08), [Q-P28](#q-p28) | The old Pip/Vane mapping, four-pilot staging and fixed overseer rungs do not select the Bible cast or route. |
| CHARACTER-capsule-lineup-study | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | question | [Q-P06](#q-p06), [Q-P26](#q-p26) | The four-pilot 64 px study requires a selected cast and production batch. Bible C01-C05/G01 are concept identity evidence, not production turnarounds. |
| CHARACTER-overseer-heraldry-study | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | question | [Q-P08](#q-p08), [Q-P28](#q-p28) | Brindle plus five overseers is not an approved supporting roster. |
| CHARACTER-companion-module-turnaround | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | question | [Q-P15](#q-p15), [Q-P26](#q-p26), [Q-P29](#q-p29) | SNIP-3 and three modules are proposals. Module appearance/animation needs an admitted assembly. |
| CHARACTER-Scrapbook-voice-copy-barks | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | question | [Q-P28](#q-p28), [Q-P37](#q-p37) | Moss narrator, five tabs, 12 barks per pilot and prose budgets are writing proposals, not selected final copy. |
| CHARACTER-mastery-titles-expression-motion | [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | question | [Q-P06](#q-p06), [Q-P26](#q-p26), [Q-P27](#q-p27), [Q-P28](#q-p28), [Q-P37](#q-p37) | Per-class titles, capsule event expressions and movement personality require selected content. Baseline titles do not prove future class progression. |
| WORLD-route-clearance-contract | [docs/WORLD-ENVIRONMENTS.md](docs/WORLD-ENVIRONMENTS.md) | question | [Q-P22](#q-p22), [Q-P24](#q-p24) | 2D widths, route dimensions and movement values are historical proposals. Preserve ordinary-growth passage and visible escape as approved invariants. |
| WORLD-wayfinding-weather-base-chips | [docs/WORLD-ENVIRONMENTS.md](docs/WORLD-ENVIRONMENTS.md) | question | [Q-P33](#q-p33), [Q-P34](#q-p34) | Signs, static lighting/weather policy and physical biome chips require selection. Old five-color miniature constraints are superseded. |
| WORLD-Windworks-Harvest-Roads-Furnace-City | [docs/WORLD-ENVIRONMENTS.md](docs/WORLD-ENVIRONMENTS.md) | parked | [Q-P07](#q-p07) | Retain the older optional kits for catalogue choice; no catalogue size or fixed finale follows. |
| WORLD-next-Spillway-kit | [docs/WORLD-ENVIRONMENTS.md](docs/WORLD-ENVIRONMENTS.md) | question | [Q-P07](#q-p07), [Q-P24](#q-p24), [Q-P25](#q-p25) | The recommended Spillway minimal kit, sluice beat, signs and water ambience remain contingent on next-region scope. |
| LEVEL-authored-versus-terrain-generation | [docs/LEVEL-DESIGN.md](docs/LEVEL-DESIGN.md) | question | [Q-P23](#q-p23) | Seeded compact levels are settled; authored module versus terrain assembly remains open. |
| LEVEL-branches-defense-and-boss-patterns | [docs/LEVEL-DESIGN.md](docs/LEVEL-DESIGN.md) | question | [Q-P12](#q-p12), [Q-P22](#q-p22), [Q-P24](#q-p24), [Q-P25](#q-p25), [Q-P38](#q-p38) | Pocket types, mouth/anchor dimensions, defense completion and boss consequences remain proposals, to be selected and re-derived for actual production movement. |
| LEVEL-historical-orchard-five-pocket-example | [docs/LEVEL-DESIGN.md](docs/LEVEL-DESIGN.md) | superseded | [Q-P23](#q-p23), [Q-P38](#q-p38) | The fixed sequence, three-stage schedule and mass/deflect prerequisites are historical. Candidate spatial ideas remain available through the selected module question. |
| LEVEL-duration-branch-telemetry-hypotheses | [docs/LEVEL-DESIGN.md](docs/LEVEL-DESIGN.md) | question | [Q-P35](#q-p35) | Proposed 10-14 minute stage and floor-of-8-minute thresholds were never accepted and conflict with earned fast clears. A new bounded evidence procedure must use the four-world target. |
| ENEMY-candidate-world-library | [docs/ENEMY-ROSTER.md](docs/ENEMY-ROSTER.md) | question | [Q-P25](#q-p25) | All named family members, pressure roles, elites, bosses and values are a library for scope selection, not a production roster. |
| ENEMY-13-inferred-occupations | [docs/ENEMY-ROSTER.md](docs/ENEMY-ROSTER.md) | question | [Q-P36](#q-p36) | Thirteen newly inferred designs require URL/access-date qualification before being called grounded. Reference work is bounded by admitted content. |
| ENEMY-candidate-reconciliations | [docs/ENEMY-ROSTER.md](docs/ENEMY-ROSTER.md) | question | [Q-P07](#q-p07), [Q-P25](#q-p25) | Glassjaw, Old Ironroot, Scooplet reuse, Kiln Strider, Plowback and Jettling placements remain proposals. |
| ENEMY-historical-build-order | [docs/ENEMY-ROSTER.md](docs/ENEMY-ROSTER.md) | superseded | [Q-P25](#q-p25) | The twelve-step deflect/mass-first order is a historical dependency study, not the next sprint. |
| ART-ball-build-state-turnaround | [docs/audit-2026-09-05/worker-4-universe.md](docs/audit-2026-09-05/worker-4-universe.md) | question | [Q-P06](#q-p06), [Q-P11](#q-p11), [Q-P26](#q-p26), [Q-P27](#q-p27) | Three stages by four class signatures was a proposed art study. Re-scope from selected characters and actual tree hardware, not old prototype roster. |
| ART-Snipcart-articulated-blockout | [docs/audit-2026-09-05/worker-4-universe.md](docs/audit-2026-09-05/worker-4-universe.md) | question | [Q-P25](#q-p25), [Q-P26](#q-p26) | Authored fork/brace model, three scales and glTF animation study remain production proposals. Existing procedural mechanisms do not complete a Blender rig. |
| ART-Pip-capsule-expression-sheet | [docs/audit-2026-09-05/worker-4-universe.md](docs/audit-2026-09-05/worker-4-universe.md) | superseded | [Q-P06](#q-p06), [Q-P26](#q-p26), [Q-P28](#q-p28) | The claim that this sheet would close hamster species canon is superseded by the approved Bible candidate cast. Expression and enclosure production needs selected scope. |
| ART-biome-palette-keyframes | [docs/audit-2026-09-05/worker-4-universe.md](docs/audit-2026-09-05/worker-4-universe.md) | superseded | [Q-P07](#q-p07), [Q-P26](#q-p26), [Q-P33](#q-p33) | Old fixed-rung cream/orange/mint keyframes are superseded by approved Section 7 and regional Bible concepts. Selected production lighting remains open. |
| ART-figurine-blockout | [docs/audit-2026-09-05/worker-4-universe.md](docs/audit-2026-09-05/worker-4-universe.md) | question | [Q-P34](#q-p34) | 60 mm Pip, part thickness and minimal-support checks are unapproved physical-product proposals. Concept grey renders do not prove a printable or safe product. |
| ART-historical-miniature-palette | [docs/ART-DIRECTION.md](docs/ART-DIRECTION.md) | superseded | None | The approved BIBLE Section 7 replaces pristine miniature, matte-only and cream/orange palette instructions for future work. Historical images and prototype evidence remain preserved. |
| CONCEPT-orchard-motion-closure-limits | [docs/CONCEPT-STUDY-03.md](docs/CONCEPT-STUDY-03.md) | question | [Q-P25](#q-p25), [Q-P26](#q-p26), [Q-P27](#q-p27) | Old boss band, closed-cut/retraction, collection and safe trajectory limitations remain production-motion questions; this is not a request to redo corrected Bible images. |
| MARKET-prices-reviews-patterns | [docs/MARKET-RESEARCH.md](docs/MARKET-RESEARCH.md) | completed | None | docs/MARKET-SOURCES.md records the 5 September three-game snapshot and 30-review convenience sample. No representative demand, revenue, current price or reproduced gameplay defect claim follows. |
| MARKET-next-rolling-playground | [docs/MARKET-RESEARCH.md](docs/MARKET-RESEARCH.md) | parked | [Q-P35](#q-p35) | Historical ramp/bumper playground and scale comparison require current purpose before new execution. Existing lightning implementation does not prove human enjoyment. This is an unselected historical research proposal; no new experiment is authorized by the current foundation scope. |
| MARKET-30-45-minute-pacing | [docs/MARKET-RESEARCH.md](docs/MARKET-RESEARCH.md) | superseded | [Q-P12](#q-p12), [Q-P35](#q-p35) | The earlier pacing target is replaced by accepted 60-75 minute runs through four worlds. Old study conclusions remain dated. |
| BIBLE-art-acceptance-contract | [BIBLE.md](BIBLE.md) | task | [PD-01](#pd-01) | This bounded documentation task can record open values and gate production without choosing them. |
| BIBLE-interface-state-specification | [BIBLE.md](BIBLE.md) | task | [PD-02](#pd-02) | This bounded documentation task can record open values and gate production without choosing them. |
| BIBLE-audio-event-specification | [BIBLE.md](BIBLE.md) | task | [PD-03](#pd-03) | This bounded documentation task can record open values and gate production without choosing them. |
| IMG-P01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/P01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-W01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/W01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-W02 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/W02-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-W03 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/W03-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-W04 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/W04-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M00 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/M00-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/M01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M02 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/M02-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M03 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/M03-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M04 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/M04-v2.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M05 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/M05-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-C01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/C01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-C02 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/C02-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-C03 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/C03-v2.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-C04 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/C04-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-C05 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/C05-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-E01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/E01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-E02 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/E02-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-U01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/U01-v2.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-U02 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/U02-v3.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-A01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/A01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-A02 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/A02-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-A03 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/A03-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-F01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/F01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-G01 | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Selected concept docs/bible/images/G01-v1.png passed the documented image review. docs/bible/production/independent-review.md and COHESION_REPORT.md record scope and notes. No model, rig, hitbox, motion, audio or human-play evidence is implied. |
| IMG-M04-correction | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Pilot enclosure corrected in M04-v2. Evidence: docs/bible/production/owner-revisions.json and docs/bible/production/independent-review.md. Concept/document inspection only; no repeat correction work remains. |
| IMG-C03-correction | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | B label corrected in C03-v2. Evidence: docs/bible/production/owner-revisions.json and docs/bible/production/independent-review.md. Concept/document inspection only; no repeat correction work remains. |
| IMG-U01-correction | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Single revival, mechanical companion and irregular chassis corrected in U01-v2. Evidence: docs/bible/production/owner-revisions.json and docs/bible/production/independent-review.md. Concept/document inspection only; no repeat correction work remains. |
| IMG-U02-automatic-correction | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | Eight leaves corrected in U02-v2, later replaced by the explicit owner revision. Evidence: docs/bible/production/owner-revisions.json and docs/bible/production/independent-review.md. Concept/document inspection only; no repeat correction work remains. |
| IMG-U02-owner-revision | [COHESION_REPORT.md](COHESION_REPORT.md) | completed | None | U02-v3 records the accepted 15-node, 14-edge binary tree with eight leaves. Evidence: docs/bible/production/owner-revisions.json and docs/bible/production/independent-review.md. Concept/document inspection only; no repeat correction work remains. |
| BIBLE-section-01 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-02 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-03 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-04 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-05 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-06 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-07 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-08 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| BIBLE-section-09 | [BIBLE.md](BIBLE.md) | completed | None | COHESION_REPORT.md records delivery and review of this manuscript section. Its concept work is complete; retained questions and production documentation tasks cover remaining scoped work. No implementation completion follows. |
| TAXONOMY-family-sheet-and-storyboard | [docs/ENEMY-TAXONOMY.md](docs/ENEMY-TAXONOMY.md) | completed | None | docs/CONCEPT-STUDY-03.md and docs/ORCHARD-ENCOUNTER-STUDY.md record the completed family/art/paper follow-up with closure, scale and motion limits. No new redraw is required and full authored rigs remain Q-P25/Q-P26 work. |
| TAXONOMY-playable-relative-miniboss-study | [docs/ENEMY-TAXONOMY.md](docs/ENEMY-TAXONOMY.md) | question | [Q-P25](#q-p25), [Q-P35](#q-p35) | The proposed ordinary-relative plus miniboss test is not complete full-boss evidence; select an enemy scope and question before execution. |
| COMBAT-Sluiceback-basin-experiment | [docs/CONFLICT-AND-COMBAT.md](docs/CONFLICT-AND-COMBAT.md) | parked | [Q-P21](#q-p21), [Q-P25](#q-p25), [Q-P35](#q-p35) | The timed guard/basin/bumper proposal remains a historical alternative. Its defensive rhythm is unselected, and later lightning evidence does not silently authorize it. This is an unselected historical research proposal; no new experiment is authorized by the current foundation scope. |
| DESIGN-INDEX-research-and-production-navigation | [docs/DESIGN-INDEX.md](docs/DESIGN-INDEX.md) | superseded | None | Its dated active-P10 and engine-open status must be reconciled by root with the current approved preparation. Its links remain useful historical source navigation. |
| NOTE-transcription | [docs/HANDWRITTEN-NOTES.md](docs/HANDWRITTEN-NOTES.md) | completed | None | Four original photos and the uncertainty-marked transcription are preserved in docs/discovery/source-notes-2026-08-21/. Source reading only, not current content approval. |
| NOTE-five-levels-and-two-rewards | [docs/HANDWRITTEN-NOTES.md](docs/HANDWRITTEN-NOTES.md) | superseded | [Q-P12](#q-p12), [Q-P14](#q-p14) | Accepted Discovery supplies four worlds and two destination offers, not a boss in every level or a universal two-item reward count. |
| NOTE-unclear-ghost-and-quantum-words | [docs/HANDWRITTEN-NOTES.md](docs/HANDWRITTEN-NOTES.md) | parked | [Q-P06](#q-p06) | Unclear names and phrases remain unresolved until Andrew supplies a reading or selects these characters; no transcription guess is required. |
| NOTE-meaningful-visual-skill-progress | [docs/HANDWRITTEN-NOTES.md](docs/HANDWRITTEN-NOTES.md) | duplicate | [Q-P11](#q-p11), [Q-P26](#q-p26), [Q-P27](#q-p27) | Approved Bible preserves visible mechanical growth; tree content and asset motion already have scoped questions. |
| NOTE-bomb-drone-and-oil-sketch | [docs/HANDWRITTEN-NOTES.md](docs/HANDWRITTEN-NOTES.md) | parked | [Q-P06](#q-p06), [Q-P22](#q-p22), [Q-P24](#q-p24) | Bomb drone learning and oil-slick terrain are candidate character/item/enemy ideas, with no mandatory learning service or launch slot. |
| ORCHARD-first-playable-proof | [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | completed | None | docs/FIRST-BUILD-VERIFICATION.md records the later bounded hero, Snipcart, Spreadleg, Pruner-arm and salvage proof. Its synthetic/browser evidence does not close the human learning/enjoyment observations. |
| ORCHARD-teaching-observations | [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | duplicate | [Q-P21](#q-p21), [Q-P35](#q-p35) | Route changes, unprompted counter recognition, maximum-growth control and baseline/strong-build comparison belong to the selected player-evidence scope. LG-01 retains current human feedback. |
| ORCHARD-four-poses-pivots-spool | [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | duplicate | [Q-P25](#q-p25), [Q-P26](#q-p26), [Q-P27](#q-p27) | Position/brace/operate/release, lowering Spreadleg frame and traceable spool-to-arm path inform a selected authored rig; no full Grand Pruner motion is proven. |
| ORCHARD-greybox-clearance-and-recovery | [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | duplicate | [Q-P21](#q-p21), [Q-P22](#q-p22), [Q-P24](#q-p24), [Q-P30](#q-p30) | 2D is a construction starting point. Check achievable outer routes, device placement, growth-camera obstruction and post-hit recovery for actual selected movement. |
| ORCHARD-companion-parts-and-fitting | [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | duplicate | [Q-P14](#q-p14), [Q-P15](#q-p15), [Q-P29](#q-p29) | Shear/Brace companion combination, priming eligibility, device vulnerability and assembly timing are content proposals already covered by item/lifecycle questions. |
| ORCHARD-boss-terrain-breaks | [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | duplicate | [Q-P24](#q-p24), [Q-P25](#q-p25) | Damage, loosened salvage and supported traversable structural breaks are separate possible outcomes. Full boss terrain consequences require scope. |
| ORCHARD-VISUAL-delivery-and-corrections | [docs/ORCHARD-VISUAL-SWARM.md](docs/ORCHARD-VISUAL-SWARM.md) | completed | None | docs/CONCEPT-STUDY-03.md and docs/ORCHARD-ENCOUNTER-STUDY.md retain corrected images, pose brief and paper review. 49 links/image hashes are historical document evidence, not rig or motion proof. |
| ORCHARD-VISUAL-aggregation-rules | [docs/ORCHARD-VISUAL-SWARM.md](docs/ORCHARD-VISUAL-SWARM.md) | duplicate | [Q-P22](#q-p22), [Q-P25](#q-p25), [Q-P27](#q-p27) | Inward jaws/outward feet, articulated legs, dependable collision envelope, autonomous enemies and staggered first lesson remain bounded mechanism references. |
| ORCHARD-VISUAL-art-limitations | [docs/ORCHARD-VISUAL-SWARM.md](docs/ORCHARD-VISUAL-SWARM.md) | duplicate | [Q-P25](#q-p25), [Q-P26](#q-p26), [Q-P27](#q-p27) | Narrow preparation wedge, side/front camera, unclear band and incomplete retraction remain production-study limitations, not a request to redo approved Bible corrections. |
| COMBAT-SWARM-delivered | [docs/COMBAT-DESIGN-SWARM.md](docs/COMBAT-DESIGN-SWARM.md) | completed | None | docs/CONFLICT-AND-COMBAT.md and docs/CONCEPT-STUDY-02.md record delivered research, four-panel art and independent paper review. No gameplay evidence accompanied the pass. |
| COMBAT-SWARM-open-conflict-defense-scale | [docs/COMBAT-DESIGN-SWARM.md](docs/COMBAT-DESIGN-SWARM.md) | duplicate | [Q-P08](#q-p08), [Q-P21](#q-p21), [Q-P22](#q-p22), [Q-P25](#q-p25), [Q-P35](#q-p35) | Conflict, guard/protection proposals, scale and first experiment remain covered. The old 30-45 minute target is superseded by the accepted run. |
| CONCEPT01-generated-study | [docs/CONCEPT-STUDY-01.md](docs/CONCEPT-STUDY-01.md) | completed | None | public/art/03-industrial-dungeon-study.png and this source preserve the generated image and inspection. No model, rig or engine/performance proof follows. |
| CONCEPT01-oversized-frame-and-orderly-shell | [docs/CONCEPT-STUDY-01.md](docs/CONCEPT-STUDY-01.md) | superseded | [Q-P22](#q-p22), [Q-P26](#q-p26), [Q-P27](#q-p27), [Q-P30](#q-p30) | The approved Bible replaces the old clean miniature/composition target. Production camera, growth envelope and cockpit/articulation work remain separately scoped. |
| CONCEPT02-generated-sheet | [docs/CONCEPT-STUDY-02.md](docs/CONCEPT-STUDY-02.md) | completed | None | public/art/04-furnace-fleet-enemies.png and this source retain four labeled machine concepts and visual inspection; no functional joints, hitboxes or runtime import. |
| CONCEPT02-weathering-and-acting | [docs/CONCEPT-STUDY-02.md](docs/CONCEPT-STUDY-02.md) | superseded | [Q-P25](#q-p25), [Q-P26](#q-p26), [Q-P27](#q-p27) | Bible Section 7 settles the greasy material direction. Proposed characters/enemies still need scoped acting, articulation and scale studies; no old palette repair is required. |
| AUDIT-recorded-probe | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | completed | None | The synthetic simulation probe and historical 73-test result are recorded here. docs/PLANNING-PREP-SWARM.md corrects initial cooldown versus approach and limits the undocumented 90-degree realign measurement. No human feel claim follows. |
| AUDIT-mass-deflect-shed-first | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | superseded | [Q-P10](#q-p10), [Q-P21](#q-p21), [Q-P35](#q-p35) | The mass/deflect-first ordering and mandatory handling penalties were superseded by approved lightning direction and Bible. Optional future experiments require current purpose. |
| AUDIT-registries-modifiers-run-save | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | superseded | None | The old Three.js target layout is replaced by HF-03/HF-05 and TH-04/TH-06/TH-08/TH-20 plus persistence contracts. This is no longer a runnable registry migration order. |
| AUDIT-three-stage-five-rung-ladder | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | superseded | [Q-P07](#q-p07), [Q-P12](#q-p12) | Three stages, five fixed beats and campaign ladder are superseded by four-world procedural runs and unselected catalogue/route details. |
| AUDIT-unlocks-and-Scrapbook | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | duplicate | [Q-P28](#q-p28), [Q-P37](#q-p37) | All classes before hour 7, ten-hour entry guarantees, observed entries and daily/friend hooks remain candidate content. Offline solo and rebuilt combat power are settled. |
| AUDIT-requisition-hamster-and-palette | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | superseded | [Q-P06](#q-p06), [Q-P08](#q-p08), [Q-P09](#q-p09) | Approved Bible supersedes hamster-as-canon and old palette. Fiction and cast remain explicit choices rather than this audit recommendation. |
| AUDIT-five-art-steps | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | duplicate | [Q-P06](#q-p06), [Q-P25](#q-p25), [Q-P26](#q-p26), [Q-P27](#q-p27), [Q-P33](#q-p33), [Q-P34](#q-p34) | Each step already has a product coverage row from worker-4-universe: build states, authored Snipcart rig, pilot expression, regional lighting and figurine. |
| AUDIT-version-control | [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | completed | None | docs/PLANNING-PREP-SWARM.md records real Git baseline 4db9b31 and planning branch integration. Off-machine publication is still Q-E07, not completed backup. |
| DEEP-RESEARCH-delivery-coherence | [docs/DEEP-RESEARCH-SWARM.md](docs/DEEP-RESEARCH-SWARM.md) | completed | None | Five documents, 13 level fixes, four runtime coherence fixes and later character fixes are documented in docs/research-2026-09-05/REVIEW-NOTES.md. Paper consistency only; unselected numeric rules remain proposals. |
| DEEP-RESEARCH-inferred-enemy-count | [docs/DEEP-RESEARCH-SWARM.md](docs/DEEP-RESEARCH-SWARM.md) | duplicate | [Q-P25](#q-p25), [Q-P36](#q-p36) | The historical thirteen count is disputed by REVIEW-NOTES, which lists 16 new rows and 15 inference tags. Qualify the actual admitted names, not an assumed total. |
| TAXONOMY-SWARM-delivery-corrections | [docs/ENEMY-TAXONOMY-SWARM.md](docs/ENEMY-TAXONOMY-SWARM.md) | completed | None | docs/ENEMY-TAXONOMY.md records three families and correction of magnet-cassette failure, Rinsebelly compaction, Grand Pruner binding and naming. Document research only. |
| TAXONOMY-SWARM-future-family-admission | [docs/ENEMY-TAXONOMY-SWARM.md](docs/ENEMY-TAXONOMY-SWARM.md) | duplicate | [Q-P25](#q-p25), [Q-P36](#q-p36) | Shared physical mechanisms, tells, counters and salvage remain admission material for selected content, not 27 approved production configurations. |
| PLANNING-PREP-delivery | [docs/PLANNING-PREP-SWARM.md](docs/PLANNING-PREP-SWARM.md) | completed | None | This historical record documents Git baseline, decision register, planning protocol and source checks, with local-only storage. No native-engine foundation task is completed by it. |
| PLANNING-PREP-90-degree-evidence | [docs/PLANNING-PREP-SWARM.md](docs/PLANNING-PREP-SWARM.md) | duplicate | [Q-P21](#q-p21), [Q-P35](#q-p35) | The 90-degree realign figure lacks a retained reproducible method. Future handling acceptance must measure a declared procedure; no historical arithmetic is promoted to human feel. |
| PLANNING-PREP-first-protocol-run | [docs/PLANNING-PREP-SWARM.md](docs/PLANNING-PREP-SWARM.md) | superseded | None | The dated next-session statement is replaced by current ORCHESTRATOR/TRACKING preparation and explicit future sprint gate. It is not an unstarted game feature. |
| REVIEW-NOTES-L013 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Character bible (CHARACTER-BIBLE.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L014 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Four character citation corrections are recorded as applied in this file preamble and docs/DEEP-RESEARCH-SWARM.md. Historical document correction only. |
| REVIEW-NOTES-L015 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | The Brindle in-motion staging correction is recorded as applied after the research run. It does not approve this scene or antagonist. |
| REVIEW-NOTES-L016 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P06](#q-p06), [Q-E05](#q-e05) | Do not silently reassign baseline blueprints to the future cast or delete saved options; candidate cast and import policy own the decision. |
| REVIEW-NOTES-L017 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P07](#q-p07), [Q-P25](#q-p25) | Rustwater/Yard naming and Cancrusher/Old Ironroot placement remain catalogue and enemy selection questions. |
| REVIEW-NOTES-L018 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P25](#q-p25), [Q-P28](#q-p28) | Bible candidate-status rules replace the old implication of a settled Yardmaster owner; no production cast is chosen. |
| REVIEW-NOTES-L019 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P08](#q-p08), [Q-P28](#q-p28) | Brindle motive and Damper defection require selected narrative scope, not an invented recommendation. |
| REVIEW-NOTES-L020 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P21](#q-p21), [Q-P27](#q-p27) | Class movement versus decorative motion must follow the selected kit and approved movement, not the old universal mass model. |
| REVIEW-NOTES-L021 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P06](#q-p06), [Q-P26](#q-p26), [Q-P27](#q-p27) | A selected Fuse production brief needs a recognizable idle/home pose; the old four-pilot sheet does not supply it. |
| REVIEW-NOTES-L022 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [PD-01](#pd-01) | Approved Bible material/readability rules replace the old exclusive accent-color assignment. |
| REVIEW-NOTES-L023 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [LG-01](#lg-01), [TH-23](#th-23) | Retain the threat-pose versus banner readability observation in human acceptance; historical warnings are not proven adequate. |
| REVIEW-NOTES-L024 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P28](#q-p28) | The old exact-two-places animal rule does not define Bible supporting-character scope. No command balcony is automatically admitted. |
| REVIEW-NOTES-L025 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P28](#q-p28), [Q-P29](#q-p29), [Q-P37](#q-p37) | Archetypes, epithets, mastery titles and designations remain proposed content and need explicit selection. |
| REVIEW-NOTES-L026 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P06](#q-p06) | Notebook transfers remain candidate choices under the approved Bible; old verdicts do not close publisher choices. |
| REVIEW-NOTES-L027 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Character bible (CHARACTER-BIBLE.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L031 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Character bible (CHARACTER-BIBLE.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L032 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | [Q-P29](#q-p29) | Editorial tightening of an unselected companion prose proposal is retained for reuse, not a new production task. |
| REVIEW-NOTES-L033 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P29](#q-p29), [Q-P15](#q-p15) | Companion epithet identity must distinguish chassis-type naming from a persistent assembled-instance identity before saving it. |
| REVIEW-NOTES-L034 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-10](#th-10), [TH-20](#th-20) | Companion module/behavior/expression/audio fields belong in the admitted companion contract and schema catalogue, with unselected content gated. |
| REVIEW-NOTES-L035 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P28](#q-p28), [Q-P37](#q-p37) | The 120-entry text count has no derivation and must not become production scope. Select the actual entry/bark inventory. |
| REVIEW-NOTES-L036 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [PD-02](#pd-02), [TH-18](#th-18) | Controller navigation and any naming entry require explicit usability/input treatment. |
| REVIEW-NOTES-L037 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Old shorthand citation legend cleanup is retained for reuse of this historical proposal. Final canonical cards use actual full paths. |
| REVIEW-NOTES-L038 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Character bible (CHARACTER-BIBLE.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L042 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P06](#q-p06), [Q-P28](#q-p28) | Character bible (CHARACTER-BIBLE.md): Do the proposed names Vane and Fuse land, and do you accept Rivet as the mole laser machinist and Moss as the hedgehog quartermaster, or do you want to supply your own names and species? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L043 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P08](#q-p08) | Character bible (CHARACTER-BIBLE.md): Is Admiral Brindle sincerely wrong about the harvest arithmetic or knowingly lying? The bible writes him sincere; the whole antagonist tone hangs on this fork. Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L044 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P28](#q-p28), [Q-P31](#q-p31) | Character bible (CHARACTER-BIBLE.md): How much text should combat carry at launch: silent text chirps as recommended, recorded voice barks, or full silence? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L045 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P06](#q-p06) | Character bible (CHARACTER-BIBLE.md): The notebook's ghost character has an unresolved name (docs/HANDWRITTEN-NOTES.md:61-64): can you supply the reading, and should it be developed or stay parked? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L046 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P08](#q-p08), [Q-P28](#q-p28) | Character bible (CHARACTER-BIBLE.md): Should First Stoker Damper's defection be a committed campaign beat, an optional discovery, or cut? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L055 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Enemy roster (ENEMY-ROSTER.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L056 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Enemy roster (ENEMY-ROSTER.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L057 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Off-by-one enemy registry gate citation is preserved as an unapplied historical note; the old build order is superseded. |
| REVIEW-NOTES-L058 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Binbug historical speed pointer correction remains an unapplied source note. Actual content stats must come from an admitted version. |
| REVIEW-NOTES-L059 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P25](#q-p25), [Q-P36](#q-p36) | Recount named additions before admission: review lists 16 new rows and 15 inference tags, not the historical 13. Requisitioner lacks a grounding tag. |
| REVIEW-NOTES-L060 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P15](#q-p15), [Q-P25](#q-p25) | Companion conscription and device drain/encasement are unapproved extensions. Select capture/recovery guarantees explicitly for any admitted enemy. |
| REVIEW-NOTES-L061 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P21](#q-p21), [Q-P25](#q-p25) | Greatfan cannot silently require the unapproved Shed Vent action; selected protection rules need achievable ordinary counters. |
| REVIEW-NOTES-L062 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P21](#q-p21), [Q-P25](#q-p25) | The old two-answer protection floor belongs to defensive/roster selection and cannot be silently omitted or promoted as settled. |
| REVIEW-NOTES-L063 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P25](#q-p25) | Pegjack stomp and Crossbelly shove are proposed extra attacks, not inherited taxonomy behavior. |
| REVIEW-NOTES-L064 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P14](#q-p14), [Q-P25](#q-p25) | Brakebogie Ballast Skate versus terrain salvage needs explicit reward identity for admitted content. |
| REVIEW-NOTES-L065 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P12](#q-p12) | Accepted four-world structure supersedes the old rung-to-stage reconciliation. |
| REVIEW-NOTES-L066 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P25](#q-p25) | Scooplet/Rackspan support-role extensions remain proposals, not publisher-confirmed roles. |
| REVIEW-NOTES-L067 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P14](#q-p14), [Q-P37](#q-p37) | Override Bolt ownership, discovery-by-observation and duplicate reward handling need explicit selected item/discovery rules. |
| REVIEW-NOTES-L068 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P08](#q-p08), [Q-P25](#q-p25) | Brindle hitbox status and enemy admission rules remain proposals; baseline labels stay preserved. |
| REVIEW-NOTES-L069 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P25](#q-p25) | Whether veterans derive from modifiers or explicit rows must be fixed for the admitted roster. Historical abbreviation cleanup is retained for reuse. |
| REVIEW-NOTES-L073 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Enemy roster (ENEMY-ROSTER.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L074 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | duplicate | [Q-P25](#q-p25), [Q-P36](#q-p36) | Duplicates the canon critic count discrepancy; qualify admitted names instead of the stale 34/21/13 total. |
| REVIEW-NOTES-L075 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | duplicate | [Q-P36](#q-p36) | Duplicates the inference-tag mismatch and missing Requisitioner grounding. |
| REVIEW-NOTES-L076 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Duplicate historical off-by-one registry-gate reference, retained for reuse rather than source rewrite now. |
| REVIEW-NOTES-L077 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P25](#q-p25), [Q-P36](#q-p36) | Old twelve-enemy next-action order has been replaced by bounded content selection; no implementation card inherits its missing acceptance steps. |
| REVIEW-NOTES-L078 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-06](#th-06), [TH-23](#th-23) | Translate accepted readability floors into explicit tests with a declared method; old prose floors are not numeric acceptance. |
| REVIEW-NOTES-L079 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Enemy roster (ENEMY-ROSTER.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L080 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Enemy roster (ENEMY-ROSTER.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L081 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Enemy roster (ENEMY-ROSTER.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L085 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P25](#q-p25) | Enemy roster (ENEMY-ROSTER.md): Do the demo names Glassjaw and Old Ironroot become Yard Commons canon, or stay reserved for something else? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L086 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P07](#q-p07), [Q-P25](#q-p25) | Enemy roster (ENEMY-ROSTER.md): Is Kiln Strider the Harvest Roads boss, or do you want it kept as an alternative first-campaign encounter? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L087 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P07](#q-p07), [Q-P25](#q-p25) | Enemy roster (ENEMY-ROSTER.md): Should Furnace City's worker mix lean on overseer veteran reprises as proposed, or get a fully new native family? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L088 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P25](#q-p25) | Enemy roster (ENEMY-ROSTER.md): Is the simultaneous-windup ceiling (two staggered workers plus one boss subsystem at rung 5) the escalation cap you want, or should late rungs go denser? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L089 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P15](#q-p15), [Q-P25](#q-p25) | Enemy roster (ENEMY-ROSTER.md): May Graftmender gain device-binding pressure, or should it stay strictly a module-reconnection enemy? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L098 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | World environments (WORLD-ENVIRONMENTS.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L099 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P21](#q-p21), [Q-P24](#q-p24), [Q-P25](#q-p25) | Heavy-versus-deflectable slag drum semantics require explicit selected combat/terrain rules; old grade model is unadopted. |
| REVIEW-NOTES-L100 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P24](#q-p24), [Q-P25](#q-p25) | Spillway drain cannot assume float-type enemies absent from the selected roster; select a grounded interaction or named new admission. |
| REVIEW-NOTES-L101 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Historical figurine rule-2 citation is off by one. Its old dimensions remain unselected and are not imported. |
| REVIEW-NOTES-L102 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P24](#q-p24) | Harvest cargo needs an explicit collectible-versus-protected distinction before terrain consequences enter production. |
| REVIEW-NOTES-L103 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-15](#th-15), [TH-23](#th-23) | 2D is unvalidated construction guidance; actual movement, maximum growth and escape must be qualified. |
| REVIEW-NOTES-L104 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P12](#q-p12) | The old rung-to-three-stage mapping is superseded by the accepted four-world run. |
| REVIEW-NOTES-L105 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P07](#q-p07), [Q-P12](#q-p12) | Historical rung numbers and fixed finale positions are not the approved route. |
| REVIEW-NOTES-L106 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-E05](#q-e05) | Future Yard Commons content cannot silently replace the preserved baseline; browser retention policy governs consolidation. |
| REVIEW-NOTES-L107 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [PD-01](#pd-01) | Approved Section 7 permits shaped material reflections; no matte-only exception approval is needed. |
| REVIEW-NOTES-L108 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [PD-01](#pd-01), [Q-P33](#q-p33) | Old hex divergence does not reopen the approved Bible palette. Selected runtime regional lighting remains production work. |
| REVIEW-NOTES-L109 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P22](#q-p22), [Q-P24](#q-p24) | Mass-gated rail capture is unselected terrain/handling scope, not a consequence of the rolling pillar. |
| REVIEW-NOTES-L110 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P33](#q-p33) | Time-of-day lighting keyframes remain selected regional production details, without falsely attributing an old reference. |
| REVIEW-NOTES-L114 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | World environments (WORLD-ENVIRONMENTS.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L115 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Padding a historical environment document to an old word/line-count target has no current deliverable value. |
| REVIEW-NOTES-L116 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-23](#th-23) | Any admitted sluice beat needs concrete route and warning evidence. Its old minimum-kit proposal is not already qualified. |
| REVIEW-NOTES-L117 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-20](#th-20), [TH-19](#th-19) | Selected terrain module dimensions/tags and import fields belong to the schema/admission contracts, not inferred from prose. |
| REVIEW-NOTES-L118 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-18](#th-18), [TH-23](#th-23) | Selected current/grip/rail/wind effects require analog-control observations and actual controller evidence. |
| REVIEW-NOTES-L119 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-23](#th-23) | Use one named reproducible method for traversal measurements; no tuning multipliers are qualified by paper review. |
| REVIEW-NOTES-L123 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P07](#q-p07) | World environments (WORLD-ENVIRONMENTS.md): Do you approve Spillway Works as the next authored biome, or do you want the Yard Commons rebuilt to campaign quality first since a playable yard already exists? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L124 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P08](#q-p08), [Q-P28](#q-p28) | World environments (WORLD-ENVIRONMENTS.md): The Furnace City kit protects the Fleet's own conscripted crews as the finale's stakes. Is that the ending argument you want, or should the finale stay purely adversarial? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L125 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [PD-01](#pd-01) | The approved Bible palette supersedes the old exclusive-mint-color rule; no art-direction approval is reopened. |
| REVIEW-NOTES-L126 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [PD-01](#pd-01) | Approved greasy material and lighting direction supersedes the old playful-miniature versus grim-weathering gate. Production readability remains to qualify. |
| REVIEW-NOTES-L127 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P24](#q-p24) | World environments (WORLD-ENVIRONMENTS.md): Should the Harvest Roads derail beat destroy stolen cargo for spectacle, or must recovered cargo always survive intact to honor the protect-the-lived-in rule? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L138 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L139 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L140 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L141 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L142 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L143 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L144 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L145 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L146 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L147 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L148 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L149 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L150 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L151 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L155 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Level design (LEVEL-DESIGN.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L156 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-14](#th-14), [TH-20](#th-20) | The schema catalogue must cover selected defense/objective/anchors and boss phase/weak-point fields, or explicitly exclude those pocket types. |
| REVIEW-NOTES-L157 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P22](#q-p22), [TH-23](#th-23) | Nearest/adjacent mouth reachability was corrected in the dated study; selected production geometry must re-derive reachability. |
| REVIEW-NOTES-L158 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-23](#th-23) | The old about-8-units-per-second exit figure lacks a derivation; do not import it as acceptance. Use the actual qualification method. |
| REVIEW-NOTES-L162 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P23](#q-p23) | Level design (LEVEL-DESIGN.md): Do you approve Model C, seeded arrangement of authored pockets, as the production stage model, or do you prefer fully authored stages or tile assembly? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L163 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P12](#q-p12) | Level design (LEVEL-DESIGN.md): Which biome triple routes the first expedition: does Iron Orchard become expedition stage 1 because it is already built, or does the campaign ladder order (Yard Commons, Spillway Works, Iron Orchard) also govern expedition routing? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L164 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P38](#q-p38) | Level design (LEVEL-DESIGN.md): Should defense beats be strictly timer-held at fixed length even when a skilled player clears waves early? The P02 pacing answer depends on this. Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L165 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P24](#q-p24), [Q-P25](#q-p25) | Level design (LEVEL-DESIGN.md): Is the Rowkeeper the right miniboss fantasy for the orchard trellis gate, and may a miniboss permanently alter the boss arena approach (countered rows staying open into the Grand Pruner fight)? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L166 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P37](#q-p37), [Q-P38](#q-p38) | Level design (LEVEL-DESIGN.md): May a branch gate Scrapbook-only sightings with no run-power payoff, or must every branch reward build content? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L175 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Runtime blueprint (RUNTIME-BLUEPRINT.md), Canon findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L176 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [HF-09](#hf-09), [TH-21](#th-21) | Migration must cover nested receipts, IDs and derived allowed sets; a top-level version change is insufficient. |
| REVIEW-NOTES-L177 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [HF-09](#hf-09), [TH-21](#th-21) | Preserve or explicitly migrate baseline blueprints under Q-E05 rather than silently dropping them. |
| REVIEW-NOTES-L178 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | The Sluiceback worked-example conflict is recorded as reconciled in the runtime conflict-fix notes. This is a paper consistency fix, not boss implementation. |
| REVIEW-NOTES-L179 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [HF-05](#hf-05), [TH-21](#th-21) | Content ID and save ID examples/validators must agree, including any prefix separator; schema examples cannot reject their own IDs. |
| REVIEW-NOTES-L180 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | None | Settled Godot/physics qualification and approved movement supersede the old engine-open mass/deflect section premise. |
| REVIEW-NOTES-L181 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Historical runtime section-number cleanup remains a source note; new cards identify exact inputs and outputs. |
| REVIEW-NOTES-L182 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [Q-P21](#q-p21), [Q-P25](#q-p25) | Historical admission/grade models are proposals. Approved Bible and selected content rules govern future contracts. |
| REVIEW-NOTES-L183 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-E05](#q-e05) | Baseline turret tables and retained browser profiles cannot be retired by an old inference. |
| REVIEW-NOTES-L184 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P19](#q-p19) | Brace max-three was a proposed cap, not current behavior. Selected stacking limits need an explicit rule. |
| REVIEW-NOTES-L185 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | [TH-15](#th-15), [TH-19](#th-19), [TH-24](#th-24) | Settled engine selection replaces old Context7 ID mismatch as a decision issue; physics/import/performance still require actual qualification. |
| REVIEW-NOTES-L186 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | parked | None | Historical line-pointer and draw-call proposal cleanup retained for reuse; new qualification uses actual source and measured budgets. |
| REVIEW-NOTES-L190 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Runtime blueprint (RUNTIME-BLUEPRINT.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L191 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Runtime blueprint (RUNTIME-BLUEPRINT.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L192 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-18](#th-18) | Input contracts need typed intent examples and explicit duplicate-poll/focus checks. Old app/input.js path is not the native layout. |
| REVIEW-NOTES-L193 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | task | [TH-17](#th-17) | Audio integration requires event mapping and observable acceptance; old app/audio.js consolidation is not a native implementation card. |
| REVIEW-NOTES-L194 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Runtime blueprint (RUNTIME-BLUEPRINT.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L195 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Runtime blueprint (RUNTIME-BLUEPRINT.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L196 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Runtime blueprint (RUNTIME-BLUEPRINT.md), Craft findings: reviewer method, strength or no-action observation retained at its dated paper/source-inspection scope. It supplies no current runtime or human evidence. |
| REVIEW-NOTES-L200 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P16](#q-p16) | Runtime blueprint (RUNTIME-BLUEPRINT.md): Resume rule: is resuming an interrupted expedition from the last interstitial acceptable, or should any closed tab settle the run as abandoned? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L201 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-P37](#q-p37) | Runtime blueprint (RUNTIME-BLUEPRINT.md): Does the pick-one-of-two ledger record only boss rewards, or every offered choice at every interstitial? Existing question retains this detail; old timing/roster/palette assumptions remain subordinate to the approved Bible. |
| REVIEW-NOTES-L202 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-E03](#q-e03) | Named target hardware and budgets remain the existing engineering hardware question. |
| REVIEW-NOTES-L203 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | superseded | None | Godot 4.7.2 standard with typed GDScript is settled; no engine comparison remains to schedule. |
| REVIEW-NOTES-L204 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | question | [Q-E09](#q-e09) | Permanent discovery write timing, receipt versus profile boundaries and interruption durability belong to the existing persistence question. |
| REVIEW-NOTES-L208 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L209 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L210 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L211 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L212 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L213 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L214 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L215 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L216 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Cross-lane conflicts (all resolved in-run), Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L220 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Conflict fix notes, Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L221 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Conflict fix notes, Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L222 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Conflict fix notes, Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L223 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Conflict fix notes, Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| REVIEW-NOTES-L224 | [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | completed | None | Conflict fix notes, Open questions for Andrew: this source and docs/DEEP-RESEARCH-SWARM.md record the corresponding correction or cross-lane reconciliation. Completion is historical document revision only, not approval or runtime proof of its proposed values. |
| FIRST-PROOF.contract | [docs/FIRST-BUILD-CONTRACT.md](docs/FIRST-BUILD-CONTRACT.md) | completed | None | Bounded orchard implementation recorded by docs/FIRST-BUILD-VERIFICATION.md and artifacts/orchard-first-build/production-http.json; not the production game. Later lightning contract replaces its input/scene specifics. |
| FIRST-PROOF.pacing | [docs/FIRST-BUILD-VERIFICATION.md](docs/FIRST-BUILD-VERIFICATION.md) | task | [LG-01](#lg-01) | 37-second precise script is dated evidence, not human balance; current lightning observation succeeds this playtest. |
| FIRST-PROOF.hardware | [docs/FIRST-BUILD-VERIFICATION.md](docs/FIRST-BUILD-VERIFICATION.md) | question | [LG-02](#lg-02), [Q-P30](#q-p30) | Physical mouse/controller and camera ergonomics remain qualified only by real device observation; mobile initial production scope is excluded. |
| FIRST-PROOF.scale | [docs/FIRST-BUILD-VERIFICATION.md](docs/FIRST-BUILD-VERIFICATION.md) | question | [Q-P22](#q-p22), [Q-P25](#q-p25), [TH-24](#th-24) | Historical radius, giant arm and brief rendering sample are not approved production dimensions or performance budgets. |
| FIRST-PROOF.swarm | [docs/FIRST-BUILD-SWARM.md](docs/FIRST-BUILD-SWARM.md) | completed | None | Historical implementation and independent correction receipts are retained in docs/FIRST-BUILD-VERIFICATION.md; old no-Git condition and engine-open language are superseded by the current checkout and accepted TADRs. |
| LEADS.external-services | [docs/LEAD-CAPTURE.md](docs/LEAD-CAPTURE.md) | parked | None | Hosted proxy/origin/abuse settings, provider credentials, approved sender, ownership/unsubscribe and privacy/consent review apply only to a separately authorized publishing or messaging project. No service integration, export or campaign is active; existing local records are preserved. |
| HOUSEKEEPING.closeout | [docs/project/HOUSEKEEPING.md](docs/project/HOUSEKEEPING.md) | completed | None | artifacts/housekeeping-2026-09-05/report.json, runtime-comparison.json and tests.log establish the six-stage historical structural closeout, 73 tests and unchanged first-proof sources. No current runtime check is implied. |
| HOUSEKEEPING.remaining | [docs/project/HOUSEKEEPING.md](docs/project/HOUSEKEEPING.md) | duplicate | [LG-01](#lg-01), [LG-02](#lg-02), [Q-E07](#q-e07), [Q-E08](#q-e08), [TH-24](#th-24) | Remote, playtest, pressure, hardware/performance and packaging already map to P/T records; no second queue. |
| BASELINE.retention | [docs/BASELINE-GUIDE.md](docs/BASELINE-GUIDE.md) | completed | None | docs/RETENTION-VERIFICATION.md holds dated expedition/collection proof. Its 15–17 simulation minutes, mastery, daily/friend links and optional signup are browser evidence only; preservation is enforced by Q-E05 and existing ADR 0001. |
| BROWSER-ADR.0001 | [docs/adr/0001-two-playable-entries.md](docs/adr/0001-two-playable-entries.md) | duplicate | [Q-E05](#q-e05) | Retained implementation boundary and evidence links. Revisit triggers apply only when the named change is selected; no browser consolidation, new asset batch or broader desktop adapter is implicitly scheduled. |
| BROWSER-ADR.0002 | [docs/adr/0002-simulation-boundary.md](docs/adr/0002-simulation-boundary.md) | duplicate | [HF-03](#hf-03), [HF-04](#hf-04) | Retained implementation boundary and evidence links. Revisit triggers apply only when the named change is selected; no browser consolidation, new asset batch or broader desktop adapter is implicitly scheduled. |
| BROWSER-ADR.0003 | [docs/adr/0003-authoritative-attack-geometry.md](docs/adr/0003-authoritative-attack-geometry.md) | duplicate | [TH-03](#th-03), [TH-15](#th-15) | Retained implementation boundary and evidence links. Revisit triggers apply only when the named change is selected; no browser consolidation, new asset batch or broader desktop adapter is implicitly scheduled. |
| BROWSER-ADR.0004 | [docs/adr/0004-procedural-prototype-assets.md](docs/adr/0004-procedural-prototype-assets.md) | duplicate | [PD-01](#pd-01), [TH-19](#th-19), [Q-P26](#q-p26) | Retained implementation boundary and evidence links. Revisit triggers apply only when the named change is selected; no browser consolidation, new asset batch or broader desktop adapter is implicitly scheduled. |
| BROWSER-ADR.0006 | [docs/adr/0006-agent-playtest-workspaces.md](docs/adr/0006-agent-playtest-workspaces.md) | duplicate | [LG-03](#lg-03), [LG-04](#lg-04), [LG-05](#lg-05), [LG-07](#lg-07), [Q-E12](#q-e12) | Retained implementation boundary and evidence links. Revisit triggers apply only when the named change is selected; no browser consolidation, new asset batch or broader desktop adapter is implicitly scheduled. |
| BROWSER-ADR.READ | [docs/adr/README.md](docs/adr/README.md) | duplicate | None | Retained implementation boundary and evidence links. Revisit triggers apply only when the named change is selected; no browser consolidation, new asset batch or broader desktop adapter is implicitly scheduled. |
| ARCH.move-1 | [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | duplicate | [HF-03](#hf-03), [TH-04](#th-04), [SC-01](#sc-01) | Class-kit registry ownership transfers to native contracts; no automatic JS registry rewrite. |
| ARCH.move-2 | [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | duplicate | [TH-08](#th-08), [SC-03](#sc-03) | Modifier/transformative build contracts supersede proposed scattered browser-hook refactor. |
| ARCH.move-3 | [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | duplicate | [TH-06](#th-06), [SC-04](#sc-04) | Enemy definition/behavior ownership belongs to native catalogue and encounters. |
| ARCH.move-4 | [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | duplicate | [HF-07](#hf-07), [TH-01](#th-01), [TH-11](#th-11) | Serializable carried build and outer lifecycle retained; old three-stage/30–45 minute proposal is superseded by the current Bible. |
| ARCH.move-5 | [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | duplicate | [HF-07](#hf-07), [HF-09](#hf-09), [TH-21](#th-21), [Q-E05](#q-e05) | Generalized profile direction retained; production JSON protocol does not wholesale import browser localStorage implementation. |
| ARCH.engine-git-debt | [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | superseded | [Q-E07](#q-e07), [Q-E05](#q-e05) | Engine uncertainty is closed by TADR-001; local Git now exists at dc72a02. Unselected cleanup of Game.update, per-kind branches, duplicated audio and collection mixing is not a native build requirement. Browser proofs remain separate; remote/import decisions stay explicit. |
| COMBAT.deflect-mass | [docs/audit-2026-09-05/worker-2-combat.md](docs/audit-2026-09-05/worker-2-combat.md) | parked | None | Roll-Through, mass penalties, Shed Vent and their Sluiceback experiment were not adopted (D02/P09). Old numerical combat economy and 90-second paper fight are retained research, not runnable tasks. |
| COMBAT.kits-counterplay | [docs/audit-2026-09-05/worker-2-combat.md](docs/audit-2026-09-05/worker-2-combat.md) | duplicate | [Q-P11](#q-p11), [Q-P13](#q-p13), [Q-P20](#q-p20), [Q-P25](#q-p25), [TH-03](#th-03), [TH-04](#th-04), [TH-06](#th-06) | Lash Hook, Hop-Jet, Coherence Beam, lightning network, deflect-grade enemy table, offcut redirection and anticipation proposals need selected kit/roster scope; source numbers do not become production defaults. |
| META.cadence | [docs/audit-2026-09-05/worker-3-meta.md](docs/audit-2026-09-05/worker-3-meta.md) | superseded | [TH-11](#th-11), [Q-P12](#q-p12) | Three stages/five beats and 38-minute paper cadence are superseded by the current four-world, 60–75 minute target. No measured full-run result exists. |
| META.unlocks-discovery | [docs/audit-2026-09-05/worker-3-meta.md](docs/audit-2026-09-05/worker-3-meta.md) | question | [Q-P37](#q-p37), [Q-P14](#q-p14), [Q-E09](#q-e09) | Exact unlock triggers, keepsake cog option, class order, first-ten-hours curve, seen/not-taken content, mystery disclosure and Scrapbook tabs remain selected-content choices; no permanent combat-stat grind is adopted. |
| META.collection | [docs/audit-2026-09-05/worker-3-meta.md](docs/audit-2026-09-05/worker-3-meta.md) | question | [Q-P28](#q-p28), [Q-P29](#q-p29), [Q-P34](#q-p34), [Q-P37](#q-p37) | Diorama, generalized field cards, cosmetic titles/finishes and figurine-linked poses require selected narrative/companion/collection scope. Existing browser collection remains preserved. |
| META.social | [docs/audit-2026-09-05/worker-3-meta.md](docs/audit-2026-09-05/worker-3-meta.md) | parked | None | Friend/daily social extension proposals do not enter current offline solo production automatically. No backend, account or challenge service is planned. |
| META.reuse-retire | [docs/audit-2026-09-05/worker-3-meta.md](docs/audit-2026-09-05/worker-3-meta.md) | superseded | [HF-09](#hf-09), [Q-E05](#q-e05) | Production uses accepted native JSON/save contracts. Do not copy progress-store.js wholesale, retire either browser entry, import data or adopt old roster/tuning without scoped authorization. |

## Source inventory

This is the bounded source set inspected for this preparation. The disposition rows above identify actionable work; referenced evidence is retained at its original version. Historical source headings below are navigation descriptions, not current execution state.

| Source | Sections inspected | Treatment |
| --- | --- | --- |
| [BIBLE.md](BIBLE.md) | 1. Pillars & Fantasy; 6. Core Systems; 7. Art Direction; 8. Audio & Feel; Architecture and implementation handoff; Sections 1-9 body and captions; Appendix A repeated prompts excluded | Thirteen core headings mapped; product gaps stay questions; engine-open wording superseded by accepted TADR metadata. All explicit gaps map to Q-P records; completed manuscripts and 25 selected images retain concept-only evidence. |
| [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md) | Character direction picks; World and fiction choices; System gaps carried from planning; Sound and presentation proposal; All character, world, systems, sound and image-choice sections | BD references preserve product-owned values; root maps to product question IDs. BD-01 through BD-17 each map to the corresponding Q-P01 through Q-P17. |
| [COHESION_REPORT.md](COHESION_REPORT.md) | Verdict, corrections, all-image table, nine-section review, retained limits and verification scope | Completed corrections preserved; articulation, size and production evidence remain questions. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Verification; Editing conventions; Handoff and version control; Full file | Browser verification and physical limits retained; no production implementation layout inferred. Documentation-only scope, two entries, evidence classes and provenance preserved; no runtime tests executed. |
| [adr/README.md](adr/README.md) | Decisions to review; Review boundary and next step | Planned ten-section handoff, assembly, full audit and native qualification boundary retained; accepted status supplied by current authorized brief. |
| [adr/TADR-001-engine-language-platforms.md](adr/TADR-001-engine-language-platforms.md) | Context; Options; Decision; Consequences; Later qualification and reconsideration | Settled production engine/platform intent drives paths and future qualification; no runtime claim. |
| [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md) | Context; Options; Decision; Consequences; Later qualification and reconsideration | Explicit hybrid/session/tick/query authority drives runtime and per-system pages. |
| [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md) | Context; Options; Decision; Consequences; Later qualification and reconsideration | Stable Resource identities, admission and schema/roundtrip coverage split into bounded producers. |
| [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md) | Context; Options; Decision; Consequences; Later qualification and reconsideration | Aggregate save protocol, critical lifecycle facts, failure and migration split into foundation and examples. |
| [adr/TADR-005-networking-scope.md](adr/TADR-005-networking-scope.md) | Context; Options; Decision; Consequences; Later qualification and reconsideration | Offline solo remains settled; no networking subsystem tasks. |
| [artifacts/agent-recovery-2026-09-06/README.md](artifacts/agent-recovery-2026-09-06/README.md) | Accepted policy and results; Comparison and rejected variants; Responsiveness and ownership; Limits and retention | Three terminal trials, 76 focused tests and limited pixel reliability preserved as historical evidence. |
| [docs/ART-DIRECTION.md](docs/ART-DIRECTION.md) | Full historical art record | Old miniature and matte constraints superseded by BIBLE Section 7; named image/runtime evidence preserved. |
| [docs/BASELINE-GUIDE.md](docs/BASELINE-GUIDE.md) | Baseline controls; Baseline expedition and collection; Baseline build and verification; Baseline art and implementation | Preserve old yard gameplay, collection, mastery and local-only capture; do not inherit its 15-wave content or budgets into production. |
| [docs/CHARACTER-BIBLE.md](docs/CHARACTER-BIBLE.md) | Headings and candidate roster/status inventory; accepted systems; supporting cast/Scrapbook/voice; notebook alternatives; titles/expressions/motion; next three art studies and evidence limits | Old roster and fixed-stage assumptions superseded; three proposed studies, narrative copy and companion identity questions retained. |
| [docs/COMBAT-DESIGN-SWARM.md](docs/COMBAT-DESIGN-SWARM.md) | Phases; Team; Delivered | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/CONCEPT-STUDY-01.md](docs/CONCEPT-STUDY-01.md) | Output and inspection; Prompt | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/CONCEPT-STUDY-02.md](docs/CONCEPT-STUDY-02.md) | Method and intent; Visual inspection; Generation prompt | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/CONCEPT-STUDY-03.md](docs/CONCEPT-STUDY-03.md) | Selected family, storyboard, method, team review and limits | Completed visual studies retained with unresolved motion/geometry limitation. |
| [docs/CONFLICT-AND-COMBAT.md](docs/CONFLICT-AND-COMBAT.md) | Simultaneous threats, pressure/readability, evidence/open choices and recommended first experiment | No mandatory deflect rule inferred; Sluiceback experiment remains a selected-study question. |
| [docs/DEEP-RESEARCH-SWARM.md](docs/DEEP-RESEARCH-SWARM.md) | Delivered documents; Cross-lane conflicts resolved; Evidence limits | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/DESIGN-AUDIT.md](docs/DESIGN-AUDIT.md) | Evidence basis; Coordinator playfeel probe; The keystone: make mass real; High-impact areas, ranked; What the lanes recommend, condensed; Coordinator reconciliation; Proposed build sequence; Evidence limits | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/DESIGN-INDEX.md](docs/DESIGN-INDEX.md) | Full design desk | Historical navigation, research limits and superseded status accounted. |
| [docs/DISCOVERY.md](docs/DISCOVERY.md) | Accepted notebook interview, publisher direction, historical build/research, production-tool and remaining decisions sections | Established rules retained; explicit content gaps, figurines and later co-op accounted. |
| [docs/ENEMY-ROSTER.md](docs/ENEMY-ROSTER.md) | World headings and proposal/status rows; support roles; elite and difficulty headings; registry fields; historical order; reconciliations and evidence limits | Named library is preserved through roster selection; thirteen inferred additions need bounded qualification, not automatic implementation. |
| [docs/ENEMY-TAXONOMY-SWARM.md](docs/ENEMY-TAXONOMY-SWARM.md) | Phases; Scope and acceptance; Result | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/ENEMY-TAXONOMY.md](docs/ENEMY-TAXONOMY.md) | Family teaching table and PM decisions/evidence/follow-up sections | Completed conceptual follow-up separated from future authored rig and playable miniboss studies. |
| [docs/FIRST-BUILD-CONTRACT.md](docs/FIRST-BUILD-CONTRACT.md) | Integration conventions; Simulation module; Model module; Parent scope; Verification | Historical first proof; increment 01 supersedes old exact interfaces and numbers. |
| [docs/FIRST-BUILD-SWARM.md](docs/FIRST-BUILD-SWARM.md) | Frame/Fan out/Aggregate/Report; Verification checkpoint; Integration decisions | Completed first-proof teamwork, local staged admission and evidence history; no automatic engine/class/expedition continuation. |
| [docs/FIRST-BUILD-VERIFICATION.md](docs/FIRST-BUILD-VERIFICATION.md) | Accepted scope; Executed checks; Visual inspection; Playtest limits and next decisions | Keep exact historical browser evidence and forward outstanding human/hardware/content questions. |
| [docs/HANDWRITTEN-NOTES.md](docs/HANDWRITTEN-NOTES.md) | Photo 1: game rule; Photo 2: game design ideas, continued; Photo 3: adaptive character and dungeon worlds; Photo 4: characters, continued; Accepted later clarification; Historical interpretation for Scrapkeep; Clarifications worth preserving | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/LEAD-CAPTURE.md](docs/LEAD-CAPTURE.md) | Commands; Environment; API; Local records; Unconfigured messaging | Preserved optional local browser service; distribution and messaging are outside the selected production scope. |
| [docs/LEVEL-DESIGN.md](docs/LEVEL-DESIGN.md) | Accepted structure; section inventory; procedural technique/schema; branch/defense/boss proposal inventory; four-world pacing; historical worked example/telemetry and evidence limits | Generation, selected encounter types and physical dimensions remain open. Historical schedule and thresholds not adopted. |
| [docs/LIGHTNING-VERIFICATION.md](docs/LIGHTNING-VERIFICATION.md) | Result and limits; Executed checks; Sustained rendered load; Evidence | Exact historical browser evidence, synthetic/human separation and RTX 4080 scope retained. |
| [docs/MARKET-RESEARCH.md](docs/MARKET-RESEARCH.md) | Finding, comparisons, commercial limits, three proposed relationships, team and next evidence | Completed dated study preserved; proposed experiments and unmeasured enjoyment/demand are separately gated. |
| [docs/MARKET-SOURCES.md](docs/MARKET-SOURCES.md) | Snapshot, review method/IDs, player-report caveat and interpretation | Dated convenience sample is evidence of reported opinions only; no current pricing or representative-demand claim. |
| [docs/ORCHARD-ENCOUNTER-STUDY.md](docs/ORCHARD-ENCOUNTER-STUDY.md) | What this study settles provisionally; Ninety-second teaching encounter; Four poses to carry through animation; Clearance and camera contract for a future greybox; Salvage that remembers its previous job; Boss damage changes the place; Evidence and production landing | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/ORCHARD-VISUAL-SWARM.md](docs/ORCHARD-VISUAL-SWARM.md) | Scope; Decisions during aggregation; Deliverables; Review result | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/PLANNING-PREP-SWARM.md](docs/PLANNING-PREP-SWARM.md) | What ran; Ground-truth check; Evidence limits | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [docs/RUNTIME-BLUEPRINT.md](docs/RUNTIME-BLUEPRINT.md) | 1. System ownership; 2. Run coordination and checkpoints; 3. Content and build interfaces; 4. Permanent profile and migration; 5. Scene and asset lifecycle; 6. Movement and encounter physics; 7. Input and dashboard; 8. Audio and character expression; 9. Validation strategy; 10. Remaining implementation decisions and engine gate; Evidence limits | Target contracts and validation scenarios reused; old DOM/Three.js engine-open prescriptions limited to browser proofs. |
| [docs/WORLD-ENVIRONMENTS.md](docs/WORLD-ENVIRONMENTS.md) | Opening scope, world rewards, historical snapshot, shared rules, candidate-kit headings, next biome and evidence limits | Seven kits remain candidates; first region, mechanics, weather/signs and figurine chips are questions. |
| [docs/adr/0001-two-playable-entries.md](docs/adr/0001-two-playable-entries.md) | Context/decision; Consequences and revisit conditions | Historical browser/player implementation boundaries, distinct from accepted production TADRs. |
| [docs/adr/0002-simulation-boundary.md](docs/adr/0002-simulation-boundary.md) | Context/decision; Consequences and revisit conditions | Historical browser/player implementation boundaries, distinct from accepted production TADRs. |
| [docs/adr/0003-authoritative-attack-geometry.md](docs/adr/0003-authoritative-attack-geometry.md) | Context/decision; Consequences and revisit conditions | Historical browser/player implementation boundaries, distinct from accepted production TADRs. |
| [docs/adr/0004-procedural-prototype-assets.md](docs/adr/0004-procedural-prototype-assets.md) | Context/decision; Consequences and revisit conditions | Historical browser/player implementation boundaries, distinct from accepted production TADRs. |
| [docs/adr/0005-caster-input-and-dashboard.md](docs/adr/0005-caster-input-and-dashboard.md) | Context; Decision; Consequences; Revisit trigger | Current cancel/clear/capture semantics are a production contract reference, not native implementation. |
| [docs/adr/0006-agent-playtest-workspaces.md](docs/adr/0006-agent-playtest-workspaces.md) | Context/decision; Consequences and revisit conditions | Historical browser/player implementation boundaries, distinct from accepted production TADRs. |
| [docs/adr/README.md](docs/adr/README.md) | Context/decision; Consequences and revisit conditions | Historical browser/player implementation boundaries, distinct from accepted production TADRs. |
| [docs/audit-2026-09-05/worker-1-architecture.md](docs/audit-2026-09-05/worker-1-architecture.md) | Module map; Extensibility assessment; Top 5 architectural moves; Duplication and divergence; Engine question; Risks and debt | Source-read historical proposals; current TADRs govern native architecture and explicit questions gate scope. |
| [docs/audit-2026-09-05/worker-2-combat.md](docs/audit-2026-09-05/worker-2-combat.md) | Defensive rhythm; Mass currency; Class kit skeletons; Enemy counterplay grammar; Anticipation beats; Written fight; Evidence limits | Paper combat alternatives and tuning cannot supersede current movement/kit rulings. |
| [docs/audit-2026-09-05/worker-3-meta.md](docs/audit-2026-09-05/worker-3-meta.md) | Expedition skeleton; Unlock architecture; Discovery-as-progression; Collection layer; Return hooks; Reuse-or-retire; Open items | Current route/lifecycle rules supersede old pacing; optional content stays explicitly selected. |
| [docs/audit-2026-09-05/worker-4-universe.md](docs/audit-2026-09-05/worker-4-universe.md) | Enemy silhouette rule, figurine-readiness and five-step art pipeline | Every next art step has a question or superseded disposition; physical print claims remain unproved. |
| [docs/project/AGENT-PLAYTEST-ENGINEERING.md](docs/project/AGENT-PLAYTEST-ENGINEERING.md) | Carry-forward map; Operational desktop foundation; Ordered work and completion checks; Resume the next engineering unit; Evidence boundaries | Completed bounded tooling evidence retained; remaining browser/player units decomposed separately from Godot. |
| [docs/project/ASSETS.md](docs/project/ASSETS.md) | Asset and tool provenance; Full provenance inventory and admission/release paragraphs | Current prototype source/license inventory only; final release policy stays Q-E06. Current asset evidence supports the art/audio briefs; future production source/license details remain required. |
| [docs/project/BACKLOG.md](docs/project/BACKLOG.md) | Ordered backlog; Completed planning decisions; Completed this closeout | Every P01–P14 and T01–T13 disposition retained individually. |
| [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) | Current rulings; Tier A; Tier B; Tier C; Accepted notebook rulings and remaining lifecycle detail; Evidence limits | Every D01–D58 mapped individually; old art/engine assumptions superseded; unselected legacy candidates explicitly parked. |
| [docs/project/HOUSEKEEPING.md](docs/project/HOUSEKEEPING.md) | Work sequence; Environment constraint; Results; Remaining work | Completed closeout at dated evidence; root TRACKING owns later status. |
| [docs/project/INCREMENT-01-lightning-playtest.md](docs/project/INCREMENT-01-lightning-playtest.md) | Goal; Requirements; Exclusions; Ownership; Acceptance; Gate; Closeout; Integration contract | Historical approval and browser completion kept separate from future production. |
| [docs/project/PLANNING.md](docs/project/PLANNING.md) | Roles; Phases 0–4; What this protocol does not do | Separate preparation, engineering documentation and gameplay go gates retained. |
| [docs/project/README.md](docs/project/README.md) | Sources of truth; Start the next session; Full project desk | Navigation and old dynamic status reconciliation left to root. Navigation and dated status given to root for minimal reconciliation. |
| [docs/project/REQUIREMENTS.md](docs/project/REQUIREMENTS.md) | R01-R20 and change rule | Every requirement individually mapped; bounded prototype claims are not full-game completion. |
| [docs/research-2026-09-05/REVIEW-NOTES.md](docs/research-2026-09-05/REVIEW-NOTES.md) | Character bible (CHARACTER-BIBLE.md); Enemy roster (ENEMY-ROSTER.md); World environments (WORLD-ENVIRONMENTS.md); Level design (LEVEL-DESIGN.md); Runtime blueprint (RUNTIME-BLUEPRINT.md); Cross-lane conflicts (all resolved in-run); Conflict fix notes | All unnumbered planning to-dos, findings, rulings and evidence limits have explicit coverage rows. Historical completed work remains method-limited; current task/question IDs hold the surviving work. |
| [tools/agent-player/README.md](tools/agent-player/README.md) | Commands; Evidence and interpretation; Maintained boundaries | Current runner, supported configured rewards and unsupported arbitrary equipment editing confirmed. |
