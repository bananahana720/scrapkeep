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
- [Source dispositions and inventory](docs/project/SOURCE-DISPOSITIONS.md)

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

## Source records

Source dispositions and the source inventory live in [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md), moved there verbatim on 6 September 2026. The coordinator owns that file. It preserves every P/T/R/D/BD identifier, the unnumbered planning obligations, core-system headings, selected concept-art receipts and requested engineering sections, and its task and question links point back to the cards and questions in this file. A disposition row grants no task completion, native support claim or implementation authorization.
