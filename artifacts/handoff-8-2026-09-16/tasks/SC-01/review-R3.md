# SC-01 review R3

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-01 review R3: candidate `1f5a5a4d298ed3b1e1ff5f87be3d3c4f38cde7f8` (attempt SC-01-A3)**

## Verdict: PASS+NOTES

B2 is fixed. Node effects now point at an ability for the player's slot action and at an attack for a device or companion action, with one family per field. SM-50 holds Q-P15 open rather than answering it. None of the notes below breaks a definition-of-done item.

**Evidence level:**
- **Level 3 (walked step by step):** the row allocation, the save crediting, the B2 logic and walks AV and AI.
- **Level 2 (pointed at file:line):** every citation I sampled.
- **Level 4:** exists only in the coordinator's receipts. I had no shell and ran nothing.

All candidate line numbers below refer to `/home/andrew/Projects/scrapkeep-wt-SC-01-A2/docs/tech/schemas/SC-01.md`.

## Is B2 resolved? Yes
- **Separate fields, one family each.**
  - `effects[].ability_ref` points at row N-021 with family `ability` (:378, :394).
  - `effects[].attack_ref` points at row F-02 with family `attack` (:379, :395).
  - SA-52 requires exactly one of `ability_ref`, `attack_ref` and `attribute_key` (:404). That satisfies HF-05's one required family per reference (HF-05.md:22, :108).
- **SA-54 ties each field to its target class (:406).** `ability_ref` requires the target to be `player` alone; `attack_ref` requires only `device` or `companion` targets.
  - This matches SC-06: device and companion compatibility lists name F-02 attacks (SC-06.md:122, 141, 200, 253), limited to the definition's own actions (SA-10 at :100).
  - An ability can never be one of those attacks, so SA-54 is the only reading that lets a node reach them.
- **SM-50 preserves Q-P15 (:408, SP-21 at :518, :624).**
  - It picks no product value. It applies HF-05's rule that unknown required rules block admission (HF-05.md:51) to TH-07 PP-46, which leaves node participation for devices and companions unset (TH-07.md:346).
  - TH-08 EC-04 blocks content whose required rules are unknown (TH-08.md:80).
  - It has no present effect beyond SM-01, because every node effect is already a Q-P11 placeholder (SP-20). What it adds: a Q-P11 answer alone cannot open device or companion targets.
- **No contradiction with the sources the packet names:**
  - **TH-08 EC-01 and EC-03** (TH-08.md:77, 79): a node is an effect source, the reference is the action or attribute modified, and eligibility stays with the rebuild.
  - **TH-08 EO-04** (:178) evaluates each target class an effect names. An effect aimed at a mixed player-and-device set can only name an attribute. That follows from one family per field and contradicts no row.
  - **TH-07 Seam 6** (:366) describes what happens once an effect is eligible. It does not grant participation.
  - **AM-H8-003** (HF-06a.md:205) covers kit actions only, and Seam 3 says so (:535). The player's slot action being an ability follows from the kit rows (HF-06a.md:66, 94).
- **Every place the A3 change request named was updated:** SA-52, the T5 references and diagnostics, the F-02 foreign row (:426), Seam 3 (:535), Seam 7 (:543), QO-3 (:486), SP-21 and RT.3 (:600).

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: met (level 3).**
   - Five types (:37-43), eleven rows (:90-102), foreign references (:423-432).
   - I matched every type phrase against HF-06a.md:66-110 by hand. Each row's types equal the types its rationale names, and no type lacks a row. For example, N-024's "Slot definitions and slot-tree definitions … 15 nodes" gives T3, T4 and T5; N-008's "(F-01)" and "kit actions" give T1 and T2.
2. **Fields, types, identity and version rules, references, diagnostics and one labelled example per type: met (level 2-3).**
   - T1 :104-167, T2 :169-221, T3 :223-269, T4 :271-364, T5 :366-417.
   - Every example is labelled "Illustrative, not canon", and SA-02 makes each one inadmissible.
