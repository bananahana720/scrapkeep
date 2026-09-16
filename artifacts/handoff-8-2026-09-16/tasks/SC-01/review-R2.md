# SC-01 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-01 review R2: candidate `4a265a6c854087cd1c94fdaf0c66ea1474692e96` (attempt SC-01-A2)**

## Verdict: FAIL

R1's blocking finding B1 is fixed. One new blocking finding remains. It comes from the change the writer made beyond the packet: node effects now point only at abilities, never at attacks.

**Evidence level:**
- Level 3 (walked step by step): the row allocation, matched phrase by phrase against HF-06a lines 66–110, and scenarios AI, AM and AV.
- Level 2 (pointed at file:line): every sampled citation.
- Level 4 exists only in the coordinator's receipts. I had no shell and ran nothing.

## Is B1 resolved? Yes
- **Allocation:** I matched the type phrases at SC-01.md:39-43 against every rationale at HF-06a.md:66-110 by hand, ignoring case. They produce exactly the types listed at SC-01.md:92-102:
  - F-01 → T1, T2, T4 ("character definition", "kit", "four slot trees").
  - N-007 → T1, T2, T4.
  - N-008 to N-011 → T1, T2.
  - N-013 → T1, T2 ("embedded in each character definition (F-01)").
  - F-03 → T4, T5 ("slot-tree definition", "15-node").
  - N-014 → T4, T5.
  - N-024 → T3, T4, T5 ("Slot definitions and slot-tree definitions", "15 nodes", "node effects").
  - N-037 → T1.
  
  These are literal readings, and they follow the rule the coordinator set in assignment-A2.md:7. No row's treatment changes (every Treatment cell equals HF-06a).
- **Save crediting:** it matches HF-07a's source cells:
  - `character_id` → F-01 (HF-07a.md:113)
  - `build` → F-03 (:125)
  - `slots` → F-03 and N-024 (:126)
  - `slot_id` → N-024 (:127, as FR-07 revised it at :350)
  - `unlocked` → N-024 (:128)
  - `tree_id` → F-03 and N-024 (:129)
  - `node_keys`: its source cell names no row (:130), so it is credited through the HF-06b rationales for F-03 and N-024 (HF-06b.md:113, 142).
  
  The result is at SC-01.md:436-445.
- **Seam 1** is now a plain citation of FR-07 (SC-01.md:527).

## Blocking finding
**B2. Node effects can reference only abilities, so a node effect can never name a device or companion action. This conflicts with admitted SC-06, TH-08 and TH-07 and closes off part of Q-P15.**
- **What the candidate does:**
  - T5 `effects[].ability_ref` (row N-021) or `attribute_key`, exactly one non-null (SC-01.md:378-379; SA-52 at :402).
  - `target_classes` still allows `device` and `companion` (:377).
  - The foreign-references table and Seam 3 say no node references an attack (:422, :531).
  - The paper check enforces this (check_contract.py:702-704).
- **What admitted sources say:**
  - TH-08 EC-01 (TH-08.md:77): one compatibility query covers "one equipped instance or one selected node". Its third input is "the action or attribute the effect would modify".
  - TH-08 EC-03 (:79): an effect reaches a target only where the target's definition declares it.
  - SC-06 (admitted) declares device and companion compatibility as `compatibility_action_ids` naming F-02 attacks (SC-06.md:122, 141, 200, 253), limited to the definition's own actions (SA-10 at :100).
  - SC-03 item effects likewise name F-02 attacks in `effects[].action_ids` (SC-03.md:78).
  - TH-07 Seam 6 (TH-07.md:366) expects "a device or companion effect eligible under a node's declared compatibility". PP-46 (:346) leaves node participation for devices and companions unset under Q-P15.
