# Specification amendment request AM-H8-003

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-003: HF-06a routes class-kit slot actions to F-02 attacks while TH-04 and N-021 support ability definitions that may commit attacks. |
| Request revision and date | Revision 1, 2026-09-16 (UTC). |
| Requester and owner | Raised as B1 of independent review R1 of SC-02 (scrapkeep-reviewer-medium, claude-opus-5 high) on candidate 07bef9da9bf72b1831307811bba177646d004f3c (attempt SC-02-A1, scrapkeep-writer, claude-opus-5 high). Received by the Handoff-8 coordinator (claude-opus-5). |
| Program and authorization | Handoff-8-2026-09-16, TRACKING EV-0367; FR-07 added at EV-0392. |
| Source identity | Main at 6d01b34df4c79a70e2a725a892560fa09721b9cd when classified. |
| Request state | `accepted` (revision 1) |
| Decision owner | Andrew (architecture choice, per the read-only advisory classification). |
| Admission state | Pending: applied by FR-07 with AM-H8-001 and AM-H8-002. |
| Affected work | HF-06a rows F-01, N-007 to N-011, N-013, N-016 and N-019 (Markdown and CSV); HF-06b N-009 clarification; SC-01 kit fields reference `ability`; SC-02 attempt 2 (FR-11 correction); SC-06 Seam 3 re-verification; TH-20. No HF-07a field change. |
| Safe continuation | SC-05, SC-06 review and SC-08 continue. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | HF-06a lines 36, 66, 80 to 84, 92 | F-01 references kit actions "(F-02) by ID and expected family"; N-007 to N-011 repeat it; N-019 "Per-character mobility actions are F-02 definitions". | Admitted reference family. |
| B | HF-06a line 94; TH-04 lines 39 to 42 (AS-01 to AS-04), 114 (EL-04), 150 (AI-25), 313 (Seam 1) | N-021 ability and ultimate definitions; TH-04 separates slot behaviour, cooldown and charge from attack geometry and makes an activation that attacks obey TH-03. | Supports ability definitions that may commit attacks, without replacing A's expected family. |
| C | SC-02 candidate lines 269 to 277, 365, 373, 508 | Kit slots reference AbilityDefinition, which may commit none (mobility). | Card-level resolution of A against B; blocked. |

## Classification and proposed change

Architecture choice (advisory-result.md in this directory, gpt-6-astra high). Proposed and chosen: a character's weapon, main hero skill, mobility and ultimate kit actions reference N-021 ability definitions by ID and expected family `ability`; an ability references F-02 attack definitions for any attacks it produces; a mobility action may produce no attack; every produced attack remains subject to TH-03. Alternative rejected: every kit action is an attack, with a non-harming attack case for pure movement.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Accepted, 2026-09-16. Andrew chose 'Abilities that may attack' by structured answer after the gpt-6-astra high advisory classified the question as an architecture choice and recommended it. |
| Accepted scope | FR-07 applies the chosen wording to HF-06a F-01, N-007 to N-011, N-013 (slot-action versus attack visual reference), N-016 (replacing a mobility action versus an attack) and N-019 in Markdown and CSV, clarifies HF-06b N-009 so planted-limb attacks stay F-02 within an ability, and re-points citing hashes; no HF-07a change. |
| Implementation defect | not applicable |
| Rejected request | not applicable |
| Deferred request | not applicable |
| Prior decision | none |
| Board event | The Andrew decision event recording this acceptance. |
