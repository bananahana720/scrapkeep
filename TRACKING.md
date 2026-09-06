# Scrapkeep execution board

Schema 1. Coordinator-owned in-repo board. Prepared 6 September 2026.

Use this file as the only execution-state authority. [BACKLOG.md](BACKLOG.md) defines tasks, dependencies and questions; [ORCHESTRATOR.md](ORCHESTRATOR.md) defines operating rules. The [Bible](BIBLE.md) and [engineering ADRs](adr/README.md) remain product and architecture authority. No external board, issue tracker or duplicate live queue is configured.

## Program authorization

| Field | Value |
| --- | --- |
| Preparation | Authorized by Andrew's explicit instruction to implement the three-document plan. |
| Proposed sprint | HF-01 through HF-10, foundation engineering contracts only. |
| Sprint authorization | **awaiting_review**. No worker may start a sprint task. |
| Native game/build authorization | **none**. No engine install, code/asset production or qualification run is authorized by this delivery. |
| Active coordinator for sprint execution | none |
| Active task attempts / write leases | PUB-01-A1 / PUB-01-L1 retained for coordinator closeout only; no sprint lease. |
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

- Assignee: publication root coordinator (`gpt-6-astra`); card revision 2; attempt PUB-01-A1; lease PUB-01-L1 retained through closeout verification.
- Owned files: the explicit PUB-01 publication edit set. Pre-existing planning files are admitted from the publication baseline, with the completed repository-local workflow package admitted unchanged from [its frozen manifest](artifacts/publication-2026-09-06/concurrent-package.json).
- Base identity: `dc72a02cd7a0fbe1f00b3ce71d36448364f93294` plus that publication baseline manifest.
- Candidate identity: [publication candidate manifest](artifacts/publication-2026-09-06/candidate-manifest.json). Integrated identity: `73c427203c9263affa747938e586325842357b0c`; reviewed candidate plus coordinator evidence metadata committed serially.
- Latest checkpoint: 2026-09-06T16:36:20+00:00; owner/privacy/default and both branch SHAs verified after successful push. Initial remote tree matches all local modes/blobs. [Closeout](artifacts/publication-2026-09-06/CLOSEOUT.md) records evidence and the next-session entry point; final receipt commit is verified again after upload.
- Evidence: [authorization](artifacts/publication-2026-09-06/AUTHORIZATION.md), [document checks](artifacts/publication-2026-09-06/document-checks.json), [content screen](artifacts/publication-2026-09-06/content-screen.json), [independent review](artifacts/publication-2026-09-06/REVIEW.md); [verified remote publication](artifacts/publication-2026-09-06/publication.json).
- Review: private_publication_review (independent Astra), **PASS+NOTES** on the pinned candidate and evidence overlay; [report](artifacts/publication-2026-09-06/REVIEW.md). Six original whitespace warnings accepted with preservation proof. No sprint worker has been assigned.


## Task state index

Blockers marked dependency refer to the pinned card's exact dependency list in BACKLOG. They are not new task definitions. At initialization all future dependencies are unfinished. Program authorization remains an additional dispatch gate for every row.

| Task ID | Card rev | Record rev | State | Blockers / admission | Accepted attempt | Last event |
| --- | --- | --- | --- | --- | --- | --- |
| [PUB-01](BACKLOG.md#pub-01) | 2 | 10 | review | Closeout commit/push and final tip/clean-tree checks | none | EV-0017 |
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

## Preparation checkpoint

Preparation is complete and handed to Andrew for review. The [independent candidate review](artifacts/swarm-prep-2026-09-06/REVIEW.md) passed; its report names exact reviewed identities. The coordinator subsequently retained the evidence links and recorded these final board events. The [final verification receipt](artifacts/swarm-prep-2026-09-06/verification.json) identifies the integrated files and checks on that result.

The backlog contains 58 bounded task cards, 50 defined questions and 458 source dispositions, including all 122 historical P/T/R/D/BD identifiers. All task/question references and dependency inputs resolve, the graph is acyclic, and the ten-card foundation sprint has no unanswered external documentation prerequisites. Six ownership/review/recovery scenarios were exercised as document rules.

Game sources, dependency files and runtime media remain unchanged against the preparation baseline. Only documentation, source-status navigation and preparation evidence changed. No engine installation, runtime verification/build, asset generation, external publication or sprint execution occurred. No future task is credited as done.

**Next-session entry point:** Read [README](README.md) and [the publication closeout](artifacts/publication-2026-09-06/CLOSEOUT.md), then review HF-01–HF-10 with Andrew. The private backup is established; the foundation sprint still requires his explicit go/no-go. No automation or background run was created.
