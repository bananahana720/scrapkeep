# SC-02 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: FAIL.** There is one blocking finding. SC-02's Seam 1 contradicts admitted HF-06a rows; it does not refine them. It changes the family that kit slot actions and mobility actions point to, and a card may not settle that on its own authority. Everything else in the contract is sound and well sourced.

**Evidence level:** I read about 190 cited lines against the sources (level 2). I walked all three scenarios step by step against the HF-05 transition table (level 3). The hash, drift, scope, docs, project and paper-check results come from the coordinator's receipts, which are level 4. I read them but could not rerun them because I had no shell.

**Candidate:** `/home/andrew/Projects/scrapkeep-wt-SC-02/docs/tech/schemas/SC-02.md` at `07bef9da`.
- Per `coordinator-candidate/identity.txt`: parent `254f8e11`, one added path, clean tree.
- Per `candidate-sha256.txt` and `paper-check.json:3`: SHA256 `18cb7a9a…`.

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: not met (B1).**
   - The six subjects each land in one place (SC-02.md:39-46).
   - Rows F-02, N-020 and N-021 match HF-06a:141 and their CSV cells.
   - The foreign-reference table is at :361-373.
   - But FR-03 (:365), FR-11 (:373) and Seam 1 (:508) contradict admitted rows (B1).
2. **Fields, types, identity and version rules, references, diagnostics and one labelled example per type: met (level 2-3).**
   - The three schema types and six embedded records are at :100-355.
   - The shared identity rules are at :90-98. The 21 admission rules, each tied to an HF-05 edge and diagnostic, are at :381-403.
   - Every example is labelled "Illustrative, not canon" and is rejected by SC02-ID-04 (:95).
3. **Save treatment, round-trip expectations and executable obligation: met.**
   - The save table (:415-419) matches HF-06b:112, :138 and :139: `immutable-by-id`, `definition-by-id`, `tres`, projection none, proof owner none.
   - All eight save-field paths (:429-437) exist in the HF-07a CSV. I grepped them at CSV lines 3, 16, 25, 26, 30, 52, 56 and 60.
   - The round-trip expectations are RT-01 to RT-06 (:441-448). The executable obligations QO-01 to QO-04 are handed to TH-22 (:450-457), as HF-06b:47 requires.
4. **Unchosen values symbolic and tied to questions, no canon: met.**
   - Every `unset` parameter row names a question (:469-504).
   - The numbered rows are sourced: SP-01 from BIBLE:491, SP-03 from TH-03:228, SP-04 from TH-13:247, SP-05 from BIBLE:533-536, SP-06 from TH-04:276, SP-07 from TRACKING EV-0322, SP-08 from HF-07a:70.
   - The recorded Q-P13, Q-E10 and Q-P41 answers are not extended; I checked them against TRACKING.md:221, :238 and :265.

