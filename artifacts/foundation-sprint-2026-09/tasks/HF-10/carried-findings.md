# Findings carried into the HF-10 foundation review

Coordinator-compiled from the recorded per-card reviews and the integrated read. Each line names the section, the finding and the recording event. HF-10 must either confirm each as a required fix or explain why it is not one; none was a DoD failure at admission.

## From integrated read 1 (EV-0140, artifacts/foundation-sprint-2026-09/integrated-read-1/report.md)

- HF-04b:116,141 uses `retain_revision` at encounter replacement where HF-03b:182 uses `resolve_id` and HF-05:85-86,173 make replacement a pinned read (N1).
- HF-04b:124 calls `read_initial_snapshot`, absent from HF-03a:32; HF-03b:185 uses `read_committed_results` (N2).
- Queue and history capacities are routed to Q-E03 under B-memory/N-memory but HF-02 has no such row (N4).
- HF-03b:125 labels A1 "F-INPUT drain" and HF-03b:156-157,176-177 label calls as F-ASYNC where HF-04a:46,50 define the classes differently (N5).
- Validators straddle HF-01:36 (editor tools) and HF-03a:23,34 with HF-05:45-52 (ContentAdmission) (N6).

## Per-card review notes

- HF-04b (EV-0132): line 82 attributes typed for-loop variables to the ctx7 receipt, which lacks them; line 67 overstates X1; line 52 is a source reading under an assertion-established column; check_patterns.py omits fault receipt lines 4-5 and 10-14 and accepts an owner name in any column; line 27 lists CollisionQueries contact observations loosely.
- HF-03b (EV-0135): DF-01 at line 91 omits the rejected D06-then-D01 relay and its rejection ground (TADR-002:28, HF-03a:47, HF-04a:77); check_graph.py checks interfaces against the whole HF-03a row not the edge's permitted-use column, and miscounts D02's negative-clause backticks; R11 at line 180 is labelled local while disconnecting on D01 and D06; line 74 omits D02.
- HF-06a (EV-0145): N-052 embedded-record names no parent row; N-050 and N-012 stretch SC-07 and SC-08 cover lists; N-014 states "each upgrade node" where BIBLE:540 says significant upgrades should; N-032 palette as schema risks a second copy of frozen AD-02 text; line 58 names Q-P10, Q-P11, Q-P18, Q-P19 which appear in no rationale; the excluded-rationale check is a length proxy; five TH cards holding excluded rows do not list HF-06a as a source.
- HF-06b (EV-0152): line 10 says question tags are copied unchanged while F-08 adds Q-E09 (required correction); line 81 misstates which rows name Q-P16 (required correction); unreferenced immutable-by-id rows say only "nothing is projected"; the no-definition-no-state case wording overstates the trace for governance rows; C11 at line 209 prescribes a TH-22 test case.
- HF-07a (EV-0158): no in-document pointer to its own CSV (required correction); equipped-by-mount_id presumes named equipment positions no source establishes (required correction; product parameter carried to SC-03); build, equipment and companion containers carry no row (required correction); the S8 table lists Q-E09's poles not the mixed answer; missing blank line before one heading; about 21 of 841 assertions cannot fail and three coverage claims overstate; admission fired S0-07's reciprocal trigger at docs/tech/proofs/S0-07-save-owner.md:116.
- HF-07b (EV-0164): Transition D's validate list at line 105 omits the array-preservation gate its P4 column relies on (required correction); C4's T9 commit names no transition; line 36 versus C1.1 differ on who stages; lines 151 and 277 overstate the model replay (80 distinct runs, R dimension inert); the preferences decision at line 157 fully decides a question shared with HF-08.
- HF-05 (EV-0097, carried since Foundation-02): section line 8 cites TADR-004 where TADR-003:41 is correct.

## Question state at compilation

Q-P14, Q-P15, Q-E09 and Q-P16 are `proposed` (EV-0144, EV-0151, EV-0157, EV-0163): engineering-half protocols only, no product answer. Q-E05 and Q-E03 are open. HF-10 confirms that no section treats any of these as settled.
