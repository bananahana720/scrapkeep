# S0-07 save-owner proof

This page records the design of the TADR-004 hello-world persistence proof under prepare-stage card S0-07. The proof lives at `native/proofs/tadr-004/` and runs headless on the pinned Godot 4.7.2 editor. It proves the logical save protocol on one Linux host with placeholder data. It is not qualification evidence, it defines no product save layout, and it decides no open question. The executed evidence is on [the S0-08 page](S0-08-save-evidence.md).

## Sources

- [TADR-004 Decision](../../../adr/TADR-004-persistence.md#decision). Line 28 fixes the order stage, validate, commit, acknowledge and says duplicate delivery of one transaction converges. Line 30 separates checkpoint timing from lifecycle timing and makes the spent revival and terminal facts monotonic. Line 32 holds the transition on a failed write. Line 34 says unknown newer formats fail visibly without overwriting the source.
- [TADR-004 Consequences](../../../adr/TADR-004-persistence.md#consequences). Line 38 reads, verbatim, "Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability." Line 40 says recovery must preserve ambiguous or corrupt records and refuse automatic resumption unless lifecycle continuity can be established.
- `BACKLOG.md` cards S0-07 and S0-08, and the audit design in `artifacts/ai-first-audit-2026-09-06/worker-results/B4-tadr-004.md` (Section 1 cases a to f, Section 2 harness).
- The Godot 4.7 documentation receipt at `artifacts/local/tasks/S0-07/ctx7-godot.txt` (three Context7 queries, disposable) and the probe outputs `probe-api.txt` and `probe-api2.txt` beside it.
- Browser prior art, read only and cited only. `src/campaign.js:112-115` replaces a profile whose version is not 1 with a fresh default, the inverse of TADR-004 line 34. `src/progress-store.js:45-51` keeps the last usable profile on a mismatch or corrupt record. `server/store.js:103-124` writes a temporary file, syncs it, renames it, then syncs the directory, and sets its in-memory state before the directory sync. None of that code is reused here.
- The scaffold conventions in [native/README.md](../../../native/README.md). Every declaration carries an explicit type. There is no second `project.godot`.

## Contract

The owner is `native/proofs/tadr-004/save_owner.gd`. It extends `RefCounted`, has no `class_name`, and is loaded by the runner through a typed `preload` constant so the global class cache stays empty. One owner instance holds one root directory and one committed record.

The envelope carries placeholder fields only.

```json
{
  "schema_version": 1,
  "content_revision": "placeholder-content-0",
  "generation": 1,
  "transaction_id": "txn-0001",
  "profile": {"placeholder": true},
  "run": {
    "checkpoint": {"next_entrance": "placeholder-entrance-1"},
    "lifecycle": {"revival_spent": false, "terminal": false}
  }
}
```

The committed file is `<root>/save.json`. A staged candidate is `<root>/save.json.tmp-<transaction_id>`. The root is always an absolute directory under `artifacts/local/proofs/tadr-004/<run-id>/`, never the game's `user://`.

| Method | Behaviour |
| --- | --- |
| `stage(aggregate) -> String` | Serialises the aggregate with sorted keys, opens the temp path for writing, stores the text, flushes, checks `get_error`, closes. Returns the temp path, or an empty string after `push_error` when the open or write failed. |
| `validate(temp_path) -> Error` | Re-reads the temp bytes from disk, never the in-memory dictionary. Parses and casts them through `parse_envelope`. Returns `ERR_PARSE_ERROR` for unparsable text, `ERR_INVALID_DATA` for a missing or mistyped required key, `ERR_UNAVAILABLE` when `schema_version` exceeds `SCHEMA_VERSION`. When the committed file exists but is unreadable or unsupported, returns that read error so nothing can commit over it. When the candidate carries the committed `transaction_id`, returns `OK` and sets `converged` to true. When `generation` is not greater than the committed generation, returns `ERR_ALREADY_EXISTS`. Only a candidate that returned `OK` is eligible for `commit`. |
| `commit(temp_path) -> Error` | Refuses with `ERR_UNCONFIGURED` unless `temp_path` is the candidate that last validated `OK`. For a converged duplicate it removes the duplicate temp and returns `OK` without touching `save.json`. Otherwise it renames the temp over `save.json` with `DirAccess.rename_absolute`, re-reads the committed file from disk and records the transaction as committed. |
| `acknowledge(transaction_id) -> void` | Records the transaction only when `commit` has returned `OK` for it. An earlier call calls `push_error` and records nothing. `is_acknowledged` exposes the record. |
| `recover() -> Dictionary` | Returns `status`, `aggregate`, `stale` and `playable`. Parses `save.json` and lists every `save.json.tmp-*` name in sorted order. It never deletes or renames a temp. Statuses are `missing`, `corrupt`, `unsupported_newer`, `committed`, `committed_stale_temp` and `ambiguous_lifecycle`. A parseable temp whose generation is higher than the committed generation, and whose resolved lifecycle differs from the committed lifecycle, produces `ambiguous_lifecycle` with `playable` false while the committed record stays the `aggregate`. A temp that fails to parse, or whose lifecycle facts match, is listed as stale and the committed record stays playable unless it is terminal. |
| `resolve_lifecycle(a, b) -> Dictionary` | Copies the higher-generation record. Sets `revival_spent` and `terminal` to the logical or of both inputs, so a fact that is true anywhere stays true. Adds `playable`, which is false whenever `terminal` is true. |

The int-casting policy. Godot parses every JSON number as a float and stringifies every number as a float (receipt lines 225 to 229, probe `n_type 3` and `stringify {"f":3.5,"n":3.0,"s":"x"}`). `parse_envelope` therefore rebuilds the envelope at the boundary and casts `schema_version` and `generation` to `int` after checking the value is an int or a float. Strings and booleans are copied through typed locals. `profile` is deep-copied as is. Nothing downstream sees a float generation. Re-serialising the cast record reproduces the original text byte for byte because the original was built from ints.

Fault injection. `SaveOwner.new(root, true)` disables only the newer-schema rejection inside `parse_envelope`. The runner passes that flag under `--inject-fault` so the harness can prove it notices a missing rejection. No other path reads the flag.

## Scenarios

The runner `native/proofs/tadr-004/proof_runner.gd` executes these cases in order, twice, each in a fresh directory `<run-id>/pass<N>/<case>/`. Fixtures are copied file by file with `DirAccess.copy_absolute` and never mutated in place. Each case prints `S0-07 <case> PASS|FAIL pass=<N> <detail>`.

| Case | Fixture | Asserts |
| --- | --- | --- |
| `commit_path` | none | Temp exists after `stage`. `acknowledge` before commit is refused. `commit` before `validate` returns `ERR_UNCONFIGURED`. `validate` returns `OK` and not converged. After `commit`, `save.json` exists, the temp is gone, and the sha256 and text of `save.json` equal the staged bytes. `acknowledge` after commit is recorded. `recover` reports `committed`. |
| `roundtrip` | none | The raw `JSON.parse_string` result carries a float generation. `parse_envelope` restores int `generation` and `schema_version`, deep-equals the original, and re-serialises to the identical text. |
| `newer_schema_candidate` | none, commits generation 1 first | A candidate with `schema_version` 99 fails `validate` with `ERR_UNAVAILABLE`. `commit` refuses with `ERR_UNCONFIGURED`. The committed sha256 is unchanged. The rejected temp is preserved. Under `--inject-fault` this case fails. |
| `newer_schema_committed` | `newer-version/` | `recover` returns `unsupported_newer`, `playable` false and an empty aggregate. Staging a schema 1 candidate then fails `validate` with `ERR_UNAVAILABLE`. The schema 99 file still exists with its sha256 unchanged. |
| `interruption_stale` | `interruption/` | `recover` returns `committed_stale_temp`, generation 3, `stale` equal to `["save.json.tmp-txn-0004"]`, `playable` true. The truncated temp exists with unchanged sha256. `save.json` is unchanged. |
| `interruption_ambiguous` | `interruption_ambiguous/` | `recover` returns `ambiguous_lifecycle`, keeps generation 3 as the aggregate, `playable` false, lists the complete generation 4 temp as stale, and leaves both files byte-identical. |
| `lifecycle_spent` | `lifecycle/` | `resolve_lifecycle(gen5, gen4)` keeps `revival_spent` true, generation 5 and `playable` true. The reversed argument order gives the same fact. Staging the generation 4 record fails `validate` with `ERR_ALREADY_EXISTS`, `commit` refuses, and the sha256 of `save.json` is unchanged. |
| `lifecycle_terminal` | `lifecycle/` | `resolve_lifecycle` of the terminal generation 6 against generation 5 gives `playable` false in both orders and takes generation 6. Committing generation 6 through the protocol then makes `recover` report `committed` and `playable` false. |
| `converged` | none, commits generation 1 first | Re-staging the committed `transaction_id` validates `OK` with `converged` true. `commit` returns `OK`, the sha256 of `save.json` is unchanged, the duplicate temp is removed, and `recover` still reports generation 1. |

Fixture directories under `native/proofs/tadr-004/fixtures/`:

- `interruption/` holds `save.json` at generation 3 (`txn-0003`, acknowledged) and `save.json.tmp-txn-0004`, a JSON document cut off mid-string. The temp is deliberately unparsable, so the coordinator's `JSON.parse` syntax check must treat that one file as an expected failure.
- `interruption_ambiguous/` holds the same `save.json` and a complete valid `save.json.tmp-txn-0004` at generation 4 with `revival_spent` true that was never renamed.
- `lifecycle/` holds `save.json` at generation 5 with `revival_spent` true, `older.json` at generation 4 with `revival_spent` false, and `terminal.json` at generation 6 with `terminal` true.
- `newer-version/` holds a `save.json` with `schema_version` 99 and one field schema 1 does not know.

Every API the proof calls, with its documentation receipt line in `artifacts/local/tasks/S0-07/ctx7-godot.txt` or the probe that confirmed it. An API marked unverified has no receipt excerpt and rests on the probe alone.

| API | Receipt | Probe |
| --- | --- | --- |
| `FileAccess.open` with `WRITE` and `READ` | lines 9 to 24 and 40 to 48 | `probe-api.txt` lines 10, 26 |
| `FileAccess.store_string`, `get_as_text` | lines 43 and 47 | `probe-api.txt` line 13 |
| `FileAccess.flush` | lines 70 to 82 | `probe-api.txt` line 11 |
| `FileAccess.close` | lines 257 to 269 | run output |
| `FileAccess.file_exists` | unverified | `probe-api.txt` line 12 |
| `FileAccess.get_open_error`, `get_error` | unverified | `probe-api.txt` lines 10, 11, 26, 36 |
| `FileAccess.get_sha256` | unverified | `probe-api.txt` line 13 equals `String.sha256_text` on line 14 |
| `DirAccess.make_dir_recursive_absolute` | lines 233 to 253 | `probe-api.txt` line 9 |
| `DirAccess.dir_exists_absolute` | lines 107 to 128 | `probe-api2.txt` line 11 |
| `DirAccess.rename_absolute` | lines 324 to 345 | `probe-api.txt` lines 33 and 35 (rename over an existing file replaces it on Linux) |
| `DirAccess.remove_absolute` | lines 300 to 320 | run output (`converged`, environment probe) |
| `DirAccess.copy_absolute` | lines 273 to 296 | `probe-api.txt` line 34 |
| `DirAccess.get_files_at` | unverified | `probe-api.txt` line 27; line 32 shows it prints an engine error on a missing directory, so the owner checks `dir_exists_absolute` first |
| `JSON.stringify` with indent and sorted keys | lines 132 to 155 and 225 to 229 for the two-argument form; the `sort_keys` argument is unverified | `probe-api2.txt` lines 9 and 10 |
| `JSON.new().parse`, `data`, `get_error_message` | lines 132 to 155 | `probe-api2.txt` lines 5 and 6 (the instance parser prints nothing on failure) |
| `JSON.parse_string` | lines 214 to 223 | `probe-api.txt` line 25 (the static parser prints an engine error on failure, so the owner uses the instance parser) |
| JSON numbers parse as float | lines 225 to 229 describe stringify only; parsing is unverified | `probe-api.txt` lines 16 to 19 |
| Typed `Dictionary` and `Array[String]` | lines 189 to 210 | run output |
| `OS.get_cmdline_user_args` | unverified | `probe-api.txt` line 3 |
| `OS.get_environment`, `OS.get_name` | unverified | `probe-api.txt` lines 4 to 6 |
| `Time.get_datetime_string_from_system`, `get_unix_time_from_system` | unverified | `probe-api.txt` lines 7 and 8 |
| `ProjectSettings.globalize_path` | unverified | `probe-api2.txt` lines 3 and 4 |
| `Engine.get_version_info` | unverified | `probe-api.txt` line 41 and the S0-01 smoke marker |
| `SceneTree.quit(exit_code)` | unverified | `probe-api.txt` last line, `exit=7` |
| `push_error`, `error_string`, `Callable.is_valid` | unverified | `probe-api.txt` line 37, every `error_string` in the run output, `probe-api2.txt` line 7 |

GDScript typing findings that shaped the code. `int(variant)` and `bool(variant)` are refused under `unsafe_call_argument`, so the owner assigns a Variant to a typed local first. A static method called through a `GDScript`-typed constant is refused under `unsafe_method_access`, so every owner method is an instance method and the runner constructs an owner for every case. `a == b as Array[String]` parses as `(a == b) as Array[String]`, so typed expected arrays are declared before comparison.

## Unresolved questions

- Q-E05 and Q-E09 stay open. The profile is `{"placeholder": true}`, no discovery field exists, and nothing reads browser storage. Any real profile field reopens those gates.
- The `ambiguous_lifecycle` rule compares the resolved lifecycle of a newer unrenamed temp with the committed lifecycle. A newer temp with identical lifecycle facts is treated as stale and the committed record stays playable. HF-08 may tighten this to "any newer valid temp blocks resumption". The fixture `interruption_ambiguous/` pins only the case TADR-004 line 40 names.
- Whether a blocked resume surfaces to the player as an error state is a product decision outside this proof.
- The converged duplicate removes its temp. A design that keeps every staged file for audit would change `commit` only.

## Re-verification triggers

- Any change to `adr/TADR-004-persistence.md` lines 22 to 42.
- Any change to the envelope shape, `SCHEMA_VERSION`, the temp naming rule or the statuses above.
- A new engine version, a second target operating system, or a change to `native/project.godot` typing keys.
- HF-07a landing a real envelope, or HF-09 defining a second schema version with a migration.
- The S0-04 generic proof discovery in `scripts/native-smoke.mjs` changing its exit-code or output expectations.

## Procedure performed

Authoring only on this page. The receipt was fetched with three Context7 commands against `/websites/godotengine_en_4_7`. Two typed probe scripts under `artifacts/local/tasks/S0-07/probe/` confirmed every unverified API on the pinned binary before the owner was written. The proof was then written, run until every case passed, and committed. The executed evidence, commands and exit codes are on the S0-08 page.

## Evidence limits

TADR-004 line 38, verbatim: "Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability." This proof asserts ordering, file state and byte identity inside one process on one Linux host. It does not assert that `flush` reaches the device, directory-entry durability after rename, rename-over-existing semantics on Windows or macOS, single-writer exclusion between processes, or any real projection field. The rename replacing an existing file was observed once on Linux (`probe-api.txt` line 35) and is not a portability claim.

Drift tripwires the executed cases pin, so a later paper or code change trips a visible failure:

1. Acknowledge follows the rename, not the flush. `commit_path` refuses `acknowledge` before `commit` and records it after. Validation reads the temp bytes from disk, not the dictionary.
2. A valid, newer, unrenamed temp carrying a lifecycle fact blocks automatic resumption. `interruption_ambiguous` fails if "prefer committed" ever silently becomes "resume committed".
3. Generation monotonicity is a commit-time rejection, not an identity claim. `lifecycle_spent` fails if an older generation can be staged over a newer one.
4. JSON number typing is a boundary cast. `roundtrip` fails if `generation` reaches the envelope as a float or the re-serialised text drifts.
5. Transaction convergence is executed, not stated. `converged` fails if a duplicate delivery rewrites `save.json` or bumps the generation.