**Other acceptance items:**
- **Seven headings:** present (paper-check C01, per the coordinator's receipt).
- **17 hashes:** the coordinator's `check-drift-schemas.log` reports 17 stated hashes and 0 mismatches.
- **Negative controls:** 5, which meets the minimum of 3.
- **Packet bans:** only the one file changed; no Resource, script, roster or chosen value.
- **HF-04a:24 randomness scope:** quoted correctly (:14), and no field names a stream (:514).

## Blocking finding
**B1. Seam 1 moves kit slot actions and mobility actions from F-02 to N-021's type.**
- **What the admitted rows say:**
  - HF-06a:66 (F-01): the character references its weapon, mobility, main skill and ultimate actions "(F-02) by ID and expected family".
  - HF-06a:80 (N-007), and N-008 to N-011 "with the same reference shape": "kit slot references (F-02 weapon, main skill, mobility and ultimate)".
  - HF-06a:92 (N-019): "Per-character mobility actions are F-02 definitions".
  - HF-06a:36 defines the rationale column as including "which sibling rows it references", so that "(F-02)" is part of the admitted contract, not loose wording.
- **What the candidate does:**
  - FR-03 (:365) and Seam 1 (:508) make a kit slot name an `ability` ID. The candidate acknowledges that HF-06a:66 says otherwise.
  - `commits` (:277) says "A mobility action may commit none". A mobility slot action can therefore be no F-02 definition at all.
  - FR-11 (:373) still restates N-019 as pointing to `AttackDefinition`, so the contract also contradicts itself.
  - :569 sends the reading to TH-20. TH-20 runs only after admission (BACKLOG.md:1747-1764), so it is not an amendment route.
- **Why this is not a refinement:** the candidate's reading has real support.
  - N-021 (HF-06a:94) is its own schema row for "Ability and ultimate definitions".
  - TH-04:150 (AI-25) resolves "slot, node, ability, ultimate and device definitions" separately.
  - TH-04:313 (Seam 1) makes an activation that attacks a TH-03 commitment.

  So the admitted sources are in tension, and the candidate's design may be the better one. But it resolves that tension by changing the expected family of references in rows SC-01 and TH-02 own. A concurrent SC-01 that follows F-01 as admitted would fail with `wrong_family` against this contract.
- **Violated requirements:**
  - The packet: "contradictions with an admitted row are blocking".
  - ORCHESTRATOR.md:138: a worker "cannot silently deviate or edit shared authority" and must submit an amendment request.
  - HF-06a:193: recheck the matrix "when an SC card cannot fit a row into its family scope".
  - This is the same pattern that failed SC-01 at `SC-01/review-R1.md` B1.
- **Fix:**
  1. File an amendment request against HF-06a under ORCHESTRATOR.md:138. Revise the rationale of F-01, N-007 to N-011, N-019, and N-013's silhouette sentence, in both the Markdown and the CSV, so that kit slot actions are N-021 ability definitions that commit F-02 attacks. Bundle this with SC-01 B1's pending HF-06a re-verification.
  2. SC-02 then re-cites the new HF-06a hashes, turns Seam 1 into a plain citation, and remaps FR-11 to `AbilityDefinition`.
  3. Because this waits on an HF-06a change outside SC-02's write set, you may prefer to log SC-02 as blocked on HF-06a rather than plain changes-requested.
- **Alternative fix:** keep F-01 as written, and model every slot action, including non-attacking mobility, as an `attack` with an ability record attached to it. That fits the current rows but strains BIBLE:491's "committed danger shape", so I don't recommend it.

## Non-blocking notes
1. **The AI scenario names only one of two failing rules.** A `height_ceiling` key on a chaos outcome also fails SC02-S02, because the key is outside the closed field set (:242, :384). The trace at :554 names only S07, which S02 fully covers for this type. State both, or state which is reported first.
2. **AM.3 and AI.2 list only some diagnostic fields.**
   - AM.3 (:543) omits `requested_content_revision`, `catalogue_revision`, `candidate_identity`, `available_revision` and `message_key` (HF-05:109-115).
   - AI.2 (:554) omits candidate identity and current catalogue revision (HF-05:117).
   - Nothing is contradicted.
3. **N-020 appears against two types in the type table (:50-51).** The packet's paper-check wording is "exactly one type". The adds/restates reading (:62-70) is supported by N-020's own rationale (HF-06a:93) and HF-06b:138, so this is acceptable. Say explicitly that "restates" is not a second mapping.
4. **SC02-M04 depends on the contract's parameter table (:396, :407).** A runtime validator cannot read "unset" from a document. State how the gate is carried, for example through a card revision that supplies the value.
5. **SP-31 (:499) cites lines that only state the consequence.** TH-03:217 and TH-16:141 say what happens when a required telegraph cannot be drawn. The line that actually says the committed-attack telegraph is required is TH-16:279 (RP-17). Add that citation.
6. **Availability versus N-021's wording.** N-021 says "with availability … references". The candidate makes availability a published decision rather than a field (:269, following TH-04:56). This is consistent, but one sentence tying `slot_role` and `charge` to that phrase would help.

## What the paper check does and does not test
It goes beyond string presence:
- matches rows to the HF-06a CSV (C02a-c);
- compares save cells with the HF-06b CSV (C07b);
- checks save paths against the HF-07a CSV (C07e);
- checks scenario edges and state continuity against HF-05's table (C08b);
- checks example value forms and symbol linkage (C09e-f);
- checks hashes (C11).

Each negative control produced new failures (`paper-check.log`). The writer's and coordinator's checker copies share SHA256 `2e15acb0…` per both `source-manifest.json` files.

Gaps:
- **C02d** only looks for a phrase in each row's own rationale. It never reads sibling rows that point into this family (F-01, N-007, N-019), which is why B1 passed.
- **C05d** checks that foreign rows exist and have the right producing card, not that the reference direction or family agrees with that row's rationale.
- **C08** does not check that the named rule is the only one that fires (note 1) or that required diagnostic fields are present (note 2).
- **C09g/h and NC-4:** the codec is a trivial `path = value` split written into the checker. NC-4 swaps in a lossy Python decoder, which proves the harness notices loss, not anything about the contract. The contract admits this at :461 and :595.
- **C10c** checks that question anchors exist, not that their subjects fit. **C11** checks hashes, not what the cited lines say. **C04a** accepts any "line N" text.
- No control targets the reference-target check (C05b) or an out-of-vocabulary value.

## Walks (level 3)
- **AV (:524-531):** E02 draft→imported, E03 →structurally valid, E04 →semantically valid, E16 self-loop, E05 →admitted, E06 →pinned. All match HF-05:81-85 and :95. The structural rules S05, S06 and S08 hold on the example (`line` keys, `preview` with `prepared`, charge on the ultimate). M06, M07 and M08 hold (prepared attack, `intended` outcome, null disclosure). Correct.
- **AM (:541-543):** E02, E03, then E09 structurally valid→draft (HF-05:88). Code `missing_id` and the `referrer` form match HF-05:105 and :111. Correct.
- **AI (:553-554):** E02, then E08 imported→draft (HF-05:87), structural gate (HF-05:50). Correct, apart from note 1.

## Citations sampled
All say what the candidate claims unless noted.
- **HF-06a:** lines 22, 36, 42, 46, 66, 67, 80, 84, 86, 92, 93, 94, 141, 193; CSV rows F-01, F-02, N-007, N-019, N-020, N-021. Lines 66, 80 and 92 are accurate as quoted but contradict the allocation (B1).
- **HF-06b:** lines 23-27, 31-36, 45, 47, 111, 112, 138, 139, 212, 223; CSV rows F-02 and N-021.
- **HF-05:** lines 18, 22-25, 27, 29, 37, 39, 50-54, 62, 81-95, 105-117, 188.
- **HF-04a:** lines 22 and 24.
- **HF-07a:** lines 60-66, 70, 79, 113, 129, 130, 156; eight CSV paths.
- **TH-03:** lines 35-42, 48, 52-62, 165-169, 181-186, 217, 228-252 (TP-05, TP-06, TP-11, TP-13, TP-15, TP-16, TP-17, TP-21, TP-22, TP-25 at their stated lines).
- **TH-04:** lines 39-42, 48, 56, 68, 83, 86, 95-101, 113-118, 150, 244, 267, 276, 282-289, 295, 313.
- **TH-13:** lines 50-54, 64, 74-82 (78), 88, 90-92, 100, 112, 113, 124, 126, 138, 239, 247-265.
- **TH-16:** lines 108, 111, 112, 121, 122, 127, 128, 134, 141-143, 279, 280. Line 279 is uncited (note 5).
- **TADR-003:** lines 23-35, 41, 45, 47.
- **BIBLE:** lines 491-503 and 533-544.
- **TRACKING:** lines 221, 238, 265. **BACKLOG:** Q-P41 at 3356-3366; SC-02 card at 2228-2248, which matches the packet.
- **Hashes:** I did not compute them. I relied on the coordinator's `check-drift-schemas.log` (17 stated, 0 mismatches) and `source-manifest.json`, whose CSV and HF-05 hashes equal the ones the contract states.

## Commands
I ran none; I had no shell. The coordinator's `exits.txt` reports exit 0 for all six:
- `check:scope` (documentation-only)
- `check:docs` (156 files, 0 failures)
- `check:project`
- `check:drift` (292 hashes, 0 mismatches)
- `node scripts/check-drift.mjs --sections docs/tech/schemas` (17 hashes, 0 mismatches)
- the paper check (597 passed, 0 failed, 5 of 5 controls noticed)

## Runtime and writes
- **Model:** `claude-opus-5[1m]`, per the host's environment statement. That is Opus 5, matching the per-card routing at EV-0367, so there is no substitution. A model cannot verify its own identity by self-description.
- **CLAUDE_EFFORT:** unavailable to me; I have no environment access.
- **Writes:** none. I only read files.