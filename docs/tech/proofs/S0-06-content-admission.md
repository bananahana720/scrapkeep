# S0-06 proof: binary-tree admission rejection and failed-reload retention

This page records the headless proof that prepare-stage card S0-06 asked for. The structural admission rule from TADR-003 line 31 runs over the S0-05 placeholder and over a malformed candidate on the pinned Godot 4.7.2 binary, a staged catalogue that contains the malformed candidate is refused while the active catalogue keeps resolving, and a fault-injection switch shows that a bypassed rule turns into a `FAIL` line and exit 1. The code shares [`native/proofs/tadr-003/proof_runner.gd`](../../../native/proofs/tadr-003/proof_runner.gd) with [S0-05](S0-05-content-identity.md). It is disposable evidence for HF-05 and HF-06a.

## Sources

- [TADR-003 § Decision](../../../adr/TADR-003-content-pipeline.md#decision), line 31 (15 nodes, 14 edges, eight endpoints, exactly two children per nonterminal, connectivity, no cycles or reconvergence) and line 33 (a failed reload keeps the current catalogue).
- [BIBLE.md § Four slots and milestone progression](../../../BIBLE.md#four-slots-and-milestone-progression), tree shape only.
- [BACKLOG.md card S0-06](../../../BACKLOG.md#s0-06) and the B3 design (`artifacts/ai-first-audit-2026-09-06/worker-results/B3-tadr-003.md`, Sections 1, 2 and the S0-02 draft).
- [The S0-05 proof page](S0-05-content-identity.md) for the definition, the catalogue, the fixture format, the preload-constant pattern and the probed APIs.

## Contract

`native/proofs/tadr-003/definitions/tree_rules.gd` declares `TreeRules` with `static func validate(def: SlotTreeDefinition) -> PackedStringArray`. It returns an empty array for an admissible tree and otherwise one diagnostic per failed check, each of the form `<id>: <check>: <detail>`. The checks run in this order: `node_count` (15), `node_unique`, `edge_count` (14), `edge_format` (`parent>child`), `edge_endpoint` (both ends are declared nodes), `reconvergence` (a node with more than one parent), `root_count` (exactly one node without a parent), `child_count` (every nonterminal has exactly two children), `endpoint_count` (8), `unreachable` (depth-first reach from the root), and `acyclic` (a topological order that covers every node). With one root, no reconvergence and full reachability the tree is already acyclic; the explicit check exists so a cycle that hides behind a second root still names itself.

`ProofCatalogue.stage(candidates: Array[SlotTreeDefinition]) -> Error` runs the same admission problems as `register` (the `proof.` prefix, then `TreeRules.validate`) over every candidate, also refuses an id staged twice, and swaps the active dictionary and bumps the catalogue `content_revision` only when no diagnostic was produced. Otherwise it returns `ERR_INVALID_DATA`, leaves the active catalogue and its revision untouched, and exposes the diagnostics.

`fixtures/candidate_bad/malformed_tree.tres` has id `proof.tree.malformed`, the same 15 nodes and 14 edges as the placeholder, except that `n6>n14` is redirected to `n6>n12`. Node `n12` therefore has two parents and leaf `n14` has none. Every field is well typed and the file parses, so the rule and not typing or syntax rejects it.

The runner accepts `-- --inject-fault` through `OS.get_cmdline_user_args()`. In that mode `rule_rejects` skips the rule and treats the malformed candidate as clean, so the run prints `S0-06 rule_rejects FAIL` and exits 1. The sibling harness from S0-04 discovers `native/proofs/*/proof_runner.gd`, expects exit 0 and no `FAIL` line normally, and exit 1 with the flag.

## Scenarios

Each case prints one line `S0-06 <case> PASS|FAIL <detail>`. Diagnostics follow the `rule_rejects` line as `DIAG` lines.

- `rule_accepts`. `TreeRules.validate(placeholder)` returns no diagnostic.
- `rule_rejects`. The runner counts the good tree independently of the rule (15 nodes, 14 edges, 8 endpoints, every nonterminal with two children). `validate(malformed)` returns diagnostics that all begin with `proof.tree.malformed`, one naming `reconvergence` (node `n12` has 2 parents) and one naming `unreachable` (node `n14`). The observed run also reports `root_count: expected 1, found 2 (n0, n14)`. With `--inject-fault` the rule is bypassed and the case prints `FAIL`.
- `failed_reload`. `stage([placeholder, malformed])` returns `ERR_INVALID_DATA` with three diagnostics; `resolve(proof.tree.placeholder)` still returns the registered instance, `resolve(proof.tree.malformed)` is `null`, and the catalogue revision is unchanged. A following `stage([placeholder])` returns `OK`, still resolves the placeholder and bumps the revision to 1, so the swap path is exercised and the failed path is not vacuous.
- `admission_exit`. The malformed id is absent from the active catalogue and the planned exit code follows the count of `FAIL` lines: 0 in the normal run, 1 under `--inject-fault`.

## Unresolved questions

- Semantic rules are out of scope: one selected lineage per slot, weapon and mobility start access, world-one milestones, recipe endpoints and compatibility references (TADR-003 line 31, second sentence). Nothing here validates them.
- Safe encounter boundary. `stage` swaps a dictionary in a headless script. When a live run may consume the swap is not proven.
- `content_revision` placement. See the S0-05 page. `stage` bumps the catalogue value; the definition value is only compared for equality.
- Whether `register` should exist beside `stage` in production or whether every admission goes through a staged set. The proof keeps both on one admission helper so they cannot drift.

## Re-verification triggers

- Any change to `tree_rules.gd`, `catalogue.gd` or either fixture.
- A change to TADR-003 line 31 or BIBLE line 529 (the tree shape).
- A different engine version string than `4.7.2.stable.official.ed1daf0bf`.
- The S0-04 harness changing its discovery path, expected exit codes or its `FAIL` grep.

## Procedure performed

All commands ran from `/home/andrew/Projects/scrapkeep-wt-S0-05` on 2026-09-06 with the pinned binary. Outputs are under `artifacts/local/tasks/S0-05/` (git-ignored, read from the worktree). `godot-version.txt` holds `4.7.2.stable.official.ed1daf0bf`.

1. `godot --headless --path native --script res://proofs/tadr-003/proof_runner.gd` into `run-normal.txt`, exit code in `run-normal.exit`: eight `PASS` lines, three `DIAG` lines, summary `{"cases":8,...,"exit":0,"failed":0,...,"passed":8}`, exit 0.
2. The same command with `-- --inject-fault` into `run-inject-fault.txt` and `run-inject-fault.exit`: `S0-06 rule_rejects FAIL rule_bypassed_by_--inject-fault ...`, summary with `"exit":1,"failed":1,"passed":7`, exit 1.
3. `probe_runner_missing_fixture.gd` (`probe-harness-exit3.txt`) with a nonexistent candidate path: `HARNESS_ERROR` line, summary with `"exit":3,"cases":0`, exit 3.
4. `npm run check:docs`, `npm run check:project`, `git diff --stat 70f2435575c9edb962994426a6c7971acab9953c` and `grep -rn 'cost\|effect\|display_name' native/proofs/tadr-003/definitions/` (expected empty) into `check-docs.txt`, `check-project.txt`, `diff-stat.txt` and `grep-product-values.txt`.
5. `sha256-manifest.txt` lists the digest of every committed proof file.

APIs used here beyond the S0-05 list: typed `Dictionary[K, V]`, typed `for x: T in` loops, `PackedStringArray.remove_at`, `append_array` and `String.join`. None appears in a receipt; each was established by the engine parsing and running the rule under the warnings-as-errors keys in the runs above.

## Evidence limits

Proven on this host only: the structural rule accepts the placeholder and rejects the malformed candidate with diagnostics that name the id, the reconvergent node and the unreachable leaf; a staged set containing the malformed candidate is refused and the active catalogue still resolves; a good staged set swaps in; a bypassed rule surfaces as a `FAIL` line and exit 1; a fixture that fails to load exits 3.

Not proven, verbatim from the B3 design: the editor import pipeline; hot reload at a safe encounter boundary; exported asset references; `.tscn` scenes; save pinning to `content_revision`; merge friction; enforced immutability; anything 4.7.2-specific beyond this Linux host. The semantic admission rules are not implemented. The catalogue is an in-memory dictionary in a script, not a project singleton, and nothing here is qualification evidence under TADR-001.
