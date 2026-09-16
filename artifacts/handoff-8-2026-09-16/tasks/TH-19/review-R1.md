# TH-19 review R1

Reviewer scrapkeep-reviewer-medium (claude-opus-5 high per agent definition; runtime effort not readable by the reviewer). Final report retained verbatim from the agent transcript.

**TH-19 review: candidate d5c158a25025d3d44b0f8516a5ad532fa22c4b47, base bb97c4111d1e7b2dd40cae575eccde17878b07c5**

## Verdict: FAIL

The contract is well sourced and mostly sound. It fails definition-of-done item 3 on one blocking defect: the repair it calls exact and complete cannot run the synthetic import proof it is paired with, because of how the runner works at the base.

Evidence level: level 3 (walked step by step) for the walks, the runner structure and the citations. Level 2 (pointed at file:line) for the rest. I did not reach level 4. I have no shell, so every hash, drift, scope and paper-check result below rests on coordinator receipts and is labelled that way.

## Per definition-of-done item

**Item 1: provenance, import settings, generated output, references, export manifest.** Met, as a usable contract. PV-01 to PV-07 are at candidate lines 66–74, IS-01 to IS-09 at 78–88, SI-01 to SI-06 at 92–99, GO-01 to GO-06 at 103–110, AR-01 to AR-08 at 114–123 and EM-01 to EM-08 at 127–136. Each rule traces to a source line I checked. Level 2–3.

**Item 2: concept images separated from admission, notices kept under Q-E06.** Met.
- CI-01 to CI-06 (lines 140–147) and the AG table's "Never satisfied by: OC-07 concept images" column (165–175) agree with PD-01 lines 26 and 63, and with HF-06a lines 114, 121, 127 and 128.
- NO-01 to NO-07 (151–159) record obligations and answer nothing. Q-E06 is still open at BACKLOG.md:2682–2694. Level 2.

**Item 3: reconcile the exclusions, specify the exact repair and synthetic proof, record the two ownership classes.**
- **Ownership classes: met.** OC-03 and OC-05 (lines 53, 55, 62) have opposite tracking and retention, consistent with HF-01 lines 30, 32 and 72.
- **Reconciliation: met.** HR-Q1 to HR-Q5 (183–187) quote `.gitignore` lines 19–20 and `scripts/native-smoke.mjs` lines 147, 148 and 742 exactly.
- **Repair and proof: not met.** See B1.

**Verification bullets.**
- **W1** (lines 300–323) and **W2** (325–341) are consistent on paper. W2 rejects through E15 (HF-05:94) with `ContentAdmissionFailure` (HF-05:117).
- **W3** (343–361) shows the setting surviving a clean checkout, the identity changing, and a rebuild. Its cache step, W3.4, depends on IQ-02 and IQ-03, which are defective under B1.
- Readiness is rejected with the gate step first in all three walks (lines 302/306, 327/333, 345/351).

## Blocking findings

**B1. The repair cannot run the synthetic proof (item 3; lines 204–212, 216–226).** The repair rows say they change only runner lines 148 and 742, and RR-04 says "Change nothing else". At the base, that repair cannot produce what IQ-02 to IQ-06 require:
- **Proofs run before any import.** They run at `scripts/native-smoke.mjs:752-753` as `--headless --path <copy> --script` (line 97), on a copy without `.godot`, before any editor import.
- **The only import is in export mode.** The only `--editor --import` is in `exportSmoke` (lines 597–604), which runs only with `--export` (lines 716, 765–766). `npm run native:smoke`, the command RR-05 names, is `node scripts/native-smoke.mjs` with no `--export` (package.json:25), so it never imports.
- **So IQ-02 is false against the code**, even after RR-02 and RR-03. IQ-02 says the runner "runs the editor import, and the proof loads the imported resource". RR-05's "expected to pass" rerun cannot be reached.
- **The runner has no steps for IQ-03, IQ-04 or IQ-05.** IQ-03 needs the cache deleted and imported again; IQ-04 needs a variant sidecar; IQ-05 needs the proof run inside the exported process. The export's main scene is `integration/smoke.tscn` (native/README.md:17).
- **Engine behaviour (inference, not checked):** as far as I know, a Godot 4 `--script` run does not import on its own.

Fix: amend RR-02 to RR-05 to specify the extra scoped runner change needed, then update RR-04, RR-05 and AQ-02 to match. That change is:
- import the staged copy before proof discovery, in the mode RR-05 names;
- define how the cache is deleted and imported again (IQ-03) and how the variant sidecar is run (IQ-04);
- define how the proof runs in the exported process (IQ-05).

Alternatively, move those actions into the proof card with a named mechanism, and stop attributing them to the runner.

## Non-blocking notes

