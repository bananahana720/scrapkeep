# Slice B3 report: TADR-003 hello-world proof (read-only, design only)

Worker: scrapkeep-explorer (claude-fable-5-1, frontmatter effort high; applied effort reported unavailable). Verdict: gap confirmed, proof definable, evidence level 2 (design only, nothing ran).

## Model/effort and base
- Frontmatter pins claude-fable-5-1 @ high; applied effort unavailable from worker vantage. Base HEAD c5e61d3 main, clean. Nothing written or executed.

## Observed gap
- No .gd/.tres/.tscn/project.godot anywhere (Glob zero). docs/tech/ absent (scaffold.txt:314-315). Godot not installed (scaffold.txt:55-61). TADR-003:47 says no schema/importer/hot reload/round-trip implemented in Step 0.

## Section 1. Minimal proof
- Type: `class_name SlotTreeDefinition extends Resource` with `@export id: StringName`, `content_revision: int`, `nodes: PackedStringArray`, `edges: PackedStringArray` ("parent>child"). class_name + typed @export is the documented pattern (docs-godot.txt:66-88, 128-148). Chosen over generic DomainDefinition so the one validation rule is the ADR's own admission rule.
- Fixture: `placeholder_tree.tres`, id `proof.tree.placeholder`, content_revision 0, 15 nodes n0..n14, 14 edges, complete binary tree depth 3. No effect/cost/name fields exist so no product value can be smuggled.
- Catalogue: `register(def) -> Error` refusing duplicate id (ERR_ALREADY_EXISTS + diagnostic); `resolve(id)`. Identity test: same content under a second path/filename must fail on id collision. Executable form of TADR-003:25 and HF-05 identity check (BACKLOG.md:297).
- Validation rule: binary-tree admission from TADR-003:31 and BIBLE.md:529: 15 nodes, 14 edges, one root, two children per non-leaf, 8 leaves, connected, acyclic, no in-degree >1. Justified: only numerically specified structural rule; settled topology (BACKLOG.md:2734); needs no second schema.
- Malformed fixture: one edge redirected causing reconvergence + unreachable leaf; validator emits diagnostic naming id and check; nonzero exit.
- Immutability: ResourceLoader.load (default cache, docs-godot.txt:152-169); session record via duplicate() (docs-godot.txt:186 confirms @export copied); mutate duplicate; reload path; cached definition unchanged. Proves duplicate-then-mutate convention, NOT engine-enforced immutability.
- Failed reload retains catalogue: admit A; build B from dir containing malformed; assert B fails, active ref still A, resolve succeeds. Headless-feasible.
- Proves: text .tres round-trip; id survives path change; duplicate ids refused; rule rejects malformed with diagnostic + nonzero exit; session mutation doesn't leak; failed candidate doesn't displace current.
- Does not prove: editor import pipeline; hot reload at safe boundary; exported asset refs; .tscn; save/content_revision pinning; merge friction; enforced immutability; anything 4.7.2-specific until pinned binary runs.

## Section 2. Harness
- Layout DRAFT under `proof/tadr-003/` (placeholder; HF-01 owns real path families BACKLOG.md:171-173): definitions/{slot_tree_definition.gd,catalogue.gd}; fixtures/{placeholder_tree.tres,malformed_tree.tres,renamed_copy/...}; scenes/ deliberately empty; tools/validate_catalogue.gd (extends SceneTree, _init runs checks, quit(code)); minimal project.godot.
- Command: `godot --headless --path proof/tadr-003 --script res://tools/validate_catalogue.gd` (docs-godot.txt:9, 35-49, 55). quit(int) exit-code semantics UNVERIFIED (not in receipt).
- Evidence: artifacts/local/tasks/S0-0x/: stdout/stderr, exit code, `godot --version`, sha256 of .gd/.tres, pinned binary URL (TADR-001:25).
- Runner: --script, not GUT/gdUnit4: zero deps, free-tool rule (AGENTS.md; ci-facts.txt:23), validator is itself an admission-time tool (TADR-003:27); framework 4.7.2 compat unverified (ci-facts.txt:28-29).
- Anti-pattern precedent in browser code: ENEMY_CONFIG literals in src/orchard/simulation.js:8-51; hero `classes` table with display name in src/heroes.js:15-19 (object key as identity + display name beside it). Not to be changed.

