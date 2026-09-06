# Specification amendment request

Use this packet when a source clause conflicts with observed behavior or another required clause. The [contradiction rule](../../../ORCHESTRATOR.md#specification-contradictions) owns authority and transitions. [Sprint closure](../../../ORCHESTRATOR.md#sprint-closure) owns final reconciliation. The [synthetic examples](amendment-examples.md) illustrate the four dispositions.

A worker stops affected work and sends a completed packet to the coordinator. Unaffected leased work may continue. Only the coordinator records the request in [TRACKING](../../../TRACKING.md#event-schema-and-write-discipline) and admits shared-document changes. This template grants no write lease or implementation authority.

## Request identity and context

Replace every placeholder. Use `none` with a reason where a field does not apply. Keep pending evidence explicit.

| Field | Required entry |
| --- | --- |
| Request ID and title | Coordinator-assigned stable ID and one concrete contradiction. Repeated submissions retain the ID. |
| Request revision and date | Revision number and UTC timestamp. Retain prior revisions and decision history. |
| Requester and owner | Worker, task attempt, lease, actual model and effort, and coordinator receiving the request. |
| Program and authorization | Sprint ID and the exact authorized scope record. |
| Source identity | Accepted base commit, worktree path, branch, candidate commit or content-hash manifest, and observed dirty files. |
| Request state | `proposed`, `accepted`, `rejected`, or `deferred`. Initially `proposed`. |
| Decision owner | Coordinator for implementation triage or evidence-backed factual correction preserving accepted direction. Andrew for accepted architecture or product changes. |
| Admission state | Separate from request state. Pending, admitted with receipt, or not applicable with reason. Acceptance alone is pending admission. |
| Affected work | Each card ID, current revision, attempt, lease, blocked action, and dependent card. Include completed work requiring explicit reopening. |
| Safe continuation | Exact unaffected leased work that may continue, or `none`. Record stopped worker status and retained lease ownership. |

## Conflicting clauses and observation

Cite each source by path, heading or line, and source commit. Quote the relevant clause or provide an exact proposed diff. Separate accepted sources from a candidate, historical text, or a hypothetical fixture.

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | `<path, heading or line, commit>` | `<clause>` | `<accepted requirement>` |
| B | `<path, heading or line, commit or fixture hash>` | `<clause or candidate behavior>` | `<why both cannot hold>` |

Record the observation with a command or review method, expected result, actual result, evidence path, and checked commit or fixture hash. State reproducibility conditions and limits. A synthetic fixture proves its scenario only. Source review cannot establish runtime behavior, physical support, performance, or human enjoyment.

## Classification and proposed change

State whether the evidence indicates an implementation defect, a factual documentation error, an accepted architecture or product change, or an unresolved contradiction. The coordinator records the classification and reason.

Describe the smallest proposed resolution. Name every source clause to replace and provide its replacement text. Name every affected card and its proposed revision, acceptance change, dependency change, and verification change. Keep proposed shared-file edits in this packet until the coordinator admits them.

Compare the proposal with leaving the contract unchanged and at least one other plausible alternative. Give the reason for choosing or rejecting each. For an implementation defect, describe the repair to the candidate and why the accepted source requires no amendment.

Record compatibility consequences for accepted product and architecture decisions, current browser proofs, native proof contracts, content and save data, dependent work, and preserved evidence. Mark each unaffected area with a reason. Name migration, rollback, or re-verification needs where applicable. A decision does not enlarge a lease or authorize a new sprint.

## Decision record

The coordinator records the authorized owner's decision and links its evidence. A proposed response is not the owner's answer.

| Field | Required entry |
| --- | --- |
| Decision | State, UTC timestamp, decision owner, exact ruling, rationale, and evidence reference. |
| Accepted scope | Exact request revision and source/card changes accepted, including conditions and exclusions. Otherwise `none`. |
| Implementation defect | Return the affected attempt through `changes_requested`; retain the unchanged source contract and request disposition. |
| Rejected request | Explain why the contract remains unchanged. Record readiness checks before affected work resumes. |
| Deferred request | Name the missing evidence or owner answer, resolution condition, and blocked cards. Deferral does not permit a workaround. |
| Prior decision | Previous request revision or decision event, or `none`. Corrections append history. |
| Board event | TRACKING event ID and the affected task record revisions. |

## Admission and propagation receipt

Complete this section separately after acceptance. Until all required changes are admitted, dependent work remains blocked. Blocking amendments can be admitted during the sprint.

| Required proof | Receipt |
| --- | --- |
| Accepted decision identity | Request ID/revision and decision event. |
| Authoritative sources | Every changed source path and clause, previous identity, accepted replacement, and admitted commit. Update the relevant ADR for a durable decision change. |
| Card propagation | Every affected card, old and new revision, revised inputs/acceptance/dependencies/verification, and admitted commit. Source and card revisions enter together. |
| Independent review | Reviewer identity, actual model/effort, exact reviewed candidate, verdict, findings and disposition, evidence path. Review the changed acceptance contract and affected implementation. |
| Required checks | Each command or method, source commit, result, evidence path, and limitations. Rerun checks affected by changed implementation. |
| Integration | Coordinator, candidate commit, integrated commit, scope check, and integrated verification receipts. A candidate in another worktree is not admission. |
| Readiness and leases | Each affected card's readiness result, dependencies and other amendments checked, task/lease actions, and TRACKING event. An admitted amendment alone does not authorize dispatch. |
| Remaining propagation | Every missing source, card, review, or check. `none` only when all required propagation is complete. |

For a rejected implementation-defect request, source/card propagation may be not applicable because the contract is unchanged. Candidate repair still needs its normal review, integration, and readiness evidence. For a deferred request, admission remains pending and affected work stays blocked.

## Closure disposition

Record the request ID, decision, admission receipt or remaining blocker, and affected task states in the sprint closure receipt. Accepted but unapplied amendments and deferred applicable contradictions prevent `passed`. Missing evidence remains `pending_evidence`; an observed failed gate is `failed`. A next-sprint proposal does not clear either result.

Record the pinned final integrated commit after reconciliation. Reuse the same request ID on repeated closure attempts. If the source commit changes, collect the required evidence again and link the prior closure receipt.
