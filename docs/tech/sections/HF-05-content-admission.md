# HF-05: Stable content identity and admission

## Sources

This section implements [HF-05](../../../BACKLOG.md#hf-05) revision 2 at source base `7a73c5b5f44806c83924661b054051818174f07e`. It specifies production contracts without authoring a catalogue, selecting content or running Godot.

- [TADR-003 decision](../../../adr/TADR-003-content-pipeline.md#decision), lines 23–35, owns typed text Resources, stable IDs, validation, immutable definitions, safe reload and content pinning. Its later qualification section requires per-type codec coverage.
- [TADR-004 decision](../../../adr/TADR-004-persistence.md#decision), lines 24–34, owns content-revision references, stable offers, derived reconstruction and explicit migrations. Its consequences forbid silently remapping missing content or discarding supported runs.
- [HF-01](HF-01-production-conventions.md) revision 3, admitted at `a618e2602b7218efb03ee6be7d2ed05b32f44da6`, owns production paths and import-settings prerequisites. [HF-03a](HF-03a-module-map.md) revision 1, admitted at `3f56a82ea7b74ebd6769b5ea50653d9d2452453a`, owns module commands and records. Their admitted bytes are present at the base above.
- [Asset provenance](../../project/ASSETS.md) requires source, creator/provider, license evidence, transformations and actual use before asset admission. Generated references and prototype examples are not production selections.
- Bible [four slots](../../../BIBLE.md#four-slots-and-milestone-progression), [equipment](../../../BIBLE.md#inventory-equipment-and-transformations), [fixed secrets](../../../BIBLE.md#themed-loot-attunement-and-fixed-secrets), [committed attacks](../../../BIBLE.md#a-committed-attack-means-what-it-shows), [devices and companion](../../../BIBLE.md#devices-and-one-main-companion), and [runs and saves](../../../BIBLE.md#runs-regions-exits-and-saves) supply the semantic obligations below.
- [S0-05](../proofs/S0-05-content-identity.md) and [S0-06](../proofs/S0-06-content-admission.md) were admitted together at `f8cf03fb463f009ebdaa2aefed087e30919aeb90`; author candidate `ca033b338a1bfb6fddf9aefebe0cc1c0c2708e45`. Their source tree `native/proofs/tadr-003/` has Git tree identity `a20f18dee50cde23191786696a1110471ed6f0a4`. The [source SHA256 manifest](../../../artifacts/prepare-stage-2026-09-06/tasks/S0-05/sha256-manifest.txt), [normal run](../../../artifacts/prepare-stage-2026-09-06/tasks/S0-05/run-normal.txt), and [fault run](../../../artifacts/prepare-stage-2026-09-06/tasks/S0-05/run-inject-fault.txt) retain exact source and observed results. Current source inspection matches those seven manifest entries; this is not a new run.

## Contract

### Identity, versions and owners

A domain ID identifies one authored definition across file moves and display-name changes. It is an opaque, nonempty, case-sensitive token issued with that definition and compared exactly. Once issued, it is not reassigned to an unrelated definition. A revised version of the same domain definition can retain its ID, while changed gameplay uses a distinct gameplay content revision. The production ID grammar and schema fields belong to HF-06a and the producing SC cards; the proof's `proof.` prefix is not a production naming rule. Neither a filename, HF-01 `<unit>` directory, engine UID nor Resource cache key is a durable identity. Display names may change or collide without changing IDs.

| Identity | Meaning and rule | Owner and consumer |
| --- | --- | --- |
| Domain ID | Unique in the complete catalogue being admitted, including across source files. Foreign references identify this token and their expected definition family. A duplicate rejects the candidate; load order never chooses the winner. | Content authors issue IDs; ContentAdmission validates and resolves them. |
| Gameplay content revision | Identifies the immutable gameplay definition set and its compatibility rules. A gameplay-affecting definition change requires a distinct revision. Reusing a revision with different gameplay meaning is forbidden. The token has no assumed numeric ordering. | ContentAdmission publishes it; Session pins it; Persistence records it with saved domain IDs. |
| Catalogue revision | Identifies one immutable admitted catalogue and asset-manifest snapshot, including exact definition/source references and validation results. A replacement gets a new identity. A presentation-only replacement may retain the gameplay content revision only after validation establishes identical gameplay definitions and compatibility. | ContentAdmission owns the registry and handle mapping. Session selects an eligible handle at a safe boundary. |
| Definition source identity | Path, source revision and content digest locate the reviewed bytes. These diagnose changes and rebuild imports; they do not replace the domain ID or saved gameplay content revision. | Content authors and Technical art supply provenance; ContentAdmission retains the admitted manifest. |

A `CatalogueHandle` binds catalogue revision and gameplay content revision to one immutable definition set and matching asset manifest. A saved `(gameplay content revision, domain ID)` must resolve to the same gameplay meaning even if more than one presentation-only catalogue snapshot supports it. Never resolve a saved ID through an unqualified “latest” catalogue. If that mapping is absent or ambiguous, return a diagnostic and hold the affected start, restore or transition.

Use HF-01's `native/content/<unit>/definitions/` for canonical `.tres` definitions, schema scripts and catalogue source. Scenes in the sibling `scenes/` family reference definitions and supply composition, never a second damage, milestone or compatibility value. Asset inputs and their provenance follow the `assets/` and `source-assets/` families. Generated imports are rebuildable. HF-01's TH-19 prerequisite blocks the first imported production asset until reviewed import settings survive staging and a fresh-copy import/export proof; HF-05 does not repair `.gitignore` or waive that gate.

ContentAdmission alone mutates `CatalogueAdmissionState` and `CatalogueRegistry` through the existing HF-03a commands `stage_catalogue`, `validate_candidate`, `admit_catalogue`, `resolve_id`, `retain_revision` and `release_revision`. Session alone selects run bindings and authorizes admission boundaries. Persistence receives a resolver through Session; it never writes catalogue records. Presentation consumes admitted handles or diagnostic values, with no mutation callback into ContentAdmission or Session.

### Immutable definitions and fresh records

`stage_catalogue` creates an isolated candidate definition graph. It cannot edit an already admitted Resource, its nested collection, a referenced subresource or an engine-cached object that an existing handle can reach. Validate the exact staged bytes and dependency identities. If any source or dependency changes after validation, restart candidate validation; prior results cannot qualify different bytes.

Admission publishes immutable `DefinitionView` values or handles whose API does not expose writable aliases. Prevent definition setters and accumulating per-run fields on the admitted path. Engine type hints, a private-looking field name and the `.tres` extension provide no such enforcement. The future implementation must demonstrate that nested writes through a consumer cannot alter the shared admitted definition or another run's state.

Session and Encounter construct fresh owned records from admitted definitions for health, selections, inventory, effective effects, device state and companion assembly according to HF-03a. Copy only the values their owner needs; mutable nested collections and referenced objects must be independent. A distinct record type is valid. A deep-copy operation is valid only when its actual nested graph is verified independent; do not assume a method name proves this for every future schema. No definition method accumulates session state.

S0-05's particular `SlotTreeDefinition` fixture shows `duplicate(true)` isolation for its exported packed arrays and revision field; shallow `duplicate()` shares packed-array storage on the recorded engine. Preserve that negative case when qualifying production record construction. This proof does not make every Resource deeply immutable or establish all future schema-copy behavior.

### Validation gates

Structural and semantic checks are separate. Both must pass before `admit_catalogue`; typed parsing alone is insufficient. Validators return findings without installing partial results.

| Gate | Required checks | Failure consequence |
| --- | --- | --- |
| Import and source | Reviewed text Resource/schema and scene inputs; import results and settings match the source manifest; required provenance exists; runtime dependencies are available. A concept or proof fixture is never admitted merely by placement in a folder. | Candidate stays unavailable. Preserve the authored input and diagnostics. |
| Structural/domain | Required fields and types, nonempty/unique IDs, supported schema representation, valid reference shapes. Each slot tree has 15 unique nodes, 14 edges, eight endpoints, one root, two children per nonterminal, full connectivity, no cycle or reconvergence. | Reject the candidate as a unit. Report the definition, rule and relevant node/reference. |
| Cross-reference/semantic | Every referenced ID exists in the candidate or an explicitly declared compatible immutable dependency revision and has the expected family. Validate selected-lineage constraints; weapon and mobility start access; main-skill and ultimate world-one access; endpoint and recipe references; declared effect compatibility. Unknown required rules block that content's admission. | No default substitution, remapped ID, partial catalogue or implicit product answer. |
| Manifest and compatibility | Definition bytes, dependencies and asset manifest agree with the proposed catalogue/content revisions. Scene composition does not override canonical gameplay values. Committed geometry and presentation references obey the shared attack contract. Supported saved content remains resolvable or has an explicitly qualified migration. | Reject inconsistent bytes or unsupported compatibility; retain existing handles and saves. |

A completed selected lineage is one connected root-to-endpoint path with three binary choices and no crosspathing. During progression, the current selection is a connected unlocked prefix of that lineage; validation must not require an endpoint before it is earned. Validate authored constraints at admission and validate actual loaded selections again at the Session/Persistence boundary. Weapon and special mobility start available; main skill and ultimate unlock during world one. Exact node effects, costs, milestone allocation and respec opportunities remain content/product work. The validator cannot invent them to make a candidate pass.

Acquired inventory and equipped selections remain distinct. Definitions declare effects and compatibility; Session rebuilds `EffectiveBuild` from current equipped selections and selected tree paths. Removed equipment stops contributing. Repeated equip/load does not accumulate another effect. Tree respec needs its separate authorized opportunity, even when equipment changes are permitted between fights.

Fixed recipe definitions refer to eligible selected endpoints and produce the same effect for the same combination. Respec out of eligibility removes the derived active bonus while retaining discovery knowledge. Loading preserves actual offered choices and resolved rewards without rerolling; a seed is not a replacement for those choices. This section authorizes no particular recipe, item, character, device capacity or companion lifecycle field. The eight-family coverage matrix and schema examples remain HF-06a and SC work.

### Admission states and permitted transitions

The seven names describe a candidate's admission progress plus its relationship to a run. `pinned` is an admitted revision retained for a specific run, not a writable fork. `rejected-reload` records the failed replacement candidate, never the still-valid active catalogue. Multiple candidate/revision records can coexist. An initial failed candidate returns to `draft`; a failed replacement is recorded as `rejected-reload` so retention is visible.

A safe admission boundary is Session's explicit barrier after the outgoing encounter has stopped advancing and consuming commands/results, before a replacement encounter starts. Initial admission uses the same barrier with no outgoing encounter, before the first encounter can start. No outstanding consumer may be redirected mid-tick or mid-attack. Admission changes the registry's eligible handle; it does not rebind an already pinned run. Session may pin a new run only before its first encounter and may restore a run only before gameplay resumes. Editor preview stays outside these gameplay boundaries. Pause or an idle frame alone is not admission permission.

| State | Meaning | Owner and permitted outgoing edges |
| --- | --- | --- |
| draft | Private editable source; no gameplay handle. | Author edits; ContentAdmission stages. E01, E02, E15. |
| imported | Isolated staged inputs and import dependencies are available for validation. | ContentAdmission. E03, E08, E11. |
| structurally valid | Types, IDs and local domain structure passed on the candidate identity. | ContentAdmission. E04, E09, E12. |
| semantically valid | Cross-references, gameplay constraints and manifest compatibility passed; publication still waits. | ContentAdmission with Session permission. E05, E10, E13, E16. |
| admitted | An immutable whole catalogue/manifest handle is available for an authorized binding. | ContentAdmission publishes; Session selects. E06. |
| rejected-reload | A failed replacement candidate and its findings are retained; prior catalogues remain valid. | ContentAdmission records rejection; author corrects a fresh candidate. E14. |
| pinned | A run binding retains an admitted gameplay revision; unavailable required content holds restore. | Session owns binding; ContentAdmission owns retention. E07. |

The transition table is exhaustive for this contract. A self-edge means the identity and applicable immutable bytes stay unchanged, except editable drafts. Correcting a validated/rejected input creates a fresh draft candidate; admitted and pinned bytes never move backward for editing.

| Edge | From | To | Operation, owner and guard | Safe boundary and result |
| --- | --- | --- | --- | --- |
| E01 | draft | draft | Author edits a private candidate or previews it. | Authoring/preview only; no gameplay handle. |
| E02 | draft | imported | ContentAdmission stages the reviewed candidate and resolves import/source dependencies. | Isolated candidate workspace; active handles untouched. |
| E03 | imported | structurally valid | `validate_candidate` passes the structural/domain gate on the staged identity. | No gameplay publication. |
| E04 | structurally valid | semantically valid | `validate_candidate` passes semantic and manifest/compatibility gates on the same identity. | No gameplay publication. |
| E05 | semantically valid | admitted | `admit_catalogue` rechecks candidate identity and Session permission, then publishes one whole immutable handle. | Session admission barrier; existing pins unchanged. |
| E06 | admitted | pinned | Session selects the exact content revision and calls `retain_revision` before installing fresh live records. | New-run start, validated restore, or durably committed migration at the Session barrier before encounter resume. |
| E07 | pinned | pinned | Resolve/read the same handle, reload a compatible saved binding, or observe another catalogue's admission. | Reads use the pin; restore waits for validation; no hot remap. |
| E08 | imported | draft | Initial candidate fails a gate or its bytes/dependencies change; report and restart as a fresh editable candidate. | Before publication; no active state changed. |
| E09 | structurally valid | draft | Initial candidate fails semantics or is edited; discard its validation status and restart. | Before publication. |
| E10 | semantically valid | draft | Initial candidate changes or fails the final identity/permission check. | Before publication; a merely delayed barrier may instead use E16. |
| E11 | imported | rejected-reload | Replacement fails import/structural checks. | Record rejection in candidate state; old admitted/pinned handles remain. |
| E12 | structurally valid | rejected-reload | Replacement fails semantic or reference checks. | Record rejection; no current catalogue/revision change. |
| E13 | semantically valid | rejected-reload | Replacement identity changes or final admission checks fail. | Reject before swap; a merely delayed barrier may instead use E16. |
| E14 | rejected-reload | draft | Author starts a corrected fresh candidate with the rejection linked for diagnosis. | Authoring only; old handles remain live. |
| E15 | draft | rejected-reload | Replacement cannot complete staging/import. | Preserve source and error before any published handle. |
| E16 | semantically valid | semantically valid | Await Session's barrier without editing validated bytes or dependencies. | No publication while permission is absent. |

Failure handling never mutates the old catalogue into `rejected-reload`. If an initial import fails before E02 completes, E01 retains the draft and its diagnostics. With no admitted handle, gameplay cannot start. A successful admission does not imply production qualification, distribution approval or authorization to create a run.

### Diagnostics and pinned compatibility

`ContentReferenceFailure` is the diagnostic for a required missing ID, missing revision, wrong family or incompatible revision at admission or resolution. It is a published value from ContentAdmission, not an exception callback that edits the run. Its required fields are:

| Field | Meaning |
| --- | --- |
| `code` | One of `missing_id`, `missing_revision`, `wrong_family`, `incompatible_revision` or `ambiguous_revision`. These distinguish the corrective action. |
| `operation` | `validate_candidate`, `resolve_id`, or the caller context `start`, `restore`, `migration` supplied with that request. |
| `requested_id` | Exact domain token, or explicit null when the revision itself cannot be resolved. |
| `expected_family` | Required definition family, or explicit null for a whole-revision lookup. |
| `requested_content_revision` | Exact gameplay revision requested by the candidate or saved binding. |
| `catalogue_revision` | Catalogue being inspected, or explicit null if no such handle is available. |
| `referrer` | Definition ID and field path, or saved-record group and field path. It locates the broken reference without copying private save payloads. |
| `candidate_identity` | Staged source revision/digest when validating; explicit null for a pure pinned lookup. |
| `available_revision` | An observed alternative, if relevant, or null. Diagnostic context only; never an instruction to substitute it. |
| `held_operation` | The candidate admission, start, restore or migration that must remain incomplete. |
| `message_key` | Stable presentation message identity explaining unavailable/incompatible content and the blocked action. Final player copy belongs to the interface contract. |

Other admission failures use `ContentAdmissionFailure` with `rule`, candidate identity, definition ID if known, field/node/reference location, source path, expected/observed constraint and current catalogue revision. Duplicate-ID diagnostics name both conflicting sources. Paths appear only as diagnostic locations; resolution still uses IDs. No raw save data or credentials belong in a message.

Compatibility has three outcomes. An exact available gameplay revision with all valid IDs may resolve through its retained handle. A different revision requires an explicit schema/content migration that validates the complete candidate and commits through Persistence before Session changes the live pin. Missing, incompatible, newer unsupported or ambiguous content refuses the affected operation and preserves source data. Neither identical display names nor a plausible default establishes compatibility.

For a migration, retain both source and candidate handles during staging. Admit and validate the target independently, retain it before use, then install its new run binding only after Persistence returns the durable acknowledgement. Until that point the source pin remains authoritative and the transition is held. E06 establishes the target binding and E07 preserves the source binding while pending. HF-07b, HF-08 and HF-09 own detailed commit, failure and migration protocols; this section specifies no new save stage or rollback policy.

`release_revision` releases a particular live reference; it does not authorize deleting content required by a supported saved run. Catalogue retirement and support windows require the later explicit persistence/release contract. No retention count, expiry period, automatic “oldest” deletion or forced migration is chosen here. Definitions needed by a currently active run remain available and unchanged across encounter replacement. New content may become eligible for new runs while the existing run stays pinned.

## Scenarios

All four traces are tabletop cases over the E01–E16 table, not engine runs. Tokens A and B are illustrative immutable catalogue handles, not production IDs or revision formats. Preconditions establish records already in the named starting state; each trace step uses an explicit edge.

### T1: A draft stays outside gameplay

Precondition: one private candidate is `draft`; no handle exists for it.

| Step | Subject | Edge | From | To | Action and observable result |
| --- | --- | --- | --- | --- | --- |
| T1.1 | candidate A | E01 | draft | draft | Rename its file and display label without changing its domain ID. Preview sees the draft; gameplay does not. |
| T1.2 | candidate A | E02 | draft | imported | Stage its reviewed source/import dependency set in isolation. No active handle changes. |
| T1.3 | candidate A | E08 | imported | draft | A required typed field is absent. Publish a rule/location diagnostic and restart a fresh editable candidate; no partial definition becomes resolvable. |

### T2: A definition becomes admitted

Precondition: candidate A is `draft`, has provenance, satisfies the applicable authored rules and has no unresolved required semantic value.

| Step | Subject | Edge | From | To | Action and observable result |
| --- | --- | --- | --- | --- | --- |
| T2.1 | candidate A | E02 | draft | imported | ContentAdmission stages canonical definition, scene references and reviewed asset inputs. |
| T2.2 | candidate A | E03 | imported | structurally valid | Structural validation accepts unique IDs, fields and fixed tree shape; no live handle yet. |
| T2.3 | candidate A | E04 | structurally valid | semantically valid | All expected-family references, access rules, recipe endpoints and manifest/compatibility checks pass. |
| T2.4 | candidate A | E16 | semantically valid | semantically valid | Session is still inside an encounter. Keep the candidate private and immutable while awaiting its barrier. |
| T2.5 | candidate A | E05 | semantically valid | admitted | At the authorized barrier, identity is unchanged; publish A as one whole catalogue/manifest pair. |
| T2.6 | candidate A | E06 | admitted | pinned | Session starts an authorized new run on A and builds fresh records. Mutating its inventory cannot mutate A's definitions. |

### T3: A rejected reload preserves the current catalogue

Precondition: A is admitted and pinned by an active run; replacement B is a fresh `draft`.

| Step | Subject | Edge | From | To | Action and observable result |
| --- | --- | --- | --- | --- | --- |
| T3.1 | candidate B | E02 | draft | imported | Stage B without modifying A or shared cached Resources. |
| T3.2 | candidate B | E03 | imported | structurally valid | B's shapes and field types pass. Passing types alone grants no admission. |
| T3.3 | candidate B | E12 | structurally valid | rejected-reload | A recipe references an absent endpoint ID. Return `ContentReferenceFailure` with exact ID, revision and referrer; eligible catalogue remains A. |
| T3.4 | run A binding | E07 | pinned | pinned | The run continues resolving A. Its selections, stable offers and current effective effects are unchanged. |
| T3.5 | candidate B | E14 | rejected-reload | draft | Author creates a corrected B candidate. It must repeat import and both validation gates before another admission attempt. |

The S0-06 malformed-tree case exercises the earlier structural failure E11 and retained dictionary behavior. T3's semantic failure is deliberately broader and remains paper evidence.

### T4: An active run keeps its pin across a newer admission

Precondition: A is `pinned` by a run and B has independently reached `semantically valid`. B changes a gameplay definition, so it has a distinct gameplay content revision.

| Step | Subject | Edge | From | To | Action and observable result |
| --- | --- | --- | --- | --- | --- |
| T4.1 | candidate B | E05 | semantically valid | admitted | Session authorizes B at an encounter barrier. B becomes eligible without rebinding the run on A. |
| T4.2 | run A binding | E07 | pinned | pinned | Session replaces the encounter and restores fresh encounter records against A's retained definitions. No definition is looked up through B merely because it is newer. |
| T4.3 | run A binding | E07 | pinned | pinned | A saved offered choice resolves by its saved ID and A's gameplay revision. Restore validates selections; it does not reroll the offer or stack a recipe bonus. |
| T4.4 | run A binding | E07 | pinned | pinned | Suppose required A content is unavailable in a later load environment. Emit `missing_revision` or `missing_id`, hold restore, and preserve the saved binding and source. B is not substituted. This self-edge preserves the requested binding, not a claim that unavailable content is playable. |
| T4.5 | candidate B | E06 | admitted | pinned | A separate authorized new run may bind B after its own start validation. This does not change the original run's pin or erase its saved data. |

## Unresolved questions

HF-06a and SC-01 through SC-08 own family coverage, ID grammar and actual schema fields; HF-06b owns save projections. Their absence prevents real content admission, not this identity contract. TH-19's import-settings repair/proof is a prerequisite for imported production assets. TH-22 owns per-type authored/save roundtrips. Semantic admission, active-run retention and safe live reload need later authorized executable checks.

[Q-P14](../../../BACKLOG.md#q-p14) and [Q-P15](../../../BACKLOG.md#q-p15) leave relevant content details open; [Q-E09](../../../BACKLOG.md#q-e09) leaves discovery write timing open. [Q-P16](../../../BACKLOG.md#q-p16) leaves unfinished-level and revival placement/health policy open. This contract stores no invented answer and requires compatibility/identity under each eventual choice. [Q-E05](../../../BACKLOG.md#q-e05) gates browser import; existing browser records remain untouched. Catalogue support windows and retirement policy remain for the later Persistence/release contract; exact revisions and supported saves must be accounted for before deletion can be authorized.

## Re-verification triggers

S0-05 and S0-06 have already landed. Their HF-05 triggers are satisfied here by comparing current source, proof assertions and retained receipts at the identified source versions. The normal receipt has eight passing cases, zero failures and exit 0; the injected rule bypass has one failure and exit 1, on `4.7.2.stable.official.ed1daf0bf`.

S0-05 supports one text Resource roundtrip, identity after path/name relocation, duplicate-ID rejection, one deep-copy isolation case and a proof-prefix rejection. S0-06 supports one valid tree, a malformed reconvergent/unreachable candidate, failed dictionary-swap retention and a subsequent successful swap. Its `stage` implementation swaps immediately in the headless script, so it is not the production `stage_catalogue`/`admit_catalogue` separation. The proof has no safe encounter barrier or active saved-run pin. S0-05's per-definition and catalogue `content_revision` fields do not settle production revision representation. None of its placeholders defines a launch catalogue.

Recheck this contract when HF-03a changes ownership or commands; HF-01 changes source/import ownership; TADR-003/004 change identity, compatibility or persistence rules; or later schema, migration and release work makes the open requirements concrete. Changed engine/copy/import behavior or proof bytes require new matching execution evidence before extending historical claims. A successful production pinning, nested-copy, semantic-validator or exported-reference proof must retain its own source and method; existing S0 receipts do not qualify it by association.

## Procedure performed

Verified branch `wt/HF-05` and clean HEAD at the assigned base. Read the exact revision-2 card, admitted HF-01/HF-03a, source ADRs, specific Bible system sections and provenance rules. Compared the seven S0-05/06 source files against their retained SHA256 manifest and inspected normal/fault receipts. No native command was executed.

Authored the identity/owner rules, independent candidate-versus-pin model, sixteen permitted edges, concrete diagnostics and four tabletop traces. The portable paper checker verifies all seven states, every trace edge and state pair, per-subject trace continuity, source hashes, the pinned card text and historical proof assertions. Its source manifest separates exact card bytes from whole BACKLOG drift. Run `python <receipt-directory>/check_contract.py <repository-root>`; it writes `paper-check.json` beside the checker. Disposable author receipts reside at `artifacts/local/tasks/HF-05/`; the coordinator retains them with candidate/integrated identities.

Required checks are `npm run check:scope -- 7a73c5b5f44806c83924661b054051818174f07e <candidate> --no-build`, `npm run check:docs -- --report artifacts/local/tasks/HF-05/check-docs.json`, `npm run check:project`, and the paper checker above. The handoff records actual commands, exits and output hashes. No shared index or execution record belongs to this writer's changes.

## Evidence limits

This is a documentation contract and reproducible paper review. It establishes no engine-enforced immutability, actual validator, deployed catalogue, safe live hot reload, production save pinning, migration or full schema roundtrip. Its four traces describe required behavior; only the narrowly identified historical S0 cases were executed previously. No build, native/browser run, dependency change, asset admission, live save access, publication or product-content selection occurs in this card. Existing browser proofs remain separate. Production qualification and human play remain outside this evidence.
