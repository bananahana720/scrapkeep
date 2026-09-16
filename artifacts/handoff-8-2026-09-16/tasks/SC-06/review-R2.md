# SC-06 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-06 R2 review: FAIL on candidate `d71b6f149ec336d85a5d15941aa0a9954f7a913d` (attempt SC-06-A2, card revision 1). Evidence level 3.**

B1 is resolved: SR-10 and Seam 2 no longer change TH-08's query. But the fix added rule SM-07, and SM-07 makes SC-06 check another card's records. The admitted sections give that check to SC-03 and Q-P14. That is the one blocking finding, and it is a judgment call: another reading is possible, set out under B2.

I read the candidate and the admitted sources, walked the scenarios gate by gate, and read the paper-check script. I had only Read, Grep and Glob, so I ran nothing. Every hash result and exit code below rests on the coordinator's receipts. Identity I checked myself: the worktree HEAD is `refs/heads/wt/SC-06` (`.git/worktrees/scrapkeep-wt-SC-06/HEAD`), and that ref holds `d71b6f14…` (`.git/refs/heads/wt/SC-06:1`). The clean tree, the one-file diff and the file SHA256 `cd1ee6ec…` come from the receipts (`coordinator-candidate-A2/identity.txt`, `candidate-sha256.txt`).

## B1 decision
**Resolved for TH-08's query.**
- **SR-10** (`SC-06.md:65`) now:
  - makes both compatibility fields admission-time only and "never read at the rebuild";
  - keeps TH-08's three query inputs (EC-01, TH-08:77), its default-deny outcome (EC-03, :79) and the rebuild's three inputs (EQ-03, :58);
  - keeps DE-04's rule that no effect row names a device or companion (TH-10:94) and DE-05's rule that no controller reads the fields (:95).
- **Seam 2** (`:450`) leaves EP-31 (TH-08:293) open.
- An ineligible effect gets no new outcome for admitted content.

**SM-07** (`:105`) is where B2 below comes from.

## Definition of done
1. **Scope, matrix rows and foreign definitions: not met (B2).**
   - The row allocation is unchanged and correct at `:35-50`. It matches F-06, F-07 and N-027 (HF-06a:71, :72, :100), and line 22 of HF-06a allows a family row and a noun row on one type.
   - But SM-07 validates effect-source declarations inside SC-03's item and modifier records, which is outside "cover only devices, companion chassis, interchangeable components and command capabilities".
2. **Fields, types, identity and version, references, diagnostics and one illustrative record per type: met apart from SM-07.** See `:111-332`. The four diagnostics tables (`:151`, `:210`, `:264`, `:316`) carry SM-07 rows whose referrer is a foreign record.
3. **Save projection, round-trip expectations and executable obligations: met, no regression.**
   - Save table and load rules at `:350-367`: every HF-07a field is at HF-07a:159-165, and HF-06b rows :116, :117 and :145 are `json-projection`.
   - Round-trip rows RT-01 to RT-06 are at `:374-379`; obligations QO-01 to QO-07 at `:410-416`.
4. **Symbolic values and no canon: met, no regression.**
   - Parameter rows at `:422-444`: five cite a source and fourteen are `unset` with a question ID.
   - All records and the projection are labelled "Illustrative, not canon."
   - No EV-0144 field names appear.

## Blocking finding
**B2. SM-07 (`SC-06.md:105`, explained at `:85`, repeated at `:151`, `:210`, `:264`, `:316`) adds an eligibility check on SC-03's records, which the admitted sections leave to SC-03 and Q-P14.**

What SM-07 does: it refuses an effect source's declaration, which lives in an N-016 item record or an N-025 definition, when the declaration names one of these definitions with an action or attribute that definition does not list.

What the admitted sections say:
- **TH-08:73:** the compatibility subsection "fixes no eligibility, which is Q-P14's and SC-03's".
- **HF-06a:42 with :89:** N-016 is an embedded record, "validated inside the parent's structural and semantic gates", and its producing card is SC-03. HF-06a:46 gives the producing card the validation diagnostics.
- **TH-10 DE-10 (:100):** a device or companion reference that an item declares is "validated for existence and expected family at admission, like every other reference", and which pairs are eligible is Q-P14 content.
- **HF-06a:54:** under every Q-P14 answer, eligibility is "references validated for existence and expected family".

The candidate also contradicts itself:
- `:142`, `:202`, `:256` and `:308` say inbound references "are validated there", on the foreign side.
- `:339` says "Eligibility is Q-P14 content on the item side."
- Seam 4 (`:454`) never tells SC-03 about this obligation.

The risk: SC-03 is being written at the same time and cannot see SM-07. If both are admitted, content SC-03 declares valid could be refused by a rule that SC-03's contract does not contain.

The other reading: EC-04 (TH-08:80) lets admission check that declarations "satisfy the authored constraints". If the coordinator reads that as covering target-side lists written by SC-06, B2 drops to a note. In that case Seam 4 must still state the obligation on SC-03, and the self-contradiction at `:142`/`:202`/`:256`/`:308` must still be fixed.

Violated requirements: card DoD item 1 (scope), and the packet rule that a contradiction with an admitted row blocks.

**Fix:**
- Delete SM-07 and its four diagnostics rows.
- Keep `compatibility_action_ids` and `compatibility_attribute_keys` as authored declarations checked only by SA-10, SM-01, SM-02 and SM-05. That still satisfies TH-10 Seam 3 (:338).
- In Seam 4, state as undecided under Q-P14 whether SC-03's declarations must stay inside those lists, and leave that rule to SC-03.
- Reword SR-10, `:85` and Seam 2 so none of them names SM-07.
- Add a paper-check assertion that no admission rule's diagnostic referrer is a record outside the four types, with a negative control that restores SM-07.

