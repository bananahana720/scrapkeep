# TH-19 review R2

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**TH-19 review R2: candidate 13bdea3d23510751384b0ee170042291177df8b1 (attempt TH-19-A2), base bb97c41**

## Verdict: PASS+NOTES

B1 is resolved. The repair rows now include an import of the staged copy before proofs run in both runner modes, a cache delete and reimport, and a run inside the exported binary. Each step is anchored to a base line whose text matches. The exported-binary run and its fallback are gates, not assumptions. The new Godot facts contradict no row. None of the notes below breaks the definition of done.

**Evidence level:**
- **Level 3 (walked step by step):** B1 against `scripts/native-smoke.mjs`, the W3 walk, and whether RR-06 fails if the exported binary ignores `--script`.
- **Level 2 (pointed at file:line):** citations.
- **Not reached by me:** level 4. I had only Read, Grep and Glob. Every hash, drift, scope, docs and paper-check result below rests on coordinator receipts and is labelled that way.

## Is B1 resolved?
Yes. Walked against the base runner:
- **RR-04 (candidate line 207): the pre-proof import.**
  - It adds a step after line 751, "in both modes", so it also runs under `npm run native:smoke`. At the base that command is `node scripts/native-smoke.mjs` with no `--export` (package.json:25).
  - It reuses the import arguments of lines 598–604 and the failure rule of 605–610. That step is already used in export mode.
  - It runs the proof loop (752–753) only if the import passed.
  - Base line 751 is `];`, which matches the anchor text.
- **RR-05 (208): the cache rebuild.** It adds a step after line 753. Line 753 is the loop's only statement, so the new step comes after the loop. It removes the copy's `.godot/imported/`, imports again and reruns the proof plainly. That is IQ-03's mechanism.
  - Retrieved support: the Godot import-process receipt, lines 104–106, says erasing the folder triggers reimport.