1. **W3 step order.** W3.3 takes E02 into `imported` before W3.4 runs the import. That conflicts with HF-05:69, where `imported` means "import dependencies are available", and with W1's order (import at W1.4, E02 at W1.6).
2. **W1.14 edge column.** The step calls `retain_revision`, which is HF-05 E06 (admitted to pinned, HF-05:85), but its HF-05 edge column says `none`.
3. **RR-01 side effect.** Deleting `.gitignore` line 20 also changes what `repositoryFiles` feeds the networking scan (smoke.mjs:162–184, 225–229), and untracked sidecars would make `sourceDirty` true (line 718). RR-04 says the networking scan is not changed; the contract should state this effect.
4. **PV-03 is stronger than its sources.** "Regenerates the OC-02 bytes" implies a byte-identical rebuild, which PD-01 PF-06 (line 107) and HF-01:72 do not state.
5. **HR-01 rationale is incomplete.** It relies on native formats having no import options, but the tree is mostly `.gd` and `.json`, which receipt lines 36–39 do not cover. The conclusion still holds, since no sidecar is tracked (Glob of `native/**`).
6. **AG-02 over-requires.** It asks for PF-01 to PF-15, but PF-14 applies only to companion artefacts (PD-01:115).
7. **Off-by-two range.** "HF-05 lines 78 to 95 are edges E01 to E16": line 78 is the table header; E01 is at line 80.
8. **Unverified history claim.** I could not check the `git log -S` claim that lines 19 and 20 arrived together in 17033a36 (candidate line 9, 196) with read-only file tools.
9. **What the paper check does not test.**
   - W3 and control N8 are string-presence checks: N8 only deletes the phrase the positive check looks for.
   - Walk steps with edge `none` are never compared with the HF-05 transition their interface implies, which is why note 2 passed.
   - It does not check whether RR and IQ can actually run against the runner (B1).
   - It does not check whether cited rows say what the candidate claims, the HF-07a field rule, or PD-01's required-evidence rows.
   - It does test real things: HF-03a/HF-03b membership, the quoted lines via `git show`, the stated hashes, and HF-05 edge from/to states.
10. **Model routing.** AGENTS.md pins consequential review to Fable 5.1 medium; this review ran on Opus 5. The coordinator decides whether that is a substitution to record.

## Citations sampled (all matched unless noted)
- **TADR-003:** lines 25, 27, 31, 35, 47.
- **ASSETS.md:** lines 9, 15, 17, 19.
- **`.gitignore`:** lines 7, 19, 20.
- **`native-smoke.mjs`:** 142–151, 162–184, 414, 597–612, 719–720, 739–743, 767–777, 809.
- **`export_presets.cfg`:** 8, 10, 17, 18, 27, 29, 36, 37.
- **`native/README.md`:** 3, 7–13, 38, 42, 86, 90.
- **HF-01:** 21, 25, 26, 28–36, 47, 50, 53, 60–62, 68, 70, 72, 74, 78, 85, 102, 104.
- **HF-05:** 18, 23–25, 27, 29, 31, 35, 49, 52, 64, 82, 86, 90, 91, 93, 94, 97, 101–117, 123, 180. Off by two on the 78–95 range (note 7).
- **HF-03a:** 34, 37, 48.
- **HF-03b:** 29, 32, 53, 68, 93.
- **HF-04a:** 44, 48, 50, 51, 81, 112.
- **HF-06a:** 40, 48, 105, 107, 114, 116, 121, 127, 128, 153.
- **HF-07a:** 60, 62, 79, 192. A grep of the CSV for asset, import, digest, manifest and catalogue_revision found nothing.
- **HF-09:** 38, 85, 86, 95, 97, 109, 111, 117, 119, 120.
- **TH-16:** RD-07:99, RE-02:108, RE-04:110, RE-05:111, RM-01/02:121–122, RM-07:127, RI-01:168, RI-03:170, RI-06:173, RF-05:251.
- **PD-01:** 26, 28, 36–57 (the AD-11 AC set matches), 63, 76, 98–116, 191.
- **PD-02:** 38, 397.
- **BIBLE:** 493, 584, 602, 606, 608, 610.
- **BACKLOG anchors:** Q-E01, Q-E03, Q-E04, Q-E06, Q-E13, Q-P26, Q-P27, Q-P31, TH-19. The card text matches the packet.
- **Godot import-process receipt:** lines 11, 20–21, 23–30, 36–39, 44–47, 49–64, 56, 68–70, 74–79, 86–90, 97–108, 118–122, 131–132.
- **ctx7 receipts:** query 1 lines 4–15, 19–31, 35–58; query 3 lines 23–38, 61–76, 78–82.
- **SHA256 hashes:** not computed by me.
  - [coordinator receipt] `check-drift.log` reports 0 mismatches.
  - [coordinator receipt] `paper-check.log:19` reports 21 hashes matching.
  - `source-manifest.json` gives the same HF-03a, HF-03b and HF-05 hashes the candidate states.

## Commands and receipts
I ran no commands; I only had read, grep and glob tools.
- **Coordinator receipts I read but did not rerun** (`exits.txt`, `check-scope.log`, `check-drift.log`, `paper-check.log`, `identity.txt`):
  - check:scope, check:docs, check:project, check:drift and the paper check each exited 0.
  - The paper check reports 19/19 positive checks and 8/8 negative controls failing as required.
  - The diff adds one file only, with a clean worktree.
- Candidate SHA256 `a89b3e97…bce89` is also a [coordinator receipt].

## Runtime
- **Model:** Opus 5 (`claude-opus-5[1m]`), taken from the host system prompt; I cannot verify it myself.
- **CLAUDE_EFFORT:** unavailable. I have no shell to echo it, and the host did not expose it.

## Write confirmation
I wrote, edited and committed nothing.

Files: `/home/andrew/Projects/scrapkeep-wt-TH-19/docs/tech/sections/TH-19-asset-import-export.md`, `/home/andrew/Projects/scrapkeep/scripts/native-smoke.mjs`, `/home/andrew/Projects/scrapkeep/artifacts/handoff-8-2026-09-16/tasks/TH-19/coordinator-candidate/`