- **Why that conflicts:** no N-021 ability ID can ever be one of a device's or companion's `compatibility_action_ids`. So under T5, a node can reach a device or companion only through an attribute key, never through an action. That decides part of PP-46/Q-P15. It also gives the rebuild's single query two action families (ability for nodes, attack for items). FR-07's AM-H8-003 routes **kit** actions to abilities (HF-06a.md:205). It says nothing about node effects, and assignment-A2.md:11 limited this change to kit references.
- **Violated requirements:** "contradictions with an admitted row are blocking" and "no open question may be answered".
- **Fix:** Pick one of these:
  - Make T5's action reference follow the target class: `ability` (N-021) for a player slot action, `attack` (F-02) for a device or companion action, as SC-06 declares.
  - Or leave the reference's family as a placeholder under Q-P11 and Q-P15, with a seam to SC-02, SC-06 and TH-20.
  
  Either way, update SA-52, the T5 references table and diagnostics, the F-02 foreign row (:422), Seam 3 (:531), and C06 (check_contract.py:702-704). If Andrew intends AM-H8-003 to cover node effects too, that needs a recorded amendment first.

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: not met, because of B2.** The five types are at :37-43, with no orphan type. All eleven rows are allocated at :90-102. Foreign references are at :419-428. B2 sits on the T5 → F-02 boundary.
2. **Fields, types, identity and version rules, references, diagnostics and one labelled example per type: met in form (level 2-3), except T5's reference family (B2).** T1 is at :104-167, T2 at :169-221, T3 at :223-269, T4 at :271-364, T5 at :366-413. Each example says "Illustrative, not canon". SA-02 rejects the example IDs (walked in AX, :581-588).
3. **Save treatment, round-trip expectations and executable obligation: met (level 2).**
   - The save table is at :434-446; column and case match HF-06b rows :111-155.
   - Load rules SL-01 to SL-06 are at :454-461.
   - Round-trip expectations RA and RS are at :465-472; TH-22 obligations QO-1 to QO-7 at :478-486.
4. **Symbolic values and no canon: met (level 2).** Placeholders use the SI-08 form. SP-14 to SP-28 are `unset` with question IDs (:507-521). SP-12 and SP-13 are labelled as this contract's own decisions (:505-506). Every shape count is sourced to BIBLE line 529 or TH-07. Q-P18's recorded scope matches TRACKING.md:244.

**Seven headings:** present at :3, 27, 545, 614, 625, 633 and 643.

## Walks (level 3)
- **AI (:574-579):** swapping edge k2→k5 for k1→k5 gives 15 nodes, 14 edges, endpoints k7–k14, root k0, every endpoint at depth 3 and no second parent. k1 now has 3 children and k2 has 1, so SA-43 fires twice and nothing else does. E08 takes an initial candidate from imported back to draft (HF-05.md:87). Correct.
- **AM (:563-570):** E02 → E03 (a well-formed string passes SA-06) → E12, where a replacement fails semantics and becomes rejected-reload (HF-05.md:91). All eleven diagnostic fields are listed and match HF-05.md:105-115. Then E07 (:86). Correct.
- **AV (:551-559):** E02, E03, E04, E16, E05 match HF-05.md:81-84 and :95. Correct.

## R1 notes 2 to 7: all resolved
- Note 2: :641 says "fourteen negative controls"; check_contract.py:985-998 has 14.
- Note 3: :645 now says the rule model is hand-coded.
- Note 4: SA-23 is labelled at :203, SP-12 and SP-13 at :505-506.
- Note 5: SV-02 now cites G11 at HF-09 line 177 (:65), which checks out at HF-09.md:177.
- Note 6: AM lists all eleven fields (:569).
- Note 7: SI-02 now says SA-02 covers only `id` fields and SM-02 handles example references (:52).

