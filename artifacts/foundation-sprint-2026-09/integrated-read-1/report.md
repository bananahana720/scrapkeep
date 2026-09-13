# Integrated read 1: HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b, HF-05

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort high pinned by agent definition; CLAUDE_EFFORT not exposed). Read at main 4e8cc47 over the sections pinned in manifest.txt. Verbatim report follows.

---

Verdict: **PASS+NOTES** for the integrated read, evidence level 2 (file:line). All seven sections were read in full at the manifest identity; the three TADR Decision sections were read at `adr/TADR-002-runtime-model.md:22-34`, `TADR-003-content-pipeline.md:21-35`, `TADR-004-persistence.md:22-34`. No checker or `sha256sum` was run (no shell in this session); manifest hashes are compared only as quoted strings between files. No note below violates a definition of done; none requires a changes_requested before HF-06a is assigned.

## Blocking findings

None.

## Notes (ranked, each names the reopen candidate if the coordinator wants alignment)

**N1. Replacement step 5 uses three different ContentAdmission commands across sections. Reopen candidate: HF-04b (least authoritative; sketch is declared unparsed).**
- `HF-04b-runtime-patterns.md:116` calls `content.retain_revision(run_state.content_revision)` on every encounter replacement, and `:141` maps `retain_revision` explicitly to HF-04a step 5.
- `HF-03b-dependency-graph.md:182` (W3 R13) uses `resolve_id` on D03 for the same step.
- `HF-05-content-admission.md:85` (E06) places `retain_revision` at new-run start, validated restore, or committed migration; `:86` (E07) and `:173` (T4.2) make encounter replacement a pinned→pinned read, not a retain.
- Not a contradiction of HF-03a: D03 (`HF-03b:29`) permits both commands, and `HF-05:123` allows multiple live references. It is a naming drift HF-06a's writer should not copy.

**N2. HF-04b sketch invokes an Encounter interface HF-03a does not list. Reopen candidate: HF-04b.**
- `HF-04b-runtime-patterns.md:124` calls `encounter.read_initial_snapshot()`. HF-03a's Encounter command list at `HF-03a-module-map.md:32` has no such command; `HF-03b-dependency-graph.md:185` (R16) uses `read_committed_results` for the initial snapshot. `HF-04b:82` disclaims "helper names outside HF-03a's command list" as sketch-local, but this one is a call on the Encounter module, not a Session-local helper.

**N3. Downstream owner of "save projections" is named differently. Reopen candidate: none; cite BACKLOG titles instead.**
- `HF-05-content-admission.md:180` "HF-06b owns save projections"; `HF-03a-module-map.md:43` "HF-07a owns save fields"; `HF-03b-dependency-graph.md:198` and `HF-04a-runtime-lifecycle.md:187` assign save projection/fields to HF-07a.
- `BACKLOG.md:436` titles HF-06b "Map matrix rows to persistence projections" and `:468` titles HF-07a "Specify the save envelope and preferences record", so both paraphrases are partial rather than wrong. HF-06a's writer should cite the card titles.

**N4. Queue/history capacity is routed to Q-E03 but HF-02 has no row for it. Reopen candidate: HF-02, only when a capacity proposal appears.**
- `HF-04a-runtime-lifecycle.md:81,102` and `HF-04b-runtime-patterns.md:169` route queue/history capacities to Q-E03 under `B-memory`/`N-memory`. `HF-02-constraints-evidence.md:54-57` rows are B-frame, B-memory, B-load, B-assets; `:85` scopes Q-E03 to hardware, drivers, controller devices and budget rulings. Not a disagreement; a gap to fill later.

**N5. HF-03b callback labels diverge slightly from HF-04a class definitions. Reopen candidate: HF-03b, cosmetic.**
- `HF-03b-dependency-graph.md:125` labels A1 "F-INPUT drain"; HF-04a defines only `F-INPUT` (`HF-04a-runtime-lifecycle.md:46`).
- `HF-03b:156-157` (E6, E7) and `:176-177` (R7, R8) label the *call* to `stage_transition`/`commit_transition`/`resolve_id` as F-ASYNC; `HF-04a:50` defines F-ASYNC as completion delivery. Inference: HF-03b's checker validates class names, so it presumably accepted these.

**N6. Validator location straddles two HF-01 path families. No reopen; guidance for HF-06a.**
- `HF-01-production-conventions.md:36` places "scoped typed validators" under `native/editor_tools/**` (Tooling); `HF-03a:23` places ContentAdmission, which owns `validate_candidate` (`HF-03a:34`), under `native/runtime/**`; `HF-05:45-52` assigns all four gates to ContentAdmission. Consistent only if editor tools invoke the runtime validators; `HF-01:36`'s forbidden column already bars a second validator.

**N7. HF-05 diagnostic type names refine, not contradict, HF-03a.** `HF-05:101` (`ContentReferenceFailure`) and `:117` (`ContentAdmissionFailure`) are concrete forms of HF-03a's "compatibility and missing-ID diagnostics" (`HF-03a:34`); HF-03b D03/D09 say only "diagnostics".

## Checks with empty results

- Item 1 (ownership): every module name in HF-03b, HF-04a, HF-04b and HF-05 is one of HF-03a's seven (`HF-03a:31-37`) or `Values` (`HF-03a:27`). No record, command or result is assigned to two modules.
- Item 2 (edges): all 29 HF-04a scenario arrows (`HF-04a:131-179`) and all 51 HF-03b walkthrough steps (`HF-03b:125-189`) use D01–D09 or `local`; no forbidden pair. HF-05 traces use D01, D03, D04, D09 only.
- Item 3 (identity): HF-05 identities (`:20-25`), path use (`:29`) and TH-19 gate match `HF-01:21,28-31,61,70` and TADR-003:25,27,29,31,33 and TADR-004:26,28,34; the six ContentAdmission commands at `HF-05:31` equal `HF-03a:34` exactly; eight-family count at `HF-05:58` matches TADR-003:25.
- Item 4 (open parameters): `h`/rate unset in `HF-04a:22,102`, `HF-04b:43,169`, `HF-03a:95`, `HF-03b:199`, `HF-02:54`; Q-P16 open in `HF-03a:85`, `HF-04a:187`, `HF-04b:173`, `HF-05:182`; Q-E09 open in `HF-03a:96`, `HF-05:182`; autoload/bootstrap open in `HF-03a:60,99`, `HF-03b:200`, `HF-04b:171`. No section treats a Q-gated value as settled.
- Item 5 (citations): 50+ section-to-section line citations sampled, all resolving at this identity. Quoted SHA256 strings for HF-02, HF-03a and HF-04a at `HF-04a:10-11`, `HF-04b:10-11`, `HF-03b:10` equal manifest lines 2, 3, 5 as strings; not recomputed.

## Item 6: inputs for HF-06a

- HF-05 admission state table: `HF-05-content-admission.md:66-74` (rows draft…pinned at 68–74); transition table E01–E16 at `:78-95`; safe-boundary definition `:64`; identity table `:20-25`; `CatalogueHandle` rule `:27`; diagnostic fields `:103-115`; explicit hand-offs to HF-06a at `:18`, `:58`, `:180`.
- HF-03a owned-definitions rows: module table `HF-03a-module-map.md:29-37` (ContentAdmission row `:34`); record meanings `:45-51` (ContentAdmission `:48`); path placement `:23`; mutation rule 2 on immutable handles `:56`; HF-05 ownership pointer `:96`.
- Supporting: `HF-01-production-conventions.md:28` (definitions family), `:74` (validation order); TADR-003:25, :29, :31.
