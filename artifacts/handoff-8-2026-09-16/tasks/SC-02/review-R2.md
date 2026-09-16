# SC-02 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**Verdict: PASS+NOTES.** B1 is resolved: the kit reference to `ability` now simply cites the admitted rows. Every definition-of-done item is met, and nothing below breaks the definition of done.

**Evidence level:** 2 for the definition-of-done items (each claim checked at file:line). 3 for the AM and AI scenarios, which I walked step by step against HF-05. The level-4 results (scope, docs, project, drift, schema drift and the paper check) come only from the coordinator's receipts. I read those receipts and the checker's source but ran nothing, because I had no shell.

**Candidate:** `/home/andrew/Projects/scrapkeep-wt-SC-02-A2/docs/tech/schemas/SC-02.md` at `c2e6c7c9`.
- Per `coordinator-candidate-A2/identity.txt`: parent `43a8f12a`, one added path, clean tree.
- SHA256 `3c856d50…` matches `candidate-sha256.txt:1` and `paper-check.json:3`.
- The writer's checker and the coordinator's copy have the same hash, `ea573421…`: `a2-final/paper/source-manifest.json:9` and `coordinator-candidate-A2/paper-check/source-manifest.json:9`.

## Definition-of-done items
1. **Scope, matrix rows and foreign definitions: met.**
   - The six subjects each land in one place (SC-02.md:41-48). The row map is at :68-72 and matches HF-06a:141.
   - **B1 is resolved.** Each piece now matches the admitted rows (HF-06a:66, :80-84, :86, :89, :92, :94):
     - FR-03 (:369) points at `AbilityDefinition`.
     - FR-11 (:377) remaps N-019 to `AbilityDefinition`.
     - The `commits` field (:281) and Seam 1 (:513) follow those rows.
     - FR-08 (:374) and FR-12 (:378) follow N-016 and N-013.
     - The TH-20 routing is gone: :574 states the family `ability` as fixed.
   - **SC-04 and SC-06 citations are accurate:**
     - SC-04:52, :150, :163, :403 and :417 say what the candidate claims.
     - SC-06:39 is `device`, which is the family `deploys[]` expects (SC-02.md:320, :367).
     - SC-06:140-141, :199-200, :252-253, :303-304 and :293 are read correctly as `attack` references, with command capabilities included (SC-02.md:373, :515).
     - SC-06:63, :143, :338, :341 and :449 match.
2. **Fields, types, identity and version rules, references, diagnostics and one labelled example per type: met.**
   - The three types and six embedded records are at :104-359.
   - Shared identity rules are SC02-ID-01 to ID-07 (:94-102).
   - References are at :160-167, :237-239 and :315-322.
   - The 21 admission rules, each with its edges, are at :386-408.
   - Each type has one example labelled "Illustrative, not canon" (:191, :258, :343).
3. **Save treatment, round-trip expectations and executable obligation: met.**
   - The save table (:420-424) matches HF-06b:112, :138 and :139.
   - The seven save paths at :434-440 are all in the HF-07a CSV (lines 3, 16, 25, 26, 30, 56, 60).
   - Round-trip expectations RT-01 to RT-06 are at :446-453.
   - The executable obligations QO-01 to QO-04 go to TH-22 (:455-462), as HF-06b:47 requires.
4. **Unchosen values symbolic and tied to questions, no canon: met.**
   - The parameter rows are at :472-509.
   - The recorded answers are not extended: Q-P13 at TRACKING.md:239, Q-E10 at :222, Q-P41 at :266.
   - Settled rules are followed:
     - The HF-04a:24 randomness scope is quoted correctly (:14), and no field names a stream (:519).
     - Durable fields exist in the HF-07a CSV.
     - Every unset row names a question.

**Other acceptance items:**
- **Seven headings:** present at lines 3, 29, 523, 563, 578, 590 and 600.
- **Hashes:** 19 are stated (:588).
  - HF-06a (Markdown and CSV), HF-06b CSV, HF-07a CSV and HF-05 match the manifest.
  - The rest rest on the receipts: `check-drift-schemas.log` reports 107 hashes and 0 mismatches, and paper check C11 passed.
- **R1 notes, all addressed:** AI.2 now names both failing rules and all required fields (:559); AM.3 lists all 11 `ContentReferenceFailure` fields (:548); "restates" is defined (:66); the SC02-M04 gate is carried by card revision (:412); SP-31 cites TH-16:279 (:504); availability is tied to `slot_role` and `charge` (:273).
- **Row allocation (N-021 on `AttackDefinition`):**
  - It follows the packet's rule literally: N-021's revised rationale names "the F-02 attack definitions" (HF-06a:94), and :74 says it appears only as the target of `commits`.
  - It is not re-treated: the treatment, producing card and save values are unchanged (HF-06b:139).
  - Note 1 records a caveat.

## Walks (level 3)
- **AM (:546-548):**
  - E02 draft→imported, then E03 imported→structurally valid (HF-05:81-82).
  - Then E09 structurally valid→draft, "Initial candidate fails semantics" (HF-05:88).
  - All 11 required fields from HF-05:105-115 are present. Correct.
- **AI (:558-559):**
  - E02, then E08 imported→draft at the structural gate (HF-05:87, :50).
  - The `ContentAdmissionFailure` fields match HF-05:117. Correct.
- **AV (:531-536):** E02, E03, E04, E16, E05, E06 match HF-05:81-85 and :95.

## Blocking findings
None.

