# Specification amendment request AM-H8-007

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-007: HF-04a's callback families name no family for an engine device connection delivery, and F-CONTROL lets InputAdapter only clear state, while TH-18 needs InputAdapter to update its own records for a connection change and to record a focus observation. |
| Request revision and date | Revision 1, 2026-09-16 (UTC). |
| Requester and owner | Requested as a shared-file change in TH-18's handoff (attempt TH-18-A2, EV-0407) and widened by TH-18-A3 after integrated read finding B2 (artifacts/handoff-8-2026-09-16/closure/integrated-read-R1.md); recorded by the Handoff-8 coordinator (claude-opus-5). |
| Program and authorization | Handoff-8-2026-09-16, TRACKING EV-0367; TH-18 admitted with the gates at EV-0460. |
| Source identity | Main at 8d06eac (TH-18 attempt 3 admitted at 2f3b2a876374b41eec4a997527e5a482105b3dc4). |
| Request state | `deferred` (revision 1) |
| Decision owner | Andrew: a change to accepted runtime architecture (ORCHESTRATOR Specification contradictions). |
| Admission state | Not admitted. Propagation would be card FR-10 after Andrew's decision. |
| Affected work | HF-04a (done; callback family table lines 46, 47 and 51); native InputAdapter implementation (not yet carded). TH-18 is complete with both uses gated: DL-08 (line 102) gates dependent implementation of connection delivery, and II-02 (line 136) with the Interfaces preamble (line 131), the HF-04a seam (line 285), FT.3 and FT.11 gate focus-observation recording under F-CONTROL. |
| Safe continuation | TH-18 stays done with the gates; no implementation of device connection handling or focus-observation recording starts before a decision and FR-10's admission. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | docs/tech/sections/HF-04a-runtime-lifecycle.md line 46 (F-INPUT) | InputAdapter updates physical and input-context records; the listed callbacks are input events and UI signals. | No engine connection-change delivery is listed. |
| B | HF-04a line 51 (F-OTHER) | Any other engine callback has no gameplay-time permission and needs an existing owner, interface and explicit classification before implementation. | A connection delivery falls here today. |
| C | HF-04a line 47 (F-CONTROL) | InputAdapter clears state. | Recording a focus observation is not clearing. |
| D | docs/tech/sections/TH-18-input-integration.md DL-08 (line 102) and II-02 (line 136) | InputAdapter updates its own records for a connection change (the same allowed work as F-INPUT) and records a focus observation under F-CONTROL. | Needs A to C revised; gated in TH-18 until then. |

Observation: integrated read R1 (gpt-6-astra high, read-only) found TH-18 attempt 2 treating the union of F-INPUT and F-CONTROL as a permission (B2, blocking); TH-18 attempt 3 gated it and review R3 confirmed the gate (artifacts/handoff-8-2026-09-16/tasks/TH-18/review-R3.md).

## Classification and proposed change

Architecture amendment to an admitted foundation section. Proposed: name the engine's device connection-change delivery in one callback family whose allowed work is exactly InputAdapter's own-record updates; let F-CONTROL's InputAdapter work include recording a focus observation in its own records beside clearing. Alternatives: (1) keep connection changes under F-OTHER with a per-implementation classification, which HF-04a line 51 already allows but leaves each implementation to classify; (2) sample connection state during F-INPUT only, dropping the delivery callback; (3) record focus observations under F-INPUT rather than F-CONTROL. Compatibility: no save field, transition, command or gameplay rule changes; no other owner's allowed work changes.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Deferred, 2026-09-16: needs Andrew's architecture decision; not needed for any Handoff-8 output, which carries the gates. |
| Accepted scope | none yet |
| Implementation defect | not applicable |
| Rejected request | not applicable |
| Deferred request | Deferred to Andrew's decision at or after the Handoff-8 closure report; blocks native input implementation only. |
| Prior decision | none |
| Board event | The Handoff-8 grooming event that registers this request. |
