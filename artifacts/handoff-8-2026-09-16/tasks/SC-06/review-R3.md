# SC-06 review R3

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-06 review R3: PASS+NOTES on candidate `b53767236ed908a5851d6ee43c681dbf8241be3f` (attempt SC-06-A3, card revision 1). Evidence level 3.** I walked the scenarios gate by gate and checked citations line by line. Every exit code, count and hash check below comes from the coordinator's receipts. I had only Read, Grep and Glob, so I ran nothing myself.

**Identity.** I checked this myself: `.git/worktrees/scrapkeep-wt-SC-06/HEAD:1` points to `refs/heads/wt/SC-06`, and `.git/refs/heads/wt/SC-06:1` holds `b5376723…`. These come from receipts: a clean tree, one changed path (`docs/tech/schemas/SC-06.md`), parent `d71b6f14…` (`coordinator-candidate-A3/identity.txt:2-8`) and file SHA256 `1de0f0e3…` (`candidate-sha256.txt:1`). I read `assignment-A3.md` because the packet names it as the change request.

## B2: resolved
- **SM-07 is gone.** The admission table (`SC-06.md:89-108`) now holds SA-01 to SA-10, SM-01 to SM-06 and SX-01 to SX-02, which is the "eighteen admission rules" at `:545`. The only "SM-07" matches left are in the attempt history at `:547` and `:551`. None of the four diagnostics tables (`:147-154`, `:206-212`, `:259-265`, `:310-316`) has an SM-07 row.
- **The compatibility fields are checked only on the record's own fields.**
  - SR-10 (`:67`) names only SA-10, SM-01, SM-02 and SM-05.
  - The option (a) paragraph (`:87`) says "No rule here checks a record outside the four types".
  - The inbound paragraphs (`:143`, `:202`, `:255`, `:306`) say foreign references are validated on the foreign side and "this contract adds no check on them". That matches TH-10 DE-10 (`TH-10:100`) and TH-08 (`:73`: "fixes no eligibility, which is Q-P14's and SC-03's").
- **Seam 4 (`:451`) leaves the rule to SC-03 and Q-P14.** It marks containment as undecided under Q-P14, and the foreign-reference rows at `:336-337` agree.
- **R2-N2 is fixed** at `:87`, in line with HF-06a:89. **R2-N3 is fixed** at `:506`: AX.3 now lists SM-04.
- **R1's B1 has not regressed.** SR-10 keeps TH-08 EC-01 (`TH-08:77`), EC-03 (`:79`) and EQ-03 (`:58`), and Seam 2 (`:447`) leaves EP-31 (`TH-08:293`) open.
- **R1's notes N1 to N5 are still fixed.**
  - N1: the TH-16 RM lines at `:22`, `:68`, `:341` and `:356` match `TH-16:121-128`.
  - N2: `:293` cites DO-09 at `TH-10:80`.
  - N3: AV is the first catalogue at `:463`.
  - N4: `:60` and `:98` leave F-02's ID grammar to SC-02.
  - N5: the two chassis-only choices are labelled at `:189`, `:431-432` and `:539`.
- **R2-N4 still holds:** Seam 3 (`:449`) still describes AM-H8-003 as accepted and not yet applied.

## Definition of done
1. **Scope, matrix rows and foreign definitions: met (level 3).**
   - Scope is at `:33`.
   - The row allocation at `:37-52` matches the HF-06a rationales. F-06 at `HF-06a:71` says "Device". F-07 at `:72` names chassis, component and command-capability. N-027 at `:100` says "Device (F-06) and companion-part (F-07)". `HF-06a:22` allows a family row and a noun row on one type.
   - The foreign-reference table is at `:333-343`.
2. **Fields, types, identity and version, references, diagnostics and one illustrative record per type: met (level 3).**
   - The four types are T1 (`:112-172`), T2 (`:174-227`), T3 (`:229-278`) and T4 (`:280-329`).
   - Each diagnostics row uses the right failure edges: E08/E11 for structural failures and E09/E12 for semantic ones (`HF-05:87-88`, `:90-91`).
