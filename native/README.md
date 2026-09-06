# Native proof scaffold

This directory is the smallest Godot 4.7.2 project that can prove the pinned editor boots headless with typed GDScript enforced. It exists for prepare-stage card S0-01 and for the hello-world proofs that follow it (S0-04 to S0-08); S0-04 is the first proof under `proofs/`. It holds no game code, scene, asset, save or renderer choice.

The path `native/` is provisional. HF-01 ratifies the native root and its path families and may rename this directory.

## Command

```sh
npm run native:smoke
```

Run it from the repository root. The runner is `scripts/native-smoke.mjs`. It uses `GODOT_BIN` when set and otherwise the install path in [the toolchain record](../docs/tech/native-toolchain.md).

## Files

`project.godot` names the project `scrapkeep-native-proofs`, tags the 4.7 feature and sets the static-typing warnings below to Error. It sets no renderer key.

`tests/smoke_boot.gd` is fully typed, extends `SceneTree`, prints `SCRAPKEEP_SMOKE <version> typed` and calls `quit(0)`. The version token is built from `Engine.get_version_info()` so it matches the binary's `--version` output.

`tests/fixtures/untyped_negative.gd` declares one variable without a type. The engine must refuse to load it.

## Typing keys

`project.godot` sets these keys under `[debug]` to the value 2, which the engine reads as Error.

- `gdscript/warnings/untyped_declaration`
- `gdscript/warnings/inferred_declaration`
- `gdscript/warnings/unsafe_property_access`
- `gdscript/warnings/unsafe_method_access`
- `gdscript/warnings/unsafe_cast`
- `gdscript/warnings/unsafe_call_argument`

The 4.7 documentation fetched for this card (`artifacts/local/tasks/S0-01/ctx7-godot.txt`, query 1) names `UNTYPED_DECLARATION`, `INFERRED_DECLARATION` and the `UNSAFE_*` family as the typed-GDScript warnings, says they are off by default and live under Project Settings, Debug, GDScript, and says individual warnings can be configured to act as errors. The `debug/gdscript/warnings` property group is the ProjectSettings home for them. The value 2 and the `untyped_declaration` key spelling were confirmed by running the engine, because the fetched excerpts do not show the text-format values; the probe in `artifacts/local/tasks/S0-01/probe-warning-key.txt` shows the untyped fixture loading with no key and being refused with `untyped_declaration=2` alone. The other five spellings follow the documented warning names and have no negative fixture yet. `inferred_declaration` is stricter than TADR-001 line 27 requires; it is a scaffold choice that HF-01 or the engineering handoff may relax.

## What it proves and does not prove

It proves that the pinned binary boots headless on this Linux host, enforces the typing keys, names no networking class, and boots again with the network unavailable. It does not prove a window, renderer, input device, scene, save, export, another operating system, controller feel or performance. Nothing here is qualification evidence under TADR-001.

## Proofs

`proofs/<name>/proof_runner.gd` is a hello-world proof of one ADR rule. Each proof runs inside this project; there is no second `project.godot`. The runner discovers every `proofs/*/proof_runner.gd`, runs it once expecting exit 0 and no `FAIL` line, and runs it again with `-- --inject-fault` expecting exit 1 and a `FAIL` line. Both runs appear in the report as `proof-<name>` and `proof-<name>-inject-fault` with their assertion and summary lines.

`proofs/tadr-002/` proves the TADR-002 ownership rule and the TADR-005 pause rule for prepare-stage card S0-04. Its record is [the S0-04 proof document](../docs/tech/proofs/S0-04-runtime-ownership.md). Run it alone with:

```sh
godot --headless --path native --script res://proofs/tadr-002/proof_runner.gd
godot --headless --path native --script res://proofs/tadr-002/proof_runner.gd -- --inject-fault
```

`proofs/tadr-003/` holds the S0-05 and S0-06 proof for TADR-003. `proof_runner.gd` extends `SceneTree`, loads the text `.tres` fixtures under `proofs/tadr-003/fixtures/`, runs the S0-05 cases (`roundtrip`, `identity`, `immutability`, `prefix`) and the S0-06 cases (`rule_accepts`, `rule_rejects`, `failed_reload`, `admission_exit`), prints one `S0-0x <case> PASS|FAIL <detail>` line per case and a final JSON summary, and exits 0 when every case passes, 1 on any `FAIL` and 3 on a harness error. Run it with `--headless --path native --script res://proofs/tadr-003/proof_runner.gd`; append `-- --inject-fault` to bypass the admission rule and get the expected `FAIL` line and exit 1. The definitions use an untyped `const X = preload(...)` to reference each other because a headless `--script` run has no editor class cache, so `class_name` does not resolve across files. Contracts, probed APIs and limits are in [the S0-05 page](../docs/tech/proofs/S0-05-content-identity.md) and [the S0-06 page](../docs/tech/proofs/S0-06-content-admission.md).

`proofs/tadr-004/` is the TADR-004 save-owner hello world (cards S0-07 and S0-08). Run it with `--headless --path native --script res://proofs/tadr-004/proof_runner.gd`; add `-- --inject-fault` to prove the runner reports a missing newer-schema rejection with exit 1. Every case prints `S0-07 <case> PASS|FAIL <detail>` and the run ends with one `SUMMARY` JSON line. Exit 0 means every case passed, 1 an assertion failure, 2 an environment failure and 3 a harness error. Run directories go under `artifacts/local/proofs/tadr-004/<run-id>/`, never `user://`. Fixtures under `proofs/tadr-004/fixtures/` are copied per case and never mutated in place. The design and API receipt are in [the S0-07 page](../docs/tech/proofs/S0-07-save-owner.md) and the executed evidence in [the S0-08 page](../docs/tech/proofs/S0-08-save-evidence.md). Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability.

## Reuse for later proofs

Later proofs can add a `tests/<name>.gd` script that extends `SceneTree`, keep every declaration typed, print one marker line and call `quit(code)`. Run them the same way with `--headless --path native --script res://tests/<name>.gd`, and read the exit code directly rather than through a pipe.

A proof with several scripts goes under `proofs/<name>/` with a `proof_runner.gd` that extends `SceneTree`, so the smoke runner discovers it. Patterns that S0-04 confirmed on the pinned binary and that later proofs can copy:

- Build the tree in `_initialize()`, not `_init()`; `root` is valid there and nodes added there receive their callbacks from the first frame.
- Start a coroutine from `_initialize()` and sequence it with `await physics_frame`. The signal is emitted before the nodes' `_physics_process` of that frame and keeps emitting while `paused` is true, so sampling right after an `await` gives a stable frame boundary.
- Reference sibling scripts through `const Name: GDScript = preload("res://proofs/<name>/file.gd")` and use `Name` as the type. A record can preload itself to type its own copy method. Do not use `class_name`; the global class cache lives under the gitignored `.godot/` and is only generated by the editor.
- Read user arguments with `OS.get_cmdline_user_args()`; everything after `--` on the command line arrives there.
- Print one `MARKER <phase> PASS|FAIL <detail>` line per assertion and one `MARKER SUMMARY <json>` line, then `quit(code)`. The runner treats any `FAIL` line as a failure of the plain run and requires one under `--inject-fault`.
