# SC-06 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**SC-06 R1 review: FAIL. Candidate `26afe716686622e6ba9df530f7781be6462a47ce`, card revision 1**

Evidence level: 3. I read the admitted sources and walked scenarios AM, AI, AX and AS gate by gate. Hashes and check exits are level 4 only through the coordinator's receipts. I had no shell in this session, so I reran nothing.

Identity: `.git/worktrees/scrapkeep-wt-SC-06/HEAD` points to `refs/heads/wt/SC-06`, and that ref holds `26afe716…`. The claims of a clean worktree and a one-file diff (`A docs/tech/schemas/SC-06.md`) come from the receipt `coordinator-candidate/identity.txt`, not from anything I observed.

## Definition of done
1. **Scope, rows and foreign definitions: met.** See `SC-06.md:29-50` and `:327-339`. HF-06a gives SC-06 exactly F-06, F-07 and N-027 (`HF-06a-schema-inventory.md:145`). I checked the row allocation against the rationale text:
   - F-06 names "Device" (`:71`).
   - F-07 names "chassis, component and command-capability" (`:72`).
   - N-027 names "Device (F-06) and companion-part (F-07)" (`:100`).
   - HF-06a line 22 permits a family row and a noun row on one type.
   - No type lacks a row. Level 3.
2. **Fields, types, identity and version, references, diagnostics and an illustrative record per type: partly met.** All four types have every part (`:108-325`). One shared rule breaks an admitted section (B1).
3. **Save projection, round trips and executable obligations: met.** See `:341-409`.
   - Every HF-07a path is at `HF-07a-save-envelope.md:159-165`.
   - HF-06b rows `:116`, `:117` and `:145` are `json-projection`. Groups are at `:62-63`.
   - The HF-06b F-06 CSV rationale says the device definition itself is `immutable-by-id`.
   - Obligations QO-01 to QO-07 are owned by TH-22. Level 3.
4. **Symbolic values, no canon: met.**
   - Parameters SP-06 to SP-19 are `unset` with question IDs (`:422-435`).
   - SP-01, SP-04 and SP-05 cite sources (SP-04 is HF-06a `:55`; SP-05 is Bible `:570`).
   - All four records and the projection are labelled "Illustrative, not canon."
   - The Q-P15 field names proposed at EV-0144 (`recall_policy`, `resource_policy`, TRACKING `:358`) are not used.

## Blocking finding
**B1. `SC-06.md:65` (rule SR-10) and `:443` (Seam 2) change TH-08's compatibility interface while claiming to consume it unchanged.**
- **What SR-10 does:** it adds a condition on the target side. A device's or companion part's `compatibility_action_ids` "can only narrow" eligibility.
- **What TH-08 fixes:**
  - EC-01: a query has exactly three inputs (effect source, target class, action or attribute) (`TH-08…md:77`).
  - EC-03: eligibility comes from the effect source's declaration (`:79`).
  - EC-04: the check is evaluated at the rebuild (`:80`).
  - EQ-03: the rebuild's inputs exclude the companion assembly (`:58`).
  - EP-31: whether a support takes part in the rebuild is still an open question (`:293`).
- **Why it cannot be evaluated consistently:** TH-10 DE-04 says an effect row never names the device or companion (`TH-10…md:94`). Nothing stops two devices, or two parts, from referencing the same F-02 attack with different compatibility sets (SA-10 only checks each record against itself). In that case the narrowed result is not a function of TH-08's three inputs. Applying it per instance would mean evaluating outside the rebuild, which EC-04 and DE-05 (`TH-10:95`) exclude.
- **Violated rule:** TH-08 line 394 says a change that alters these interfaces "is a finding against this section, not a local exception". The packet treats a contradiction with an admitted row as blocking.
- **Fix, either of:**
  - (a) Make these declarations admission-time constraints only, which EC-04's "satisfy the authored constraints" allows. They then change no query outcome, and Seam 2 stays true.
  - (b) Drop the narrowing meaning. State it as an undecided seam against TH-08 EC-01 and EP-31 under Q-P15, and route it as a finding against TH-08.

## Non-blocking notes (fix in the same revision)
- **N1. TH-16 citations are off by one.** RM-01 is `TH-16:121` (line 120 is a table separator), RM-02 is `:122`, RM-07 is `:127` and RM-08 is `:128`. The wrong numbers appear at:
  - `SC-06.md:22`, the Sources entry.
  - `:66` (SR-11 cites 120, 121, 127).
  - `:337` (cites 120 and 121).
  - `:352` ("no field", which is RM-08 at line 128).
  The rules themselves are stated correctly.
- **N2. `SC-06.md:289` cites TH-10 line 77 for `ActionRequest`.** Line 77 is rule DO-06; `ActionRequest` appears in DO-09 at `TH-10:80`.
- **N3. The valid-record walk (AV) never says whether catalogue A is the first catalogue or a replacement.** Its step AV.4 (`:466`) says "Session is still inside an encounter". For a first catalogue that is impossible: HF-05 lines 64 and 97 say gameplay cannot start without an admitted handle.
- **N4. Rule SA-08 (`:94`) applies this card's ID grammar (SR-03) to F-02 attack IDs.** HF-05 line 18 gives SC-02 its own grammar, so this is an unstated seam with SC-02.
- **N5. `availability_rule` sits only on the chassis (T2), and `assembly_rule` is the single fit model (`:182-185`).** Both are structural choices no admitted row states, and both narrow Q-P15's possible answers. They are symbolic, so a later answer would force a contract revision (VR-07).
- **N6. Seam 5 is a known follow-up.** Row N-013 (`HF-06a:86`) mentions "SC-07 visual references on … F-06 definitions" but no row types them, and the closed field list (SR-04 with SA-04) would refuse such a field. The candidate states this at `:337` and `:449`, and TH-16 RM-01 supports its no-field reading.
- **AM-H8-003 (Seam 3):** no device or companion reference silently depends on it. Every outbound action reference rests on admitted text: HF-06a `:67`, `:71` and `:100` all say attacks are referenced by ID. The deploying ability is listed as an inbound reference under N-021 (`:334`), and Seam 3 (`:445`) states the dependency without choosing.

