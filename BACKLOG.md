# Scrapkeep execution backlog

Edition 3 · Updated 15 September 2026 · HF cards amended and split per the accepted AI-first audit under PS-04; PUB-01 revision 2 includes the completed repository-local workflow package; AR-08 reconciled the sprint prose with the admitted state; FR-02, NP-01 and Q-P39 imported from the 15 September adversarial review

Use **an in-repo board in [TRACKING.md](TRACKING.md)** to keep assignments, evidence and integration history beside the work. This board was selected while the checkout was local-only and remains the sole execution board after private GitHub publication.

This file turns the approved planning into bounded work. It contains no live execution status. [TRACKING.md](TRACKING.md) owns task/question state and recorded answers; [ORCHESTRATOR.md](ORCHESTRATOR.md) owns assignment, review and integration. The [Bible](BIBLE.md) remains product authority and the [accepted ADRs](adr/README.md) remain architecture authority. A historical proposal never overrides either.

Godot 4.7.2 standard, typed GDScript, explicit hybrid/session ownership, native Resource/scene content, JSON aggregate saves and offline solo are settled. The approved art direction and 1/2/4/8 branching trees are settled. Old engine-open, matte-only and fan-shaped-tree references do not reopen them.

The initial authorization covered preparation documents. Andrew subsequently authorized private publication in PUB-01 and the [operational Sprint 0 proof scope](docs/project/sprint-0/AUTHORIZATION.md). The fourteen-card foundation set below is a dependency programme, not a dispatch authorization; it was authorized as documentation-only work on 6 September 2026. Authorization lives in `TRACKING.md` ([program authorization](TRACKING.md#program-authorization)); this file never grants it. TECH_BIBLE.md and its full AUDIT_REPORT.md remain future outputs; no production feature work is authorized by these definitions.

## Navigation

- [Proposed first sprint](#proposed-first-sprint)
- [Task catalogue](#task-catalogue) and individual cards, including the [asset production cards](#asset-production-cards-16-september-2026)
- [World 1 and scaling backlog](#world-1-and-scaling-backlog-12-november-2026): the buildable rows for world 1 now and the groundwork for more stages, worlds and features
- [Open questions](#open-questions)
- [Source dispositions and inventory](docs/project/SOURCE-DISPOSITIONS.md)

## Task contract

Cards retain revision 1 from preparation handoff unless a recorded definition change raised them. After the accepted 6 September audit, HF-01, HF-02, HF-05, HF-08, HF-09 and HF-10 are revision 2, and HF-03a/b, HF-04a/b, HF-06a/b and HF-07a/b are the revision-1 replacements of four split cards. PUB-01 is a separate revision-2 publication card. S means one bounded deliverable; M means coupled changes with one acceptance boundary. L is a nonassignable parent and must be split before admission. There are no assignable L cards here. Card revisions are immutable when pinned to an attempt; retain old revisions in the admitted source snapshot and record changes in TRACKING.

All workers read the Bible sections and accepted ADR sections their card names, this card, ORCHESTRATOR.md, TRACKING.md and CONTRIBUTING.md. Sources below give the exact additional sections and prerequisites. The coordinator supplies these files and accepted dependency evidence in a self-contained packet; no worker must recover conversation history. A dependency output is a future input until its producer is done. A listed output path is permitted scope, not an existing file or a live lease. Every `docs/tech/sections/` output uses the headings Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed and Evidence limits. The coordinator checks those headings and every local `#anchor` on admission with `npm run check:docs`; `npm run check:project` validates file links only.

For documentation cards, completion means a reviewed, source-cited contract, not a running implementation. Every output identifies sources, unresolved question IDs, procedure actually performed and evidence limits. Work under `artifacts/local/tasks/ID/` (ignored). At handoff copy every receipt the coordinator will cite into `artifacts/foundation-sprint-2026-09/tasks/ID/` and list each file in the candidate manifest, because `artifacts/local/` is not committed. Workers return disjoint section drafts; the coordinator admits shared documents serially.

Native implementation cannot yet receive complete atomic cards: the production ownership map and system/schema contracts are future inputs, and the selected qualification/content scope is missing. Q-E01 and the affected product questions explicitly gate that work. After their closure, the coordinator creates scoped implementation cards with exact paths and measurable behavior. Contract completion never closes the corresponding production behavior by implication.

The LG cards apply only to the maintained browser proofs/player. They require a separately admitted work wave. Existing browser code, both entries, profiles and named evidence remain intact. Physical-device availability or required Andrew feedback must be confirmed before the applicable card becomes ready.

## Proposed first sprint

Fourteen foundation-contract cards form one closed dependency set. Andrew authorized the whole fourteen-card set as documentation-only work at [TRACKING.md](TRACKING.md) EV-0078; the board's task index owns each card's current state. HF-01 and HF-02 have no predecessors; every other predecessor is inside this foundation programme. Open questions that shape a card are registered on it as non-blocking; each such contract must hold under every candidate answer, and HF-07b may submit a proposed Q-E09 protocol. Unknown values remain named and gate later implementation. The S0 prepare-stage proofs are a separate family scheduled into the writer slots these waves leave idle.

| ID | Outcome | Dependencies | Owner / size |
| --- | --- | --- | --- |
| [HF-01](#hf-01) | Specify production paths and contribution conventions | None | Conventions / M |
| [HF-02](#hf-02) | Create constraints and evidence register | None | Verification / S |
| [HF-03a](#hf-03a) | Specify module ownership and owned records | [HF-01](#hf-01) | Runtime / M |
| [HF-03b](#hf-03b) | Specify dependency edges and interface walkthroughs | [HF-03a](#hf-03a) | Runtime / M |
| [HF-04a](#hf-04a) | Specify tick, pause and scene lifecycle | [HF-03a](#hf-03a) | Runtime / M |
| [HF-04b](#hf-04b) | Specify runtime patterns and typed sketches | [HF-04a](#hf-04a) | Runtime / M |
| [HF-05](#hf-05) | Specify stable content identity and admission | [HF-03a](#hf-03a) | Content / M |
| [HF-06a](#hf-06a) | Inventory authored content and its treatment | [HF-05](#hf-05) | Content / M |
| [HF-06b](#hf-06b) | Map matrix rows to persistence projections | [HF-06a](#hf-06a) | Persistence / M |
| [HF-07a](#hf-07a) | Specify the save envelope and preferences record | [HF-06b](#hf-06b) | Persistence / S |
| [HF-07b](#hf-07b) | Specify durable commit boundaries | [HF-04a](#hf-04a), [HF-07a](#hf-07a) | Persistence / M |
| [HF-08](#hf-08) | Specify save failure and conservative recovery | [HF-07b](#hf-07b) | Persistence / M |
| [HF-09](#hf-09) | Specify schema and gameplay-content migration | [HF-06b](#hf-06b), [HF-07b](#hf-07b) | Persistence / M |
| [HF-10](#hf-10) | Review the complete foundation contract | [HF-01](#hf-01), [HF-02](#hf-02), [HF-03a](#hf-03a), [HF-03b](#hf-03b), [HF-04a](#hf-04a), [HF-04b](#hf-04b), [HF-05](#hf-05), [HF-06a](#hf-06a), [HF-06b](#hf-06b), [HF-07a](#hf-07a), [HF-07b](#hf-07b), [HF-08](#hf-08), [HF-09](#hf-09) | Independent review / M |

Schedule in dependency waves under the two-writer ceiling. W1 HF-01 and HF-02. W2 HF-03a beside S0-01. W3 HF-04a and HF-05. W4 HF-03b and HF-04b. W5 HF-06a beside S0-05. W6 HF-06b beside S0-07. W7 HF-07a beside S0-04. W8 HF-07b beside S0-08. W9 HF-08 and HF-09. W10 HF-10, whose reviewer slot leaves a writer slot for S0-06. S0-02 and S0-03 precede W1; they need no engine and make the integration checks executable. These are dependency waves, not promises of duration. A reviewer uses one of the three delegate slots, and one fresh reviewer may read a wave's two candidates together. After HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b and HF-05 are admitted, the coordinator runs one integrated read of them before assigning HF-06a; findings return through changes_requested. Early completed work may proceed through review while the other writer runs if ownership is disjoint. The audit's seven-wave order placed S0-01 beside HF-03, S0-05 and S0-07 beside HF-06, and S0-04, S0-06 and S0-08 beside HF-07 with spill into the next idle slot; the four splits add three waves under the same ceiling, and each proof lands before or beside the card whose "re-verify when S0-0x lands" trigger names it, or that trigger fires on the admitted card.

HF-10 produces a scoped foundation review. It does not stand in for all per-system designs, the assembled TECH_BIBLE.md or TH-31's final architecture audit. That later audit must separate paper schema consistency from unperformed native roundtrip qualification.

## Task catalogue

HF covers foundation contracts; S0 covers prepare-stage tooling and executable ADR proofs; PD covers production-facing briefs; TH covers later engineering sections and assembly; SC splits authored schema families; LG preserves bounded browser/player work. Numeric ordering does not override dependencies.

| ID | Concrete outcome | Role | Size |
| --- | --- | --- | --- |
| [PUB-01](#pub-01) | Publish SCRAPKEEP privately and record the session handoff | Coordinator | M |
| [HF-01](#hf-01) | Specify production paths and contribution conventions | Conventions | M |
| [HF-02](#hf-02) | Create constraints and evidence register | Verification | S |
| [HF-03a](#hf-03a) | Specify module ownership and owned records | Runtime | M |
| [HF-03b](#hf-03b) | Specify dependency edges and interface walkthroughs | Runtime | M |
| [HF-04a](#hf-04a) | Specify tick, pause and scene lifecycle | Runtime | M |
| [HF-04b](#hf-04b) | Specify runtime patterns and typed sketches | Runtime | M |
| [HF-05](#hf-05) | Specify stable content identity and admission | Content | M |
| [HF-06a](#hf-06a) | Inventory authored content and its treatment | Content | M |
| [HF-06b](#hf-06b) | Map matrix rows to persistence projections | Persistence | M |
| [HF-07a](#hf-07a) | Specify the save envelope and preferences record | Persistence | S |
| [HF-07b](#hf-07b) | Specify durable commit boundaries | Persistence | M |
| [HF-08](#hf-08) | Specify save failure and conservative recovery | Persistence | M |
| [HF-09](#hf-09) | Specify schema and gameplay-content migration | Persistence | M |
| [HF-10](#hf-10) | Review the complete foundation contract | Independent review | M |
| [S0-01](#s0-01) | Pin the Godot 4.7.2 toolchain and prove a typed offline headless boot | Verification | M |
| [S0-02](#s0-02) | Add the documentation-only check command | Tooling | S |
| [S0-03](#s0-03) | Add the verification-scope selector and reserve the native check command | Verification | S |
| [S0-04](#s0-04) | Prove runtime ownership under TADR-002 and TADR-005 | Runtime | M |
| [S0-05](#s0-05) | Prove typed Resource identity, admission and immutability headlessly | Content | S |
| [S0-06](#s0-06) | Prove binary-tree admission rejection and failed-reload retention | Content | S |
| [S0-07](#s0-07) | Author the TADR-004 save-owner proof and fixtures | Persistence | S |
| [S0-08](#s0-08) | Execute the TADR-004 proof and record evidence | Verification | S |
| [S0-09](#s0-09) | Export presets and CI smoke workflow (parked) | Verification | M |
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

**Card revision:** 3 · **Owner:** Conventions · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (scene/Resource ownership, source assets and generated imports)
- [CONTRIBUTING.md § Editing conventions](CONTRIBUTING.md#editing-conventions)
- [CONTRIBUTING.md § Handoff and version control](CONTRIBUTING.md#handoff-and-version-control) (commit and PR rules)
- [docs/adr/0001-two-playable-entries.md](docs/adr/0001-two-playable-entries.md) (both browser entries stay preserved)
- [docs/project/ASSETS.md](docs/project/ASSETS.md) and [artifacts/README.md](artifacts/README.md) (asset provenance and output retention)
- [BIBLE.md § Architecture and implementation handoff](BIBLE.md#architecture-and-implementation-handoff)
- Godot 4.7 project-organization documentation, resolved by the coordinator and supplied in the packet; the card cites the resolved page, not memory.

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-01-production-conventions.md`; `artifacts/local/tasks/HF-01/`. The coordinator pre-creates `docs/tech/sections/` with an index stub before wave 1 so that HF-01 and HF-02 hold file-level leases.

**Definition of done:**

1. One path-family table with the columns path family (glob), owner role, permitted content, forbidden content and governing ADR line. It covers scripts, scenes, definition Resources, source assets, generated imports, tests, tools and docs. No row overlaps `/`, `/orchard.html`, `src/`, `server/`, `tests/`, `tools/` or `artifacts/`. Reconcile against the admitted S0-01 scaffold and record the checked revision.
2. Specify contribution rules for source assets, generated imports, validation and documentation ownership; preserve both browser entries and data.
3. List exact implementation path families that later scoped cards may own, including the `native/` root that S0-01 materializes. Reconcile those families against the admitted S0-01 scaffold without moving existing files.
4. State naming, the typed GDScript boundary, scene/Resource ownership, code style, commit/PR rules and a numbered definition-of-done checklist a reviewer can tick. Convention changes cannot create a remote or authorize publication.
5. For each engine-layout fact (project root, cache and import sidecar locations, export presets), record its evidence status and exact source/proof identity. Use "unverified until a scaffold proof exists" for a layout claim lacking an applicable proof. Reconcile the admitted S0-01 evidence and later admitted Sprint 0 evidence separately; a boot proof does not prove every import or export detail.

**Verification and evidence:**

- Review the path table for overlap with both browser entries and historical evidence.
- Check every convention against the accepted engine/content ADRs and existing contribution requirements.
- Check the table has all five columns and every S0-01 native implementation file falls inside exactly one row. Separately account for every admitted S0-01 support/configuration/documentation file and its required disposable evidence destinations, naming existing ownership without granting production path ownership. No production row may overlap the protected browser, tooling or artifact paths in DoD 1.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-02"></a>

### HF-02: Create constraints and evidence register

**Card revision:** 2 · **Owner:** Verification · **Size:** S · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Later qualification and reconsideration](adr/TADR-001-engine-language-platforms.md#later-qualification-and-reconsideration)
- [docs/LIGHTNING-VERIFICATION.md § Sustained rendered load](docs/LIGHTNING-VERIFICATION.md#sustained-rendered-load)
- [docs/FIRST-BUILD-VERIFICATION.md](docs/FIRST-BUILD-VERIFICATION.md), [artifacts/performance-stress.json](artifacts/performance-stress.json) and [artifacts/performance-stress-final.json](artifacts/performance-stress-final.json) (historical browser measurements)
- [adr/TADR-004-persistence.md § Consequences](adr/TADR-004-persistence.md#consequences)
- [Q-E03](#q-e03), [Q-E04](#q-e04) and [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) row D28
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-02-constraints-evidence.md`; `artifacts/local/tasks/HF-02/`.

**Definition of done:**

1. Separate approved constraints, proposed budgets, historical browser measurements and unmeasured native requirements. Every row carries exactly one of those four classifications.
2. Define units, workload, target identity, sampling method and owner required to admit frame, memory, load and asset budgets. A skeleton whose native rows read "unmeasured" is a valid S completion. Re-verify when S0-01 lands, which produces the first native run record; the first measurement under Q-E03 supersedes the row.
3. Negative check. No numeric frame, memory, load or asset value appears without a `measured:<artifact path>` or `proposed:Q-E03` tag. Record Q-E03/Q-E04 without inventing hardware, renderer or numeric limits.

**Verification and evidence:**

- Trace each claimed measurement to exact retained evidence and identify its method/version limits.
- Grep every numeric budget cell for its `measured:` or `proposed:` tag and its unit.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-03a"></a>

### HF-03a: Specify module ownership and owned records

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (content-admission owner)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (persistence owner)
- [BIBLE.md § Architecture and implementation handoff](BIBLE.md#architecture-and-implementation-handoff)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- Godot 4.7 documentation for autoload, `class_name` and `preload`, resolved by the coordinator and supplied in the packet.

**Dependencies:** [HF-01](#hf-01). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-03a-module-map.md`; `artifacts/local/tasks/HF-03a/`.

**Definition of done:**

1. One module table with the columns module, owned mutable records, allowed imports, exposed commands and published results, under one session authority. Re-verify when S0-01 lands, because allowed imports drift from observed autoload, `class_name` and `preload` behavior.
2. Assign collision queries, encounter timing, run/profile mutation, persistence, content admission and presentation to explicit owners. Each owner row cites its TADR line.
3. Name every record that exactly one module may mutate. A record with two owners is a defect in the output, not a note.

**Verification and evidence:**

- Inspect the table for a module with no owned record and for a record with two owners.
- Check each owner assignment against the cited TADR lines.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-03b"></a>

### HF-03b: Specify dependency edges and interface walkthroughs

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [docs/adr/0003-authoritative-attack-geometry.md](docs/adr/0003-authoritative-attack-geometry.md) (attack walkthrough precedent)
- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows), [BIBLE.md § Inventory, equipment and transformations](BIBLE.md#inventory-equipment-and-transformations) and [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)

**Dependencies:** [HF-03a](#hf-03a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-03b-dependency-graph.md`; `artifacts/local/tasks/HF-03b/`.

**Definition of done:**

1. An adjacency list of allowed dependency edges between HF-03a modules, from which a reviewer's cycle check reproduces. Forbid hidden gameplay mutation through signals or rendering. Re-verify when S0-04 lands.
2. Three walkthroughs (an attack, an equipment change, an encounter replacement) appear in the output as step tables naming the interface used at each step.
3. Every walkthrough step uses a listed edge. A step that needs an unlisted edge is a defect to report, not an edge to add silently.

**Verification and evidence:**

- Reproduce the cycle check from the adjacency list and record the result.
- Check each walkthrough step against the edge list and the HF-03a owner table.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-04a"></a>

### HF-04a: Specify tick, pause and scene lifecycle

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-002-runtime-model.md § Later qualification and reconsideration](adr/TADR-002-runtime-model.md#later-qualification-and-reconsideration) (pause qualification)
- [docs/adr/0005-caster-input-and-dashboard.md](docs/adr/0005-caster-input-and-dashboard.md) (focus-loss precedent the production rule preserves)
- [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings) and [BIBLE.md § Movement, camera and active aim](BIBLE.md#movement-camera-and-active-aim)
- `docs/tech/sections/HF-02-constraints-evidence.md` from [HF-02](#hf-02) (unresolved rates land in its register)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)

**Dependencies:** [HF-03a](#hf-03a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04a-runtime-lifecycle.md`; `artifacts/local/tasks/HF-04a/`.

**Definition of done:**

1. Define fixed-tick phases, command admission, collision synchronization, published result lifetime and overload policy. Unresolved rates are labelled and routed to HF-02's register under Q-E03. Re-verify when S0-04 lands.
2. Separate release of held input, cancellation of prepared actions, solo pause and resume as four operations, each with its own owner and order. Re-verify when S0-04 lands.
3. Define encounter replacement and scoped connection teardown while run/profile ownership survives.
4. Enumerate every engine callback that may advance gameplay time and name exactly one owner. List every other callback under a Forbidden heading.
5. Five tabletop scenarios (start, focus loss during preparation, pause and resume, slow frame, scene replacement) appear in the output as step tables identifying each owner and order.

**Verification and evidence:**

- Check no path permits a second tick owner, a replayed held action or a stale scene callback.
- Check each scenario step against the callback list in item 4.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-04b"></a>

### HF-04b: Specify runtime patterns and typed sketches

**Card revision:** 2 · **Owner:** Runtime · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (typed GDScript)
- Godot 4.7 static-typing documentation, resolved by the coordinator and supplied in the packet.
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (owner map, admitted before assignment)
- [docs/tech/proofs/S0-04-runtime-ownership.md](docs/tech/proofs/S0-04-runtime-ownership.md), particularly Contract, Scenarios, Unresolved questions and Evidence limits
- The seven source scripts under `native/proofs/tadr-002/`, pinned to their admitted source identity
- `artifacts/prepare-stage-2026-09-06/tasks/S0-04/S0-04-int-proof-run.txt` and `S0-04-int-proof-fault.txt`

**Dependencies:** [HF-04a](#hf-04a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04b-runtime-patterns.md`; `artifacts/local/tasks/HF-04b/`.

**Definition of done:**

1. Name the game-loop, state-machine, scoped signal/message and scene-lifecycle patterns and when not to use each. Document time/tick ownership and event ordering under HF-04a.
2. For the game-loop, state-machine and scoped signal/message patterns, replace inline sketches with links to the applicable admitted S0-04 source. Link `native/proofs/tadr-002/encounter_coordinator.gd` for the single physics-callback owner, queued command admission and minimal prepared/cast transitions; `session_owner.gd`, `input_adapter.gd` and `menu_probe.gd` for input release, prepared-action cancellation, pause and resume; and `intruder.gd` with `proof_runner.gd` phase B for rejection of a second mutation source. Each example identifies its source commit, the assertion or phase that exercised it, the retained normal and fault-run evidence, and the behavior those assertions establish. State explicitly that these examples do not prove a complete production state machine, positive committed-result signal delivery or scoped connection teardown. Retain a minimal typed scene-lifecycle sketch marked "unparsed: no editor run in this card; scene replacement and scoped teardown await a later authorized proof". Reconcile every example and remaining paper contract against the admitted HF-04a lifecycle contract. Record the S0-04 trigger as satisfied by source and retained-evidence review; no native execution occurs in this card.
3. State for each pattern which HF-03a module may own it.

**Verification and evidence:**

- Confirm each linked source file and retained receipt exists; identify the exact assertion supporting each claimed behavior; inspect proof discovery and the pinned typing configuration without executing them. Check that every remaining inline sketch carries the unparsed marker, every pattern names its HF-03a owner, and no example substitutes a proof default or untested behavior for the admitted HF-04a contract.
- The reviewer confirms presence and typed form only; no sketch is executed under this card.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-05"></a>

### HF-05: Specify stable content identity and admission

**Card revision:** 2 · **Owner:** Content · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (catalogue/content revisions and pinning)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (path families)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- [docs/project/ASSETS.md](docs/project/ASSETS.md)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-03a](#hf-03a). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-05-content-admission.md`; `artifacts/local/tasks/HF-05/`.

**Definition of done:**

1. Define stable domain IDs, catalogue/content revisions, immutable Resource definitions and fresh session records. Immutability is an enforced rule, not a file-extension guarantee. Re-verify when S0-05 lands.
2. A state table (draft, imported, structurally valid, semantically valid, admitted, rejected-reload, pinned) with its transitions and the safe boundary at which each occurs. Re-verify when S0-06 lands.
3. Define missing-ID diagnostics, naming the diagnostic and its fields, and active-run content pinning without silent remapping.
4. Four traces (a draft, an admitted definition, a rejected reload, a pinned active run) appear in the output as step tables over the item 2 states.

**Verification and evidence:**

- Check identity remains independent of display name, file path and engine Resource ID.
- Check every trace uses only item 2 transitions.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-06a"></a>

### HF-06a: Inventory authored content and its treatment

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (the eight-family enumeration)
- [adr/TADR-003-content-pipeline.md § Later qualification and reconsideration](adr/TADR-003-content-pipeline.md#later-qualification-and-reconsideration)
- [BIBLE.md § 3. Maps & Areas](BIBLE.md#3-maps--areas), [§ 4. Characters](BIBLE.md#4-characters), [§ 5. Weapons & Items](BIBLE.md#5-weapons--items), [§ 6. Core Systems](BIBLE.md#6-core-systems), [§ 7. Art Direction](BIBLE.md#7-art-direction), [§ 8. Audio & Feel](BIBLE.md#8-audio--feel) and [§ 9. Glossary](BIBLE.md#9-glossary)
- `artifacts/local/tasks/HF-06a/nouns.md`, the coordinator-supplied noun list drawn from the BIBLE § 3-9 headings and included in the packet
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (owned definitions)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)

**Dependencies:** [HF-05](#hf-05). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P14](#q-p14), [Q-P15](#q-p15), [Q-E09](#q-e09). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-06a-schema-inventory.md`; `docs/tech/sections/HF-06a-schema-inventory.csv`; `artifacts/local/tasks/HF-06a/`.

**Definition of done:**

1. A matrix with one row per TADR-003 § Decision family plus one row per noun in the supplied `nouns.md`. Each row has a stable row ID and exactly one treatment: schema, embedded-record, or excluded with a rationale. Re-verify when S0-05 lands, because ID-versus-path identity drifts.
2. Each row names the producing card (SC-01 through SC-08, or a TH card) that will author its definition schema.
3. A machine-readable copy (CSV) carries the same row IDs. Nine downstream cards reference "HF-06 matrix rows" by these IDs.
4. Rows shaped by Q-P14, Q-P15 or Q-E09 carry the question ID and a treatment that holds under every candidate answer.

**Verification and evidence:**

- Cross-check every supplied noun and every family against the matrix.
- Check row IDs are unique and the CSV and Markdown agree one for one.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-06b"></a>

### HF-06b: Map matrix rows to persistence projections

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision)
- [adr/TADR-003-content-pipeline.md § Consequences](adr/TADR-003-content-pipeline.md#consequences)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05)
- `docs/tech/sections/HF-06a-schema-inventory.md` and `.csv` from [HF-06a](#hf-06a) (must be admitted before assignment)

**Dependencies:** [HF-06a](#hf-06a). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P14](#q-p14), [Q-P15](#q-p15), [Q-E09](#q-e09). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-06b-persistence-projection.md`; `docs/tech/sections/HF-06b-persistence-projection.csv`; `artifacts/local/tasks/HF-06b/`.

**Definition of done:**

1. For every HF-06a row, one save column value from json-projection, transient-reconstructed or immutable-by-id; the latter two carry a rationale. Immutable Resources are not serialized as live engine objects.
2. For each json-projection row, name the authoring codec, the save projection and the card owning the executable roundtrip proof (TH-22). Re-verify when S0-08 lands.
3. A machine-readable copy keyed by the HF-06a row IDs.
4. Device, companion and discovery rows hold under every candidate answer to Q-P15 and Q-E09.

**Verification and evidence:**

- Check every HF-06a row has exactly one save column value.
- Check no row serializes a Resource as a live engine object.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-07a"></a>

### HF-07a: Specify the save envelope and preferences record

**Card revision:** 1 · **Owner:** Persistence · **Size:** S · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Context](adr/TADR-004-persistence.md#context) and [§ Decision](adr/TADR-004-persistence.md#decision)
- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves) and [BIBLE.md § HUD, dashboard and settings](BIBLE.md#hud-dashboard-and-settings) (preferences)
- [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) rows D26 and D27
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (owning modules)
- `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)

**Dependencies:** [HF-06b](#hf-06b). **Blocking questions:** None. **Registered non-blocking questions:** [Q-E09](#q-e09), [Q-P16](#q-p16). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-07a-save-envelope.md`; `docs/tech/sections/HF-07a-save-envelope.csv`; `artifacts/local/tasks/HF-07a/`.

**Definition of done:**

1. A field table for the envelope (schema version, content revision, generation, transaction), profile, checkpoint, lifecycle facts and the separate preferences record. Each field has a type, an owning module from HF-03a and a source or question ID. Re-verify when S0-07 lands.
2. A stable anchor per field group and a machine-readable copy. HF-07b, HF-08, HF-09, TH-11 and TH-21 reference fields by these names.
3. Fields shaped by Q-E09 or Q-P16 carry the question ID and a shape that holds under every candidate answer.

**Verification and evidence:**

- Check every field carries all three attributes.
- Check the envelope identifies generation, content and transaction without a field that only one candidate policy needs.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-07b"></a>

### HF-07b: Specify durable commit boundaries

**Card revision:** 1 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (revival and interruption hold on a failed write)
- [Q-P16](#q-p16) and [Q-E09](#q-e09)
- [docs/project/DECISION-REGISTER.md](docs/project/DECISION-REGISTER.md) rows D26 and D27
- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves)
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (level completion seam)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) (must be admitted before assignment)

**Dependencies:** [HF-04a](#hf-04a), [HF-07a](#hf-07a). **Blocking questions:** None. **Registered non-blocking questions:** [Q-E09](#q-e09), [Q-P16](#q-p16). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-07b-commit-boundaries.md`; `artifacts/local/tasks/HF-07b/`.

**Definition of done:**

1. For each transition (level completion, reward/offer resolution, revival use, terminal settlement), a numbered stage list of stage, validate, commit and acknowledge that names the observable state before and after. Re-verify when S0-08 lands.
2. Enumerate the candidate revival/interruption policies, at minimum resume at the last completed level, resume mid-level from a checkpoint, and forfeit the level. Show the nonduplication invariants hold under each. Label the candidates pending Q-P16.
3. Keep unresolved revival/interruption product choices explicit. The Persistence half of Q-E09 (write-timing protocol) may be submitted as a proposed answer.
4. Four tabletop cases (duplicate completion, revival with an older spatial checkpoint, terminal defeat, stable offered-choice restore) appear in the output as step tables.

**Verification and evidence:**

- Review that only a validated committed generation can be acknowledged as durable.
- Check each tabletop case against the stage lists under every candidate policy.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-08"></a>

### HF-08: Specify save failure and conservative recovery

**Card revision:** 2 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) (hold on a failed write) and [§ Consequences](adr/TADR-004-persistence.md#consequences) (ordering and single writer)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (target OS families)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (seam with PD-02 interface states)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) and `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- Godot 4.7 `FileAccess` and `OS` documentation, resolved by the coordinator and supplied in the packet.
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-07b](#hf-07b). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-08-save-recovery.md`; `artifacts/local/tasks/HF-08/`.

**Definition of done:**

1. Define the single-writer protocol and write/flush/commit ordering. For each TADR-001 target OS family, one row with the qualification question, the engine API surface by documentation reference and the evidence method. Never claim rename alone proves durability. Every stage is marked "unqualified on paper; re-verify when S0-08 lands, and again when the TH-22 proof lands".
2. A state table of failure class by transition stage giving the held state, message class, and permitted and forbidden actions, including user-visible retry and recovery states.
3. Preserve corrupt or ambiguous files and refuse rollback to a living/unspent generation when lifecycle continuity cannot be established. An ambiguity-conditions checklist names each condition.
4. An interruption matrix at every HF-07b commit stage for rewards, revival and terminal facts, stored in the output as enumerable test-case rows.

**Verification and evidence:**

- Review corrupt newest generation, unknown version, full disk and retry cases for false success or silent data loss.
- Check every matrix row names a stage, an outcome and a held state.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-09"></a>

### HF-09: Specify schema and gameplay-content migration

**Card revision:** 2 · **Owner:** Persistence · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Consequences](adr/TADR-003-content-pipeline.md#consequences)
- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) and [§ Consequences](adr/TADR-004-persistence.md#consequences) (browser storage preservation)
- [Q-E05](#q-e05)
- `src/campaign.js:115` and `src/progress-store.js:45`, the two browser storage records this card preserves
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (content compatibility and missing IDs)
- `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) and `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-06b](#hf-06b), [HF-07b](#hf-07b). **Blocking questions:** None. **Registered non-blocking questions:** [Q-E05](#q-e05). The contract must hold under every candidate answer; the card may submit a proposed protocol for the engineering half of a question as `proposed` in TRACKING, never as an answer.

**Files touched:** `docs/tech/sections/HF-09-schema-migration.md`; `artifacts/local/tasks/HF-09/`.

**Definition of done:**

1. (1a) A compatibility predicate over schema version, content revision and catalogue version with an accept, migrate or reject table.
2. (1b) Chaining as ordered single-step migrations, each validated before the next; the original stays untouched until the migrated generation commits through the HF-07b protocol. Re-verify when S0-08 lands.
3. Specify missing ID, incompatible content and newer-format handling without rerolling, losing discoveries or adding active effects. One tabletop case per negative appears in the output.
4. Name the browser records preserved by file and key (`src/campaign.js:115`, `src/progress-store.js:45`). State that HF-09 reads none of them. Q-E05 gates any import, and the contract holds under every candidate answer.

**Verification and evidence:**

- Walk one compatible migration, a rejected future version, a missing recipe and a repeated load through the proposed rules.
- Review that no migration implicitly imports or overwrites the named browser storage.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="hf-10"></a>

### HF-10: Review the complete foundation contract

**Card revision:** 2 · **Owner:** Independent review · **Size:** M · **Lane:** foundation

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md](adr/TADR-001-engine-language-platforms.md)
- [adr/TADR-002-runtime-model.md](adr/TADR-002-runtime-model.md)
- [adr/TADR-003-content-pipeline.md](adr/TADR-003-content-pipeline.md)
- [adr/TADR-004-persistence.md](adr/TADR-004-persistence.md)
- [adr/TADR-005-networking-scope.md](adr/TADR-005-networking-scope.md)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01) (must be admitted before assignment)
- `docs/tech/sections/HF-02-constraints-evidence.md` from [HF-02](#hf-02) (must be admitted before assignment)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) and `docs/tech/sections/HF-03b-dependency-graph.md` from [HF-03b](#hf-03b) (must be admitted before assignment)
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) and `docs/tech/sections/HF-04b-runtime-patterns.md` from [HF-04b](#hf-04b) (must be admitted before assignment)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) and `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) and `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- `docs/tech/sections/HF-08-save-recovery.md` from [HF-08](#hf-08) (must be admitted before assignment)
- `docs/tech/sections/HF-09-schema-migration.md` from [HF-09](#hf-09) (must be admitted before assignment)
- The pinned card revision of each output above and its retained receipts under `artifacts/foundation-sprint-2026-09/tasks/ID/`
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-01](#hf-01), [HF-02](#hf-02), [HF-03a](#hf-03a), [HF-03b](#hf-03b), [HF-04a](#hf-04a), [HF-04b](#hf-04b), [HF-05](#hf-05), [HF-06a](#hf-06a), [HF-06b](#hf-06b), [HF-07a](#hf-07a), [HF-07b](#hf-07b), [HF-08](#hf-08), [HF-09](#hf-09). **Blocking questions:** None.

**Files touched:** `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md`; `artifacts/foundation-sprint-2026-09/tasks/HF-10/` (retained receipts); `artifacts/local/tasks/HF-10/`. The report is review evidence recorded by the coordinator, not a TECH_BIBLE section.

**Definition of done:**

1. Produce an independent report with required fixes, notes, evidence level and the exact reviewed draft identity (commit or content hash) of every output.
2. One matrix with one row per foundation output (the audit's nine-by-five form, extended to the thirteen outputs after the splits) and five check columns: module boundaries, tick ownership, content/persistence coverage, transition order and unresolved parameter gates. Each cell is PASS, FAIL or NOTES, with a path and line per FAIL.
3. Reproduce every paper scenario (walkthroughs, traces, tabletop cases and the interruption matrix) from the retained receipts. No cell asserts native behavior.
4. The reviewer reports only. The coordinator records the report, and a second fresh reviewer checks its coverage before it is recorded, per ORCHESTRATOR § Handoff and review.

**Verification and evidence:**

- Read all thirteen foundation outputs together and reproduce their paper scenarios from the retained receipts.
- Check author/reviewer independence and distinguish source review from future native qualification.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="s0-01"></a>

### S0-01: Pin the Godot 4.7.2 toolchain and prove a typed offline headless boot

**Card revision:** 1 · **Owner:** Verification (Conventions co-signs the root path) · **Size:** M · **Lane:** prepare

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) (pinned editor, typed GDScript)
- [adr/TADR-005-networking-scope.md § Decision](adr/TADR-005-networking-scope.md#decision) and [§ Later qualification and reconsideration](adr/TADR-005-networking-scope.md#later-qualification-and-reconsideration) (offline solo)
- [docs/adr/0001-two-playable-entries.md](docs/adr/0001-two-playable-entries.md) (the root stays disjoint from both browser entries)
- `docs/tech/sections/HF-01-production-conventions.md` from [HF-01](#hf-01), or the interim root path the coordinator records in TRACKING as a question answer
- [TRACKING.md](TRACKING.md) event EV-0024, the install record (editor at `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`, version `4.7.2.stable.official.ed1daf0bf`, official 4.7.2-stable release, SHA512 verified against the release sums)
- Godot 4.7 command-line reference, resolved by the coordinator and supplied in the packet; the card cites the resolved page, not memory.

**Dependencies:** [HF-01](#hf-01) or the interim path answer. **Blocking questions:** None. **Blocking item:** engine installed on this machine under EV-0024; export templates parked.

**Files touched:** `native/project.godot`; `native/tests/smoke_boot.gd`; `native/tests/fixtures/untyped_negative.gd`; `docs/tech/native-toolchain.md`; `scripts/native-smoke.mjs`; `.gitignore` (add `native/.godot/`); optional `package.json` `check:native` entry; `artifacts/local/tasks/S0-01/`. The `native/` root and `docs/tech/native-toolchain.md` are provisional pending HF-01, and the toolchain document says so.

**Definition of done:**

1. `docs/tech/native-toolchain.md` records the installed editor: version string, official release archive name, SHA512 digest as verified under EV-0024, install path and machine identity. It records export templates as not installed and parked with S0-09, and states that its own path is provisional pending HF-01.
2. `native/project.godot` carries the project name, no renderer override, and the static-typing warnings-as-errors keys cited from the resolved 4.7 documentation.
3. `native/tests/smoke_boot.gd` is typed, extends SceneTree, prints a marker and the engine version, and calls `quit()`.
4. `native/tests/fixtures/untyped_negative.gd` fails to load under the item 2 settings.
5. `scripts/native-smoke.mjs` runs outside `verify`, resolves the binary through an environment variable or the recorded path, runs the positive, negative and static networking-grep checks, and writes `artifacts/local/native-smoke/report.json` with commands, exit codes, stdout, host identity and a sha256 manifest of `native/`.
6. The `verify` stage list is unchanged and `npm run check:project` passes.
7. `index.html`, `orchard.html`, `src/`, `server/` and `tests/` are unchanged.

**Verification and evidence:**

- Positive run exits 0 and prints the identity line; negative run exits nonzero; positive rerun with the network unavailable by a recorded method.
- `node scripts/native-smoke.mjs`; `npm run check:project`.
- The receipt records the Godot version string, host, offline method and the observed `quit()` exit code.

**Boundary:** No game code, scene, Resource, save, input or rendering. Linux host only; nothing about Windows, controllers or feel. No export, CI or publication. Proves engine launch, typed parsing and exit only.

<a id="s0-02"></a>

### S0-02: Add the documentation-only check command

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** prepare

**Source and inputs:**

- [ORCHESTRATOR.md § Serial integration and completion](ORCHESTRATOR.md#serial-integration-and-completion) (manifest and documentation-only checks)
- [CONTRIBUTING.md § Verification](CONTRIBUTING.md#verification)
- [TRACKING.md](TRACKING.md) (event sequence and index-row rules)
- [§ Task contract](#task-contract) above (card field set and required output headings)
- `scripts/check-project.mjs` (reuse its link regex and fence stripping)
- [artifacts/publication-2026-09-06/document-checks.json](artifacts/publication-2026-09-06/document-checks.json) (the unpreserved PUB-01 anchor check)

**Dependencies:** None. **Blocking questions:** None. **Blocking item:** coordinator ruling on whether a tooling card may run the build-containing `verify`.

**Files touched:** `scripts/check-docs.mjs`; `package.json` (scripts block only); `tests/check-docs.test.js`; `CONTRIBUTING.md` (one table row); `artifacts/local/tasks/S0-02/`.

**Definition of done:**

1. `npm run check:docs` checks local file links and heading and `<a id>` anchors in root `*.md`, `adr/**`, `docs/**` and `artifacts/**/README.md`, stripping fences and skipping remote URLs.
2. It validates every BACKLOG card field set, the preceding anchor matching the card ID, resolving dependency and question links, and rejects an assignable L.
3. It checks TRACKING `EV-NNNN` numbers are strictly increasing with no gaps and no blank line inside the append-only events table, and that every index row links an existing BACKLOG anchor and names an existing event.
4. When `docs/tech/sections/` exists, each section carries the seven required headings from § Task contract.
5. It writes `artifacts/local/check-docs/report.json` with a sha256 manifest of every checked Markdown file and a limits line.
6. The `verify.mjs` stage list is unchanged and the existing tooling test holds.

**Verification and evidence:**

- `npm run check:docs` passes on the integrated tree; fixtures with a broken anchor, a card missing Boundary and a duplicated EV each fail naming the path.
- `npm run check:project` and `npm test` pass; `verify` only if the coordinator authorizes the build.

**Boundary:** Tooling only. Structural evidence, not contract correctness. Implemented under PS-01; the coordinator records its live state.

<a id="s0-03"></a>

### S0-03: Add the verification-scope selector and reserve the native check command

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** prepare

**Source and inputs:**

- [ORCHESTRATOR.md § Serial integration and completion](ORCHESTRATOR.md#serial-integration-and-completion)
- [.agents/skills/scrapkeep-verify/SKILL.md](.agents/skills/scrapkeep-verify/SKILL.md) and [AGENTS.md](AGENTS.md)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)
- `scripts/check-docs.mjs` from [S0-02](#s0-02)

**Dependencies:** [S0-02](#s0-02). **Blocking questions:** None. **Blocking item:** None.

**Files touched:** `scripts/check-scope.mjs`; `package.json` (scripts block only); `tests/check-scope.test.js`; `CONTRIBUTING.md` (scope-to-command map); `artifacts/local/tasks/S0-03/`.

**Definition of done:**

1. `npm run check:scope -- <base> <candidate>` classifies changed paths into documentation-only, browser-proof, tooling, native (`*.gd`, `*.tscn`, `*.tres`, `project.godot`, `export_presets.cfg`) or mixed, and prints the exact required commands with evidence-class labels. It exits nonzero when a documentation-only scope mixes with build-requiring paths under a no-build instruction.
2. The map appears in CONTRIBUTING § Verification and the scrapkeep-verify skill table cites it.
3. `check:godot` is documented as a reserved name, unavailable until the engineering handoff, with no body; `verify.mjs` is unmodified.
4. Hosted CI is recorded as parked with its unpark conditions; no workflow file is added.

**Verification and evidence:**

- Unit fixtures per class plus the mixed refusal.
- `npm run check:docs` and `npm test` pass.

**Boundary:** Tooling and contribution docs only. No Godot command, no CI, no admission authority outside the coordinator. Implemented under PS-01; the coordinator records its live state.

<a id="s0-04"></a>

### S0-04: Prove runtime ownership under TADR-002 and TADR-005

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** prepare

**Source and inputs:**

- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision), [§ Consequences](adr/TADR-002-runtime-model.md#consequences) and [§ Later qualification and reconsideration](adr/TADR-002-runtime-model.md#later-qualification-and-reconsideration)
- [adr/TADR-005-networking-scope.md § Decision](adr/TADR-005-networking-scope.md#decision) and [§ Later qualification and reconsideration](adr/TADR-005-networking-scope.md#later-qualification-and-reconsideration) (pause and menu focus)
- [docs/adr/0005-caster-input-and-dashboard.md](docs/adr/0005-caster-input-and-dashboard.md)
- `src/orchard/simulation.js:140`, `:347-374`, `:417-421` and `tests/orchard.test.js:12-15`, `:327-337`, the browser precedent to differ from and not port
- S0-01 evidence and toolchain record
- Godot 4.7 documentation for `_physics_process`, `Node.process_mode`, `SceneTree.paused`, `SceneTree.physics_frame`, `Engine.physics_ticks_per_second`, `Engine.is_in_physics_frame`, application focus notifications and `SceneTree.quit(exit_code)`, resolved by the coordinator and supplied in the packet.

**Dependencies:** [S0-01](#s0-01), plus the path decision (HF-01 admission or the interim path answer). **Blocking questions:** None. **Blocking item:** engine install (satisfied on this machine under EV-0024; the coordinator confirms at admission).

**Files touched:** `native/proofs/tadr-002/project.godot`; `native/proofs/tadr-002/proof_runner.gd`; `native/proofs/tadr-002/session_owner.gd`; `native/proofs/tadr-002/encounter_coordinator.gd`; `native/proofs/tadr-002/encounter_state.gd`; `native/proofs/tadr-002/input_adapter.gd`; `native/proofs/tadr-002/menu_probe.gd`; `native/proofs/tadr-002/intruder.gd`; `docs/tech/proofs/S0-04-runtime-ownership.md`; `artifacts/local/tasks/S0-04/`. Paths under `native/` and `docs/tech/` are provisional pending HF-01.

**Definition of done:**

1. Cite the resolved 4.7 documentation for every API above and save the receipt.
2. Implement phases A through E exactly (single physics-callback owner, second source rejected, positive control cast, pause freezes gameplay while an always-process node runs, focus loss clears held input and cancels prepared actions without manufacturing a cast), typed, with no accumulator, no `Input` singleton and no addon.
3. The run exits 0 on the pinned host with stdout and `result.json` under `artifacts/local/godot-proof/S0-04/`.
4. The proof document states the proven and not-proven lists verbatim and logs the tick rate as a placeholder, never a chosen value.
5. The handoff proposes the HF-04b revision 2 sketch-replacement text.

**Verification and evidence:**

- `godot --headless --path native/proofs/tadr-002 --script res://proof_runner.gd`; expect exit 0 and five PASS lines.
- Fault injection (the intruder mutates state directly) yields exit 1; the reviewer reads source and stdout and reruns.

**Boundary:** No rendering, physics bodies, scene replacement, save, export, CI, addon or browser changes. Not qualification evidence; proves ADR rules only.

<a id="s0-05"></a>

### S0-05: Prove typed Resource identity, admission and immutability headlessly

**Card revision:** 1 · **Owner:** Content · **Size:** S · **Lane:** prepare

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision)
- [BIBLE.md § Four slots and milestone progression](BIBLE.md#four-slots-and-milestone-progression) (tree shape only)
- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision)
- S0-01 evidence and toolchain record
- Godot 4.7 documentation for `Resource`, `class_name` and typed `@export`, resolved by the coordinator and supplied in the packet.

**Dependencies:** [S0-01](#s0-01). **Blocking questions:** None. **Blocking item:** engine install (satisfied on this machine under EV-0024; the coordinator confirms at admission).

**Files touched:** `native/proofs/tadr-003/project.godot`; `native/proofs/tadr-003/definitions/slot_tree_definition.gd`; `native/proofs/tadr-003/definitions/catalogue.gd`; `native/proofs/tadr-003/fixtures/placeholder_tree.tres`; `native/proofs/tadr-003/fixtures/renamed_copy/placeholder_tree_other_name.tres`; `native/proofs/tadr-003/tools/validate_catalogue.gd`; `artifacts/local/tasks/S0-05/`. Paths under `native/` are provisional pending HF-01.

**Definition of done:**

1. A typed `SlotTreeDefinition` Resource saved as text `.tres` with only `id`, `content_revision`, `nodes` and `edges` fields, so no product value can be smuggled in.
2. `register` refuses the same id from a different path or filename; `resolve` returns the first registration.
3. A `duplicate()` session record is mutated, the reload is unchanged and `resolve` returns the original.
4. The headless `--script` command exits 0 with a per-check summary.

**Verification and evidence:**

- Run on the pinned 4.7.2; capture stdout, exit code, `godot --version` and a sha256 manifest under `artifacts/local/tasks/S0-05/`.
- The reviewer confirms the renamed copy differs in path and filename, no field can hold a cost, effect or name, and every id carries the `proof.` prefix.

**Boundary:** Disposable. No production path, content, import, hot reload, `.tscn` or save format. Browser proofs untouched. Deletable once HF-05 and HF-06a cite it.

<a id="s0-06"></a>

### S0-06: Prove binary-tree admission rejection and failed-reload retention

**Card revision:** 1 · **Owner:** Content (Verification reviews) · **Size:** S · **Lane:** prepare

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (structural admission and failed-reload retention)
- [BIBLE.md § Four slots and milestone progression](BIBLE.md#four-slots-and-milestone-progression)
- S0-05 outputs

**Dependencies:** [S0-05](#s0-05). **Blocking questions:** None. **Blocking item:** engine install (satisfied on this machine under EV-0024; the coordinator confirms at admission).

**Files touched:** `native/proofs/tadr-003/definitions/tree_rules.gd`; `native/proofs/tadr-003/fixtures/malformed_tree.tres`; `native/proofs/tadr-003/fixtures/candidate_bad/`; `native/proofs/tadr-003/tools/validate_catalogue.gd` (extend); `artifacts/local/tasks/S0-06/`. Paths under `native/` are provisional pending HF-01.

**Definition of done:**

1. `tree_rules.validate` returns an empty list for the good fixture and at least one diagnostic naming the id and the failed check for the malformed fixture (reconvergence, unreachable leaf).
2. The validator with a malformed candidate exits nonzero with the diagnostic.
3. A failed staged catalogue leaves the prior active catalogue in place; `resolve` still succeeds.
4. A fixture without the `proof.` prefix is refused.

**Verification and evidence:**

- Two runs (exit 0 for the good fixture; nonzero for the candidate) logged with exit codes and `godot --version`.
- The reviewer confirms the defect is structural, so the rule rejected it and typing did not, per TADR-003 § Decision.

**Boundary:** Semantic rules (lineage per slot, start access, milestones, recipe endpoints, compatibility) are out of scope. No safe-encounter-boundary behavior is proven.

<a id="s0-07"></a>

### S0-07: Author the TADR-004 save-owner proof and fixtures

**Card revision:** 1 · **Owner:** Persistence · **Size:** S · **Lane:** prepare

**Source and inputs:**

- [adr/TADR-004-persistence.md § Decision](adr/TADR-004-persistence.md#decision) and [§ Consequences](adr/TADR-004-persistence.md#consequences)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) if admitted, else a placeholder envelope with no discovery field and no browser IDs
- `server/store.js:103-124` and `tests/progress-store.test.js:72-133` as prior art only, not reuse
- Godot 4.7 documentation for `FileAccess`, `DirAccess` and `JSON`, resolved by the coordinator and supplied in the packet.

**Dependencies:** [HF-01](#hf-01) or a placeholder path. **Blocking questions:** None. **Blocking item:** none for authoring; engine install to run.

**Files touched:** `native/proofs/tadr-004-save/project.godot`; `native/proofs/tadr-004-save/save_owner.gd`; `native/proofs/tadr-004-save/run_proof.gd`; `native/proofs/tadr-004-save/fixtures/`; `native/proofs/tadr-004-save/README.md`; `artifacts/local/tasks/S0-07/`. Paths under `native/` are provisional pending HF-01.

**Definition of done:**

1. A typed `SaveOwner` with the six methods `stage`, `validate`, `commit`, `acknowledge`, `recover` and `resolve_lifecycle`, in the order stage, validate, commit, acknowledge; `validate` re-reads the staged bytes, not the in-memory record.
2. Cases a through e (f optional) with stated inputs, outputs and exit codes: commit path, round trip, newer schema (c1, c2), interruption (d1, d2) and lifecycle authority (e).
3. Fixtures for c2, d1, d2 and e under three fixture directories.
4. The README states the command, the run-directory rule, the evidence layout and the TADR-004 § Consequences non-claim verbatim (temporary files, a rename, a checksum or a backup alone do not prove power-loss durability).
5. Every API absent from the resolved documentation receipt is marked unverified.

**Verification and evidence:**

- Source review against TADR-004 § Decision and § Consequences.
- Fixture JSON parses under Node (syntax only); no Godot execution is claimed by this card.

**Boundary:** No game code, no future `user://` layout, no browser storage reads, no discovery field, no migration implementation, no CI. Placeholders only.

<a id="s0-08"></a>

### S0-08: Execute the TADR-004 proof and record evidence

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** prepare

**Source and inputs:**

- S0-07 outputs (proof, fixtures, README)
- [CONTRIBUTING.md § Verification](CONTRIBUTING.md#verification) (evidence classes)
- S0-01 toolchain record

**Dependencies:** [S0-07](#s0-07), [S0-01](#s0-01). **Blocking questions:** None. **Blocking item:** engine install (satisfied on this machine under EV-0024; the coordinator confirms at admission).

**Files touched:** `artifacts/local/proofs/tadr-004/<run-id>/`; `artifacts/local/tasks/S0-08/`; suggested HF-08 matrix cross-references travel in the handoff, not in HF-08's file.

**Definition of done:**

1. One headless run exits 0 with every case PASS.
2. Engine version and OS are recorded.
3. `result.json` names the method "headless fixture run".
4. An explicit statement that flush/fsync durability and non-Linux rename semantics are not asserted.

**Verification and evidence:**

- Rerun twice for idempotence.
- The reviewer reads `result.json` against the S0-07 case table.

**Boundary:** Linux only. No CI, no templates. Certifies nothing and closes no HF card; HF-08's re-verify trigger consumes it.

<a id="s0-09"></a>

### S0-09: Export presets and CI smoke workflow

**Revised under operational Sprint 0.** [The implementation request](docs/project/sprint-0/AUTHORIZATION.md) authorizes templates, local exports and the private CI workflow. Previous parked history remains in TRACKING.

**Card revision:** 3 · **Owner:** Verification · **Size:** M · **Lane:** prepare

**Source and inputs:**

- [adr/TADR-001-engine-language-platforms.md § Decision](adr/TADR-001-engine-language-platforms.md#decision) and [§ Consequences](adr/TADR-001-engine-language-platforms.md#consequences)
- [adr/TADR-005-networking-scope.md § Consequences](adr/TADR-005-networking-scope.md#consequences)
- S0-01 outputs
- Godot 4.7 export command-line documentation and the template download record, resolved by the coordinator when unparked.

**Dependencies:** [S0-01](#s0-01); [S0-12](#s0-12). **Blocking questions:** None for internal CI generation and report retention. [Q-E06](#q-e06) stays open for external distribution.

**Files touched:** `native/export_presets.cfg`; `scripts/native-smoke.mjs` (`--export` mode); `.github/workflows/native-smoke.yml`; `docs/tech/native-toolchain.md` (the CI install mirrors the pin); `tests/native-smoke.test.js`; `artifacts/local/tasks/S0-09/`.

**Definition of done:**

1. Exactly two presets, Linux x64 and Windows x64, with their names referenced verbatim and no credentials.
2. `--export` runs both to absolute paths under `artifacts/local/native-export/linux/` and `artifacts/local/native-export/windows/`, asserting exit 0, presence, size and sha256.
3. The Linux export visibly launches locally, reports success and exits through its Exit action; CI launches it headlessly with a required success marker. Positive stage/resume execute in fresh processes and faults, timeouts, missing markers and failed exports fail the harness; the Windows export is file-existence only unless a Windows runner executes it.
4. The manually dispatched workflow uses `[self-hosted, linux, x64, scrapkeep-s0]` on a temporary local one-job runner. It downloads the editor and templates by URL, verifies the recorded digests, runs the smoke and exports and uploads `report.json`; no marketplace action is required; no hosted runner or Windows execution job is included. Retain the small report in the job log/summary, without uploaded artifact storage.
5. No export is committed or published.

**Verification and evidence:**

- The two export commands; `node scripts/native-smoke.mjs --export`.
- One green CI run on the pinned SHA, logged to `artifacts/local/tasks/S0-09/`.

**Boundary:** Export success is not qualification. Nothing is distributed or uploaded as a binary; CI generates binaries internally and retains reports only. Q-E06 remains open. Only included CI allowance may be used. Windows is unproven without execution. The renderer stays default (Q-E04 open). Smoke-script presence in exports is noted for Q-E13 and TH-26.

<a id="s0-10"></a>

### S0-10: Establish sprint closure and selection

**Card revision:** 1 · **Owner:** Coordinator · **Size:** S · **Lane:** operational-s0

**Source and inputs:**

- [Approved implementation scope](docs/project/sprint-0/AUTHORIZATION.md).
- [Sprint closure](ORCHESTRATOR.md#sprint-closure) and [accepted ADRs](adr/README.md).

**Dependencies:** None. **Blocking questions:** None within the synthetic proof scope.

**Files touched:** ORCHESTRATOR.md; TRACKING.md; BACKLOG.md; docs/project/prompts/sprint-close.md; docs/project/sprint-0/AUTHORIZATION.md; docs/project/sprint-0/amendment-request.md placeholder; docs/project/AI-WORKFLOW.md; .agents/skills/scrapkeep-task/SKILL.md; .agents/skills/scrapkeep-verify/SKILL.md

**Definition of done:**

1. Define closure outcomes, exact-commit evidence, retro/grooming, at most four S/M proposed cards and approval-only dispatch. Define amendment authority and propagation. Wire handback to the canonical close prompt.
2. Retain source identity, evidence limits and independent review.

**Verification and evidence:**

- npm run check:docs; npm run check:project; independent scenario review.

**Boundary:** Operational proof and workflow scope only. No game features, production qualification, paid services or release. Coordinator alone admits shared records.

<a id="s0-11"></a>

### S0-11: Supply specification amendment packets

**Card revision:** 1 · **Owner:** Coordinator · **Size:** S · **Lane:** operational-s0

**Source and inputs:**

- [Approved implementation scope](docs/project/sprint-0/AUTHORIZATION.md).
- [Sprint closure](ORCHESTRATOR.md#sprint-closure) and [accepted ADRs](adr/README.md).

**Dependencies:** [S0-10](#s0-10). **Blocking questions:** None within the synthetic proof scope.

**Files touched:** docs/project/sprint-0/amendment-request.md; docs/project/sprint-0/amendment-examples.md; artifacts/local/tasks/S0-11/

**Definition of done:**

1. Supply every contradiction field, decision and propagation evidence. Include examples for implementation defect, factual correction, architecture change and deferred contradiction. Return proposed shared-document changes to the coordinator.
2. Retain source identity, evidence limits and independent review.

**Verification and evidence:**

- npm run check:docs; independent contradiction scenario review.

**Boundary:** Operational proof and workflow scope only. No game features, production qualification, paid services or release. Coordinator alone admits shared records.

<a id="s0-12"></a>

### S0-12: Run one integrated native smoke scene

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** operational-s0

**Source and inputs:**

- [Approved implementation scope](docs/project/sprint-0/AUTHORIZATION.md).
- [Sprint closure](ORCHESTRATOR.md#sprint-closure) and [accepted ADRs](adr/README.md).

**Dependencies:** [S0-10](#s0-10); [S0-04](#s0-04); [S0-06](#s0-06); [S0-08](#s0-08). **Blocking questions:** None within the synthetic proof scope.

**Files touched:** native/integration/; native/project.godot; native/README.md; artifacts/local/tasks/S0-12/

**Definition of done:**

1. Compose existing session/tick, typed content and save components. Persist and resume synthetic state across fresh processes. Expose a minimal success/failure screen and Exit button. Support headless automation and injected failure. Do not mutate fixtures or user saves.
2. Retain source identity, evidence limits and independent review.

**Verification and evidence:**

- Pinned Godot headless runs with isolated data directory, positive and fault cases; source review; later exported launch in S0-09.

**Boundary:** Operational proof and workflow scope only. No game features, production qualification, paid services or release. Coordinator alone admits shared records.

<a id="s0-13"></a>

### S0-13: Reject invalid sprint closeout receipts

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** operational-s0

**Source and inputs:**

- [Approved implementation scope](docs/project/sprint-0/AUTHORIZATION.md).
- [Sprint closure](ORCHESTRATOR.md#sprint-closure) and [accepted ADRs](adr/README.md).

**Dependencies:** [S0-10](#s0-10); [S0-11](#s0-11). **Blocking questions:** None within the synthetic proof scope.

**Files touched:** scripts/sprint-close.mjs; tests/sprint-close.test.js; scripts/check-docs.mjs; tests/check-docs.test.js; tests/fixtures/check-docs/; docs/project/sprint-0/closure-receipt.md; artifacts/local/tasks/S0-13/

**Definition of done:**

1. Validate structured closure receipts with required evidence identity, outcomes, no active leases or incomplete tasks, amendment propagation and bounded next proposal. Missing/stale evidence stays pending; failed gates stay failed. Idempotent repeated receipt checking does not mutate canonical state. Add documentation checks for close prompt linkage and required contract sections.
2. Retain source identity, evidence limits and independent review.

**Verification and evidence:**

- node --test tests/sprint-close.test.js tests/check-docs.test.js; npm run check:docs; injected malformed/stale/failed receipts.

**Boundary:** Operational proof and workflow scope only. No game features, production qualification, paid services or release. Coordinator alone admits shared records.

<a id="s0-14"></a>

### S0-14: Review and close operational Sprint 0

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** operational-s0

**Source and inputs:**

- [Approved implementation scope](docs/project/sprint-0/AUTHORIZATION.md).
- [Sprint closure](ORCHESTRATOR.md#sprint-closure) and [accepted ADRs](adr/README.md).

**Dependencies:** [S0-09](#s0-09); [S0-10](#s0-10); [S0-11](#s0-11); [S0-12](#s0-12); [S0-13](#s0-13). **Blocking questions:** None within the synthetic proof scope.

**Files touched:** TRACKING.md; BACKLOG.md; CONTRIBUTING.md; docs/project/README.md; docs/project/sprint-0/README.md; docs/project/sprint-0/closure.json; artifacts/local/sprint-0/

**Definition of done:**

1. Independently review the integrated result and review coverage. Run required checks at a pinned clean commit. Retain local visible Linux launch and CI evidence. Run closeout once and repeat safely. Prepare at most four S/M HF cards awaiting_review. Do not call the sprint complete on missing evidence.
2. Retain source identity, evidence limits and independent review.

**Verification and evidence:**

- npm run check:scope -- <base> <candidate>; applicable checks; node scripts/sprint-close.mjs <receipt>; fresh review of the sprint-level review.

**Boundary:** Operational proof and workflow scope only. No game features, production qualification, paid services or release. Coordinator alone admits shared records.

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

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

**Card revision:** 2 · **Owner:** Runtime · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [BIBLE.md § Runs, regions, exits and saves](BIBLE.md#runs-regions-exits-and-saves)
- [adr/TADR-002-runtime-model.md § Decision](adr/TADR-002-runtime-model.md#decision)
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)

**Dependencies:** [HF-10](#hf-10), [FR-04](#fr-04) (revision 2: TH-01's run-start and terminal prose must be reconciled to the FR-02 contract before this card reads it). **Blocking questions:** None.

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)
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
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` from [TH-02](#th-02) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-04a](#hf-04a), [TH-02](#th-02), [TH-12](#th-12). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-18-input-integration.md`; `artifacts/local/tasks/TH-18/`.

**Definition of done:**

1. Map physical device actions to gameplay/UI intents and define device loss, focus/modal clearing and prepared cancellation.
2. Define full keyboard/mouse and controller gameplay/menu coverage and record unqualified hardware.

**Verification and evidence:**

- Tabletop disconnect during aim, controller modal navigation and focus return; identify future native physical tests per transition.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-19"></a>

### TH-19: Specify source-asset import and export admission

**Card revision:** 2 · **Owner:** Content · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision)
- [docs/project/ASSETS.md](docs/project/ASSETS.md)
- `.gitignore` native import-sidecar exclusion and `scripts/native-smoke.mjs` copy/hash exclusions, as observed during HF-01; re-inspect at assignment.
- Godot 4.7 import-process documentation: https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html (source-adjacent import settings versus generated cache).
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-05](#hf-05), [TH-16](#th-16). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-19-asset-import-export.md`; `artifacts/local/tasks/TH-19/`.

**Definition of done:**

1. Define source provenance, import settings, generated-output handling, scene/Resource references and export manifest validation.
2. Separate concept images from production asset admission and retain required notices from Q-E06.
3. Reconcile the proof-only `.import` ignore and harness exclusions with retention of authored import settings. Specify the exact scoped staging/runner repair and synthetic import proof required before admitting production source assets; the documentation card does not perform that repair or qualify imports. Record source-adjacent settings and generated `.godot/imported/` as different ownership classes.

**Verification and evidence:**

- Follow one source asset to exported reference and one missing reference through rejection; no production asset is generated here.
- Include a changed import-setting scenario: settings must survive a clean checkout and affect the admitted source identity; generated cache must remain rebuildable. Reject production asset readiness while the applicable staging/runner repair and import proof are absent.

**Boundary:** Documentation contract only. Record unresolved product parameters explicitly and gate dependent implementation. No engine behavior or executable test is established by this card.

<a id="th-20"></a>

### TH-20: Reconcile the authored schema catalogue

**Card revision:** 2 · **Owner:** Content · **Size:** M · **Lane:** technical handoff

**Source and inputs:**

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/schemas/SC-01.md` from [SC-01](#sc-01) (must be admitted before assignment)
- `docs/tech/schemas/SC-02.md` from [SC-02](#sc-02) (must be admitted before assignment)
- `docs/tech/schemas/SC-03.md` from [SC-03](#sc-03) (must be admitted before assignment)
- `docs/tech/schemas/SC-04.md` from [SC-04](#sc-04) (must be admitted before assignment)
- `docs/tech/schemas/SC-05.md` from [SC-05](#sc-05) (must be admitted before assignment)
- `docs/tech/schemas/SC-06.md` from [SC-06](#sc-06) (must be admitted before assignment)
- `docs/tech/schemas/SC-07.md` from [SC-07](#sc-07) (must be admitted before assignment)
- `docs/tech/schemas/SC-08.md` from [SC-08](#sc-08) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-06a](#hf-06a), [SC-01](#sc-01), [SC-02](#sc-02), [SC-03](#sc-03), [SC-04](#sc-04), [SC-05](#sc-05), [SC-06](#sc-06), [SC-07](#sc-07), [SC-08](#sc-08). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/TH-20-authored-schemas.md`; `artifacts/local/tasks/TH-20/`.

**Definition of done:**

1. Produce one index mapping every HF-06 authored row to its admitted SC-01–SC-08 definition and example.
2. Identify cross-family reference/type conflicts, including integrated read findings B4 (SC-03 rebuild inputs against TH-08 EQ-03 and EP-31) and B5 (companion part families across SC-03, SC-06's three F-07 families and SC-08 Seam 8) in `artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md` and SC-03 review R3 notes 2 and 4 in `artifacts/handoff-8-2026-09-16/tasks/SC-03/review-R3.md`, and return corrections to the owning card, keeping Q-P15-dependent presence clauses gated; do not rewrite all schemas in this card.
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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- `docs/tech/sections/TH-23-gameplay-native-tests.md` from [TH-23](#th-23) (must be admitted before assignment)
- [BIBLE.md § 6. Core Systems](BIBLE.md#6-core-systems) (Product invariants; cite the specific relevant system pages in the output.)

**Dependencies:** [HF-03a](#hf-03a), [TH-14](#th-14), [TH-23](#th-23). **Blocking questions:** None.

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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
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
- `docs/tech/sections/HF-03a-module-map.md` from [HF-03a](#hf-03a) (must be admitted before assignment)
- `docs/tech/sections/HF-03b-dependency-graph.md` from [HF-03b](#hf-03b) (must be admitted before assignment)
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` from [HF-04a](#hf-04a) (must be admitted before assignment)
- `docs/tech/sections/HF-04b-runtime-patterns.md` from [HF-04b](#hf-04b) (must be admitted before assignment)
- `docs/tech/sections/HF-05-content-admission.md` from [HF-05](#hf-05) (must be admitted before assignment)
- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/HF-06b-persistence-projection.md` from [HF-06b](#hf-06b) (must be admitted before assignment)
- `docs/tech/sections/HF-07a-save-envelope.md` from [HF-07a](#hf-07a) (must be admitted before assignment)
- `docs/tech/sections/HF-07b-commit-boundaries.md` from [HF-07b](#hf-07b) (must be admitted before assignment)
- `docs/tech/sections/HF-08-save-recovery.md` from [HF-08](#hf-08) (must be admitted before assignment)
- `docs/tech/sections/HF-09-schema-migration.md` from [HF-09](#hf-09) (must be admitted before assignment)
- `artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md` from [HF-10](#hf-10) (must be admitted before assignment)
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

**Dependencies:** [HF-01](#hf-01), [HF-02](#hf-02), [HF-03a](#hf-03a), [HF-03b](#hf-03b), [HF-04a](#hf-04a), [HF-04b](#hf-04b), [HF-05](#hf-05), [HF-06a](#hf-06a), [HF-06b](#hf-06b), [HF-07a](#hf-07a), [HF-07b](#hf-07b), [HF-08](#hf-08), [HF-09](#hf-09), [HF-10](#hf-10), [TH-01](#th-01), [TH-02](#th-02), [TH-03](#th-03), [TH-04](#th-04), [TH-05](#th-05), [TH-06](#th-06), [TH-07](#th-07), [TH-08](#th-08), [TH-09](#th-09), [TH-10](#th-10), [TH-11](#th-11), [TH-12](#th-12), [TH-13](#th-13), [TH-14](#th-14), [TH-15](#th-15), [TH-16](#th-16), [TH-17](#th-17), [TH-18](#th-18), [TH-19](#th-19), [TH-20](#th-20), [TH-21](#th-21), [TH-22](#th-22), [TH-23](#th-23), [TH-24](#th-24), [TH-25](#th-25), [TH-26](#th-26), [TH-27](#th-27), [TH-28](#th-28), [TH-29](#th-29), [SC-01](#sc-01), [SC-02](#sc-02), [SC-03](#sc-03), [SC-04](#sc-04), [SC-05](#sc-05), [SC-06](#sc-06), [SC-07](#sc-07), [SC-08](#sc-08). **Blocking questions:** None.

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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` from [TH-07](#th-07) (must be admitted before assignment)
- [BIBLE.md § 4. Characters](BIBLE.md#4-characters) (characters, class kits, four slots, binary trees and milestone nodes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-04](#th-04), [TH-07](#th-07). **Blocking questions:** None.

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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` from [TH-03](#th-03) (must be admitted before assignment)
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` from [TH-04](#th-04) (must be admitted before assignment)
- `docs/tech/sections/TH-13-chaos-outcomes.md` from [TH-13](#th-13) (must be admitted before assignment)
- [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows) (committed attacks, hit geometry, telegraphs, abilities, ultimates and chaos outcomes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-03](#th-03), [TH-04](#th-04), [TH-13](#th-13). **Blocking questions:** None.

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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-08-inventory-equipment-and-transformations.md` from [TH-08](#th-08) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- [BIBLE.md § 5. Weapons & Items](BIBLE.md#5-weapons--items) (items, equipment, modifiers, transformations, attunement and fixed recipes)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-08](#th-08), [TH-09](#th-09). **Blocking questions:** None.

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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` from [TH-06](#th-06) (must be admitted before assignment)
- [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies) (enemy archetypes, attack references, waves, bosses, encounter admission and objective records)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-06](#th-06). **Blocking questions:** None.

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

**Card revision:** 2 · **Owner:** Content · **Size:** M · **Lane:** schema contracts

**Source and inputs:**

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment)
- [BIBLE.md § 3. Maps & Areas](BIBLE.md#3-maps--areas) (regions, areas, level modules, routes, exits and generation constraints; events and secret rooms are F-04 objective definitions owned by SC-04 per TH-06 UN-05 and AM-H8-004)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-11](#th-11), [TH-14](#th-14). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-05.md`; `artifacts/local/tasks/SC-05/`.

**Definition of done:**

1. Cover only regions, areas, level modules, routes, exits and generation constraints; identify its HF-06 matrix rows and referenced foreign definitions, including the F-04 objective definitions through which levels reach events and secret rooms.
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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-10-devices-and-one-main-companion.md` from [TH-10](#th-10) (must be admitted before assignment)
- [BIBLE.md § Devices and one main companion](BIBLE.md#devices-and-one-main-companion) (devices, companion chassis, interchangeable components and command capabilities)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-10](#th-10). **Blocking questions:** None.

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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` from [TH-12](#th-12) (must be admitted before assignment)
- `docs/tech/sections/TH-16-rendering-integration.md` from [TH-16](#th-16) (must be admitted before assignment)
- `docs/tech/sections/TH-17-audio-integration.md` from [TH-17](#th-17) (must be admitted before assignment)
- [BIBLE.md § 8. Audio & Feel](BIBLE.md#8-audio--feel) (audio cues, visual references and interface settings)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-12](#th-12), [TH-16](#th-16), [TH-17](#th-17). **Blocking questions:** None.

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

- `docs/tech/sections/HF-06a-schema-inventory.md` from [HF-06a](#hf-06a) (must be admitted before assignment)
- `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` from [TH-09](#th-09) (must be admitted before assignment)
- `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` from [TH-11](#th-11) (must be admitted before assignment)
- [BIBLE.md § 9. Glossary](BIBLE.md#9-glossary) (dialogue, glossary entries, discoveries and permanent unlock definitions)
- [adr/TADR-003-content-pipeline.md § Decision](adr/TADR-003-content-pipeline.md#decision) (Native Resource/scene authoring)

**Dependencies:** [HF-06a](#hf-06a), [TH-09](#th-09), [TH-11](#th-11). **Blocking questions:** None.

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

**Evidence needed to close:** Explicit discovery scenarios name loss/retention behavior and integrate with the single save aggregate without duplicate awards. Recorded answer (16 September 2026, TRACKING EV-0250): discovery facts commit only at the next durable transition (A, C or D, and S where a run starts); no immediate discovery transition; a discovery made in a level interrupted before completion is lost, consistent with Q-P16's P1. Protocol half carried by FR-05.

<a id="q-e10"></a>

### Q-E10: Encounter attack admission policy

**Source:** [docs/project/DECISION-REGISTER.md § Tier B: gates a later increment](docs/project/DECISION-REGISTER.md#tier-b-gates-a-later-increment) (D15 and D21); [BIBLE.md § Encounters, waves and enemies](BIBLE.md#encounters-waves-and-enemies)

**Missing information:** For the first selected encounter, what readable overlapping-attack admission policy and pressure limits apply? Completion and objective rules belong to Q-P38. Scope recorded (17 September 2026, TRACKING EV-0303): the policy and its pressure limits govern every attack commitment, enemy or player, so a limit may refuse a player ability or ultimate activation; TH-04 AV-08 and TH-06 AM-06 read it that way.

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

<a id="q-e14"></a>

### Q-E14: Same-tick defeat and completion candidate ordering

**Source:** TH-06 review note 2 (17 September 2026): [docs/tech/sections/TH-06-encounters-waves-and-enemies.md](docs/tech/sections/TH-06-encounters-waves-and-enemies.md) EE-07 and ET-18; [docs/tech/sections/HF-07b-commit-boundaries.md](docs/tech/sections/HF-07b-commit-boundaries.md) Transitions A, C and D (Transition A carries `revival_spent` unchanged and Transition C changes nothing else, so the two facts cannot share one candidate).

**Missing information:** When a lethal hero outcome and an objective completion are published from the same tick, in what order does Session stage the resulting HF-07b candidates, and what does a crash between the two leave in the save? The product half is answered: defeat wins (Q-P38 partial answer, TRACKING EV-0296), so the lethal side's Transition C or D is settled before any completion candidate and the completion counts only if the hero is alive after the R2 revive.

**Decision owner:** Runtime with Persistence

**Affected work:** TH-06 EE-07 and ET-18; HF-07b's transition catalogue; TH-01 RL7 and RL8; the future Session implementation

**Evidence needed to close:** HF-07b names the candidate order and the recovery outcome for a crash between the two candidates, and a paper walk shows no checkpoint is earned on a tick the run ended.

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

**Evidence needed to close:** An explicit material rule and supply policy support opening-world slot access and all four endpoints by the final boss without elapsed-time gates. Partial answers recorded (16 September 2026, TRACKING EV-0255): a milestone upgrade earned mid-encounter grows the chassis and becomes usable at the next intermission only; recovered material is consumed as collected with milestone unlocks and the rebuilt chassis as the only durable trace, so no material balance field is added; attraction pulls through cover within range, so no obstruction test is needed. Milestone costs, supply rates and visible mass values remain open. Carried into TH-05 at its next attempt.

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

**Evidence needed to close:** A route policy specifies legal starting and subsequent worlds, repeat handling, level counts and whether world four boss is the finale. Four worlds and two destination offers remain fixed. Partial answers recorded (16 September 2026, TRACKING EV-0273): route policy is a fixed starting world (the yard settlement, Yard Commons), no repeats and any order after, with each transition's two offers drawn from the unvisited pool; the fourth world's boss is the finale, whichever world is fourth, so every run region other than the fixed starting world needs a finale-capable boss variant; levels per world stay a tunable parameter bounded only by the 60 to 75 minute run. Destination-eligibility details and level counts remain open. Carried into TH-11 at attempt 1.

<a id="q-p13"></a>

### Q-P13: Chaos elements and miscast limits

**Source:** [BIBLE_DECISIONS.md § System gaps carried from planning](BIBLE_DECISIONS.md#system-gaps-carried-from-planning)

**Missing information:** Which elements and effects can the chaos kit produce, which actions can miscast, and what frequency, severity and warning rules bound harmful or inconvenient failures?

**Decision owner:** Andrew

**Affected work:** Chaos outcomes, warnings, audio, safety of mobility and kit tuning

**Evidence needed to close:** The pool, eligibility, outcome limits and warning policy are explicit. Directed attacks normally work as intended and no instability meter is inferred. Partial answer recorded (17 September 2026, TRACKING EV-0322): a miscast never changes the previewed danger shape (origin, shape, frame, height band, targets); it changes the outcome and, for a window not declared before resolution, the recovery boundary. TH-03's 'means what it shows' and single-query rules stand; TH-13 XG-06 and XT-15 read it that way. Pool, eligibility, frequency, severity and warnings remain open.

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

**Evidence needed to close:** Health, placement and interrupted-level policy are recorded without replenishing spent revival or duplicating rewards. Completed-level resume remains the next entrance. Recorded answer (16 September 2026, TRACKING EV-0247): interruption policy P1, resume at the last completed level; mid-level progress is lost and the run resumes at `run.checkpoint.next_entrance`, `run.interruption` stays null in every committed document. Revival policy R2, revive in place with a named health value left to tuning. Confirmed (17 September 2026, TRACKING EV-0300): an equipment swap made at the intermission is lost with an interrupted level, since the intermission stages nothing and the swap commits with the next level completion (TH-08 EO-12, EX-12). Protocol half carried by FR-05; the tuning value stays a parameter row.

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

**Missing information:** What grants respec access, how often can it occur, which branches can change, and what refund and presentation rules apply? Scope recorded (17 September 2026, TRACKING EV-0314): a slot's tree is fixed for the character (BIBLE, four character-specific trees), so a respec changes node selections within the slot's tree and never the tree itself; TH-07 PR-05 and PX-20 read it that way.

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

**Evidence needed to close:** Andrew selects the initial technique and bounded content set against clearance, readable encounters and replay variety. Fixed historical pocket sequences are not inherited. Partial answer recorded (16 September 2026, TRACKING EV-0275): the five candidate worlds of the Bible's area catalogue are the launch run-region set; with a fixed start (Q-P12) every run visits four of the five and skips exactly one. Region ids and per-region content remain with the content cards.

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

**Evidence needed to close:** A bounded named roster and accepted attack/defense grammar are recorded. One implemented Pruner arm does not select the complete Grand Pruner or historical build order. Partial answer recorded (16 September 2026, TRACKING EV-0275): the five candidate worlds of the Bible's area catalogue are the launch run-region set; with a fixed start (Q-P12) every run visits four of the five and skips exactly one. Region ids and per-region content remain with the content cards.

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

**Evidence needed to close:** Provisional limits and observable threat-readability/comfort criteria are recorded for the selected kit and target setup. Further decision recorded (17 September 2026, TRACKING EV-0284): a presentation-owned aim point is unlockable only by a TADR-002 amendment; this question owns feel bounds only.

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

**Evidence needed to close:** Each selected type has an explicit objective/reward boundary and required route accessibility. Historical timers and counter-only entry requirements remain proposals. Partial answer recorded (17 September 2026, TRACKING EV-0296): when an objective completion and a lethal outcome on the hero are staged in the same tick, defeat wins; the lethal outcome applies first, the Q-P16 R2 revive resolves, and the completion counts only if the hero is alive after that, so no checkpoint is earned on a tick the run ended. Type selection, rewards and reconfiguration boundaries remain open.

<a id="q-p39"></a>

### Q-P39: Starting a new run while a run is alive

**Source:** Adversarial review of 15 September 2026 (finding F1, `docs/tech/sections/HF-07b-commit-boundaries.md` line 37 and line 117 against `HF-07a-save-envelope.md` line 99); [BIBLE.md § The complete loop](BIBLE.md#the-complete-loop) states no rule for abandoning a run.

**Missing information:** May the player start a new run while the current run is alive and not terminal, and if so, does abandoning count as a defeat, a forfeit without a defeat record, or something else?

**Decision owner:** Andrew

**Affected work:** The run-start transition [FR-02](#fr-02) admits only when no run exists or the committed run is terminal and records this question for the live-run case; the Session `start_run` command; run presentation on the dashboard.

**Evidence needed to close:** Andrew's answer names whether a live run may be replaced and what durable record, if any, the abandoned run leaves. FR-02's Transition S and HF-08's rejection row for a differing `run.run_id` are then revised in place without weakening the monotonic lifecycle facts. Recorded answer (16 September 2026, TRACKING EV-0247): yes; starting a new run while a run is alive abandons it as a defeat. The Session commits Transition D with `run.lifecycle.outcome` `lost` for the live run, then Transition S; one closing fact, no new field, profile knowledge kept. Protocol half carried by FR-05.

<a id="q-p41"></a>

### Q-P41: A required telegraph that cannot be drawn

**Source:** TH-03 handoff (TRACKING EV-0235, EV-0236) reading `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` FM-06 against [BIBLE.md § A committed attack means what it shows](BIBLE.md#a-committed-attack-means-what-it-shows) lines 491 and 525 and `HF-04a-runtime-lifecycle.md` lines 100 and 112.

**Missing information:** When a committed attack's required telegraph cannot be drawn mid-encounter (a presentation failure, not an optional cosmetic), does the encounter hold, continue with a diagnostic, or end the level? HF-04a lets Presentation omit only optional cosmetics and requires view readiness at initialization; no source states the mid-encounter case.

**Decision owner:** Andrew for whether play may continue without the telegraph; Runtime for the protocol.

**Affected work:** TH-03 FM-06 (commitment unchanged, failure diagnosed, hold decision open), TH-06 encounter scheduling, HF-04a's failure-mode table.

**Evidence needed to close:** Andrew's answer names the behaviour and its disclosure; FM-06 and HF-04a's table are then revised in place without weakening the readability requirement. Recorded answer (16 September 2026, TRACKING EV-0247): hold the encounter and show a diagnostic; the commitment is unchanged, play holds as for a failed critical write, and readability never silently degrades. Protocol half carried by FR-05.

<a id="q-p40"></a>

### Q-P40: How a successful run closes its durable record

**Source:** TH-01 handoff (TRACKING EV-0199) reading [BIBLE.md § The complete loop](BIBLE.md#the-complete-loop) line 582 against `docs/tech/sections/HF-07b-commit-boundaries.md` Transition D and the [FR-02](#fr-02) run-start rule.

**Missing information:** The Bible ends a successful run at the final encounter, but the only lifecycle-closing durable fact is `run.lifecycle.terminal`, set by the second death. Does a won run close the run record, and how is the outcome recorded?

**Decision owner:** Andrew for the product half; Persistence for the protocol half.

**Affected work:** [FR-02](#fr-02) (run-start admission and the outcome fact), HF-07b Transition D, [TH-11](#th-11).

**Evidence needed to close:** Andrew's answer names whether victory and defeat share one closing fact and where the outcome lives. Recorded answer (15 September 2026, TRACKING EV-0202): terminal means the run is over for both victory and defeat, and a separate durable outcome fact records won versus lost; FR-02 revision 2 carries the protocol half.

<a id="q-p42"></a>

### Q-P42: Enemy family motion treatment

**Source:** BACKLOG Q-P27's missing information names the selected mech only; TRACKING EV-0372 recorded the hybrid treatment for the mech and nothing for enemies; TH-03 EP-01 and AO-01; the asset production drafts (`artifacts/handoff-8-2026-09-16/drafts/asset-production-cards.md`, replacing drafting question DQ-04).

**Missing information:** The approach is recorded at TRACKING EV-0447 decision 3: hybrid, with procedural locomotion and turning in Godot and hand-keyed Blender wind-up and attack clips. Still missing: for each family member, which motions are procedural and which are keyed, recovery included, and which parts are stable.

**Decision owner:** Andrew

**Affected work:** The parameter rows of ART-23 and ART-29, and through them ART-24 and SND-04.

**Evidence needed to close:** A recorded selection per family member naming the treatment for each attack stage, with poses still presenting the declared geometry and never advancing a window.

<a id="q-p43"></a>

### Q-P43: Controller vibration and haptic feedback scope

**Source:** `docs/tech/sections/TH-18-input-integration.md` proposed protocol PQ-1 (line 391), admitted at TRACKING EV-0460.

**Missing information:** Whether the first production scope uses controller vibration, for which events, and with what player control over it.

**Decision owner:** Andrew

**Affected work:** TH-18 DP-26; PD-03's feel events; the settings view.

**Evidence needed to close:** A recorded scope or a recorded exclusion, with a comfort observation if included.

<a id="q-p44"></a>

### Q-P44: Arbitration between concurrently bound device classes

**Source:** `docs/tech/sections/TH-18-input-integration.md` proposed protocol PQ-2 (line 392), admitted at TRACKING EV-0460.

**Missing information:** When keyboard/mouse and controller both supply continuous movement or aim samples in one input context, which governs or how they combine.

**Decision owner:** Andrew

**Affected work:** TH-18 DP-13 and IC-06; InputAdapter frame assembly.

**Evidence needed to close:** A recorded rule with an observable acceptance check on physical devices.

<a id="q-p45"></a>

### Q-P45: Input kinds beyond the proposed minimum coverage

**Source:** `docs/tech/sections/TH-18-input-integration.md` proposed protocol PQ-3 (line 393); integrated read C2 (`artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md`).

**Missing information:** Which physical action kinds beyond TH-18 IK-01 to IK-12, if any, the first production scope must support for remapping or accessibility, including an alternative to relative pointer motion for keyboard/mouse aim.

**Decision owner:** Andrew

**Affected work:** TH-18's kind table, every affected coverage cell and DP-07; Q-P30's remapping and accessibility scope.

**Evidence needed to close:** A recorded kind list with its acceptance method.

<a id="q-p46"></a>

### Q-P46: Simultaneous controller connection count

**Source:** `docs/tech/sections/TH-18-input-integration.md` proposed protocol PQ-4 (line 394); integrated read C2 (Q-E03's text does not ask this).

**Missing information:** How many controllers the game must accept connected at once on each platform, and what happens beyond that count.

**Decision owner:** Andrew, with Verification evidence

**Affected work:** TH-18 DP-24, HQ-05 to HQ-07 and DL-07.

**Evidence needed to close:** A recorded count and the observed behaviour at the limit.

<a id="q-p47"></a>

### Q-P47: Device, focus and capture status presentation

**Source:** `docs/tech/sections/TH-18-input-integration.md` proposed protocol PQ-5 (line 395); integrated read C2.

**Missing information:** Whether an unbound device's loss is announced, and the wording and treatment of device, focus and capture status.

**Decision owner:** Andrew

**Affected work:** TH-18 DP-14, DL-07 and II-11; TH-12's status views.

**Evidence needed to close:** Recorded status states and wording with a readability check.

<a id="q-p48"></a>

### Q-P48: Mid-play pointer capture

**Source:** `docs/tech/sections/TH-18-input-integration.md` proposed protocol PQ-6 (line 396); integrated read C2.

**Missing information:** Whether pointer capture may be acquired during unpaused play without the resume route, and with what clearing.

**Decision owner:** Andrew

**Affected work:** TH-18 DP-15 and CA-05.

**Evidence needed to close:** A recorded rule and, if allowed, its O1 and O2 handling by revision.


## Source records

Source dispositions and the source inventory live in [docs/project/SOURCE-DISPOSITIONS.md](docs/project/SOURCE-DISPOSITIONS.md), moved there verbatim on 6 September 2026. The coordinator owns that file. It preserves every P/T/R/D/BD identifier, the unnumbered planning obligations, core-system headings, selected concept-art receipts and requested engineering sections, and its task and question links point back to the cards and questions in this file. A disposition row grants no task completion, native support claim or implementation authorization.

## Audit repair cards (10 September 2026)

Defined from the read-only audit at `artifacts/audit-2026-09-10/`. Andrew approved the Tier 1 + 2
wave on 10 September 2026; authorization and leases live in `TRACKING.md`. These cards change checking
and verification behaviour only; none of them changes game rules, product direction or dependencies.

<a id="ar-01"></a>

### AR-01: Validate live board state in the documentation check

**Card revision:** 3 · **Owner:** Tooling · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- `TRACKING.md` § Task record schema (`:30` state vocabulary) and § Task state index
- `scripts/check-docs.mjs` (existing `tracking` checks)
- [Audit finding L6-01 and card L6-A](artifacts/audit-2026-09-10/lane-6-code-tooling.md)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `scripts/check-docs.mjs`; `tests/check-docs.test.js`; `tests/fixtures/check-docs/**` (fixture directories; definition change, revision 3, 10 September 2026, to match lease AR-01-L1, which authorized the fixture set the revision-2 card did not list).

**Definition of done:**

1. `check:docs` fails when a task-index `State` cell is not one of the values defined at `TRACKING.md:30`.
2. `check:docs` fails when a row's `Last event` cannot be resolved, or predates a later **record-level** event that names the same record, so a delivered handoff cannot stay invisible behind a stale row. Program-level events - those whose kind cell names authorization, coordination or closure - legitimately name many records without changing any of them and are excluded. The exclusion is documented in the checker and carries a negative control proving it is load-bearing. When the board adopts a structured event-kind field, this exclusion must key off that field rather than free text (definition change, revision 2, 10 September 2026: the revision-1 wording said "any later event" and was unsatisfiable together with item 4, because EV-0077 and EV-0078 name all fourteen foundation cards).
3. Both rules carry passing and failing fixtures in `tests/check-docs.test.js`, including a fixture that reproduces the historical `IN_REVIEW` token.
4. The current board passes both rules without any board edit.

**Verification and evidence:** `npm test` and `npm run check:docs` (documentation-only scope; no build). The failing fixtures must be shown failing.

**Boundary:** Checker only. No board content change, no runtime behaviour, no new dependency.

<a id="ar-02"></a>

### AR-02: Track the Sprint 0 closure evidence chain and state the disposal contract

**Card revision:** 2 · **Owner:** Verification · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- `docs/project/sprint-0/closure.json` (12 pinned `path` + `sha256` entries)
- `artifacts/local/sprint-0/closed/` (the disposable location those pins currently resolve to)
- [Audit findings H-01, T5-1 and T5-6](artifacts/audit-2026-09-10/lane-5-hygiene.md)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `artifacts/sprint-0-closure-2026-09-06/` (new); `docs/project/sprint-0/closure.json` (path values only); `artifacts/README.md`; `docs/project/sprint-0/README.md`. (Definition change, revision 2, 10 September 2026: the contract must live in the tracked artifacts/README.md, not inside the disposable tree it warns about, per lease AR-02-L2 and the audit's no-tracked-file-under-an-ignored-path property.)

**Definition of done:**

1. The nine distinct files pinned by `closure.json` exist under a tracked directory, byte-identical to the pinned hashes.
2. The pinned `path` values resolve through tracked files, so the authority record no longer depends on a directory `AGENTS.md` calls disposable.
3. `artifacts/README.md` states the disposal contract and names every pin-critical path that must be copied before any cleanup.
4. `node scripts/sprint-close.mjs` still validates the receipt unchanged in behaviour.

**Verification and evidence:** a `path` + `sha256` walk over `closure.json` reporting `present+match=12`; `git ls-files artifacts/sprint-0-closure-2026-09-06`; `npm run check:docs` and `npm run check:project`. If the validator forbids the repointed paths, stop and submit an amendment request rather than weakening the check.

**Boundary:** Evidence relocation and documentation only. The closure gates are not re-run and no gate result is changed.

<a id="ar-03"></a>

### AR-03: Make the asserted expedition gate patrol the shipped path

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- `src/game.js` `PATH` (`:2-23`, 20 points)
- `tests/expedition-balance.mjs` (hard-coded 18-point route, a different shape)
- `scripts/verify.mjs` (asserted victory stage) and `tests/balance.mjs` (non-asserted probe)
- [Audit finding L6-05](artifacts/audit-2026-09-10/lane-6-code-tooling.md)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `tests/expedition-balance.mjs`; `tests/balance.mjs` if the probe duplicates the route.

**Definition of done:**

1. The asserted route is derived from the shipped `PATH` (imported or asserted equal), so the two cannot drift.
2. The probe and the asserted gate use the same geometry.
3. The balance assertions still pass, and a deliberate `PATH` change is shown to move the asserted route.

**Verification and evidence:** `node tests/expedition-balance.mjs` and `npm test`. `npm run verify` runs the build and belongs to admission, not to this attempt.

**Boundary:** Test integrity only. `PATH` itself is a gameplay value and must not change.

<a id="ar-04"></a>

### AR-04: Widen the native networking check to the whole tree

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- `scripts/native-smoke.mjs` (`:30`, `:147` scan 16 of 32 native files)
- `TRACKING.md:276` (the recorded, unimplemented follow-up)
- [Audit finding L6-07 and card L6-E](artifacts/audit-2026-09-10/lane-6-code-tooling.md)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `scripts/native-smoke.mjs`; `tests/native-smoke.test.js`.

**Definition of done:**

1. The networking scan covers every tracked file under `native/`, not a subset.
2. The forbidden list includes `MultiplayerPeer`, `WebRTC`, `SceneMultiplayer`, `DTLSServer` and `UPNP`.
3. A fixture with a planted forbidden symbol is shown failing; the real tree passes.

**Verification and evidence:** `npm test` (the `native-smoke` unit checks). `npm run native:smoke` needs the Godot toolchain and is recorded as a separate, hardware-dependent check when it is available.

**Boundary:** Checker scope only. No engine change and no claim that the native tree was executed.

<a id="ar-05"></a>

### AR-05: Move documentation-only concept art out of the served tree

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- [Audit finding H-09](artifacts/audit-2026-09-10/lane-5-hygiene.md) and [card L6-F](artifacts/audit-2026-09-10/lane-6-code-tooling.md)
- `docs/project/ASSETS.md` (retain the original file names)
- `public/art/` (8 PNGs, 22,149,367 bytes) and the tracked documents that reference them

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `public/art/*.png` (8 files, moved); the new tracked art directory under `docs/`; every tracked document that links them.

**Definition of done:**

1. The eight PNGs live under `docs/` beside the concept studies that cite them, keeping their exact file names and bytes.
2. Every tracked reference is updated, including `docs/CONCEPT-STUDY-0*.md`, `docs/ART-DIRECTION.md`, `docs/project/ASSETS.md`, `docs/project/SOURCE-DISPOSITIONS.md`, `TRACKING.md` and the audit records under `artifacts/audit-2026-09-10/`.
3. `public/art/` no longer exists, so a production build stops copying 21 MB of documentation art into `dist/art/`.
4. No live code reference exists or is introduced: `index.html`, `orchard.html`, `src/`, `server/`, `scripts/` and `tests/` load none of these files (verify, do not assume).

**Verification and evidence:** `npm run check:docs` and `npm run check:project` exit 0; a repository-wide search shows no remaining `public/art` reference except any deliberately recorded historical note; `git ls-files public/art` is empty and `git ls-files <new directory>` lists 8 files. The build-copy effect is verified at admission by the coordinator through `npm run verify`, which this attempt must not run.

**Boundary:** A path move and link update only. No image is deleted, re-encoded or renamed, and no page or build configuration changes.

<a id="ar-06"></a>

### AR-06: Close the three accepted review follow-ups

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- [Wave review AR-03/AR-04](artifacts/audit-2026-09-10/review-wave-ar03-ar04.md) — the accepted notes
- `tests/expedition-balance.mjs` (AR-03 comments), `scripts/native-smoke.mjs` (AR-04 comment), `artifacts/README.md` (the cited-but-unpinned list)
- `docs/project/sprint-0/closure.json` (which cites `artifacts/local/sprint-0/final/dispatch-validation.json`)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `tests/expedition-balance.mjs` (comments only); `scripts/native-smoke.mjs` (comment only); `artifacts/README.md`.

**Definition of done:**

1. The AR-03 comments describe the defect accurately: the replaced modulo wrap still visited every waypoint, so the claim that it stopped patrolling the geometry is removed or corrected, and the "probe's traversal" description matches what the probe actually does or is stated as approximate.
2. The AR-04 comment matches the list it describes. The forbidden list is **not** extended: either the comment stops claiming every replication class, or it names what is and is not covered. Adding `MultiplayerSpawner` or `MultiplayerSynchronizer` is out of scope for this card.
3. `artifacts/README.md` names `artifacts/local/sprint-0/final/dispatch-validation.json` among the cited-but-unpinned local paths and records that `docs/project/sprint-0/closure.json` cites it.
4. No executable behaviour changes in any of the three files.

**Verification and evidence:** `npm test` exit 0 with the same pass count as before the change, proving the edits are comment-only in the two scripts; `npm run check:docs` exit 0; quote the three changed passages in the handoff.

**Boundary:** Comment and document accuracy only. No behaviour change, no forbidden-list extension, no reformatting of unrelated lines.

<a id="ar-07"></a>

### AR-07: Let the documentation check read archived events

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- [Audit finding L3-25/L3-30 and card L3 Task 6](artifacts/audit-2026-09-10/lane-3-canonical.md)
- `scripts/check-docs.mjs` (the `tracking` event checks, including the AR-01 rules)
- `TRACKING.md` (112 events; 117 index rows whose `Last event` is at or before EV-0057)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `scripts/check-docs.mjs`; `tests/check-docs.test.js`; new fixtures under `tests/fixtures/check-docs/**`.

**Definition of done:**

1. The checker resolves event IDs from `TRACKING.md` **and** from tracked archive files that declare themselves as event archives, so an event may move to an archive without breaking a row that cites it.
2. Archive membership is not silently accepted: an ID that appears in no checked source still fails, and a duplicate ID across sources fails.
3. The three AR-01 rules keep working across the boundary — state vocabulary, unresolvable `Last event`, and a `Last event` that predates a later record-level event naming the same record, including when the later event is in an archive or the row points into one.
4. Fixtures cover: an event resolved from an archive, a missing ID, a duplicate ID, and a stale row whose later naming event lives in an archive.

**Verification and evidence:** `npm test` and `npm run check:docs` exit 0 on the current board; each new fixture is shown failing without its rule. State the file-name convention the checker recognises for an archive so the coordinator can perform the split against it.

**Boundary:** Checker capability only. This card does **not** move any event, does not edit `TRACKING.md`, and creates no archive; the coordinator performs the split afterwards.


<a id="ar-08"></a>

### AR-08: Reconcile stale coordination records with the admitted state

**Card revision:** 1 · **Owner:** Coordinator · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- [Repository audit of 12 September 2026](artifacts/audit-2026-09-12/README.md), its `checks.log` and `git-hygiene.sh`
- `TRACKING.md` task state index and events EV-0099 to EV-0125 (the admitted state the records must match)
- `docs/FIRST-BUILD-CONTRACT.md` line 3 (the historical-banner form to copy)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/project/README.md`; `BACKLOG.md` (edition line and the prose under "Proposed first sprint" only); `ORCHESTRATOR.md` (revision header and closing paragraph only); `adr/README.md` (one sentence); `docs/RUNTIME-BLUEPRINT.md`; `docs/PLANNING-PREP-SWARM.md`; `docs/project/HOUSEKEEPING.md`; `docs/project/ASSETS.md`.

**Definition of done:**

1. The dated status paragraph in `docs/project/README.md` states the admitted state at the card's base: five of fourteen foundation cards done with HF-03a, HF-04a and HF-05 named and linked, the AR-01 to AR-07 wave admitted, and the event archive in place. It links `TRACKING.md` for live counts instead of restating them.
2. The `BACKLOG.md` edition line carries the card's date, and the prose under "Proposed first sprint" says the fourteen-card set was authorized at EV-0078. The heading text stays unchanged so existing anchors hold.
3. The `ORCHESTRATOR.md` revision header no longer presents Operational Sprint 0 as the current authorization, and its closing paragraph no longer says foundation authorization is awaiting review; both defer to the TRACKING authorization row.
4. `adr/README.md` no longer says the per-system pages have not been produced; it links `docs/tech/sections/README.md`.
5. `docs/RUNTIME-BLUEPRINT.md` and `docs/PLANNING-PREP-SWARM.md` open with a historical banner in the form of `docs/FIRST-BUILD-CONTRACT.md` line 3, naming what superseded them (TADR-002 for the blueprint's ownership table; the HOUSEKEEPING remote record and the historical planning protocol for the swarm record's line 32 claims).
6. `docs/project/HOUSEKEEPING.md` line 40 and `docs/project/ASSETS.md` line 15 point their backlog and T04 references at the root `BACKLOG.md` or `docs/project/SOURCE-DISPOSITIONS.md` instead of the frozen `docs/project/BACKLOG.md`.
7. Every heading and anchor another file links to is unchanged. `npm run check:docs` and `npm run check:project` exit 0.

**Verification and evidence:** `npm run check:docs` and `npm run check:project` on the candidate; no build. The reviewer reads each changed paragraph against the TRACKING rows and events it cites and confirms no claim exceeds an admitted state.

**Boundary:** Documentation-only. This card does **not** edit `TRACKING.md` (the coordinator corrects board records through events), does not change any card definition, dependency, ADR status or question, deletes no artifact, and leaves the unreferenced artifact files and `artifacts/visual-iterations/*.js` snapshots named in the audit for a separate disposition.

## Foundation repair cards (13 September 2026)

Defined at the Foundation-full sprint closure from the HF-10 foundation review
(`artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md`). These cards correct admitted
foundation sections in place; none changes game rules, product direction, an ADR or a card dependency.

<a id="fr-01"></a>

### FR-01: Apply the HF-10 required fixes to the foundation sections

**Card revision:** 1 · **Owner:** Coordinator · **Size:** M · **Lane:** foundation-repair

**Source and inputs:**

- [HF-10 foundation review](artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md), required fixes RF-1 to RF-9 with their exact path and line, and its notes N-01 onward
- The admitted sections `docs/tech/sections/HF-04b-runtime-patterns.md`, `HF-06a-schema-inventory.md`, `HF-06b-persistence-projection.md`, `HF-07a-save-envelope.md` and `.csv`, `HF-07b-commit-boundaries.md`, `HF-08-save-recovery.md` at the closure commit
- `docs/tech/sections/HF-03a-module-map.md` lines 31, 32, 49 and `HF-03b-dependency-graph.md` line 185 (the names RF-1 and RF-6 must align to)
- The retained paper checks under `artifacts/foundation-sprint-2026-09/tasks/<id>/attempt-1/` for each section touched

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P16](#q-p16), [Q-E09](#q-e09). No fix may answer a question or assume a proposed protocol.

**Files touched:** `docs/tech/sections/HF-04b-runtime-patterns.md`; `docs/tech/sections/HF-06a-schema-inventory.md`; `docs/tech/sections/HF-06b-persistence-projection.md`; `docs/tech/sections/HF-07a-save-envelope.md`; `docs/tech/sections/HF-07a-save-envelope.csv`; `docs/tech/sections/HF-07b-commit-boundaries.md`; `docs/tech/sections/HF-08-save-recovery.md`; `artifacts/local/tasks/FR-01/`.

**Definition of done:**

1. RF-1: the HF-04b sketch uses an Encounter command HF-03a line 32 lists, or the call is removed; no other sketch line changes.
2. RF-2 and RF-3: the HF-06a line 58 question list and the HF-06b line 10 and line 81 claims state exactly what the matrices carry.
3. RF-4 and RF-5: HF-07a gives `run.checkpoint.build`, `run.checkpoint.equipment` and `run.checkpoint.companion` container rows in both the Markdown and the CSV, and links its own CSV in a "Machine-readable copy" block in the HF-06b form.
4. RF-6 and RF-7: HF-07b names Persistence as the stager at C1.1, and assigns C4's T9 commit to a named transition (folding presentation into Transition A or adding a stated exception), with the four-stage invariants re-argued for that path.
5. RF-8 and RF-9: HF-08 makes the candidate-path rule and FC-03 retry consistent with P1 and P2 (an attempt ordinal or a stated overwrite exemption), and R5 routes FC-13 with no candidate, FC-14 as a load failure and `incompatible_content` to named user-visible states.
6. Every retained paper check for a touched section still exits 0 from its retained copy with `--out` outside the retained directory, updated only where a fix changes a cited line, and the HF-10 matrix cells those fixes clear are listed with their new PASS justification in the handoff.
7. Card revisions of the touched sections are not changed; each section's Procedure performed records the revision-in-place with the RF identifiers and the closure event.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, and the seven retained paper checks rerun from their retained copies; the reviewer re-walks C4 and V3 by hand under the corrected rules. No build.

**Boundary:** Documentation-only. This card applies only the nine required fixes; every HF-10 note stays a note for a later revision, no question is answered, no envelope key is added or removed, and no card definition or dependency changes.

<a id="fr-02"></a>

### FR-02: Add the run-start transition and split initial-run facts from the checkpoint

**Card revision:** 2 · **Owner:** Persistence · **Size:** M · **Lane:** foundation-repair

**Source and inputs:**

- The adversarial review of 15 September 2026 (TRACKING EV-0187), findings F1 and F5: the common validator at `docs/tech/sections/HF-07b-commit-boundaries.md` line 37 and N5 at line 117 reject every fresh run after a terminal run, because `HF-07a-save-envelope.md` line 99 replaces `run.run_id` only by starting a new run; and `run.checkpoint` (line 100) is null until the first level completes while the character, generator state, next entrance and the Q-P16 reservation (line 148) live beneath it
- The [FR-01](#fr-01) result at its accepted integrated commit: `docs/tech/sections/HF-07a-save-envelope.md` and `.csv`, `HF-07b-commit-boundaries.md`, `HF-08-save-recovery.md`
- `HF-07b-commit-boundaries.md` lines 36 to 39 (the four-stage form), lines 125 to 138 (P1 to P4, pending Q-P16), line 52 (D1.4) and line 119 (N7); `HF-07a-save-envelope.md` lines 44 to 46 (RNG stream shape), lines 174 to 182 (rejected keys); `HF-08-save-recovery.md` line 140 (FC-18, the last failure class) and line 157 (`MC-INVALID` routing)
- `docs/tech/sections/HF-04a-*.md` line 131 (`start_run` and `restore_run` are Session commands)
- The [NP-01](#np-01) evidence page for the executed re-stage and lifecycle-regression gates, consumed once as the `native/proofs/tadr-004/**` re-verification trigger at HF-07a line 243, HF-07b line 269 and HF-08 line 373
- The retained paper checks `artifacts/foundation-sprint-2026-09/tasks/HF-07a/attempt-1/check_envelope.py`, `HF-07b/attempt-1/check_boundaries.py` and `HF-08/attempt-1/check_recovery.py` as FR-01 leaves them

**Dependencies:** [FR-01](#fr-01), [NP-01](#np-01). **Blocking questions:** None ([Q-P40](#q-p40) is resolved by Andrew's recorded answer at TRACKING EV-0202). **Registered non-blocking questions:** [Q-P16](#q-p16), [Q-E09](#q-e09), [Q-P39](#q-p39). No item may answer an open question; the shape must hold under P1, P2 and P3.

**Files touched:** `docs/tech/sections/HF-07a-save-envelope.md`; `docs/tech/sections/HF-07a-save-envelope.csv`; `docs/tech/sections/HF-07b-commit-boundaries.md`; `docs/tech/sections/HF-08-save-recovery.md`; `artifacts/foundation-sprint-2026-09/tasks/HF-07a/attempt-1/check_envelope.py`, `HF-07b/attempt-1/check_boundaries.py` and `HF-08/attempt-1/check_recovery.py` (expected-value pins only); `artifacts/local/tasks/FR-02/`.

**Definition of done:**

1. HF-07b gains Transition S, run start, in the four-stage form of lines 36 to 39. Its validate rule admits a candidate only when the committed `run` is null or the committed `run.lifecycle.terminal` is true; the candidate carries a new `run.run_id`, both lifecycle flags false, `run.checkpoint` null, `run.interruption` null and `run.start` populated. The live-run case cites Q-P39 and decides nothing.
2. The common validator at line 37 is scoped by run identity: the monotonic `revival_spent` and `terminal` checks and "run stays present" apply when the candidate and committed `run.run_id` match; a differing `run.run_id` is accepted only as a Transition S candidate; any other differing-`run_id` candidate is rejected as a new HF-08 R4 failure class numbered after FC-18 with message class `MC-INVALID`. N5 reads "unchanged in every transition except S".
3. One aggregate rule states that `generation` orders the save, not the run: Transition S commits at `G+1` with D1.4 unchanged, and the `profile.*` sets carry forward unchanged under N7.
4. HF-07a splits the envelope by one naming rule stated once: a fact that exists at Transition S before any level completes lives under `run.start.*`; a fact produced by completing a level stays under `run.checkpoint.*`; the Q-P16 reservation becomes `run.interruption` (`object or null`, group `reserved`, still carrying no keys). Concrete rows: `run.start` (object, when-present), `run.start.character_id` (moved from `run.checkpoint.build.character_id`), `run.start.entrance_id` (the resume position while `run.checkpoint` is null; `run.checkpoint.next_entrance` afterwards) and `run.start.rng_state[]` in the lines 44 to 46 shape. A new group `run-start` with anchor `run-start-fields`; Markdown and CSV in parity; the envelope keeps six top-level keys.
5. Scenarios: HF-07a S9 "new run after a terminal run" and S10 "first-level revival then interruption, checkpoint null" read under P1, P2 and P3; HF-07b C5 "run start after terminal defeat" as a step table of six or more rows carrying the "Under every candidate policy" sentence; HF-08 matrix rows IM-S1 to IM-S5 for the five stop points of Transition S and walkthrough V7 "stale old-run candidate after S committed".
6. The three retained checks are re-pinned, not weakened: `check_envelope.py` field count, group list, group counts, anchors, the interruption field name and the run-identity dot rule; `check_recovery.py` CSV field count and the transition enumeration extended with `S` so the matrix cross product includes IM-S1 to IM-S5; `check_boundaries.py` transition and case enumerations extended with `S` and C5 and its replay extended to C5. Each exits 0 from its retained copy with `--out` outside the retained directory.
7. Card revisions of the touched sections are not changed; each section's Procedure performed records the revision-in-place with the finding identifiers, the consumed NP-01 trigger, the Q-P40 answer and the closure event.
8. Q-P40 protocol half (revision 2): `run.lifecycle.terminal` means the run is over for victory and defeat alike, and a new lifecycle row `run.lifecycle.outcome` (an enumerated string, `won` or `lost`, present exactly when `terminal` is true and null otherwise, set once with `terminal` and never changed) is added to HF-07a in both copies with its source (BIBLE line 582; Andrew's answer at TRACKING EV-0202). HF-07b Transition D gains the victory path: completing the final encounter settles `terminal` true with `outcome` `won` through the same four stages, the common validator treats `outcome` as monotonic with `terminal` (present iff terminal, never rewritten), and N5 reads for both outcomes. HF-08's IM-D rows and V-series read under both outcomes, and Transition S's admission rule stays 'no run or terminal run', now covering a won run. HF-07a scenario S11 'final encounter won, then a new run' walks the pair.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, and the three retained paper checks rerun from their retained copies with `--out` under `artifacts/local/tasks/FR-02/`; the reviewer re-walks C5, V7 and S11 by hand and reads S10 under P2 and P3. No build.

**Boundary:** Documentation-only. No answer to Q-P16, Q-E09 or Q-P39; no rule for replacing a live run; no keys inside `run.interruption`; no results-screen, reward or presentation rule for a won run beyond the durable facts; no runtime or proof code; no card revision or dependency change outside this card.

<a id="fr-03"></a>

### FR-03: Revise HF-09 for the FR-01 and FR-02 field set

**Card revision:** 1 · **Owner:** Persistence · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- `docs/tech/sections/HF-09-schema-migration.md` as admitted (HF-09 revision at EV-0173), whose re-verification trigger on HF-07a and HF-07b changes fired when [FR-01](#fr-01) and [FR-02](#fr-02) were integrated (TRACKING EV-0201, EV-0212)
- The integrated `docs/tech/sections/HF-07a-save-envelope.md` and `.csv` (sixty-nine fields in seven groups; `run.start.*`, `run.interruption`, `run.lifecycle.outcome`; `run.checkpoint.build.character_id` and `run.checkpoint.interruption` removed), `HF-07b-commit-boundaries.md` (Transition S, run_id-scoped validator, Transition D victory path) and `HF-06b-persistence-projection.md` at the FR-02 integrated identity
- `artifacts/foundation-sprint-2026-09/tasks/HF-09/attempt-1/check_migration.py` and its failures on the integrated tree recorded at TRACKING EV-0212: `hf07a.csv.sixty_fields`, `fields.all_exist_in_hf07a_csv` (`run.checkpoint.interruption`), four `envelope.rejected_key` guards, and the S0-07 page citation at line 116 (now 122 after NP-01)
- `docs/tech/proofs/S0-07-save-owner.md` at the NP-01 integrated identity for the shifted citations

**Dependencies:** [FR-02](#fr-02). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P16](#q-p16), [Q-E09](#q-e09), [Q-P39](#q-p39). No item may answer a question.

**Files touched:** `docs/tech/sections/HF-09-schema-migration.md`; `artifacts/foundation-sprint-2026-09/tasks/HF-09/attempt-1/check_migration.py` (expected-value pins and citation lines only); `artifacts/local/tasks/FR-03/`.

**Definition of done:**

1. Every HF-09 statement about the HF-07a field set (count, groups, named paths, the rejected-key guards) reads the integrated HF-07a: sixty-nine fields, `run.interruption` in place of `run.checkpoint.interruption`, `run.start.*` and `run.lifecycle.outcome` classified for migration by value with their source rows, and the M-series steps still write no field outside the admitted contract.
2. Every HF-07a, HF-07b, HF-06b and S0-07 line citation and stated dependency hash in HF-09 resolves to the integrated bytes; the migration walkthroughs that cross Transition D read under both outcomes and name Transition S where a migrated save starts a run.
3. `check_migration.py` re-pinned, not weakened, and exiting 0 from its retained copy with `--out` outside the retained directory; no assertion removed.
4. HF-09's card revision is unchanged; its Procedure performed records the revision-in-place, the FR-01 and FR-02 triggers consumed and the closure event.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, and `check_migration.py` from its retained copy; the reviewer re-walks one migration walkthrough across Transition D under the `won` outcome. No build.

**Boundary:** Documentation-only. No new schema version, migration step or compatibility predicate; no question answered; no other section or script changed.

<a id="fr-04"></a>

### FR-04: Reconcile TH-01, TH-02 and TH-03 after the FR-02 persistence contract

**Card revision:** 1 · **Owner:** Runtime · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- The Handoff-2 integrated read (TRACKING EV-0243) finding F1: `docs/tech/sections/TH-01-complete-loop.md` states the FR-02 hashes for HF-07a and HF-07b (lines 13 and 14) while lines 47, 55, 171, 233 to 235, 251, 292 and 306 still describe run start as undefined, Transition D as death-only, the durable projection as `run.checkpoint.*` and `run.lifecycle.*` only, and no committed resume point before the first level; its own re-verification trigger at line 310 named FR-02 integration and was not applied
- The integrated `docs/tech/sections/HF-07a-save-envelope.md` (`run.start` at line 102, `run.start.entrance_id` at 114, `run.lifecycle.outcome` at 176) and `HF-07b-commit-boundaries.md` (Transition D's victory path at 105, Transition S at 112 to 121, admission at 116), `HF-09-schema-migration.md` lines 146, 193, 297 and 298
- Findings F2 to F4 of the same read: `TH-02-movement-camera-and-active-aim.md` line 17 and `TH-03-a-committed-attack-means-what-it-shows.md` line 18 claim TH-01 cites Q-P40 (it does not); Session's held-state read of the D02 world diagnostic is classed F-LIFECYCLE at TH-01 line 80, F-CONTROL at TH-02 line 91 and F-PROCESS at TH-03 line 105 against `HF-04a-runtime-lifecycle.md` line 166; TH-02 MP-14 (line 228) routes jumpable-height thresholds to Q-E10 while TH-03 TP-15 and TP-19 (lines 242 and 246) route them to Q-P25, Q-P21 and Q-P22, with the read's recommendation (enemy height bands under Q-P25; player jump and air envelopes under Q-P21 with Q-P22 for growth; Q-E10 admission and pressure only)
- Findings F9 and F10: TH-01 claims a complete interface set (line 24) but has no row for reading `ActionRequest` on D05 and omits `AimPreview` from IF-17 and IF-27; TH-02 line 30 places every MA state inside RL2 while MR.1 places MA-09 at RL4
- The retained paper checks `artifacts/repair-handoff-2026-09-15/tasks/TH-01/coordinator-candidate/check_loop.py`, `artifacts/handoff-2-2026-09-16/tasks/TH-02/coordinator-candidate/check_movement.py` and `artifacts/handoff-2-2026-09-16/tasks/TH-03/coordinator-candidate/check_attack.py`

**Dependencies:** [TH-03](#th-03). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P16](#q-p16), [Q-P39](#q-p39), [Q-P41](#q-p41), [Q-P32](#q-p32). No item may answer a question.

**Files touched:** `docs/tech/sections/TH-01-complete-loop.md`; `docs/tech/sections/TH-02-movement-camera-and-active-aim.md`; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md`; `artifacts/local/tasks/FR-04/`.

**Definition of done:**

1. TH-01's run-start, terminal and durable-projection prose reads the integrated HF-07a and HF-07b: RL1 enters through Transition S, RL8 and RL9 close through Transition D under both outcomes with `run.lifecycle.outcome`, the durable projection names `run.start.*` and `run.interruption`, EC-06 and the first-level interruption case name `run.start.entrance_id` as the committed resume position, the seam paragraph states run start as settled by FR-02 and Q-P40, and FR-02 is no longer described as concurrent; RS.3 and the RL1 durable row updated; the fired trigger at line 310 recorded as consumed.
2. TH-02 line 17 and TH-03 line 18 no longer claim TH-01 cites Q-P40; the D02 diagnostic read carries one callback class across TH-01, TH-02 and TH-03 matching HF-04a line 166; TH-02 MP-14 re-pointed to Q-P21 and Q-P22 with Q-E10 left to admission and pressure, no question answered.
3. TH-01 gains the `ActionRequest` D05 read row and `AimPreview` in IF-17 and IF-27 where HF-03b permits; TH-02 line 30 and MR.1 agree on where MA-09 sits.
4. The three paper checks exit 0 from their retained copies; `npm run check:drift` exit 0; card revisions unchanged; each Procedure performed records the revision-in-place with the finding identifiers and the closure event.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, and the three paper checks; the reviewer re-walks TH-01's RT.1 to RT.15 under the `won` outcome and RS.1 to RS.3 through Transition S. No build.

**Boundary:** Documentation-only. No answer to Q-P16, Q-P32, Q-P39 or Q-P41; no new state, rule or field; no HF section changed; the reduced-motion preference (integrated-read F5) stays a note pending Q-P32 and an HF-07a amendment.

<a id="fr-05"></a>

### FR-05: Propagate the Q-P16, Q-P39 and Q-P41 answers into the persistence and runtime contracts

**Card revision:** 3 · **Owner:** Persistence · **Size:** M · **Lane:** foundation-repair

**Source and inputs:**

- Andrew's recorded answers at TRACKING EV-0247: [Q-P39](#q-p39) (abandoning a live run is a defeat: Transition D with `outcome` `lost`, then Transition S), [Q-P16](#q-p16) (interruption P1, resume at the last completed level; revival R2, revive in place with a named health value left to tuning), [Q-P41](#q-p41) (a required telegraph that cannot be drawn holds the encounter with a diagnostic)
- `docs/tech/sections/HF-07b-commit-boundaries.md`: the candidate policy table (P1 to P4, R1 to R3, around lines 139 to 149), Transition S admission (line 116), the invariants under every candidate policy, C5; `HF-07a-save-envelope.md`: `run.interruption` (line 104) and the Q-P16 rows; `HF-08-save-recovery.md`: FC-19 (line 142), V7, the policy readings P1 and P2 in the retry rules
- `docs/tech/sections/TH-01-complete-loop.md` EC-05 and EC-06 and the seam paragraph, `TH-03-a-committed-attack-means-what-it-shows.md` FM-06 (line 217), `HF-04a-runtime-lifecycle.md` failure-mode table (lines 100 and 112), each at the [FR-04](#fr-04) integrated identity
- The retained checks for HF-07a, HF-07b, HF-08, TH-01 and TH-03
- Andrew's decision at TRACKING EV-0248 (revision 2): reduced motion is a fifth saved preference, `preferences.reduced_motion`, distinct from `impact_shake`; the numeric bounds of [Q-P32](#q-p32) stay open until a playable native slice exists. `docs/tech/sections/HF-07a-save-envelope.md` preferences rows (lines 184 to 188) and its record rule (line 204), `HF-06b-persistence-projection.md` preferences group, `TH-02-movement-camera-and-active-aim.md` ME-11 and MP-22, `BIBLE.md` line 602

**Dependencies:** [FR-04](#fr-04). **Blocking questions:** None (Q-P16, Q-P39 and Q-P41 are resolved at EV-0247; the reduced-motion setting is decided at EV-0248; Q-E09 is resolved at EV-0250). **Registered non-blocking questions:** [Q-P32](#q-p32). No item may answer a question that remains open.

**Files touched:** `docs/tech/sections/HF-07a-save-envelope.md`; `docs/tech/sections/HF-07a-save-envelope.csv`; `docs/tech/sections/HF-07b-commit-boundaries.md`; `docs/tech/sections/HF-08-save-recovery.md`; `docs/tech/sections/HF-04a-runtime-lifecycle.md`; `docs/tech/sections/HF-06b-persistence-projection.md`; `docs/tech/sections/HF-06b-persistence-projection.csv`; `docs/tech/sections/TH-01-complete-loop.md`; `docs/tech/sections/TH-02-movement-camera-and-active-aim.md`; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md`; the retained check scripts for HF-06b, HF-07a, HF-07b, HF-08 (expected-value pins and enumerations only); `artifacts/local/tasks/FR-05/`.

**Definition of done:**

1. HF-07b adopts P1 and R2: the candidate policy table becomes the adopted policy with the rejected candidates retained as history, `run.interruption` is stated null in every committed document, Transition C's revival reads in place with the health value as a sourced or gated parameter, and every "under every candidate policy" clause reads under the adopted one.
2. HF-07b Transition S admits a live-run replacement by requiring a preceding Transition D with `outcome` `lost` in the same session before S, stated as two transactions and two generations; HF-08 FC-19 and V7 read under that rule; HF-07a's `run.lifecycle.outcome` row names abandonment as a `lost` outcome; C5 gains the abandonment steps.
3. HF-04a's failure-mode table and TH-03 FM-06 state the hold-with-diagnostic behaviour for a required telegraph that cannot be drawn, citing Q-P41, without changing the readability requirement.
4. TH-01 EC-05 and EC-06 read under P1 and R2 and cite the resolved questions; the retained checks for HF-06b, HF-07a, HF-07b, HF-08, TH-01, TH-02 and TH-03 exit 0 re-pinned not weakened; `npm run check:drift` exit 0; card revisions unchanged; each Procedure performed records the revision-in-place and the answers consumed.
5. Revision 2: HF-07a's preferences record carries a fifth setting `preferences.reduced_motion` (type, presence, owner, source BIBLE line 602 and EV-0248, meaning: a comfort setting distinct from `impact_shake`, its bound a parameter under Q-P32) in both copies with the record rule and field counts updated; HF-06b projects it in the preferences group in both copies; HF-08's preference-write rule reads five settings; TH-02 ME-11 and MP-22 name the field and keep the bound gated on Q-P32. The placeholder proof envelope under `native/proofs/tadr-004/` is not changed by this card; its paper gap is recorded as a re-verification trigger for a later proof card.
6. Revision 3, Q-E09 (TRACKING EV-0250): HF-07b's discovery-timing clauses adopt 'commit only at the next durable transition' (A, C, D and S), with the engineering-half protocols recorded at EV-0144, EV-0151, EV-0157 and EV-0163 retained as history; HF-07a's `profile.*` rows and HF-08's readings under Q-E09 read under the adopted rule; no immediate discovery transition is added; the loss case for an interrupted level is stated once beside P1.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, and the five retained checks; the reviewer re-walks C5 with the abandonment steps and TH-01's RT route under R2. No build.

**Boundary:** Documentation-only. Q-P32's numeric bounds stay open and only the reduced-motion setting is added; the revival health value stays a parameter; no new schema version; no runtime or proof code.

<a id="fr-06"></a>

### FR-06: Scope HF-04a's control-drain randomness rule and close HF-07b's offer-only generator gap

**Card revision:** 1 · **Owner:** Runtime with Persistence · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 24: the non-advancing control drain "cannot ... consume randomness", read unqualified, while HF-07b line 76 runs the destination-offer generator in Session's accepted-results batch, TH-01 RL6 offers destinations in a non-ticking state and TH-11 lines 83 and 100 place the route draw in Session; TH-14 GG-02 reads the rule as scoped to gameplay randomness and TRACKING EV-0336 ruled for that reading with a clarification carried
- `docs/tech/sections/HF-07b-commit-boundaries.md` lines 76 and 79: Transition A's offer-only path moves no field but the `offered_choices[]` entry, so a route draw made after the completion has committed cannot carry `run.checkpoint.rng_state` and the route position would be reinstalled stale on restore (TH-14 GB.3 walks the same-batch path and records the gap; TRACKING EV-0336, EV-0337)
- `docs/tech/sections/TH-14-randomness-generation.md` from [TH-14](#th-14) (must be admitted before assignment); `docs/tech/sections/TH-13-chaos-outcomes.md` XD-06 as reworded at EV-0337

**Dependencies:** [TH-14](#th-14). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04a-runtime-lifecycle.md`; `docs/tech/sections/HF-07b-commit-boundaries.md`; the retained HF-04a and HF-07b check scripts (pins only); the stated hashes and line citations of every section that cites HF-04a or HF-07b (re-pointed, no prose change unless a citation's meaning moved); `artifacts/local/tasks/FR-06/`.

**Definition of done:**

1. HF-04a line 24 scopes the control drain's prohibition to gameplay randomness (the encounter's `EncounterRandomState`), states that Session's run-level route and layout streams are consumed in the control drain at the positions TH-11 and TH-14 fix, and cites TH-14 GR-01, GR-02 and GG-02.
2. HF-07b states that a destination offer opened by a completed level rides that level's Transition A candidate with `run.checkpoint.rng_state`, and that the offer-only path is admissible only for an offer whose draw consumed no run-level stream position; a candidate on the offer-only path whose route position moved is rejected as a new HF-08 R4 row numbered after the last, message class `MC-INVALID`.
3. Every section citing HF-04a line 24 or HF-07b lines 76 and 79 is re-pointed by the drift fixpoint and read for meaning; TH-13 XD-06, TH-14 GB.3, GB.4 and Seam 5 reading 1 cite the corrected text; no rule in any citing section changes.
4. The HF-04a and HF-07b retained checks are re-pinned, not weakened; `npm run check:drift` exit 0 with zero mismatches.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, the retained HF-04b, HF-06a, HF-06b, HF-07a, HF-07b, HF-08, HF-09 checks and the TH-01, TH-13 and TH-14 paper checks rerun from copies with `--out` under `artifacts/local/tasks/FR-06/`; one integrated read over the citing sections. No build.

**Boundary:** Documentation contract only. No new transition, stage or field; no answer to Q-P23, Q-E03 or Q-E14; no runtime code.

<a id="fr-07"></a>

### FR-07: Type the slot definition and route kit actions through abilities in the content matrix

**Card revision:** 1 · **Owner:** Content with Persistence · **Size:** M · **Lane:** foundation-repair

**Source and inputs:**

- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-001/request.md` (accepted): `docs/tech/sections/HF-06a-schema-inventory.md` lines 22, 46, 97 and 193 type no slot definition while `docs/tech/sections/HF-07a-save-envelope.md` line 127 gives each slot its own domain ID; SC-01 review R1 B1
- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-002/request.md` (accepted): `docs/tech/sections/HF-06b-persistence-projection.md` line 114 names the level and encounter by ID against `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` line 45 and HF-07a line 70
- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-003/request.md` (accepted, Andrew's decision): kit weapon, main hero skill, mobility and ultimate actions reference N-021 ability definitions by ID and expected family `ability`; an ability references the F-02 attacks it produces; a mobility action may produce none; every produced attack stays under TH-03. HF-06a rows F-01, N-007 to N-011, N-013, N-016, N-019 and N-021; HF-06b N-009; `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` AS-01 to AS-04, EL-04, AI-25 and Seam 1
- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-004/request.md` (accepted, option 1): event and secret-room types are F-04 objective definitions owned by SC-04 per `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` UN-05 (line 119); HF-06a N-024 and HF-06b N-024 call a respec opportunity an SC-05 event definition, repeated at `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` Seam 5
- `docs/tech/sections/HF-06a-schema-inventory.csv`, `docs/tech/sections/HF-06b-persistence-projection.csv`, `docs/tech/sections/HF-07a-save-envelope.csv`

**Dependencies:** [HF-06a](#hf-06a), [HF-06b](#hf-06b), [HF-07a](#hf-07a), [TH-04](#th-04), [TH-06](#th-06), [TH-07](#th-07), [TH-11](#th-11). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-06a-schema-inventory.md` and `.csv`; `docs/tech/sections/HF-06b-persistence-projection.md` and `.csv`; `docs/tech/sections/HF-07a-save-envelope.md` and `.csv` (the `slot_id` source cell only, if its row changes); `docs/tech/sections/TH-07-four-slots-and-milestone-progression.md` (Seam 5's respec-opportunity sentence only); the retained HF-06a, HF-06b and HF-07a check scripts (pins only); the stated hashes and line citations of every technical, product and schema section that cites a changed file (re-pointed, no rule change); `artifacts/local/tasks/FR-07/`.

**Definition of done:**

1. HF-06a types the slot definition under its line 193 re-verification, either as a new noun row numbered after the last or by rewording N-024 so its rationale names both slot and slot-tree definitions, chosen by HF-06a's own row rules with the choice stated; HF-06b carries the matching projection or exclusion cell and HF-07a line 127's source cell names the row that types the slot; Markdown and CSV agree.
2. HF-06a rows F-01, N-007 to N-011 and N-019 state that kit actions reference N-021 ability definitions by ID and expected family `ability` and that an ability references the F-02 attacks it produces, a mobility action possibly none; N-013 distinguishes a slot action's visual reference from an attack's; N-016 distinguishes replacing a mobility action from replacing an attack; N-021 names the attacks it references; HF-06b N-009 states that planted-limb attacks stay F-02 within an ability; Markdown and CSV agree; no HF-07a field changes.
3. HF-06a N-024 and HF-06b N-024 (Markdown and CSV) and TH-07 Seam 5 state that a respec opportunity is an F-04 objective definition (SC-04) under Q-P18, not an SC-05 event definition, citing TH-06 UN-05. HF-06b line 114's clause names the accepted route decision and next entrance only and cites TH-11 line 45, with no level or encounter ID.
4. Every section citing a changed file is re-pointed by a drift fixpoint over the technical and product corpora and `docs/tech/schemas`, and each citing sentence is read for meaning; no citing section's rule changes; the retained HF-06a, HF-06b and HF-07a checks are re-pinned, not weakened; `npm run check:drift` and `node scripts/check-drift.mjs --sections docs/tech/schemas` exit 0 with zero mismatches.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, `node scripts/check-drift.mjs --sections docs/tech/schemas`, the retained HF-06a, HF-06b, HF-07a, HF-08 and HF-09 checks rerun from copies with `--out` under `artifacts/local/tasks/FR-07/`, and a paper check that compares every changed rationale cell between Markdown and CSV and asserts each row's named family references; independent review against the four accepted amendments. No build.

**Boundary:** Documentation contract only. No new save field, transition, stage or command; no answer to Q-P06, Q-P10, Q-P11, Q-P13 or Q-P18; no schema contract edited beyond stated hashes and line citations; no runtime code.

<a id="fr-08"></a>

### FR-08: Admit the UI-only input-moment click exception in HF-04a and TH-16

**Card revision:** 1 · **Owner:** Presentation with Runtime and Audio · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-006/request.md` (accepted): Andrew's product decision at TRACKING EV-0453 that menu and interface navigation and activation sounds play at the input moment while every gameplay cue still waits for its published value
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 46 (F-INPUT allowed work: Presentation records UI requests and nothing else)
- `docs/tech/sections/TH-16-rendering-integration.md` RV-5 (line 55), RI-12 (line 179), RI-14 (line 181) and Seam 4 (line 304)
- `docs/product/sections/PD-03-sound-feel-events.md` lines 48, 65, 102, 176 and the AM-H8-006 re-verification trigger (PD-03 attempt 3), which gate SE-14's input-moment playback on this card
- `docs/tech/sections/TH-12-hud-dashboard-and-settings.md` SO-02 (line 116): Session reads the UI request on D06 in F-PROCESS
- `docs/tech/sections/HF-06a-schema-inventory.md` N-051 (line 124): cues are consumed from committed results (PD-03 review R3 note R3-N2)

**Dependencies:** [HF-04a](#hf-04a), [HF-06a](#hf-06a), [TH-16](#th-16), [PD-03](#pd-03). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-04a-runtime-lifecycle.md` (the F-INPUT row and its Procedure performed entry only); `docs/tech/sections/TH-16-rendering-integration.md` (RV-5, RI-14, Seam 4 and the matching Scenarios, Re-verification triggers and Procedure performed entries only); `docs/tech/sections/HF-06a-schema-inventory.md` and `.csv` (N-051's rationale cell only, if it must name the exception); `docs/product/sections/PD-03-sound-feel-events.md` (the AM-H8-006 gate sentences restated as admitted, no other change); stated hashes and line citations of every citing technical, product and schema section (re-pointed, no rule change); retained HF-04a, TH-16 and PD-03 check copies (pins only); `artifacts/local/tasks/FR-08/`.

**Definition of done:**

1. HF-04a's F-INPUT row lets Presentation start a UI-only click for a recorded UI request, deciding nothing, reading no gameplay fact and never used by a gameplay cue; every other family's allowed work is unchanged.
2. TH-16 RI-14, RV-5 and Seam 4 name the same exception: the click's source is the recorded input context or `UiRequest`, it records no consumption of a published gameplay fact, and SE-14 is the only cue it covers; every gameplay cue still plays from a published fact.
3. HF-06a N-051 is checked against the exception and, if its rationale excludes a UI-request-keyed click, qualified in Markdown and CSV alike. PD-03's gate sentences state the exception as admitted; SE-14's committed-moment cell and SI-04 cite FR-08's revised rows; no other PD-03 rule changes.
4. A drift fixpoint over the technical and product corpora and `docs/tech/schemas` exits with zero mismatches; the retained checks are re-pinned, not weakened.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, `node scripts/check-drift.mjs --sections docs/tech/schemas`; the retained HF-04a, TH-16 and PD-03 checks rerun from copies with `--out` under `artifacts/local/tasks/FR-08/`; a paper check asserting that the three places name one exception limited to SE-14 and that no gameplay cue row changed, with negative controls; independent review against AM-H8-006. No build.

**Boundary:** Documentation contract only. No audio bus, voice, mixer or playback implementation (TH-17's); no other callback family changes; no answer to Q-P17, Q-P30 or Q-P31.

<a id="fr-09"></a>

### FR-09: Add production concept and audio path rows to HF-01

**Card revision:** 1 · **Owner:** Conventions with Technical art and Audio · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- `artifacts/handoff-8-2026-09-16/drafts/asset-production-rationale.md` drafting question DQ-01: HF-01 owns no path for production concept work or for the Audio cards' writes, with three proposed disjoint rows and the exclusion wording for the existing rows
- `docs/tech/sections/HF-01-production-conventions.md` Path ownership (rows are disjoint; an unlisted path needs an ownership amendment before a card claims it) and its `source-assets/**` and `native/content/*/assets/**` rows
- TRACKING EV-0447 decision 1 (Andrew: the batch asset list and its file locations are recorded before the budget)
- `docs/tech/sections/TH-19-asset-import-export.md` OC-07 and CI-01 to CI-04; `adr/` TADR-003 lines 27 and 35

**Dependencies:** [HF-01](#hf-01), [TH-19](#th-19). **Blocking questions:** None.

**Files touched:** `docs/tech/sections/HF-01-production-conventions.md` (the path ownership table, its Procedure performed entry and any citing sentence inside HF-01); stated hashes of every citing section (re-pointed, no rule change); retained HF-01 check copies (pins only); `artifacts/local/tasks/FR-09/`.

**Definition of done:**

1. HF-01 adds `docs/art/production/**` (Technical art: production concept sheets, image prompt records, paintovers, review captures, check records and motion briefs carrying PD-01 PF provenance; forbidding runtime inputs, editable 3D masters, generated engine cache and any claim that an image proves a physical property).
2. HF-01 adds `source-assets/*/audio/**` (Audio: editable audio masters, synthesis and transformation recipes, provenance, license evidence and notices) and `native/content/*/assets/audio/**` (Audio: reviewed audio runtime inputs with adjacent import settings and UID sidecars), each with forbidden content and a governing ADR line.
3. The existing `source-assets/**` and `native/content/*/assets/**` rows exclude the audio rows so every path keeps exactly one row; a paper check proves the table disjoint over a path sample that includes one path per new row.
4. Drift over the technical and product corpora and `docs/tech/schemas` exits with zero mismatches.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, `node scripts/check-drift.mjs --sections docs/tech/schemas`; the paper check above with negative controls (an overlapping row, a path claimed by no row); independent review against DQ-01. No build.

**Boundary:** Documentation contract only. Creates no directory, asset, image or sound; changes no other row's owner or permitted content.

<a id="fr-10"></a>

### FR-10: Name device connection delivery and InputAdapter focus-observation recording in HF-04a's callback families

**Card revision:** 1 · **Owner:** Runtime with Input · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-007/request.md` (proposed; decision owner Andrew)
- `docs/tech/sections/TH-18-input-integration.md` DL-08 (line 102), the Interfaces preamble (line 131), II-02 (line 136), the HF-04a seam (line 285), FT.3 and FT.11, which gate dependent implementation on this revision
- `docs/tech/sections/HF-04a-runtime-lifecycle.md` lines 46, 47 and 51 (F-INPUT, F-CONTROL and F-OTHER allowed work)
- `artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md` B2; TH-01 IF-33 and TH-12 UI-19

**Dependencies:** [HF-04a](#hf-04a), [TH-18](#th-18). **Blocking questions:** None. Gate: Andrew's recorded decision on AM-H8-007 before readiness.

**Files touched:** `docs/tech/sections/HF-04a-runtime-lifecycle.md` (the callback family table and its Procedure performed entry only); `docs/tech/sections/TH-18-input-integration.md` (the gate sentences at DL-08, the Interfaces preamble, II-02, the HF-04a seam, FT.3, FT.11 and the trigger, restated as admitted); stated hashes and line citations of citing sections (re-pointed); retained HF-04a and TH-18 check copies (pins only); `artifacts/local/tasks/FR-10/`.

**Definition of done:**

1. HF-04a names the engine delivery of a device connection change in one callback family with exactly InputAdapter's own-record updates as its allowed work, or records Andrew's rejection.
2. HF-04a's F-CONTROL row permits InputAdapter to record a focus observation in its own records alongside clearing, or records Andrew's rejection; no other owner's allowed work changes.
3. TH-18's gates are lifted or restated to match the decision; drift over the three corpora exits with zero mismatches; retained checks re-pinned, not weakened.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, `node scripts/check-drift.mjs --sections docs/tech/schemas`; retained HF-04a and TH-18 checks rerun from copies; independent review against AM-H8-007 and Andrew's decision. No build.

**Boundary:** Documentation contract only. No input implementation, device support claim or answer to Q-E03, Q-P30 or Q-P43 to Q-P48.

<a id="fr-11"></a>

### FR-11: Correct SC-02's allocation of HF-06a N-021 to AttackDefinition

**Card revision:** 1 · **Owner:** Content · **Size:** S · **Lane:** foundation-repair

**Source and inputs:**

- `artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md` B6: `docs/tech/schemas/SC-02.md` allocates N-021 to `AttackDefinition` and its save treatment, while `docs/tech/sections/HF-06a-schema-inventory.md` N-021 (line 94) and `docs/tech/sections/HF-06b-persistence-projection.md` N-021 (line 139) describe abilities that reference F-02 attacks
- `artifacts/handoff-8-2026-09-16/amendments/AM-H8-003/request.md` (Andrew's decision, EV-0411) as applied by FR-07
- SC-02's retained paper check `artifacts/handoff-8-2026-09-16/tasks/SC-02/coordinator-candidate-A2/check_sc02.py`, whose substring-based row allocation enforces the current attribution

**Dependencies:** [SC-02](#sc-02), [FR-07](#fr-07). **Blocking questions:** None.

**Files touched:** `docs/tech/schemas/SC-02.md` (row allocation, save treatment attribution and the citing sentences for N-021 only, plus Procedure performed); stated hashes and line citations of citing schema contracts (re-pointed); a re-pinned copy of the SC-02 check with the allocation assertion corrected under `artifacts/local/tasks/FR-11/`.

**Definition of done:**

1. SC-02 states N-021 as the ability definition row that references F-02 attacks, with `AttackDefinition` covering F-02 only; the save treatment names the rows HF-06b gives each type; no field, diagnostic or save value changes beyond the attribution.
2. The corrected check allocates rows by HF-06a rationale meaning, not substring, and fails on the former attribution (negative control).
3. Drift over the three corpora exits with zero mismatches; SC-01, SC-03 and SC-08 checks still exit 0.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, `node scripts/check-drift.mjs --sections docs/tech/schemas`; the corrected SC-02 check and the retained SC-01, SC-03 and SC-08 checks rerun from copies; independent review against B6 and HF-06a N-021. No build.

**Boundary:** Documentation contract only. No new schema type, no answer to Q-P06, Q-P13 or Q-P20.

## Tooling repair cards (16 September 2026)

Defined at the Repair-and-handoff-2026-09-15 sprint closure from its retro. Two admitted sections went stale
against their dependencies inside one sprint and nothing mechanical said so until a retained check was rerun by
hand. These cards add the missing lever; none changes a contract.

<a id="tl-01"></a>

### TL-01: Dependency-hash drift check for admitted sections

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** tooling

**Source and inputs:**

- The Sources convention every admitted section follows: a bullet per dependency naming the file and its `section bytes SHA256` at the section's base (for example `docs/tech/sections/TH-01-complete-loop.md` lines 8 to 16 and `HF-08-save-recovery.md` lines 9 to 15)
- `scripts/check-docs.mjs` (the structural documentation gate) and `package.json` scripts `check:docs`, `check:project`, `check:scope`
- TRACKING EV-0205 and EV-0212, where TH-01 and HF-09 were found stale against HF-07a and HF-07b only when their retained checks were rerun

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `scripts/check-drift.mjs` (new); `package.json` (one `check:drift` script entry, no dependency change); `CONTRIBUTING.md` (one sentence naming the command under the documentation checks); `artifacts/local/tasks/TL-01/`.

**Definition of done:**

1. `npm run check:drift` scans every `docs/tech/sections/*.md`, parses each Sources bullet that names a repository path and a `SHA256` value, recomputes the file's SHA-256 at the working tree, and prints one line per mismatch naming the citing section, the dependency path, the stated and actual hashes; exit 1 on any mismatch, exit 0 otherwise, with a one-line limits statement that it proves hash agreement only.
2. Run at the closure commit of Repair-and-handoff-2026-09-15 it reports exactly the HF-09 drift against HF-07a and HF-07b (and any other stale section it finds), and reports nothing for TH-01, HF-07a, HF-07b and HF-08.
3. A synthetic negative control (a copied section with one altered hash under `artifacts/local/tasks/TL-01/`) is detected; the control run is retained.
4. No dependency added; the script uses `node:crypto` and `node:fs` only.

**Verification and evidence:** `npm run check:drift` at the candidate with its output retained; `npm run check:docs`; `npm run check:project`; `npm run check:scope -- <base> <candidate> --no-build`. No build.

**Boundary:** Tooling only. It does not rewrite citations, re-pin hashes or judge whether a drift matters; that stays with a card and a reviewer.

<a id="tl-02"></a>

### TL-02: No-build tooling class and the drift check in the scope map

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** tooling

**Source and inputs:**

- `scripts/check-scope.mjs` and `tests/check-scope.test.js`, the scope classifier and its tests; `CONTRIBUTING.md` lines 35 to 37 (the check table) and the scope-to-command paragraph at line 53
- TRACKING EV-0223: TL-01's candidate was classed tooling, whose required command `npm run verify` builds, under an authorization that forbade builds, so the coordinator substituted `npm test` and recorded the gap
- TRACKING EV-0205, EV-0212 and EV-0216: TH-01 and HF-09 went stale against their dependencies with no mechanical signal until a check was rerun by hand; `scripts/check-drift.mjs` (TL-01, EV-0223) now detects it but is not in any required-command set

**Dependencies:** [TL-01](#tl-01). **Blocking questions:** None.

**Files touched:** `scripts/check-scope.mjs`; `tests/check-scope.test.js`; `CONTRIBUTING.md` (the check table row for `check:scope` and the scope-to-command paragraph); `artifacts/local/tasks/TL-02/`.

**Definition of done:**

1. `npm run check:scope -- <base> <candidate> --no-build` classifies a change confined to `scripts/*.mjs`, `tests/*.test.js`, `package.json` scripts entries and documentation as `tooling-no-build` and names `npm test`, `npm run check:docs`, `npm run check:project` and `npm run check:drift` as its required commands; a change touching `src/`, `server/`, `vite` configuration, dependencies or the lockfile still classes as build-requiring and `--no-build` still refuses it.
2. The documentation-only class's required commands gain `npm run check:drift`.
3. `tests/check-scope.test.js` covers the new class with one positive case, one boundary case that must still refuse `--no-build`, and the documentation-only command list including `check:drift`; `npm test` exit 0.
4. CONTRIBUTING's check table and scope-to-command paragraph state the new class and the added command; no dependency, lockfile or build change.

**Verification and evidence:** `npm test`, `npm run check:docs`, `npm run check:project`, `npm run check:drift`, and `npm run check:scope -- <base> <candidate> --no-build` on the candidate itself (which must class as `tooling-no-build`). No build.

**Boundary:** Tooling only. No change to what any check asserts; no new gate beyond adding an existing check to the required lists.

<a id="tl-03"></a>

### TL-03: Widen the drift check to the product sections

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** tooling

**Source and inputs:**

- `scripts/check-drift.mjs` (TL-01, EV-0223) scans `docs/tech/sections` only; PD-01 and PD-02 (EV-0341, EV-0343) state SHA256 dependency hashes in the same Sources-bullet form under `docs/product/sections`, proved today only by their retained paper checks
- `docs/product/sections/README.md`, the coordinator-owned index that records the gap
- `scripts/check-scope.mjs` and `tests/check-scope.test.js` (TL-02, EV-0289): the documentation-only and tooling-no-build classes and their required commands; `CONTRIBUTING.md` check table

**Dependencies:** [TL-02](#tl-02). **Blocking questions:** None.

**Files touched:** `scripts/check-drift.mjs`; `tests/check-drift.test.js` (new or extended); `docs/product/sections/README.md` (the gap sentence); `CONTRIBUTING.md` (the check table row for `check:drift`); `artifacts/local/tasks/TL-03/`.

**Definition of done:**

1. `npm run check:drift` scans `docs/tech/sections` and `docs/product/sections`, resolves each product section's stated dependencies from the citing file's own directory and from `docs/tech/sections`, and reports the same DRIFT line form for both.
2. A stated hash in a product section that mismatches, or a link it cannot bind, fails the check exactly as a technical section's does; a product section with no stated hashes is reported unbound, not passed.
3. Tests cover one product section that binds, one that mismatches and one unbound; `npm test` exit 0.
4. The product README's gap sentence and CONTRIBUTING's check table state the widened scan; `npm run check:scope` classes the candidate `tooling-no-build`; no dependency, lockfile or build change.

**Verification and evidence:** `npm test`, `npm run check:docs`, `npm run check:project`, `npm run check:drift` (exit 0 over both directories at the candidate), and `npm run check:scope -- <base> <candidate> --no-build`. No build.

**Boundary:** Tooling only. No change to what a technical section's check asserts; no change to any section's bytes beyond the README sentence.

<a id="tl-04"></a>

### TL-04: Include the schema contracts in the default drift check

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** tooling

**Source and inputs:**

- `scripts/check-drift.mjs` (TL-01, TL-03): `npm run check:drift` scans `docs/tech/sections` and `docs/product/sections`; the eight Handoff-8 schema contracts under `docs/tech/schemas` state hashes in the same form and are scanned only with `--sections docs/tech/schemas`
- TRACKING EV-0424: an integration commit gated on the default scan left a stale stated hash in `docs/tech/schemas/SC-03.md`, caught one commit later
- `docs/tech/schemas/README.md`; `CONTRIBUTING.md` check table; `tests/check-drift.test.js`

**Dependencies:** [TL-03](#tl-03). **Blocking questions:** None.

**Files touched:** `scripts/check-drift.mjs`; `tests/check-drift.test.js`; `docs/tech/schemas/README.md` (the check sentence); `CONTRIBUTING.md` (the `check:drift` row); `artifacts/local/tasks/TL-04/`.

**Definition of done:**

1. `npm run check:drift` scans `docs/tech/sections`, `docs/product/sections` and `docs/tech/schemas`, resolving schema dependencies from the citing file's directory and from `docs/tech/sections` and `docs/product/sections`, with the same DRIFT line form.
2. A schema contract's mismatched or unbindable stated hash fails the default run; `--sections` still narrows the scan.
3. Tests cover one schema contract that binds, one that mismatches and one unbound; `npm test` exit 0.
4. The schema README and CONTRIBUTING state the widened default; `npm run check:scope` classes the candidate `tooling-no-build`; no dependency, lockfile or build change.

**Verification and evidence:** `npm test`, `npm run check:docs`, `npm run check:project`, `npm run check:drift` (exit 0 over three directories at the candidate) and `npm run check:scope -- <base> <candidate> --no-build`. No build.

**Boundary:** Tooling only. No section or contract bytes change beyond the README sentence.

## Native proof repair cards (15 September 2026)

Defined from the adversarial review of 15 September 2026 (TRACKING EV-0187). The review read the
placeholder save owner under `native/proofs/tadr-004/` against the admitted HF-07b contract and found
two gates the contract requires and the proof does not enforce. These cards change proof code that
proves ADR rules only; none adds a game feature, an export, a qualification run or production code.

<a id="np-01"></a>

### NP-01: Repair the TADR-004 save-owner re-stage and lifecycle gates

**Card revision:** 1 · **Owner:** Persistence · **Size:** S · **Lane:** native-proof-repair

**Source and inputs:**

- The adversarial review of 15 September 2026 (TRACKING EV-0187), findings F2 and F3: `native/proofs/tadr-004/save_owner.gd` `stage()` (lines 46 to 63) overwrites the deterministic temp path without clearing `_validated_temp`, and `commit()` (lines 93 to 114) checks only path equality, so a validated-then-restaged candidate commits; `validate()` (lines 85 to 90) gates only `generation`, so a higher-generation candidate can clear `terminal` or `revival_spent`, and `resolve_lifecycle()` (lines 176 to 193) runs only from `recover()`
- `docs/tech/sections/HF-07b-commit-boundaries.md` line 37 (common validator), line 50 (D1.2: a candidate validated and then re-staged is not eligible), lines 116 and 117 (N4, N5); `adr/TADR-004-*.md` line 30
- `native/proofs/tadr-004/proof_runner.gd` lines 17 to 27 (`CASES`) and its fixture mapping; `native/proofs/tadr-004/fixtures/lifecycle/` (`save.json`, `older.json`, `terminal.json`), unchanged
- `docs/tech/proofs/S0-07-save-owner.md` (the API receipt and drift tripwires at lines 127 to 133) and `docs/tech/proofs/S0-08-save-evidence.md` lines 81 to 90 (the direct invocation form); the S0-07 card names `native/proofs/tadr-004-save/` as provisional paths and the admitted paths are `native/proofs/tadr-004/`
- `scripts/native-smoke.mjs` (`npm run native:smoke`): headless runs of every `native/proofs/*/proof_runner.gd` with the pinned Godot 4.7.2 binary, the fault-injection pass and the engine-pin check

**Dependencies:** None. **Blocking questions:** None. Requires the scoped native proof-repair authorization in the TRACKING program authorization row before dispatch.

**Files touched:** `native/proofs/tadr-004/save_owner.gd`; `native/proofs/tadr-004/proof_runner.gd`; `docs/tech/proofs/S0-07-save-owner.md` (in-place extension only; the substrings pinned at lines 39 to 41 and 45 stay on those lines); `docs/tech/proofs/NP-01-save-owner-repair.md` (new); `artifacts/local/tasks/NP-01/`.

**Definition of done:**

1. `stage()` clears `_validated_temp` and `converged` on entry; `validate()` records the SHA-256 of the staged bytes it read; `commit()` refuses with `ERR_UNCONFIGURED` when the path or the staged bytes differ from the candidate that last validated. A validated-then-restaged candidate cannot commit (D1.2).
2. `validate()` calls `resolve_lifecycle(candidate, committed)` after the generation gate and returns a distinct `Error` value, not `ERR_ALREADY_EXISTS`, when the resolved flags differ from the candidate's; a higher-generation candidate cannot clear `revival_spent` or `terminal` (N4, N5). The existing `--inject-fault` argument can additionally disable this gate so the harness proves it is noticed.
3. `CASES` gains `restage_after_validate`, `lifecycle_regression_spent` and `lifecycle_regression_terminal`, built in-runner from `placeholder_aggregate` over the existing `fixtures/lifecycle/` files without changing any fixture byte. Each asserts the rejection code, `ERR_UNCONFIGURED` on the following commit, `save.json` bytes unchanged, the temp preserved, and a FAIL line under fault injection.
4. `docs/tech/proofs/S0-07-save-owner.md` gains the three case rows and two drift tripwires for the new gates; `docs/tech/proofs/NP-01-save-owner-repair.md` records the fresh execution in the S0-08 form (commands, exit codes, per-case summaries, fixture hashes, limits). `S0-08-save-evidence.md` is unchanged as a dated execution record.
5. `npm run native:smoke` exits 0 with `proof-tadr-004`, `proof-tadr-004-inject-fault` (exit 1 with a FAIL line), `engine-pin` and `source-preservation` all PASS, and the direct runs in the S0-08 form are saved under `artifacts/local/tasks/NP-01/`.

**Verification and evidence:** `npm run native:smoke` on the candidate and again on the integrated commit; the direct headless invocations from `S0-08-save-evidence.md` lines 85 to 90 with their exit codes; `npm run check:docs`; `npm run check:scope -- <base> <candidate>`. The reviewer reads the diff against the five items and the coordinator's smoke receipts.

**Boundary:** Proof code only. No production Persistence module, no export, no other proof, no envelope or fixture change, no `run_id` in the proof envelope (that gate stays paper until FR-02 lands and a later proof card carries it), no engine or dependency change.

**Parked proposal, not a card.** The adversarial review also recommended that, once the persistence contracts settle and TH-01 to TH-03 are admitted, the first native scope be one bounded playable slice: satisfying starting movement, one upgrade that visibly changes a useful action, readable committed attack geometry, and save and reload across a defeat and a fresh run, qualified before the four-tree, equipment and companion combinations expand. Andrew parked it on 15 September 2026 as a proposal for the next sprint proposal. It has no card, no inputs, no files and no authority; it waits on the TH cards, on the completed engineering handoff and on Andrew's next-scope decision.


## Asset production cards (16 September 2026)

Imported at the Handoff-8 closure from the reviewed staging drafts `artifacts/handoff-8-2026-09-16/drafts/asset-production-cards.md` (sha256 `86bc527d001b4006eff563cace0e7b11eed6db9415d0021393effa47a9637bdf`) and `artifacts/handoff-8-2026-09-16/drafts/asset-production-rationale.md` (sha256 `518f0e6ffeaaad4e30552fd36908a90e74e5747d678f44272373824364d7a902`), admitted as staging records at TRACKING EV-0452. The drafts' reading notes still apply: a `concept stage` card runs only inside a sprint Andrew authorizes after Handoff-8 (TRACKING EV-0423 decision 1); a `native stage` card waits for the Q-E01 native slice and Andrew's production authorization; Blender, Krita and Audacity are not installed, and installing a tool is Andrew's step, never a card outcome; no card states a count, budget, polycount, bone count, texture size, loudness, duration, distance or frame rate. Drafting question identifiers `DQ-nn` resolve in the rationale's Drafting question dispositions table. DQ-01's path rows are card [FR-09](#fr-09); DQ-02's shader-source amendment and DQ-05's module collision card are not yet carded, so the cards that name them stay blocked on them. NQ-03, the fully grown route-clearance trial, is held back from this import until DQ-05's collision card exists (TRACKING EV-0435).

<a id="nq-01"></a>

### NQ-01: Author the synthetic import proof, repair the sidecar exclusions and execute the proof

**Card revision:** 1 · **Owner:** Tooling with Verification · **Size:** M · **Lane:** native qualification

**Source and inputs:**

- `docs/tech/sections/TH-19-asset-import-export.md` § The synthetic import proof, line 220; TH-19 IQ-01 to IQ-07, PV-06, OC-08, GO-03, GO-04, IS-01, IS-02, IS-04, HR-01 to HR-04, RR-01 to RR-11, IG-01 to IG-07 and AQ-05, AQ-06, AQ-15, AQ-16, AQ-19 and AQ-20; the quoted base lines at TH-19 lines 183 to 187
- TH-19 RR-09 at line 212 (fixtures in the failing run, only the passing candidate integrated) and TH-19 line 216 (running the runner needs its own authorization)
- `ORCHESTRATOR.md` lines 42 and 104: a prerequisite is done only when integrated, which is why fixtures and repair are one card
- `.gitignore` line 20 and `scripts/native-smoke.mjs` lines 147, 148, 688, 742, 751 and 753 as TH-19 quotes them; re-inspect at assignment, and a moved anchor returns the card to the coordinator
- `docs/tech/sections/HF-01-production-conventions.md` lines 34, 47, 50, 61, 66 and 68; `native/README.md` lines 42 and 86 and `native/tests/fixtures/untyped_negative.gd`, as TH-19 line 220 cites them
- The Godot import-process receipt TH-19 line 13 retained under `artifacts/local/tasks/TH-19/`, and Context7 library `/websites/godotengine_en_4_7` for TH-19 AQ-05 and AQ-06, at most three queries per question with saved receipts

- `artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md` B7: TH-19 IQ-03 (line 226) relies on unchanged source hashes while the reimport happens in a staged copy; the proof measures staged sidecar bytes before and after reimport, separately from source preservation

**Dependencies:** [TH-19](#th-19). **Blocking questions:** None. Gate: a native execution authorization for the pinned editor and the runner, recorded in TRACKING by Andrew before assignment (TH-19 line 216). **Registered non-blocking questions:** [Q-E03](#q-e03) for hosts beyond the runner's (TH-19 AQ-16), [Q-E13](#q-e13) for proof scripts in exports (TH-19 AQ-15).

**Files touched:** `native/proofs/tadr-003-import/**` (typed `proof_runner.gd` and its UID sidecar, the authored, variant and negative inputs, and the committed `.import` sidecars of the authored and variant inputs); `.gitignore`, deletion of line 20 only (TH-19 RR-01, under the coordinator's shared-file lease); `scripts/native-smoke.mjs`, TH-19 RR-02 to RR-06 only; `artifacts/local/tasks/NQ-01/` for the fixture receipt, the failing proof-mode receipt, the passing proof-mode receipt, the export-mode receipt and the clean-checkout receipt.

**Definition of done:**

1. The proof directory holds the three synthetic importable inputs TH-19 line 220 names: an authored input whose committed sidecar sets one parameter away from its default, a variant with byte-identical content whose committed sidecar differs only in that parameter, and a negative input committed without a sidecar. Each records itself as synthetic (TH-19 PV-06). The fixture file type (TH-19 AQ-06), the parameter, its value and the observation method (TH-19 AQ-05) are selected from retrieved Godot documentation with receipt lines; with no supporting text the card returns blocked.
2. The sidecars are produced by the pinned editor's import, which TH-19 IS-01 documents as writing a sidecar beside its input; an edit outside the Import dock is followed by a reimport (TH-19 IS-04). No sidecar for the negative input and no `native/.godot/` path remains staged or on disk in the proof directory (TH-19 GO-04; TH-19 RR-08).
3. `proof_runner.gd` extends `SceneTree`, loads the authored and variant inputs through the Resource Loader (TH-19 GO-03), prints `PASS` only when the authored input shows the non-default effect and the two observations differ (TH-19 IQ-02, IQ-04), and under `-- --inject-fault` applies the TH-19 IQ-02 assertion to the negative input and fails with the output and exit status TH-19 IQ-06 names.
4. TH-19 RR-09's failing run is recorded on this card's own branch. With the fixtures and TH-19 RR-01, RR-04 and RR-05 applied, and before TH-19 RR-02, RR-03 and RR-06 are applied, `npm run native:smoke` fails at the TH-19 IQ-02 observation; a failure for any other reason is not the reproduced failure and returns the card. With TH-19 RR-02, RR-03 and RR-06 then applied, the same command passes and reports `staged-import`, `staged-reimport` and each `proof-<name>-rebuilt` check (TH-19 IQ-02, IQ-03, IQ-04, IQ-06). Only the passing candidate is offered for integration.
5. The ignore diff is exactly TH-19 RR-01 and the runner diff exactly TH-19 RR-02 to RR-06 (TH-19 RR-07). `git check-ignore` exits 1 for a sidecar path under `native/content/*/assets/` and under `native/proofs/`, and exits 0 for a path under `native/.godot/imported/`, as TH-19 RR-01's acceptance column states.
6. `node scripts/native-smoke.mjs --export` passes and reports `proof-tadr-003-import-exported` (TH-19 RR-06, IQ-05). If the exported binary does not run the script (TH-19 AQ-19), TH-19 RR-06 fails the export run, so the card cannot complete: it returns blocked with TH-19 IG-04 recorded absent, its receipts preserved, and a request that the coordinator define the TH-19 IQ-05 fallback as a separate Verification card. Nothing is integrated in that case.
7. TH-19 IQ-01's clean-checkout procedure, which TH-19 assigns to the proof card, runs at the candidate commit. Every receipt carries TH-19 IQ-07's identity fields, including a false `sourceDirty` (TH-19 RR-08).
8. The handoff lists TH-19 IG-01 to IG-04 each as closed with the receipt that shows it; TH-19 IG-05 to IG-07 stay open and are not claimed.

**Verification and evidence:** Automated native trial for items 4 and 6, on the runner's Linux host (TH-19 AQ-16), with source commit, engine pin and binary hash in each receipt. Static git inspection for items 1, 2, 5 and 7, and `npm run check:scope -- <base> <candidate>` for the required check set. The failing receipt is the reproduced failure and the passing receipts are the fix, on one branch. Not established: Windows execution, any production importer or asset, renderer, budget or human review (TH-19 line 232), or what `--editor --import` does beyond the runner's observed result (TH-19 AQ-20). Human-hands steps: Andrew records the native execution authorization; no other hands-on step.

**Boundary:** No change to export presets, `package.json`, `npm run verify`, the networking grep, the boots or the existing `editor-import` step (TH-19 RR-07). TH-19 RR-10 and RR-11 stay rejected. No production asset is admitted, and no candidate that has not passed items 4 and 6 is integrated.

**Fuse and shared chassis: concept to import.**

Ordered so the concept-to-import path for the shared core and Fuse reads first.

<a id="art-01"></a>

### ART-01: Make concept and paintover sheets for the shared rolling core and enclosed cockpit

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 (the rolling core and cockpit all five candidates share); TRACKING EV-0423 decisions 1, 2 and 3
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-02, AC-05, AC-06, AC-07, AC-08, AC-09, AC-13, AC-14, AC-17, AC-18, AC-20 and AC-22; PD-01 VW-01, VW-02, VW-04, VW-05 and VW-10; PD-01 PF-01 to PF-15; PD-01 RL-02 to RL-05; PD-01 lines 5 and 63
- BIBLE.md § 5.2 lines 420 and 422; § 7 lines 620, 682, 719, 725, 727 and 739; § 6 line 487
- `docs/DISCOVERY.md` lines 213 and 215: the proposed workflow starts from concept and paintover, and raster art is not a production mesh, rig or clip
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-06, RQ-07 and RM-06; `docs/tech/sections/TH-19-asset-import-export.md` TH-19 CI-01 to CI-04
- Existing concept records, as references only: PD-01 CC-01 and CC-03

**Dependencies:** [PD-01](#pd-01), [FR-09](#fr-09). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P06](#q-p06), [Q-P10](#q-p10), [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P33](#q-p33). The sheets must hold under every candidate answer and caption each unselected value as unset.

**Files touched:** `docs/art/production/rolling_core/**` (sheets, prompt records, paintovers, captions and each sheet's provenance record; path under FR-09, DQ-01); `artifacts/local/tasks/ART-01/`.

**Definition of done:**

1. A view set for the shared core and cockpit: a PD-01 VW-04 turnaround that answers where the cockpit is, what moves, how scrap enters and which feature identifies the role; a PD-01 VW-05 cutaway of intake, sorting paths and fabrication chamber with its enlargement stated; a PD-01 VW-01 gameplay view; and a PD-01 VW-10 motion sequence captioned approximate. The PD-01 VW-02 beauty view is a separate member.
2. Each sheet is made by image prompts plus paintover (TRACKING EV-0423 decision 3). Its provenance record carries the prompt text and generator under PD-01 PF-03 and PF-04, the paintover and its tool under PD-01 PF-06, and any reference image it paints over; a reference stays a concept record (TH-19 CI-04). The image generator and its output terms are recorded as PD-01 PF-05 license evidence before the generator is first used (HF-01 line 72; ASSETS.md line 17).
3. No sheet carries a class tool. The cockpit encloses a neutral pilot silhouette captioned as a placeholder, not a species selection (PD-01 AC-20; Q-P06).
4. Growth is shown at the starting mech (TRACKING EV-0423 decision 2), with no mass value (Q-P10); the ordinary maximum envelope stays unset (TH-02 MP-16; Q-P22) and is not depicted as settled.
5. Each sheet carries PD-01 PF-01 to PF-13 and PF-15 and a caption stating image ID, proposal status and what it does not establish. No caption or record claims that a generated image proves articulation, mounting dimension, growth extent or route clearance (PD-01 line 63; PD-01 AC-22, PE-01, PE-02 and PE-04).
6. The review record under PD-01 PF-12 lists the acceptance check IDs applied and Andrew's verdict.

**Verification and evidence:** Static: a paper check lists, per sheet, the view ID, caption, prompt record and provenance field IDs, and fails on a missing member. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-01, AC-02, AC-05 to AC-09, AC-13, AC-14, AC-17, AC-18, AC-20 and AC-22. Not established: rolling articulation, dimensions, clearance or motion (PD-01 RL-02). No automated or native evidence applies. Human-hands steps: Andrew's review and verdict; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept work only. Sheets remain concept references and never runtime inputs (TH-19 CI-01). No model lock, budget, species or motion selection.

<a id="art-02"></a>

### ART-02: Make concept and paintover sheets for Fuse's construction C and mounted emitter

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372: Q-P04 resolved to construction C, the cable hoop with separate discharge heads, and its carried risks; `artifacts/handoff-8-2026-09-16/decisions/Q-P04-fuse-construction.json`; TRACKING EV-0423 decisions 1 to 3
- BIBLE.md § 4.4 lines 342, 346, 348 and 354 to 359; § 5.1 lines 413 and 416; § 5.2 line 428; § 7 lines 682, 721, 731 and 739
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-06, AC-10, AC-13, AC-14, AC-16, AC-20 and AC-22; PD-01 VW-01, VW-04, VW-07 and VW-11; PD-01 PF-01 to PF-15; PD-01 line 63
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-05, RR-10, RR-12 and RM-06; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-06, TP-21 and TP-22
- TRACKING EV-0322: a miscast never changes the previewed danger shape (Q-P13 partial)
- ART-01's sheets

**Dependencies:** [ART-01](#art-01), [PD-01](#pd-01), [FR-09](#fr-09). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P06](#q-p06), [Q-P13](#q-p13), [Q-P20](#q-p20), [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32).

**Files touched:** `docs/art/production/fuse/**` (sheets, prompt records, paintovers, captions and provenance records; FR-09, DQ-01); `artifacts/local/tasks/ART-02/`.

**Definition of done:**

1. Construction C on ART-01's core at the starting mech: an open cable frame with separate discharge heads legible above it and the aiming nozzle landmark kept (BIBLE lines 359, 416). It is shown in a PD-01 VW-04 turnaround, a PD-01 VW-01 gameplay view and a PD-01 VW-11 combat-readability diagram of tool, danger footprint and escape, captioned as intended geometry (TH-16 RR-12).
2. Each discharge head is drawn as a working mechanism whose construction differs where behaviour differs, never as a colour swap (EV-0372 carried risk; PD-01 AC-10; BIBLE lines 428, 682). A PD-01 VW-07 lineup of candidate heads carries a common size reference, is captioned as a relative comparison, and captions the head set as candidates under Q-P13 (PD-01 AC-20).
3. A miscast-tell panel shows instability localized to one head while the nozzle's aim line and danger shape stay unchanged (EV-0322; TH-16 RR-10). It is captioned as a candidate with warning timing unset (TH-03 TP-22), and localization is labelled unproven while Q-P13 is open (EV-0372).
4. A pilot panel shows Fuse seated in the enclosed cockpit, with expressiveness from the whole seated body and ears and tail inside (BIBLE line 346), captioned as a candidate species under Q-P06.
5. Method, provenance and captions as ART-01 items 2 and 5, and a PD-01 PF-12 review record.

**Verification and evidence:** Static: the ART-01 paper check applied to this set. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-01, AC-06, AC-10, AC-13, AC-14, AC-16, AC-20 and AC-22. Not established: occlusion or sightline at camera distance, which is ART-04's; miscast localization; mounting dimension (PD-01 PE-02); articulation. Human-hands steps: Andrew's review and verdict; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept only. No element pool, head count, failure rate, instability meter or self-damage amount is selected (BIBLE line 359; Q-P13). The discharge post device (BIBLE line 413) is outside this batch.

<a id="art-03"></a>

### ART-03: Make rough blockouts of the shared core, cockpit and Fuse's construction C

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- ART-01 and ART-02 sheets and review records; TRACKING EV-0423 decisions 1 and 2
- BIBLE.md § 7 line 719 (leave useful gaps around moving assemblies); § 5.1 line 416 (landmarks that mounts grow around)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-06, PF-08, PF-09, PE-02 and PE-03
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 and PV-02; `docs/tech/sections/HF-01-production-conventions.md` lines 31 and 72
- TRACKING EV-0447 decision 1: the batch asset list and file locations are recorded before the budget, so rough blockouts may be proposed for the next sprint; Q-P26's measured budget stays open
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-16 and MP-17; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11 and CO-14
- `docs/DISCOVERY.md` line 215 (model and pivot authoring in Blender)

**Dependencies:** [ART-01](#art-01), [ART-02](#art-02). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P10](#q-p10), [Q-P13](#q-p13), [Q-P22](#q-p22), [Q-P26](#q-p26) (the measured budget only), [Q-P27](#q-p27).

**Files touched:** `source-assets/rolling_core/blockout/**` and `source-assets/fuse/blockout/**` (editable Blender masters; HF-01 line 31); `source-assets/rolling_core/provenance/blockout/**` and `source-assets/fuse/provenance/blockout/**`; `artifacts/local/tasks/ART-03/` (renders).

**Definition of done:**

1. Low-detail blockouts at the starting mech (TRACKING EV-0423 decision 2) of the core mass, cockpit enclosure, suspension and retracting mounts, and construction C's cable hoop, head mounts and emitter nozzle, as separately named objects so moving and stable parts can be told apart (BIBLE line 719; PD-01 AC-10).
2. Units, axes and the scale reference are recorded under PD-01 PF-08. Every dimension is labelled a provisional blockout value, is not a mounting record (PD-01 PE-02), and says nothing about the ordinary maximum envelope (TH-02 MP-16, MP-17).
3. A list of parts proposed as moving or stable is recorded as input to ART-05, not as a motion selection (Q-P27).
4. Each TH-19 OC-01 record carries PD-01 PF-01 to PF-13 and PF-15, the Blender version pinned at first use in PD-01 PF-06, and links forward to the ART-01 and ART-02 sheets it realizes. Masters stay outside `native/` (TH-19 OC-01).

**Verification and evidence:** Static: a reviewer checks the provenance records and compares the recorded object list with turnaround renders from each master. Human review record (PD-01 PF-12): Andrew compares the renders with ART-01 and ART-02 for PD-01 AC-01, AC-02 and AC-10. Not established: any dimension, clearance, articulation or in-engine appearance. Human-hands steps: Andrew installs Blender and records Blender execution authorization before assignment; Andrew's review.

**Boundary:** Rough blockouts only. No final topology, UVs, textures, rig, runtime input or import. No blockout value becomes a mounted dimension, growth envelope or route clearance.

<a id="art-04"></a>

### ART-04: Check silhouette and pilot sightline at the provisional camera distance before model lock

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 carried risk and the `risks_to_watch` list in `artifacts/handoff-8-2026-09-16/decisions/Q-P04-fuse-construction.json`
- TRACKING EV-0423 decision 4: the orchard browser proof's camera distance is the provisional distance, rechecked in the native slice, and is not an answer to Q-P32's bounds
- `src/orchard/scene.js` lines 410 and 412: the orchard chase camera's distance expression and the camera position derived from it
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-06, AC-10, AC-13 and AC-16; PD-01 VW-01
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-04 and MP-23; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-06 and RR-05
- BIBLE.md lines 416, 483, 663 and 682
- ART-03's blockouts

**Dependencies:** [ART-03](#art-03), [FR-09](#fr-09). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32) (the native recheck belongs to ART-18).

**Files touched:** `docs/art/production/fuse/review/**` (captures, paintover proposals, the check record and its PD-01 PF-12 review record; FR-09, DQ-01); `artifacts/local/tasks/ART-04/`.

**Definition of done:**

1. The check record states the provisional camera distance as the orchard expression at `src/orchard/scene.js` line 410 evaluated for the starting mech, with every input to that expression named, and labels it provisional under TRACKING EV-0423 decision 4; the card writes no distance value of its own.
2. Renders of ART-03's blockout in close third person (TH-02 MP-04) at that distance, from the aiming, rear-quarter and side views the record names.
3. For each view the record states whether the cockpit and pilot are findable (PD-01 AC-01), whether the hoop or heads obstruct the aiming nozzle landmark or its aim line (BIBLE line 416), and whether each head reads as a distinct mechanism at that distance (PD-01 AC-06, AC-10).
4. Each failing view gets a paintover proposal. The record ends with a lock or revise verdict recorded by Andrew; model lock, meaning the start of ART-06 to ART-08, requires the lock verdict.
5. The record names the native recheck at the native slice's camera as an open obligation carried by ART-18, not as satisfied.

**Verification and evidence:** Human review record (PD-01 PF-12): Andrew's verdict. Static: every required view exists at the recorded distance, and the distance traces to `src/orchard/scene.js` line 410. Not established: in-engine camera collision, the native camera, occlusion while rolling (Q-P27), human feel or hardware. Human-hands steps: Andrew's verdict; Andrew installs Blender if renders are made from the masters.

**Boundary:** The provisional distance is Andrew's decision and not an answer to Q-P32. No change to the blockout beyond paintover proposals.

<a id="art-05"></a>

### ART-05: Propose the motion brief for the rolling core, suspension, retraction and fabrication sequence

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372, Q-P27 partial answer (hybrid); BACKLOG Q-P27's missing information (rolling core, stable cockpit, retracting equipment and the intake-to-fabrication sequence) and closure evidence (moving and stable parts, required action phases and ordinary route clearance)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PE-01, PE-05, VW-10, RL-02 and RL-05
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RT-01 to RT-07, RQ-02, RQ-03, RQ-07 and RM-06; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11 and CO-14
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-03, MP-06, MP-16, MP-17 and MP-23; `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 22
- BIBLE.md lines 481, 487, 725, 727 and 719
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g2-skeleton.txt` lines 50, 58 and 66 (a skeleton modifier's per-update pose hook, influence blending by the parent skeleton, and a pose-override caution), cited as documented candidates only
- ART-03's moving-and-stable part list

**Dependencies:** [ART-03](#art-03), [FR-09](#fr-09). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P21](#q-p21), [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32). This card produces input for Andrew's Q-P27 answer and does not answer it.

**Files touched:** `docs/art/production/rolling_core/motion-brief.md` (FR-09, DQ-01); `artifacts/local/tasks/ART-05/`.

**Definition of done:**

1. Every part in ART-03's list is classified as procedurally moving, hand-keyed or stable, including the rolling core, cockpit, suspension, retracting mounts and the hoop head mounts, with the EV-0372 hybrid split kept.
2. Each procedurally moving part names the published value it derives from, the committed pose, extent and basis (TH-16 RM-06, RT-06). The brief states that no displayed motion advances a gameplay interval or feeds the query world (TH-16 RT-05, RT-07; HF-04a line 22).
3. Action phases for suspension and retraction are listed per movement action in TH-02 MP-03 (rolling, jumping, rebounds, impacts).
4. The intake-to-fabrication sequence is described in the phases PD-01 PE-05 names (attraction, intake, internal processing and construction of the changed part), with the retained attachment to the chassis identified, each phase classed as procedural or hand-keyed, and presented only from committed values (TH-05 CO-11, CO-14; TH-16 RQ-07; BIBLE lines 725, 727).
5. Rates, ranges, growth extent, route clearance and camera response are listed as parameters tied to Q-P21 (TH-02 MP-06), Q-P22 (TH-02 MP-16, MP-17) and Q-P32 (TH-02 MP-23), with no value.
6. Godot mechanisms appear only as candidates with receipt lines. A mechanism with no receipt is recorded as a limit.
7. The brief goes to the coordinator for Andrew. The card completes on reviewed delivery, not on Q-P27's answer.

**Verification and evidence:** Static paper check: every listed part and every PD-01 PE-05 phase is classified, every parameter row has a question ID and no value, and every engine statement cites a receipt line; one independent review. Not established: the executed trials PD-01 PE-01 and PE-05 require, feel or clearance. Human-hands steps: Andrew reads the brief and answers Q-P27.

**Boundary:** No motion selected, no script, no rig and no value. Q-P27 stays open until Andrew records an answer in TRACKING.

<a id="art-06"></a>

### ART-06: Model, UV and texture the shared rolling core and cockpit

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-03's blockout, ART-04's lock verdict, and ART-05's brief with Andrew's recorded Q-P27 answer; TRACKING EV-0423 decisions 1 and 2
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` TH-04 AS-01 to AS-04, AA-02 and AA-03; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-02, AC-05, AC-06, AC-07 and AC-09; PD-01 PF-01 to PF-15; PD-01 PE-02 and PE-03; PD-01 VW-01, VW-02 and VW-04
- BIBLE.md § 5.2 line 422; § 7 lines 645, 699 and 701
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03; `docs/tech/sections/HF-01-production-conventions.md` lines 31, 68 and 72
- `docs/DISCOVERY.md` line 211 (Blender and Krita as free local candidates)
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` lines 16 and 24 (the exporter supports meshes and textures; quads and n-gons are triangulated on export)

**Dependencies:** [ART-03](#art-03), [ART-04](#art-04), [ART-05](#art-05). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P10](#q-p10), [Q-P22](#q-p22).

**Files touched:** `source-assets/rolling_core/model/**` (Blender master), `source-assets/rolling_core/textures/**` (texture masters) and `source-assets/rolling_core/provenance/model/**` (provenance and notice records); `artifacts/local/tasks/ART-06/`.

**Definition of done:**

1. Final topology is separated into the moving and stable parts the approved brief names, with pivots at the brief's joints.
2. UVs and texture masters place wear by material and use (PD-01 AC-05) and keep materials distinct at gameplay distance (PD-01 AC-06). Mesh and texture limits come from the Q-P26 and Q-E03 answers, recorded as review parameters; the card states no limit of its own.
3. The model is at the starting mech (TRACKING EV-0423 decision 2). Its PD-01 PE-03 record names the capability-set selection it derives from: the run-start set, with weapon and special mobility available and the main hero skill and ultimate locked (TH-04 AS-01 to AS-04; TH-04 AA-02), holding only the slot selections the run's initial state holds (TH-04 AA-03), and reaching the encounter only as an installed value (TH-05 CO-11). No grown state is modelled.
4. The TH-19 OC-01 record carries PD-01 PF-01 to PF-13 and PF-15, tool versions pinned in PD-01 PF-06, license evidence and notice obligation for every texture source (TH-19 NO-02, NO-03), and the recipe to the future runtime input (TH-19 PV-03).
5. No runtime input is written. Export to `native/content/` belongs to ART-17.

**Verification and evidence:** Static: provenance and license fields; budget conformance by the method the Q-P26 answer records. Human review record (PD-01 PF-12): Andrew reviews PD-01 VW-02, VW-04 and VW-01 renders for PD-01 AC-01, AC-02, AC-05, AC-06, AC-07 and AC-09. Not established: in-engine appearance, renderer (Q-E04), measured performance (Q-E03) or articulation (PD-01 PE-01). Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No rig, runtime input, import or admission. No budget value invented. No paid tool, download or LFS (HF-01 line 72).

<a id="art-07"></a>

### ART-07: Model, UV and texture Fuse the pilot

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-02's pilot panel, ART-03's cockpit enclosure and ART-04's lock verdict; TRACKING EV-0423 decision 1
- BIBLE.md § 4.4 lines 346 and 348; § 7 lines 620 and 701
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-06, AC-18, AC-19 and AC-20; PD-01 PF-01 to PF-15; PD-01 RL-04
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03

**Dependencies:** [ART-02](#art-02), [ART-03](#art-03), [ART-04](#art-04). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P06](#q-p06) (species and animal-only cast), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P27](#q-p27).

**Files touched:** `source-assets/fuse/pilot/**`; `source-assets/fuse/provenance/pilot/**`; `artifacts/local/tasks/ART-07/`.

**Definition of done:**

1. A seated pilot model that fits ART-03's cockpit enclosure, with ears and tail inside the cockpit (BIBLE line 346) and a species that matches the Q-P06 answer.
2. Topology and joint placement support whole-seated-body expression (BIBLE line 346), with the expression list left to Q-P27.
3. UVs and texture masters simplify fine fur and glass detail before it obscures the pilot at gameplay distance (PD-01 AC-06, RL-04), within the Q-P26 and Q-E03 answers.
4. TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance and license fields; budget conformance by the Q-P26 method. Human review record (PD-01 PF-12): Andrew reviews turnaround and in-cockpit renders at the ART-04 distance for PD-01 AC-01, AC-18 and AC-19. Not established: expression range, in-engine appearance or human feel. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No rig, clip, runtime input or import. No species, roster or cast decision beyond the recorded Q-P06 answer.

<a id="art-08"></a>

### ART-08: Model, UV and texture Fuse's emitter, cable hoop and discharge heads

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-02's sheets, ART-03's blockout, ART-04's lock verdict and ART-06's chassis master; TRACKING EV-0423 decision 1
- BIBLE.md lines 354, 359, 413, 416 and 428; the EV-0372 carried risk that each head is a working mechanism, not a colour swap
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-07, AC-10 and AC-16; PD-01 PE-02; PD-01 PF-01 to PF-15
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RM-06; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-06, TP-06 and TP-21

**Dependencies:** [ART-02](#art-02), [ART-03](#art-03), [ART-04](#art-04), [ART-06](#art-06). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13) (which elements, and so which heads), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P20](#q-p20), [Q-P22](#q-p22).

**Files touched:** `source-assets/fuse/tool/**`; `source-assets/fuse/provenance/tool/**`; `artifacts/local/tasks/ART-08/`.

**Definition of done:**

1. An emitter with the aiming nozzle landmark and a visible working chamber (BIBLE lines 413, 416).
2. A cable hoop carrying one head per element in the Q-P13 answer, each head with its own working mechanism (PD-01 AC-10; BIBLE line 428).
3. A dimensioned mounting record against ART-06's chassis in the provenance record, with units and axes (PD-01 PE-02, PF-08). Dimensions live in the master, not in this card.
4. Texture and mesh limits from the Q-P26 and Q-E03 answers; TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance, mounting record and license fields. Human review record (PD-01 PF-12): Andrew reviews turnaround and gameplay-distance renders for PD-01 AC-07, AC-10 and AC-16. Not established: mounted fit in engine, head mechanism motion or miscast localization. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No element pool, head count or failure behaviour chosen by the card. No device. No rig, import or runtime input.

<a id="art-09"></a>

### ART-09: Rig the rolling core, suspension and retracting mounts for procedural drive

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-05's brief with Andrew's recorded Q-P27 answer; ART-06's master; TRACKING EV-0423 decision 1
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8, 16 and 24 (armature deform parenting with automatic, envelope or empty-group weights; a bone's Deform toggle excludes it), `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` lines 20 and 28 (painting bone vertex groups; deform groups), `artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` lines 4, 8 and 16 (the glTF exporter covers armatures and skinning), `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 22 to 36 and 83 to 94 (glTF skins and skeletons in Godot's import state)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-09 and PE-01; `docs/tech/sections/TH-19-asset-import-export.md` TH-19 PV-05

**Dependencies:** [ART-05](#art-05), [ART-06](#art-06). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P21](#q-p21), [Q-P22](#q-p22).

**Files touched:** `source-assets/rolling_core/model/**` (the armature in the master) and `source-assets/rolling_core/provenance/rig/**` (PD-01 PF-09 record); `artifacts/local/tasks/ART-09/` (test export and renders).

**Definition of done:**

1. Bones exist exactly for the parts the approved brief marks as procedurally driven, named for the Godot-side driver of ART-14, with deform and non-deform bones distinguished (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` line 24), including the mount bones the hoop attaches to.
2. Skin weights use the method recorded under PD-01 PF-09, whether automatic, envelope or painted (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` line 20), and are reviewed at every joint.
3. No hand-keyed action is authored on these bones (EV-0372 hybrid split).
4. PD-01 PF-09 records the bone list, rest pose, units and axes. The bone count stays within the Q-P26 and Q-E03 answers, and the card states none.
5. A test export in glTF 2.0 (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` line 4) with skinning goes to the receipts directory only, to show the rig exports. It is not a runtime input.

**Verification and evidence:** Static: PD-01 PF-09 record and bone naming against the brief. Human review record (PD-01 PF-12): Andrew reviews pose-range renders for deformation at joints and PD-01 AC-02. Not established: Godot import of the skeleton, procedural behaviour or PD-01 PE-01's trial. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No motion values, no clips, no runtime input and no import.

<a id="art-10"></a>

### ART-10: Rig Fuse the pilot for hand-keyed expressions

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, native stage

**Source and inputs:**

- ART-07's master; ART-05's brief and Andrew's recorded Q-P27 answer (expressions are hand-keyed Blender clips, EV-0372); TRACKING EV-0423 decision 1
- BIBLE.md line 346
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` lines 20 and 28; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 8 (NLA tracks hold action strips)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-09

**Dependencies:** [ART-05](#art-05), [ART-07](#art-07). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P06](#q-p06), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).

**Files touched:** `source-assets/fuse/pilot/**`; `source-assets/fuse/provenance/pilot/**`; `artifacts/local/tasks/ART-10/`.

**Definition of done:**

1. An armature whose controls cover the whole-seated-body expression range the Q-P27 answer lists (BIBLE line 346).
2. Weights use a method recorded under PD-01 PF-09 and are reviewed at every joint the answered expressions move.
3. PD-01 PF-09 records the bone list, rest pose, units and axes within the Q-P26 and Q-E03 answers. A test export goes to receipts only.

**Verification and evidence:** Static: PD-01 PF-09 record. Human review record (PD-01 PF-12): Andrew reviews pose renders for each answered expression's extreme. Not established: clip quality, in-engine playback or human feel. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No clips, runtime input or import.

<a id="art-11"></a>

### ART-11: Rig Fuse's emitter and cable hoop heads as working mechanisms

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, native stage

**Source and inputs:**

- ART-08's master and ART-09's mount bones; ART-05's brief and Andrew's recorded Q-P27 answer (tool actions are hand-keyed; retraction is procedural); TRACKING EV-0423 decision 1
- The EV-0372 carried risk: each head a visible working mechanism
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RC-02, RR-01 and RR-10; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 TP-06
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-10, PE-02 and PF-09
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 8

**Dependencies:** [ART-05](#art-05), [ART-08](#art-08), [ART-09](#art-09). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).

**Files touched:** `source-assets/fuse/tool/**`; `source-assets/fuse/provenance/tool/**`; `artifacts/local/tasks/ART-11/`.

**Definition of done:**

1. Each head's working mechanism has its own controls, so its action is visible and not a material change (PD-01 AC-10).
2. The nozzle's aim reference is a separate control that head actions never move, because committed geometry originates at the weapon and a miscast never moves it (TH-03 TP-06; TH-16 RR-01, RR-10). At runtime a view sets it only from published values Session supplies (TH-16 RC-02).
3. The hoop's attachment to ART-09's mount bones is recorded against PD-01 PE-02.
4. PD-01 PF-09 record within the Q-P26 and Q-E03 answers. A test export goes to receipts only.

**Verification and evidence:** Static: PD-01 PF-09 record and control list against the Q-P13 head set. Human review record (PD-01 PF-12): Andrew reviews renders of each head's mechanism at its extremes. Not established: in-engine playback, miscast localization or effect alignment. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No clips, effects, runtime input or import.

<a id="art-12"></a>

### ART-12: Hand-key Fuse's pilot expression clips

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-10's rig; Andrew's recorded Q-P27 answer listing expressions and phases; TRACKING EV-0423 decision 1
- BIBLE.md lines 346 and 350
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` lines 8, 32 and 40 (actions as NLA strips; Push Down moves the active action into a track; the glTF exporter's NLA Tracks mode exports each track as its own animation); `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 14 and 53 (glTF animations become animations in an AnimationPlayer node on import)
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RE-07 and RT-07; `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 22; `docs/tech/sections/HF-01-production-conventions.md` line 68

**Dependencies:** [ART-10](#art-10). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P13](#q-p13), [Q-P28](#q-p28).

**Files touched:** `source-assets/fuse/pilot/**` (actions in the master); `source-assets/fuse/provenance/pilot/**` (PD-01 PF-09 per clip); `artifacts/local/tasks/ART-12/` (captures and test export).

**Definition of done:**

1. One action per expression in the Q-P27 answer, each on its own NLA track so the exporter's NLA Tracks mode emits it as an independent animation (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40), with snake_case names (HF-01 line 68).
2. Each clip's record names the published fact meant to trigger it. No clip decides, times or advances gameplay (TH-16 RE-07, RT-07; HF-04a line 22).
3. Clip lengths and the authoring frame rate are recorded as parameters under the Q-P27 answer, with no value in the card.
4. No clip is synchronized to a voiced line or bark (Q-P28).

**Verification and evidence:** Static: PD-01 PF-09 per clip and track organization. Human review record (PD-01 PF-12): Andrew reviews rendered captures of each clip against BIBLE line 346. Not established: in-engine blending, timing against published results, or human feel. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No runtime input or import. No clip for an unanswered expression. No voice.

<a id="art-13"></a>

### ART-13: Hand-key Fuse's tool action clips

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-11's rig; Andrew's recorded Q-P27 answer listing tool actions and phases; TRACKING EV-0423 decision 1
- TRACKING EV-0411 and FR-07's accepted AM-H8-003: kit weapon, main hero skill, mobility and ultimate actions reference ability definitions (HF-06a row N-021) that reference the attacks they produce
- BIBLE.md lines 354, 357, 413 and 428
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RE-05, RE-07, RR-10 and RT-07; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-05 and EP-01
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40; `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 14 and 53

**Dependencies:** [ART-04](#art-04), [ART-11](#art-11), [FR-07](#fr-07). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P20](#q-p20), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P11](#q-p11).

**Files touched:** `source-assets/fuse/tool/**`; `source-assets/fuse/provenance/tool/**`; `artifacts/local/tasks/ART-13/`.

**Definition of done:**

1. One action per tool action in the Q-P27 answer, each on its own NLA track (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40). Candidate names come from BIBLE lines 354, 357 and 428 and are used only where the answer admits them. A miscast action exists only for an element Q-P13 makes miscastable, and an ultimate action only as Q-P20 defines it.
2. Each clip's record names its trigger as the published result of an ability definition or of an attack that ability produces (AM-H8-003 through FR-07), never a raw input.
3. No clip moves the nozzle aim control, and a miscast clip stays local to one head (TH-16 RR-10; EV-0372 carried risk).
4. No clip decides, rerolls or advances an outcome (TH-16 RE-05, RE-07, RT-07; TH-03 CH-05).
5. Clip lengths and frame rate are parameters under the Q-P27 answer.

**Verification and evidence:** Static: PD-01 PF-09 per clip, with each trigger naming an ability or produced attack. Human review record (PD-01 PF-12): Andrew reviews captures of each clip at the ART-04 distance. Not established: alignment with committed geometry, in-engine playback or feel. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No effect, cue, runtime input or import. No node or upgrade content (Q-P11).

<a id="art-14"></a>

### ART-14: Implement the procedural rolling core, suspension and retraction motion in Godot

**Card revision:** 1 · **Owner:** Rendering/input/UI · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-05's brief with Andrew's recorded Q-P27 answer; ART-09's bone list; the scenes ART-17 and ART-18 admitted, including the ART-12 and ART-13 clips
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RC-02, RT-01 to RT-08, RM-06, RQ-02, RQ-03 and RE-06
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-04, MP-06, MP-16 and MP-23; `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 22
- `docs/tech/sections/HF-01-production-conventions.md` lines 26, 27, 66 and 68; Godot 4.7.2 (BACKLOG.md line 9) with typed GDScript
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/g2-skeleton.txt` lines 8, 50, 58 and 66; `artifacts/handoff-8-2026-09-16/drafts/ctx7/g3-animtree.txt` lines 75 and 83 (AnimationTree for blending beyond the player's fixed cross-fades)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PE-01

**Dependencies:** [ART-05](#art-05), [ART-09](#art-09), [ART-12](#art-12), [ART-13](#art-13), [ART-17](#art-17), [ART-18](#art-18), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P22](#q-p22), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P21](#q-p21), [Q-P32](#q-p32).

**Files touched:** `native/presentation/motion/rolling_core_motion.gd` and its UID sidecar; `native/presentation/motion/rolling_core_motion.tscn` (the presentation composition that binds the script to the admitted core scene; HF-01 line 27); `artifacts/local/tasks/ART-14/`.

**Definition of done:**

1. Typed GDScript drives exactly ART-09's procedural bones from the published pose, extent and movement values Session supplies on D06 (TH-16 RC-02, RM-06), with the mechanism the approved brief selects from retrieved documentation.
2. Motion holds when no newer snapshot exists and on pause (TH-16 RT-02, RT-03). It is display-only with no writeback (TH-16 RT-05) and never advances a gameplay interval (TH-16 RT-07; HF-04a line 22).
3. The ART-12 and ART-13 clips imported by ART-18 play over the procedural pose, and the blending method and precedence are recorded (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g3-animtree.txt` lines 75 and 83).
4. Rates and ranges are read from parameters tied to the Q-P21, Q-P22 and Q-P32 answers. No authored tuning is duplicated in code (HF-01 line 26).
5. PD-01 PE-01's trial runs with the command the engineering handoff (TH-29) names and is recorded with source identity. If no command exists, the card returns blocked.

**Verification and evidence:** Automated native trial by the handoff's command for items 1, 2 and 5. Static: typed-boundary review against HF-01 line 66. Human review record (PD-01 PF-12): Andrew reviews captures from the trial for PD-01 AC-02. Not established: human feel, controller support, performance on target hardware (Q-E03) or route clearance (PD-01 PE-04). Human-hands steps: Andrew records Godot execution authorization; Andrew's review.

**Boundary:** Reads only D06 values. No gameplay record, camera, clearance claim or `native/runtime/**` change.

<a id="art-15"></a>

### ART-15: Design Fuse's elemental discharge effects as source masters

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RC-03, RE-01 to RE-09, RR-01, RR-05, RR-06, RR-08, RR-10, RP-16, RP-17, RP-20, RX-09 and RX-12
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 AT-17, CH-03, CH-05 and TP-06; `docs/tech/sections/TH-13-chaos-outcomes.md` TH-13 XP-01, XP-02 and XP-04
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-03, AC-16 and VW-11; BIBLE.md lines 493, 495 and 731
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g4-particles.txt` lines 26, 81 and 91 (a `GPUParticles3D` node needs a process material and at least one draw pass; the process material can be a ParticleProcessMaterial or carry a particles shader)
- `docs/tech/sections/HF-01-production-conventions.md` line 30 (materials permitted, shader source not named; DQ-02) and line 31; TH-19 IG-01 to IG-07 (no runtime input before the gates); ART-11's head controls; TRACKING EV-0423 decision 1

**Dependencies:** [ART-04](#art-04), [ART-11](#art-11). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P30](#q-p30), [Q-P32](#q-p32), [Q-P38](#q-p38).

**Files touched:** `source-assets/fuse/effects/**` (effect specification records, texture masters and provenance); `artifacts/local/tasks/ART-15/`. Nothing under the native tree; runtime effect scenes and materials are built at ART-19 after the import gates.

**Definition of done:**

1. One effect specification per head in the Q-P13 answer, stating that the effect is presented from the committed descriptor's parts and derives no geometry (TH-16 RC-03, RR-01), rooted at the firing head and the weapon origin (TH-03 TP-06).
2. The composition order keeps tool, danger footprint and escape visible before effects (TH-16 RR-05; BIBLE line 731), and each specification shows it with a mock frame over an ART-04 capture.
3. The specification names a ParticleProcessMaterial as the process material; a particles shader is not used until the DQ-02 amendment admits shader source.
4. Cosmetic variation changes no published part (TH-16 RE-08), instances hold no per-run state (TH-16 RE-06), and resources will reach Presentation only as handles (TH-16 RE-02).
5. Counts, lifetimes and pool sizes are parameters bound to TH-16 RP-20 under Q-E04 and Q-E03, and requiredness is bound to TH-16 RP-17 under Q-P30 and Q-P38, with no value.
6. Texture masters carry provenance (TH-19 PV-01) and tool versions pinned in PD-01 PF-06.

**Verification and evidence:** Static: review of each specification against TH-16 RE-01 to RE-09 and RR-10. Human review record (PD-01 PF-12): Andrew reviews the mock frames for PD-01 AC-03 and AC-16. Not established: engine behaviour of any effect, dense-fight readability (TH-16 RR-06), performance or human feel. Human-hands steps: Andrew installs Krita and records execution authorization; Andrew's review.

**Boundary:** No `native/` write, gameplay value, geometry or outcome. No sound.

<a id="art-16"></a>

### ART-16: Design Fuse's miscast tells as source masters

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, native stage

**Source and inputs:**

- TRACKING EV-0322 (a miscast never changes the previewed danger shape) and the EV-0372 carried risk (miscast localization unproven while Q-P13 is open); TRACKING EV-0423 decision 1
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-08, RR-09, RR-10, RT-07 and RP-17; `docs/tech/sections/TH-13-chaos-outcomes.md` TH-13 XP-02 and XP-06; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-03 and TP-22
- ART-13's miscast clips and ART-15's effect specifications

**Dependencies:** [ART-13](#art-13), [ART-15](#art-15). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P26](#q-p26), [Q-P30](#q-p30), [Q-P38](#q-p38). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04).

**Files touched:** `source-assets/fuse/effects/**`; `artifacts/local/tasks/ART-16/`.

**Definition of done:**

1. A tell specification for each miscast the Q-P13 answer allows, localized to one head, with its warning timing and disclosure following the answer (TH-03 TP-22).
2. No tell widens, moves or retargets the danger shape (TH-16 RR-10), and no tell advances or lengthens a window (TH-16 RT-07).
3. Requiredness follows the Q-P30 and Q-P38 answers (TH-16 RR-09, RP-17). A required tell that cannot be drawn holds the encounter (TH-16 RR-08; TH-13 XP-06).

**Verification and evidence:** Static: review against TH-16 RR-08 to RR-10. Human review record (PD-01 PF-12): Andrew reviews mock frames of each tell. Not established: that players read the tell before harm, which needs a human session, or localization in play. Human-hands steps: Andrew's review.

**Boundary:** No `native/` write. No miscast rule, frequency or warning policy chosen by the card. No gameplay change.

<a id="art-17"></a>

### ART-17: Import and admit the shared rolling core and cockpit through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01 to OC-05, PV-01 to PV-07, IS-01 to IS-09, SI-01 to SI-06, GO-01 to GO-06, AR-01 to AR-08, EM-01 to EM-08, NO-02 to NO-04, AG-01 to AG-09 and IG-01 to IG-07, and walk W1 at lines 306 to 329
- `docs/tech/sections/HF-05-content-admission.md` lines 24, 25, 49 and 52; `docs/tech/sections/HF-01-production-conventions.md` lines 30, 36, 61, 72 and 85
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RM-01, RM-02 and RM-07; `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-11
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40 and `artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` line 40 (export modes); `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1-gltf-import.txt` lines 8 and 111 (a post-import script is set through the Custom Script import property); `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 22 to 36 and 83 to 94
- NQ-01's receipts; ART-06 and ART-09 masters; TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [ART-06](#art-06), [ART-09](#art-09), [SC-01](#sc-01), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13).

**Files touched:** `native/content/rolling_core/assets/**` (exported glTF input and textures with their `.import` sidecars); `native/content/rolling_core/scenes/**` (composition scene); `source-assets/rolling_core/provenance/import/**` (TH-19 PV-02 links and recipe); `artifacts/local/tasks/ART-17/`.

**Definition of done:**

1. TH-19 IG-01 to IG-07 are each closed with named evidence before any file is staged (TH-19 AG-01).
2. The runtime input is exported from the masters by the recipe recorded under PD-01 PF-06, with the exporter mode recorded (TH-19 PV-03).
3. Each sidecar is committed beside its input and reviewed as sidecar bytes (TH-19 IS-01, IS-02). Texture import settings follow the Q-E04 answer (TH-19 AQ-12). A custom post-import script is used only if a Tooling card under `native/editor_tools/**` supplies it (HF-01 line 36).
4. The composition scene references inputs by exact path and definitions by domain ID and carries no second gameplay value (TH-19 AR-01, AR-02, AR-07). A missing reference is a diagnostic, never a fallback (TH-19 AR-06; TH-16 RM-07).
5. TH-19's W1 order is walked for this unit through the authorized export, ending with the exported-load receipt (TH-19 EM-06, AG-09).
6. Every manifest entry reaches its provenance link and notice obligation (TH-19 EM-02, NO-04).

**Verification and evidence:** Automated native: import of a staged copy, validation of TH-19 AG-05 to AG-07, and the exported load of TH-19 AG-09, by the handoff's commands. Static: each sidecar tracked and not ignored, no `.godot` path staged (TH-19 GO-04), provenance complete. Human review record (PD-01 PF-12): Andrew compares in-engine captures with ART-06's review renders for PD-01 AC-01, AC-02 and AC-06, with any difference recorded as a finding. Not established: renderer qualification, budgets measured on target hardware, Windows execution or human feel. Human-hands steps: Andrew installs Blender for the export and records Blender and Godot execution authorization; Andrew's review.

**Boundary:** Admission is not distribution approval (TH-19 NO-05; Q-E06). No definition authoring, which belongs to Content cards. No editor tool. No gameplay value.

<a id="art-18"></a>

### ART-18: Import and admit Fuse's pilot, tool and clips through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row
- TRACKING EV-0411 and FR-07's accepted AM-H8-003: slot actions reference ability definitions (HF-06a row N-021), and HF-06a row N-013 distinguishes a slot action's visual reference from an attack's
- TRACKING EV-0423 decision 4: the provisional distance of ART-04 is rechecked in the native slice
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 14 and 53 (glTF animations become AnimationPlayer animations on import)
- ART-04's check record; ART-07, ART-08, ART-10, ART-11, ART-12 and ART-13 masters and PD-01 PF-09 records

**Dependencies:** [NQ-01](#nq-01), [ART-04](#art-04), [ART-07](#art-07), [ART-08](#art-08), [ART-10](#art-10), [ART-11](#art-11), [ART-12](#art-12), [ART-13](#art-13), [ART-17](#art-17), [FR-07](#fr-07), [SC-01](#sc-01), [SC-02](#sc-02), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P06](#q-p06), [Q-P13](#q-p13), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13), [Q-P32](#q-p32).

**Files touched:** `native/content/fuse/assets/pilot/**` and `native/content/fuse/assets/tool/**` (inputs with sidecars; the effects folder is ART-19's and the audio folder belongs to the sound import card); `native/content/fuse/scenes/pilot/**` and `native/content/fuse/scenes/tool/**` (compositions mounted on ART-17's core scene); `source-assets/fuse/provenance/import/**`; `docs/art/production/fuse/review/native/**` (the native recheck record; FR-09, DQ-01); `artifacts/local/tasks/ART-18/`.

**Definition of done:**

1. ART-17 items 1 to 6 hold for the pilot and tool inputs.
2. Every clip in the ART-12 and ART-13 records is present after import under its recorded name (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` line 53). A missing or renamed clip is a rejection.
3. Each tool-action clip's binding names the ability definition or produced attack its record names (AM-H8-003 through FR-07), and the tool's visual reference is kept distinct from an attack's (HF-06a row N-013).
4. The tool mounts on the core scene at ART-11's recorded attachment, and the nozzle aim control is left for published values (TH-16 RC-02).
5. ART-04's silhouette and sightline check is repeated at the native slice's camera and recorded beside ART-04's provisional verdict; a disagreement returns the model to Andrew as a finding (TRACKING EV-0423 decision 4).

**Verification and evidence:** As ART-17, plus an automated check listing imported clip names against the PD-01 PF-09 records. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each clip and the native recheck. Not established: blending with ART-14's procedural motion in play, Q-P32's bounds, or human feel. Human-hands steps: as ART-17, and Andrew's native recheck verdict.

**Boundary:** As ART-17. No effects, which belong to ART-19. The native recheck answers nothing about Q-P32's bounds.

<a id="art-19"></a>

### ART-19: Build, import and admit Fuse's discharge effects and miscast tells through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RE-02 to RE-04, RP-17 and RX-10
- ART-15 and ART-16 specifications and texture masters; Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g4-particles.txt` lines 81 and 91
- TRACKING EV-0411 and FR-07 (HF-06a row N-013's visual references); TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [ART-15](#art-15), [ART-16](#art-16), [ART-18](#art-18), [FR-07](#fr-07), [SC-02](#sc-02), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P13](#q-p13), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-P30](#q-p30), [Q-P38](#q-p38).

**Files touched:** `native/content/fuse/assets/effects/**` (textures, process materials and sidecars); `native/content/fuse/scenes/effects/**` (effect scenes); `source-assets/fuse/provenance/effects_import/**`; `artifacts/local/tasks/ART-19/`.

**Definition of done:**

1. After TH-19 IG-01 to IG-07 are closed (TH-19 AG-01), one effect scene per ART-15 specification and one per ART-16 tell is built with the process material and draw pass the specification names (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g4-particles.txt` lines 81 and 91).
2. ART-17 items 2 to 6 hold for every effect input.
3. A presentation-only effect replacement is staged as a new catalogue revision, and it keeps the gameplay content revision only after validation (TH-16 RE-04; TH-19 SI-04).

**Verification and evidence:** As ART-17. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each effect and tell against the specifications' mock frames. Not established: dense-fight readability or performance. Human-hands steps: Andrew records Godot execution authorization; Andrew's review.

**Boundary:** As ART-17. No shader source until DQ-02's amendment. No gameplay value.

**Iron Orchard enemy family.**

<a id="art-20"></a>

### ART-20: Make candidate concept and telegraph sheets for the Iron Orchard enemy family

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 (one Iron Orchard enemy family); TRACKING EV-0423 decisions 1 and 3; BIBLE.md lines 221, 225, 519, 521, 523, 525 and 731
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4, EP-01, EP-06, EP-09 and TP-15; `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` TH-06 AV-03 and AV-06
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-01, RR-02, RR-05, RR-06 and RR-07
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-10, AC-13, AC-14, AC-16, AC-19, AC-20 and AC-22; PD-01 VW-01, VW-03, VW-04 and VW-11; PD-01 CC-06, CC-07 and RL-05; PD-01 PF-01 to PF-15; PD-01 line 63
- `docs/ENEMY-ROSTER.md` as a candidate reference only

**Dependencies:** [PD-01](#pd-01), [FR-09](#fr-09). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-E10](#q-e10), [Q-P25](#q-p25), [Q-P33](#q-p33). The sheets support Andrew's Q-P25 selection and select nothing.

**Files touched:** `docs/art/production/iron_orchard_enemies/**` (FR-09, DQ-01); `artifacts/local/tasks/ART-20/`.

**Definition of done:**

1. A PD-01 VW-03 comparison of candidate families drawn from the orchard mechanisms the Bible names (BIBLE line 225), each with a PD-01 VW-04 turnaround of its working tool.
2. For each candidate attack, a panel set for prepare, commit, execute and recover (TH-03 EN-1 to EN-4) in which the working tool explains the threat before any danger shape exists (TH-03 EP-01), and a PD-01 VW-11 diagram captioned intended geometry with the height band drawn (TH-16 RR-02).
3. One overlapping-commitment panel shows two windups each keeping its own drawing (TH-16 RR-06), with admission limits captioned unset (Q-E10).
4. Sheets are made by image prompts plus paintover with provenance as ART-01 item 2 (TRACKING EV-0423 decision 3). Captions name every family, shape, band and window as a candidate, TH-03 TP-15 values stay unset under Q-P25, and no caption claims a generated image proves a timing, hitbox or physical property (PD-01 line 63).

**Verification and evidence:** Static: a paper check per sheet for view IDs, stage panels, prompt records and provenance fields. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-10, AC-13, AC-14, AC-16, AC-19, AC-20 and AC-22. Not established: a verified hitbox, timing or readability in play. Human-hands steps: Andrew's review; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept only. No roster, family, attack grammar or defensive grade chosen.

<a id="art-21"></a>

### ART-21: Make rough blockouts of the selected enemy family and check telegraph-pose silhouettes

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- ART-20's sheets; Andrew's recorded Q-P25 answer naming the family and its attack grammar; TRACKING EV-0423 decision 1; TRACKING EV-0447 decisions 1 and 2 (the orchard camera distance is the provisional distance for these enemies, rechecked natively)
- `src/orchard/scene.js` lines 410 and 412: the orchard chase camera's distance expression and the camera position derived from it
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4, EP-01 and TP-15; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-02, RR-05 and RR-06
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-04 and MP-23; `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-16 and VW-01

**Dependencies:** [ART-20](#art-20), [FR-09](#fr-09). **Blocking questions:** [Q-P25](#q-p25). Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-E10](#q-e10), [Q-P26](#q-p26) (the measured budget only), [Q-P32](#q-p32) (the provisional distance is Andrew's decision at TRACKING EV-0447 decision 2, not an answer to Q-P32's bounds; the native recheck belongs to ART-24).

**Files touched:** `source-assets/iron_orchard_enemies/blockout/**`; `source-assets/iron_orchard_enemies/provenance/blockout/**`; `docs/art/production/iron_orchard_enemies/review/**` (FR-09, DQ-01); `artifacts/local/tasks/ART-21/`.

**Definition of done:**

1. Rough blockouts for each family member the Q-P25 answer names, with a held pose for each of that member's attack stages (TH-03 EN-1 to EN-4).
2. Renders at the provisional distance record, per stage pose, whether the tool, danger footprint and escape stay visible (TH-16 RR-05) and whether the height band reads (TH-16 RR-02).
3. The check record states the provisional distance as the orchard expression at `src/orchard/scene.js` line 410 evaluated for each member, with every input to that expression named, and labels it provisional under TRACKING EV-0447 decision 2 (TH-02 MP-23 stays unset); the card writes no distance value of its own.
4. The check record ends with a lock or revise verdict recorded by Andrew, and names the native recheck at the native slice's camera as an open obligation carried by ART-24.

**Verification and evidence:** Human review record (PD-01 PF-12): Andrew's verdict. Static: every stage pose has renders at the recorded camera parameters. Not established: committed geometry, timing or play readability. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's verdict.

**Boundary:** No shape, band or window value. The provisional distance is Andrew's decision and not an answer to Q-P32.

<a id="art-22"></a>

### ART-22: Model, UV and texture the selected enemy family

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-21's locked blockouts; TRACKING EV-0423 decision 1; BIBLE.md lines 221, 225 and 645
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-05, AC-06, AC-10 and AC-19; PD-01 PF-01 to PF-15
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03

**Dependencies:** [ART-21](#art-21). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).

**Files touched:** `source-assets/iron_orchard_enemies/models/**`, `source-assets/iron_orchard_enemies/textures/**` and `source-assets/iron_orchard_enemies/provenance/model/**`; `artifacts/local/tasks/ART-22/`.

**Definition of done:**

1. Final models for each member in the Q-P25 answer, with the working tool's joints separated at the locked pivots.
2. UVs and textures place wear by use and stay distinct at gameplay distance (PD-01 AC-05, AC-06), within the Q-P26 and Q-E03 answers.
3. TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance and license fields; budget conformance by the Q-P26 method. Human review record (PD-01 PF-12): Andrew reviews turnaround and gameplay-distance renders for PD-01 AC-05, AC-06, AC-10 and AC-19. Not established: in-engine appearance or performance. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No rig, poses, runtime input or import. Re-size check: split per member if the Q-P25 answer names more members than one M card can review.

<a id="art-23"></a>

### ART-23: Rig the enemy family's working tools

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-22's masters; Andrew's recorded Q-P25 answer; TRACKING EV-0423 decision 1; TRACKING EV-0447 decision 3 (hybrid enemy motion: procedural locomotion and turning in Godot, hand-keyed Blender wind-up and attack clips; specifics open)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4 and EP-01
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8, 16 and 24; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` line 20
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-09

**Dependencies:** [ART-22](#art-22). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P42](#q-p42) (the hybrid approach is recorded at TRACKING EV-0447 decision 3; the per-member split is the parameter row in item 2).

**Files touched:** `source-assets/iron_orchard_enemies/models/**` (armatures in the masters); `source-assets/iron_orchard_enemies/provenance/rig/**`; `artifacts/local/tasks/ART-23/`.

**Definition of done:**

1. An armature for each member covering every attack stage the Q-P25 answer names (TH-03 EN-1 to EN-4), under the hybrid approach of TRACKING EV-0447 decision 3: bones for locomotion and turning are named for a Godot-side procedural driver, and working-tool joints carry controls for hand-keyed wind-up and attack clips.
2. Parameter row: which motions of each member are procedural and which are keyed, recovery included. Value unset, gated on the specifics Q-P42 leaves open; bones for a motion whose treatment is unset are recorded as provisional.
3. Weights use a method recorded under PD-01 PF-09 (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` line 20).
4. PD-01 PF-09 records the bone list, rest pose, units and axes within the Q-P26 and Q-E03 answers. A test export goes to receipts only.

**Verification and evidence:** Static: PD-01 PF-09 record against the Q-P25 attack list. Human review record (PD-01 PF-12): Andrew reviews pose-range renders of each tool. Not established: clip quality, committed geometry or playback. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No clips, attack values, runtime input or import. Re-size check as ART-22.

<a id="art-29"></a>

### ART-29: Key the enemy family's telegraph stage clips

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-23's rigs; Andrew's recorded Q-P25 answer; TRACKING EV-0423 decision 1; TRACKING EV-0447 decision 3 (hand-keyed Blender wind-up and attack clips; procedural locomotion and turning in Godot; specifics open)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4, EP-01, EP-09, AO-01 and TP-15; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-01, RR-07, RE-05 and RT-07
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` lines 8 and 40

**Dependencies:** [ART-21](#art-21), [ART-23](#art-23). **Blocking questions:** [Q-E01](#q-e01), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P42](#q-p42) (the hybrid approach is recorded at TRACKING EV-0447 decision 3; which stages are keyed per member is the parameter row in item 2).

**Files touched:** `source-assets/iron_orchard_enemies/models/**` (actions in the masters); `source-assets/iron_orchard_enemies/provenance/clips/**`; `artifacts/local/tasks/ART-29/`.

**Definition of done:**

1. One hand-keyed action per wind-up and attack stage per attack in the Q-P25 answer (TH-03 EN-1 to EN-3), each on its own NLA track (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40), under TRACKING EV-0447 decision 3; locomotion and turning are procedural in Godot and are not keyed here.
2. Parameter row: whether each member's recovery stage (TH-03 EN-4) and any other motion is keyed or procedural. Value unset, gated on the specifics Q-P42 leaves open.
3. Poses present the declared geometry and never define it (TH-16 RR-01, RE-05; TH-03 EP-01). Clip progress never advances a windup, active window or recovery (TH-03 AO-01; TH-16 RT-07).
4. Stage lengths are parameters under TH-03 TP-15 and Q-P25, with no value.

**Verification and evidence:** Static: PD-01 PF-09 per clip. Human review record (PD-01 PF-12): Andrew reviews captures of each stage at the ART-21 camera distance. Not established: alignment with committed geometry, timing or play readability. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No attack shape, band or window. Re-size check: split per member if the Q-P25 answer's clip list exceeds one M card.

<a id="art-24"></a>

### ART-24: Import and admit the enemy family through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row; ART-21's check record, ART-22 and ART-23 masters and ART-29 clip records; TRACKING EV-0423 decision 1; TRACKING EV-0447 decision 2 (native recheck of the provisional distance)

**Dependencies:** [NQ-01](#nq-01), [ART-21](#art-21), [ART-22](#art-22), [ART-23](#art-23), [ART-29](#art-29), [SC-02](#sc-02), [SC-04](#sc-04), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13).

**Files touched:** `native/content/iron_orchard_enemies/assets/models/**` (inputs with sidecars; the audio folder belongs to the sound import card); `native/content/iron_orchard_enemies/scenes/**`; `source-assets/iron_orchard_enemies/provenance/import/**`; `docs/art/production/iron_orchard_enemies/review/native/**` (the native recheck record; FR-09, DQ-01); `artifacts/local/tasks/ART-24/`.

**Definition of done:**

1. ART-17 items 1 to 6 hold for every member input.
2. Every stage clip is present after import under its recorded name (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` line 53).
3. Scenes reference the enemy definition by domain ID and carry no attack value (TH-19 AR-07; TH-16 RE-05).
4. ART-21's telegraph-pose check is repeated at the native slice's camera and recorded beside ART-21's provisional verdict; a disagreement returns the member to Andrew as a finding (TRACKING EV-0447 decision 2).

**Verification and evidence:** As ART-17, plus the imported clip-name check. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each stage and the native recheck. Not established: telegraph readability in play, which needs PD-03 AU-02 or a play session, or Q-P32's bounds. Human-hands steps: as ART-17, and Andrew's native recheck verdict.

**Boundary:** As ART-17. No encounter or enemy definition authoring. Re-size check as ART-22.

**Iron Orchard environment module set.**

<a id="art-25"></a>

### ART-25: Make the Iron Orchard landscape study and candidate module sheets

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 (one Iron Orchard environment module set); TRACKING EV-0423 decisions 1 and 3; BIBLE.md lines 215, 219, 221, 223 and 227; § 7 lines 655, 684, 685, 709 and 711
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-04, AC-11, AC-12, AC-17, AC-18 and AC-20; PD-01 VW-02, VW-08 and VW-09; PD-01 PE-04, PE-07 and RL-01; PD-01 PF-01 to PF-15; PD-01 line 63
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-04; `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-17

**Dependencies:** [PD-01](#pd-01), [FR-09](#fr-09). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P07](#q-p07), [Q-P22](#q-p22), [Q-P23](#q-p23), [Q-P24](#q-p24), [Q-P26](#q-p26), [Q-P33](#q-p33).

**Files touched:** `docs/art/production/iron_orchard_modules/**` (FR-09, DQ-01); `artifacts/local/tasks/ART-25/`.

**Definition of done:**

1. A PD-01 VW-08 landscape study of the Iron Orchard with the region's terrain language (tree rows, irrigation hardware, patched greenhouses, worn turning aprons, terraces, service ramps and greenhouse courts; BIBLE lines 221, 223), under one coherent lighting condition captioned as a candidate under Q-P33 (PD-01 AC-04).
2. A module sheet decomposing that language into candidate modules with a shared scale reference, captioned as candidates whose membership belongs to Q-P26.
3. Route-clearance callouts are captioned unset (TH-02 MP-17; Q-P22) and make no clearance claim (PD-01 PE-04).
4. Terrain consequences and generated-level assembly are captioned as proposals under Q-P24 and Q-P23.
5. Sheets are made by image prompts plus paintover with provenance as ART-01 item 2, and no caption claims a generated image proves clearance or a physical property (PD-01 line 63).

**Verification and evidence:** Static: paper check of view IDs, captions, prompt records and provenance fields. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-04, AC-11, AC-12, AC-17, AC-18 and AC-20. Not established: clearance, lighting behaviour in play (PD-01 PE-07) or wayfinding. Human-hands steps: Andrew's review; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept only. No module list, region scope, lighting rule or level technique chosen.

<a id="art-26"></a>

### ART-26: Make rough blockouts of the Iron Orchard module set

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- ART-25's sheets and Andrew's review record of them; the module set recorded at TRACKING EV-0447 decision 1; TRACKING EV-0423 decisions 1 and 2
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-17; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-04
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-12, AC-17 and PE-04; BIBLE.md lines 487 and 711

**Dependencies:** [ART-25](#art-25). **Blocking questions:** [Q-P23](#q-p23). Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P22](#q-p22), [Q-P24](#q-p24), [Q-P26](#q-p26) (the measured budget only), [Q-P33](#q-p33).

**Files touched:** `source-assets/iron_orchard_modules/blockout/**`; `source-assets/iron_orchard_modules/provenance/blockout/**`; `artifacts/local/tasks/ART-26/`.

**Definition of done:**

1. Rough blockouts for each candidate module ART-25's sheet names and Andrew's review record keeps, with connection points assembled as the Q-P23 answer allows.
2. Each passage is labelled with its intended route role; clearance is not measured here, because the fully grown clearance check is NQ-03's executed trial (TRACKING EV-0423 decision 2; PD-01 PE-04).
3. Provenance records carry PD-01 PF-01 to PF-13 and PF-15, with the Blender version pinned in PD-01 PF-06.

**Verification and evidence:** Static: provenance records and the route-role labels. Human review record (PD-01 PF-12): Andrew reviews blockout renders for PD-01 AC-12 and AC-17. Not established: clearance, collision behaviour or play. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** Rough blockouts only. No collision geometry (DQ-05), no clearance measurement, and no envelope or clearance value.

<a id="art-27"></a>

### ART-27: Model, UV and texture the Iron Orchard module set

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-26's blockouts; TRACKING EV-0423 decision 1; BIBLE.md lines 221, 223, 699, 701 and 711
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-05, AC-06, AC-11 and AC-12; PD-01 PF-01 to PF-15
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03

**Dependencies:** [ART-26](#art-26). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P33](#q-p33).

**Files touched:** `source-assets/iron_orchard_modules/models/**`, `source-assets/iron_orchard_modules/textures/**` and `source-assets/iron_orchard_modules/provenance/model/**`; `artifacts/local/tasks/ART-27/`.

**Definition of done:**

1. Final modules that keep each blockout passage's route role and connection points.
2. UVs and textures within the Q-P26 and Q-E03 answers, with vegetation bands related to rock and slope (PD-01 AC-11; BIBLE line 711).
3. TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance and license fields. Human review record (PD-01 PF-12): Andrew reviews PD-01 VW-02 and VW-08 renders for PD-01 AC-05, AC-06, AC-11 and AC-12. Not established: lighting behaviour, performance or clearance in play. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No collision geometry, runtime input or import.

<a id="art-28"></a>

### ART-28: Import and admit the Iron Orchard module set through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row; ART-27 masters; `docs/tech/schemas/SC-05.md` (admitted; level module definitions); TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [ART-27](#art-27), [SC-05](#sc-05), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P23](#q-p23), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13).

**Files touched:** `native/content/iron_orchard_modules/assets/**`; `native/content/iron_orchard_modules/scenes/**`; `source-assets/iron_orchard_modules/provenance/import/**`; `artifacts/local/tasks/ART-28/`.

**Definition of done:**

1. ART-17 items 1 to 6 hold for every module input.
2. Module scenes reference level module definitions by domain ID and carry no second gameplay value (TH-19 AR-07).

**Verification and evidence:** As ART-17. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each module. Not established: executed clearance, which is NQ-03's, lighting behaviour or performance. Human-hands steps: as ART-17.

**Boundary:** As ART-17. No level definition, route or generation rule.


**Sound production.**

Every sound card waits on TH-17 for cue ownership and mix, on PD-03's questions, and on the playable native build (TRACKING EV-0423 decision 1; BIBLE line 747). No card here produces a listening result that stands in for PD-03's audition matrix, which needs that build (PD-03 AU-01 to AU-06). Sound cards do not block on Q-P26: BACKLOG Q-P26's affected work names models, textures, rigs, attachment sizing, material and lighting work and import checks, not audio, and Q-P31 is the sound batch's manifest gate (a recorded deviation from attempt A2's required change 5).

<a id="snd-01"></a>

### SND-01: Record or synthesize Fuse's directed weapon cues

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-07 and SE-08; PD-03 SI-01 to SI-04, SI-11 and SI-12; PD-03 UD-03 and UD-06; PD-03 SP-06, SP-07 and SP-14; PD-03 BP-01 to BP-07 as non-precedent
- TRACKING EV-0411 and FR-07's accepted AM-H8-003 (weapon actions reference ability definitions, HF-06a row N-021); TRACKING EV-0423 decision 1
- BIBLE.md lines 745, 747, 776 and 789; `docs/DISCOVERY.md` line 211 (Audacity as a free local candidate)
- `docs/project/ASSETS.md` line 17; `docs/tech/sections/TH-19-asset-import-export.md` TH-19 PV-04, NO-02 and NO-03, and Seam 2 at line 296
- TH-17's admitted section (cue ownership and mix)

**Dependencies:** [FR-07](#fr-07), [PD-03](#pd-03), [TH-17](#th-17), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-P06](#q-p06), [Q-P28](#q-p28).

**Files touched:** `source-assets/fuse/audio/weapon/**` (editable masters, synthesis recipes and provenance with license evidence; HF-01 line 31 with FR-09's Audio rows, DQ-01); `artifacts/local/tasks/SND-01/`.

**Definition of done:**

1. Masters for PD-03 SE-07's preparation, contact and reset tail and for PD-03 SE-08's directed-cast identity for Fuse (BIBLE line 776), each keyed to the published result of the weapon's ability definition or an attack it produces (AM-H8-003 through FR-07).
2. The source method follows the Q-P31 answer, recorded or synthesized with a free local tool (`docs/DISCOVERY.md` line 211), with the tool version pinned at first use. Provenance records creator, license evidence and notice obligation (ASSETS.md line 17; TH-19 NO-02, NO-03). A recording names its physical source. Nothing is downloaded unless the Q-P31 answer allows it and license evidence is recorded.
3. No cue is aligned to a beat, and none carries timing that could lengthen a window (PD-03 SI-02, SI-03). Durations and tails are recorded against the PD-03 SP-06 answer, with no value in the card.
4. Variation for repeated details follows the PD-03 SP-07 answer, with no count in the card.
5. No runtime input is written. Export belongs to SND-05.

**Verification and evidence:** Static: provenance and license fields per master. Human review record: Andrew's listening review of the masters in isolation, recorded as one listener's opinion and explicitly not PD-03 AU-01. Not established: mix or priority in play (PD-03 SI-01), fatigue (PD-03 FT-01), playback hardware or human feel. Human-hands steps: Andrew installs Audacity or the chosen tool and records execution authorization; Andrew's listening review; any physical recording.

**Boundary:** No bus, voice or mix decision (TH-17). No music (Q-P17). No voice or barks (PD-03 UD-07). No paid tool or generation service.

<a id="snd-02"></a>

### SND-02: Record or synthesize Fuse's field and miscast cues

**Card revision:** 1 · **Owner:** Audio · **Size:** S · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-08, SI-08, SI-11, UD-04 and SP-12; TRACKING EV-0322
- Every SND-01 source row

**Dependencies:** [FR-07](#fr-07), [PD-03](#pd-03), [SND-01](#snd-01), [TH-17](#th-17), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-P13](#q-p13), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06).

**Files touched:** `source-assets/fuse/audio/field_miscast/**`; `artifacts/local/tasks/SND-02/`.

**Definition of done:**

1. Masters that tell automatic field activity and each miscast the Q-P13 answer allows apart from SND-01's directed cast (PD-03 SE-08), keyed to the main hero skill's ability definition or the miscast outcome it publishes.
2. No miscast cue implies a danger shape other than the previewed one (PD-03 SI-08), and no cosmetic variation rerolls an outcome (PD-03 SI-11).
3. Provenance, timing and variation as SND-01 items 2 to 4.

**Verification and evidence:** As SND-01. Not established: whether players hear a miscast before harm, which needs a human session. Human-hands steps: as SND-01.

**Boundary:** As SND-01. No miscast rule or warning policy chosen.

<a id="snd-03"></a>

### SND-03: Record or synthesize Fuse's ultimate cue

**Card revision:** 1 · **Owner:** Audio · **Size:** S · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-10, SI-01, SI-14, UD-05 and SP-11; BIBLE.md lines 745 and 791
- Every SND-01 source row

**Dependencies:** [FR-07](#fr-07), [PD-03](#pd-03), [SND-01](#snd-01), [TH-17](#th-17), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-P17](#q-p17), [Q-P20](#q-p20), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06).

**Files touched:** `source-assets/fuse/audio/ultimate/**`; `artifacts/local/tasks/SND-03/`.

**Definition of done:**

1. Masters for anticipation and main consequence of the ultimate the Q-P20 answer defines (PD-03 SE-10), keyed to the ultimate's ability definition.
2. The consequence earns an added layer, not a rising master level (PD-03 SI-14), and leaves threats audible first (PD-03 SI-01). Any music interaction follows the Q-P17 answer.
3. Provenance, timing and variation as SND-01 items 2 to 4.

**Verification and evidence:** As SND-01. Not established: PD-03 AU-05's exceptional-build session. Human-hands steps: as SND-01.

**Boundary:** As SND-01. No charge or cadence value.

<a id="snd-04"></a>

### SND-04: Record or synthesize the enemy family's warning cues

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-11, SE-12 and SE-13; PD-03 SI-02, SI-03, SI-05 and SI-10; PD-03 UD-10 and UD-11; PD-03 BP-02 (no browser precedent for warnings)
- BIBLE.md lines 777 and 789; ART-29's stage clips, whose working mechanism each cue voices
- Every SND-01 source row

**Dependencies:** [ART-29](#art-29), [PD-03](#pd-03), [TH-17](#th-17), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-P25](#q-p25), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-P30](#q-p30).

**Files touched:** `source-assets/iron_orchard_enemies/audio/warnings/**`; `artifacts/local/tasks/SND-04/`.

**Definition of done:**

1. Masters for preparation, commitment and release, and recovery for each attack in the Q-P25 answer (PD-03 SE-11 to SE-13), voicing that member's working mechanism (BIBLE line 777).
2. No warning is deferred, quantized or aligned to a beat (PD-03 SI-02). Each is paired with visible information, so sound disabled removes no needed warning (PD-03 SI-05).
3. An arrival cue is made only if the Q-P30 answer makes one required (PD-03 UD-10).
4. Provenance, timing and variation as SND-01 items 2 to 4.

**Verification and evidence:** As SND-01. Not established: PD-03 AU-02 and AU-04, the sound-disabled readability sessions, or dense-fight audibility (PD-03 AU-03). Human-hands steps: as SND-01.

**Boundary:** As SND-01. No attack timing.

<a id="snd-05"></a>

### SND-05: Import and admit the batch's sound inputs through TH-19

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/tech/sections/TH-19-asset-import-export.md` Seam 2 at line 296, TH-19 OC-02, OC-03, IS-01, SI-01, EM-02, NO-02, NO-04, AG-01 to AG-09, IG-01 to IG-07 and AQ-18
- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SI-04 and SI-12; `docs/tech/sections/HF-01-production-conventions.md` lines 30 and 72
- SND-01 to SND-04 masters and records; TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [SND-01](#snd-01), [SND-02](#snd-02), [SND-03](#snd-03), [SND-04](#snd-04), [SC-07](#sc-07), [TH-17](#th-17), [TH-29](#th-29), [TH-31](#th-31), [FR-09](#fr-09). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P31](#q-p31). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06).

**Files touched:** `native/content/fuse/assets/audio/**` and `native/content/iron_orchard_enemies/assets/audio/**` (inputs with `.import` sidecars; FR-09's Audio rows, DQ-01); `source-assets/fuse/audio/import/**` and `source-assets/iron_orchard_enemies/audio/import/**` (recipes and provenance links); `artifacts/local/tasks/SND-05/`.

**Definition of done:**

1. TH-19 IG-01 to IG-07 are closed with named evidence before staging (TH-19 AG-01).
2. Each audio input is exported from its master by a recorded recipe, with its sidecar committed and reviewed as bytes (TH-19 IS-01, SI-01).
3. Every manifest entry reaches its provenance and notice obligation (TH-19 EM-02, NO-04).
4. No cue fact becomes durable (PD-03 SI-04).

**Verification and evidence:** Automated native: import and validation of a staged copy by the handoff's commands. Static: sidecars tracked, provenance complete. Human review record: Andrew's listening review of the imported cues, recorded as one listener's opinion. Not established: PD-03 AU-01 to AU-06, PD-03 FT-01 and FT-02, playback hardware or the mix. Human-hands steps: Andrew records Godot execution authorization; Andrew's listening review.

**Boundary:** As ART-17. No cue definitions, which belong to SC-07. No bus or mix. Re-size check: split by owner unit if the Q-P31 answer's batch exceeds one M card.
## Jev Lab cards (25 September 2026)

Authorized at EV-0484. The program plan is retained at [artifacts/jev-lab-2026-09-25/plan.md](artifacts/jev-lab-2026-09-25/plan.md); its architecture sections are the design source for every JL card. Every JL card runs in the heavy lane: worktree from `scripts/new-worktree.sh`, packet, attempt record and event before dispatch, `check:scope` receipts under `artifacts/local/tasks/JL-NN/`, a fresh independent reviewer and serial coordinator integration. No JL card mixes `tools/` or `scripts/` with `sketches/`. Automated play is never a feel verdict. Cards are added one wave at a time so each wave's retro can change the next wave's cards.

<a id="jl-00"></a>

### JL-00: Audit the Opus 5 tooling commits and EV-0483

**Card revision:** 1 · **Owner:** Coordinator with an independent reviewer · **Size:** S · **Lane:** Jev Lab (audit)

**Source and inputs:**

- Commits 41ab9f6, 7a3c159, 9c067de and 9a7f7ae; TRACKING EV-0483
- The plan's "Audit of the Opus 5 work" table, findings A1 to A10, from a prior read-only pass
- `tools/jev-player/`, `scripts/play.mjs`, ORCHESTRATOR (tooling class and light play lane)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `artifacts/jev-lab-2026-09-25/audit/README.md`; TRACKING (coordinator only, EV-0485).

**Definition of done:**

1. A claims ledger marks every factual or performance claim in the four commit messages, the jev-player README and EV-0483 as verified, unverified or retracted, with file:line evidence.
2. The label-edit history of `tools/jev-player/corpus.json` is listed case by case from `git log -p`.
3. Each of A1 to A10 is confirmed, revised or rejected with evidence; new findings are numbered from A11.
4. EV-0485 records the correction of EV-0483's timestamp, any retraction the audit confirms and the reconciliation of the commits that have no event.

**Verification and evidence:** The reviewer's report retained verbatim; the coordinator spot-checks at least three cited lines; `npm run check:docs`.

**Boundary:** No code change. Fixes land in the cards that own each file (JL-03, JL-06 and later).

<a id="jl-01"></a>

### JL-01: Run record `scrapkeep-run/1` and its index

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Run record `scrapkeep-run/1`"
- `tools/agent-player/run.py:88-99` (exclusive output directory claimed with `x`), `tools/agent-player/evidence.py:11-36` (hash provenance, NDJSON)

**Dependencies:** [JL-00](#jl-00). **Blocking questions:** None.

**Files touched:** `scripts/lab/record.mjs`; `tests/lab-record.test.js`; `package.json` (the `test` script's file list only, if needed); `artifacts/local/tasks/JL-01/`.

**Definition of done:**

1. `createRun({type, label})` claims an exclusive `artifacts/local/runs/<ts>-<type>-<label>-<uuid8>/` by opening `run-owner.json` with the `wx` flag; a second claim of the same directory fails.
2. `run.json` carries `schema: "scrapkeep-run/1"`, `type`, `result`, `provenance` (git head, branch, dirty flag, source hashes at start and end, tool versions, an `instrument` block, and Jev model, call, token and cache counts), `config`, `kpis` and `kris` as `{value, n, ci}`, `findings` each with a repro command, and `limits`. A start/end source-hash mismatch forces `result: "inconclusive"`.
3. Metric ids are validated against an injected registry; an unknown id throws. (The registry itself is JL-02.)
4. `index.ndjson` is append-only, and `rebuildIndex()` reproduces it byte-identically from the run directories.
5. Node built-ins only; no dependency or lockfile change.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints; receipts under `artifacts/local/tasks/JL-01/`.

**Boundary:** No metric definitions, no Godot code, no gate logic.

<a id="jl-02"></a>

### JL-02: Metric registry, status table and statistics

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Registry", the KPI/KRI layer table and "Gate → Statistics"
- `tools/agent-player/report.py` (nearest-rank percentiles)
- `~/.config/omarchy/themes/neon-noir/colors.toml` (palette)

**Dependencies:** [JL-00](#jl-00). **Blocking questions:** None.

**Files touched:** `scripts/lab/metrics/{index,status,core,program,human,tdd,ball-lab}.mjs`; `scripts/lab/stats.mjs`; `tests/lab-metrics.test.js`; `package.json` (the `test` script's file list only, if needed); `artifacts/local/tasks/JL-02/`.

**Definition of done:**

1. One `STATUS` table owns each status's colour, glyph, ANSI code, gate effect and exit code: green `#7fd9a0` ●, amber `#ffd166` ▲, red `#ef476f` ■, insufficient `#5e7a82` ○. A test fails if a hex colour or status word appears elsewhere under `scripts/lab/`.
2. Every metric id in the plan's layer table for the mechanics (ball-lab), agent, stability, pipeline, TDD, program and human layers is defined once as `{id, layer, kind, sentinel, thresholds, min_n, says}`; `index.mjs` merges the layers and rejects a duplicate id.
3. A metric below its `min_n` evaluates to insufficient, never green; a sentinel goes red on one occurrence.
4. `stats.mjs` gives Wilson intervals, Newcombe differences and nearest-rank p50/p95. Tests check them against published reference values and against `report.py` on a shared fixture.
5. Node built-ins only.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints; receipts under `artifacts/local/tasks/JL-02/`.

**Boundary:** Cable Bench and Spillway Drop metrics belong to JL-26 and JL-27. No gate CLI (JL-12), no output formatting beyond `says`.

<a id="jl-03"></a>

### JL-03: Versioned question sets and the jev-player retractions

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 1 "Question sets are versioned files" and "Instrument epoch"; audit findings A1, A2, A6 and A10 as dispositioned by JL-00
- `tools/jev-player/{decide.mjs,score.mjs,README.md,corpus.json,tests/gate.test.js}`

**Dependencies:** [JL-00](#jl-00). **Blocking questions:** None.

**Files touched:** `tools/jev-player/questions/{q1-original.json,INDEX.json}`; `tools/jev-player/decide.mjs`; `tools/jev-player/score.mjs`; `tools/jev-player/README.md`; `tools/jev-player/tests/`; `artifacts/local/tasks/JL-03/`.

**Definition of done:**

1. `questions/q1-original.json` holds today's intent, danger, greedy and rationale wording verbatim with `status: "retracted-leading"`; `INDEX.json` pins its sha256, and a test fails when a published question file's bytes change.
2. `decide.mjs` loads a question set by version and exports `GATE_VERSION` and `instrumentIdentity()` returning `{questions_sha, model, confidence_floor, gate_version}`; the existing gate tests pass unchanged under q1.
3. `score.mjs` reports the authored and blind corpora separately and never merges them; only the blind score is marked as gating.
4. The README retracts the sweep conclusion, calls `CONFIDENCE_FLOOR` provisional, and is rewritten plainly.
5. `score.mjs` records `rawIntent` and `lowConfidence` for every case and reports floor-induced failures separately from model misses (audit A13).
6. Offline tests cover the `start_exit` precondition, the all-gated fallback, the confidence floor, and a snapshot of the built questions so prompt drift fails `npm test` (A14).
7. The blanket "already rolling over it" prefix is removed from `take_cache` options where the case states a distance (A17, at least `low-hp-chaser`); labels are unchanged. The README says the `danger` and `greedy` answers are recorded but drive no decision (A18).
8. No test makes a live Jev call.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints; receipts under `artifacts/local/tasks/JL-03/`.

**Boundary:** No new question wording (q2 is JL-18), no preflight (JL-15), no blind corpus content (JL-04).

<a id="jl-04"></a>

### JL-04: Blind corpus, labelled in isolation

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 1 "Blind corpus"
- Permitted inputs only: the READMEs and `src/tuning.gd` of Cable Bench (`proto/cable-bench` at 29dcbcf, `sketches/cable-bench/`), Spillway Drop (`proto/spillway-drop` at af89c89, `sketches/spillway-drop/`) and ball-lab (`sketches/ball-lab/`); `BIBLE.md`; and the schema-only description of a case supplied in the packet

**Dependencies:** [JL-00](#jl-00). **Blocking questions:** None.

**Files touched:** `tools/jev-player/corpus-blind.json`; `tools/jev-player/corpus-blind.PROVENANCE.md`; `artifacts/local/tasks/JL-04/`.

**Definition of done:**

1. At least 20 cases in the packet's schema, each with an expected choice, a severity weight and `{labeller, date, inputs_seen, prompt_epoch}`; at least four are dominance cases where one option is plainly better regardless of wording.
2. The labeller read no forbidden input: `tools/jev-player/decide.mjs`, `README.md`, `corpus.json`, `sweep.mjs`, `score.mjs`, any Jev output, the plan or the audit. The coordinator confirms this from the delegate's tool log.
3. The provenance file states the inputs seen, the labelling rule for each case family and the rule that a case the prompt author sees is burned and moves to the authored set.

**Verification and evidence:** JSON parses against the packet schema; the coordinator's tool-log check; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No scoring, no Jev calls, no prompt wording. Blind results reach the prompt author only as aggregates.

<a id="jl-05"></a>

### JL-05: Godot–Node protocol v1, its document and fixtures

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 2 "Protocol v1", "Timing" and "Arms"; TADR-005 (no sockets)
- `tools/jev-player/corpus.json` state and option shape (the `jev` block is pre-quantised to it); JL-01's `scrapkeep-run/1` for the run-level fields the harness will later write

**Dependencies:** [JL-01](#jl-01), [JL-03](#jl-03). **Blocking questions:** None.

**Files touched:** `tools/jev-player/protocol/PROTOCOL.md`; `tools/jev-player/protocol/protocol.mjs`; `tools/jev-player/protocol/fixtures/`; `tools/jev-player/tests/protocol.test.js`; `artifacts/local/tasks/JL-05/`.

**Definition of done:**

1. `PROTOCOL.md` specifies, for one `<io>` directory per trial: every file (`hello.json`, `state-NNNNNN.json`, `intent-NNNNNN.json`, `error.json`, `abort.json`, `done.json`, `events.ndjson`), its single writer, tmp-then-rename writes, the tick schedule (snapshot every D ticks, hold the previous intent for k ticks, block until the intent arrives), the timeouts and exit codes (Godot 30 s → `error{intent_timeout}`, exit 5; Node watchdog `max(30 s, 20 × median step)` → `stall`; no `done.json` → `crash`) and the `forced` single-option rule.
2. `protocol.mjs` exports a validator per message type and `writeAtomic()`; an `intent` for the jev arm without `meta.questions_sha` is invalid.
3. Canonical fixtures cover every message type with at least one valid and one invalid example each; the validators accept every valid fixture and reject every invalid one.
4. No Godot code (JL-09 copies the fixtures into the sketch), no harness (JL-11), no live Jev call.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Protocol and fixtures only.

<a id="jl-06"></a>

### JL-06: `play.mjs` writes run records, measured timing, the shot fix and run-record hardening

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- `scripts/play.mjs`; `scripts/lab/record.mjs` (JL-01) and `scripts/lab/metrics/` (JL-02)
- Audit A5 (computed timings), A8 (shot window and `/tmp`), A9 (unexplained flake), A16 (CONTRIBUTING lacks `watch`, `--jobs`, `jev:score`), A19 (untracked `~/.local/bin/scrapkeep`)
- JL-01 review notes (EV-0489) and JL-02's `python3` test dependency (EV-0491)

**Dependencies:** [JL-01](#jl-01), [JL-02](#jl-02). **Blocking questions:** None.

**Files touched:** `scripts/play.mjs`; `scripts/lab/record.mjs`; `scripts/bin/scrapkeep` (new, the tracked wrapper); `tests/play.test.js`; `tests/lab-record.test.js`; `CONTRIBUTING.md` (the sketch and lab rows only); `artifacts/local/tasks/JL-06/`.

**Definition of done:**

1. `scrapkeep test` writes one `scrapkeep-run/1` record of type `suite` with `suite_pass`, `suite_wall_s`, `engine_crash` and per-test outcomes; `--repeat N` runs the suite N times in one record and reports `flake_rate` as the fraction of tests whose outcome disagrees across repeats.
2. A 20-run soak and a serial-versus-concurrent timing run are executed and retained under `artifacts/local/runs/`; the numbers in CONTRIBUTING come from those records, with the command that produced them.
3. `scrapkeep shot` writes to `artifacts/local/shots/` and opens its window through `claude-open` on workspace 10 when present, headless otherwise; it never writes to `/tmp`.
4. `record.mjs`: `seq` is `max(seq) + 1` of parsed index lines and a missing trailing newline is repaired before appending; `finished` is set only after the locked write; an injected `uuid` must match `/^[0-9a-f]{8,}$/`; `rebuildIndex()` on a missing root returns an empty index; per-file source hashes move to `sources.json` beside `run.json`, and `run.json` keeps the digests and the `changed` list.
5. The `scrapkeep` wrapper is tracked at `scripts/bin/scrapkeep`; CONTRIBUTING documents `watch`, `--jobs`, `--repeat`, `jev:score` and the `python3` test prerequisite.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run sketch:smoke`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No Godot or sketch change; no Jev call; no gate logic.

<a id="jl-07"></a>

### JL-07: Human verdict index with backfill

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Human verdict index"; `docs/playtests/PLAYTEST-LOG.md` entries 1 and 2

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/playtests/verdicts.ndjson`; `scripts/lab/verdicts.mjs`; `tests/lab-verdicts.test.js`; `artifacts/local/tasks/JL-07/`.

**Definition of done:**

1. One NDJSON line per PLAYTEST-LOG entry: `{entry, build_sha, anchor, quote, tags}`, where `quote` is Andrew's verdict copied verbatim, `anchor` links the log entry and `tags` is an empty array (JL-20 fills it).
2. `verdicts.mjs` validates the file and fails when a `quote` is not found verbatim in PLAYTEST-LOG or a `build_sha` is not a commit.
3. PLAYTEST-LOG stays the prose source and is unchanged.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No tagging, no Jev call, no new verdicts.

<a id="jl-08"></a>

### JL-08: Program-layer collector

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 program-layer row and "Self-feedback after every wave"
- `~/.claude/state/delegates.tsv` (actual model, pinned effort, token fields, verdict per delegate); TRACKING events; `git log`
- EV-0492, the event-time correction this collector must be able to detect

**Dependencies:** [JL-01](#jl-01), [JL-02](#jl-02). **Blocking questions:** None.

**Files touched:** `scripts/lab/program.mjs`; `artifacts/jev-lab-2026-09-25/agent-map.tsv` (new, coordinator-maintained map from delegate id to card and role); `tests/lab-program.test.js`; `artifacts/local/tasks/JL-08/`.

**Definition of done:**

1. `node scripts/lab/program.mjs` writes a `scrapkeep-run/1` record of type `program` with `first_pass_review`, `cycle_time_h`, `tokens_per_card`, `rework_per_card`, `blocked_cards`, `model_substitution`, `untracked_commits` and `event_time_skew`.
2. `tokens_per_card` reports `input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens` and `output_tokens` as separate fields, deduplicated by delegate id; they are never summed into one "input" figure.
3. `model_substitution` counts delegates whose actual model differs from the pin their agent definition or map row names; `untracked_commits` counts commits on the program branch after EV-0484 that no event names by SHA; `event_time_skew` is the largest gap in hours between an event's stated time and the UTC commit time of the commit that added its row (`git blame` on TRACKING).
4. Tests use fixture TSV, fixture TRACKING rows and a throwaway git repo; one fixture reproduces the EV-0486 to EV-0491 skew and must measure it.

**Verification and evidence:** `npm test`; `npm run verify`; a live run on the coordinator branch retained under `artifacts/local/runs/`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Read-only over the ledger, TRACKING and git; writes only its run record.

<a id="jl-05b"></a>

### JL-05b: Protocol v1 document and fixture patch before the Godot port

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- The JL-05 review, `artifacts/jev-lab-2026-09-25/reviews/JL-05.md` notes 3, 5, 6, 7, 8 and 10 (EV-0499)
- `tools/jev-player/protocol/{PROTOCOL.md,protocol.mjs,fixtures/}`

**Dependencies:** [JL-05](#jl-05). **Blocking questions:** None.

**Files touched:** `tools/jev-player/protocol/PROTOCOL.md`; `tools/jev-player/protocol/protocol.mjs`; `tools/jev-player/protocol/fixtures/`; `tools/jev-player/tests/protocol.test.js`; `artifacts/local/tasks/JL-05b/`.

**Definition of done:**

1. PROTOCOL.md states every rule `protocol.mjs` enforces: the grid tolerance, LF line endings and the trailing newline of `events.ndjson` (an empty file is valid), positive `tick_hz`, `snapshot_every` and `intent_timeout_s`, the closed set of file names in `<io>`, that `sim` is unchecked and never hashed, that `stage.time_s` is `floor(tick / tick_hz)`, that the verdict key is computed by Node only, and that the watchdog starts after Node's last intent.
2. The intent-before-trace order at an equal tick is either enforced by `validateEvents` with a fixture, or stated as a Godot write-order rule that is not validated; `validateTrial` rejects a state `seq > 0` with no intent for `seq - 1`.
3. Trial-level invalid fixtures exist and fail for exactly their stated reason: wrong protocol string, intent for an unsnapshotted seq, non-contiguous snapshots, `done.snapshots` mismatch, `trace_hash` mismatch, done beside error, aborted without `abort.json`, `intent_timeout` tick mismatch.
4. Fixture tests assert the exact error path list (`deepEqual`), not `some`.
5. No change to message shapes: the protocol string stays `scrapkeep-jev/1`.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No Godot code, no harness, no new message field.

<a id="jl-09"></a>

### JL-09: Godot protocol I/O for the ball lab

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- `tools/jev-player/protocol/PROTOCOL.md` and fixtures after JL-05b; plan § 2 "Protocol v1" and "Runner"
- `sketches/ball-lab/src/intent.gd` (`Intent.Source`), `tests/mode_check.gd:10-24`

**Dependencies:** [JL-05b](#jl-05b). **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/jev_io.gd`; `sketches/ball-lab/src/jev/fixtures/` (byte-identical copy); `sketches/ball-lab/tests/jev_io_test.gd`; `tests/jev-fixtures.test.js` (the drift test); `artifacts/local/tasks/JL-09/`.

**Definition of done:**

1. `jev_io.gd` writes `hello`, `state-NNNNNN`, `error` and `done` files tmp-then-rename, appends `events.ndjson.tmp` and renames it before `done` or `error`, and reads and validates `intent-NNNNNN` and `abort` files by the rules PROTOCOL.md states.
2. `jev_io_test.gd` (headless) accepts every valid fixture and rejects every invalid one with the same field path the Node validator reports.
3. `tests/jev-fixtures.test.js` fails when the sketch copy of the fixtures differs byte for byte from `tools/jev-player/protocol/fixtures/`.
4. No gameplay file changes; `npm run sketch:smoke` passes.

**Verification and evidence:** `npm run sketch:smoke`; `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No state synthesis (JL-10), no runner or steering (JL-13, JL-17).

<a id="jl-10"></a>

### JL-10: Read-only state synthesis and ball-lab scenarios

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 2 "Ball-lab state is synthesised read-only" and "Determinism"; plan § 3 scenario list
- `sketches/ball-lab/src/{lab,player_ball,field,ball_state,ball_rules,enemy,speed_tier}.gd`; the `shockwave` signal on `player_ball.gd`

**Dependencies:** [JL-05](#jl-05). **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/jev_state.gd`; `sketches/ball-lab/src/jev/scenarios.gd`; `sketches/ball-lab/tests/jev_state_test.gd`; `artifacts/local/tasks/JL-10/`.

**Definition of done:**

1. `jev_state.gd` builds the `jev` block (quantised to the protocol grid) and the `sim` block from a running lab: the nearest three enemies within 60 m, `air_jump_available`, the speed tier and knocks detected by a second listener on `shockwave` (0.6 stomp, 1.0 ram). It reads only; it never writes to gameplay nodes.
2. With the exporter installed and a fixed scripted input sequence, positions and velocities over 900 physics ticks are identical to the same run without it, for both physics modes; the test fails on any difference.
3. `scenarios.gd` defines `downhill-run`, `run-to-pad`, `bench-climb`, `kicker-gap` (a speed parameter from 14 to 28 m/s), `dummy-knock`, `pillar-weave` and `soak`, each with spawn, objective and time limit taken from `field.gd` coordinates, and a success predicate.
4. `npm run sketch:smoke` passes; no gameplay file changes.

**Verification and evidence:** `npm run sketch:smoke`; `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No protocol I/O (JL-09), no steering (JL-13).

<a id="jl-11"></a>

### JL-11: Harness and arms against a fake Godot

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 2 "Arms", "Timing"; PROTOCOL.md after JL-05b; `scripts/lab/record.mjs`; JL-05 review notes 2 and 9 (EV-0499)
- `tools/jev-player/decide.mjs` (the gate and its `push_objective` fallback)

**Dependencies:** [JL-05b](#jl-05b), [JL-06](#jl-06). **Blocking questions:** None.

**Files touched:** `scripts/lab/harness.mjs`; `scripts/lab/arms.mjs`; `scripts/lab/fake-godot.mjs`; `tools/jev-player/decide.mjs` (export the fallback as `offeredOptions`; no behaviour change); `tools/jev-player/protocol/protocol.mjs` (import it instead of re-implementing); `tests/lab-harness.test.js`; `artifacts/local/tasks/JL-11/`.

**Definition of done:**

1. `harness.mjs` runs N trials of a scenario for the `random` (seeded) and `scripted` arms against `fake-godot.mjs`, one `<io>` directory per trial, validates every file with `validateTrial`, and writes one `scrapkeep-run/1` record per batch with per-trial outcomes and `trial_abort_rate`.
2. The Node watchdog (`max(30 s, 20 × median step)`) classifies a stalled fake as `stall` and kills it; an exit with no `done.json` is `crash`; a Node-side invalid state writes `abort` with a documented reason.
3. A single offered option is answered `forced` with no arm call. The `jev` arm is a stub that throws (JL-14 builds it); no live Jev call.
4. `decide.mjs` exports the fallback and `protocol.mjs` imports it; `tests/gate.test.js` stays byte-identical and passes.
5. A per-batch call cap exists in the harness config for the future jev arm (the runaway guard named at EV-0484).

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No real Godot process (JL-17), no jev arm (JL-14), no gate (JL-12).

<a id="jl-12"></a>

### JL-12: Gate, pinning and threshold repairs

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Gate"; `scripts/lab/{record,stats}.mjs`, `scripts/lab/metrics/`
- Carried notes: EV-0489 (source mismatch downgrades `invalid`), EV-0491 (threshold-less KRIs render green only; `lever_effect` epoch rule; gate names no status), EV-0498 (1 h `event_time_skew` warn missed a 0.58 h skew)

**Dependencies:** [JL-01](#jl-01), [JL-02](#jl-02). **Blocking questions:** None.

**Files touched:** `scripts/lab/gate.mjs`; `scripts/lab/record.mjs` (sticky `invalid`); `scripts/lab/metrics/{status,core,program,ball-lab}.mjs`; `tests/lab-gate.test.js`; `tests/lab-metrics.test.js`; `artifacts/local/tasks/JL-12/`.

**Definition of done:**

1. `gate.mjs --pin <run_id> --as <name>` copies a run to `artifacts/jev-lab-YYYY-MM-DD/pins/<name>/` and refuses an unpinnable run; `gate.mjs <candidate> --against <pin>` compares by Wilson (rates) and Newcombe (differences) at tolerance 0.10, treats a straddling interval as inconclusive, and exits 0 pass, 1 red KRI or conclusive regression, 2 usage, 3 inconclusive (too few samples, stale baseline, dirty tree), 4 instrument invalid.
2. A source mismatch keeps `invalid` and records the original result in a structured field.
3. The nine KRIs without plan thresholds render as a distinct tracked-without-threshold state, never as a pass colour, and the gate ignores them; `lever_effect` is insufficient until its epoch has passed controls; `event_time_skew` warns above 0.25 h and fails above 1 h.
4. The gate branches only on `STATUS` entries' `gate` and `exit` fields and names no status word.
5. Tests cover every exit code with fixture records.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No preflight controls (JL-15) or epoch creation; no dashboard.

<a id="jl-13"></a>

### JL-13: Godot steering agent and telemetry

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 2 "Input seam", "Steering at 90 Hz" and "Telemetry"; `sketches/ball-lab/src/{intent,ball_rules,player_ball,field}.gd`; `src/jev/{jev_state,scenarios,jev_io}.gd` (JL-09, JL-10)
- Contract items from the JL-10 review (EV-0509): the first snapshot comes at least one physics tick after `Scenarios.place()`; raw `shockwave` emissions collapse into one hit per enemy and contact stretch before any stomp or ram count

**Dependencies:** [JL-09](#jl-09), [JL-10](#jl-10). **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/jev_agent.gd`; `sketches/ball-lab/src/jev/telemetry.gd`; `sketches/ball-lab/tests/jev_agent_test.gd`; `artifacts/local/tasks/JL-13/`.

**Definition of done:**

1. `jev_agent.gd` extends `Intent.Source`, installs as `player.source` the way `tests/mode_check.gd` does, and turns the held intent into stick input at 90 Hz through one shared `seek(point)` (`move = (d·B.x, −d·B.z)`, the inverse of `ball_rules.gd:48`) with brake on overshoot, aligned boost, jump edges and unstick; it implements `push_objective`, `hit_kicker`, `stomp_target`, `ram_target` and `evade_hazard`.
2. Headless tests show each intent reaching its target on a fixed placement in both physics modes within a stated tick budget, and `seek` inverting `ball_rules.gd:48` to within 1°.
3. `telemetry.gd` writes `events.ndjson` lines in the protocol's closed event kinds and a 10 Hz trace: tier changes, takeoffs and landings, collapsed knocks, stuck begin and end, and anomalies (NaN, tunnelling below `Field.height − 0.5`, out of bounds, speed over 80 m/s).
4. No gameplay file changes; `npm run sketch:smoke` passes.

**Verification and evidence:** `npm run sketch:smoke`; `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No runner process or protocol loop (JL-17), no Jev call.

<a id="jl-14"></a>

### JL-14: Verdict cache, the jev arm and replay

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 2 "Arms" (verdict cache key, replay); `scripts/lab/{harness,arms}.mjs` (JL-11); `tools/jev-player/{decide.mjs,score.mjs}`; `protocol.mjs` `verdictKey()`
- Carried notes: EV-0489 (confirm the real Jev `usage` field names; only `input_tokens` is confirmed), EV-0493 (`score.mjs` needs a `--help`/`--dry-run` guard before any live call; copy `decision.model` into score records)

**Dependencies:** [JL-11](#jl-11). **Blocking questions:** None.

**Files touched:** `scripts/lab/harness.mjs`; `scripts/lab/arms.mjs`; `scripts/lab/verdict-cache.mjs`; `tools/jev-player/score.mjs`; `tools/jev-player/decide.mjs` (return usage and resolved model unchanged in shape); `tests/lab-jev-arm.test.js`; `tools/jev-player/tests/score.test.js`; `artifacts/local/tasks/JL-14/`.

**Definition of done:**

1. The jev arm calls `decide()` once per non-forced snapshot, caches each verdict under `verdictKey()`, records the resolved model and the four token fields separately, and respects the per-batch call cap; `--replay` makes zero network calls and treats a cache miss as an error.
2. Tests use an injected `decideFn`; no test makes a live call.
3. `score.mjs` parses its arguments before doing anything: `--help` prints usage and exits 0 with no call; `--dry-run` loads and validates the corpora and question set with no call; each score record carries `decision.model`.
4. One live smoke of the jev arm on the fake Godot, capped at 5 calls, confirms the real `usage` field names and the resolved model; the record is retained and the finding is written to the card's receipts.

**Verification and evidence:** `npm test`; `npm run verify`; the capped live smoke; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No preflight (JL-15), no question-set change, no real Godot.

<a id="jl-15"></a>

### JL-15: Preflight controls

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 1 "Preflight controls" and "Instrument epoch"; `tools/jev-player/{decide.mjs,questions/}`; `scripts/lab/{gate,metrics/status}.mjs` (JL-12's epoch rule)
- Carried: `control_separation` needs a threshold before the gate can use exit 4 for it (EV-0504)

**Dependencies:** [JL-03](#jl-03), [JL-12](#jl-12). **Blocking questions:** None.

**Files touched:** `tools/jev-player/preflight.mjs`; `tools/jev-player/controls/c1.json`; `tools/jev-player/tests/preflight.test.js`; `scripts/lab/metrics/core.mjs` (the `control_separation` threshold only); `artifacts/local/tasks/JL-15/`.

**Definition of done:**

1. `preflight.mjs` exports `runControls({questions, decideFn})` for the free-cache, lethal-option and wording-swap controls in `controls/c1.json`, each run with the options in both orders, never reading a cache, and returns pass or fail per control with its probabilities; a failure makes the caller exit 6 before any Godot process starts.
2. An epoch record (questions sha, model, floor, gate version, control results, blind-corpus result) is written when both controls and the blind corpus pass; JL-12's gate reads it for `lever_effect` and for pinning.
3. `control_separation` gets a warn and fail threshold in the registry, with the rationale in a comment.
4. Tests use an injected `decideFn`; one live run against q1 is retained and reported as-is (q1 is retracted-leading, so a failure is an expected, recordable result).

**Verification and evidence:** `npm test`; `npm run verify`; the live control run; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No new question set (JL-18); thresholds in `c1.json` are provisional.

<a id="jl-16"></a>

### JL-16: `scrapkeep stats` and lab verb routing

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Output" (`scrapkeep stats`); `scripts/lab/{record,gate,metrics/*}.mjs`; `scripts/play.mjs`
- Carried from the JL-06 review (EV-0505): NB1 (the headless shot has no process timeout), NB3 (a relative or `//tmp` path can resolve into `/tmp`)

**Dependencies:** [JL-06](#jl-06), [JL-12](#jl-12). **Blocking questions:** None.

**Files touched:** `scripts/lab/model.mjs`; `scripts/lab/stats-cli.mjs`; `scripts/play.mjs`; `tests/lab-stats.test.js`; `tests/play.test.js`; `artifacts/local/tasks/JL-16/`.

**Definition of done:**

1. `scripts/lab/model.mjs` loads the run index into one in-memory model (latest record per type and label, trends per metric, epoch boundaries) and refuses to aggregate across mixed question shas or models.
2. `scrapkeep stats [--layer <layer>]` prints one line per metric: glyph, value, n, change from the latest pin and the registry's `says` line, rendered only through `status.mjs`.
3. `play.mjs` routes `lab`, `stats` and `gate` verbs to their scripts.
4. NB1: the headless shot spawn has a process timeout; NB3: the output path is resolved and refused when it lands under `/tmp` or `os.tmpdir()`.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No dashboard (JL-22), no new metric.

<a id="jl-05c"></a>

### JL-05c: Protocol validator defects and the rules left only in code

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- The JL-09 review, `artifacts/jev-lab-2026-09-25/reviews/JL-09.md` N1, N2 and N3, and the JL-11 review N7 (EV-0513, EV-0514, EV-0517)
- `tools/jev-player/protocol/{PROTOCOL.md,protocol.mjs,fixtures/}`; `tools/jev-player/decide.mjs`; `sketches/ball-lab/src/jev/jev_io.gd`

**Dependencies:** [JL-09](#jl-09). **Blocking questions:** None.

**Files touched:** `tools/jev-player/protocol/{PROTOCOL.md,protocol.mjs,fixtures/}`; `tools/jev-player/decide.mjs` (the `PRECONDITION` lookup only); `tools/jev-player/tests/protocol.test.js`; `sketches/ball-lab/src/jev/fixtures/` (the byte-identical copy only); `sketches/ball-lab/src/jev/jev_io.gd` (whole-number exactness and a `GATE_VERSION` constant only); `tests/jev-fixtures.test.js`; `artifacts/local/tasks/JL-05c/`. Scoped exception to the Jev Lab rule that no card mixes `tools/` with `sketches/`: the drift test forces the fixture copy to change with the canonical fixtures, and the Godot validator must agree with the Node judge.

**Definition of done:**

1. Node looks up event kinds, arms and preconditions with own-property checks, so `constructor`, `__proto__`, `toString` and array values are rejected or reported as errors, never accepted or thrown; fixtures cover each.
2. PROTOCOL.md and `protocol.mjs` agree on whole numbers (one rule, applied on both sides), on non-empty strings, and on the gate: PROTOCOL.md states the four precondition rules and `GATE_VERSION`, and `jev_io.gd` pins the same `GATE_VERSION`, asserted by `tests/jev-fixtures.test.js`.
3. Gate fixtures cover `start_exit`, ram dropped, stomp dropped and `hit_kicker` kept; Node and Godot agree on all of them.
4. PROTOCOL.md states the `abort{arm_error}` write on a Node-side invalid state and classifies a Godot that hangs after writing `done.json`.
5. The protocol string stays `scrapkeep-jev/1`; no message field is added.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run sketch:smoke`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No behaviour change for valid input; no new message field.

<a id="jl-17"></a>

### JL-17: The Godot runner and the bridge test

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 2 "Runner", "Protocol v1", "Timing" and "Determinism"; `sketches/ball-lab/src/jev/{jev_io,jev_state,jev_agent,telemetry,scenarios}.gd`; `scripts/lab/{harness,arms}.mjs` (the `launch` seam)
- Carried from the JL-11 review (EV-0514): N3 (process-group cleanup and `abort{interrupted}` on the harness's own SIGINT or SIGTERM) and N5 (the launch seam has no D, k or env, and records do not store D and k)

**Dependencies:** [JL-13](#jl-13), [JL-14](#jl-14). **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/jev_run.gd`; `sketches/ball-lab/tests/jev_bridge_test.gd`; `scripts/lab/harness.mjs`; `scripts/lab/godot-launch.mjs`; `tests/lab-bridge.test.js`; `artifacts/local/tasks/JL-17/`. Scoped exception to the no-mixing rule: the runner and the harness seam must change together.

**Definition of done:**

1. `jev_run.gd` extends `SceneTree`, lives outside `tests/`, runs one trial of a named scenario headless at `--fixed-fps 90` (ticks equal frames), snapshots every D ticks, keeps flying the held intent for k ticks, then blocks inside `_physics_process` until the intent arrives and applies it at exactly t + k; timeouts and exit codes follow PROTOCOL.md.
2. `godot-launch.mjs` supplies the harness `launch` for real Godot with `--headless`, `--fixed-fps 90`, the scenario, seed, D, k and output directory, spawned in its own process group; the harness kills the group on stall and writes `abort{interrupted}` on its own SIGINT or SIGTERM; D and k are stored in the batch record.
3. The bridge test runs the scripted arm with random responder delays and shows every intent applied at exactly t + k and `trace_hash` identical across delay patterns, for each physics mode; if rigid mode diverges it is reported as stochastic, not hidden.
4. One real batch per arm (random, scripted, jev capped at 10 calls) on `downhill-run` completes and is retained.

**Verification and evidence:** `npm run sketch:smoke`; `npm test`; `npm run verify`; the retained batches; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No calibration (JL-21), no new question set (JL-18).

<a id="jl-18"></a>

### JL-18: Neutral question set q2 and the c2 controls

**Card revision:** 2 · **Owner:** Verification · **Size:** S · **Lane:** Jev Lab

Revision 2 (EV-0524) splits the original card so the prompt author never meets the blind corpus: this card is the prompt side only; the harness wiring and blind scoring moved to [JL-18b](#jl-18b).

**Source and inputs:**

- Plan § 1; `tools/jev-player/{decide.mjs,questions/,preflight.mjs,controls/c1.json}`; the audit (A1, A7, A18) and the JL-15 review (EV-0520) on the c1 controls
- Carried: equalise decision-bearing facts across the wording-swap arms by putting them in the option text, add a max-shift line, run the swap on the free-cache state too, length-match options

**Dependencies:** [JL-15](#jl-15). **Blocking questions:** None.

**Files touched:** `tools/jev-player/questions/{q2-neutral.json,INDEX.json}`; `tools/jev-player/controls/c2.json`; `tools/jev-player/preflight.mjs` (the max-shift line only); `tools/jev-player/tests/`; `artifacts/local/tasks/JL-18/`.

**Definition of done:**

1. `q2-neutral.json` states mechanics only, with no valuation of any option, is pinned in `INDEX.json`, and passes the pin and snapshot tests; its author reads no blind case, no blind-corpus file and no review that names blind cases.
2. `c2.json` puts every decision-bearing fact in the option text for both wording-swap arms, adds the swap on the free-cache state, adds a provisional max-shift line recorded beside the same-choice rule, and length-matches options.
3. One live preflight of q2 with c2 is run and reported as it falls, with the epoch record written; no wording or threshold is tuned after the result.

**Verification and evidence:** `npm test`; `npm run verify`; the live preflight, retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Prompt side only; no harness, cache or scoring change.

<a id="jl-18b"></a>

### JL-18b: Preflight in every jev batch, the cache model check, and the blind score under q2

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- `scripts/lab/{harness,verdict-cache,arms}.mjs`; `tools/jev-player/{preflight,score}.mjs`; `artifacts/jev-lab-2026-09-25/blind-diagnostic.json` (the state-diagnostic case ids, prepared by the coordinator from the JL-04 attempt-3 review)
- Carried: from the JL-14 review (EV-0523) F1 (`model_mismatch` mapped to invalid; anchor all-hit batches on the preflight's resolved model), F3 (argument errors exit 2) and F6 (unknown causes default to fail); from the JL-15 review (EV-0520) storing `resolved_models`, not overwriting a passed epoch with an all-error run, and deriving validity from per-control results

**Dependencies:** [JL-14](#jl-14), [JL-15](#jl-15); DoD 5 also needs [JL-18](#jl-18). **Blocking questions:** None.

**Files touched:** `scripts/lab/{harness,verdict-cache}.mjs`; `tools/jev-player/preflight.mjs` (epoch record fields and validity); `tools/jev-player/score.mjs` (the state-diagnostic subscore); `tools/jev-player/protocol/{PROTOCOL.md,protocol.mjs}` (outcome rows and the null-state guard only); `tests/lab-jev-arm.test.js`; `tests/lab-harness.test.js`; `tools/jev-player/tests/{preflight,score}.test.js`; `artifacts/local/tasks/JL-18b/`.

**Definition of done:**

1. Every jev batch runs preflight first and refuses with exit 6 on failure; the preflight's resolved model anchors the batch.
2. A cache hit whose stored resolved model differs from the batch's anchor is treated as a miss in a live batch and aborts with `model_mismatch`, mapped to invalid, in a replay or mixed batch; harness argument errors exit 2; an unknown abort cause defaults to fail.
3. The epoch record stores `resolved_models`, is not overwritten by an all-error run, and derives validity from per-control results with the expected control count.
4. `score.mjs` reports a state-diagnostic subscore from `blind-diagnostic.json` beside the blind total, aggregates only.
5. From the JL-05c review (EV-0524): PROTOCOL.md's arm-failure row names `replay_miss` beside `arm_error`, its precedence prose matches the harness (a Node-side rejection outranks crash), and `validateTrial` does not throw on a state file whose content is JSON `null`.
6. After JL-18 lands: the blind corpus is scored live under q2, the epoch record's blind result is filled, and the result is reported as it falls.

**Verification and evidence:** `npm test`; `npm run verify`; the live blind score, retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** The writer of this card must not write or edit any question set; blind results reach a question-set author only as aggregates.

<a id="jl-19"></a>

### JL-19: Jev failure triage in the test loop

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 5 (JL-19 row: Choice {timing_flake, real_regression, engine_crash, test_bug, infra} plus a safe-to-rerun Noul; control: an injected `assert(false)` must come back `real_regression`); the TypeSafe typesafe-ai skill for the call shape
- The intermittent `npm test` failures at EV-0497 as real cases

**Dependencies:** [JL-06](#jl-06), [JL-14](#jl-14). **Blocking questions:** None.

**Files touched:** `scripts/lab/triage.mjs`; `scripts/lab/triage-corpus.json`; `tests/lab-triage.test.js`; `artifacts/local/tasks/JL-19/`.

**Definition of done:**

1. `triage.mjs` classifies a failed check from its log and diff with one typed Jev call, redacting secrets first, caching verdicts, and falling back to a deterministic rule when Jev is unavailable; nothing on the gate path waits on it.
2. A labelled corpus of real and edge cases plus a blind adversarial set is scored with severity weights, where a regression called a flake is severe; the control case must return `real_regression`.
3. A rerun counts toward `flake_rate` and never turns a red result green.

**Verification and evidence:** `npm test`; `npm run verify`; the corpus score retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Advisory only; the gate never depends on it.

<a id="jl-20"></a>

### JL-20: Verdict tagging

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 5 (JL-20 row: a Noul per tag; control: PLAYTEST-LOG entries 1 and 2 hand-labelled); `docs/playtests/verdicts.ndjson` and `scripts/lab/verdicts.mjs` (JL-07)

**Dependencies:** [JL-07](#jl-07), [JL-14](#jl-14). **Blocking questions:** None.

**Files touched:** `scripts/lab/verdict-tags.mjs`; `scripts/lab/verdict-tags.json` (the tag vocabulary and hand labels); `docs/playtests/verdicts.ndjson` (`tags` only); `tests/lab-verdict-tags.test.js`; `artifacts/local/tasks/JL-20/`.

**Definition of done:**

1. A fixed tag vocabulary (for example movement feel, level shape, exploration, abilities, physics mode) with hand labels for entries 1 and 2 written before any Jev call.
2. `verdict-tags.mjs` scores each tag with one typed Jev Noul per verdict, cached, and fills `tags` only when the hand labels are reproduced; disagreements are reported, not overwritten.
3. The quotes stay verbatim and `node scripts/lab/verdicts.mjs` still passes.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Tags describe Andrew's words; they never stand in for his verdict.

<a id="jl-18c"></a>

### JL-18c: Pre-registered Jev-as-player redesign experiment

**Card revision:** 1 · **Owner:** Verification · **Size:** M · **Lane:** Jev Lab

Andrew's decision at EV-0527: one redesign, fixed before any call; if it still fails, Jev-as-player is parked for this program.

**Source and inputs:**

- The JL-18 review § 6 (`artifacts/jev-lab-2026-09-25/reviews/JL-18.md`), EV-0516, EV-0520, EV-0526 and EV-0527; `tools/jev-player/{decide.mjs,preflight.mjs,questions/q2-neutral.json,controls/c2.json}`
- Findings to separate: residual option framing, position bias in Choice answers, and a genuine prior toward the objective-directed option over a free dominant one

**Dependencies:** [JL-18](#jl-18). **Blocking questions:** None.

**Files touched:** `artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md`; `tools/jev-player/experiments/jl18c/` (experiment script, states and per-option question text); `tools/jev-player/tests/jl18c.test.js`; `artifacts/local/tasks/JL-18c/`. No change to `decide.mjs`, the harness or any pinned question set; adopting a passing design into the arm is a later card.

**Definition of done:**

1. **Phase A, before any call:** `PREREGISTRATION.md` fixes the designs, the exact prompts, the pass rules and the call budget, and is reviewed by Fable before Phase B starts. Designs, from the JL-18 review: every threshold control in all six option permutations with three repeats, reporting per-position P and spread while keeping the every-order pass rule; per-option comprehension Nouls asked without a Choice; a third free-cache state whose push option does not name the exit or charge, plus a two-option variant; a dominance probe outside caches (a free full heal at low health with no threats); per-option yes/no preference Nouls with order averaging; one intent-only cell. The 0.6 and 0.2 lines stay.
2. **Phase B:** the pre-registered calls run once under a stated cap, every cell is reported as it falls, and nothing in the pre-registration changes after the first call.
3. A verdict against the pre-registered rule: pass (a design that clears every control in every order becomes a candidate for a follow-up card), or fail (Jev-as-player is parked for this program, per EV-0527), with the evidence separating framing, position and preference stated.

**Verification and evidence:** `npm test`; `npm run verify`; the Phase A review; the retained Phase B results; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** An experiment, not an instrument change.

## Jev Lab re-scope after the Jev-as-player park (25 September 2026)

Andrew approved the trimmed plan at EV-0542. Jev-as-player is parked (EV-0527, EV-0540, EV-0541); the arm comparisons below use the scripted and random arms, and Jev keeps its test-loop roles (JL-19, JL-20, JL-23, JL-24).

<a id="jl-21"></a>

### JL-21: Scenario calibration with real choices

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 3 (scenarios; recalibrate limits to `max(initial, 2 × scripted p90)`; the D and k sweep); `sketches/ball-lab/src/jev/*.gd`; `scripts/lab/{harness,godot-launch}.mjs`
- Carried: JL-10 review N3 and JL-13 review (`KICKER_AT` to the lip); JL-13 review N1 (the ram placement inside the shallow kicker) and N5 (count knocks from Telemetry in `JevState` and scenario progress); JL-17 review N1 (the orphaned final snapshot), N2 (record the scenario's own result), N3 (`downhill-run` forces every answer), N5 (determinism evidence)

**Dependencies:** [JL-17](#jl-17). **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/{jev_state,scenarios,jev_run}.gd`; `sketches/ball-lab/tests/jev_*_test.gd` (placements and budgets only); `scripts/lab/harness.mjs` (the scenario result in records); `scripts/lab/metrics/ball-lab.mjs`; `tests/lab-*.test.js` as needed; `artifacts/local/tasks/JL-21/`. Scoped exception to the no-mixing rule: the runner and the record change together.

**Definition of done:**

1. At least three scenarios offer real choices in most snapshots (threats in range, the kicker reachable, loot), and the scripted and random arms produce measurably different outcomes on them.
2. Time limits recalibrated to `max(initial, 2 × scripted p90)` from at least 20 trials per scenario; `requires_speed_ms` and `KICKER_AT` recalibrated to the lip; the D and k sweep runs over pairs with k < D; results recorded.
3. Knocks counted from Telemetry everywhere; the scenario's own success or timeout is written to `done.json`'s summary or the batch record; no snapshot is written after the trial has ended.
4. Determinism evidence widened: a contact scenario with multi-option snapshots, a sensitivity control (the hash changes when k or an answer changes), repeated identical rigid runs, several random-arm seeds.

**Verification and evidence:** `npm run sketch:smoke`; `npm test`; `npm run verify`; the calibration batches retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No gameplay change; no Jev player arm.

<a id="jl-22"></a>

### JL-22: The lab dashboard

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Output" (`scrapkeep dash`: a local HTML page, inline SVG, no script, `default-src 'none'`, Neon Noir palette through `status.mjs`); `scripts/lab/{model,stats-cli,gate}.mjs`
- Carried from the JL-16 review (EV-0519): one epoch key (the canonical instrument plus the answered model), trend breaks per series, no crash on a stray pin file, correct "no pin" wording

**Dependencies:** [JL-16](#jl-16). **Blocking questions:** None.

**Files touched:** `scripts/lab/dash.mjs`; `scripts/lab/model.mjs`; `scripts/play.mjs` (the `dash` verb); `tests/lab-dash.test.js`; `tests/lab-stats.test.js`; `artifacts/local/tasks/JL-22/`.

**Definition of done:**

1. `scrapkeep dash` writes `artifacts/local/dash/index.html` with, in order: "Waiting for Andrew" (unplayed builds and the playtest checklist), per-layer tiles with sparklines, arms side by side per scenario, trends with threshold bands and epoch rules, the Jev test-loop scores (triage, tagging) with their qualifications, findings and limits.
2. Every registry id appears exactly once; no colour appears outside `STATUS`; the page loads with no script and a `default-src 'none'` policy.
3. A headless Chromium screenshot of the real page is retained; the page is readable at phone width.
4. The four JL-16 notes are fixed.

**Verification and evidence:** `npm test`; `npm run verify`; the screenshot; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Local file only; no server, no network.

<a id="jl-23"></a>

### JL-23: Jev test ordering for `scrapkeep watch`

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 5 (JL-23 row: which checks will this save break? Score per test; reorders only, never skips; control: a test that imports the changed file must outrank one that does not); `scripts/play.mjs` (`watch`); `scripts/lab/triage.mjs` (the redaction, cache and call-log pattern); `scripts/lab/metrics/tdd.mjs` (`first_red_s`)

**Dependencies:** [JL-19](#jl-19). **Blocking questions:** None.

**Files touched:** `scripts/lab/test-order.mjs`; `scripts/play.mjs` (the `watch` ordering hook only); `tests/lab-test-order.test.js`; `artifacts/local/tasks/JL-23/`.

**Definition of done:**

1. On a save, `watch` asks one typed Jev call for a per-test failure score from the redacted diff and test names, orders the run by it, and never skips a test; with no key or on error it falls back to the current order.
2. Labelled cases plus a separately labelled check set measure `first_red_s` against the unordered run; the import control passes.
3. Nothing on the gate path imports it (transitive check).

**Verification and evidence:** `npm test`; `npm run verify`; the scored cases retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Ordering only.

<a id="jl-24"></a>

### JL-24: Jev coverage-gap check

**Card revision:** 1 · **Owner:** Tooling · **Size:** S · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 5 (JL-24 row: is this change exercised by any test? Noul per test; the `untested_change` KRI; control: a file with no test at all must be flagged); `scripts/lab/triage.mjs` pattern; `scripts/lab/metrics/tdd.mjs`

**Dependencies:** [JL-19](#jl-19). **Blocking questions:** None.

**Files touched:** `scripts/lab/coverage-gap.mjs`; `tests/lab-coverage-gap.test.js`; `artifacts/local/tasks/JL-24/`.

**Definition of done:**

1. Given a diff, one typed Jev call per changed file asks whether any existing test exercises it, using test names and imports as context; redacted, cached, with a deterministic fallback (a static import scan).
2. It feeds `untested_change` as advisory output; labelled cases plus a separately labelled check set; the no-test control is flagged.
3. Nothing on the gate path imports it.

**Verification and evidence:** `npm test`; `npm run verify`; the scored cases retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Advisory only.

<a id="jl-25"></a>

### JL-25: Gate qualification

**Card revision:** 2 · **Owner:** Verification · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § 4 "Gate" and § "Verification" step 5 (exit codes 1 → 0 → 4); `scripts/lab/{gate,record,harness}.mjs`
- Carried: EV-0504 (the `andrew-anchor` pin is exempt from staleness), EV-0511 (exclude `sources.json` and `run-owner.json` from pin copies; test the uncaught-error exit 4), EV-0523 (a replay's call cap defaults from its source run), EV-0536 (a null-model replay anchor counts as a mismatch)
- Revision 2 (EV-0546, JL-21 review): rigid runs flip about 1 trial in 20, so trace equality and replay gates apply to kinematic records only; rigid records gate on distributions with n ≥ 20; `margin_vs_scripted` is not gated until JL-28 lands; `bench-climb` is exempt from `unreachable_scenarios` until `hit_kicker` is reachable

**Dependencies:** [JL-21](#jl-21). **Blocking questions:** None.

**Files touched:** `scripts/lab/{gate,harness}.mjs`; `tests/lab-gate.test.js`; `tests/lab-jev-arm.test.js`; `artifacts/jev-lab-2026-09-25/pins/`; `artifacts/local/tasks/JL-25/`.

**Definition of done:**

1. A baseline of scripted-arm and suite records is pinned, including `andrew-anchor` for the build Andrew played (dc94b2c), which never goes stale.
2. Qualification on real records: an injected bounded regression exits 1, removing it exits 0, an invalid record exits 4, an instrument change against a pin exits 4, too few samples exits 3; each result retained.
3. The carried notes are fixed.

**Verification and evidence:** `npm test`; `npm run verify`; the qualification runs retained; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No new metric.

<a id="jl-26"></a>

### JL-26: `lab/cable-bench`

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Plan § "Waves" row 7; `proto/cable-bench` at 29dcbcf; the ball-lab `src/jev/` stack

**Dependencies:** [JL-21](#jl-21). **Blocking questions:** None.

**Files touched:** a new branch `lab/cable-bench` from 29dcbcf, with `sketches/cable-bench/src/jev/` adapters, `seed_override` in `stage.gd`, and `scripts/lab/metrics/cable-bench.mjs`; `artifacts/local/tasks/JL-26/`. `proto/cable-bench` stays byte-identical.

**Definition of done:**

1. The runner, state export, steering and telemetry run on Cable Bench with the random and scripted arms; the existing stage tests pass unchanged.
2. Stage metrics are registered; at least 20 trials per arm are retained.
3. `proto/cable-bench`'s head is unchanged before and after.

**Verification and evidence:** the stage's `sketch:smoke`; `npm test`; `npm run verify`; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No gameplay change; no merge into `proto/*` or `main`.

<a id="jl-27"></a>

### JL-27: `lab/spillway-drop`

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- As JL-26, for `proto/spillway-drop` at af89c89

**Dependencies:** [JL-21](#jl-21). **Blocking questions:** None.

**Files touched:** a new branch `lab/spillway-drop` from af89c89, with `sketches/spillway-drop/src/jev/` adapters, `seed_override` in `stage.gd`, and `scripts/lab/metrics/spillway.mjs`; `artifacts/local/tasks/JL-27/`. `proto/spillway-drop` stays byte-identical.

**Definition of done:** As JL-26, for Spillway Drop.

**Verification and evidence:** As JL-26.

**Boundary:** As JL-26.

<a id="jl-28"></a>

### JL-28: Arm comparison across the three sketches

**Card revision:** 3 · **Owner:** Verification · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- JL-21, JL-21b, JL-26, JL-27 records; the registry; the gameplay findings recorded at EV-0531 and EV-0534
- Revision 2 (EV-0546, JL-21 review): pre-register the scenario's own success predicate as the sole primary metric and progress metrics (gates, knocks) as exploratory; both physics modes; seeds 1000 to 1019 paired by spawn jitter; state that n = 20 resolves only differences of about 0.3; state the direction expected from JL-21 (random above scripted) as the hypothesis; require a multi-option share of at least 0.5 per scenario as a validity check; name JL-21b's knocked-threat rule as the instrument epoch
- Revision 3 (EV-0550): trial seeds 2000 to 2019 (batch seed 2), because the lab cards already ran 1000 to 1019; the instrument epoch is the per-stage threat rule (ball-lab drops a knocked dummy; Cable Bench and Spillway Drop drop only a dead or removed foe); for the scripted kinematic ball-lab pins, re-cut after JL-21b before any gate comparison

**Dependencies:** [JL-21b](#jl-21b), [JL-25](#jl-25), [JL-26](#jl-26), [JL-27](#jl-27). **Blocking questions:** None.

**Files touched:** `artifacts/jev-lab-2026-09-25/experiments/arms/`; `artifacts/local/tasks/JL-28/`.

**Definition of done:**

1. A pre-registered comparison of the scripted and random arms on the mechanics metrics (stuck rate, dead tier, anomalies, scenario success) across ball-lab, Cable Bench and Spillway Drop, run once and reported as it falls, labelled "automated; not a feel verdict".
2. A list of gameplay findings for Andrew with the evidence behind each, ready for his next play.

**Verification and evidence:** the retained runs and report; a Fable read.

**Boundary:** No Jev player arm; nothing here is a feel verdict.

<a id="jl-29"></a>

### JL-29: Program close

**Card revision:** 2 · **Owner:** Coordinator · **Size:** S · **Lane:** Jev Lab

**Source and inputs:** Every JL card and event; the plan's § "Verification"

**Dependencies:** [JL-22](#jl-22), [JL-23](#jl-23), [JL-24](#jl-24), [JL-28](#jl-28), [JL-30](#jl-30), [JL-31](#jl-31). **Blocking questions:** None.

**Files touched:** `CONTRIBUTING.md`; `tools/jev-player/README.md`; `.agents/skills/scrapkeep-verify/SKILL.md` (a Jev Lab method row); `artifacts/jev-lab-2026-09-25/RETRO.md`; TRACKING (coordinator only).

**Definition of done:**

1. Docs describe how to run the lab, the gate, the dashboard and the Jev test-loop tools, with each tool's measured limits.
2. The final retro reports every program metric and the Jev findings with their qualifications.
3. A Fable integrated read of the whole branch passes; `wt/JL-coord` merges into `main`; pushing waits for Andrew's go.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run sketch:smoke`; `check:docs`; `check:drift`; the integrated read.

**Boundary:** No new feature.

<a id="jl-21b"></a>

### JL-21b: Knocked threats leave the state; re-derive per-mode limits

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- JL-21 review F1, F5, F6 ([report](artifacts/jev-lab-2026-09-25/reviews/JL-21.md)); JL-21 evidence under `artifacts/jev-lab-2026-09-25/live/JL-21/`
- `sketches/ball-lab/src/jev/{jev_state,scenarios,jev_run}.gd`; `scripts/lab/arms.mjs`; `scripts/lab/harness.mjs`

**Dependencies:** [JL-21](#jl-21). **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/jev_state.gd`; `sketches/ball-lab/tests/jev_state_test.gd`; `tests/lab-bridge.test.js`; `sketches/ball-lab/src/jev/scenarios.gd` (time limits only); `artifacts/local/tasks/JL-21b/`.

**Definition of done:**

1. A dummy knocked in the current trial is left out of the exported threats, for every arm alike, using the Telemetry contact stretches; the ladder in `arms.mjs` is unchanged. Tested red then green.
2. The JL-21 arms batches are re-run at the committed head (both modes, 20 trials per arm and scenario, seed 1), and the multi-option share and success rates are reported beside JL-21's, labelled as a new instrument epoch.
3. Time limits are re-derived per scenario and per physics mode with max(initial, 2 × scripted p90); any scenario whose scripted p90 is still censored at 3 × the limit is recorded as inconclusive with its limit unchanged.
4. Every batch cited ran at the committed head with a clean tree.

**Verification and evidence:** `npm run sketch:smoke`; `npm test`; `npm run verify`; the retained batches; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No gameplay file (`enemy.gd`, `field.gd`, `ball_rules.gd` and the rest stay unchanged); no ladder tuning; no Jev call.

<a id="jl-30"></a>

### JL-30: A skill suite for the lab and for reactive model decisions

**Card revision:** 1 · **Owner:** Coordinator · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Andrew's request (EV-0552): codify what this program learned about Jev, reactive model decision-making and headless game development, as skills agents can use, edit and extend as mechanics change, so the knowledge stays current instead of becoming debt
- The program record: TRACKING EV-0483 to the latest event, `artifacts/jev-lab-2026-09-25/` (plan, audit, reviews, experiments, live evidence), BACKLOG JL-00 to JL-31, the JL-18c pre-registration and results; this session's transcript as a secondary source
- The existing project skills under `.agents/skills/` (`plan-session`, `scrapkeep-task`, `scrapkeep-verify`) and their `.claude/skills` links

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** new skill folders under `.agents/skills/` with matching `.claude/skills` links; small cross-links from the existing three skills; `artifacts/jev-lab-2026-09-25/skills/` (the lesson inventory and the design); `artifacts/local/tasks/JL-30/`.

**Definition of done:**

1. A lesson inventory, each lesson citing the event, review or result it came from, grouped into: model-as-decider instruments (controls, blind corpora, pre-registration, framing and position effects, caching, redaction, fallbacks, cost fields), the headless game lab (protocol, determinism per physics mode, scenarios, arms, gates, pins, per-stage rules), and coordination (reviews, receipts, board gates, the coordinator's own recorded mistakes).
2. A reviewed design: which skills, each one's trigger, boundary and owner; which parts are Scrapkeep-specific and which are portable to any reactive model-in-the-loop system; and an update procedure (when a mechanic, protocol, instrument or result changes, which skill section changes and who checks it) with a mechanical check that flags a skill citing a file, command or event that no longer exists.
3. The skills are written and each is exercised: a fresh agent given only the skill completes one representative task per skill (for example, add a scenario, run a pre-registered control, add a stage lab), and the result is reviewed.
4. The portable skill contains nothing Scrapkeep-specific and is ready to promote; promotion outside the repository waits for Andrew.

**Verification and evidence:** `npm run check:docs`; `npm run check:drift`; the new staleness check; the exercise transcripts and their review; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** Documentation and configuration inside the repository only; no game feature; no change to user-level configuration.

<a id="jl-31"></a>

### JL-31: Watch the lab play

**Card revision:** 1 · **Owner:** Gameplay tooling · **Size:** M · **Lane:** Jev Lab

**Source and inputs:**

- Andrew's request (EV-0552): a view of the game while a model or an arm plays it, to validate and give feedback visually
- `sketches/ball-lab/src/jev/` (runner, state, steering, telemetry), `scripts/lab/{harness,godot-launch,arms}.mjs`, `tools/jev-player/decide.mjs`, `scripts/play.mjs`, the Neon Noir palette through `scripts/lab/metrics/status.mjs`

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `sketches/ball-lab/src/jev/` (a watch overlay and runner flag, no gameplay file); `scripts/lab/{watch,godot-launch,harness}.mjs`; `scripts/play.mjs` (the `lab watch` route); a replay page generator under `scripts/lab/`; tests; `artifacts/local/tasks/JL-31/`.

**Definition of done:**

1. `scrapkeep lab watch <scenario> --arm jev|scripted|random [--mode kinematic|rigid]` opens a visible Godot window running a real trial through the harness, with an overlay showing, at each decision: the options on offer, the arm's probabilities (for Jev) as bars, the chosen intent, the decision latency, the arm and scenario, and a trail of the ball's recent path. Colour and glyphs come from the shared palette.
2. `--arm jev` in watch mode runs even when the instrument's epoch has not passed its controls, but only in watch mode, labelled on screen and in the record "demo, not evidence", and the record is refused by the gate; preflight still runs and its result is shown. A per-session call cap applies.
3. A hotkey marks the current moment with an optional typed note; each mark saves the exact state snapshot, the options, the probabilities and the note to a feedback file that a later labelled corpus can use.
4. A generated replay page plays any retained trial (events and intents) as a top-down view at selectable speed, with the decisions on a timeline; no network and no script from outside the page.
5. The headless path, the protocol and the determinism tests are unchanged.

**Verification and evidence:** `npm test`; `npm run verify`; `npm run sketch:smoke`; a screenshot of the watch window taken on workspace 10 and closed after; the replay page rendered headless; `npm run check:scope -- <base> <candidate>` and every command it prints.

**Boundary:** No gameplay change; watch-mode Jev runs are never evidence; no window opens on Andrew's workspace during verification.


## Direction foundation after the sketch plays (26 September 2026)

Andrew authorized this documentation-only round at TRACKING EV-0579 after playing the three EV-0482 sketches (playtest log entries 3 to 5) and deciding D1 (EV-0578). It writes five new engineering decisions as ADRs in the form of TADR-001 to TADR-005, marks the technical sections written for rooms and waves as superseded, then harmonizes the Bible. No game code, no build, no edit to TADR-001 to TADR-005 or to any admitted section body. Wave 1 is DF-01 to DF-03 with disjoint files; DF-04 follows their admission. The coordinator alone edits `adr/README.md`, BACKLOG and TRACKING.

<a id="df-01"></a>

### DF-01: Physics authority, verification basis and sketch promotion

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** Direction foundation

**Source and inputs:**

- TRACKING EV-0578 (decision D1, Andrew) and EV-0579; `docs/decisions.tsv` last row
- `docs/playtests/PLAYTEST-LOG.md` entries 2 to 5; `docs/playtests/verdicts.ndjson`; `scripts/lab/verdicts.mjs`
- `.agents/skills/scrapkeep-lab/references/lessons.md` lines 51 to 77 (kinematic exact replay, rigid divergence, the split gate)
- `adr/TADR-001-engine-language-platforms.md`, `adr/TADR-002-runtime-model.md` (line 40, controlled repeatability), `adr/README.md` (form of an ADR)
- `ORCHESTRATOR.md` § Light play lane; `docs/tech/sections/TH-02-movement-camera-and-active-aim.md`; `docs/tech/sections/TH-15-physics-query-contract.md`
- `sketches/mobility-kit/src/tuning.gd`, `sketches/mobility-kit/src/tuning_panel.gd` (tuning as data today)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `adr/TADR-006-physics-authority-and-verification.md`; `adr/TADR-007-sketch-promotion-and-playtest-traceability.md`; `artifacts/local/tasks/DF-01/`.

**Definition of done:**

1. TADR-006 records D1 as accepted engineering direction: rigid Jolt bodies are the game's physics authority; rigid behaviour is judged statistically (outcome rates, n ≥ 20, a stated nondeterminism floor); exact trace and replay equality applies only to a kinematic twin kept as a lab instrument that never ships. It states what TADR-002's "controlled repeatability" means under this decision, names the qualification still owed (fixed physics rate, interpolation, the camera and aim reading interpolated state), and lists the TH-02 and TH-15 passages that need a later amendment without editing them.
2. TADR-007 records how a sketch mechanic becomes production direction: the promotion criteria (Andrew's verdict keeps it, its sketch checks pass, the Bible and ADRs agree or an amendment is filed), the heavy-lane route into `native/`, and playtest traceability: every verdict names the exact tuning values that were played, with a proposed file shape and where it lives. Proposed tooling is named as future cards, not implemented.
3. Each ADR has context, at least three options with at least two explicitly rejected and why, a decision, consequences, and later qualification needs, in the form of TADR-001 to TADR-005. Every claim about play or the lab cites a log entry, event or lessons line; inference is labelled.

**Verification and evidence:** `npm run check:docs`; `npm run check:scope -- <base> <candidate>` reports documentation only; independent review against this card, TADR-001 to TADR-005 and the cited sources.

**Boundary:** Documentation only. No edit to existing ADRs, sections, the Bible, tools or sketches.

<a id="df-02"></a>

### DF-02: The ability contract and element-material interactions

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** Direction foundation

**Source and inputs:**

- `docs/playtests/PLAYTEST-LOG.md` entries 3 and 4; TRACKING EV-0578 and EV-0579
- `artifacts/bible-harmonization-2026-09-26/REVIEW.md` (rows on the mobility slot, element × material, slam anchor, reach indicator)
- `BIBLE.md` § 5 Weapons & Items (lines 398 to 460), the class tables (lines 275 to 377), § 6 committed attack geometry (lines 481 to 497)
- `adr/TADR-002-runtime-model.md`, `adr/TADR-003-content-pipeline.md`
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md`, `TH-04-abilities-ultimates-and-combat-rhythm.md`, `TH-07-four-slots-and-milestone-progression.md`, `TH-10-devices-and-one-main-companion.md`
- `sketches/mobility-kit/src/intent.gd`, `augments.gd`, `augment_kit.gd` (the intent-to-augment pattern the sketch already uses)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `adr/TADR-008-ability-contract.md`; `adr/TADR-009-element-material-interactions.md`; `artifacts/local/tasks/DF-02/`.

**Definition of done:**

1. TADR-008 fixes one ability pipeline: input becomes intent; the simulation resolves the ability once and owns its outcome; presentation, audio and HUD read that committed result. Abilities, augments and item modifiers are typed Resource definitions with stable IDs (TADR-003) bound to the Bible's four slots and class trees as data. Any preview (for example the grapple reach indicator) and its action read one shared query, per TH-03. Self-chosen commitment beats such as a slam anchor or a pylon mount are distinguished from handling penalties.
2. TADR-009 fixes one element × material interaction table as a typed Resource that both abilities and stage events consult. An interaction resolves once in the simulation, and any new surface it creates (ice from water, rock from lava) is shared geometry that collision, rendering and damage read. Example entries are labelled candidates; no balance numbers, costs or durations are invented.
3. Each ADR has context, at least three options with at least two rejected, a decision, consequences, qualification needs, and cites the Bible and TH lines it relies on; it names Bible silences as open rather than filling them.

**Verification and evidence:** `npm run check:docs`; `npm run check:scope -- <base> <candidate>`; independent review against this card, the Bible sections cited and TADR-002/003.

**Boundary:** Documentation only. No invented roster, recipes, costs or class assignments; class mappings stay candidates.

<a id="df-03"></a>

### DF-03: Open stages and the event director

**Card revision:** 1 · **Owner:** Runtime · **Size:** M · **Lane:** Direction foundation

**Source and inputs:**

- `docs/playtests/PLAYTEST-LOG.md` entries 1, 4 and 5; TRACKING EV-0479, EV-0480, EV-0578, EV-0579
- `artifacts/bible-harmonization-2026-09-26/REVIEW.md` (rows on the run unit, encounter grammar, the flood, events, the threat clock)
- `BIBLE.md` § 3 Maps & Areas (lines 169 to 265), § 6 lines 505 to 525 and 575 to 586
- `adr/TADR-002-runtime-model.md` (session owner, encounter tick coordinator), `adr/TADR-004-persistence.md`
- `docs/tech/sections/TH-06-encounters-waves-and-enemies.md`, `TH-11-runs-regions-exits-and-saves.md`, `TH-14-randomness-generation.md`, `docs/tech/sections/README.md`
- `sketches/spillway-drop/src/` (flood cycle and director), `sketches/cable-bench/src/` (tier clock and director)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `adr/TADR-010-open-stages-and-event-director.md`; `docs/tech/sections/README.md` (a superseded-direction note only); `artifacts/local/tasks/DF-03/`.

**Definition of done:**

1. TADR-010 makes the open stage the run's level unit and replaces wave-based encounter grammar with an event director that composes stage events (floods, drains, weather, special events), enemy spawns including a miniboss at a varied location, and discoveries; events ebb and flow, vary by area and can be unique to a map; waves become one event type. It states that elapsed time may scale threat but never gates progression, and how the director fits TADR-002's session owner and encounter tick coordinator and TADR-004's commit points. It keeps what still holds: the four worlds, world bosses, two destination offers and the save lifecycle.
2. `docs/tech/sections/README.md` notes, per section, which parts of TH-06, TH-11 and TH-14 are superseded by TADR-010 and which remain; the section bodies are not edited, so their stated hashes stay valid.
3. The ADR has context, at least three options with at least two rejected, a decision, consequences and qualification needs, citing the sketches' director and flood code as prototype evidence, not proof.

**Verification and evidence:** `npm run check:docs`; `npm run check:drift` (0 mismatches); `npm run check:scope -- <base> <candidate>`; independent review.

**Boundary:** Documentation only. No generation technique, level count or balance number is chosen.

<a id="df-04"></a>

### DF-04: Harmonize the Bible with the played direction

**Card revision:** 1 · **Owner:** Content · **Size:** M · **Lane:** Direction foundation

**Source and inputs:** `artifacts/bible-harmonization-2026-09-26/REVIEW.md`; the admitted TADR-006 to TADR-010; `docs/playtests/PLAYTEST-LOG.md` entries 1 to 5; `BIBLE.md`; the sections that pin `BIBLE.md`'s bytes (TH-12, TH-18, TH-19, PD-01, PD-02, PD-03) and those that pin them in turn, as `npm run check:drift` reports.

**Dependencies:** [DF-01](#df-01), [DF-02](#df-02), [DF-03](#df-03). **Blocking questions:** None.

**Files touched:** `BIBLE.md`; the hash lines of sections `check:drift` reports as mismatched after the Bible edit, and only after each cited line is re-verified; `artifacts/local/tasks/DF-04/`.

**Definition of done:**

1. Every REVIEW.md finding is applied or explicitly declined with a reason. Edits keep every existing line number: wording is replaced in place, and orchard-era material is marked superseded where it stands rather than moved, because 34 sections cite the Bible by line.
2. The Bible agrees with TADR-006 to TADR-010 and with the playtest log; the header points to the light play lane's authorization.
3. Each drift mismatch is resolved by re-verifying the cited lines and updating that stated hash, or reported as a finding when a cited claim no longer holds; `check:drift` ends at 0 mismatches.

**Verification and evidence:** `npm run check:docs`; `npm run check:drift`; `npm run check:project`; a Fable review of the Bible diff against REVIEW.md and the ADRs.

**Boundary:** No change to settled engine, ADR or art-lock choices; no invented product detail.

<a id="df-05"></a>

### DF-05: Carry Andrew's design principles into the Bible

**Card revision:** 1 · **Owner:** Content · **Size:** S · **Lane:** Direction foundation (follow-up)

**Source and inputs:** `docs/playtests/PLAYTEST-LOG.md` entry 6 (Andrew's principles, verbatim); `BIBLE.md` § 1 Pillars & Fantasy and § 8 Audio & Feel; TADR-006 to TADR-010; the DF-04 review notes ([report](artifacts/direction-foundation-2026-09-26/reviews/DF-04-A1.md)).

**Dependencies:** [DF-04](#df-04). **Blocking questions:** None.

**Files touched:** `BIBLE.md`; stated-hash lines that `check:drift` reports afterwards, each re-pinned only after its cited lines are re-read; `artifacts/local/tasks/DF-05/`.

**Definition of done:**

1. The principles in entry 6 appear in the Bible in Andrew's terms: momentum is sacred (only the player's performance costs momentum; loot, rewards and transitions happen on the move), quick restart, opt-in event layers with milestone rewards, insane scaling bounded by visual clarity, class identities (pylon engineer, runner-gunner as candidates), high-BPM jazzy EDM, and harmonizing apparent contradictions. Nothing beyond his words is added as settled.
2. Every existing Bible line number is preserved, as in DF-04; the four DF-04 review notes (lines 209, 293, 513, 606) are applied or declined with reason.
3. `check:drift` ends at 0 mismatches; `check:docs` passes; a Fable review of the diff passes.

**Verification and evidence:** `npm run check:docs`; `npm run check:drift`; independent review.

**Boundary:** Not authorized until Andrew or the coordinator records a scope for it; the core-loop prototype does not wait on it.

<a id="at-01"></a>

### AT-01: Inspect exported assets against explicit delivery budgets

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Asset tooling

**Source and inputs:** Andrew's 27 September 2026 tooling investment request and subsequent instruction to proceed; [asset provenance](docs/project/ASSETS.md); [TADR-001](adr/TADR-001-engine-language-platforms.md); the GLB container, accessors, meshes and scene graph in the [glTF 2.0 specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html). The paused V3 worktree supplies read-only exported fixtures, identified by hashes in the execution evidence; it is not a code dependency.

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `scripts/asset-inspect.mjs`; `scripts/asset-profiles.mjs`; `tests/asset-inspect.test.js`; `docs/ASSET-TOOLING.md`; `package.json` scripts entries only; `artifacts/local/tasks/AT-01/`. Coordinator-only changes to BACKLOG, TRACKING, CONTRIBUTING and dependency hash lines are recorded separately.

**Definition of done:**

1. A dependency-free, read-only CLI inspects GLB files and emits terminal or versioned JSON reports with source hashes, file-wide unique mesh counts, selected scene/assembly instance counts, primitive/material counts and explicit animation/skin/texture information and limits. Engine import, visual acceptance, GPU memory and performance remain unmeasured.
2. A named generic 30,000-triangle ceiling and explicit user budget support delivery checks. Inventory without a budget is never approval. The cap applies to a selected assembly at one chosen LOD, not all library variants. Numeric node IDs and manifests make selection reproducible; overlap, invalid references and ambiguous selection fail clearly. Numeric checks use no model call.
3. Validate actual binary ranges and index values, not only accessor counts. Test oversized geometry, repeated instances, unused variants, alternate LOD selection, multiple primitives, non-indexed triangles, malformed accessors, invalid scene graphs and unsupported compression/geometry extensions. At-cap passes; above-cap fails. Invalid/unsupported files never pass.
4. Manifest inputs are local and relative to the manifest; no remote fetching. Distinguish static geometry bounds from animated/skinned bounds; unmeasured values are explicit. Source files remain unchanged; report output cannot overwrite inputs, including through aliases.
5. A saved batch over nine hashed V3 exports agrees with independent file totals and explains collection-versus-assembly counts. Document inventory, cap, assembly and exit-code examples. Existing game code and the paused sprint remain untouched.

**Verification and evidence:** `node --test tests/asset-inspect.test.js`; `npm test`; `npm run check:scope -- <base> <candidate> --no-build`; `npm run check:docs`; `npm run check:project`; `npm run check:drift`; independent review; read-only CLI runs on the V3 exports. No browser or game build for this CLI-only scope.

**Boundary:** No mesh mutation, decimation, Blender job, engine import, dependency, native change, asset design acceptance, engine migration or paused-sprint integration. The later clothing/fur library is separate.

<a id="at-02"></a>

### AT-02: Build a reusable fur and accessory mesh kit

**Card revision:** 1 · **Owner:** Tooling · **Size:** M · **Lane:** Asset tooling

**Source and inputs:** Andrew's tooling request, instruction to proceed and subsequent "keep going"; [AT-01](#at-01); [asset provenance](docs/project/ASSETS.md); [TADR-001](adr/TADR-001-engine-language-platforms.md). The paused V3 session's chunky silhouette and material-role lessons inform the kit; its unapproved hero designs and dirty source files are not inputs.

**Dependencies:** [AT-01](#at-01). **Blocking questions:** None.

**Files touched:** `tools/asset-kit/**`; `docs/ASSET-TOOLING.md` (kit entry only); `artifacts/local/tasks/AT-02/`. Coordinator owns BACKLOG, TRACKING and consequential stated-hash maintenance.

**Definition of done:**

1. One reusable Blender library generates chunky fur tufts and fitted goggles/collar on two distinctly proportioned neutral head fixtures using explicit dimensions and anchors. Parts remain separate and editable in saved blend files.
2. Each fixture has a detailed and reduced static GLB. Actual exported detailed assemblies are at most 6,000 triangles; reduced assemblies at most 3,000 and smaller than detailed. These are fixture ceilings, not adopted production character budgets. A manifest binds parameters, counts, source/artifact hashes and locally authored provenance.
3. A repeatable headless recipe validates finite positive dimensions and bounded complexity, refuses existing output destinations and generates identical mesh geometry from identical inputs. Meaningful Blender probes cover these boundaries. All Blender runs use a capped user scope.
4. A rendered contact sheet shows both shapes and LODs for visual review. Documentation explains commands, fit limits, modular selection, static exports, provenance and unmeasured engine import, runtime performance and human acceptance. No universal clothing fit or production character acceptance is claimed.

**Verification and evidence:** Headless Blender probes and generation under `systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G`; AT-01 checks on all four exports; rendered image inspection; `npm run check:scope -- <base> <candidate>` and its required commands; independent review. No browser flow changes; browser UAT is not applicable.

**Boundary:** Local original mesh tooling and neutral fixtures only. No paid provider, new dependency, clothing rig, engine migration, game change, paused-sprint mutation or acceptance of pending hero/boss designs.

## Comps study: learn from the games Andrew loves (10 October 2026)

Andrew installed Risk of Rain 2, Gunfire Reborn, Roboquest and The Binding of Isaac: Rebirth and asked what Scrapkeep can take from them without reinventing the wheel, with one hard line: no copyright infringement. The pack takes mechanics, formulas, tuning numbers and structure (ideas and facts), measures production budgets (metadata only, nothing exported) and traces free upstream sources (fetched from the original under their own license, never from the game). Models, textures, audio, code text, names, characters and level layouts are never copied. The study tree and extracted data live outside the repository and are deleted when the notes are accepted. The lead lens is map design, the events on the map and the run's objectives; companions are the second lens.

<a id="cs-01"></a>

### CS-01: Risk of Rain 2 and Isaac comps pack

**Card revision:** 1 · **Owner:** Design research · **Size:** M · **Lane:** Comps study

**Source and inputs:** Andrew's request and decisions of 10 October 2026 (open stage with authored pockets; a crew of scrap bots that grow, persist and have personality); `BIBLE.md` AD-10 (line 673); `docs/DISCOVERY.md:69`; TRACKING EV-0479; `docs/CONCEPT-STUDY-01.md:25`; `docs/project/ASSETS.md`; `docs/tech/sections/TH-19-asset-import-export.md`; the decompiled Risk of Rain 2 study tree and the official Isaac resource extractor output, both in scratch outside the repository.

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `sketches/core-loop/design-v3/research/comps/**`; `docs/project/ASSETS.md` (comps posture paragraph only); BACKLOG and TRACKING (coordinator).

**Definition of done:**

1. `comps/README.md` carries the borrow list: each borrowed relationship mapped to a Bible principle and the Bible section or ADR it would amend, plus the proposed asset-forge budget deltas and the Gunfire and Roboquest follow-ups.
2. `comps/ror2/` holds notes on stage anatomy (lead), events and objectives, director and difficulty, run flow, companions (lead for the scrap-bot crew), items and stacking, characters and feel, progression and music, architecture, production budgets and provenance, with a measured stage table under `data/`.
3. `comps/isaac/` holds notes on floor generation, rooms, items and synergies, pacing and trades, and curated data tables.
4. Every note has the six fixed sections (what it does, parameters with sources, why it works, what Scrapkeep borrows, what it must not copy, lab measure) and one diagram. No game code, text, names used as Scrapkeep names, layouts or art appear.
5. The pack is handed to the main Scrapkeep session with the branch, head and borrow list.

**Verification and evidence:** greps over the diff for C# tokens and local disk paths (0 hits); `npm run check:docs`; independent review of structure and Bible fit; scratch cleanup recorded in TRACKING.

**Boundary:** Research and documentation only. No game change, no asset import, no dependency, no ADR edit (amendments are proposed in the README, not applied).

<a id="cs-02"></a>

### CS-02: Gunfire Reborn comps notes

**Card revision:** 1 · **Owner:** Design research · **Size:** M · **Lane:** Comps study

**Source and inputs:** [CS-01](#cs-01) note shape and posture; the installed game (Unity IL2CPP, so logic is native; wiki and play notes are the primary sources, asset tables readable for budgets only).

**Dependencies:** [CS-01](#cs-01). **Blocking questions:** None.

**Files touched:** `sketches/core-loop/design-v3/research/comps/gunfire/**`.

**Definition of done:** stage anatomy as the lead note (room-by-room act structure, placement of vaults, challenge rooms and shops, wave events per room), weapon-and-scroll synergy and elemental fusion, run and act pacing, production budgets by metadata, and a three-game map comparison started. Same six-section shape and the same bans as CS-01.

**Verification and evidence:** as CS-01. **Boundary:** as CS-01; no IL2CPP decompilation unless a single number the wiki lacks is needed, and then it is stated.

<a id="cs-03"></a>

### CS-03: Roboquest comps notes

**Card revision:** 2 · **Owner:** Design research · **Size:** M · **Lane:** Comps study

**Source and inputs:** [CS-01](#cs-01) note shape and posture; the installed game (Unreal 4, compiled C++; play notes, frame-counted capture and a pak reader for metadata).

**Dependencies:** [CS-01](#cs-01). **Blocking questions:** None.

**Files touched:** `sketches/core-loop/design-v3/research/comps/roboquest/**`; `comps/maps-compared.md` (the Roboquest column and completion) and `comps/README.md` (method rows, decisions, borrow rows, forge delta, follow-ups) as the CS-02 pattern set; card revision 2 (11 October 2026) widened the files and renamed the comparison four-game.

**Definition of done:** stage anatomy as the lead note (handcrafted stages with branching exits, in-stage objectives and secrets, the basecamp between runs), movement feel with frame-counted values, class perks, production budgets by metadata, and the four-game map comparison completed against Scrapkeep's open-stage-with-pockets shape. Same six-section shape and bans as CS-01.

**Verification and evidence:** as CS-01. **Boundary:** as CS-01; the pak reader is chosen at card start and built from source or a package registry.

## Systems audit add-on (11 November 2026)

Andrew asked on 11 November 2026 for an add-on workstream: find and fix the weakest parts of the game's systems, mechanics and features, with evidence from running the game. It runs beside the world 1 polish program and never pauses or re-scopes a wave. Step 0 is [docs/systems-audit/PLAN.md](docs/systems-audit/PLAN.md); it fills the two numbers Andrew's request left in brackets (first 15 minutes; 10 hours of game time per player type), names which file stands in for the absent `TECH_BIBLE.md`, and records that a headless harness exists, so no harness card is filed. Scope is world 1 (the title, the camp, the dam, the flume and Brindle) and early progression; worlds 2 and 3 are parked (ruling at). Outputs go in `docs/systems-audit/`.

Order and regression rule: [PLAN.md section 5](docs/systems-audit/PLAN.md#5-how-the-passes-run). Live state, including which files each open pull request holds, is on the wave board named in [STATE.md](project-guide/handoff/STATE.md), not here.

Rules for every card: evidence, not claims ("it compiles" or "tests pass" closes nothing; a DoD without its artifact is rejected). A pass that shows the Bible is wrong files a change request and never edits BIBLE.md or an ADR. A pass stays in its own files; a file another thread or an open pull request holds waits or becomes a dependency note to its owner. NEEDS ANDREW only for a cut or merge of a feature, a change that conflicts with a pillar, or a balance fix that needs a design change rather than a number change; every other call is decided and logged as a one-line assumption he can overturn. Each pass ends with a per-system summary (pass status, top open issue, last sim or bot result, what changed, one finding in plain words) for the coordinator's "Systems health" digest. Gate per pull request: the per-PR tier of [ORCHESTRATOR's tiered gate](ORCHESTRATOR.md#light-play-lane), its only owner; docs-only cards use the scoped docs checks in AGENTS.md.

Every card leaves alone the files another thread or an open pull request holds; the card checks the wave board's current fences at claim. Controls and input mapping (`src/core/bindings.gd`, `src/movement/intent.gd`) and the save format (`src/core/run_store.gd`, `profile.gd`, `safe_store.gd`) stay out of scope for the whole workstream.

<a id="sa-a"></a>

### SA-A: Systems map

**Card revision:** 1 · **Owner:** Systems audit thread · **Size:** M · **Lane:** Systems audit (docs only)

**Source and inputs:** BIBLE.md section 1 (Pillars & Fantasy) and section 6 (Core Systems); [STORY-MAP.md](sketches/core-loop/design-v3/STORY-MAP.md) section 4; adr/README.md (TADR-008, TADR-010, TADR-011) standing in for TECH_BIBLE.md; [PLAN.md](docs/systems-audit/PLAN.md) section 2; the 9 Nov "Game systems: audit and plan" doc; world 1 bot runs with a resource ledger.

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/systems-audit/PLAN.md`, `docs/systems-audit/systems-map.md`, this section of BACKLOG.md, one line in `project-guide/handoff/ROADMAP.md`.

**Definition of done:** `systems-map.md` holds every system's inputs, outputs and resources touched; the core loop in one sentence; the five biggest problems first (dominant strategies, dead mechanics, overlapping systems, choices with no tradeoff, feedback the player cannot read); every system tied to a pillar or marked for cut; a before diagram and a proposed after diagram. No code changes.

**Verification and evidence:** the bot-run ledger the problems cite, with its exact command; `npm run check:docs`; `npm run check:project`; one independent review.

**Boundary:** read-only for game code. Cuts and merges it proposes go to SA-D, then to Andrew.

<a id="sa-b"></a>

### SA-B: Economy balance (world 1)

**Card revision:** 1 · **Owner:** a new thread · **Size:** M · **Lane:** Systems audit

**Source and inputs:** BIBLE.md section 6, "Electromagnetic collection, recycling and growth" and "Four slots and milestone progression"; STORY-MAP.md section 4 rows Scrap, Cogs, Cores, Grey panels, Mint items, Cobalt items, the keeper's gamble and the foreman's kindness; TADR-010 ("stage time may scale threat, never gate progression"); [systems-map.md](docs/systems-audit/systems-map.md); the 10 Nov balance re-measure (`handoff/balance-remeasure.md` in the project's shared Library, outside the repo: band win counts at 24 seeds are not a balance sensor).

**Dependencies:** [SA-A](#sa-a). **Blocking questions:** None.

**Files touched:** new `docs/systems-audit/economy/**`; new `sketches/core-loop/tools/sysaudit/econ_*.gd` (a resource-ledger wrapper over `tools/bot_run.gd`, one seed per process, and a shopping-and-choosing policy that buys at Moss, takes the start pick and the tree offers, used for the min-maxer); value tables only in `src/build/fabricators.gd` (`COG_PRICES`, `RESTOCK`), `src/core/start_picks.gd` (the option lists), `src/world/stake_devices.gd` (`HEALTH_SHARES`, `SCRAP_PER_HP_PAID`) and `src/build/panels.gd` (drop table); `src/world/trade_pockets.gd` (odds) only after a fence check with the wave 37 board thread, which holds world scripts. A rate that lives in a held file (`flow.gd` `BURST_PER_STAGE`, `run_state.gd`, `scrap_field.gd`; check board 749 at claim) is a dependency note to its owner, not an edit.

**Definition of done:** a table of every source and sink per resource (scrap, mass, cogs, cores, hull, panels, parts, relics, tree picks, meta unlocks) with rates per game minute; 10 hours of game time per player type (rusher = skipper, completionist = completionist, min-maxer = the new policy), reached as 24 world 1 runs per type (the project's 24-seed rule, about 3 to 4 game hours each) with per-minute rates carried to 10 hours, because of ruling db (long wall-clock runs never stall the work, [DECISIONS.md](project-guide/handoff/DECISIONS.md)); flags for inflation, hoarding, dead currencies and any strategy that wins over 60% of the time; before and after charts from real sim runs; the diff of changed values; the exact sim command.

**Verification and evidence:** ledger files and charts under `docs/systems-audit/economy/`; world 1 bands before and after on 24 seeds (`scripts/challenge/run.mjs`, same seeds each arm); the w1 Novice target in the [difficulty plan](project-guide/handoff/shared/world1/difficulty-plan.md) must not get easier (ruling cu).

**Boundary:** data and value tables only. A fix that needs a rule change, not a number, is NEEDS ANDREW.

<a id="sa-c"></a>

### SA-C: Mechanic depth and feel (world 1)

**Card revision:** 1 · **Owner:** a new thread · **Size:** M · **Lane:** Systems audit

**Source and inputs:** BIBLE.md section 1 "Joyful physical mastery" and section 6 "Movement, camera and active aim", "A committed attack means what it shows" and "Abilities, ultimates and combat rhythm"; TADR-008 (the ability contract); TADR-006 (physics as rates); [LEGIBILITY.md](sketches/core-loop/design-v3/LEGIBILITY.md) section 13; [systems-map.md](docs/systems-audit/systems-map.md).

**Dependencies:** [SA-A](#sa-a). **Blocking questions:** None.

**Files touched:** new `docs/systems-audit/mechanics/**`; new `sketches/core-loop/tools/sysaudit/clip_*.gd`; feedback and mechanic owners not held elsewhere: `src/movement/` except `intent.gd`, `src/combat/` except the files the parked difficulty stack on `claude/w37-difficulty` changes; until pull request 763 lands, also not the files its Heat build holds (`player_ball.gd`, `combat.gd`, `player_fx.gd`, `run_state.gd`, `run_log.gd`, `tuning.gd`, `audio.gd`, `lock_rows.gd`, `stage_locks.gd`) (confirm `warden*.gd` and `rogue.gd` with the wave 37 board thread at claim, as it holds boss and arena work), `src/combat/actives/`, `src/presentation/player_fx.gd` (after pull request 763 lands), `juice.gd`, `vfx.gd`, `machine_fx.gd`, `sfx_bank.gd`; `src/core/game_events.gd` for one new signal (carve). Never controls, input mapping or the save format.

**Definition of done:** for each world 1 mechanic, the decision it asks, the counterplay, the risk and reward, and its feedback for anticipation, impact and recovery; mechanics that ask no decision fixed; feedback added where an action has none; a recorded clip or frame sequence per changed mechanic, reviewed, with a note on what was fixed after review.

**Verification and evidence:** frame sequences from `tools/look_harness.gd` or `tools/eye_film.gd`; a PC film for anything that is a feel call; focused tests and the fast gate per pull request.

**Boundary:** difficulty only gets harder, never easier, through movement (ruling cu).

<a id="sa-d"></a>

### SA-D: Feature fit

**Card revision:** 1 · **Owner:** a new thread · **Size:** S · **Lane:** Systems audit (docs only)

**Source and inputs:** BIBLE.md section 1 (the three pillars and their decision tests) and section 6; [BIBLE_DECISIONS.md](BIBLE_DECISIONS.md); TADR-007 (sketch promotion), TADR-011 (crew); STORY-MAP.md sections 4 and 5; [systems-map.md](docs/systems-audit/systems-map.md); [PLAN.md](docs/systems-audit/PLAN.md) section 2; the candidate mechanics from the thread "Design loops you can't put down" (Heat, Reservoir, Called Shot; `docs/design/loops.md` on draft pull request 763), judged beside this pass's own three. Andrew accepted those three on 11 Nov 2026 at 18:42Z and wants them in before the sitting (ruling da, [DECISIONS.md](project-guide/handoff/DECISIONS.md)), so feature-fit.md logs them as Andrew-approved, not as NEEDS ANDREW; the loops thread builds them behind flags and owns their files.

**Dependencies:** [SA-A](#sa-a). **Blocking questions:** None.

**Files touched:** `docs/systems-audit/feature-fit.md` only.

**Definition of done:** a table of feature, pillar served, player cost to learn, dev cost to maintain, verdict (keep, merge, cut, defer); three new mechanics that extend rules already in the game, each naming the rule it extends and the new decision it creates; every cut, merge and new mechanic sent to Andrew as NEEDS ANDREW; change requests for where the Bible and the game differ (the crew of TADR-011, the four slots, the respec opportunity).

**Verification and evidence:** each verdict cites a file, a receipt or a ledger row; `npm run check:docs`.

**Boundary:** implements nothing.

<a id="sa-e"></a>

### SA-E: The first 15 minutes (world 1)

**Card revision:** 1 · **Owner:** a new thread · **Size:** M · **Lane:** Systems audit

**Source and inputs:** BIBLE.md section 1 "A world worth crossing" and section 6 "Runs, regions, exits and saves"; TADR-010 (open stages and the event director) and [design-v3/TESTING.md](sketches/core-loop/design-v3/TESTING.md), standing in for TECH_BIBLE.md; [FIRST-HOUR.md](sketches/core-loop/design-v3/FIRST-HOUR.md); [STORY-MAP.md](sketches/core-loop/design-v3/STORY-MAP.md); the world 1 audits in [shared/world1/](project-guide/handoff/shared/world1/) (map standard, ruling ct; one ride, ruling cv); SA-C and SA-D outputs.

**Dependencies:** [SA-C](#sa-c), [SA-D](#sa-d). **Blocking questions:** None.

**Files touched:** new `docs/systems-audit/first-15/**`. Layout and tip files are named at claim time after a fence check, because the park JSON, lines and site markers may be held; check board 749 at claim.

**Definition of done:** world 1 mechanics in the order a first-timer meets them; each introduced alone, practised safely, tested, then combined with one earlier mechanic; no tutorial text over one line, teaching through layout; a chart of difficulty and new concepts per minute for the first 15 minutes, with spikes and flat stretches flagged; a playthrough recording; the list of changes. Story beats do not change.

**Verification and evidence:** `tools/eye_film.gd --film=whole` and a first-timer film on the PC; `tools/first_timer.gd -- --table=park` probes.

**Boundary:** no story beat changes; words on screen follow ruling cx.

<a id="sa-f"></a>

### SA-F: Break it (world 1)

**Card revision:** 1 · **Owner:** a new thread · **Size:** M · **Lane:** Systems audit

**Source and inputs:** BIBLE.md section 6 "Runs, regions, exits and saves" (reload never duplicates a reward, refills a death save or resurrects a run); TADR-004 (persistence); TADR-006; [BUG-BAR.md](sketches/core-loop/BUG-BAR.md); [scripts/redteam/README.md](scripts/redteam/README.md).

**Dependencies:** [SA-E](#sa-e) for the first run; none for the sprint-close reruns. **Blocking questions:** None.

**Files touched:** new `docs/systems-audit/break-it/**`; new `sketches/core-loop/tools/sysaudit/break_*.gd` (input spam, sequence breaks, save-and-quit mid-action then resume, every buff stacked with every debuff: curse, wear, stage modifiers, low hull); new `sketches/core-loop/tests/sysaudit_*_test.gd` for each fixed break. A fix inside a held file goes to its owner as a dependency.

**Definition of done:** a table of issue, repro, severity (BUG-BAR), fix, verified (yes or no, with evidence) covering softlocks, infinite resource loops, unkillable states, out of bounds and lost progress; only severity high and above fixed; each unfixed issue a backlog row. A change request to the coordinator for the sprint-close rule (a new dominant strategy or high-severity break reopens the sprint), because ORCHESTRATOR owns the tiered gate.

**Verification and evidence:** the break bot's logs and replay commands; a replay test per fix.

**Boundary:** fixes severity high and above only.

**Pass F's open rows** (11 Nov 2026; repro and evidence in [docs/systems-audit/break-it/](docs/systems-audit/break-it/README.md)):

| Row | What | Severity | Owner | Done when |
| --- | --- | --- | --- | --- |
| SA-F1 | A quit or crash after a stage is cleared and before the next stage is entered continues at the start of the cleared stage: the gates and launch after the dam, and the whole Brindle fight after the flume | Blocker, closed | thread "Keep a cleared stage's earnings on Continue" (`flow.gd`), PR 790 | Closed: PR 790 keeps the earnings for a quit in the launch or the boss fight (seeds 2882 and 2883, measured on head 85461fc8 and on the stage at 5159ce67). The gates case is SA-F5 |
| SA-F2 | `play_watch.gd` logs Sable's mounted pylon as "hung" (also in sitting notes) | Minor, closed | thread "Close the remaining world 1 gaps", branch `claude/w37-watch-mount` | Closed: a ball mounted on a pylon is left out of hung and stuck, pinned by three checks in `tests/play_watch_test.gd`. Seed 2880 no longer writes the hung row on stage 03d96412 with or without the fix, so the replay is no after-measure |
| SA-F3 | One stuck row fighting a plated brute in the flume (seed 2877) | Minor, watch | the red team sweep | no repeat in two sweeps, or three on one stage becomes a finding |
| SA-F4 | Quitting during a rendered launch (under the comic swipe) is untested; headless skips the swipe | Coverage gap | the PC lane | one quit in the swipe on a rendered build, Continue checked |
| SA-F5 | A quit at the open gates replays the cleared stage from its start, by design after PR 790 (re-entering a cleared stage would pay its loot twice) | Minor | after the sitting, if players quit there | save the cleared stage at the break with its loot marked as paid; seed 2884 `--quit-in=gates:3` keeps its 661 cogs |

## World 1 and scaling backlog (12 November 2026)

Andrew asked on 12 November 2026 for as many buildable items as possible: for world 1 now, and for the groundwork that lets the game scale later to more stages, more worlds and deeper features. This section is that list. Each row is one unit: one branch from the open stage, one pull request against it, focused tests plus `npm run sketch:fast`, one independent review, then the board thread stacks it ([ORCHESTRATOR's tiered gate](ORCHESTRATOR.md#light-play-lane) owns the gate). Live state, who holds which file and what is stacked stay on the wave board named in [STATE.md](project-guide/handoff/STATE.md); the order of the alpha stays in [ROADMAP.md](project-guide/handoff/ROADMAP.md). Rows were gathered from the open play findings ([PLAY-FINDINGS.tsv](project-guide/handoff/PLAY-FINDINGS.tsv)), the systems audit ([docs/systems-audit/](docs/systems-audit/PLAN.md)), the world 1 audits ([shared/world1/](project-guide/handoff/shared/world1/)), the wave 38 board (issue 814) and the sound gaps the music thread found on 12 November (`music/soundcheck/sound-gaps-2026-11-12.md` in the project Library).

**How to pull a row.** The ready rows also stand as GitHub issues 818 to 843, labelled "world 1 now" or "scaling groundwork"; each issue links back here, and this page stays the one definition. Read the row's source, check the wave board's fences for its files, claim it with one board comment, and build it. World 1 rows rank ahead of scaling rows (ruling at, ruling cs). A row marked "owned" belongs to the named thread: it is listed so nothing is lost, and another thread does not build it. Mechanics and tuning taste are decided by the builder and logged as one-line assumptions Andrew can overturn. Words a player reads follow ruling cx and [LEGIBILITY.md](sketches/core-loop/design-v3/LEGIBILITY.md) section 13.

**The rule for scaling rows.** A scaling row may not change what the world 1 sitting plays. Each one proves that with a check named in its row: the same bot record on fixed seeds before and after, a content hash that does not move, or a flag that is off by default. If that proof cannot be had, the row waits until after the sitting.

### World 1 now: ready to build

| ID | What the player gets | Files | Size | Proof | Source |
| --- | --- | --- | --- | --- | --- |
| W1-01 | Moss's scale (sell mass for cogs) is on in the sitting launch, like the other two resource mechanics of ruling dd. Today `SITTING_SET` turns on marked hull and carry a core but not the scale, so the sitting would miss one of the three. Taste call: on | `src/movement/tuning.gd` `SITTING_SET`, `tests/tuning_flags_test.gd` | S | `tuning_flags_test`; bots and bands never pass the profile, so no band moves | ruling dd; [economy README](docs/systems-audit/economy/README.md) (scale arm measured). Built 12 Nov on branch `claude/project-thread-cnftmf` |
| W1-02 | The eleven record-only achievements pay something: each gives a paint (a colour row, no new art), so finding a Signal cache or riding a sluice flap is worth chasing in a completionist run | `src/core/achievements.gd`, `src/core/cosmetics.gd`, `src/core/content_registry.gd` (re-pin), `tests/achievement_fill_test.gd` | S | `achievement_fill_test` with `RECORD_ONLY` empty; the cosmetics and content-registry tests | [feature-fit.md](docs/systems-audit/feature-fit.md) row 30. Built 12 Nov on branch `claude/project-thread-cnftmf` |
| W1-03 | Each reward gate carries its own part name and line on the gate, not in small blue text by the ball, so a player can tell which gate gives what (PF-22, major) | `src/ui/world_prompt.gd`, the gate's presentation | M | first-timer reader pass; cloud film stills of both gate scenes; word budget test | PF-22 |
| W1-04 | An event warning points at its place: the "incoming" line gets an edge arrow or ground ring at the spot, not the event's name alone (PF-16, the warning half) | event warning UI, `src/world/events/` presentation only | M | film stills of four events; first-timer reader | PF-16 |
| W1-05 | A danger zone shows its safe side: Brindle's ram and the yard telegraphs draw where to go, not only where the hit lands (PF-16, the telegraph half) | telegraph presentation (`src/presentation/`), boss telegraph rows | M | film stills at the ram's 0.7 s mark; `telegraph` tests | PF-16; [map-audit.md](project-guide/handoff/shared/world1/map-audit.md) unit 2 |
| W1-06 | The ability row explains itself: a greyed slot shows why (cooldown sweep or empty charge), the "2" stack count reads as a count, and the arc gauge by the ball is named once in the notes (PF-21) | ability bar UI (`src/ui/`), `field_notes.gd` | M | film stills 014, 022, 059, 071 re-shot; word budget test | PF-21 |
| W1-07 | Pop-ups never land on story cards: music toasts wait for the prologue's cards to close, and the radio panel folds away after its swell (PF-19) | toast queue in `src/ui/`, the radio dial | S | `screens_prologue_test` extended; film of the prologue | PF-19 |
| W1-08 | Warning lines and toasts reach full contrast fast enough to read ("Bench Dropship incoming" faint at film 068) (PF-20) | toast and warning fade timings (`ui_tokens.gd` only for values) | S | film stills; a timing check in the toast test | PF-20 |
| W1-09 | A lobber's shell trace and landing box read as danger, not as a goal (PF-25) | shell trace presentation (`projectile.gd` look only, or its fx module) | S | first-timer reader on film 090-091 | PF-25 |
| W1-10 | Brindle's target tags sit on the boss part they name, never over the player's ball (PF-35) | boss target tag UI | S | film stills 081-103; a placement check | PF-35 |
| W1-11 | Pickup stat lines stay off the fight: they rise at the HUD edge, not over enemies or the gates' feet (PF-14) | pickup line UI | S | film stills 025, 044 | PF-14 |
| W1-12 | Fewer see-through shapes over the view: arrival rings, the orange frame and the red cage lines thin out once read (PF-27) | the owning fx modules | S | film stills 048, 059, 090; PC still | PF-27 |
| W1-13 | The light cone over the dam yard and the flume Warden fight no longer washes out the middle of the view (PF-07) | the cone's material | S | PC stills against the 12-21% washout measure | PF-07 |
| W1-14 | The camera keeps the ball out of the lens and walls out of half the view in tight fights (PF-06) | camera rig | M | PC film of Brindle's pillars and the dam Warden hit; feel goes on the sitting watch list | PF-06 |
| W1-15 | The radio tip stops sending the player to the notes: the dial draws its own keys the first time it shows (first 15 minutes, change 3) | `src/ui/field_tips.gd`, the radio dial | S | `field_tips` tests; film of the first stage | [first-15 README](docs/systems-audit/first-15/README.md) section 5 |
| W1-16 | The dam Warden's lessons split: the lobber's shell is met on the yard crew's ground before the Warden, and the ultimate prompt gets its own moment when the meter first fills outside a fight (first 15 minutes, change 4; harder sooner, ruling cu) | park dam sites or director rows, `field_tips.gd` | M | 24-seed w1 band read (must not get easier); first-timer probes | first-15 README section 5 |
| W1-17 | More to find on the flume: two or three more side spots (caches on the skill lines, a cracked wall), toward the 30-minute completionist run (the flume has 3 cache spots, the dam many more) | `assets/park/park_flume/` sites and lines | M | map checks; 24-seed band read; completionist bot minutes before and after | map-audit.md "Flume"; ROADMAP completionist re-read (ruling ag). Built 12 Nov on branch `claude/project-thread-cppr1p`: `trestle_cache`, a standing cracked cache on the low canal country under the trestle's turn (the flume's second reward pocket), and `grade_wall`, a hidden cache room on the canal grade sealed by a cracked wall that files the codex row "Overtime Locker" (camp count 8). A cracked wall can now seal a cache as a valve does (`contraptions.gd`); `tests/flume_side_spots_test.gd`. Assumptions Andrew can overturn: the trestle cache pays common or rare, the locker no marker |
| W1-18 | A power read: a lab run where a bot plays the parts' abilities and buys toward a maker pair, to say whether 16 parts beat 3 and whether a maker pair is worth chasing | `tools/sysaudit/` (lab only, no game code) | M | the run's ledger and its exact command in `docs/systems-audit/economy/` | economy README "Follow-ups" |
| W1-19 | Quit during a launch on a rendered build (under the comic swipe) and Continue: proven, not assumed (SA-F4) | PC lane run only | S | one rendered quit, Continue checked, receipt on the board | [SA-F](#sa-f) row SA-F4 |
| W1-20 | The two dense-fight frame findings re-measured alone on an idle PC: the 107 s stage 1 hitch and the dense-fight CPU p99 (PF-44, PF-45) | PC lane run only | S | MangoHud or the frame probe on an idle 4080, medians of 3 | PF-44, PF-45 |

### World 1 now: owned by another thread (listed, not built here)

| ID | What | Owner |
| --- | --- | --- |
| W1-30 | Re-land the difficulty stack with its three behaviour reds fixed: pocket entry fairness in five pockets, the ultimate firing one short of its crowd, the flume small-ball band (board 814, 15:02Z) | "Tune dam yard and Brindle pressure" |
| W1-31 | w1 Novice to 15% or less from 35%; Brindle's worst minute at least the dam Warden's share of max hull; the flume's opening not a rest ([difficulty plan](project-guide/handoff/shared/world1/difficulty-plan.md), first-15 change 5) | "Tune dam yard and Brindle pressure" |
| W1-32 | Overtime sounds like a risk, not the arena's safety bells (sound gap 3) | "Make music follow game states" |
| W1-33 | Heat's own sounds: rises, cooling and a hot hit (sound gap 5) | "Make music follow game states" |
| W1-34 | Danger cues join the threat register so they get the bass dip and warning focus (sound gap 6) | "Make music follow game states" |
| W1-35 | Brindle's five attacks each get their own telegraph sound (sound gap 7) | "Make music follow game states" |
| W1-36 | The flume's head-gate siren stops sharing the beacon hum (sound gap 8) | "Make music follow game states" |
| W1-37 | Ride and set-piece sounds made for the `sound_next` stand-ins, movement first (sound gap 9) | "Make music follow game states" |
| W1-38 | The camp jukebox gets a real record-on sound, then the rest of camp (sound gap 10) | "Make music follow game states" |
| W1-39 | Menu move, confirm and back sounds on every page under a pad (sound gap 11) | "Make music follow game states" |
| W1-40 | A ready ultimate, a found item and a failure stop sharing the same generic sounds (sound gap 12) | "Make music follow game states" |
| W1-41 | The sound fallback test reads every row kind and `sound_next`, and flags two facts sharing one heard sound (sound gap 13) | "Make music follow game states" |
| W1-42 | Sounds for the silent fight states and the facts with no listener: guard about to break, beacon opening, missed drop, drop landed, evolution (sound gaps 14, 15) | "Make music follow game states" |
| W1-43 | The recorded band keeps its lead at a run's start (sound gap 16; a one-line call) | "Make music follow game states" |
| W1-44 | Pilot select opens on the first pilot the profile can take (PF-40, PR 816 for wave 39) | "Close the remaining world 1 gaps", then the board thread |
| W1-45 | The twin-line grapple prototype (PR 771) waits on Andrew's feel check | the board thread |

### World 1 after the sitting (already ruled to wait)

| ID | What | Source |
| --- | --- | --- |
| W1-50 | A quit at the open gates keeps the cleared stage: save at the break with its loot marked paid (SA-F5) | [SA-F](#sa-f) |
| W1-51 | After Brindle's rout, a rim kicker launches the ball out of the Slag Bowl toward the Dig under the swipe (T7) | [transitions-audit.md](project-guide/handoff/shared/world1/transitions-audit.md) |
| W1-52 | The dam launch rides up the face and over the crest with the reservoir in view (T8) | transitions-audit.md |
| W1-53 | An authored concave Warden yard with a berm rim in place of the half bowl | map-audit.md unit 8 |
| W1-54 | A reactive works lever: a valve that drains a lobber ledge | map-audit.md unit 9 |
| W1-55 | Dam perf remainders: the f4045 riser, the Warden break and engage spikes, the seed 3 f14k swing | [STATE.md](project-guide/handoff/STATE.md) "Parked" |
| W1-56 | Type the four audio files worker threads run and add a cold two-thread stress test | issue 593 |
| W1-57 | Arrivals on the musical grid | difficulty-plan.md "Arrivals on the grid" |
| W1-58 | A second cog sink on the main route for a player who skips Moss | economy README "Follow-ups" |

### Scaling groundwork: ready now, world 1 unchanged

Read from the code on `stage/alpha-w38` (48f62bf9), 12 November 2026. Adding a world today means writing it into code by hand wherever the code names a world, a map or a world boss outright (`world == 1`, `for world_id in [1, 2, 3]`, `== "mind"`, map ids as strings, including per-map data written as code). `tests/new_world_cost_test.gd` (SG-01) counts those places: 109 in 32 files on 12 Nov. A new enemy kind touches nine places beside its roster row. Each row below removes one of those costs and keeps every world 1 value as it is. [ALPHA-PLAN.md](sketches/core-loop/design-v3/ALPHA-PLAN.md) ("New worlds ... enter through registered tables") and [SOUND-BIBLE.md](sketches/core-loop/design-v3/SOUND-BIBLE.md) "Adding a world" already set this direction; these rows close the gap between that text and the code.

| ID | What it makes cheaper | Files | Size | Proof that world 1 is unchanged | Notes |
| --- | --- | --- | --- | --- | --- |
| SG-01 | A test that counts every place the code names a world, a map or a world boss outright, outside the tables that own those facts, as a ratchet of one pin per file: a new site fails it, and a removed site asks for its pin to be lowered, so "how many places does a new world touch" is a number on every gate (109 sites in 32 files on 12 Nov) | `tests/new_world_cost_test.gd`; `scripts/sketch-fast.mjs` runs it on every pull request | S | test only; a planted `world == 4` fails it | Built 12 Nov on branch `claude/project-thread-cnftmf`. Assumption Andrew can overturn: a code scan with pins, not a four-world test double, because it counts every site without driving a run. It is the yardstick for SG-02 to SG-08 |
| SG-02 | Each world row owns its own facts: `final` (the run ends after its boss), `scenery` (its scenery hook), `world_one_rules`, `ending_log`. `flow.gd` stops asking whether the boss music is "mind", `game.gd` stops naming three scenery hooks, `screens.gd` stops looping over `[1, 2, 3]` | `src/core/worlds.gd`, `flow.gd`, `game.gd`, `ui/screens.gd`, `ui/ending_sequence.gd` | M | same bot record on fixed seeds; `world_table_test`, ending and flow tests | `flow.gd` and `game.gd` are the board thread's files: claim through the board |
| SG-03 | One home for the stage tables' shared helpers and pack constants: `alpha_defs.gd`, `park_defs.gd` and `slice_defs.gd` keep only their rows and real differences | `src/core/alpha_defs.gd`, `park_defs.gd`, `slice_defs.gd`, a new shared module | S-M | `stage_table_test`, `alpha_table_test`, row digests unchanged | |
| SG-04 | The park schema reads which map is which stage from the stage table, and the pocket draw reads `ctx.stages` instead of preloading the park table | `src/world/park/park_schema.gd` (`MAP_STAGE`, `PARKS`), `src/world/pockets/pocket_draw.gd` | S | the same pocket draw on every map for fixed seeds; `pocket_library_test`, `park_schema_test` | |
| SG-05 | A new enemy kind gets a test that names what it is missing: every director kind must be a built roster row with a chassis row, a director card, a windup row and a telegraph record (unless its roster row says it never attacks), and every built roster kind must be a director kind or a known non-pack kind. Known gaps are listed and must stay exact (today: no chassis for the world 3 `ballast_heavy` and `gap_net`) | `tests/kind_wiring_test.gd` | S | test only; a card renamed away fails it | Built 12 Nov on branch `claude/project-thread-cnftmf`. `KIND_NAMES` stays hand-kept for now, because the director's kind enum and `director_rows_test.gd` read positions in it; deriving it from the roster in today's order is a follow-up. Assumption Andrew can overturn. `spillway_roster_test.gd:92` checks part of this for the four Spillway kinds |
| SG-06 | Pockets per world: the pocket library reads `pockets/w<N>/` (or a `worlds` key) instead of `w1/` only, defaulting to world 1 | `src/world/pockets/pocket_library.gd`, `pocket_draw.gd` | S | the same draw on all six maps for fixed seeds | trade pockets and stage modifiers are world-agnostic code tables; a `worlds` column for them is a follow-up |
| SG-07 | Per-world numbers live in world columns, not code branches: the hot-wire cap (`world <= 1`) and the panel drop table by world | `src/build/parts.gd`, `src/build/panels.gd`, `src/core/worlds.gd` | S | values identical per world; parts and panels tests | a content hash may re-pin for the move alone; say so in the commit |
| SG-08 | Per-map data written as code moves beside its map: world effects specs and ambient kinds keyed by map id | `src/presentation/world_fx/world_fx_specs.gd`, `src/core/ambient_kinds.gd`, park JSON or one row file per map | M | identical specs read back per map; a film still of the dam unchanged | |
| SG-09 | The content registry also checks the stage tables, the roster, the pockets and the world rows (schema, references, a minimum row count, a golden hash), so a broken row fails at admission instead of in a run | `src/core/content_registry.gd`, `tests/content_registry_reach_test.gd` | M | new checks pass on today's rows | |
| SG-10 | Adding a part is one row: the alpha part whitelist that park reuses is derived or retired, after checking why it exists | `src/core/alpha_defs.gd` (`PARTS`), `src/build/parts.gd` | S-M | the same offer pool per stage on fixed seeds | read the whitelist's history first; if it is deliberate, write the reason in its comment and close the row |
| SG-11 | One checklist for adding a stage, a world, an enemy kind, a pocket and an item, naming each file it touches, kept true by SG-01 and SG-05 | the "registered tables" paragraph of `design-v3/ALPHA-PLAN.md` (updated in place, ruling bz) | S | docs checks | update it as each SG row lands |
| SG-12 | World 2 findings carry the right label: PF-42 and PF-43 say "World 1 stage 3" and "stage 4", but stages 3 and 4 are the Dig (world 2), so neither holds the world 1 sitting | `project-guide/handoff/PLAY-FINDINGS.tsv` | S | `check:docs` | done with this section |

### Scaling: feature depth (built behind a flag, or after the sitting)

| ID | What the player gets later | Files | Size | When | Source |
| --- | --- | --- | --- | --- | --- |
| FD-01 | Run modifiers become real: a module builds the shift board's open seeds behind `--run-modifiers=on` (off by default), starting with "short crew" (no dam shop, a cache instead) as the cheapest. Before it ships, the seed named "overtime" gets a new name, because Overtime is already the Reservoir mechanic (one name for one thing, ruling cx) | `src/core/shift_board.gd` `SEEDS`, a new module, a new test | M | behind the flag now; on after the sitting (ROADMAP phase 2, item 2) | shift_board.gd "Seeds for the layered variation" |
| FD-02 | Stage variants: the dam night shift (floodlights, a fuller crew, one more cage) and the flume backwash, as park JSON variants a run can draw | `assets/park/park_dam/`, `park_flume/`, `stage_modifier.gd` | L, split per variant | after the sitting (map-audit.md says no variants before it) | shift_board.gd seeds; map-audit.md unit 10 |
| FD-03 | Unlock-gated anticipation: the shift board's punch cards run past three, each new card opens an item into the pool, and the board shows the next one coming | `src/core/shift_board.gd` `CARDS`, items | M | after the sitting (moves the offer pool, so a band read) | ROADMAP phase 2, item 2 |
| FD-04 | Item rungs above cobalt can be written as rows: the rarity table accepts pearl and gold rows with zero drop weight, validated, with no content yet | `src/build/item_gen.gd` `RARITY`, content registry | S | now, if the drop tables stay identical; content after the alpha (ruling bn) | ROADMAP phase 3 |
| FD-05 | The Mind's offerings (purple): a temporary buff, then a permanent item, then more | spec first | M | after the alpha | queued-cards ITEM DEALS, 23 Oct |
| FD-06 | Three-phase Waking and Mind fights with their anthem phase covers, and two-phase mini-bosses in worlds 2 and 3 | `src/boss/waking.gd`, `mind.gd`, `fight_phases.gd` | L, split per boss | phase 2, when ruling at lifts | ROADMAP phase 2, item 3 |
| FD-07 | Staged story beats in worlds 2 and 3, as world 1 has (cold open, Rivet, the reveal, the clear card) | story rows, `design-v3/STORY-MAP.md` | M per world | phase 2 | ROADMAP phase 2, item 3 |
| FD-08 | World 2 stuck spots fixed before world 2 is played: the sinkhole pin (PF-41), the Dig Warden that never breaks (PF-42) and the broken Warden with no exit gate (PF-43), each replayed first | world 2 maps and bots | M each | phase 2 | PF-41 to PF-43 |
| FD-09 | The set director's sections and the boss phase tracks per world: folding `phase_music.gd`'s per-boss dictionaries and the engine's per-boss sections into music rows, so a world's music is rows and recordings | `src/presentation/phase_music.gd`, `music_engine.gd`, `music_rows.gd` | M | owned by "Make music follow game states" | SOUND-BIBLE "Adding a world" |
| FD-10 | Bible questions to settle before world 2: the scrap-bot crew of TADR-011 (defer or schedule), and a respec opportunity (a world 2 rescue reward) | change requests 1 and 2 in feature-fit.md | S each | NEEDS ANDREW, after the sitting | feature-fit.md "Change requests" |
