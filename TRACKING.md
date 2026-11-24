# Scrapkeep execution board

Schema 1. Coordinator-owned in-repo board. Prepared 6 September 2026.

Use this file for schema, the foundation-era task and question index and the program authorization record. [BACKLOG.md](BACKLOG.md) defines tasks, dependencies and questions; [ORCHESTRATOR.md](ORCHESTRATOR.md) defines operating rules. The [Bible](BIBLE.md) and [engineering ADRs](adr/README.md) remain product and architecture authority. Alpha waves 17 to 21 do not use this file for live execution: their units, owners and gates are in `project-guide/coord/GRAPH.md` and GitHub board issue #241, and their rulings are in [project-guide/handoff/DECISIONS.md](project-guide/handoff/DECISIONS.md).

## Program authorization

| Field | Value |
| --- | --- |
| Preparation | Authorized by Andrew's explicit instruction to implement the three-document plan. |
| Asset tooling | **Authorized** by Andrew after the 27 September tooling plan. AT-01 delivered inspection and budgets. AT-02 authorized local Blender fur/accessory tooling, neutral fixtures, renders and the scope-selected checks. Both are delivered and no asset-tooling writer is active. |
| Light play lane | **Authorized** by Andrew for Godot sketches under `sketches/` (EV-0479, EV-0480; ORCHESTRATOR § Light play lane). No card, lease or reviewer; Andrew's play is the review; verdicts go to docs/playtests/PLAYTEST-LOG.md. **Alpha program authorized** on 2026-10-01 (EV-0599); plan at [ALPHA-PLAN.md](sketches/core-loop/design-v3/ALPHA-PLAN.md). Waves 17 to 21 run from GRAPH.md and board issue #241 (see above). |
| Jev Lab program | **Authorized** by Andrew on 2026-09-25 (EV-0484): card family JL, heavy lane for every card, plan retained at `artifacts/jev-lab-2026-09-25/plan.md`. Coordinator worktree `wt/JL-coord`. Automated play never stands in for Andrew's play. |
| Direction foundation | **Complete** (EV-0586); authorized by Andrew on 2026-09-26 (EV-0579): card family DF (DF-01 to DF-04), documentation only, heavy lane. Five ADRs (TADR-006 to TADR-010) for decisions D1 to D5, superseded-direction notes on TH-06, TH-11 and TH-14 in the sections index, then Bible harmonization per the review (`artifacts/bible-harmonization-2026-09-26/REVIEW.md`). No game code, build, dependency or remote action. Wave 1 DF-01 to DF-03; DF-04 after their admission. |
| Proposed sprint | None. The Handoff-9 proposal was deferred by Andrew at EV-0479 and grants no execution authority. Closed sprints and their receipts are in the archive (`docs/project/tracking/EVENTS-0058-0627.md`) and `docs/project/*/closure.json`. |
| Sprint authorization | **None active.** Every foundation and handoff sprint is closed; the last, Handoff-8-2026-09-16, closed passed at EV-0475. Closure receipts are in `docs/project/*/closure.json`. Foundation-full (authorized EV-0078, closed EV-0185), Foundation-01 (EV-0077) and Operational Sprint 0 (EV-0064) are historical. |
| Native game/build authorization | **None active.** NP-01's proof repair (authorized EV-0188, done EV-0193) is historical: edits confined to `native/proofs/tadr-004/` and its proof pages, verified by headless `npm run native:smoke`; no export, feature or production code. Earlier historical: **Operational Sprint 0 proofs and exports authorized** by implementation request (`docs/project/sprint-0/AUTHORIZATION.md`), superseding the earlier parked template/workflow scope. Foundation-01 is documentation-only; it authorizes no new native execution. Historical scope follows. **prepare-stage proofs only.** The pinned Godot 4.7.2 standard editor is installed on this machine under Andrew's confirmation (EV-0024); export templates and exports were parked until EV-0035. Proof code lives under `native/` and proves ADR rules only; no game feature, asset or qualification run is authorized. |
| Active coordinator | The claude.ai project "Scrapkeep" coordinates the alpha waves; the live board is named in [STATE.md](project-guide/handoff/STATE.md). The Codex lane retired on 17 October 2026; Claude project agents under `.claude/agents` are the only workers. This file has no open sprint to coordinate. |
| Active task attempts / write leases | None open on this board. Old lease and attempt records are in the archive (`docs/project/tracking/EVENTS-0058-0627.md`). |
| Remote / publication | Verified [private bananahana720/scrapkeep](https://github.com/bananahana720/scrapkeep), default `main`. Alpha work stacks on `stage/alpha-w<N>` and promotes to `main` by GitHub merge. See the accepted PUB-01 attempt and publication receipt (`artifacts/publication-2026-09-06/publication.json`). |

Ready means that a selected card has complete inputs. It does not bypass the program authorization row. The full foundation authorization covers only the fourteen selected HF cards and necessary scoped factual amendments. Other task families remain outside this scope. PUB-01 retains its separate historical authorization.

## Task record schema

Every row identifies one BACKLOG card. Record revisions and event sequence numbers increase monotonically. Do not copy definitions, acceptance criteria or live states into another file.

| Field | Meaning and constraint |
| --- | --- |
| task_id | Existing unique backlog ID. |
| card_revision | Exact immutable card revision assigned or queued. A changed card requires a definition-change event and readiness review. |
| record_revision | Monotonic integer; a checkpoint increments it even when workflow state is unchanged. |
| state | queued, blocked, ready, in_progress, review, changes_requested, done, parked or cancelled. |
| assignee | Actual worker/session identifier and role; null until assigned. |
| attempt_id / lease_id | Unique IDs for the current attempt and exclusive write lease; never reused for a replacement worker. |
| owned_files | Explicit active lease paths, including generated/test/shared outputs. Empty when unassigned. They must be a subset of the pinned card's permitted files. |
| base_identity | Actual base commit, plus accepted dependency identities; permitted prose-only work also records its source manifest. |
| candidate_identity / integrated_identity | Candidate and accepted integrated commit or permitted document manifest, recorded separately. Null until produced. |
| latest_checkpoint | UTC timestamp, actual progress, changed paths, next step and evidence limits. Null until the attempt starts. |
| blockers | References to unmet dependency tasks, unanswered blocking questions, scope authorization or a concrete environment/evidence failure. |
| evidence | Paths/commands/outcomes and their source identities. No completion claim from a missing artifact or another version. |
| review | Independent reviewer identifier, verdict, candidate/integrated identity reviewed, findings and disposition. |
| last_event | Most recent append-only event that changed this record. |

The initial compact task table uses the following explicit defaults. All cards are revision 1. Assignee, attempt, lease, base, candidate, integrated result and checkpoint are null. owned_files and evidence are empty; review is not_run. A card's future output scope is in BACKLOG and does not grant a live lease. The preparation handoff had no overrides. The explicit PUB-01 record below overrides these initial defaults for publication.

When assigning a task, add its expanded record under Active attempt records and record every field above. The compact row remains the workflow-state index; its Accepted attempt column stays none until admission, even when an expanded active attempt exists. the expanded record supplies the nonduplicated attempt details. Do not repeat its state in the expanded record. After closure, retain the attempt record and evidence as history and reference the accepted attempt from the task row.

## Transition authority

Only the coordinator writes this file. Workers and reviewers submit requests; the coordinator validates and serializes them. No meaningful worker action counts toward ownership or completion until it appears in a versioned record and event here.

| From → to | Requester | Coordinator must establish before recording |
| --- | --- | --- |
| absent → queued | Coordinator | Complete atomic card, sources and identifiers exist; scheduling/readiness has not yet been admitted. |
| absent/queued → blocked | Coordinator | A named blocking question, missing input or environment condition prevents admission. |
| queued/blocked → ready | Coordinator | Selected scope, current card, every dependency done, required outputs present and all blocking answers applicable. A stale lease must be resolved first. |
| ready → in_progress | Coordinator | Program authorization, verified base, available slot, conflict-free write set and recorded assignment/lease. |
| in_progress → in_progress | Worker checkpoint | Record revision, checkpoint and event advance with observed progress; ownership and source remain valid. |
| in_progress → review | Worker handoff | Complete packet, candidate identity, actual changed files, evidence and retained lease accounting. |
| review → review | Independent reviewer / coordinator | Record a verdict, integration attempt or additional evidence without claiming completion. |
| review → changes_requested | Independent reviewer / coordinator | Concrete failed criteria or integration regression, with actionable findings and preserved attempt evidence. |
| changes_requested → in_progress | Coordinator | Revised assignment, attempt 2 or 3, readiness rechecked and no competing lease. An old writer cannot remain active. |
| review → done | Coordinator | Independent PASS/PASS+NOTES, no failed DoD, serial integration and required checks on the exact accepted integrated result. |
| ready/in_progress/review/changes_requested → blocked | Worker/reviewer/coordinator | Named blocker, stopped or explicitly retained worker, and safe lease disposition. |
| eligible nonterminal → parked/cancelled | Coordinator | Sourced scope ruling or duplicate disposition; active writer stopped and lease handled first. |
| done/parked/cancelled → queued/blocked | Coordinator | Explicit reopen reason, preserved former result, revised card if needed and fresh readiness review. Old evidence does not approve new scope. |

Queued work can remain queued even if its dependencies happen to finish. Readiness is admitted, not inferred by a worker. Parked questions and parked dependencies do not satisfy readiness. A failed integration stays out of done and cannot unlock downstream work.

## Questions and definition changes

Question wording, source, decision owner, affected work and closure criteria live in BACKLOG. The question table here owns their live states. Valid states are open, proposed, resolved and parked. A submitted suggestion is proposed, not resolved. Resolve only with the authorized owner's answer or the accepted evidence/producer contract named in its closure rule. Record the answer, evidence and affected-card propagation before unblocking work. Reopening retains the former answer and records why it no longer applies.

Do not assume an unanswered product value. Documentation cards that explicitly require a question register can finish without it; implementation cards that require the value cannot. Once missing paths or scope become concrete, add/revise complete atomic cards and import them through a definition-change event. Do not create an assignable “implement everything” placeholder.

## Event schema and write discipline

Each event has a unique increasing sequence, UTC timestamp, authorized actor/requester, kind, affected IDs, prior/next workflow state or record revision, reason and evidence reference. Batch initialization may name an explicit ID list; later events must identify the specific changed task/question records. Rejected requests may be recorded without granting their requested state.

Event kinds cover preparation, definition import/change, question proposal/resolution, readiness, assignment/lease, checkpoint, handoff, review, integration, completion, block, ownership recovery, park/cancel, reopen and authorization/coordination transfer.

The coordinator checks the last sequence before updating, writes a complete valid document and verifies it before admitting more work. If another coordinator changed the sequence, reconcile ownership instead of overwriting. Never delete previous events to make the current state appear cleaner. A corrected event is followed by a compensating event. Maintain one board writer; elapsed time is not a lease transfer mechanism.

Unlogged handoffs cannot be reviewed as accepted work. Unlogged scope changes cannot expand ownership. Repeated handoff/completion requests for the same attempt attach to the existing event/result rather than granting duplicate progress. An abandoned or delayed old attempt remains evidence, not authority over the replacement.

## Active attempt records

### PUB-01-A1

- Assignee: publication root coordinator (`gpt-6-astra`); card revision 2; accepted attempt PUB-01-A1; lease PUB-01-L1 closed. Active owned files: none.
- Historical owned files: the explicit PUB-01 publication edit set. Pre-existing planning files are admitted from the publication baseline, with the completed repository-local workflow package admitted unchanged from its frozen manifest (`artifacts/publication-2026-09-06/concurrent-package.json`).
- Base identity: `dc72a02cd7a0fbe1f00b3ce71d36448364f93294` plus that publication baseline manifest.
- Candidate identity: publication candidate manifest (`artifacts/publication-2026-09-06/candidate-manifest.json`). Integrated identity: `73c427203c9263affa747938e586325842357b0c`; closeout identity: `6d7967856448c2f4d5e2f7b316e59b72c0bd4560`. Both stages committed serially and verified remotely; closeout verification (`artifacts/publication-2026-09-06/closeout-verification.json`) precedes this terminal event.
- Latest checkpoint: 2026-09-06T16:40:13+00:00; all publication and closeout requirements verified, including both remote tips and clean working tree at `6d7967856448c2f4d5e2f7b316e59b72c0bd4560`. PUB-01 complete; no active worker or sprint lease. The terminal record is committed after this observed result.
- Evidence: authorization (`artifacts/publication-2026-09-06/AUTHORIZATION.md`), document checks (`artifacts/publication-2026-09-06/document-checks.json`), content screen (`artifacts/publication-2026-09-06/content-screen.json`), independent review (`artifacts/publication-2026-09-06/REVIEW.md`); verified remote publication (`artifacts/publication-2026-09-06/publication.json`).
- Review: private_publication_review (independent Astra), **PASS+NOTES** on the pinned candidate and evidence overlay; report (`artifacts/publication-2026-09-06/REVIEW.md`). Six original whitespace warnings accepted with preservation proof. No sprint worker has been assigned.

## Task state index

Blockers marked dependency refer to the pinned card's exact dependency list in BACKLOG. They are not new task definitions. At initialization all future dependencies are unfinished. Program authorization remains an additional dispatch gate for every row.

| Task ID | Card rev | Record rev | State | Blockers / admission | Accepted attempt | Last event |
| --- | --- | --- | --- | --- | --- | --- |
| [PUB-01](BACKLOG.md#pub-01) | 2 | 11 | done | none | PUB-01-A1 | EV-0018 |
| PS-01 (audit rec 3, 13, 17; S0-02, S0-03) | interim | 5 | done | none | PS-01-A1 | EV-0026 |
| PS-02 (audit rec 5, 12) | interim | 5 | done | none | PS-02-A1 | EV-0025 |
| PS-03 (audit rec 6, 7, 16; settings effort key) | interim | 3 | done | none | PS-03-A1 | EV-0026 |
| PS-04 (audit rec 2, 4, 8, 11; S0 import) | interim | 5 | done | none | PS-04-A1 | EV-0029 |
| PS-05a (tooling follow-ups, FRONT-MATTER anchors, artifact manifests) | interim | 3 | done | none | PS-05-A1 | EV-0027 |
| PS-05b (audit rec 9, 14; lead server, controller pin) | interim | 5 | done | none | PS-05-A2 | EV-0034 |
| PS-06 (S0-01, S0-04, S0-05, S0-06, S0-07, S0-08) | interim | 7 | done | none | PS-06-A1 | EV-0034 |
| [HF-01](BACKLOG.md#hf-01) | 3 | 9 | done | none | HF-01-A1 | EV-0075 |
| [HF-02](BACKLOG.md#hf-02) | 2 | 7 | done | none | HF-02-A1 | EV-0072 |
| [HF-05](BACKLOG.md#hf-05) | 2 | 6 | done | none | HF-05-A1 | EV-0097 |
| [HF-08](BACKLOG.md#hf-08) | 2 | 8 | done | none | HF-08-A1 | EV-0365 |
| [HF-09](BACKLOG.md#hf-09) | 2 | 11 | done | none; re-pointed to the FR-05 bytes at EV-0270 | HF-09-A1 | EV-0364 |
| [HF-10](BACKLOG.md#hf-10) | 2 | 9 | done | none | HF-10-A2 | EV-0183 |
| [HF-03a](BACKLOG.md#hf-03a) | 1 | 8 | done | none | HF-03a-A1 | EV-0086 |
| [HF-03b](BACKLOG.md#hf-03b) | 1 | 8 | done | none | HF-03b-A1 | EV-0136 |
| [HF-04a](BACKLOG.md#hf-04a) | 1 | 6 | done | none | HF-04a-A1 | EV-0096 |
| [HF-04b](BACKLOG.md#hf-04b) | 2 | 12 | done | none; line 10 hash re-pointed at EV-0270 | HF-04b-A1 | EV-0365 |
| [HF-06a](BACKLOG.md#hf-06a) | 1 | 6 | done | none | HF-06a-A1 | EV-0146 |
| [HF-06b](BACKLOG.md#hf-06b) | 1 | 6 | done | none | HF-06b-A1 | EV-0153 |
| [HF-07a](BACKLOG.md#hf-07a) | 1 | 7 | done | none | HF-07a-A1 | EV-0345 |
| [HF-07b](BACKLOG.md#hf-07b) | 1 | 6 | done | none | HF-07b-A1 | EV-0165 |
| [S0-01](BACKLOG.md#s0-01) | 1 | 1 | done | none | PS-06-A1 | EV-0029 |
| [S0-02](BACKLOG.md#s0-02) | 1 | 1 | done | none | PS-01-A1 | EV-0029 |
| [S0-03](BACKLOG.md#s0-03) | 1 | 1 | done | none | PS-01-A1 | EV-0029 |
| [S0-04](BACKLOG.md#s0-04) | 1 | 2 | done | none | PS-06-A1 | EV-0031 |
| [S0-05](BACKLOG.md#s0-05) | 1 | 3 | done | none | PS-06-A1 | EV-0033 |
| [S0-06](BACKLOG.md#s0-06) | 1 | 3 | done | none | PS-06-A1 | EV-0033 |
| [S0-07](BACKLOG.md#s0-07) | 1 | 4 | done | none | PS-06-A1 | EV-0034 |
| [S0-08](BACKLOG.md#s0-08) | 1 | 4 | done | none | PS-06-A1 | EV-0034 |
| [S0-09](BACKLOG.md#s0-09) | 3 | 12 | done | none | S0-09-A3 | EV-0061 |
| [PD-01](BACKLOG.md#pd-01) | 1 | 7 | done | none | none | EV-0360 |
| [PD-02](BACKLOG.md#pd-02) | 1 | 6 | done | none | none | EV-0345 |
| [PD-03](BACKLOG.md#pd-03) | 1 | 10 | done | Reopened at closure (EV-0453); readmitted with attempt 3 | PD-03-A3 | EV-0468 |
| [TH-01](BACKLOG.md#th-01) | 1 | 12 | done | none; RL5 and RS.15 corrected to HF-07a route semantics at EV-0280 | TH-01-A1 | EV-0365 |
| [TH-02](BACKLOG.md#th-02) | 1 | 11 | done | none; MO-03 unlock authority corrected at EV-0284 | TH-02-A2 | EV-0284 |
| [TH-03](BACKLOG.md#th-03) | 1 | 10 | done | none | TH-03-A2 | EV-0241 |
| [TH-04](BACKLOG.md#th-04) | 1 | 8 | done | none | none | EV-0303 |
| [TH-05](BACKLOG.md#th-05) | 1 | 11 | done | none | TH-05-A2 | EV-0271 |
| [TH-06](BACKLOG.md#th-06) | 1 | 8 | done | none | none | EV-0345 |
| [TH-07](BACKLOG.md#th-07) | 1 | 6 | done | none | none | EV-0325 |
| [TH-08](BACKLOG.md#th-08) | 1 | 8 | done | none | none | EV-0325 |
| [TH-09](BACKLOG.md#th-09) | 1 | 8 | done | none | none | EV-0325 |
| [TH-10](BACKLOG.md#th-10) | 1 | 6 | done | none | none | EV-0325 |
| [TH-11](BACKLOG.md#th-11) | 2 | 14 | done | none | TH-11-A2 | EV-0365 |
| [FR-04](BACKLOG.md#fr-04) | 1 | 9 | done | none | FR-04-A2 | EV-0260 |
| [FR-05](BACKLOG.md#fr-05) | 3 | 11 | done | none | FR-05-A2 | EV-0270 |
| [FR-06](BACKLOG.md#fr-06) | 1 | 5 | done | none | none | EV-0364 |
| [FR-07](BACKLOG.md#fr-07) | 1 | 4 | done | Handoff-8 (EV-0392, EV-0411, EV-0412); HF-06a, HF-06b, HF-07a, TH-04, TH-06, TH-07, TH-11 done; dispatch after SC-06 and SC-08 admission | FR-07-A1 | EV-0437 |
| [FR-08](BACKLOG.md#fr-08) | 1 | 1 | ready | none | none | EV-0470 |
| [FR-09](BACKLOG.md#fr-09) | 1 | 1 | ready | none | none | EV-0470 |
| [FR-10](BACKLOG.md#fr-10) | 1 | 1 | queued | AM-H8-007 decision by Andrew | none | EV-0470 |
| [FR-11](BACKLOG.md#fr-11) | 1 | 1 | ready | none | none | EV-0470 |
| [TH-12](BACKLOG.md#th-12) | 1 | 6 | done | none | none | EV-0365 |
| [TH-13](BACKLOG.md#th-13) | 1 | 9 | done | none | none | EV-0364 |
| [TH-14](BACKLOG.md#th-14) | 1 | 7 | done | none | none | EV-0364 |
| [TH-15](BACKLOG.md#th-15) | 1 | 6 | done | none | none | EV-0345 |
| [TH-16](BACKLOG.md#th-16) | 1 | 6 | done | none | none | EV-0365 |
| [TH-17](BACKLOG.md#th-17) | 1 | 1 | queued | TH-04, TH-12, PD-03 | none | EV-0002 |
| [TH-18](BACKLOG.md#th-18) | 1 | 13 | done | Reopened at closure (EV-0453); readmitted with attempt 3 | TH-18-A3 | EV-0460 |
| [TH-19](BACKLOG.md#th-19) | 2 | 9 | done | Handoff-8 selected (EV-0367); HF-05, TH-16 done; later import staging/proof requirement recorded | TH-19-A2 | EV-0398 |
| [TH-20](BACKLOG.md#th-20) | 2 | 4 | queued | HF-06a, SC-01, SC-02, SC-03, SC-04, SC-05, SC-06, SC-07, SC-08 | none | EV-0472 |
| [TH-21](BACKLOG.md#th-21) | 1 | 1 | queued | HF-08, HF-09, TH-20 | none | EV-0002 |
| [TH-22](BACKLOG.md#th-22) | 1 | 1 | queued | TH-20, TH-21 | none | EV-0002 |
| [TH-23](BACKLOG.md#th-23) | 1 | 1 | queued | TH-01, TH-13, TH-15, TH-18, TH-02, TH-03, TH-04, TH-05, TH-06, TH-07, TH-08, TH-09, TH-10, TH-11, TH-12 | none | EV-0002 |
| [TH-24](BACKLOG.md#th-24) | 1 | 1 | queued | HF-02, TH-16, TH-19 | none | EV-0002 |
| [TH-25](BACKLOG.md#th-25) | 1 | 1 | queued | TH-18, TH-21, TH-24 | none | EV-0002 |
| [TH-26](BACKLOG.md#th-26) | 1 | 2 | queued | HF-03a, TH-14, TH-23 | none | EV-0029 |
| [TH-27](BACKLOG.md#th-27) | 1 | 1 | queued | TH-13, TH-14, TH-15, TH-16, TH-17, TH-18, TH-21, TH-01 | none | EV-0002 |
| [TH-28](BACKLOG.md#th-28) | 1 | 1 | queued | TH-22, TH-23, TH-24, TH-25, TH-26, TH-27 | none | EV-0002 |
| [TH-29](BACKLOG.md#th-29) | 1 | 1 | queued | TH-22, TH-23, TH-24, TH-25, TH-26, TH-28 | none | EV-0002 |
| [TH-30](BACKLOG.md#th-30) | 1 | 2 | queued | HF-01, HF-02, HF-03a, HF-03b, HF-04a, HF-04b, HF-05, HF-06a, HF-06b, HF-07a, HF-07b, HF-08, HF-09, HF-10, TH-01, TH-02, TH-03, TH-04, TH-05, TH-06, TH-07, TH-08, TH-09, TH-10, TH-11, TH-12, TH-13, TH-14, TH-15, TH-16, TH-17, TH-18, TH-19, TH-20, TH-21, TH-22, TH-23, TH-24, TH-25, TH-26, TH-27, TH-28, TH-29, SC-01, SC-02, SC-03, SC-04, SC-05, SC-06, SC-07, SC-08 | none | EV-0029 |
| [TH-31](BACKLOG.md#th-31) | 1 | 1 | queued | TH-30 | none | EV-0002 |
| [SC-01](BACKLOG.md#sc-01) | 1 | 14 | done | Handoff-8 selected (EV-0367); AM-H8-001 applied by FR-07 (EV-0437) | SC-01-A3 | EV-0468 |
| [SC-02](BACKLOG.md#sc-02) | 1 | 12 | done | Handoff-8 selected (EV-0367); AM-H8-003 applied by FR-07 (EV-0437) | SC-02-A2 | EV-0445 |
| [SC-03](BACKLOG.md#sc-03) | 1 | 15 | done | Reopened at closure (EV-0453); readmitted with attempt 3 | SC-03-A3 | EV-0458 |
| [SC-04](BACKLOG.md#sc-04) | 1 | 9 | done | Handoff-8 selected (EV-0367); HF-06a, TH-06 done | SC-04-A2 | EV-0409 |
| [SC-05](BACKLOG.md#sc-05) | 2 | 10 | done | Handoff-8 selected (EV-0367); HF-06a, TH-11, TH-14 done | SC-05-A2 | EV-0426 |
| [SC-06](BACKLOG.md#sc-06) | 1 | 11 | done | Handoff-8 selected (EV-0367); HF-06a, TH-10 done | SC-06-A3 | EV-0431 |
| [SC-07](BACKLOG.md#sc-07) | 1 | 2 | queued | HF-06a, TH-12, TH-16, TH-17 | none | EV-0029 |
| [SC-08](BACKLOG.md#sc-08) | 1 | 17 | done | Reopened at closure (EV-0453); readmitted with attempt 3 | SC-08-A3 | EV-0468 |
| [LG-01](BACKLOG.md#lg-01) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [LG-02](BACKLOG.md#lg-02) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [LG-03](BACKLOG.md#lg-03) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [LG-04](BACKLOG.md#lg-04) | 1 | 1 | queued | LG-03 | none | EV-0002 |
| [LG-05](BACKLOG.md#lg-05) | 1 | 1 | queued | LG-03, LG-04 | none | EV-0002 |
| [LG-07](BACKLOG.md#lg-07) | 1 | 1 | queued | LG-03 | none | EV-0002 |
| [S0-10](BACKLOG.md#s0-10) | 1 | 2 | done | none | S0-10-A2 | EV-0036 |
| [S0-11](BACKLOG.md#s0-11) | 1 | 5 | done | none | S0-11-A1 | EV-0042 |
| [S0-12](BACKLOG.md#s0-12) | 1 | 5 | done | none | S0-12-A1 | EV-0045 |
| [S0-13](BACKLOG.md#s0-13) | 1 | 7 | done | none | S0-13-A2 | EV-0055 |
| [S0-14](BACKLOG.md#s0-14) | 1 | 4 | done | none | S0-14-A1 | EV-0064 |
| [AR-01](BACKLOG.md#ar-01) | 3 | 6 | done | none | AR-01-A1 | EV-0105 |
| [AR-02](BACKLOG.md#ar-02) | 2 | 5 | done | none | AR-02-A2 | EV-0105 |
| [AR-03](BACKLOG.md#ar-03) | 1 | 4 | done | none | AR-03-A1 | EV-0111 |
| [AR-04](BACKLOG.md#ar-04) | 1 | 4 | done | none | AR-04-A1 | EV-0112 |
| [AR-05](BACKLOG.md#ar-05) | 1 | 4 | done | none | AR-05-A2 | EV-0118 |
| [AR-06](BACKLOG.md#ar-06) | 1 | 4 | done | none | AR-06-A1 | EV-0119 |
| [AR-07](BACKLOG.md#ar-07) | 1 | 5 | done | none | AR-07-A1 | EV-0121 |
| [AR-08](BACKLOG.md#ar-08) | 1 | 5 | done | none | AR-08-A1 | EV-0138 |
| [FR-01](BACKLOG.md#fr-01) | 1 | 9 | done | none | FR-01-A2 | EV-0201 |
| [FR-02](BACKLOG.md#fr-02) | 2 | 10 | done | none | FR-02-A2 | EV-0212 |
| [FR-03](BACKLOG.md#fr-03) | 1 | 6 | done | none | FR-03-A1 | EV-0227 |
| [TL-01](BACKLOG.md#tl-01) | 1 | 6 | done | none | TL-01-A1 | EV-0223 |
| [TL-02](BACKLOG.md#tl-02) | 1 | 6 | done | none | TL-02-A1 | EV-0289 |
| [TL-03](BACKLOG.md#tl-03) | 1 | 5 | done | none | none | EV-0360 |
| [TL-04](BACKLOG.md#tl-04) | 1 | 2 | ready | none | none | EV-0470 |
| [NP-01](BACKLOG.md#np-01) | 1 | 6 | done | none | NP-01-A1 | EV-0193 |
| [NQ-01](BACKLOG.md#nq-01) | 1 | 2 | queued | native execution authorization by Andrew | none | EV-0470 |
| [ART-01](BACKLOG.md#art-01) | 1 | 1 | queued | FR-09, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-02](BACKLOG.md#art-02) | 1 | 1 | queued | ART-01, FR-09, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-03](BACKLOG.md#art-03) | 1 | 1 | queued | ART-01, ART-02, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-04](BACKLOG.md#art-04) | 1 | 1 | queued | ART-03, FR-09, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-05](BACKLOG.md#art-05) | 1 | 1 | queued | ART-03, FR-09, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-06](BACKLOG.md#art-06) | 1 | 1 | queued | ART-03, ART-04, ART-05, Q-E01, Q-E03, Q-P26, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-07](BACKLOG.md#art-07) | 1 | 1 | queued | ART-02, ART-03, ART-04, Q-E01, Q-E03, Q-P06, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-08](BACKLOG.md#art-08) | 1 | 1 | queued | ART-02, ART-03, ART-04, ART-06, Q-E01, Q-E03, Q-P13, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-09](BACKLOG.md#art-09) | 1 | 1 | queued | ART-05, ART-06, Q-E01, Q-E03, Q-P26, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-10](BACKLOG.md#art-10) | 1 | 1 | queued | ART-05, ART-07, Q-E01, Q-E03, Q-P06, Q-P26, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-11](BACKLOG.md#art-11) | 1 | 1 | queued | ART-05, ART-08, ART-09, Q-E01, Q-E03, Q-P13, Q-P26, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-12](BACKLOG.md#art-12) | 1 | 1 | queued | ART-10, Q-E01, Q-E03, Q-P26, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-13](BACKLOG.md#art-13) | 1 | 1 | queued | ART-04, ART-11, Q-E01, Q-E03, Q-P13, Q-P20, Q-P26, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-14](BACKLOG.md#art-14) | 1 | 1 | queued | ART-05, ART-09, ART-12, ART-13, ART-17, ART-18, TH-29, TH-31, Q-E01, Q-E03, Q-E04, Q-P22, Q-P27, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-15](BACKLOG.md#art-15) | 1 | 1 | queued | ART-04, ART-11, Q-E01, Q-E03, Q-P13, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-16](BACKLOG.md#art-16) | 1 | 1 | queued | ART-13, ART-15, Q-E01, Q-E03, Q-P13, Q-P26, Q-P30, Q-P38, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-17](BACKLOG.md#art-17) | 1 | 1 | queued | NQ-01, ART-06, ART-09, SC-07, TH-29, TH-31, Q-E01, Q-E03, Q-E04, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-18](BACKLOG.md#art-18) | 1 | 1 | queued | NQ-01, ART-04, ART-07, ART-08, ART-10, ART-11, ART-12, ART-13, ART-17, SC-07, TH-29, TH-31, FR-09, Q-E01, Q-E03, Q-E04, Q-P06, Q-P13, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-19](BACKLOG.md#art-19) | 1 | 1 | queued | NQ-01, ART-15, ART-16, ART-18, SC-07, TH-29, TH-31, Q-E01, Q-E03, Q-E04, Q-P13, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-20](BACKLOG.md#art-20) | 1 | 1 | queued | FR-09, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-21](BACKLOG.md#art-21) | 1 | 1 | queued | ART-20, FR-09, Q-P25, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-22](BACKLOG.md#art-22) | 1 | 1 | queued | ART-21, Q-E01, Q-E03, Q-P25, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-23](BACKLOG.md#art-23) | 1 | 1 | queued | ART-22, Q-E01, Q-E03, Q-P25, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-29](BACKLOG.md#art-29) | 1 | 1 | queued | ART-21, ART-23, Q-E01, Q-P25, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-24](BACKLOG.md#art-24) | 1 | 1 | queued | NQ-01, ART-21, ART-22, ART-23, ART-29, SC-07, TH-29, TH-31, FR-09, Q-E01, Q-E03, Q-E04, Q-P25, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-25](BACKLOG.md#art-25) | 1 | 1 | queued | FR-09, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-26](BACKLOG.md#art-26) | 1 | 1 | queued | ART-25, Q-P23, concept stage: sprint authorization by Andrew | none | EV-0470 |
| [ART-27](BACKLOG.md#art-27) | 1 | 1 | queued | ART-26, Q-E01, Q-E03, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [ART-28](BACKLOG.md#art-28) | 1 | 1 | queued | NQ-01, ART-27, SC-07, TH-29, TH-31, Q-E01, Q-E03, Q-E04, Q-P23, Q-P26, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [SND-01](BACKLOG.md#snd-01) | 1 | 1 | queued | TH-17, FR-09, Q-E01, Q-P31, Q-P32, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [SND-02](BACKLOG.md#snd-02) | 1 | 1 | queued | SND-01, TH-17, FR-09, Q-E01, Q-P13, Q-P31, Q-P32, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [SND-03](BACKLOG.md#snd-03) | 1 | 1 | queued | SND-01, TH-17, FR-09, Q-E01, Q-P17, Q-P20, Q-P31, Q-P32, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [SND-04](BACKLOG.md#snd-04) | 1 | 1 | queued | ART-29, TH-17, FR-09, Q-E01, Q-P25, Q-P31, Q-P32, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [SND-05](BACKLOG.md#snd-05) | 1 | 1 | queued | NQ-01, SND-01, SND-02, SND-03, SND-04, SC-07, TH-17, TH-29, TH-31, FR-09, Q-E01, Q-E03, Q-P31, Q-E01 native slice and production authorization gate | none | EV-0470 |
| [JL-00](BACKLOG.md#jl-00) | 1 | 2 | done | none | JL-00-A1 | EV-0485 |
| [JL-01](BACKLOG.md#jl-01) | 1 | 4 | done | none | JL-01-A1 | EV-0489 |
| [JL-02](BACKLOG.md#jl-02) | 1 | 4 | done | none | JL-02-A1 | EV-0491 |
| [JL-03](BACKLOG.md#jl-03) | 1 | 4 | done | none | JL-03-A1 | EV-0493 |
| [JL-04](BACKLOG.md#jl-04) | 1 | 10 | done | none | JL-04-A3 | EV-0498 |
| [JL-05](BACKLOG.md#jl-05) | 1 | 4 | done | none | JL-05-A1 | EV-0499 |
| [JL-06](BACKLOG.md#jl-06) | 1 | 7 | done | none | JL-06-A2 | EV-0505 |
| [JL-07](BACKLOG.md#jl-07) | 1 | 5 | done | none | JL-07-A1 | EV-0500 |
| [JL-08](BACKLOG.md#jl-08) | 1 | 4 | done | none | JL-08-A1 | EV-0498 |
| [JL-05b](BACKLOG.md#jl-05b) | 1 | 4 | done | none | JL-05b-A1 | EV-0506 |
| [JL-05c](BACKLOG.md#jl-05c) | 1 | 4 | done | none | JL-05c-A1 | EV-0524 |
| [JL-09](BACKLOG.md#jl-09) | 1 | 5 | done | none | JL-09-A1 | EV-0517 |
| [JL-10](BACKLOG.md#jl-10) | 1 | 4 | done | none | JL-10-A1 | EV-0509 |
| [JL-11](BACKLOG.md#jl-11) | 1 | 5 | done | none | JL-11-A1 | EV-0514 |
| [JL-12](BACKLOG.md#jl-12) | 1 | 5 | done | none | JL-12-A1 | EV-0511 |
| [JL-13](BACKLOG.md#jl-13) | 1 | 5 | done | none | JL-13-A1 | EV-0534 |
| [JL-14](BACKLOG.md#jl-14) | 1 | 5 | done | none | JL-14-A1 | EV-0523 |
| [JL-15](BACKLOG.md#jl-15) | 1 | 5 | done | none | JL-15-A1 | EV-0520 |
| [JL-16](BACKLOG.md#jl-16) | 1 | 5 | done | none | JL-16-A1 | EV-0519 |
| [JL-17](BACKLOG.md#jl-17) | 1 | 5 | done | none | JL-17-A1 | EV-0542 |
| [JL-18](BACKLOG.md#jl-18) | 2 | 6 | done | none | JL-18-A1 | EV-0529 |
| [JL-18b](BACKLOG.md#jl-18b) | 1 | 5 | done | none | JL-18b-A1 | EV-0536 |
| [JL-18c](BACKLOG.md#jl-18c) | 1 | 7 | done | none | JL-18c-A1 | EV-0541 |
| [JL-19](BACKLOG.md#jl-19) | 1 | 7 | done | none | JL-19-A1 | EV-0534 |
| [JL-20](BACKLOG.md#jl-20) | 1 | 5 | done | none | JL-20-A1 | EV-0534 |
| [JL-21](BACKLOG.md#jl-21) | 1 | 2 | done | none | none | EV-0546 |
| [JL-21b](BACKLOG.md#jl-21b) | 1 | 2 | done | none | none | EV-0566 |
| [JL-22](BACKLOG.md#jl-22) | 1 | 2 | done | none | none | EV-0545 |
| [JL-23](BACKLOG.md#jl-23) | 1 | 2 | done | none | none | EV-0549 |
| [JL-24](BACKLOG.md#jl-24) | 1 | 2 | done | none | none | EV-0544 |
| [JL-25](BACKLOG.md#jl-25) | 2 | 1 | done | none | none | EV-0551 |
| [JL-26](BACKLOG.md#jl-26) | 1 | 1 | done | none | none | EV-0553 |
| [JL-27](BACKLOG.md#jl-27) | 1 | 1 | done | none | none | EV-0559 |
| [JL-28](BACKLOG.md#jl-28) | 3 | 1 | done | none | none | EV-0576 |
| [JL-29](BACKLOG.md#jl-29) | 2 | 1 | done | none | none | EV-0577 |
| [JL-30](BACKLOG.md#jl-30) | 1 | 1 | done | none | none | EV-0569 |
| [JL-31](BACKLOG.md#jl-31) | 1 | 1 | done | none | none | EV-0571 |
| [DF-01](BACKLOG.md#df-01) | 1 | 4 | done | none | DF-01-A1 | EV-0584 |
| [DF-02](BACKLOG.md#df-02) | 1 | 4 | done | none | DF-02-A1 | EV-0584 |
| [DF-03](BACKLOG.md#df-03) | 1 | 5 | done | none | DF-03-A2 | EV-0584 |
| [DF-04](BACKLOG.md#df-04) | 1 | 4 | done | none | DF-04-A1 | EV-0586 |
| [DF-05](BACKLOG.md#df-05) | 1 | 1 | queued | scope authorization | none | EV-0587 |
| [AT-01](BACKLOG.md#at-01) | 1 | 7 | done | none | AT-01-A1 | EV-0595 |
| [AT-02](BACKLOG.md#at-02) | 1 | 4 | done | none | AT-02-A1 | EV-0598 |

## Question state index

At preparation handoff every question was open. Q-E07 is now resolved from Andrew's explicit private-publication instruction; every other answer remains null and no product value was inferred. These live states do not reopen choices the source-disposition table records as settled.

| Question | Record rev | State | Answer / evidence | Last event |
| --- | --- | --- | --- | --- |
| [Q-E01](BACKLOG.md#q-e01) | 2 | parked | none | EV-0480 |
| [Q-E03](BACKLOG.md#q-e03) | 2 | parked | none | EV-0480 |
| [Q-E04](BACKLOG.md#q-e04) | 2 | parked | none | EV-0480 |
| [Q-E05](BACKLOG.md#q-e05) | 3 | parked | HF-09-A1 engineering-half protocol recorded at EV-0170; product half unanswered. | EV-0480 |
| [Q-E06](BACKLOG.md#q-e06) | 1 | open | none | EV-0004 |
| [Q-E07](BACKLOG.md#q-e07) | 2 | resolved | Andrew: private `bananahana720/scrapkeep`; default `main`; publish `main` and `codex/lightning-playtest`. Authorization (`artifacts/publication-2026-09-06/AUTHORIZATION.md`). | EV-0007 |
| [Q-E08](BACKLOG.md#q-e08) | 2 | parked | none | EV-0480 |
| [Q-E09](BACKLOG.md#q-e09) | 6 | resolved | Andrew, 16 September 2026: discovery facts commit only at the next durable transition; no immediate transition. Engineering-half protocols at EV-0144, EV-0151, EV-0157, EV-0163 retained as history; protocol half carried by FR-05. | EV-0250 |
| [Q-E10](BACKLOG.md#q-e10) | 2 | open | Andrew, 17 September 2026 (EV-0303): scope is every attack commitment, enemy or player. Policy and limits still open. | EV-0303 |
| [Q-E11](BACKLOG.md#q-e11) | 2 | parked | none | EV-0480 |
| [Q-E12](BACKLOG.md#q-e12) | 2 | parked | none | EV-0480 |
| [Q-E13](BACKLOG.md#q-e13) | 2 | parked | none | EV-0480 |
| [Q-E14](BACKLOG.md#q-e14) | 2 | parked | none; registered at EV-0297 from the TH-06 review, non-blocking | EV-0480 |
| [Q-P01](BACKLOG.md#q-p01) | 2 | parked | none | EV-0480 |
| [Q-P02](BACKLOG.md#q-p02) | 2 | parked | none | EV-0480 |
| [Q-P03](BACKLOG.md#q-p03) | 2 | parked | none | EV-0480 |
| [Q-P04](BACKLOG.md#q-p04) | 2 | resolved | Andrew delegated, 16 September 2026 (EV-0372): construction C, cable hoop with separate discharge heads, selected by the coordinator on a Fable advisory; an override reopens it. | EV-0372 |
| [Q-P05](BACKLOG.md#q-p05) | 2 | parked | none | EV-0480 |
| [Q-P06](BACKLOG.md#q-p06) | 2 | open | Andrew, 16 September 2026 (EV-0372): first pilot only; Fuse supplies the first complete kit; the other four stay candidates. Roster size, species and animal-only cast open. | EV-0372 |
| [Q-P07](BACKLOG.md#q-p07) | 1 | open | none | EV-0004 |
| [Q-P08](BACKLOG.md#q-p08) | 2 | parked | none | EV-0480 |
| [Q-P09](BACKLOG.md#q-p09) | 2 | parked | none | EV-0480 |
| [Q-P10](BACKLOG.md#q-p10) | 2 | open | Andrew, 16 September 2026 (EV-0255): growth at the next intermission; material consumed as collected, milestones the durable trace; attraction through cover. Costs, supply and mass values open. | EV-0255 |
| [Q-P11](BACKLOG.md#q-p11) | 2 | parked | none | EV-0480 |
| [Q-P12](BACKLOG.md#q-p12) | 2 | open | Andrew, 16 September 2026 (EV-0273): fixed start, no repeats, any order; fourth world's boss is the finale; levels per world a tuning parameter. Eligibility details and counts open. | EV-0273 |
| [Q-P13](BACKLOG.md#q-p13) | 3 | parked | Andrew, 17 September 2026 (EV-0322): a miscast never changes the previewed danger shape. Pool, eligibility, frequency, severity and warnings open. | EV-0480 |
| [Q-P14](BACKLOG.md#q-p14) | 3 | parked | HF-06a-A1 engineering-half protocol recorded at EV-0144; product half unanswered. | EV-0480 |
| [Q-P15](BACKLOG.md#q-p15) | 4 | parked | HF-06a-A1 and HF-06b-A1 engineering-half protocols recorded at EV-0144 and EV-0151; product half unanswered. | EV-0480 |
| [Q-P16](BACKLOG.md#q-p16) | 4 | resolved | Andrew, 16 September 2026: interruption P1 (resume at the last completed level, run.interruption null); revival R2 (in place, health value to tuning). Protocol half carried by FR-05. Confirmed 17 September 2026 (EV-0300): an intermission equipment swap is lost with an interrupted level. | EV-0300 |
| [Q-P17](BACKLOG.md#q-p17) | 2 | parked | none | EV-0480 |
| [Q-P18](BACKLOG.md#q-p18) | 3 | parked | Andrew, 17 September 2026 (EV-0314): a slot's tree is fixed for the character; a respec changes node selections only. Grant, frequency, scope and refunds open. | EV-0480 |
| [Q-P19](BACKLOG.md#q-p19) | 2 | parked | none | EV-0480 |
| [Q-P20](BACKLOG.md#q-p20) | 2 | parked | none | EV-0480 |
| [Q-P21](BACKLOG.md#q-p21) | 2 | proposed | Partial, from Andrew's play of the ball lab: rigid-body rolling at the ball-lab defaults is his movement baseline (playtest log (`docs/playtests/PLAYTEST-LOG.md`) entry 2). He also asked for class- or item-driven mobility such as a grapple and air maneuverability. Defensive rhythm and the human acceptance procedure stay open. | EV-0481 |
| [Q-P22](BACKLOG.md#q-p22) | 1 | open | none | EV-0004 |
| [Q-P23](BACKLOG.md#q-p23) | 2 | open | Andrew, 16 September 2026 (EV-0275): the five catalogue worlds are the launch run-region set; ids and content open. | EV-0275 |
| [Q-P24](BACKLOG.md#q-p24) | 1 | open | none | EV-0004 |
| [Q-P25](BACKLOG.md#q-p25) | 3 | parked | Andrew, 16 September 2026 (EV-0275): the five catalogue worlds are the launch run-region set; ids and content open. | EV-0480 |
| [Q-P26](BACKLOG.md#q-p26) | 12 | parked | Andrew, 16 September 2026 (EV-0372, EV-0423, EV-0447): first batch asset list and file locations recorded before the budget (shared core and cockpit, Fuse hoop and tool at starting mech, Iron Orchard enemy family and module set); blockouts before the native slice, final assets after. Measured budget open. | EV-0480 |
| [Q-P27](BACKLOG.md#q-p27) | 2 | open | Andrew, 16 September 2026 (EV-0372): hybrid, procedural Godot motion for core, suspension and retraction; hand-keyed Blender clips for pilot and tool actions. Specifics open. | EV-0372 |
| [Q-P28](BACKLOG.md#q-p28) | 2 | parked | none | EV-0480 |
| [Q-P29](BACKLOG.md#q-p29) | 2 | parked | none | EV-0480 |
| [Q-P30](BACKLOG.md#q-p30) | 2 | parked | none | EV-0480 |
| [Q-P31](BACKLOG.md#q-p31) | 2 | parked | none | EV-0480 |
| [Q-P32](BACKLOG.md#q-p32) | 5 | open | Andrew, 17 September 2026 (EV-0284): a presentation-owned aim point is unlockable only by a TADR-002 amendment; Q-P32 owns bounds, which stay open until a native slice plays; reduced motion a saved preference (EV-0248). | EV-0447 |
| [Q-P33](BACKLOG.md#q-p33) | 1 | open | none | EV-0004 |
| [Q-P34](BACKLOG.md#q-p34) | 2 | parked | none | EV-0480 |
| [Q-P35](BACKLOG.md#q-p35) | 2 | parked | none | EV-0480 |
| [Q-P36](BACKLOG.md#q-p36) | 2 | parked | none | EV-0480 |
| [Q-P37](BACKLOG.md#q-p37) | 2 | parked | none | EV-0480 |
| [Q-P38](BACKLOG.md#q-p38) | 2 | open | Andrew, 17 September 2026 (EV-0296): a same-tick completion and lethal hero outcome resolves as defeat wins; the completion counts only if the hero is alive after R2 revive. Types, rewards and reconfiguration boundaries open. | EV-0296 |
| [Q-P39](BACKLOG.md#q-p39) | 2 | resolved | Andrew, 16 September 2026: abandoning a live run is a defeat; Transition D with outcome lost, then S. Protocol half carried by FR-05. | EV-0247 |
| [Q-P41](BACKLOG.md#q-p41) | 2 | resolved | Andrew, 16 September 2026: hold the encounter and show a diagnostic. Protocol half carried by FR-05. | EV-0247 |
| [Q-P40](BACKLOG.md#q-p40) | 1 | resolved | Andrew, 15 September 2026: terminal means over for victory and defeat; a separate outcome fact records won versus lost. Protocol half carried by FR-02 revision 2. | EV-0202 |
| [Q-P42](BACKLOG.md#q-p42) | 2 | parked | Andrew, 16 September 2026 (EV-0447 decision 3): hybrid approach, procedural locomotion and turning in Godot with hand-keyed Blender wind-up and attack clips; per-member treatment open. | EV-0480 |
| [Q-P43](BACKLOG.md#q-p43) | 2 | parked | none | EV-0480 |
| [Q-P44](BACKLOG.md#q-p44) | 2 | parked | none | EV-0480 |
| [Q-P45](BACKLOG.md#q-p45) | 2 | parked | none | EV-0480 |
| [Q-P46](BACKLOG.md#q-p46) | 2 | parked | none | EV-0480 |
| [Q-P47](BACKLOG.md#q-p47) | 2 | parked | none | EV-0480 |
| [Q-P48](BACKLOG.md#q-p48) | 2 | parked | none | EV-0480 |

## Append-only events

Events EV-0001 to EV-0057 are in EVENTS-0001-0057.md (`docs/project/tracking/EVENTS-0001-0057.md`). Events EV-0058 to EV-0627, the preparation and sprint closure records and the per-card attempt records are in EVENTS-0058-0627.md (`docs/project/tracking/EVENTS-0058-0627.md`). New events start at EV-0628.

| Sequence | UTC timestamp | Actor / kind | Affected records | Change and evidence |
| --- | --- | --- | --- | --- |

## Next bounded foundation proposal

**Historical record, superseded.** This proposal was superseded by the fourteen-card foundation authorization at EV-0078. It grants no dispatch authority, and the `awaiting_review` status below is retained as the state it held when it was written, not as a current claim.

Authorization: **awaiting_review**. Approval owner: Andrew. Objective: define production path ownership and a constraints/evidence register so subsequent foundation contracts have consistent inputs. This proposal grants no dispatch authority. Operational Sprint 0 must first satisfy its outstanding integration evidence; a discovered integration failure takes priority over this proposal.

| Selected revision | Size | Dependency order / initial readiness | Permitted action types | Acceptance |
| --- | --- | --- | --- | --- |
| HF-01 revision 2 | M | First wave; no task predecessors or blocking questions; input-ready | Scoped documentation, official-source research, structure/link checks, independent review | Deliver the five-column path-family table, exact ownership and contribution rules, preserve both browser proofs, reconcile existing S0 scaffold evidence, satisfy every current HF-01 DoD item. |
| HF-02 revision 2 | S | Same first wave; no task predecessors or blocking questions; input-ready | Scoped documentation, evidence inspection, structure/link checks, independent review | Deliver the four-class constraints/evidence register, units/method/identity/owner for each proposed budget, source tags on numbers, named unknowns, satisfy every current HF-02 DoD item. |

Canonical scopes and exact write sets remain [HF-01](BACKLOG.md#hf-01) and [HF-02](BACKLOG.md#hf-02). Admit serially after independent review. No build, engine changes or feature implementation belongs to this documentation-only proposal. Other twelve foundation cards are outside this bounded sprint.

Inputs checked: accepted TADRs, contribution rules, both preserved proofs, existing S0 scaffold/runtime evidence, historical browser evidence and named questions. The coordinator resolved [Godot 4.7 project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html) on 6 September 2026 for HF-01's future packet. Before initial dispatch, the coordinator must create the sections directory and index stub required by HF-01; the two proposed output files remain disjoint. Q-E03 and Q-E04 remain unresolved constraints for HF-02 to record; they do not block its documentation-only register. Q-E01 and Q-E06 remain open for later direction and licensing decisions. No proposed answer is inferred from Sprint 0's synthetic fixtures.

## Operational Sprint 0 closure record

Outcome: **passed**. Tested integrated source: `e54e429c76f3d83641c0127b4e44fe7eb8b2098f`. S0-09 through S0-14 are done; S0-01 through S0-08 retain their original completions. All delivery and closure leases are closed. This is the sole completed-sprint event for this source. The earlier pending receipt is preserved, not rewritten as a success.

Final closure receipt (`docs/project/sprint-0/closure.json`) and `artifacts/local/sprint-0/closed/closure-result.json` record every required gate passed with no issues. The same receipt returned identical PASS twice without canonical mutations. Synthetic variants with missing CI, stale CI, failed CI or unauthorized next-sprint dispatch failed closed. `repeat-receipt.json` retains their exact outcomes and before/after board hashes. The later administrative commit records this result; it is not retroactively the runtime-tested commit.

Verification at that source: fresh locked-dependency checkout, document/project checks, full six-stage verification,92 independently executed targeted scenario/document/harness tests, and37 real native checks. [CI run34060932888](https://github.com/bananahana720/scrapkeep/actions/runs/34060932888) passed on local ephemeral runnerid2, exported Linux/Windows and executed Linux fresh-process resume, injected faults, offline cases and save/source preservation. CI's report exactly matches its logged JSON. GitHub timing reports an empty billable map and the artifact API reports zero uploads. The runner exited0, unregistered and its temporary directory was removed; no service or registered repository runner remains.

The final Linux export visibly reported Resume passed,16 checks,0 failures; the observed Exit button returned code0 and saved bytes stayed unchanged. The first refreshed capture attempt expired while its parent preview was hidden; its failure is retained in `closed/visible/`. After showing the owned preview, the separate `closed/visible-2/` run passed. Both browser proofs and their source remain preserved; no browser UI path changed. Windows execution, performance/hardware qualification and Pillars/human enjoyment remain untested. This is a synthetic technical integration proof.

Fresh independent integrated review: s0_final_fresh, gpt-6-astra high, PASS. Separate fresh coverage review: s0_review_coverage, gpt-6-astra high, PASS. Reports and hashed evidence are under `artifacts/local/sprint-0/closed/`. Earlier reused-session reviews remain historical supporting evidence. The new fresh reviews resolve the previous capacity gap.

Retro: initial closeout record defects and historical-prerequisite validation were repaired within S0-10/S0-13. S0-09's consumed-template pinning and config isolation were corrected in attempt2; real GitHub workflow parsing exposed unsupported job-level context placement, corrected and freshly reviewed in the final allowed attempt3. No new repair card duplicates those resolved defects. The coordinator reconciled the amendment inventory: no live specification amendment was submitted and no accepted amendment remains unapplied. These fixes preserve accepted product/architecture decisions. For S0-09 revision3 DoD4, the explicit final sentence and Andrew's local-run clarification govern report retention in logs/summary without uploaded artifact storage; the older phrase about uploading report.json does not authorize an artifact upload. The pinned card revision and its historical wording are preserved.

Next proposal: HF-01 revision2 (M) and HF-02 revision2 (S), documentation only, objective and acceptance detailed above. Inputs remain ready; Q-E03/Q-E04 are register unknowns, not invented budgets. The coordinator creates the sections index before any approved dispatch. This proposal remains **awaiting_review**. No foundation work was started or dispatched. Q-E06 remains open. The other twelve foundation cards remain outside the bounded proposal.

## Foundation-02 proposal

**Historical record, superseded.** This proposal was superseded by the fourteen-card foundation authorization at EV-0078. It grants no dispatch authority, and the `awaiting_review` status below is retained as the state it held when it was written, not as a current claim.

Authorization: **awaiting_review**. Approval owner: Andrew. Objective: define one session's mutable-record ownership and the allowed dependency paths used by attack, equipment and encounter changes.

| Selected card | Size | Dependency order and readiness | Permitted actions | Acceptance |
| --- | --- | --- | --- | --- |
| HF-03a revision 1 | M | First; input-ready after HF-01 admission and current source recheck. Sole eligible initial dispatch card after Andrew approves this proposal. | Scoped documentation, official source research, source/scenario checks, independent review. | Five-column module table covering owned mutable records, imports, commands and published results under one session authority; every required owner and ADR citation, no duplicate mutator. |
| HF-03b revision 1 | M | Second; requires admitted HF-03a output. Not input-ready for initial dispatch. | Scoped documentation, dependency-cycle and walkthrough checks, independent review. | Reproducible dependency adjacency/cycle check; attack, equipment and encounter walkthroughs use only listed interfaces and preserve committed geometry. |

Exact source inputs and file leases remain in [HF-03a](BACKLOG.md#hf-03a) and [HF-03b](BACKLOG.md#hf-03b). This is a two-card documentation sprint; no build, engine changes, asset admission, runtime feature or automatic future dispatch follows. A newly observed integration failure takes priority over this proposal.

The coordinator resolved the official Godot 4.7 [autoload](https://docs.godotengine.org/en/4.7/tutorials/scripting/singletons_autoload.html) and [GDScript class/preload reference](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html) on 6 September 2026 for the eventual HF-03a packet. Accepted TADR-002 session ownership governs their use; an autoload alone does not enforce singleton ownership. Existing native proofs must be inspected at assignment without a new execution claim.

Unresolved questions: no blocking owner question for either documentation card. Q-E03 budgets, Q-E04 renderer and applicable product parameters remain unanswered and must not be invented in the contracts. If a walkthrough needs such an answer, record the boundary and gate dependent implementation. HF-03b's absent producer output is a real dependency; approval cannot substitute for it. Next-sprint proposal status grants no execution authority.