3. **Save projection, round-trip expectations and executable obligation: met (level 2-3).**
   - The save table (`:349-354`) uses HF-07a fields that exist at `HF-07a:159-165`.
   - `json-projection` matches `HF-06b:116`, `:117` and `:145`. The F-06 CSV rationale says the definition "itself is immutable-by-id" (HF-06b CSV row 7).
   - Load rules SL-01 to SL-04 (`:360-363`) match `HF-09:121-122`.
   - Round-trip expectations RT-01 to RT-06 are at `:371-376`, and obligations QO-01 to QO-07 at `:407-413`, which meets `TADR-003:45`.
4. **Symbolic values and no canon: met (level 2).**
   - The parameter table (`:421-439`) has fourteen `unset` rows with question IDs. The five sourced rows (SP-01 to SP-05) restate their sources: `HF-06a:55`, `TH-08:77-78`, `BIBLE:570` and `TH-10:293`.
   - Every illustrative record and the projection is labelled (`:158`, `:216`, `:269`, `:320`, `:380`).
   - Symbolic values fail admission (SM-03, walk AX).

**Packet items.**
- The seven headings are at `:3`, `:29`, `:457`, `:523`, `:535`, `:541` and `:555`.
- All 17 stated hashes equal `coordinator-candidate-A3/paper-check/source-manifest.json:4-20`. That match rests on the receipt.

## Blocking findings
None.

## Non-blocking notes
- **R3-N1. SC-03's `companion_part_ids` against F-07's three families is a seam, not a contradiction.**
  - Why it is not a contradiction: admitted SC-03 says "The expected-family token for a foreign row is that producing card's, and TH-20 reconciles the tokens" (`SC-03.md:47`). It references row F-07 without fixing a token (`:56`, `:143`), and its Seam 4 (`:388`) sets no family rule.
  - Why the split is sound: `HF-06a:72` puts three kinds of definition under one row, and HF-07a keeps them in separate arrays (`:160-162`). HF-09's `wrong-family` case (`:99`) only means something for `chassis_id` if the families are split.
  - What is still open: `HF-05:22` and `:108` give each reference a single `expected_family`, and SC-03:47 says "token" in the singular. So one SC-03 field cannot validate against three tokens as written.
  - Who handles it: TH-20's second definition-of-done item (`BACKLOG.md:1771`) sends cross-family conflicts back to the owning card, which will probably mean a correction to SC-03. The coordinator should record this for TH-20.
- **R3-N2. Stale statements about SC-03.**
  - `:532` says SC-03's attunement declarations are "concurrent and unadmitted; their seams are stated by row, not by bytes". That contradicts `:26`, `:336-337` and `:451`, and `TRACKING.md:174` (SC-03 done at EV-0402).
  - `:539` still triggers a recheck "when … SC-03 … is admitted", which has already happened.
  - `:543` ("No SC sibling's bytes were read or cited") is overtaken by `:551`.
  - None of these breaks the definition of done.
- **R3-N3. Seam 4 cites the wrong HF-06a line for N-025.** `:451` cites `HF-06a:42` (the embedded-record treatment) for both N-016 and N-025, but N-025 is a `schema` row (`HF-06a:98`). It is still inside SC-03's gates, so only the citation is off.
- **R3-N4. The SC-03 digest at `:26` is not machine-checked.** No link or dependency list binds it, which the candidate admits. It matches `tasks/SC-03/coordinator-candidate/candidate-sha256.txt:1` and `TRACKING.md:608` and `:617` as a string only; I did not recompute it.

## What the paper check does and does not test
From `check_contract.py`:
- **Real checks:**
  - C03 compares row allocation against the CSV (`:272-319`).
  - C06 checks save fields against the HF-06b and HF-07a CSVs (`:408-433`).
  - C07 checks walk edges against HF-05's parsed edge table (`:441-470`).
  - There are 13 negative controls. NC13 restores SM-07 and fails C13 (log `:831`).
