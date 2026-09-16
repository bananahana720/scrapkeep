# NP-01 save-owner repair evidence

This page records one execution of the TADR-004 save-owner proof after the NP-01 repair of the re-stage and lifecycle gates. The proof design, envelope and API receipt are on [the S0-07 page](S0-07-save-owner.md), which the repair extended in place. [The S0-08 page](S0-08-save-evidence.md) stays the dated record of the 6 September 2026 execution and is not rewritten by this run. The method is "headless fixture run, Linux only". The run certifies nothing, closes no HF card and is not qualification evidence under TADR-001.

## Sources

- [The S0-07 design page](S0-07-save-owner.md) and its extended case table, fault-injection contract and drift tripwires.
- [The S0-08 execution page](S0-08-save-evidence.md) for the command form and the fixture hashes this run had to reproduce.
- [TADR-004 Decision](../../../adr/TADR-004-persistence.md#decision) line 30 and [Consequences](../../../adr/TADR-004-persistence.md#consequences).
- [HF-07b commit boundaries](../sections/HF-07b-commit-boundaries.md): line 37 (the common validator), line 50 (D1.2), lines 116 and 117 (N4 and N5).
- [The native toolchain record](../native-toolchain.md) for the pinned binary and its install path.
- [CONTRIBUTING verification](../../../CONTRIBUTING.md#verification) for evidence classes.
- The disposable evidence directory `artifacts/local/tasks/NP-01/` in the NP-01 worktree, listed under Procedure performed.

## What changed in the proof

The adversarial review of 15 September 2026 recorded two findings against the placeholder owner. Both are repaired in `native/proofs/tadr-004/save_owner.gd` and proven by three new runner cases.

| Finding | Repair | Case |
| --- | --- | --- |
| F2: `stage` rewrote the deterministic temp path without revoking the recorded validation and `commit` compared only the path, so a validated-then-re-staged candidate committed its new bytes (HF-07b line 50, D1.2) | `stage` clears `converged` and the recorded validation on entry; `validate` records the SHA-256 of the bytes it read; `commit` refuses with `ERR_UNCONFIGURED` when the path or the staged digest differs, and any commit attempt consumes the eligibility | `restage_after_validate` |
| F3: `validate` gated only `generation`, so a strictly newer candidate could clear `revival_spent` or `terminal`, while the monotonic merge ran only inside `recover` (HF-07b lines 116 and 119) | `validate` calls `resolve_lifecycle(candidate, committed)` after the generation gate and returns `ERR_LOCKED` when the merged lifecycle differs from the candidate's | `lifecycle_regression_spent`, `lifecycle_regression_terminal` |

`ERR_LOCKED` is the distinct rejection value for the lifecycle gate. It is not `ERR_ALREADY_EXISTS` (the generation gate), `ERR_UNCONFIGURED` (commit eligibility), `ERR_UNAVAILABLE` (unsupported newer schema) or `ERR_INVALID_DATA` and `ERR_PARSE_ERROR` (envelope shape), so each refusal in the protocol still names its own cause. The pinned engine printed `error_string(ERR_LOCKED)` as `Locked` in both runs below.

Fixture bytes are unchanged. The three cases are built in the runner from `placeholder_aggregate` over the committed `fixtures/lifecycle/` files.

## Scenarios

Executed on 15 September 2026 from the NP-01 worktree `../scrapkeep-wt-NP-01` on branch `wt/NP-01`, based on `395bc3ff5583a460bba21095fffcda7faf514555`, with the repaired sources in the tree. The candidate commit is recorded in the NP-01 handoff and in `artifacts/local/native-smoke/report.json` for the smoke run.

| Field | Value |
| --- | --- |
| Engine | `4.7.2.stable.official.ed1daf0bf`, the same token `--version` prints |
| Binary | `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64` |
| Host | Linux `7.2.3-arch1-3` x86_64, Arch-based Omarchy, `OS.get_name()` reports `Linux` |
| Method | headless fixture run, Linux only |
| Passes | 2 per run, 12 cases each |

Normal run. Exit 0. Twenty-four case lines with `PASS`, zero `FAIL`, `S0-07 idempotence PASS 12 cases compared across 2 passes`, and the summary `{"cases":12,"engine":"4.7.2.stable.official.ed1daf0bf","exit_code":0,"failed":0,"host_os":"Linux","idempotent":true,"inject_fault":false,"method":"headless fixture run, Linux only","passed":24,"passes":2,"proof":"S0-07","run_dir":".../artifacts/local/proofs/tadr-004/run-20260915T205728Z-1789505848422"}`. The one `ERROR: acknowledge refused: txn-0001 has not committed` line per pass is the deliberate `push_error` from `commit_path` and carries no `FAIL` token.

Fault run. Exit 1. `newer_schema_candidate`, `newer_schema_committed`, `restage_after_validate`, `lifecycle_regression_spent` and `lifecycle_regression_terminal` print `FAIL` in both passes, the other seven cases pass, idempotence passes, and the summary reports `"failed":10,"passed":14,"inject_fault":true,"exit_code":1` over `run-20260915T205737Z-1789505857053`.

Per-case observations from the normal run, in order:

| Case | Observed |
| --- | --- |
| `commit_path` | Temp validated from re-read bytes, renamed to `save.json` with identical sha256 `abbab4e805a0...`, acknowledge refused before commit and recorded after. |
| `roundtrip` | Raw parse gave a float generation, the boundary cast restored ints, deep-equal and byte-equal re-stringify held. |
| `newer_schema_candidate` | Schema 99 rejected with `ERR_UNAVAILABLE`, committed sha256 unchanged, rejected temp preserved. |
| `newer_schema_committed` | Schema 99 `save.json` recovered as `unsupported_newer`, not playable, sha256 `326b6bc66d46...` unchanged, a later commit refused. |
| `interruption_stale` | Generation 3 recovered, truncated temp listed as stale and left untouched. |
| `interruption_ambiguous` | Generation 3 stays the source, unrenamed generation 4 `revival_spent` temp preserved, status `ambiguous_lifecycle`, not playable. |
| `lifecycle_spent` | `revival_spent` stays true from generation 5, generation 4 rejected with `ERR_ALREADY_EXISTS`, sha256 `610bd415af94...` unchanged. |
| `lifecycle_terminal` | Terminal generation 6 beats generation 5 in both orders and stays not playable after commit. |
| `converged` | Re-staged `txn-0001` converged with generation 1 and sha256 unchanged. |
| `restage_after_validate` | A generation 6 candidate validated `OK`, was re-staged at generation 7 over the same temp path, and `commit` refused with `ERR_UNCONFIGURED`; committed sha256 `610bd415af94...` and generation 5 unchanged, re-staged temp preserved. |
| `lifecycle_regression_spent` | A generation 6 candidate clearing `revival_spent` rejected with `Locked`, committed sha256 `610bd415af94...` unchanged, rejected temp preserved. |
| `lifecycle_regression_terminal` | Committed terminal generation 6 refused a generation 7 candidate clearing `terminal` with `Locked`, committed sha256 `ce9fdf2b83bb...` unchanged, rejected temp preserved, run still not playable. |

Fault-run detail for the three new cases, the evidence that each gate is noticed when it is removed:

| Case | First failure under `--inject-fault` |
| --- | --- |
| `restage_after_validate` | `commit of a re-staged candidate returned OK` |
| `lifecycle_regression_spent` | `validate of a generation 6 candidate clearing revival_spent returned OK` |
| `lifecycle_regression_terminal` | `validate of a generation 7 candidate clearing terminal returned OK` |

## Fixture hashes at this run

No fixture byte changed, and every value below matches the pins on [the S0-08 page](S0-08-save-evidence.md).

| File | sha256 |
| --- | --- |
| `fixtures/interruption/save.json` and `fixtures/interruption_ambiguous/save.json` | `f762ab6dbff97ddd9639df23349f12a35c52e2650483bb7c06b2b9899aa5112a` |
| `fixtures/interruption/save.json.tmp-txn-0004` | `135f5d92c75a3548df9934abe1139a59dde5478d759a2bd29197ace196842e00` |
| `fixtures/interruption_ambiguous/save.json.tmp-txn-0004` | `63c85da7c30888d85cf37848aef0c435ef5f9e71bb1d0cd25c6e45fc231fff00` |
| `fixtures/lifecycle/save.json` | `610bd415af943ce0622114c2e6ece2059366a198b00b7fdfdb591dc368a6a441` |
| `fixtures/lifecycle/older.json` | `902896a9edc1a01e68945ba7f139f45fe6a76c9d0a51439795651a13902d7a1c` |
| `fixtures/lifecycle/terminal.json` | `2f62550d62c79e23ba0d08c58909193b7aa4debd183514aa6fd7f61aca399e94` |
| `fixtures/newer-version/save.json` | `326b6bc66d46cdffb80cf4161949ebc41321c42f5695df2b1016ab45ab8ef133` |

## Unresolved questions

- Q-P14, Q-P15, Q-E09, Q-P16 and Q-E05 are proposed, not settled, and this page settles none of them. The profile stays `{"placeholder": true}` and nothing reads browser storage.
- Q-P39 is open. This page decides nothing about it.
- The proof envelope still carries no `run_id`, so N5's "`run.run_id` is unchanged" clause stays paper until FR-02 lands and a later proof card carries it.
- Acknowledgement remains in-memory, so the "rename completed, acknowledge not yet recorded" row on the S0-08 page still has no fixture.
- Whether a refused commit should be retryable after a re-validation, rather than consuming the eligibility, is a design choice this proof fixes one way and no accepted source constrains.

## Re-verification triggers

- Any trigger on [the S0-07 page](S0-07-save-owner.md).
- Any change to `native/proofs/tadr-004/**`, including the two new fault flags or the digest `validate` records.
- A change to the rejection values: `ERR_LOCKED` for the lifecycle gate and `ERR_UNCONFIGURED` for commit eligibility.
- HF-07b changing line 50, line 116 or line 117, or a production validator adopting these gates.

## Procedure performed

All commands ran from the NP-01 worktree root. `GODOT` is the pinned binary path above. Outputs are saved under `artifacts/local/tasks/NP-01/` in that worktree and are disposable.

```sh
$GODOT --headless --path native --script res://proofs/tadr-004/proof_runner.gd
echo $?
0
$GODOT --headless --path native --script res://proofs/tadr-004/proof_runner.gd -- --inject-fault
echo $?
1
npm run native:smoke
echo $?
0
```

Saved outputs: `run-normal.txt` and `run-normal.exit` (0), `run-inject-fault.txt` and `run-inject-fault.exit` (1), `native-smoke.txt`, `native-smoke.exit` (0), `native-smoke-report.json`, `check-docs.txt`, `check-project.txt`, `check-scope.txt`, `fixture-hashes.txt`, `ctx7-godot-error-enum.txt` and `ctx7-godot-error-enum-2.txt`. The run directories `run-20260915T205728Z-1789505848422` (normal) and `run-20260915T205737Z-1789505857053` (fault) under `artifacts/local/proofs/tadr-004/` hold `result.json` and every per-case directory. `npm run native:smoke` reported `proof-tadr-004` PASS, `proof-tadr-004-inject-fault` PASS (exit 1 with a `FAIL` line), `engine-pin` PASS and `source-preservation` PASS.

`FileAccess.get_sha256` was re-read from the Godot 4.7 documentation through Context7 (`/websites/godotengine_en_4_7`) for this card; the receipt is in `artifacts/local/tasks/NP-01/ctx7-godot-error-enum.txt`. Three Context7 calls did not return the `@GlobalScope` `Error` enum listing, so the existence and spelling of `ERR_LOCKED` rest on the pinned 4.7.2 binary, which compiled it and printed `Locked` through `error_string` in both runs above. `validate` hashes the text it read with `String.sha256_text`, which the S0-07 receipt's probe showed equal to `FileAccess.get_sha256` for the same bytes.

## Evidence limits

The limits on the S0-08 page apply unchanged. Flush and fsync durability, directory-entry durability after rename, non-Linux rename semantics and single-writer exclusion between processes were not asserted. TADR-004 line 38 applies in full: "Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability."

The new gates are asserted against placeholder aggregates on one Linux host in one process. A digest comparison inside `commit` detects a re-stage by this owner; it is not a defence against a concurrent writer, which the proof does not assert. The lifecycle gate is proven for `revival_spent` and `terminal` only, because those are the two monotonic flags the placeholder envelope carries. Two passes inside one process show idempotence of the harness, not durability across restarts. Automated execution establishes no human feel, no product save layout and no qualification under TADR-001.
