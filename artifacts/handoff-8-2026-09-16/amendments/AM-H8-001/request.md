# Specification amendment request AM-H8-001

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-001: HF-06a types no slot definition, while HF-07a gives each slot its own domain ID and SC-01 must map every type to a row. |
| Request revision and date | Revision 1, 2026-09-16 (UTC); board event recorded with this request. |
| Requester and owner | Raised by independent review R1 of SC-01 (scrapkeep-reviewer-medium, claude-opus-5 high) on candidate 46c5c199ad1bb00d0d7f117e5316aa47ecf43df8 from attempt SC-01-A1 (lease SC-01-L1, scrapkeep-writer, claude-opus-5 high, CLAUDE_EFFORT=high), whose writer disclosed the gap as its Seam 1. Received by the Handoff-8 coordinator (claude-opus-5). |
| Program and authorization | Handoff-8-2026-09-16, TRACKING EV-0367 (PD-03, TH-18, TH-19, SC-01 to SC-06, SC-08; documentation-only). No repair card for HF-06a is in that scope. |
| Source identity | Base bb97c4111d1e7b2dd40cae575eccde17878b07c5; worktree /home/andrew/Projects/scrapkeep-wt-SC-01 on wt/SC-01, clean; candidate 46c5c19; review report artifacts/handoff-8-2026-09-16/tasks/SC-01/review-R1.md. |
| Request state | `proposed` |
| Decision owner | Coordinator for classification; Andrew for adding a repair card to the authorized scope. |
| Admission state | Pending. |
| Affected work | SC-01 revision 1 (attempt SC-01-A1, lease released, blocked). TH-20 (reconciles the catalogue) and TH-21 depend on SC-01. Admitted sections citing HF-06a, HF-06b or HF-07a would take stated-hash re-points only. |
| Safe continuation | SC-02, SC-03, SC-04, TH-18-A2 and TH-19 review continue; none types slots. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | docs/tech/sections/HF-06a-schema-inventory.md lines 22, 46, 97 and 193 at bb97c41 | Line 22 uses F-03 and N-024 as its example of two rows for one type; N-024's rationale reads "Slot-tree definitions (F-03)"; a row that does not fit "returns here for re-verification rather than being re-treated inside the consuming card"; line 193 re-opens the matrix when an SC card cannot fit a row. | Admitted matrix: no row types a slot definition. |
| B | docs/tech/sections/HF-07a-save-envelope.md line 127 at bb97c41 | `run.checkpoint.build.slots[].slot_id` is "The slot's domain ID. The slot definition and its milestone rule stay in the catalogue", sourced to HF-06b row F-03. | Admitted save contract: a slot definition exists in the catalogue as its own identity. |
| C | Candidate SC-01.md lines 95, 432 and 442 | Allocates N-024 to a new type T3 (slot definition) and splits the save fields between F-03 and N-024. | Re-treats an admitted row inside the consuming card (forbidden by A, line 46). |

## Classification and proposed change

Specification defect (an omission in the admitted matrix), not an implementation defect: SC-01 cannot satisfy "each row maps to exactly one type, no orphan type" for a slot definition that B requires and A never rows. Proposed: a scoped foundation-repair card re-verifies HF-06a under line 193, either adding a row that types the slot definition (with its HF-06b projection cell and HF-07a source cell) or rewording N-024 so it covers the slot definition, then re-points stated hashes in citing sections by the drift fixpoint; SC-01 attempt 2 then cites the revised rows. Alternative considered: SC-01 assigns N-024 to T4 beside F-03 and leaves T3 without a row, which fails SC-01's own no-orphan requirement. Compatibility: no field, transition or save shape changes; only matrix rows, their cells and stated hashes.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Pending: Andrew's scope decision on adding the repair card. |
| Accepted scope | none yet |
| Implementation defect | not applicable |
| Rejected request | not applicable |
| Deferred request | not applicable |
| Prior decision | none |
| Board event | Recorded with the SC-01 review event in TRACKING. |
