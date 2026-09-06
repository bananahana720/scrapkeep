# Scrapkeep execution board

Schema 1. Coordinator-owned in-repo board. Prepared 6 September 2026.

Use this file as the only execution-state authority. [BACKLOG.md](BACKLOG.md) defines tasks, dependencies and questions; [ORCHESTRATOR.md](ORCHESTRATOR.md) defines operating rules. The [Bible](BIBLE.md) and [engineering ADRs](adr/README.md) remain product and architecture authority. No external board, issue tracker or duplicate live queue is configured.

## Program authorization

| Field | Value |
| --- | --- |
| Preparation | Authorized by Andrew's explicit instruction to implement the three-document plan. |
| Proposed sprint | HF-01 through HF-10, foundation engineering contracts only. |
| Sprint authorization | **awaiting_review** for HF-01..HF-10 as originally proposed. Andrew's 6 September instruction ("proceed with all recommendations based on findings and orchestrate work ... to get the project state 100% prepared for sprint 0") authorizes the **prepare-stage program PS-01..PS-nn** defined from the [accepted audit](artifacts/ai-first-audit-2026-09-06/AI-FIRST-AUDIT-2026-09-06.md): its 18 recommendations and draft cards S0-01..S0-08 (S0-09 stays parked). HF cards remain unstarted until their amended revisions are admitted. |
| Native game/build authorization | **prepare-stage proofs only.** The pinned Godot 4.7.2 standard editor is installed on this machine under Andrew's confirmation (EV-0024); export templates and exports (S0-09) stay parked. Proof code lives under `native/` and proves ADR rules only; no game feature, asset or qualification run is authorized. |
| Active coordinator for sprint execution | This Claude Code session (claude-fable-5-1; configured xhigh, actual effort unconfirmed per the audit). Delegates run on the project definitions at low, medium, high or xhigh as recorded per lease; Andrew authorized low and medium effort for prepare-stage units on 6 September 2026. |
| Active task attempts / write leases | See the Active attempt records below. PUB-01-A1 accepted and PUB-01-L1 closed. |
| Remote / publication | Verified [private bananahana720/scrapkeep](https://github.com/bananahana720/scrapkeep), default `main`; only `main` and `codex/lightning-playtest` published. See the accepted PUB-01 attempt and [publication receipt](artifacts/publication-2026-09-06/publication.json). |

Ready means that a selected card has complete inputs. It does not bypass the program authorization row. HF-01 and HF-02 can be ready while the proposed sprint is awaiting review. No foundation-sprint row represents work already started or a future result already produced. PUB-01 is the separately authorized publication task.

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

When assigning a task, add its expanded record under Active attempt records and record every field above. The compact row remains the workflow-state index; the expanded record supplies the nonduplicated attempt details. Do not repeat its state in the expanded record. After closure, retain the attempt record and evidence as history and reference the accepted attempt from the task row.

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
- Historical owned files: the explicit PUB-01 publication edit set. Pre-existing planning files are admitted from the publication baseline, with the completed repository-local workflow package admitted unchanged from [its frozen manifest](artifacts/publication-2026-09-06/concurrent-package.json).
- Base identity: `dc72a02cd7a0fbe1f00b3ce71d36448364f93294` plus that publication baseline manifest.
- Candidate identity: [publication candidate manifest](artifacts/publication-2026-09-06/candidate-manifest.json). Integrated identity: `73c427203c9263affa747938e586325842357b0c`; closeout identity: `6d7967856448c2f4d5e2f7b316e59b72c0bd4560`. Both stages committed serially and verified remotely; [closeout verification](artifacts/publication-2026-09-06/closeout-verification.json) precedes this terminal event.
- Latest checkpoint: 2026-09-06T16:40:13+00:00; all publication and closeout requirements verified, including both remote tips and clean working tree at `6d7967856448c2f4d5e2f7b316e59b72c0bd4560`. PUB-01 complete; no active worker or sprint lease. The terminal record is committed after this observed result.
- Evidence: [authorization](artifacts/publication-2026-09-06/AUTHORIZATION.md), [document checks](artifacts/publication-2026-09-06/document-checks.json), [content screen](artifacts/publication-2026-09-06/content-screen.json), [independent review](artifacts/publication-2026-09-06/REVIEW.md); [verified remote publication](artifacts/publication-2026-09-06/publication.json).
- Review: private_publication_review (independent Astra), **PASS+NOTES** on the pinned candidate and evidence overlay; [report](artifacts/publication-2026-09-06/REVIEW.md). Six original whitespace warnings accepted with preservation proof. No sprint worker has been assigned.


## Task state index

Blockers marked dependency refer to the pinned card's exact dependency list in BACKLOG. They are not new task definitions. At initialization all future dependencies are unfinished. Program authorization remains an additional dispatch gate for every row.

| Task ID | Card rev | Record rev | State | Blockers / admission | Accepted attempt | Last event |
| --- | --- | --- | --- | --- | --- | --- |
| [PUB-01](BACKLOG.md#pub-01) | 2 | 11 | done | none | PUB-01-A1 | EV-0018 |
| PS-01 (audit rec 3, 13, 17; S0-02, S0-03) | interim | 4 | review | none | none | EV-0025 |
| PS-02 (audit rec 5, 12) | interim | 5 | done | none | PS-02-A1 | EV-0025 |
| PS-03 (audit rec 6, 7, 16; settings effort key) | interim | 2 | in_progress | none | none | EV-0025 |
| PS-04 (audit rec 2, 4, 8, 11; S0 import) | interim | 4 | in_progress | none | none | EV-0024 |
| PS-05 (audit rec 9, 14, 15) | interim | 1 | queued | PS-01 (package.json, tests/ overlap) | none | EV-0023 |
| PS-06 (S0-01, S0-04, S0-05, S0-06, S0-07, S0-08) | interim | 2 | queued | PS-01 | none | EV-0024 |
| [HF-01](BACKLOG.md#hf-01) | 1 | 2 | ready | Sprint authorization awaiting_review | none | EV-0003 |
| [HF-02](BACKLOG.md#hf-02) | 1 | 2 | ready | Sprint authorization awaiting_review | none | EV-0003 |
| [HF-03](BACKLOG.md#hf-03) | 1 | 1 | queued | HF-01 | none | EV-0002 |
| [HF-04](BACKLOG.md#hf-04) | 1 | 1 | queued | HF-03 | none | EV-0002 |
| [HF-05](BACKLOG.md#hf-05) | 1 | 1 | queued | HF-03 | none | EV-0002 |
| [HF-06](BACKLOG.md#hf-06) | 1 | 1 | queued | HF-05 | none | EV-0002 |
| [HF-07](BACKLOG.md#hf-07) | 1 | 1 | queued | HF-04, HF-06 | none | EV-0002 |
| [HF-08](BACKLOG.md#hf-08) | 1 | 1 | queued | HF-07 | none | EV-0002 |
| [HF-09](BACKLOG.md#hf-09) | 1 | 1 | queued | HF-06, HF-07 | none | EV-0002 |
| [HF-10](BACKLOG.md#hf-10) | 1 | 1 | queued | HF-01, HF-02, HF-03, HF-04, HF-05, HF-06, HF-07, HF-08, HF-09 | none | EV-0002 |
| [PD-01](BACKLOG.md#pd-01) | 1 | 1 | queued | HF-01 | none | EV-0002 |
| [PD-02](BACKLOG.md#pd-02) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [PD-03](BACKLOG.md#pd-03) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [TH-01](BACKLOG.md#th-01) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-02](BACKLOG.md#th-02) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-03](BACKLOG.md#th-03) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-04](BACKLOG.md#th-04) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-05](BACKLOG.md#th-05) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-06](BACKLOG.md#th-06) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-07](BACKLOG.md#th-07) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-08](BACKLOG.md#th-08) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-09](BACKLOG.md#th-09) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-10](BACKLOG.md#th-10) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-11](BACKLOG.md#th-11) | 1 | 1 | queued | HF-10 | none | EV-0002 |
| [TH-12](BACKLOG.md#th-12) | 1 | 1 | queued | HF-10, PD-02 | none | EV-0002 |
| [TH-13](BACKLOG.md#th-13) | 1 | 1 | queued | TH-03, TH-04 | none | EV-0002 |
| [TH-14](BACKLOG.md#th-14) | 1 | 1 | queued | TH-06, TH-11 | none | EV-0002 |
| [TH-15](BACKLOG.md#th-15) | 1 | 1 | queued | TH-02, TH-03 | none | EV-0002 |
| [TH-16](BACKLOG.md#th-16) | 1 | 1 | queued | TH-03, TH-05, TH-10, PD-01 | none | EV-0002 |
| [TH-17](BACKLOG.md#th-17) | 1 | 1 | queued | TH-04, TH-12, PD-03 | none | EV-0002 |
| [TH-18](BACKLOG.md#th-18) | 1 | 1 | queued | HF-04, TH-02, TH-12 | none | EV-0002 |
| [TH-19](BACKLOG.md#th-19) | 1 | 1 | queued | HF-05, TH-16 | none | EV-0002 |
| [TH-20](BACKLOG.md#th-20) | 1 | 1 | queued | HF-06, SC-01, SC-02, SC-03, SC-04, SC-05, SC-06, SC-07, SC-08 | none | EV-0002 |
| [TH-21](BACKLOG.md#th-21) | 1 | 1 | queued | HF-08, HF-09, TH-20 | none | EV-0002 |
| [TH-22](BACKLOG.md#th-22) | 1 | 1 | queued | TH-20, TH-21 | none | EV-0002 |
| [TH-23](BACKLOG.md#th-23) | 1 | 1 | queued | TH-01, TH-13, TH-15, TH-18, TH-02, TH-03, TH-04, TH-05, TH-06, TH-07, TH-08, TH-09, TH-10, TH-11, TH-12 | none | EV-0002 |
| [TH-24](BACKLOG.md#th-24) | 1 | 1 | queued | HF-02, TH-16, TH-19 | none | EV-0002 |
| [TH-25](BACKLOG.md#th-25) | 1 | 1 | queued | TH-18, TH-21, TH-24 | none | EV-0002 |
| [TH-26](BACKLOG.md#th-26) | 1 | 1 | queued | HF-03, TH-14, TH-23 | none | EV-0002 |
| [TH-27](BACKLOG.md#th-27) | 1 | 1 | queued | TH-13, TH-14, TH-15, TH-16, TH-17, TH-18, TH-21, TH-01 | none | EV-0002 |
| [TH-28](BACKLOG.md#th-28) | 1 | 1 | queued | TH-22, TH-23, TH-24, TH-25, TH-26, TH-27 | none | EV-0002 |
| [TH-29](BACKLOG.md#th-29) | 1 | 1 | queued | TH-22, TH-23, TH-24, TH-25, TH-26, TH-28 | none | EV-0002 |
| [TH-30](BACKLOG.md#th-30) | 1 | 1 | queued | HF-01, HF-02, HF-03, HF-04, HF-05, HF-06, HF-07, HF-08, HF-09, HF-10, TH-01, TH-02, TH-03, TH-04, TH-05, TH-06, TH-07, TH-08, TH-09, TH-10, TH-11, TH-12, TH-13, TH-14, TH-15, TH-16, TH-17, TH-18, TH-19, TH-20, TH-21, TH-22, TH-23, TH-24, TH-25, TH-26, TH-27, TH-28, TH-29, SC-01, SC-02, SC-03, SC-04, SC-05, SC-06, SC-07, SC-08 | none | EV-0002 |
| [TH-31](BACKLOG.md#th-31) | 1 | 1 | queued | TH-30 | none | EV-0002 |
| [SC-01](BACKLOG.md#sc-01) | 1 | 1 | queued | HF-06, TH-04, TH-07 | none | EV-0002 |
| [SC-02](BACKLOG.md#sc-02) | 1 | 1 | queued | HF-06, TH-03, TH-04, TH-13 | none | EV-0002 |
| [SC-03](BACKLOG.md#sc-03) | 1 | 1 | queued | HF-06, TH-08, TH-09 | none | EV-0002 |
| [SC-04](BACKLOG.md#sc-04) | 1 | 1 | queued | HF-06, TH-06 | none | EV-0002 |
| [SC-05](BACKLOG.md#sc-05) | 1 | 1 | queued | HF-06, TH-11, TH-14 | none | EV-0002 |
| [SC-06](BACKLOG.md#sc-06) | 1 | 1 | queued | HF-06, TH-10 | none | EV-0002 |
| [SC-07](BACKLOG.md#sc-07) | 1 | 1 | queued | HF-06, TH-12, TH-16, TH-17 | none | EV-0002 |
| [SC-08](BACKLOG.md#sc-08) | 1 | 1 | queued | HF-06, TH-09, TH-11 | none | EV-0002 |
| [LG-01](BACKLOG.md#lg-01) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [LG-02](BACKLOG.md#lg-02) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [LG-03](BACKLOG.md#lg-03) | 1 | 1 | queued | Separate wave admission | none | EV-0002 |
| [LG-04](BACKLOG.md#lg-04) | 1 | 1 | queued | LG-03 | none | EV-0002 |
| [LG-05](BACKLOG.md#lg-05) | 1 | 1 | queued | LG-03, LG-04 | none | EV-0002 |
| [LG-07](BACKLOG.md#lg-07) | 1 | 1 | queued | LG-03 | none | EV-0002 |

## Question state index

At preparation handoff every question was open. Q-E07 is now resolved from Andrew's explicit private-publication instruction; every other answer remains null and no product value was inferred. These live states do not reopen choices the source-disposition table records as settled.

| Question | Record rev | State | Answer / evidence | Last event |
| --- | --- | --- | --- | --- |
| [Q-E01](BACKLOG.md#q-e01) | 1 | open | none | EV-0004 |
| [Q-E03](BACKLOG.md#q-e03) | 1 | open | none | EV-0004 |
| [Q-E04](BACKLOG.md#q-e04) | 1 | open | none | EV-0004 |
| [Q-E05](BACKLOG.md#q-e05) | 1 | open | none | EV-0004 |
| [Q-E06](BACKLOG.md#q-e06) | 1 | open | none | EV-0004 |
| [Q-E07](BACKLOG.md#q-e07) | 2 | resolved | Andrew: private `bananahana720/scrapkeep`; default `main`; publish `main` and `codex/lightning-playtest`. [Authorization](artifacts/publication-2026-09-06/AUTHORIZATION.md). | EV-0007 |
| [Q-E08](BACKLOG.md#q-e08) | 1 | open | none | EV-0004 |
| [Q-E09](BACKLOG.md#q-e09) | 1 | open | none | EV-0004 |
| [Q-E10](BACKLOG.md#q-e10) | 1 | open | none | EV-0004 |
| [Q-E11](BACKLOG.md#q-e11) | 1 | open | none | EV-0004 |
| [Q-E12](BACKLOG.md#q-e12) | 1 | open | none | EV-0004 |
| [Q-E13](BACKLOG.md#q-e13) | 1 | open | none | EV-0004 |
| [Q-P01](BACKLOG.md#q-p01) | 1 | open | none | EV-0004 |
| [Q-P02](BACKLOG.md#q-p02) | 1 | open | none | EV-0004 |
| [Q-P03](BACKLOG.md#q-p03) | 1 | open | none | EV-0004 |
| [Q-P04](BACKLOG.md#q-p04) | 1 | open | none | EV-0004 |
| [Q-P05](BACKLOG.md#q-p05) | 1 | open | none | EV-0004 |
| [Q-P06](BACKLOG.md#q-p06) | 1 | open | none | EV-0004 |
| [Q-P07](BACKLOG.md#q-p07) | 1 | open | none | EV-0004 |
| [Q-P08](BACKLOG.md#q-p08) | 1 | open | none | EV-0004 |
| [Q-P09](BACKLOG.md#q-p09) | 1 | open | none | EV-0004 |
| [Q-P10](BACKLOG.md#q-p10) | 1 | open | none | EV-0004 |
| [Q-P11](BACKLOG.md#q-p11) | 1 | open | none | EV-0004 |
| [Q-P12](BACKLOG.md#q-p12) | 1 | open | none | EV-0004 |
| [Q-P13](BACKLOG.md#q-p13) | 1 | open | none | EV-0004 |
| [Q-P14](BACKLOG.md#q-p14) | 1 | open | none | EV-0004 |
| [Q-P15](BACKLOG.md#q-p15) | 1 | open | none | EV-0004 |
| [Q-P16](BACKLOG.md#q-p16) | 1 | open | none | EV-0004 |
| [Q-P17](BACKLOG.md#q-p17) | 1 | open | none | EV-0004 |
| [Q-P18](BACKLOG.md#q-p18) | 1 | open | none | EV-0004 |
| [Q-P19](BACKLOG.md#q-p19) | 1 | open | none | EV-0004 |
| [Q-P20](BACKLOG.md#q-p20) | 1 | open | none | EV-0004 |
| [Q-P21](BACKLOG.md#q-p21) | 1 | open | none | EV-0004 |
| [Q-P22](BACKLOG.md#q-p22) | 1 | open | none | EV-0004 |
| [Q-P23](BACKLOG.md#q-p23) | 1 | open | none | EV-0004 |
| [Q-P24](BACKLOG.md#q-p24) | 1 | open | none | EV-0004 |
| [Q-P25](BACKLOG.md#q-p25) | 1 | open | none | EV-0004 |
| [Q-P26](BACKLOG.md#q-p26) | 1 | open | none | EV-0004 |
| [Q-P27](BACKLOG.md#q-p27) | 1 | open | none | EV-0004 |
| [Q-P28](BACKLOG.md#q-p28) | 1 | open | none | EV-0004 |
| [Q-P29](BACKLOG.md#q-p29) | 1 | open | none | EV-0004 |
| [Q-P30](BACKLOG.md#q-p30) | 1 | open | none | EV-0004 |
| [Q-P31](BACKLOG.md#q-p31) | 1 | open | none | EV-0004 |
| [Q-P32](BACKLOG.md#q-p32) | 1 | open | none | EV-0004 |
| [Q-P33](BACKLOG.md#q-p33) | 1 | open | none | EV-0004 |
| [Q-P34](BACKLOG.md#q-p34) | 1 | open | none | EV-0004 |
| [Q-P35](BACKLOG.md#q-p35) | 1 | open | none | EV-0004 |
| [Q-P36](BACKLOG.md#q-p36) | 1 | open | none | EV-0004 |
| [Q-P37](BACKLOG.md#q-p37) | 1 | open | none | EV-0004 |
| [Q-P38](BACKLOG.md#q-p38) | 1 | open | none | EV-0004 |

## Append-only events

| Sequence | UTC timestamp | Actor / kind | Affected records | Change and evidence |
| --- | --- | --- | --- | --- |
| EV-0001 | 2026-09-06T15:43:30+00:00 | Coordinator / preparation authorization | program | Andrew authorized documentation preparation only. Foundation sprint awaiting_review; build authorization none. Source: accepted preparation plan; base dc72a02cd7a0fbe1f00b3ce71d36448364f93294 plus preserved dirty-source manifest. |
| EV-0002 | 2026-09-06T15:43:30+00:00 | Coordinator / definition import | HF-01, HF-02, HF-03, HF-04, HF-05, HF-06, HF-07, HF-08, HF-09, HF-10, PD-01, PD-02, PD-03, TH-01, TH-02, TH-03, TH-04, TH-05, TH-06, TH-07, TH-08, TH-09, TH-10, TH-11, TH-12, TH-13, TH-14, TH-15, TH-16, TH-17, TH-18, TH-19, TH-20, TH-21, TH-22, TH-23, TH-24, TH-25, TH-26, TH-27, TH-28, TH-29, TH-30, TH-31, SC-01, SC-02, SC-03, SC-04, SC-05, SC-06, SC-07, SC-08, LG-01, LG-02, LG-03, LG-04, LG-05, LG-07 | Imported card revision 1, record revision 1. Initial queued state; no assignments, leases, candidate or completion evidence. [BACKLOG](BACKLOG.md). |
| EV-0003 | 2026-09-06T15:43:30+00:00 | Coordinator / readiness | HF-01, HF-02 | queued → ready, record revision 1 → 2. Required sources exist and no task/question predecessors apply. Sprint dispatch remains unauthorized pending Andrew's review. |
| EV-0004 | 2026-09-06T15:43:30+00:00 | Coordinator / question import | Q-E01, Q-E03, Q-E04, Q-E05, Q-E06, Q-E07, Q-E08, Q-E09, Q-E10, Q-E11, Q-E12, Q-E13, Q-P01, Q-P02, Q-P03, Q-P04, Q-P05, Q-P06, Q-P07, Q-P08, Q-P09, Q-P10, Q-P11, Q-P12, Q-P13, Q-P14, Q-P15, Q-P16, Q-P17, Q-P18, Q-P19, Q-P20, Q-P21, Q-P22, Q-P23, Q-P24, Q-P25, Q-P26, Q-P27, Q-P28, Q-P29, Q-P30, Q-P31, Q-P32, Q-P33, Q-P34, Q-P35, Q-P36, Q-P37, Q-P38 | Initial open records, revision 1; wording and closure evidence in BACKLOG. No answers inferred. |
| EV-0005 | 2026-09-06T15:48:17+00:00 | Coordinator / preparation review | preparation package | Fresh Astra reviewer prep_artifact_review returned PASS on the [candidate identities](artifacts/swarm-prep-2026-09-06/candidate-manifest.json). [Review](artifacts/swarm-prep-2026-09-06/REVIEW.md) records corrected dependency, owner and historical-authority findings; [six paper scenarios](artifacts/swarm-prep-2026-09-06/tracking-scenarios.md) have explicit outcomes. Product/engineering workers supplied disjoint staging drafts during preparation; no sprint card was assigned or completed. |
| EV-0006 | 2026-09-06T15:48:17+00:00 | Coordinator / preparation handoff | program | preparation in_review → delivered_for_review. Coordinator retained receipts, corrected their navigation and recorded this checkpoint; final integrated identities and document checks are in the [verification receipt](artifacts/swarm-prep-2026-09-06/verification.json). HF-01/HF-02 remain ready but sprint authorization stays awaiting_review; all other cards remain queued. No task lease, game/build authorization or automation created. |
| EV-0007 | 2026-09-06T16:00:47+00:00 | Coordinator / authorization and question resolution | program, Q-E07 | Andrew explicitly authorized private repository publication with exact owner/name/branches; Q-E07 open → resolved, revision 1 → 2. [Authorization](artifacts/publication-2026-09-06/AUTHORIZATION.md). Foundation authorization unchanged. |
| EV-0008 | 2026-09-06T16:00:47+00:00 | Coordinator / definition import | PUB-01 | Added revision-1 atomic publication card; absent → queued, record revision 1. Source scope and explicit edit/admission boundaries are recorded in BACKLOG. |
| EV-0009 | 2026-09-06T16:00:47+00:00 | Coordinator / readiness | PUB-01 | queued → ready, record revision 1 → 2. Authenticated owner, absent destination, available sources and fast-forward ancestry verified; Q-E07 resolved. |
| EV-0010 | 2026-09-06T16:00:47+00:00 | Coordinator / assignment and lease | PUB-01 | ready → in_progress, record revision 2 → 3. Root coordinator owns PUB-01-A1 / PUB-01-L1 and its explicit file set; baseline captured before edits. No delegate writer or sprint task assigned. |
| EV-0011 | 2026-09-06T16:07:17+00:00 | Coordinator / checkpoint and scope reconciliation | PUB-01 | Record revision 3 → 4, state unchanged. Documentation/portability checks pass; content screen reports zero credential/contact matches. Separate user-authorized “Align Claude Code plugins” task is editing shared instructions outside this lease. Its package is not yet admitted for publication; Andrew was asked which snapshot to include. Root continues only scoped publication work and preserves all concurrent edits. |
| EV-0012 | 2026-09-06T16:17:08+00:00 | Coordinator / definition and admission-scope reconciliation | PUB-01 | Record revision 4 → 5; card revision 1 → 2, state unchanged. “Align Claude Code plugins” finished repository edits; its user-authorized repository-local package is pinned in [concurrent-package.json](artifacts/publication-2026-09-06/concurrent-package.json). Recommended inclusion used after optional question received no answer. No home config is uploaded and Claude live checks remain explicitly pending. Root edits/lease unchanged; admission includes the frozen package as delivered. |
| EV-0013 | 2026-09-06T16:20:00+00:00 | Coordinator / verified handoff | PUB-01 | in_progress → review, record revision 5 → 6. Frozen candidate and source package have portable links, unchanged protected content, clean whitespace/project checks and zero screened credential/contact matches. Staged file identities are in candidate-manifest.json; independent review requested. No commit or upload yet. |
| EV-0014 | 2026-09-06T16:24:31+00:00 | Coordinator / evidence correction and checkpoint | PUB-01 | review unchanged, record revision 6 → 7. EV-0013 used the working-tree whitespace result; the full staged check subsequently exposed six pre-existing warnings in approved sources. [whitespace-check.json](artifacts/publication-2026-09-06/whitespace-check.json) proves preservation; new publication deltas pass. Approved text and prompt bytes remain unchanged. Final review includes this explicit exception. |
| EV-0015 | 2026-09-06T16:27:50+00:00 | Coordinator / independent review admission | PUB-01 | review unchanged, record revision 7 → 8. Independent Astra PASS+NOTES accepted on frozen staged content and identified evidence overlay. No blocking finding; the original whitespace exception is supported. Coordinator admits the review and receipts serially, checks the integrated candidate, then commits and performs the authorized private publication. Remote completion remains pending. |
| EV-0016 | 2026-09-06T16:31:55+00:00 | Coordinator / integration, creation and recovery checkpoint | PUB-01 | review unchanged, record revision 8 → 9. Integrated `73c427203c9263affa747938e586325842357b0c`, rechecked project documentation, and fast-forwarded main. Created the exact private destination and verified owner/privacy/default main before upload. Initial push failed before authentication because the global helper referenced a removed gh executable; corrected this repository’s helper to the installed authenticated gh, leaving global/home configuration unchanged. Retried only the two authorized branches; final remote verification remains pending. |
| EV-0017 | 2026-09-06T16:36:20+00:00 | Coordinator / verified publication and closeout | PUB-01 | review unchanged, record revision 9 → 10. Independent PASS+NOTES and serial integration accepted; published `73c427203c9263affa747938e586325842357b0c` to exactly the two authorized branches. GitHub owner/private/default main, transport SHAs and all 1,213 remote file identities verified. Independent closeout review accepted the content; its completion-timing finding is resolved by retaining review state. Attempt PUB-01-A1 and coordinator lease remain active. Publication receipt and closeout checkpoint record observed results; commit/push them and verify final remote tips plus a clean tree before recording completion. No foundation task dispatched. |
| EV-0018 | 2026-09-06T16:40:13+00:00 | Coordinator / verified completion | PUB-01 | review → done, record revision 10 → 11. Closeout commit `6d7967856448c2f4d5e2f7b316e59b72c0bd4560` was pushed successfully to both authorized branches; owner/private/default main and all 1,217 remote modes/blobs match locally. Project check passed and working tree was clean before this transition. [closeout-verification.json](artifacts/publication-2026-09-06/closeout-verification.json) retains the observed proof. PUB-01-A1 accepted and PUB-01-L1 closed; no remaining publication blocker. Coordinator persists this terminal event and verifies its administrative commit is also backed up. |
| EV-0019 | 2026-09-06T18:05:00+00:00 | Coordinator / authorization and evidence retention | program | Andrew's read-only ai-firstify audit of the prepare stage completed (ten `scrapkeep-explorer` slices, one `scrapkeep-reviewer` PASS+NOTES) and was retained at [artifacts/ai-first-audit-2026-09-06/](artifacts/ai-first-audit-2026-09-06/AI-FIRST-AUDIT-2026-09-06.md). Andrew then instructed: proceed with all recommendations, orchestrate with low and medium effort Fable agents, and bring the project to 100% prepared for Sprint 0. Recorded as program authorization above. Engine install remains gated on Andrew's confirmation of the exact download (`Godot_v4.7.2-stable_linux.x86_64.zip`, 77.9 MB, official release, SHA512 verified); export templates and S0-09 stay parked. Coordinator fixed the events-table blank lines (EV-0010..0013) that the audit identified. |
| EV-0020 | 2026-09-06T18:05:00+00:00 | Coordinator / definition import (interim) | PS-01, PS-02, PS-03, PS-04 | Prepare-stage units defined from the accepted audit; their definitions are the named audit sections until PS-04 materializes them as BACKLOG cards (S0-01..S0-08 plus the HF amendments). PS-01 tooling: audit recommendations 3, 13, 17 and draft cards S0-02, S0-03. PS-02 documentation hygiene: recommendations 5 (section-scoped reads, Bible row, desk labels, Appendix A collapse) and 12 (stale names, dead references, absolute links, historical banners). PS-03 agent and skill configuration: recommendations 6, 7, 16 and the explorer/reviewer context trim. PS-04 board definitions: recommendations 2, 4, 8, 11 (ORCHESTRATOR and desk amendments only), the ORCHESTRATOR wave-review and integrated-checkpoint rules, and the S0-01..S0-08 import. All queued at record revision 1. |
| EV-0021 | 2026-09-06T18:05:00+00:00 | Coordinator / configuration for delegation | program | Added `.claude/agents/scrapkeep-writer-medium.md`, `scrapkeep-writer-low.md` and `scrapkeep-reviewer-medium.md` (claude-fable-5-1, effort per frontmatter) under Andrew's explicit instruction; the existing high/xhigh definitions are unchanged. AI-WORKFLOW and ORCHESTRATOR role text are updated by PS-03 and PS-04. |
| EV-0022 | 2026-09-06T18:05:00+00:00 | Coordinator / readiness, assignment and leases | PS-01, PS-02, PS-04 | queued → in_progress, record revision 1 → 2 each. Disjoint write sets: PS-01 owns `scripts/check-docs.mjs`, `scripts/check-scope.mjs`, `scripts/new-worktree.sh`, `tests/check-docs.test.js`, `tests/check-scope.test.js`, `package.json` (scripts block), `CONTRIBUTING.md`, `.gitignore`. PS-02 owns `BIBLE.md` (Appendix A only), `docs/**` except `docs/project/AI-WORKFLOW.md`, `README.md`, `tools/agent-player/README.md`, `artifacts/agent-player-2026-09-06/README.md`. PS-04 owns `BACKLOG.md`, `ORCHESTRATOR.md`, `docs/project/README.md`. Base identity is the commit carrying this event; leases PS-01-L1, PS-02-L1, PS-04-L1; attempts A1. PS-03 stays queued (its write set overlaps skills and AI-WORKFLOW, assigned after wave 1 admits). Writers run on `scrapkeep-writer-medium`; a `scrapkeep-reviewer-medium` reviews each wave's candidates together. |
| EV-0023 | 2026-09-06T18:00:43Z | Coordinator / coordination transfer, lease reconciliation and wave-1 assignment | program, PS-01, PS-02, PS-03, PS-04, PS-05, PS-06 | Coordinator transferred to Claude Code session `scrapkeep-1c` (claude-fable-5-1; configured xhigh, observed effort marker 25, actual effort unconfirmed). Reconciliation before dispatch: the EV-0022 leases had no worktree, branch, candidate or evidence on disk (`git worktree list` showed only `main`; no PS attempt files), no peer session was online, and the tree was clean at `67476f2`; the prior session is treated as stopped and leases PS-01-L1, PS-02-L1 and PS-04-L1 are carried forward under this coordinator rather than re-issued. Base identity for wave 1 is the commit carrying this event. Effort assignment revised per Andrew's importance and difficulty instruction: PS-01 (tooling levers that gate every later admission) and PS-04 (canonical board definitions) run on `scrapkeep-writer` (high); PS-02 on `scrapkeep-writer-medium`; PS-01 and PS-04 candidates get `scrapkeep-reviewer` (xhigh), PS-02 gets `scrapkeep-reviewer-medium`. PS-02 write set clarified: excludes `docs/project/README.md` (PS-04) and adds `.codex/environments/environment.toml`. PS-04 additionally owns the new `docs/project/SOURCE-DISPOSITIONS.md` for audit recommendation 11. Record revisions 2 → 3 for PS-01, PS-02, PS-04. New interim units imported at record revision 1: PS-05 safety and scope code (audit recommendations 9, 14, 15: `scripts/check-build.mjs`, the `tests/` default glob, a `server/` freeze note, `tools/agent-player/run.py`, `scripts/agent-playtest.mjs`, hash manifests replacing `artifacts/agent-recovery-2026-09-06/*/implementation/`), queued behind PS-01 for the `package.json` and `tests/` overlap; PS-06 native proofs (draft cards S0-01, S0-04, S0-05, S0-06, S0-07, S0-08: `native/**`, `scripts/native-smoke.mjs`, `docs/tech/native-toolchain.md`), blocked on gate G-01 and on PS-01. Gate G-01: Andrew's confirmation of the exact engine download, official `Godot_v4.7.2-stable_linux.x86_64.zip`, 77,860,424 bytes, SHA512 `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65` from the release `SHA512-SUMS.txt` (export templates, 1,281,349,702 bytes, stay parked with S0-09). Gate G-02: force-push and deletion protection on `main` (audit recommendation 16) is an external repository setting and waits for Andrew's explicit yes. Environment note: `git fetch` fails because the global credential helper references a removed `gh 2.98.0` path; pushes will use a repository-local helper pointing at the installed `gh 2.100.0`, recorded when first used. |
| EV-0024 | 2026-09-06T18:12:15Z | Coordinator / gates resolved, environment fix, checkpoint | program, PS-01, PS-02, PS-04 | Andrew answered the three gates: G-01 yes (download and install the pinned editor), effort substitution acknowledged (continue at high; PS-03 fixes the `.claude/settings.json` key so future sessions get xhigh; this session's environment reports `CLAUDE_EFFORT=high`), G-02 yes. Engine installed under `/home/andrew/.local/share/godot/4.7.2/` from the official 4.7.2-stable release, SHA512 verified against the release sums, version string `4.7.2.stable.official.ed1daf0bf`; a five-line headless SceneTree smoke ran. Export templates stay parked. G-02 could not be applied: the GitHub branch-protection API returns 403 on this private repository under the Free plan; a repository ruleset was attempted as the free-tier alternative (result recorded in the coordinator receipt). Program authorization row: native proofs now permitted on this machine. Environment fix: the harness cut every isolated writer worktree from a stale snapshot (`c5e61d3`, the previous `origin/main`), and isolated agents refuse git commands naming other worktrees; all three wave-1 writers stopped correctly on the base check with zero writes. Remedy: `main` was pushed to `origin` (`1cfc2ae`, using a repository-local credential helper pointing at the installed `gh 2.100.0`), and the three writer definitions under `.claude/agents/` lost their frontmatter `isolation: worktree` so writers run in coordinator-created worktrees at the recorded base (`scripts/new-worktree.sh` from PS-01 formalizes this). PS-02-A1 relaunched into `/home/andrew/Projects/scrapkeep-wt-PS-02` (branch `wt/PS-02`) and handed off candidate `e023315c04f146c7d9730a56f56864dd60c0c660` with PASS+NOTES; PS-02 in_progress → review, record revision 3 → 4; `scrapkeep-reviewer-medium` assigned. PS-01-A1 running in `scrapkeep-wt-PS-01` (`wt/PS-01`). PS-04-A1 relaunches into a fresh `scrapkeep-wt-PS-04` cut from the commit carrying this event; record revision 3 → 4. |
| EV-0025 | 2026-09-06T18:18:16Z | Coordinator / review admission, integration, handoff and assignment | PS-01, PS-02, PS-03 | PS-02: independent `scrapkeep-reviewer-medium` PASS+NOTES on candidate `e023315` (BIBLE.md body verified unchanged at forty sampled lines, Appendix B intact, prompt table links resolve, banners name the right owners); the one ruling, an absolute link remaining in the frozen copy `artifacts/agent-recovery-2026-09-06/extended-live/implementation/tools/agent-player/README.md:11`, is out of PS-02 scope because PS-05 replaces those copies with manifests. Serial integration: merged with a no-ff commit, integrated identity `d25d946c15ee4c15c6ae4a7ba2f1b59fbe856120`; `npm run check:project` passed on the integrated tree (85 files, 581 links); one `## 7. Art Direction` heading remains; receipts copied to `artifacts/prepare-stage-2026-09-06/tasks/PS-02/`. PS-02 review → done, record revision 4 → 5, lease PS-02-L1 closed. Follow-ups for later units: `COHESION_REPORT.md:94` is now historical; `docs/DESIGN-INDEX.md:67` should say "a separately authorized task". PS-01: worker handed off candidate `cc02fb48adcb4bd400ee303c34583e0c2af5d464` (three commits on `wt/PS-01`, base `1cfc2ae`) with PASS+NOTES at evidence level 4; coordinator built an integration preview over `d25d946` (clean merge, 19 paths) and ran `npm run check:docs` (15 failures, all pre-existing and outside PS-01: four in the frozen artifact copy and eleven self-anchors in `docs/bible/production/FRONT-MATTER.md`, a fragment assembled into BIBLE.md), `npm test` and `npm run verify` after a locked install; results in the coordinator receipts handed to the reviewer. PS-01 in_progress → review, record revision 3 → 4; `scrapkeep-reviewer` (xhigh) assigned. PS-03 (agent and skill configuration, audit recommendations 6, 7, 16 and the explorer/reviewer context trim, plus the `.claude/settings.json` effort key fix Andrew chose) queued → in_progress, record revision 1 → 2, lease PS-03-L1, attempt A1, `scrapkeep-writer-medium`, base the commit carrying this event, worktree `/home/andrew/Projects/scrapkeep-wt-PS-03`; write set `.claude/agents/**`, `.agents/skills/**`, `.claude/settings.json`, `docs/project/AI-WORKFLOW.md`. PS-05 gains the FRONT-MATTER anchor fix so `check:docs` turns green once PS-01 and PS-05 are admitted. |

## Preparation checkpoint

Preparation is complete and handed to Andrew for review. The [independent candidate review](artifacts/swarm-prep-2026-09-06/REVIEW.md) passed; its report names exact reviewed identities. The coordinator subsequently retained the evidence links and recorded these final board events. The [final verification receipt](artifacts/swarm-prep-2026-09-06/verification.json) identifies the integrated files and checks on that result.

The backlog contains 58 bounded task cards, 50 defined questions and 458 source dispositions, including all 122 historical P/T/R/D/BD identifiers. All task/question references and dependency inputs resolve, the graph is acyclic, and the ten-card foundation sprint has no unanswered external documentation prerequisites. Six ownership/review/recovery scenarios were exercised as document rules.

Game sources, dependency files and runtime media remain unchanged against the preparation baseline. Only documentation, source-status navigation and preparation evidence changed. No engine installation, runtime verification/build, asset generation, external publication or sprint execution occurred. No future task is credited as done.

**Next-session entry point:** Read [README](README.md), the [accepted audit](artifacts/ai-first-audit-2026-09-06/AI-FIRST-AUDIT-2026-09-06.md) and the PS attempt records above. The prepare-stage program is in progress under EV-0019..0022; the HF sprint starts only after PS-04's amended cards are admitted and Andrew's go. No automation or background run was created.

## Prepare-stage attempt records

### PS-01-A1, PS-02-A1, PS-04-A1

- Assignees: PS-01 and PS-04 on `scrapkeep-writer` (claude-fable-5-1, effort high per definition); PS-02 on `scrapkeep-writer-medium` (effort medium). Actual model and effort as reported at handoff. Leases PS-01-L1, PS-02-L1, PS-04-L1 with the write sets in EV-0022 as amended by EV-0023. Base identity: the commit carrying EV-0023 (recorded in each handoff). Candidate identities: null until handoff. Reviewers: `scrapkeep-reviewer` (xhigh) for PS-01 and PS-04, `scrapkeep-reviewer-medium` for PS-02, each on the exact candidate commit. Coordinator: session `scrapkeep-1c`. Evidence: `artifacts/local/tasks/PS-0x/` in each worktree, summarized in the handoff and copied to `artifacts/prepare-stage-2026-09-06/tasks/PS-0x/` on admission.