- **Wording or string presence only:**
  - C13 is a keyword regex (`:543-557`). A cross-card rule reworded to avoid "item", "effect source" or "SC-0x" would pass, and it lets SX-01 through by whitelisting "scene path". SX-01 is HF-05:52's scene-override check, not an eligibility rule.
  - C11 is also wording-based (`:530-540`).
  - The identity check (`:347`) only looks for "`id`" and "VR-".
- **Symmetric or trivial:** the projection round trip is `json.loads(json.dumps(x)) == x` (`:492`, `:495`).
- **Not tested at all:**
  - Whether a sourced parameter's source actually states the value (`:517` only looks for "line N").
  - Bare line citations beyond being nonblank (`:602-604`).
  - Consistency of the prose about admission state (R3-N2).
  - The SC-03 digest.

## Walk traced
**AM** (`:476-485`):
- AM.1, E02 draft to imported, matches `HF-05:81`.
- AM.2, E03 imported to structurally valid, matches `:82`. SA-08 checks shape only.
- AM.3, E12 structurally valid to rejected-reload, matches `:91`. It carries all eleven `ContentReferenceFailure` fields listed at `:105-115`, with `operation` `validate_candidate` as `:106` requires.
- AM.4, E07 pinned to pinned, matches `:86`, and no old catalogue is mutated (`:97`).

Also checked:
- AX.3 takes E09 (`:88`). SM-01 correctly fails `example.attack.gamma` because candidate E holds only T2's record.
- AI.2 takes E08 (`:87`).
- AV's E16, E05 and E06 match `:95`, `:84` and `:85`.
- AS rows match `HF-09:75`, `:85`, `:99`, `:121`, `:122` and `:126-130`.

## Citations sampled (all correct apart from R3-N3)
- **HF-06a:** :22, :42, :46, :54, :55, :67, :71, :72, :89, :98, :100.
- **HF-06b:** :116, :117, :145, and CSV row 7.
- **HF-07a:** :37, :46, :56, :60-64, :159-165, :223, :252, :253.
- **HF-05:** :18, :22-24, :27, :29, :35-39, :47-52, :80-95, :97, :105-117.
- **HF-09:** :75, :85, :98, :99, :109, :121, :122, :126-130.
- **HF-04a:** :24, scoped to `EncounterRandomState`.
- **HF-07b:** :101.
- **TH-10:** :44-49, :59-64, :66, :75, :80, :91-100, :123-128, :137, :140, :293, :308-328 (every SP row's DP line), :338, :342.
- **TH-08:** :58, :73, :77-80, :288, :292, :293.
- **TH-16:** :121-128.
- **TADR-003:** :23, :25, :27, :29, :31, :35, :45.
- **BIBLE:** :566-574.
- **SC-03:** :47, :55, :56, :142, :143, :388.
- **Hashes:** the 17 stated hashes against the receipt manifest.

## Commands (coordinator receipts; I ran none)
`coordinator-candidate-A3/exits.txt:1-6`, each exit 0:
- `check:scope` (documentation-only, 1 path, `check-scope.log:2`)
- `check:docs`
- `check:project`
- `check:drift`
- `node scripts/check-drift.mjs --sections docs/tech/schemas` (2 sections, 17 hashes, 0 mismatches, 0 unbound; `check-drift-schemas.log:1-2`)
- The paper check: 818 passed, 0 failed, 13 of 13 controls failed as intended (`paper-check.log:1`).

Merged onto main, `coordinator-view-A3/exits.txt:1-5` are all exit 0 with the same paper-check counts. Both manifests record the same file hash (`1de0f0e3…`) and checker hash (`d4b73d1b…`).

## Model, effort and writes
- **Model:** the runtime system prompt says Opus 5 (`claude-opus-5[1m]`), which matches the routing at EV-0367. Self-description cannot verify it.
- **`CLAUDE_EFFORT`:** unavailable. I have no environment or shell access.
- **Writes:** none. No file written, edited or committed, and no board update.

Files reviewed:
- /home/andrew/Projects/scrapkeep-wt-SC-06/docs/tech/schemas/SC-06.md
- /home/andrew/Projects/scrapkeep/docs/tech/schemas/SC-03.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-06/coordinator-candidate-A3/check_contract.py