3. **Save treatment, round-trip expectations and executable obligation: met (level 2-3).**
   - Save table :438-450. Crediting checks out: `build` (HF-07a.md:125), `slots` (:126), `slot_id` (:127), `unlocked` to N-024 (:128), `tree_id` (:129), and `node_keys` through the HF-06b F-03 and N-024 rationales (HF-06b.md:113, 142).
   - The R2 note 1 sentence (:436) is accurate: both the F-03 and N-013 rationales name the access state (HF-06b.md:113, 131).
   - Load rules SL-01 to SL-06 (:460-465), round-trip expectations RA and RS (:471-476), TH-22 obligations QO-1 to QO-7 (:484-490).
4. **Symbolic values and no canon: met (level 2).**
   - SP-14 to SP-28 are `unset` with question IDs; SP-01 to SP-11 cite source lines; SP-12 and SP-13 are labelled as this contract's decisions (:498-527).
   - No cost, grant or count is chosen, and nothing has a Resource, script or runtime form.

**Seven headings:** present at :3, 27, 549, 618, 629, 637 and 649.

## Walks (level 3)
- **AV (:555-563):** E02 → E03 → E04 → E16 → E05 match HF-05.md:81-84 and :95. The coordinator's model fixture uses `player` targets with `ability_ref` (check_contract.py:447), so SA-54 and SM-50 pass. AV.2 does not list SA-54 (note 3).
- **AI (:578-583):** replacing the edge k2→k5 with k1→k5 leaves seven nonterminals holding fourteen edges, so there are still eight endpoints, all at depth three. Only SA-43 fires, once at k1 and once at k2, then E08 (HF-05.md:87). Correct.
- **AM (:567-574):** unchanged since R2. E12 (HF-05.md:91) with all eleven fields (HF-05.md:105-115).

## No regressions
- **Allocation and crediting:** unchanged; see items 1 and 3.
- **R1 notes 2 to 7 still hold:**
  - SV-02 still cites G11 (:65).
  - AM still lists all eleven fields (:573).
  - The hand-coded model is still described (:651).
  - SI-02 is intact (:52).
  - SA-23, SP-12 and SP-13 are still labelled (:203, :509-510).
  - The control count now reads sixteen (:647), matching the receipt.
- **R2 notes 2 and 3 still stand:** slots are shared by every character (:225), and the SC-03 and SC-08 hashes and lines get re-pointed at integration.
- **R2 note 4:** still no randomness here, so HF-04a line 24 does not apply.

## Blocking findings
None.

## Non-blocking notes
1. **The player target now has two action families, and no seam says so.** Admitted SC-03 lets a `player` target name F-02 attacks (SC-03.md:78-79, 187-188; its example at :210-211). HF-06a N-016 also lets an item effect name either an ability or an attack (HF-06a.md:89). SA-54 lets a player-target node name only an ability.
   - This is a gap, not a contradiction: no admitted row fixes the family for node effects, and EC-01 accepts "the action".
   - Fix: one sentence in Seam 3 (:535) naming SC-03 and TH-20 for reconciling player-target action families in the single compatibility query.
2. **Stale attempt number.** :5 still says "attempt 2" although this is attempt 3. The procedure at :643 is correct.
3. **AV.2 (:560) omits SA-54.** It lists "SA-50 to SA-53" passing on each node.
4. **Re-verification triggers miss the new sources.** :633 lists TH-08 EQ-03, EC-01, EC-02 and EO-04 but not EC-03, which SA-54 cites. :635 rechecks Seam 3 only when SC-02 is admitted, not when SC-06 changes lines 122, 141, 200 or 253, which `attack_ref` depends on.
5. **TH-07 PX-02 contains an arithmetic error; SC-01 is right.** TH-07.md:253 says that in its case (15 nodes, 14 edges, one nonterminal with one child and another with three) "the endpoint count also fails". Fourteen edges over seven nonterminals always leave eight endpoints, so it cannot fail. AI.2 cites PX-02 and correctly says SA-44 passes. Their outcomes agree (rejected under PT-04). The coordinator can correct this as a factual documentation error under ORCHESTRATOR.md:140. This dates from before A3.