## Non-blocking notes
- **Review R1's notes, all fixed and checked against the source lines:**
  - N1: TH-16 RM-01 is at line 121, RM-02 at 122, RM-07 at 127 and RM-08 at 128. The candidate now cites them correctly at `:22`, `:66`, `:344` and `:359` (TH-16:121-128).
  - N2: `ActionRequest` now cites TH-10 DO-09 line 80 at `:295`.
  - N3: walk AV now says catalogue A is the first catalogue, consistent with HF-05:64 and :97 (`:466`, AV.4 at `:473`).
  - N4: SA-08 (`:96`) and SR-03 (`:58`) now leave F-02's ID grammar to SC-02.
  - N5: the two chassis-only choices are labelled at `:189`, `:434`, `:435` and `:542`, with revision triggers.
- **R2-N1. No walk exercises SM-07.** Its failure edge (E09/E12) and its diagnostic are never traced.
- **R2-N2. `:85` misreads N-016.** It calls "whether an effect source's declaration names definitions by ID" open N-016 content under Q-P14, but HF-06a:89 already says attunement names device and companion IDs by expected family.
- **R2-N3. AX.3 (`:509`) leaves out SM-04.** SM-04 also fails `assembly_rule` and `availability_rule`, because their admissible sets are empty. The outcome is unchanged.
- **R2-N4. Seam 3 is accurate.** It names AM-H8-003 as accepted and not yet applied (`:452`). The amendment's scope at `amendments/AM-H8-003/request.md:15` and `:35` names this seam for re-verification and changes no F-06, F-07 or N-027 wording.

## Paper-check coverage
From the receipt (`coordinator-candidate-A2/paper-check.log:1`): 774 passed, 0 failed, and all 12 negative controls failed as intended. What the script (`check_contract.py`) does not test:
- **Compatibility check (`:530-540`) is wording only.** A regex searches for words like "narrow" and "can only". It cannot see whose record a rule validates, so it missed B2. Candidate line 558 admits this.
- **Projection round trip (`:492`, `:495`) is still `json.loads(json.dumps(x)) == x`.** Only the field types checked against HF-07a (`:496-504`) add real checking. The per-record encode and decode (`:154-181`) is a real replacement for the old JSON identity check, but it is symmetric by construction.
- **Citation check (`:572-586`) checks a line's content only when a row ID is cited with it.** A bare line citation only has to be nonblank.
- **Parameter check** confirms a sourced row cites "line N", not that the source states the value.
- **AS walk check** confirms axis values and row IDs exist in HF-09, not the consequences of a reject.

## Citations sampled (about 60 lines across 10 sources; all correct except SM-07's ownership claim)
- **TH-08:** :58 EQ-03, :62 EQ-07, :73, :77-80 EC-01 to EC-04, :96 EN-03, :99 EN-06, :288 EP-26, :292 EP-30, :293 EP-31, :304 Seam 1, :394.
- **TH-10:**
  - Rows: :66, :75 DO-04, :80 DO-09, :91-100 DE-01 to DE-10, :106-111 DC-01 to DC-06, :123-128 DN-01 to DN-06, :137, :140, :154 DI-03, :182 DI-31, :338 Seam 3.
  - Parameter lines behind SC-06's `SP-*` rows: :293, :308-318, :321-323, :328.
- **TH-16:** :121-128 RM-01 to RM-08, :286 RP-24.
- **HF-06a:** :22, :42, :46, :54, :55, :67, :71, :72, :89, :98, :100, :130 N-057.
- **HF-06b:** :116 F-06, including its "immutable-by-id" rationale; :117 F-07; :145 N-027 `json-projection`.
- **HF-07a:** :159-165.
- **HF-05:** :18, :22, :50, :51, :64, :81-91, :97, :105-117.
- **HF-09:** :121 P13, :122 P14.
- **HF-04a:** :24, scoped to `EncounterRandomState`.
- **Hashes:** all 17 stated hashes equal `coordinator-candidate-A2/paper-check/source-manifest.json:3-20`. That match rests on the receipt.

## Walks
- **AM** (missing reference): E02 → E03 → E12 → E07 matches HF-05:81, :82, :91 and :86. All eleven `ContentReferenceFailure` fields are present (HF-05:105-115).
- **AV** (valid record): the first-catalogue path runs E02, E03, E04, E16, E05 and E06 (HF-05:81-85, :95), with no admitted handle before E05 (:64, :97).
- **AI** (invalid record): E08 at HF-05:87, failing on structural rules SA-04 and SA-09.
- **AX** (illustrative record): E09 at HF-05:88.

All correct.

## Commands (coordinator receipts, level 4 only as coordinator evidence; I ran none)
From `coordinator-candidate-A2/exits.txt:1-6`, each exited 0:
- `check:scope`: documentation-only, one path (`check-scope.log:2`).
- `check:docs`.
- `check:project`.
- `check:drift`.
- `node scripts/check-drift.mjs --sections docs/tech/schemas`: 2 sections, 17 hashes, 0 mismatches, 0 unbound (`check-drift-schemas.log:2`).
- The paper check.

## Model, effort and writes
- **Model:** the runtime system prompt says Opus 5 (`claude-opus-5[1m]`), matching Andrew's routing at EV-0367. I cannot verify that by self-description.
- **`CLAUDE_EFFORT`:** unavailable; I have no environment or shell access.
- **Writes:** none. No file written, edited or committed, and no board update.

Files reviewed:
- /home/andrew/Projects/scrapkeep-wt-SC-06/docs/tech/schemas/SC-06.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-08-inventory-equipment-and-transformations.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-10-devices-and-one-main-companion.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/HF-06a-schema-inventory.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/HF-05-content-admission.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-06/coordinator-candidate-A2/check_contract.py