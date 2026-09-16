# Specification amendment request AM-H8-006

## Request identity and context

| Field | Required entry |
| --- | --- |
| Request ID and title | AM-H8-006: Andrew's UI-only input exception (menu and interface navigation sounds at the input moment) departs from admitted TH-16's rule that every audible cue plays from a published fact in F-PROCESS. |
| Request revision and date | Revision 2, 2026-09-16 (UTC). Revision 1 named TH-16 and TH-17 only; revision 2 adds HF-04a line 46 (coordinator reading while defining FR-08) and HF-06a N-051 line 124 (PD-03 review R3 note R3-N2). |
| Requester and owner | Raised as blocking finding BF-1 of independent review R2 of PD-03 closure repair candidate 3baba5a354df013cfe42be64beefdbd53191e287 (scrapkeep-reviewer-medium, claude-opus-5 high), retained at artifacts/handoff-8-2026-09-16/tasks/PD-03/review-R2.md; received by the Handoff-8 coordinator (claude-opus-5). |
| Program and authorization | Handoff-8-2026-09-16, TRACKING EV-0367; Andrew's product decision at EV-0453 on integrated read finding B3. |
| Source identity | Main at 156310763985b7d6698e1ee52fabf08b27d4b3b1 (TH-16 unchanged since its Handoff-7 admission, EV-0365). |
| Request state | `accepted` (revision 1) |
| Decision owner | Andrew: product direction (EV-0453, "Instant UI clicks"). The TH-16 wording that realizes it is a technical revision needing its own card, reviewed attempt and authorization. |
| Admission state | Not admitted. Propagation is card FR-08 (HF-04a F-INPUT row, TH-16 RI-14, RV-5 and Seam 4, HF-06a N-051 check), proposed for a later sprint. |
| Affected work | HF-04a (done; line 46's F-INPUT row lets Presentation record UI requests only, so starting a click there needs the same named exception); HF-06a (done; N-051 line 124 says cues are consumed from committed results, which FR-08 checks and qualifies for UI-request-keyed clicks); TH-16 (done, Handoff-7; RI-14, RV-5, Seam 4 need the named exception); TH-17 (queued; owns the click plumbing and must not realize input-moment playback before admission). PD-03 records the decision and gates SE-14's input-moment playback on this amendment's admission, so PD-03 depends on this request's decision, not on its propagation. |
| Safe continuation | PD-03 attempt 3 states the exception as Andrew's decision, names the TH-16 rules it departs from and gates it; until admission SE-14 follows TH-16's published-fact rule. No other Handoff-8 output is affected. |

## Conflicting clauses and observation

| Clause | Source and identity | Relevant text | Authority and conflict |
| --- | --- | --- | --- |
| A | TRACKING.md EV-0453 | Menu and interface navigation sounds play at the input moment as a named UI-only exception; every gameplay cue still waits for its published value. | Andrew's product decision. |
| B | docs/tech/sections/TH-16-rendering-integration.md RI-14 (line 181) | Play a cue, effect, animation or audio voice from a published fact, in F-PROCESS, or F-SIGNAL for an engine completion. | Admitted technical rule; no input-moment path. |
| C | TH-16 RV-5 (line 55) | Feedback derived from one published fact that `present_committed_result` or `present_snapshot` delivered. | Admitted state definition; a click at F-INPUT has no delivered fact. |
| D | TH-16 Seam 4 (line 304) | An audible cue consumes a published value. | Admitted seam to TH-17. |
| E | docs/product/sections/PD-03-sound-feel-events.md at 3baba5a, lines 48, 65 and 102 | SE-14 sounds at the input moment under the exception; SI-04 cites TH-16 line 304 as a carrier. | Candidate states A without disclosing its conflict with B to D. |

Observation (reviewer walk, level 3): in F-INPUT InputAdapter updates the input context and Presentation records a `UiRequest` (HF-04a line 46; TH-16 RI-12 line 179); the click plays there, before any published fact exists and outside F-PROCESS, so B, C and D fail; Session reads the request on D06 in F-PROCESS (TH-12 SO-02 line 116).

## Classification and proposed change

Product-direction amendment to an admitted technical section. Proposed propagation (later card FR-08, TH-16 revision): add a named UI-feedback exception to RI-14, RV-5 and Seam 4 that lets Presentation play an interface navigation or activation click at F-INPUT from the recorded input context or `UiRequest`, deciding nothing, recording no consumption of a gameplay fact and never used by a gameplay cue; re-point citing hashes by drift fixpoint; TH-17 then owns the plumbing. Alternatives considered: (1) reverse the decision and keep SE-14 on published values (rejected: Andrew chose instant clicks); (2) reopen TH-16 inside Handoff-8 (not taken: TH-16 is a Handoff-7 output, closure repair reopens only this sprint's outputs, and widening scope needs Andrew's authorization; nothing implements audio before TH-17). Compatibility: no save field, transition, command or gameplay rule changes; only UI feedback timing.

## Decision record

| Field | Required entry |
| --- | --- |
| Decision | Accepted, 2026-09-16: product direction by Andrew at EV-0453; recorded as an amendment by the coordinator after PD-03 review R2. Propagation deferred to a TH-16 revision card proposed for the next sprint. |
| Accepted scope | A UI-only input-moment exception for menu and interface navigation and activation sounds; gameplay cues unchanged. |
| Implementation defect | not applicable |
| Rejected request | not applicable |
| Deferred request | not applicable (accepted; propagation carried) |
| Prior decision | EV-0453 |
| Board event | The PD-03 review R2 and attempt 3 assignment event. |
