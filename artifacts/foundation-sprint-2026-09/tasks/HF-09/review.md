# HF-09-A1 independent review

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort medium pinned by agent definition after EV-0149; CLAUDE_EFFORT not exposed). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-09, branch wt/HF-09, head bb63210cf06156bc1bc2fa4cd1fe72b2f0d9a01e, base 2db978b7e8220e8b414d808d2a7d782b72492b58. Verbatim report follows.

---

## Verdict: PASS+NOTES

Evidence level: 3 (walked) for DoD 1a, 1b, 3, 4 and the verification bullets; 2 (file:line) for headings, prohibitions and citations; 4 (coordinator receipt) for every claim that scope/docs/project exited 0 and that the paper check produced 371/0/125/26/5.

Artifact read: `docs/tech/sections/HF-09-schema-migration.md`, 400 lines, sha256 `95b6d16e…` per `paper-check.json:1868` and `verification.json:13` (receipt).

## Blocking findings

None.

## Check results

**1. DoD 1a (walked).** Axes at `:73-99`, precedence at `:69`, table `:107-122`. The rows partition 5x5x5: P5-P7 cover SA in {malformed, newer, unsupported-older} (75), P8-P10 cover SA in {current, step} x CA in {malformed, missing, ambiguous} (30), P1-P4 the remaining SA x CA with KA=complete (4), P11-P14 the same with KA != complete (16) = 125. Five hand-picked combinations each match exactly one row with the precedence verdict. `check_migration.py:502-541` performs the same enumeration against an independent precedence function (`:515-523`).

**2. DoD 1b (walked).** Chain definition `:136`, working area not storage `:138`, one commit per chain `:140` citing TADR-004:34 (verified) and HF-07b D1.4 (`HF-07b:52`); per-step gates G1-G13 `:163-177` validated before the next step `:161`; four stages `:148-153` match `HF-07b:36-39`. S0-08 reconciled by source review `:241-258`, nine cases matching `S0-08-save-evidence.md:46-54`.

**3. DoD 3 (walked).** W2 newer `:294-307`, W3 missing recipe `:309-321`, W5 incompatible `:340-353`. W2 by hand: P6 reject, nothing written, source byte-identical, matches S0-08:48-49. W3 by hand: P13 reject with `missing_id`, `requested_id`, `referrer` (HF-05:105-111 verified); `rec-b` retained, not remapped (`:319`, TADR-003:41 verified). No reroll (M4 `:188`), no knowledge loss (M5 `:189`), no added effect (M6 `:190,196`, grounded in HF-07a rule 2 at `HF-07a:58`).

**4. DoD 4 (file:line).** Table `:213-218` matches source at this base: `src/collection.js:29-31` keys and `:38`; `src/progress-store.js:8`, `:12` prefix `${key}.run.`, `:17`, `:45`; `src/campaign.js:115`; `src/main.js:43-45,48,141`; `src/orchard/main.js:20,106`. "HF-09 reads none of them" `:220`. Q-E05 candidate table `:228-233` covers preserve/import/never-retire/retire, no answer adopted `:235`. EV-0170 does not appear in the section; `:231` stands on B2 (`:223`).

**5. Verification bullets (walked).** W1 `:275-292`: P4, two steps in W, one candidate G6/T6, four stages, acknowledge before resume. W4 `:323-338`: second load P1 accept, no generation; interrupted before commit re-runs from untouched source; between commit and acknowledge P1. Browser keys appear only in `:215-218`, `:239` and `:392`.

**6. Writer's flagged decisions.** (a) One record plus extras: `progress-store.js:45-49` calls `parseProfile(parsed)` on the same key read; `campaign.js:115` is the parser's predicate. Inside the card; no amendment. (b) Empty registry and no second schema version: the DoD asks to specify handling; `:260-267` reconciles both readings of `S0-07:116` and `:370` records the empty registry as unresolved. Inside the card; no amendment.

**7. Prohibitions and headings.** Card titles at `:10-12` match BACKLOG. No `mount_id`, `retain_revision`, `read_initial_snapshot`; the three containers appear once at `:377` as non-contract. Headings in order `:3,18,269,367,380,388,398`. No engine behavior claimed `:400`. HF-05:8 not propagated; `:8` cites TADR-003:41 directly and names the known error.

**8. Script coverage.** Substantive: 125-combination enumeration with hit-count == 1 and independent precedence agreement (`:526-541`); cited-line needles verified per line (`:465-478`); five negative controls are real removals (`:1161-1205`). Gaps below.

## Notes (none violates the DoD)

- N1. `check_migration.py:659-672`: the model's schema step declares no adds/renames and mutates nothing, while `:284` (W1.3) says the schema step renames a path and adds a key. G4, G9 and the `added_values` rule (`:54,63`) are never exercised by a nontrivial step. The `:394` claim "replays all five walks" is true of verdicts and invariants, not of W1.3's declared field changes.
- N2. `check_migration.py:1150-1156`: the per-gate "still_safe" loop runs a well-formed registry, so disabling a gate cannot change the outcome; those 13 checks are vacuous.
- N3. W4.8 (`:337`, redelivered committed transaction converging, S0-08:54) has a model code path (`:929,951-955`) but no test drives it.
- N4. `:216` reads "the `.run.` suffix prefix"; the source shows a prefix. Wording only.
- N5. The card says "catalogue version"; the section's third axis is handle existence and resolution, not a version compare (`:36-38`), justified by `HF-07a:172,181` and HF-05:24. Deliberate and sourced; flag for the card owner's awareness.
- N6. Command and count claims rest on coordinator receipts. The receipt's per-check details for `gate.*.exercised` carry the failure message text even on pass, a cosmetic script artifact (`check_migration.py:351`).
