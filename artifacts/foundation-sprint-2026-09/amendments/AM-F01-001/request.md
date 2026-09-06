# HF-01 coverage and scaffold wording amendment

## Request identity and context

Request ID: pending coordinator assignment. Revision 1, 2026-09-06. Requester: HF-01-A1, lease HF-01-L1, Conventions writer, gpt-6-astra at high effort as dispatched. Receiver and proposed decision owner: coordinator. Program: bounded foundation HF-01/HF-02 documentation authorization recorded at coordinator commit 0e4d202. Request state: proposed. Admission state: pending.

Source base: 3ab3477bc8731f157e9cdff31598251e20acef98. Worktree: /home/andrew/Projects/scrapkeep-wt-HF-01, branch wt/HF-01. No tracked changes or candidate at submission. This request is disposable evidence within the existing lease.

Affected work: HF-01 revision 2 path-table and engine-layout acceptance drafting is stopped. The lease remains held. Unaffected source inspection and drafting of contribution rules may continue. HF-03a, HF-05 and other consumers remain governed by their existing HF-01 dependency; no new dispatch or completed-task reopening is proposed.

## Conflicting clauses and observation

At base 3ab3477, BACKLOG.md HF-01 DoD 1 requires that no production table row overlap `artifacts/`; verification requires that "every S0-01 file falls inside exactly one row." S0-01's Files touched includes `artifacts/local/tasks/S0-01/` and DoD 5 requires the runner to emit `artifacts/local/native-smoke/report.json`. Artifact ownership cannot satisfy both clauses.

HF-01 DoD 5 also requires every engine-layout fact to carry "unverified until a scaffold proof exists", immediately identifies S0-01 as that proof, and elsewhere asks for re-verification when it lands. S0-01 already landed. Its boot establishes the root at a recorded version, while cache/import/export evidence differs and must be assessed individually. Keeping the phrase as every fact's current status would misstate existing evidence.

Observed with `git diff 7aaea69^1 7aaea69 --name-only`, accepted S0-01 merge 7aaea699582c188eb2b1e3723bbb946e4b2c8f37 has nine files: `.gitignore`, `CONTRIBUTING.md`, `docs/tech/native-toolchain.md`, `native/README.md`, `native/project.godot`, `native/tests/fixtures/untyped_negative.gd`, `native/tests/smoke_boot.gd`, `package.json`, `scripts/native-smoke.mjs`. Its ignored evidence is absent from Git by design. Current `native/export_presets.cfg` and integration files are later S0 work, not S0-01 evidence. Method: source/history inspection only; no engine invocation.

## Classification and proposed change

Proposed classification: factual documentation acceptance defect, preserving accepted architecture and product direction. Change only HF-01 card to revision 3 and its following clauses.

Replace DoD 1 final sentence with: "Reconcile against the admitted S0-01 scaffold and record the checked revision."

Replace DoD 3 final sentence with: "Reconcile those families against the admitted S0-01 scaffold without moving existing files."

Replace DoD 5 with: "For each engine-layout fact (project root, cache and import sidecar locations, export presets), record its evidence status and exact source/proof identity. Use 'unverified until a scaffold proof exists' for a layout claim lacking an applicable proof. Reconcile the admitted S0-01 evidence and later admitted Sprint 0 evidence separately; a boot proof does not prove every import or export detail."

Replace verification's final bullet with: "Check the table has all five columns and every S0-01 native implementation file falls inside exactly one row. Separately account for every admitted S0-01 support/configuration/documentation file and its required disposable evidence destinations, naming existing ownership without granting production path ownership. No production row may overlap the protected browser, tooling or artifact paths in DoD 1."

Dependencies remain unchanged. No other card or ADR wording changes are required; their existing input dependency is HF-01's admitted output. Coordinator must propagate the revision and packet acceptance before affected drafting resumes.

Alternatives: leave unchanged, which makes evidence coverage contradictory and marks observed facts unverified; reject. Allow production rows inside artifacts, which weakens preserved evidence ownership; reject. Treat all non-native S0-01 files as production paths, which unnecessarily broadens production ownership and still conflicts with artifacts; reject. The proposal keeps production allocation and historical support accounting distinct.

Compatibility: accepted engine/language/content decisions, browser entry behavior/data, native proof code, save formats and retained evidence remain unchanged because only acceptance wording changes. No migration or runtime rollback is needed. Re-verify docs/project structure and independently review the revised acceptance; HF-01's focused coverage check must separately enumerate both sets. No lease enlargement, build, export, CI, publication or new implementation authority follows.

## Decision record

Pending coordinator classification, independent review and ruling. No accepted scope, board event or prior decision exists in this writer packet.

## Admission and propagation receipt

Pending coordinator source/card commit, review receipt, checks and TRACKING readiness/lease update. Acceptance alone does not permit affected drafting to resume.

## Closure disposition

Pending. Retain this proposed request and later coordinator disposition in the sprint closure record. A deferred or accepted-but-unapplied applicable amendment remains blocking.
