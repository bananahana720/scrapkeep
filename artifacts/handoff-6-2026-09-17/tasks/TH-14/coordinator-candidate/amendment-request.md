# Specification amendment request: TH-14 durable-field enumeration and two sibling readings

Filed under the [amendment rule](../../../../ORCHESTRATOR.md#specification-contradictions), in the form of `docs/project/sprint-0/amendment-request.md`. This packet grants no write lease. Work on TH-14 continued, because the contradiction below is resolvable inside the card's own scope and stopping the whole card would be disproportionate; the resolution taken is stated and is the coordinator's to accept, reject or defer.

## Request identity and context

| Field | Entry |
| --- | --- |
| Request ID and title | Coordinator-assigned. Working title: TH-14 packet field enumeration omits `run.checkpoint.generation_decisions[]`. |
| Request revision and date | Revision 1, 2026-09-15 UTC. |
| Requester and owner | `scrapkeep-writer`, attempt TH-14-A1, lease TH-14-L1, model claude-opus-5 (1M context), runtime `CLAUDE_EFFORT=high`. Received by the Handoff-6 coordinator. |
| Program and authorization | Sprint Handoff-6-2026-09-17, authorized by Andrew at TRACKING EV-0327. |
| Source identity | Base `a3644ca2e2c7124a930de0f66cf1c310ca0f1309`, worktree `/home/andrew/Projects/scrapkeep-wt-TH-14`, branch `wt/TH-14`. Candidate commit recorded in the handoff. No dirty files outside the two permitted paths. |
| Request state | `proposed`. |
| Decision owner | Coordinator. This is an evidence-backed correction to an assignment packet, not a change to accepted architecture or product direction. |
| Admission state | Pending. Nothing shared was edited. |
| Affected work | TH-14 revision 1, attempt A1, lease TH-14-L1. No other card is blocked. TH-15 is unaffected; no byte of it was read or cited. |
| Safe continuation | All of TH-14 continued. No worker is stopped. |

## Conflicting clauses and observation

### Item 1: the packet's durable-field enumeration omits a field the admitted sources require

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | `artifacts/handoff-6-2026-09-17/tasks/TH-14/assignment.md`, CONTEXT and VERIFY, at the base above | "HF-07a's CSV rows for `run.start.rng_state[]`, `run.checkpoint.rng_state[]`, `run.checkpoint.offered_choices[]`, `run.checkpoint.route[]`, `run.checkpoint.resolved_rewards[]` and `run.checkpoint.next_entrance` are the only durable randomness and generation facts; name no other." | Packet scope rule for the writer. |
| B | `docs/tech/sections/HF-07a-save-envelope.md` line 63, rule 4, section bytes SHA256 `267a5880e27e66436d31a669776b73ac502be73409a78e17084c89d8d9a61e8d` | "Offered options, accepted route steps, **accepted generation decisions** and resolved rewards are stored as what actually happened, and `run.checkpoint.rng_state` exists to continue generation, not to recompute any of them." | Admitted contract. It names accepted generation decisions as a stored outcome of exactly the same class as the four the packet lists. |
| C | `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` line 41, section bytes SHA256 `1a627a9d8afe03686981b44e73248fb23bda6755d46fa25022c8f7e525edfaa4` | A level's durable trace is "the advance of `run.checkpoint.next_entrance` and the scope's `run.checkpoint.generation_decisions`, and nothing else". | Admitted sibling. It makes the scope's decisions half of a level's whole durable trace. |
| D | `docs/tech/sections/TH-11-runs-regions-exits-and-saves.md` lines 42 and 45, section bytes SHA256 `4f705ee341dc5f53ae421f5605dba771ea797ce4f05ab4214db6b0df7483e9d3` | A level is identified by its entrance and "the `run.checkpoint.generation_decisions[].scope_id` the generator recorded its decisions under"; its content "is reproduced from `generation_decisions` and `rng_state` as what actually happened". | Admitted sibling. |
| E | `artifacts/handoff-6-2026-09-17/tasks/TH-14/assignment.md`, GOAL and the exact card's DoD 1 | Four independent responsibilities "each with one owner, one stream and one saved form for its resolved choice". | The card. The layout responsibility has no saved form under clause A. |
| F | `docs/tech/sections/HF-07b-commit-boundaries.md` line 76, section bytes SHA256 `0bcf60022ee4ef7c42f39f3714fd7947a1b7375f6ddf5be5f0d94c5c5940ae91` | Transition A's candidate carries "`run.checkpoint.route`, `run.checkpoint.generation_decisions`, `run.checkpoint.rng_state`, `run.checkpoint.offered_choices`, `run.checkpoint.resolved_rewards`..." | Admitted contract. The five fields commit together in one candidate. |

Both cannot hold. Clause A forbids naming the only field clauses B, C, D and F assign the layout responsibility's resolved choice to, and clause E requires that responsibility to have one.

Observation method: source review of the admitted bytes at the base above, hashes recomputed in the worktree. No command establishes runtime behaviour and none was run for this item.

### Item 2: two readings of admitted siblings, recorded for a ruling rather than assumed

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| G | `docs/tech/sections/TH-13-chaos-outcomes.md` line 63, XD-06, section bytes SHA256 `582b4dc5ea0fddfa6bc45bf5ca72442f8324e5e87d98977b9a2aed1aef93a068` | "No draw happens anywhere else. Not at P0, P1, P2, P3, P5 or P6..." | Admitted sibling, in a subsection whose subject is the chaos commitment's own draw. |
| H | `docs/tech/sections/TH-09-themed-loot-attunement-and-fixed-secrets.md` lines 49 and 121, section bytes SHA256 `500929af9d110cdee37162cd4a3b7859d2302ee7c751693274f0aff16daee578` | LK-1 is random at most once "from the encounter's own `EncounterRandomState` at P4 and P5"; LI-10 is the P5 row that names `EncounterRandomState` and determines the reward result values. | Admitted sibling. |
| I | `docs/tech/sections/TH-13-chaos-outcomes.md` line 281, Seam 2 | Whether route, layout, loot and miscast draw from separate streams is TH-14's. | The same sibling defers the loot half of the separation to this card. |
| J | `docs/tech/sections/TH-13-chaos-outcomes.md` line 251, XT-05 | "Generator positions an encounter owns: 1, `EncounterRandomState`." | Read flatly this fixes one encounter stream; TH-13 line 265, XT-19, says in terms that the `stream_id` vocabulary is not fixed there. |
| K | `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 24, section bytes SHA256 `cca7c341b0a163b0010e47c948af3d749e74c9a7fb61f475a3d332824215f91a` | The non-advancing control drain "cannot decrement a cooldown, move an actor, consume randomness, apply damage or release a cast". | Every other item in that list is Encounter's. The route and layout streams are Session's own `RunState` and must advance somewhere; every remaining position is inside a tick, which TH-11 RO-01 at its line 202 excludes. |

## Classification and proposed change

**Item 1. Factual correction to the assignment packet, not a defect in any admitted section.** The smallest resolution is to add `run.checkpoint.generation_decisions[]` with its `scope_id`, `policy_id` and `decision_keys` to the packet's enumeration and to the VERIFY clause that repeats it. No admitted document changes and no card revision is needed.

Resolution taken in attempt A1, pending that ruling: the section names the field, on clause B's and clause C's ground, and names no other field outside the packet's list. The paper check at `artifacts/local/tasks/TH-14/check_randomness.py` asserts the declared set of eight field paths, six groups plus the two resume positions, and fails on any durable field outside it, so the addition is enforced rather than assumed. The section records the addition and this request in its Procedure performed.

**Item 2. Unresolved contradiction between two admitted siblings, with a reading stated rather than assumed.** The section records both readings in its Seam 5 with the alternative named in each case, so a reviewer can reject either without re-deriving it.

- Reading 1 (GG-02): HF-04a line 24's prohibition on consuming randomness in the control drain is read as a prohibition on advancing *gameplay* randomness there. If the coordinator rules otherwise, the route and layout streams have no admitted position at all and TH-14 needs a reopened HF-04a rather than a revision.
- Reading 2 (GO-04): TH-13 XD-06's phase list is read as scoped to the chaos commitment's own draw, so the loot stream may be consumed at P5 as TH-09 LI-10 places it. The alternative, placing the loot consumption at P4 instead, satisfies every other rule in TH-14 unchanged; the choice is a TH-09 and TH-13 reconciliation.
- Reading 3 (GS-03): TH-13 XT-05's "1" counts the record HF-03a line 46 names rather than the number of encounter `stream_id` values, because XT-19 defers that vocabulary here. If the coordinator rules that XT-05 fixes one encounter stream, TH-13 needs a revision before TH-14's loot and miscast separation can stand.

Each of the three is recorded in the section's Re-verification triggers so a later change to the cited line reopens exactly the rule that rests on it.

## Decision record

Pending. To be completed by the coordinator.

## Admission and propagation receipt

Not applicable. No shared document was edited by this writer.

## Closure disposition

Pending. Item 1 closes with a packet correction or with a directed TH-14 revision that removes the field and reopens DoD 1. Item 2 closes with a ruling on each reading, or with a deferral recorded against TH-09, TH-13 and HF-04a.
