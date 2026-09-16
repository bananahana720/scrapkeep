# Specification amendment request AM-H8-002

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-002: HF-06b line 114 says N-028's projection names the level and encounter by ID, while TH-11 line 45 and HF-07a's closed field list store no level or encounter ID. |
| Request revision and date | Revision 1, 2026-09-16 (UTC). |
| Requester and owner | Raised as note 1 of independent review R1 of SC-04 (scrapkeep-reviewer-medium, claude-opus-5 high) on candidate b1427907f28ef7c353bf8cfe564f12dd97874791; the SC-04 writer disclosed it as a seam for TH-20. Received by the Handoff-8 coordinator (claude-opus-5). |
| Program and authorization | Handoff-8-2026-09-16, TRACKING EV-0367, with FR-07 added under AM-H8-001 at EV-0392. |
| Source identity | Main at the recording commit; HF-06b line 114, TH-11 line 45 and HF-07a line 70 unchanged since bb97c41. |
| Request state | `accepted` (revision 1) |
| Decision owner | Coordinator: factual correction supported by observed evidence that preserves TH-11's accepted contract. |
| Admission state | Pending: applied by FR-07 with AM-H8-001. |
| Affected work | HF-06b (row F-04 rationale wording); SC-04 A2 cites this request at its seam; TH-20 no longer inherits it. No field, transition or save shape changes. |
| Safe continuation | All leased Handoff-8 work continues. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | docs/tech/sections/HF-06b-persistence-projection.md line 114 | "A completed level is recorded as an accepted route decision and a next entrance in N-028's projection, naming the level and encounter by ID" | Foundation matrix wording, admitted before TH-11. |
| B | docs/tech/sections/TH-11-runs-regions-exits-and-saves.md line 45 | "A level has no durable domain identity, and that is the contract rather than a gap ... it stores no level ID" | Later admitted run contract, repeated by HF-07a's closed seventy-field list (line 70). |

## Classification and proposed change

Factual documentation error in HF-06b preserving accepted decisions: TH-11 fixed that no level identity is stored and HF-07a carries no such field, so HF-06b's clause is stale. Proposed: FR-07 rewords the clause to name the route decision and next entrance only, citing TH-11 line 45, and re-points stated hashes by the drift fixpoint.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Accepted by the coordinator, 2026-09-16, as a factual correction preserving TH-11 and HF-07a; folded into FR-07's definition alongside AM-H8-001 and reported to Andrew. |
| Accepted scope | One clause of HF-06b line 114 and its citing hashes; nothing else. |
| Implementation defect | not applicable |
| Rejected request | not applicable |
| Deferred request | not applicable |
| Prior decision | none |
| Board event | Recorded with the SC-04 review event in TRACKING. |
