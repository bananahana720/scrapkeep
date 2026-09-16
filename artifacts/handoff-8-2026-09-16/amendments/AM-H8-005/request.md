# Specification amendment request AM-H8-005

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-005: admitted SC-03's replacement fields target only F-02 while FR-07's revised HF-06a N-016 and N-019 send replacing a mobility action to an N-021 ability reference. |
| Request revision and date | Revision 1, 2026-09-16 (UTC). |
| Requester and owner | Raised as note 1 of independent review R1 of FR-07 (scrapkeep-reviewer-medium, claude-opus-5 high) on candidate ed928434f026d06c85a44d21ed730183200cd697; received by the Handoff-8 coordinator (claude-opus-5). |
| Program and authorization | Handoff-8-2026-09-16, TRACKING EV-0367; propagation of AM-H8-003 (Andrew's decision, EV-0411) applied by FR-07. |
| Source identity | Main at 93989a43aa93f3c3c8d964646141f95df297ce21 (FR-07 admitted). |
| Request state | `accepted` (revision 1) |
| Decision owner | Coordinator: implementation propagation of an accepted amendment into an admitted contract; no architecture or product choice beyond AM-H8-003. |
| Admission state | Pending: SC-03 reopened as attempt SC-03-A2 at card revision 1. |
| Affected work | SC-03 (done at EV-0402, reopened); SC-02 attempt 2 and TH-20 read SC-03's replacement fields. |
| Safe continuation | SC-01 and SC-02 second attempts proceed; SC-02 states the SC-03 seam without its revised bytes. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | docs/tech/sections/HF-06a-schema-inventory.md N-016 (line 89) and N-019 (line 92) at 93989a4 | Replacing a mobility action is an effect reference to an N-021 ability definition; replacing an attack is an effect reference to an F-02 attack definition; per-character mobility actions are kit actions referencing N-021 abilities. | Admitted matrix after FR-07. |
| B | docs/tech/schemas/SC-03.md lines 58, 85, 86, 384 at 93989a4 | Mobility actions are F-02 definitions; `replacements[].replaces_action_id` and `provides_action_id` reference F-02; replaced and replacing actions are F-02 references. | Admitted SC-03 contradicts A. |
| C | docs/tech/sections/HF-05-content-admission.md lines 22 and 108 | Each reference names one expected family. | A single replacement field cannot carry both families. |

Observation: the coordinator's in-merge alignment of B at 0102758 (one field naming "F-02 when an attack; N-021 when a mobility action") failed SC-03's retained paper check C07 (a reference target must be one type or one foreign row) and FR-07's hash-only assertion, and was reverted at 93989a4; receipts artifacts/handoff-8-2026-09-16/tasks/FR-07/integrated/ (failures) and integrated-rerun/ (passes after revert).

## Classification and proposed change

Specification propagation defect in an admitted schema contract. Proposed: SC-03 attempt 2 models attack replacement and mobility-action replacement so each reference has exactly one expected family (for example separate attack and ability replacement fields or records with an exactly-one rule), adds N-021 to its foreign-reference table, corrects lines 58 and 384, keeps save treatment unchanged, and passes its paper check with a control for the old single-family field.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Accepted by the coordinator, 2026-09-16, as propagation of AM-H8-003; SC-03 reopened. |
| Accepted scope | SC-03.md replacement fields and the four contradicting sentences, one expected family per reference, no save, row or treatment change. |
| Implementation defect | not applicable |
| Rejected request | not applicable |
| Deferred request | not applicable |
| Prior decision | AM-H8-003 (EV-0411) |
| Board event | The FR-07 completion and SC-03 reopen events. |
