# Specification amendment request AM-H8-004: SC-05 events and secrets have no HF-06a row

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-004: SC-05 card item 1 requires event and secret definitions, but no SC-05 row in HF-06a types either, and the only matrix sentence naming an SC-05 event sits in SC-01's row N-024. |
| Request revision and date | Revision 1, 2026-09-16T19:40:00Z. |
| Requester and owner | Writer scrapkeep-writer (claude-opus-5 by agent definition; runtime `CLAUDE_EFFORT=high`), task SC-05, attempt SC-05-A1, lease SC-05-L1. Coordinator of Handoff-8-2026-09-16 receives it. |
| Program and authorization | Sprint Handoff-8-2026-09-16, authorized by Andrew at TRACKING EV-0367. The SC-05 assignment is at TRACKING EV-0391. |
| Source identity | Base `56e579a078e80e8cd4ba4298553b8b8942357109`; worktree `/home/andrew/Projects/scrapkeep-wt-SC-05`; branch `wt/SC-05`; candidate commit named in the SC-05-A1 handoff; no other dirty tracked file. |
| Request state | `accepted` (revision 1, option 1) |
| Decision owner | Coordinator for the matrix-omission classification and propagation. Andrew only if the resolution changes card scope in a way EV-0367 does not cover. Q-P38 (event and secret-room type selection) and Q-P18 (respec opportunity rules) stay Andrew's product questions whatever is decided here. |
| Admission state | Pending. |
| Affected work | SC-05 revision 1, attempt A1, lease SC-05-L1: card item 1's events and secrets only. SC-04 revision 1 (concurrent; F-04 objective definitions). SC-01 revision 1 (row N-024's wording; already blocked on AM-H8-001). TH-20 (reconciliation). TH-07's Seam 5 wording, if the event owner moves. |
| Safe continuation | SC-05-A1 continues for the five types that have rows: region (area), level module, route, exit and generation constraint. They are delivered in `docs/tech/schemas/SC-05.md`, where events and secrets are withheld and no field reserves a place for them. The writer stops after the handoff. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | `BACKLOG.md` § SC-05, card revision 1, source bullet and definition of done item 1, at base 56e579a | "BIBLE.md § 3. Maps & Areas (regions, areas, level modules, routes, generation constraints, events and secrets)"; "Cover only regions, areas, level modules, routes, generation constraints, events and secrets; identify its HF-06 matrix rows" | The card requires SC-05 to define event and secret types. |
| B | `docs/tech/sections/HF-06a-schema-inventory.md` line 144 (rows by producing card) and line 70 (row F-05), SHA256 fd0bd9b3…5fa7 | SC-05's rows are "F-05, N-001, N-002, N-003, N-004, N-005, N-006, N-028, N-036". F-05: "Region, level-module, route, exit and generation-constraint definitions that bound seeded assembly". N-028: "World (run-region) and exit definitions". | No SC-05 row's rationale describes an event or secret definition. |
| C | HF-06a line 97 (row N-024, treatment schema, producing card SC-01); HF-06b line 142 (row N-024), SHA256 83f6e4ba…4014; TH-07 line 364 (Seam 5), SHA256 e55d14ee…501ced | N-024: "Slot-tree definitions (F-03) … a respec opportunity is an SC-05 event definition (TH-07)". HF-06b N-024: "A respec through an SC-05 event replaces the selection". TH-07 Seam 5 repeats it. | The admitted corpus expects an SC-05 event definition but types it in SC-01's slot-tree row. Allocating an SC-05 type to N-024 would borrow a row whose rationale describes slot trees. |
| D | HF-06a line 69 (row F-04, producing card SC-04); `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` line 119 (UN-05), SHA256 0dbf71dd…b935 | F-04: "Encounter, wave, boss and objective definitions". UN-05: "Event, secret-room, branch and defense objective types … The level's objective definitions … Q-P38". | The admitted encounter contract places event and secret-room types in objective definitions, which HF-06a gives to SC-04. |
| E | HF-06a line 46; SC-05 assignment packet (EV-0388 lesson, AM-H8-001) | "if that confirmation fails, the row returns here for re-verification rather than being re-treated inside the consuming card"; packet: "allocate each type to the HF-06a row whose rationale actually describes it … If a type you need has no HF-06a row, stop that part and submit an amendment request". | Clauses A to D cannot all hold without a matrix change. |