## Paper-check coverage
The receipt reports 385 passed, 0 failed, and 8 of 8 negative controls failing as intended. The checker does not test:
- The meaning of SR-10 against TH-08, so it missed B1.
- Whether a cited line says what is claimed; it checks hashes only, so it missed N1 and N2.
- A real round trip. `json.loads(json.dumps(record))` on a dict parsed from the Markdown always passes for strings, lists and ints.
- Whether each diagnostics table pairs a rule with its own gate's failure edge; it only checks the edges exist in HF-05.
- Whether the rule named at a failing walk step belongs to that step's gate.
- Whether the nouns that drive row allocation denote the right types. The nouns come from the candidate's own table, and only one mutation (NC2) tests them.
- Whether a sourced parameter's source actually states its value; it only matches the pattern "line N".
- EV-0144 proposal names beyond `recall_policy` and `resource_policy`.

## Citations sampled
I checked 15; 13 hold and 2 are wrong.
- **Correct:**
  - HF-06a `:22`, `:46`, `:55`, `:67`, `:71`, `:72`, `:89`, `:100`.
  - HF-05 `:18`, `:22-25`, `:50-51`, `:58`, `:81-95`, `:105-117`.
  - HF-07a `:37`, `:46`, `:56`, `:159-165`, `:223`, `:252-253`.
  - HF-06b `:25`, `:27`, `:31-36`, `:62-63`; F-06 CSV "immutable-by-id".
  - HF-09 `:75`, `:85`, `:98-99`, `:121-122`, `:126-130`, `:175-176`, `:195`.
  - HF-04a `:24`.
  - Bible `:566-574`.
  - TADR-003 `:23-35`, `:45`.
  - TH-10 `:66`, `:75`, `:123-125`, `:137`, `:154`, `:182`, `:293`, `:308-328`, `:338`, `:342`.
  - TH-08 `:77-80`, `:293`.
  - TH-04 `:44`, `:114`, `:115`, `:118`, `:150`, `:295-296`; TH-03 `:172`; TH-16 `:286`.
  - HF-07b `:38`, `:76`, `:101`; HF-03a `:45-48`; HF-01 `:28`.
- **Wrong:** TH-16 RM line numbers (N1) and TH-10 line 77 (N2).
- **Hashes:** all 17 stated hashes equal `coordinator-candidate/paper-check/source-manifest.json`. That rests on the receipt.

## Walks
- **AM** (missing reference): steps E02, E03 and E12 match `HF-05:81`, `:82` and `:91`. All eleven `ContentReferenceFailure` fields are present. AM.4 (E07) matches `:86`. Correct.
- **AI** (invalid record): E08 at `HF-05:87`; findings for SA-04 and SA-09 match line 50's report-as-a-unit rule. Correct.
- **AX** (illustrative record): the T2 record passes the structural gate. Its semantic step (E09, `:88`) fails on SM-03 at three fields and SM-01 at `action_ids[0]`. Correct.
- **AS** (wrong-family save): schema axis `current`, content axis `pinned`, catalogue axis `wrong-family` maps to row P14, and the three reject consequences apply (`HF-09:126-130`). Correct.

## Commands and coordinator receipts
I ran no commands; I used only Read, Grep and Glob. From `coordinator-candidate/exits.txt` and the logs I read, each at level 4 as coordinator evidence:
- `check:scope --no-build` exited 0: documentation-only, one path.
- `check:docs` exited 0 with 0 failures.
- `check:project` exited 0.
- `npm run check:drift` exited 0. It scans only `docs/tech/sections` and `docs/product/sections`, so it does not cover this file.
- `node scripts/check-drift.mjs --sections docs/tech/schemas` exited 0: 2 sections, 17 hashes, 0 mismatches, 0 unbound.
- The paper check exited 0.
- The candidate's SHA256 is `7dd7ed463f24c2b0074e26ef564a9331d2f6d88a9d57b6dca99c2c1ea0bd07a9`.

## Model, effort and writes
- **Model:** the runtime system prompt says Opus 5 (`claude-opus-5[1m]`), which matches Andrew's routing of per-card review to Opus 5 high at EV-0367. I can't confirm my identity from self-description.
- **`CLAUDE_EFFORT`:** unavailable; I have no environment access.
- **Writes:** none. No files written, edited or committed; no board update.

Files reviewed:
- /home/andrew/Projects/scrapkeep-wt-SC-06/docs/tech/schemas/SC-06.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-08-inventory-equipment-and-transformations.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-10-devices-and-one-main-companion.md
- /home/andrew/Projects/scrapkeep/docs/tech/sections/TH-16-rendering-integration.md
- /home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/SC-06/coordinator-candidate/