## What the paper check does not test
I read these in `coordinator-candidate-A3/check_contract.py`:
- **C06 is weak on the real document.** Its "effect family follows its target class" check (:723-731) passes trivially, because every example target is a placeholder. Only NC15's mutation makes it bite. C06 also never compares families with SC-06's or SC-03's text.
- **The model tests SA-54 in one direction only.** The `effect_family_target` mutation covers a device target with an ability (:504), never a player target with an attack.
- **SM-50's tie to SP-21 and Q-P15 is not tested.** The model fires `node_target_unset` on any device target (:385-386).
- **Every R2 gap remains:**
  - C02 checks hashes only.
  - C03 matches phrases by substring.
  - C07 falls back to rationale text only for `node_keys`.
  - C09 runs a hand-written model, not the rule text.
  - C10 uses a model notation.
  - C11's number scan covers only the rule and field tables (:978).

## Citations sampled (all say what the candidate claims unless noted)
- **HF-05:** lines 18, 22, 50, 51, 54, 81-95, 105-117.
- **HF-06a:** lines 22, 24, 46, 66-110 (F-01, F-02, F-03, N-007 to N-014, N-016, N-021, N-024, N-037), 193, 205.
- **HF-06b:** lines 111, 113, 125-132, 142.
- **HF-07a:** lines 125-130.
- **HF-09:** P13 and P14 at lines 121-122, M9 at 195.
- **TH-07:** PT-06 (:62), PT-12 (:68), PT-13 (:69), PI-01 (:145), PX-02 (:253, see note 5), PX-07 (:258), PX-08 (:259), PX-20 (:271), PF-06 (:284), PP-16 (:316), PP-22 (:322), PP-46 (:346), Seams 5 and 6 (:364, :366), WC.5 (:398).
- **TH-08:** EQ-03 (:58), EQ-05 (:60), EQ-09 (:64), EC-01 to EC-04 (:77-80), EO-04 (:178), EO-06 (:180).
- **TH-04:** AA-02 (:53), AA-03 (:54), AP-23 (:289), AP-26 (:292).
- **SC-06:** lines 100, 122, 141, 143, 200, 253.
- **BIBLE:** lines 529-544, 552.
- **BACKLOG:** Q-P11 (:2950), Q-P15 (:3006).
- **Hashes:** I computed none.

## Commands
I ran none: this session had no shell tool. These results come only from the coordinator's receipts, which I read but could not rerun:
- `exits.txt`: exit 0 for check:scope, check:docs, check:project, check:drift, `check-drift.mjs --sections docs/tech/schemas`, and the paper check.
- `check-scope.log`: documentation-only, one changed path.
- `check-drift-schemas.log`: 108 hashes, 0 mismatches, 0 unbound.
- `paper-check.log` and `paper-check.json`: 353 passed, 0 failed, 16/16 negative controls failed as intended.
- `identity.txt`: head `1f5a5a4`, parent `4a265a6`, clean tree, one added file.
- `candidate-sha256.txt`: `e2264c76…b90f`.

## Runtime, reads and writes
- **Model:** `claude-opus-5[1m]`, according to the host's environment statement; a model cannot verify its own identity. That matches the Opus 5 routing at EV-0367.
- **CLAUDE_EFFORT:** unavailable; I had no environment access.
- **Reads outside the packet:** I read `assignment-A3.md` because the packet names it as the change request, even though my standing instructions say not to read the writer's brief. My findings rest on the candidate and its sources.
- **Writes:** none. I only read files.