## Non-blocking notes
1. **N-021 on `AttackDefinition` blurs "describes" and "references".**
   - HF-06a:22 lets a noun row describe a family's type only when it names the family row it instantiates. N-020 does that; N-021 only references F-02.
   - The checker would force this allocation anyway: `check_sc02.py:343` fails a type that omits any row whose rationale contains one of its phrases. F-02's "attack definition" appears inside N-021's "F-02 attack definitions".
   - As a result, the save table (:422) lists HF-06b N-021 for attacks, although HF-06b:139 talks only about abilities.
   - **Fix:** mark N-021 as reference-only in the type table (:52), or narrow the attack basis phrases.
2. **Wrong citation at :96.** "HF-06a lines 124, 125" is cited for player-facing names belonging to presentation and glossary definitions. Those lines are N-051 (audio cues) and N-052 (feedback bindings). The glossary rows are N-056 and N-057 (lines 129-130), and neither covers abilities.
3. **SC-03 changed after the base.** It was readmitted at EV-0442 (TRACKING.md:175), so "being revised concurrently" (:27, :517) is out of date on main. Admitted SC-03 also points at F-02 from `effects[].action_ids` (SC-03.md:79) and `result.action_ids` (SC-03.md:188), and SC-02's foreign-reference table has no row for either. The trigger at :586 already covers this; it is an omission, not a contradiction.
4. **SC02-M09 adds a check on SC-04's records.** It rejects an enemy archetype that names a `prepared` attack (:406), a check admitted SC-04 does not carry (SC-04:417). Yet :515 says SC-04's usability check "adds nothing". State plainly that SC02-M09 is the SC-02-side check.
5. **The foreign ID grammar is still open.** SC-06:60 says F-02's ID grammar is SC-02's. SC-02 fixes only opaque, nonempty and case-sensitive, and leaves the character set to TH-20 (:96). Nothing contradicts, but the gap remains.
6. **Small overreach at :559.** HF-05:45 says validators "return findings", not "every finding".

## What the paper check does and does not test
It goes beyond string presence:
- the row map and allocation against both HF-06a copies (C02);
- sibling rows' wording and the types they point to (C12);
- save cells against the HF-06b CSV (C07b) and save paths against the HF-07a CSV (C07e);
- scenario edges, required fields and every rule that fires (C08);
- a table-driven encode and decode with typed decoding and reference resolution (C09g-j);
- hashes (C11).

Per `paper-check.log`, all 10 negative controls noticed their corruption, including NC-6, which restores the kit-to-attack reference.

Gaps:
- **C12b** compares against expected type sets written into the checker, not sets derived from the rows.
- **C04a and C10a** accept any "line N" text; no check confirms what the cited line says.
- **C05b** never checks a foreign reference's expected family (for example `device` against SC-06), and no negative control targets it.
- **`spec_kind`** (`check_sc02.py:225-234`) lumps bool, ticks, quantity, behavior-id, key and map fields together as "symbolic", so their values are never type-checked.
- **Rule content** is not tested: only the presence of identity and version rules (C03b) and the existence of listed diagnostics (C06c).
- **The codec** is still written inside the checker; the contract says so at :466 and :602.

## Citations sampled (all accurate except note 2)
- **HF-06a:** 22, 42, 46, 66, 67, 71, 72, 80-84, 86, 89, 92-94, 100, 124, 125 (note 2), 141.
- **HF-06b:** 23-27, 31-36, 45, 47, 112, 127, 138, 139, 212, 223.
- **HF-05:** 18, 22-25, 27, 29, 37, 39, 45-52, 54, 62, 66-95, 101-117, 188.
- **HF-04a:** 22, 24. **HF-07a:** 60-66, 70, 79, plus eight CSV fields. **HF-09:** 109, 111, 117, 121, 122, 175, 195.
- **TH-03:** 35-42, 52-62, 101, 102, 131, 134, 135, 138, 165-169, 181-186, 217, 228-252.
- **TH-04:** 39-42, 48, 56, 68, 83, 86, 95-101, 113-118, 150, 242, 244, 267, 276, 282-289, 295, 313.
- **TH-13:** 50-54, 64, 74-82, 88, 90-92, 100, 112, 113, 124, 126, 138, 239, 247-265.
- **TH-15:** 99, 108, 303. **TH-16:** 108, 111, 112, 121, 122, 127, 128, 134, 141-143, 279, 280.
- **SC-04:** 52, 150, 163, 403, 417. **SC-06:** 39, 63, 140, 141, 143, 199, 200, 252, 253, 293, 303, 304, 338, 341, 449.
- **Other:** BIBLE 489-503 and 529-544; TADR-003 lines 23-47; BACKLOG SC-02 card at 2226-2250 (matches the packet) and Q-P41 at 3354-3364.
- **Five hashes** match the manifest.

## Commands
I ran none. `coordinator-candidate-A2/exits.txt:1-6` reports exit 0 for:
- `check:scope` (documentation-only, 1 path)
- `check:docs` (164 files, 0 failures)
- `check:project`
- `check:drift` (349 hashes, 0 mismatches)
- `node scripts/check-drift.mjs --sections docs/tech/schemas` (107 hashes, 0 mismatches)
- the paper check (636 passed, 0 failed, 10 of 10 controls noticed)

## Runtime and writes
- **Model:** `claude-opus-5[1m]`, per the host's environment statement. That matches Opus 5 routing at EV-0367, but a model cannot verify its own identity.
- **CLAUDE_EFFORT:** unavailable to me; I have no environment access.
- **Writes:** none. I only read files.