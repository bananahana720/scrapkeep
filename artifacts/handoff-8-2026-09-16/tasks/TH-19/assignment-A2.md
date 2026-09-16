# TH-19 assignment A2 (changes requested)

GOAL: Revise TH-19 revision 2 so its repair and synthetic import proof can actually run against the runner at the base, and correct the review notes below, leaving every other passed item intact.

SCOPE: /home/andrew/Projects/scrapkeep-wt-TH-19, branch wt/TH-19, building on your A1 candidate d5c158a25025d3d44b0f8516a5ad532fa22c4b47 (base bb97c4111d1e7b2dd40cae575eccde17878b07c5). Exclusive lease TH-19-L2, attempt TH-19-A2, the second of at most three attempts. Permitted files unchanged: docs/tech/sections/TH-19-asset-import-export.md; artifacts/local/tasks/TH-19/ (ignored, receipts), including your paper check.

CONTEXT: Independent review R1 (scrapkeep-reviewer-medium, claude-opus-5 high) returned FAIL on definition-of-done item 3 with one blocking finding and ten notes; the review is at artifacts/handoff-8-2026-09-16/tasks/TH-19/review-R1.md in the main checkout /home/andrew/Projects/scrapkeep. The coordinator confirmed B1 against the base: package.json line 25 defines `native:smoke` as `node scripts/native-smoke.mjs` with no `--export`; scripts/native-smoke.mjs line 97 runs proofs as `--headless --path <copy> --script`; the only `--import` invocation is inside `exportSmoke` (lines 597 to 604), reached only with `--export` (lines 714 to 716). Items 1 and 2, the ownership classes, the HR reconciliation quotes and the gate-first walks passed and must not regress. Engine facts come only from retrieved receipts: use Context7 (`npx -y ctx7@latest docs /websites/godotengine_en_4_7 "<one-topic query>"`, for example "command line --import flag editor import headless" or "command line --script run without import"), at most three queries per question, saved with retrieval time under artifacts/local/tasks/TH-19/; a fact not retrieved is a recorded limit.

REQUIRED CHANGES:
1. B1 (blocking). Amend RR-02 to RR-05 so the specified runner repair is sufficient for IQ-02 to IQ-06, or move the actions the runner cannot perform into the proof card with a named mechanism and stop attributing them to the runner. Whichever you choose, the contract must name: an import of the staged copy before proof discovery in the mode RR-05 names (or RR-05 must name the mode that imports); how IQ-03 deletes the cache and reimports; how IQ-04 runs the variant sidecar; and how IQ-05 runs the proof inside the exported process given the export's main scene is integration/smoke.tscn (native/README.md line 17). Update RR-04's "change nothing else" and AQ-02 to match. Every named runner step cites the exact base lines it changes or adds after.
2. Note 1. Reorder W3 so the import runs before E02 takes the entry to `imported`, matching HF-05 line 69 and W1's order.
3. Note 2. W1.14's HF-05 edge column names E06 for `retain_revision`.
4. Note 3. State RR-01's side effect on the networking scan's `repositoryFiles` input (smoke.mjs lines 162 to 184, 225 to 229) and on `sourceDirty` (line 718).
5. Note 4. PV-03 claims no more than its sources: say the cache is rebuildable, not byte-identical, unless a retrieved source states otherwise.
6. Note 5. HR-01's rationale covers the `.gd` and `.json` files the tree actually holds, or narrows its claim to what the receipts show.
7. Note 6. AG-02 applies PF-14 only to companion artefacts (PD-01 line 115).
8. Note 7. The HF-05 edge range reads from line 80 (E01), not 78.
9. Paper check. Replace the W3 and N8 string-presence checks with a step-order assertion against the gate; add an assertion that every walk step whose interface implies an HF-05 transition names that edge (the check that would have caught note 2); add an assertion that each RR or IQ step naming a runner action cites a runner line that exists at the base or is explicitly stated as an added step. Keep at least three negative controls, including one that removes the pre-proof import step.

VERIFY: In the worktree: npm run check:scope -- bb97c4111d1e7b2dd40cae575eccde17878b07c5 <candidate> --no-build; npm run check:docs; npm run check:project; npm run check:drift (no line for your file); your revised paper check with --out under artifacts/local/tasks/TH-19/. Record exit codes and counts. The coordinator reruns everything and a fresh reviewer reads the revision.

TIMEBOX: Checkpoint at handoff. Target 40 minutes; reassess from evidence.

FORBIDDEN: As A1: no edits outside the permitted files; no repair of .gitignore, the smoke script or the runner; no import, export, asset or Godot project change; no answer to Q-E06; no builds, no native or browser execution, no push, no rebase, no touching main. If B1 cannot be resolved without an architecture choice that belongs to Andrew or an ADR, stop and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/TH-19/.

REPORT: Commit only the permitted file on your branch and leave the tracked worktree clean. Report the new candidate SHA, changed paths, the section sha256, each required change item by item with line references, commands with exit codes, paper-check counts, CLAUDE_EFFORT, deviations, and state explicitly that you have stopped.