## Non-blocking notes
1. **Access state is credited to N-024 only.** HF-06b's F-03 rationale names "the slot's access state" (HF-06b.md:113), and N-013's rationale places it "inside the F-03 and N-024 build-selection projection" (:131). The candidate lists `unlocked` only under N-024 (:437, :443, :445), following HF-07a.md:128. That is consistent with its stated rule (:432), but the gap should be stated in one sentence.
2. **One set of slots for every character.** T3 makes slots shared across characters, and SM-30 requires exactly four slot definitions in a catalogue (:225, :253). HF-06a N-024's wording ("each of a character's four slots is a slot definition", :97) allows either reading. This is a sourced design choice, but a product answer wanting per-character slot IDs would have to reopen SP-01.
3. **Line citations into SC-03 and SC-08 will move at integration.** On current main, SC-03's `action_ids` row has moved from line 78 to 79. The coordinator's view receipt shows the SC-03 and SC-08 hash mismatches; they plan to re-point these by content.
4. **HF-04a line 24's randomness rule does not apply:** SC-01 has no randomness.

## What the paper check does not test
- C03 compares rows only against the phrases the document itself declares (check_contract.py:628-634). It does not test whether those phrases capture each type's meaning; for example, `node` matches "15-node".
- C06 enforces the ability-only rule (:702-704) but never compares reference families with admitted sibling contracts. That is why B2 passed. It also accepts excluded rows as reference targets (:697-698).
- C07 uses HF-07a source cells first and falls back to HF-06b rationale text only for `node_keys` (:717-724), so note 1 is not tested.
- C02 checks hashes but not what the cited lines say.
- C09 runs a hand-written Python model of the rules (:172-380), not the document's rule text.
- C11's number check covers only the rule and field tables (:954), not scenarios, load rules or prose. It also checks that question IDs exist, not that their subjects fit.
- C10 round-trips through a model notation, not the real codec.

## Citations sampled (all say what the candidate claims)
- **HF-06a:** lines 22, 24, 46, 58, 66-110, 193, 205.
- **HF-06b:** lines 25, 27, 31-36, 45, 47, 60, 111, 113, 125-132, 142, 155, 209, 245.
- **HF-07a:** lines 26, 37, 56, 61, 64, 113, 125-130, 350.
- **HF-05:** lines 18, 22-24, 27, 35-41, 45, 50-54, 68-74, 80-95, 105-117.
- **HF-09:** lines 121, 122, 175, 177, 181, 195.
- **BIBLE:** lines 273, 275, 400, 402, 529-544.
- **TADR-003:** lines 23-45.
- **TH-07:**
  - PA-1 to PA-4 and line 49.
  - PT-01 to PT-13.
  - PI-01, PI-26, PI-27.
  - PX-02 to PX-20.
  - PF-06, WC.5.
  - PP-01 to PP-28, PP-46.
  - Seams 4 to 6.
- **TH-04:** AS-01 to AS-04, line 44, AA-02, AA-03, AP-22 to AP-26.
- **TH-08:** EQ-03, EQ-05, EQ-09, EC-01 to EC-03, EO-04, EO-06.
- **Sibling contracts:** SC-03 lines 53, 169, 170, 237, 382; SC-04 lines 44, 365, 366; SC-06 line 143; SC-08 line 272.
- **Hashes:** I computed none; see the coordinator receipts below.

## Commands
I ran none: this session had no shell tool. These results come from the coordinator's receipts, which I read but could not rerun:
- `coordinator-candidate-A2/exits.txt`: exit 0 for
  - check:scope (documentation-only, 1 path)
  - check:docs
  - check:project
  - check:drift
  - `check-drift.mjs --sections docs/tech/schemas` (108 hashes, 0 mismatches, 0 unbound)
  - the paper check (332 passed, 0 failed, 14/14 negative controls failed as intended)
- `identity.txt`: parent `43a8f12`, one added file, clean tree.
- `candidate-sha256.txt`: `6252dcda…258e`.
- `coordinator-view-A2/exits.txt`: schema drift and the paper check exit 1, only on the SC-03 and SC-08 hashes.

## Runtime and writes
- **Model:** `claude-opus-5[1m]`, according to the host's environment statement; a model cannot verify its own identity. That matches the Opus 5 routing at EV-0367.
- **CLAUDE_EFFORT:** unavailable; I had no environment access.
- **Writes:** none. I only read files.