- **IQ-04 (227): the variant sidecar.** Both fixtures import together in RR-04, and the digests come from `files` once RR-02 is applied.
- **RR-06 (209) and IQ-05 (228): the exported run.**
  - RR-06 adds a step after line 688 (`);`, the end of the Linux export's integrated pair). Lines 681–688 sit inside the block that runs only for a passing Linux export.
  - If the exported binary ignores `--script`, the main scene starts in the default `--stage` mode without `--auto-exit` and keeps running (native/README.md:68, 71). The runner then kills it at the 60 s timeout with SIGKILL (native-smoke.mjs:54–55), and `executionFailures` flags the signal (433). So the check fails rather than falsely passing, which is what IQ-05 claims.
  - The fallback, a user argument that makes `integration/smoke.tscn` call the proof, is assigned to its own Verification card. IG-04 stays absent until then.
- **RR-07 and AQ-02 were updated** (210, 272).
- **RR-09 (212)** puts a failing receipt before the passing one.

**New Godot 4.7 facts** (`engine-facts/command-line-excerpt.md`: lines 15–16 for `--import`, 21–25 for `--export-debug` and `--export-pack`):
- `--import` "implies --editor and --quit". That matches the runner's `--editor --import`, which RR-04 and RR-05 reuse.
- No row assumes `--export-release` imports.
- AQ-19 (289) and IQ-05 treat template `--script` support as unknown and gated.
- Candidate line 216 and AQ-20 (290) say `--import` behaviour was not retrieved, with RR-09's first run as the first observation. That is now partly answerable (note 1). It is not a contradiction.

## Per definition-of-done item
1. **Provenance, import settings, generated output, references, export manifest: met.** PV-01–07 (68–74), IS-01–09 (80–88), SI-01–06 (94–99), GO-01–06 (105–110), AR-01–08 (116–123), EM-01–08 (129–136). Level 2–3.
2. **Concept images separated from admission, notices kept under Q-E06: met.**
   - CI-01–06 (142–147) and the AG table's "Never satisfied by" column (167–175).
   - NO-01–07 (153–159) answer nothing; Q-E06 is still open at BACKLOG.md:2682–2694.
   - N-041, N-048, N-054 and N-055 match HF-06a:114, 121, 127, 128 and 153.
   - Level 2.
3. **Reconciliation, repair and proof, ownership classes: met.**
   - OC-03 and OC-05 (53, 55, 62) have opposite tracking and retention.
   - HR-Q1 to HR-Q5 (183–187) match `.gitignore`:19–20 and native-smoke.mjs:147, 148 and 742 exactly.
   - The repair and proof are sufficient, as above. Gates IG-01 to IG-07 (240–246).
   - Level 3.

**Verification bullets:**
- **W1 (312–327)** ends at an exported reference. W1.14 now names E06 (HF-05:85).
- **W2 (339–345)** rejects on E15 (HF-05:94) with `ContentAdmissionFailure` (HF-05:117).
- **W3, walked step by step:**
  - W3.0: the gate rejects.
  - W3.1: E01, draft to draft.
  - W3.2: a clean checkout, after RR-01.
  - W3.3: the cache rebuilds, still E01.
  - W3.4: E02, draft to imported. Imported now follows the cache step, which fits HF-05:69 ("import dependencies are available").
  - W3.5 to W3.7: E03, E04, E05 (HF-05:82–84).
  - W3.8: E07 (HF-05:86); the HF-09 outcomes P1, P3, P9 and P11 match HF-09:109, 111, 117 and 119.
- Readiness is rejected with the gate step first in all three walks.

**R1 notes 1–9:** all addressed.
- W3 reordered (360–361). W1.14 edge set (326). RR-08 side effects stated (211). PV-03 (70). HR-01 (191).
- The HR-01 file counts (16 .gd, 6 .json, 3 .tres, and so on, 32 files) match my Glob of `native/**`. Glob cannot tell tracked from untracked files.
- AG-02 (168) matches PF-14's scope at PD-01:115. The HF-05 edge range now reads from line 80.
- The `git log -S` history claim is backed by the writer's receipt `a2-tree-and-history.txt` (lines 4–9).
- The paper-check changes are present (see the last note).
- Items 1 and 2 did not regress.

**Packet bans:** respected.
- [coordinator receipt] `identity.txt` shows one added file and a clean status.
- [coordinator receipt] `check-scope.log` classifies the change as documentation-only.
- The concurrent cards are named without their bytes cited (29, 292–300).

## Blocking findings
None.

## Non-blocking notes
1. **AQ-20 is partly answerable now.** The coordinator's excerpt, lines 15–16, states what `--import` does. Sources line 14, line 216, AQ-20 and Evidence limits line 403 still say no retrieved text states it. Fix: cite the excerpt and narrow AQ-20 to whether a `--script` run imports.
2. **RR-07 miscounts imports (line 210).** It says export mode "imports the copy twice". RR-05's reimport also runs in both modes, so export mode imports three times: RR-04, RR-05 and line 598.
3. **Some runner changes lack their own anchor.**
   - RR-04 gates the loop at lines 752–753, which changes the loop header. AQ-02 (272) lists only lines 148 and 742 as changed.
   - RR-05's directory removal may need `rm`, which the imports at lines 4–14 don't include. Invoking `rm` through the existing `run` helper would avoid that.
   - The line numbers themselves are cited in the rows.
4. **IQ-04's fixture may be unbuildable as written (220, 227).** "Differs only in that parameter" is probably impossible: Godot sidecars normally also carry path-specific `source_file`, `dest_files` and `uid` values. That is inference from engine knowledge, not retrieved. IQ-04's pass condition doesn't depend on it; reword it to "differs in that parameter".
5. **IQ-03's "hashes unchanged" is weak (226).** `source-preservation` hashes the source tree (767–769), which the copy's import never touches. It doesn't show that the copy's sidecar survived reimport unchanged.
6. **W3 mixes callers on one candidate.** W3.4 moves candidate B to `imported` through the Tooling editor validators (AI-02, no edge). W3.5 to W3.8 continue on D03 as Session. W1 keeps editor validation (W1.6–8) separate from a fresh exported-process candidate (W1.10–13).
7. **What the paper check does not test** (read at `coordinator-candidate-A2/check_import_export.py`).
   - What it now tests for real:
     - W3's step order, through row swaps (199–206; control N8 at 386).
     - That walk steps name the HF-05 edge their interface implies (209–227; control N10).
     - Runner anchors against `git show` of the base (229–248; controls N9 and N11).
   - What it does not test:
     - Whether RR-04 applies in proof mode, and whether RR-05 and RR-06 are sufficient. The pre-proof import test is a string search plus an anchor below line 752 (250–252).
     - The IQ-05 fallback and gate wording, or the AQ-19 and AQ-20 links.
     - The content of W3's checkout and cache steps; only the stage labels are checked.
     - Runner line citations in the Sources prose and IQ-07, beyond a line count (262–265).
     - The HF-07a CSV field rule, and whether cited rows say what the section claims.
   - The hash check reads worktree bytes, not base blobs (346–347). That is equivalent here only because the diff adds one file [coordinator receipt].
8. **Model routing.** AGENTS.md pins consequential review to Fable 5.1 medium. This review ran on Opus 5, per the packet's EV-0367 routing. Recording that is the coordinator's call.

## Citations sampled (all matched)
- **Runner and package:**
  - native-smoke.mjs lines 54–55, 96–98, 142–151, 162–184, 225–229, 297–333, 414, 597–612, 659–666, 681–688, 712–718, 739–753, 765–777, 782, 785 and 809.
  - package.json:25.
- **`.gitignore`:** 7, 19, 20.
- **native/README.md:** 17, 42, 51, 57–78, 90.
- **HF-05:** 18, 23–25, 29, 35, 49, 64, 69, 80–95 (E06 at 85, E15 at 94), 97, 117, 123.
- **HF-01:** 21, 30–36, 47, 50, 53, 60–62, 68, 70, 72, 74, 85, 102, 104.
- **Other sections:**
  - HF-03a: 34, 37, 48.
  - HF-03b: 29, 32, 53, 68, 93.
  - HF-04a: 24, 44, 48, 50, 51. No randomness claim in the candidate.
  - HF-07a: 60, 62, 79. A case-insensitive grep of the CSV for asset, import, digest, manifest and catalogue_revision found nothing.
  - HF-09: 38, 85, 86, 95, 97, 109, 111, 117, 119, 120.
  - TH-16: RD-07:99, RE-02:108, RE-04:110, RE-05:111, RM-02:122, RM-07:127.
  - PD-01: PF-05 to PF-15 at 106–116.
  - HF-06a: 114, 121, 127, 128, 153.
- **ADR, assets, Bible, backlog:**
  - TADR-003: 25, 27, 29, 31, 35, 47.
  - ASSETS.md: 9, 15, 17, 19.
  - BIBLE: 493, 584, 602, 610.
  - BACKLOG Q-E06: 2682–2694.
- **Writer receipts:**
  - Godot import-process text: 86–108.
  - ctx7 query 5: lines 36–50, 52–56.
  - ctx7 query 9: line 68.
  - `a2-tree-and-history.txt`: 1–9.
- **Identity:** `.git/refs/heads/wt/TH-19` = 13bdea3d…df8b1.
- **Section count claims (line 35):** all ten counts match the tables.
- **SHA256 hashes:** not computed by me.
  - [coordinator receipt] `check-drift.log`: 313 stated hashes, 0 mismatches, 0 unbound.
  - [coordinator receipt] `paper-check.log:21`: 21 source hashes match.
  - [coordinator receipt] Candidate sha256 `8354d271…07f05`.

## Commands
I ran none; I had no shell. Coordinator receipts I read but did not rerun (`coordinator-candidate-A2/exits.txt`):
- `check:scope`, `check:docs`, `check:project`, `check:drift` and the paper check each exited 0.
- The paper check reports 21/21 positive checks, and 11/11 negative controls failing as required (`paper-check.log:33`).

## Runtime
- **Model:** Opus 5 (`claude-opus-5[1m]`), per the host system prompt; I can't verify it myself.
- **CLAUDE_EFFORT:** unavailable. The host did not expose it and I have no shell.

## Write confirmation
I wrote, edited and committed nothing.

Files:
- `/home/andrew/Projects/scrapkeep-wt-TH-19/docs/tech/sections/TH-19-asset-import-export.md`
- `/home/andrew/Projects/scrapkeep/scripts/native-smoke.mjs`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/TH-19/coordinator-candidate-A2/`
- `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/TH-19/engine-facts/command-line-excerpt.md`