Observation method: source review at base 56e579a. The HF-06a CSV was filtered for `producing_card == SC-05`. Every rationale of those nine rows was searched, case-insensitively, for "event", "secret", "room" and "objective", and none of the four terms occurs. The same search over all sixty-seven rationales found "event" only in N-024 (as "SC-05 event definition"). It found "secret" only in F-08, N-017, N-026 and N-059, all fixed-secret recipe and discovery rows owned by SC-03 and SC-08. It found "objective" only in F-04 and "room" nowhere. Receipt: `artifacts/local/tasks/SC-05/amendment-term-search.txt`. The executable paper check `artifacts/local/tasks/SC-05/check_sc05.py` asserts that no SC-05 type lacks a row and that this request exists. Limits: documentary source review; no runtime evidence is relevant.

## Classification and proposed change

Classification: a specification omission in the admitted HF-06a matrix and an ownership conflict between SC-05 card item 1 and HF-06a F-04 with TH-06 UN-05. It is not an implementation defect in SC-05-A1, and it is of the same kind as AM-H8-001.

Proposed resolution: extend the HF-06a re-verification AM-H8-001 already proposes (under HF-06a line 193, "when an SC card cannot fit a row into its family scope") to decide the owner of event, secret-room and respec-opportunity definitions. Then propagate the result.

1. **Preferred: objectives stay with SC-04.** Event and secret-room types are objective definitions under F-04, as TH-06 UN-05 already reads, and a respec opportunity is an objective or reward boundary under Q-P18 and Q-P38. SC-05's card goes to revision 2 with "events and secrets" removed from its source bullet and item 1, plus a note that levels reach them through F-04 references. HF-06a N-024's sentence becomes "a respec opportunity is an F-04 objective definition (SC-04) under Q-P18", with the HF-06b N-024 cell and TH-07 Seam 5 repointed in the same drift fixpoint. The SC-05 contract needs no field change, because T2 already references F-04 encounters and objective placement reaches a level the same way.
2. **Alternative: SC-05 owns them.** The re-verification adds a matrix row, or revises F-05's rationale, typing event and secret-room definitions under SC-05, with their HF-06b save cells and any HF-07a cell. SC-04's objective scope and TH-06 UN-05 are revised to reference them. SC-05 then needs an attempt 2 to author the two types.
3. **Leave unchanged: rejected.** SC-05 cannot meet item 1 without borrowing N-024 or F-04, which HF-06a line 46 and the packet forbid.

Option 1 is preferred because it matches the one admitted runtime contract that already places these types (TH-06 UN-05) and moves one sentence, not a family boundary. Option 2 is viable if Andrew wants spatial secret rooms modelled as world content rather than objectives. That choice overlaps Q-P38's type selection and should be put to him with it.

Compatibility: no save field changes under either option. Objective state is `EncounterState` (HF-03a line 46), a respec replaces the build selection and is not a separate record (HF-06b N-024), and no HF-07a CSV field names an event or secret. The browser proofs are unaffected (no native content). Native proof contracts are unaffected. SC-05's delivered T1 to T5 are unaffected under both options. Re-verification is needed for HF-06a, the HF-06b N-024 cell, TH-07 Seam 5, the SC-04 and SC-05 cards, and TH-20's inventory.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Accepted by the coordinator, 2026-09-16, option 1, as a factual correction preserving the admitted TH-06 UN-05 contract (event and secret-room types are F-04 objective definitions owned by SC-04) and HF-06a F-04; option 2 would change an admitted family boundary and is not taken. Reported to Andrew, who may override. |
| Accepted scope | SC-05 card revision 2 removing events and secrets from its source bullet and definition-of-done item 1 with a note that levels reach them through F-04 references, recorded by a definition-change event with FR-07's definition import; FR-07 applies HF-06a N-024's sentence ('a respec opportunity is an F-04 objective definition (SC-04) under Q-P18'), the HF-06b N-024 cell and TH-07 Seam 5 in its drift fixpoint. No save field changes. |
| Implementation defect | not applicable; classified as a specification omission |
| Rejected request | not applicable |
| Deferred request | not applicable |
| Prior decision | none; related requests AM-H8-001 (EV-0388, EV-0392), AM-H8-002, AM-H8-003 |
| Board event | The SC-05 handoff and amendment event in TRACKING. |

## Admission and propagation receipt

Pending acceptance. Required propagation under option 1: HF-06a N-024 rationale and its CSV cell; HF-06b N-024 rationale and its CSV cell; TH-07 Seam 5; SC-05 card revision 2; a note on SC-04's card if its scope wording needs it; stated-hash fixpoint over every citing section; an independent review of the changed acceptance contract.

## Closure disposition

Open until the coordinator records a decision. SC-05's events and secrets remain blocked on it; SC-05's other five types do not depend on it.
