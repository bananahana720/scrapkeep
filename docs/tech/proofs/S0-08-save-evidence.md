# S0-08 save-owner proof evidence

This page records one execution of the TADR-004 save-owner proof under prepare-stage card S0-08. The proof design, envelope and API receipt are on [the S0-07 page](S0-07-save-owner.md). The method is "headless fixture run, Linux only". The run certifies nothing, closes no HF card and is not qualification evidence under TADR-001.

## Sources

- [The S0-07 design page](S0-07-save-owner.md) and its case table.
- [TADR-004 Decision](../../../adr/TADR-004-persistence.md#decision) and [Consequences](../../../adr/TADR-004-persistence.md#consequences).
- [The native toolchain record](../native-toolchain.md) for the pinned binary and its install path.
- [CONTRIBUTING verification](../../../CONTRIBUTING.md#verification) for evidence classes.
- The disposable evidence directory `artifacts/local/tasks/S0-07/` in the S0-07 worktree, listed under Procedure performed.

## Contract

The runner is `native/proofs/tadr-004/proof_runner.gd`. It is a `SceneTree` script, fully typed, with no `class_name`. Its outputs and exit codes:

- One line per case per pass, `S0-07 <case> PASS|FAIL pass=<N> <detail>`, nine cases over two passes.
- One line `S0-07 idempotence PASS|FAIL <detail>` comparing every case's verdict and detail between the two passes.
- One final line `SUMMARY <json>` with `proof`, `engine`, `host_os`, `method`, `inject_fault`, `passes`, `cases`, `passed`, `failed`, `idempotent`, `run_dir` and `exit_code`.
- A `result.json` in the run directory with the same summary, the per-case results, each case's root and fixture, and a `not_asserted` list.
- Exit 0 when every case passes and the passes match. Exit 1 on any assertion failure. Exit 2 on an environment failure, printed as `S0-07 environment ERROR <detail>`, when the fixtures directory is missing or the run directory cannot be created, written or cleaned. Exit 3 on a harness error, printed as `S0-07 harness ERROR <detail>`, when a case name has no method.
- `-- --inject-fault` after the script path is read through `OS.get_cmdline_user_args`. It constructs every owner with the newer-schema rejection disabled, so `newer_schema_candidate` prints `FAIL` and the run exits 1. `newer_schema_committed` also fails in that mode because the same owner now reads the schema 99 file as committed.

The run directory is `<worktree>/artifacts/local/proofs/tadr-004/run-<utc-stamp>-<unix-millis>/`, created fresh on every run and gitignored. `SCRAPKEEP_PROOF_RUN_ROOT` overrides the parent directory. The game's `user://` is never touched. A passing run prints one `ERROR: acknowledge refused: txn-0001 has not committed` line per pass. That is the `push_error` the `commit_path` case provokes on purpose and it contains no `FAIL` token.

## Scenarios

Executed on 2026-09-06 from the S0-07 worktree at candidate commit `ce79c66` (authoring) with the pinned binary.

| Field | Value |
| --- | --- |
| Engine | `4.7.2.stable.official.ed1daf0bf`, the same token `--version` prints |
| Binary | `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64` |
| Host | Linux `7.1.9-arch1-2` x86_64, Arch-based Omarchy, `OS.get_name()` reports `Linux` |
| Method | headless fixture run, Linux only |
| Passes | 2 per run, 9 cases each |

Normal run. Exit 0. Eighteen case lines with `PASS`, zero `FAIL`, `S0-07 idempotence PASS 9 cases compared across 2 passes`, and the summary `{"cases":9,"engine":"4.7.2.stable.official.ed1daf0bf","exit_code":0,"failed":0,"host_os":"Linux","idempotent":true,"inject_fault":false,"method":"headless fixture run, Linux only","passed":18,"passes":2,"proof":"S0-07","run_dir":".../artifacts/local/proofs/tadr-004/run-20260906T190853Z-1788721733739"}`.

Fault run. Exit 1. `newer_schema_candidate` and `newer_schema_committed` print `FAIL` in both passes, the other seven cases pass, idempotence passes, and the summary reports `"failed":4,"passed":14,"inject_fault":true,"exit_code":1`.

Per-case observations from the normal run, in order:

| Case | Observed |
| --- | --- |
| `commit_path` | Temp validated from re-read bytes, renamed to `save.json` with identical sha256 `abbab4e805a0...`, acknowledge refused before commit and recorded after. |
| `roundtrip` | Raw parse gave a float generation, the boundary cast restored ints, deep-equal and byte-equal re-stringify held. |
| `newer_schema_candidate` | Schema 99 rejected with `ERR_UNAVAILABLE`, committed sha256 unchanged, rejected temp preserved. |
| `newer_schema_committed` | Schema 99 `save.json` recovered as `unsupported_newer`, not playable, sha256 `326b6bc66d46...` unchanged, a later commit refused. |
| `interruption_stale` | Generation 3 recovered, truncated temp listed as stale and left byte-identical. |
| `interruption_ambiguous` | Generation 3 stays the source, unrenamed generation 4 `revival_spent` temp preserved, status `ambiguous_lifecycle`, not playable. |
| `lifecycle_spent` | `revival_spent` stays true from generation 5, generation 4 rejected with `ERR_ALREADY_EXISTS`, sha256 `610bd415af94...` unchanged. |
| `lifecycle_terminal` | Terminal generation 6 beats generation 5 in both orders and stays not playable after commit. |
| `converged` | Re-staged `txn-0001` converged with generation 1 and sha256 unchanged. |

Proposed HF-08 interruption matrix rows. Each row names the committed fixture directory that reproduces it, so the matrix can cite executed behaviour instead of paper. HF-08 owns whether to adopt them.

| Interruption point | Fixture directory | Observed recovery |
| --- | --- | --- |
| Power loss during temp write, temp truncated | `native/proofs/tadr-004/fixtures/interruption/` | `committed_stale_temp`, generation 3 playable, temp preserved |
| Crash after a complete temp write, before rename, temp carries a new lifecycle fact | `native/proofs/tadr-004/fixtures/interruption_ambiguous/` | `ambiguous_lifecycle`, generation 3 stays the source, not playable, temp preserved |
| Older checkpoint offered after a spent revival | `native/proofs/tadr-004/fixtures/lifecycle/` (`older.json` against `save.json`) | `ERR_ALREADY_EXISTS`, committed file unchanged |
| Terminal defeat committed, any older living checkpoint | `native/proofs/tadr-004/fixtures/lifecycle/` (`terminal.json`) | `playable` false in both resolution orders |
| Save written by a newer build | `native/proofs/tadr-004/fixtures/newer-version/` | `unsupported_newer`, not playable, file unchanged, later commit refused |
| Duplicate delivery of a committed transaction | no fixture, `converged` case builds it | `converged` true, no rewrite, generation unchanged |
| Rename completed, acknowledge not yet recorded | paper only, no fixture | not executed; the owner has no persisted acknowledge record yet |

## Unresolved questions

- The last matrix row has no fixture because acknowledgement is in-memory in this proof. HF-07b decides whether an acknowledgement leaves a durable trace.
- Whether `ambiguous_lifecycle` should also cover a newer valid temp with unchanged lifecycle facts is listed on the S0-07 page.
- Q-E05 and Q-E09 remain open and untouched.

## Re-verification triggers

- Any trigger on the S0-07 page.
- A change to `native/proofs/tadr-004/**` or to the fixture bytes. The fixture sha256 values at this run are `f762ab6d...` (`interruption/save.json` and `interruption_ambiguous/save.json`), `135f5d92...` (`interruption/save.json.tmp-txn-0004`), `63c85da7...` (`interruption_ambiguous/save.json.tmp-txn-0004`), `610bd415...` (`lifecycle/save.json`), `902896a9...` (`lifecycle/older.json`), `2f62550d...` (`lifecycle/terminal.json`) and `326b6bc6...` (`newer-version/save.json`).
- HF-08 consuming these rows, which then owns its own re-verify trigger.

## Procedure performed

All commands ran from the S0-07 worktree root with `GODOT` set to the pinned binary path above. Outputs are saved under `artifacts/local/tasks/S0-07/` in that worktree and are disposable.

```sh
$GODOT --headless --path native --script res://proofs/tadr-004/proof_runner.gd
echo $?
0
$GODOT --headless --path native --script res://proofs/tadr-004/proof_runner.gd -- --inject-fault
echo $?
1
```

Saved outputs: `run-normal.txt` and `run-normal.exit` (0), `run-inject-fault.txt` and `run-inject-fault.exit` (1), `ctx7-godot.txt`, `probe-api.txt`, `probe-api2.txt`, `probe-type.txt`, the probe scripts under `probe/`, `npm-ci.log`, `fixture-syntax.txt`, `check-docs.txt`, `check-project.txt` and `diff-stat.txt`. The run directories `run-20260906T190853Z-1788721733739` (normal) and `run-20260906T190853Z-1788721733959` (fault) under `artifacts/local/proofs/tadr-004/` hold `result.json` and every per-case directory.

The fixture syntax check parsed every file under `native/proofs/tadr-004/fixtures/` with Node's `JSON.parse` and treated `interruption/save.json.tmp-txn-0004` as the one expected parse failure. `npm run check:docs` and `npm run check:project` ran after the documentation was written. Their exit codes are in the saved outputs and in the handoff.

## Evidence limits

Flush and fsync durability were not asserted. `FileAccess.flush` returned `OK` through `get_error`, which is a library claim about buffered data and not a device guarantee. Directory-entry durability after rename was not asserted and no directory sync API appears in the receipt. Non-Linux rename semantics were not asserted; rename over an existing file was observed on one Linux filesystem only. Single-writer exclusion between processes was not asserted. TADR-004 line 38 applies in full: "Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability."

The run proves the logical protocol with placeholder data on one host. Automated execution establishes no human feel, no product save layout and no qualification under TADR-001. Two passes inside one process show idempotence of the harness, not durability across restarts.