## Section 3. HF coverage and gaps
- HF-05 (BACKLOG.md:274-299) and HF-06 (303-329) are paper-only (:299, :329).
- HF-06 can inventory nouns honestly but cannot honestly fill the "authoring codec" column without one proven .tres round-trip; ADR bar is TADR-003:45. Proof makes one row real; others become "same codec as proven row" claims.
- Recommendation: PAIR the proof with HF-05 in a disjoint write set; land before HF-06 is assigned. Proof needs only TADR-003:25-33 and BIBLE.md:529.
- Drift risks: (1) ID vs path identity: Godot cache keyed by path (docs-godot.txt:160-165 cache_mode) so "resolve by ID" can silently become "dictionary of paths"; renamed-copy test is the tripwire. (2) content_revision placement: per definition vs per catalogue; TADR-004:28 implies catalogue-level; proof carries both to make the question visible. (3) "immutable" drifting to "never happened to mutate"; duplicate-then-reload check is the only evidence.

## Section 4. Gates
- Q-E01: not a technical blocker for a throwaway proof, but ORCHESTRATOR.md:11 requires scoped build authorization; coordinator cannot self-authorize. Andrew must either close Q-E01 naming this proof as first slice or grant a separate explicit prepare-stage authorization.
- Content values open (BIBLE.md:538; Q-P10/Q-P11 BACKLOG.md:2324-2334): schema has no effect/cost/name fields; fixture id has `proof.` prefix; harness refuses non-`proof.` ids from a production catalogue. Content role limit ORCHESTRATOR.md:24 respected.
- Hard blocker: Godot not installed and not authorized (scaffold.txt:55-61; ci-facts.txt:20).

## Section 5. DRAFT cards
### S0-01: Prove typed Resource identity, admission and immutability headlessly
Card revision 0 DRAFT, not imported · Owner Content · Size S · Lane prepare.
Sources: TADR-003 § Decision (25-33); BIBLE.md:529 (tree shape only); docs-godot.txt Q2 and Q1; TADR-001:25.
Dependencies: none in HF sprint. Blocking item: Godot 4.7.2 install authorization + Q-E01 closure naming this proof or explicit prepare-stage go in TRACKING.
Files: proof/tadr-003/project.godot; definitions/slot_tree_definition.gd; definitions/catalogue.gd; fixtures/placeholder_tree.tres; fixtures/renamed_copy/placeholder_tree_other_name.tres; tools/validate_catalogue.gd; artifacts/local/tasks/S0-01/. Provisional path pending HF-01.
DoD: (1) typed SlotTreeDefinition saved as text .tres; (2) register refuses same id from different path/filename, resolve returns first; (3) duplicate() session record mutated, reload unchanged, resolve returns original; (4) headless --script command exits 0 with per-check summary.
Verification (DRAFT): run on pinned 4.7.2; capture stdout, exit, `godot --version`, sha256 manifest to artifacts/local/tasks/S0-01/. Reviewer confirms renamed copy differs in path+filename, no field can hold cost/effect/name, id has `proof.` prefix.
Boundary: disposable; no production path, content, import, hot reload, .tscn, save format; browser proofs untouched; deletable once HF-05/06 cite it.

### S0-02: Prove binary-tree admission rejection and failed-reload retention
Card revision 0 DRAFT, not imported · Owner Content (Verification reviews) · Size S · Lane prepare.
Sources: TADR-003:31, :33; BIBLE.md:529; S0-01 outputs. Dependencies: S0-01 done. Blocking item: same install authorization.
Files: proof/tadr-003/definitions/tree_rules.gd; fixtures/malformed_tree.tres; fixtures/candidate_bad/; tools/validate_catalogue.gd (extend); artifacts/local/tasks/S0-02/.
DoD: (1) tree_rules.validate returns [] for good fixture, >=1 diagnostic naming id + failed check for malformed (reconvergence, unreachable leaf); (2) validator with malformed candidate exits nonzero with diagnostic; (3) failed staged catalogue leaves prior active; resolve still succeeds; (4) fixture without `proof.` prefix refused.
Verification (DRAFT): two runs (exit 0 good; nonzero candidate), logged with exit codes + `godot --version`. Reviewer confirms defect is structural (rule, not typing, rejected it per TADR-003:31).
Boundary: semantic rules (lineage per slot, start access, milestones, recipe endpoints, compatibility) out of scope; no safe-encounter-boundary behavior proven.

## Decisions only Andrew can make
- Authorize installing pinned Godot 4.7.2 standard + export templates as a free local tool.
- Whether the prepare-stage proof counts as the Q-E01 first native slice or a separate prepare-stage authorization.
- Confirm HF sprint may run with S0-01/S0-02 paired beside HF-05 (proof before HF-06).
- Accept provisional `proof/tadr-003/` path as disposable pending HF-01.
