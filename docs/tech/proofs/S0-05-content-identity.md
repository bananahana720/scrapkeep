# S0-05 proof: typed Resource identity, round trip and immutability

This page records the headless proof that prepare-stage card S0-05 asked for. One typed `SlotTreeDefinition` Resource is authored as text `.tres`, loaded on the pinned Godot 4.7.2 binary, saved, reloaded, registered by stable ID, and copied into a session record. The proof code lives under [`native/proofs/tadr-003/`](../../../native/proofs/tadr-003/proof_runner.gd) and shares one runner with [S0-06](S0-06-content-admission.md). It is disposable evidence for HF-05 and HF-06a, not production content or a production path.

## Sources

- [TADR-003 § Decision](../../../adr/TADR-003-content-pipeline.md#decision), lines 23 to 33. Typed Resources as text `.tres`; a stable ID independent of display name, path or engine resource id; a catalogue that resolves IDs; admitted definitions immutable with fresh mutable session records.
- [BIBLE.md § Four slots and milestone progression](../../../BIBLE.md#four-slots-and-milestone-progression), tree shape only.
- [BACKLOG.md card S0-05](../../../BACKLOG.md#s0-05) and the design in `artifacts/ai-first-audit-2026-09-06/worker-results/B3-tadr-003.md`, Sections 1 and 2.
- [The native scaffold](../../../native/README.md) and [the toolchain record](../native-toolchain.md) for the binary, the typing keys and the run command.
- Godot 4.7 documentation fetched for this card into `artifacts/local/tasks/S0-05/ctx7-godot.txt` (three queries) and the earlier receipt `artifacts/ai-first-audit-2026-09-06/receipts/docs-godot.txt`.
- Browser precedent that this proof differs from, read only: `src/orchard/simulation.js` lines 8 to 51 and `src/heroes.js` lines 15 to 19 embed definitions and display names in code.

## Contract

`native/proofs/tadr-003/definitions/slot_tree_definition.gd` declares `class_name SlotTreeDefinition extends Resource` with four exported, defaulted, typed fields: `id: StringName`, `content_revision: int`, `nodes: PackedStringArray` and `edges: PackedStringArray` (each edge is `parent>child`). There is no cost, effect, display-name or milestone field, so no product value can be smuggled into a fixture.

`native/proofs/tadr-003/definitions/catalogue.gd` declares `ProofCatalogue`. `register(def) -> Error` refuses an id without the `proof.` prefix with `ERR_INVALID_DATA`, refuses a duplicate id with `ERR_ALREADY_EXISTS`, and records the diagnostic in `diagnostics`. `resolve(id: StringName) -> SlotTreeDefinition` returns the registered instance or `null`. `stage(candidates) -> Error` belongs to S0-06.

Fixtures are committed text files. `fixtures/placeholder_tree.tres` has id `proof.tree.placeholder`, `content_revision = 0`, nodes `n0` to `n14` and the 14 edges of a complete binary tree of depth 3. `fixtures/renamed_copy/placeholder_tree_other_name.tres` is byte-identical under a different directory and filename. The text was generated once with `ResourceSaver.save` (`artifacts/local/tasks/S0-05/probe-apis-run2.txt`) and then written by hand with `content_revision = 0` added, because the saver omits a property that equals its default.

Consumers reference the class through an untyped `const SlotTreeDefinition = preload(...)`. A headless `--script` run has no editor class cache, so `class_name` is not resolvable across files, and a `: GDScript` annotation on the constant hides static methods from the analyzer. Both facts are unverified by documentation and were established by probe (see Procedure performed).

The command is `godot --headless --path native --script res://proofs/tadr-003/proof_runner.gd`. Exit 0 means every case passed, 1 means at least one `FAIL` line, 3 means a harness error such as a fixture that did not load. The last stdout line is a JSON summary with the engine version token and case counts.

## Scenarios

Each case prints one line `S0-05 <case> PASS|FAIL <detail>`.

- `roundtrip`. The placeholder loads with every field equal to the authored value. `ResourceSaver.save` writes it to `user://s0-05-roundtrip.tres`, the source keeps its `resource_path`, the saved file begins with `[gd_resource`, and a `CACHE_MODE_IGNORE` reload of the temp file is a distinct instance with equal fields.
- `identity`. The renamed copy is a distinct instance under a distinct path with the same id. Registering the placeholder returns `OK`; registering the renamed copy returns `ERR_ALREADY_EXISTS` with a diagnostic naming the id and the refused path; `resolve` returns the first instance.
- `immutability`. A session record made with `duplicate(true)` is mutated in `nodes`, `edges` and `content_revision`. The cached definition still equals the authored values, `resolve` still returns it, a default-cache reload of the same path returns the same instance unchanged, and a `CACHE_MODE_IGNORE` reload from disk is unchanged. The detail also records that a shallow `duplicate()` shares `PackedStringArray` storage with its source on this engine (`shallow_duplicate_shares_packed_arrays=true`), observed on a fresh instance so the cached definition is never touched.
- `prefix`. An in-memory definition with id `tree.unprefixed` is refused with `ERR_INVALID_DATA`, the diagnostic names the id and the `id_prefix` check, and `resolve` returns `null`.

## Unresolved questions

- ID versus path identity. The engine cache is keyed by path, so a "resolve by ID" catalogue can silently become a dictionary of paths. The renamed-copy case is the tripwire; keep it when the catalogue moves.
- `content_revision` placement. The definition carries a per-definition `content_revision` and the catalogue carries its own `content_revision`, which `stage` bumps. TADR-004 implies the catalogue-level value is what a save pins. The proof carries both so the question stays visible; it does not decide it.
- "Immutable" versus "never mutated". The engine enforces nothing. A shallow `duplicate()` leaks packed-array mutation into the shared definition; the convention this proof demonstrates is `duplicate(true)` for session records. HF-06a should state the convention explicitly.
- Whether the production project keeps an editor-generated class cache or the preload-constant pattern. HF-01 and the engineering handoff own that choice.

## Re-verification triggers

- A different engine binary or version string than `4.7.2.stable.official.ed1daf0bf`.
- Any change to `native/project.godot` typing keys or to `slot_tree_definition.gd`.
- Moving the proof under the HF-01 native root, which changes every `res://` path in the runner and fixtures.
- A change in how session records are created (anything other than `duplicate(true)`).

## Procedure performed

All commands ran from `/home/andrew/Projects/scrapkeep-wt-S0-05` on 2026-09-06 with `/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64` (`--version` prints `4.7.2.stable.official.ed1daf0bf`). Evidence is under `artifacts/local/tasks/S0-05/`, which is ignored by git and is read from the worktree.

1. Three Context7 queries against `/websites/godotengine_en_4_7` into `ctx7-godot.txt`. They document `class_name` plus typed `@export`, `ResourceLoader.load` with `cache_mode`, `ResourceLoader.exists`, `DirAccess.open`, `FileAccess.open`, `ResourceSaver`, `Array.duplicate`, and that packed arrays are passed by reference with `duplicate()` returning an independent copy.
2. `probe_apis.gd` (`probe-apis-run1.txt`, `probe-apis-run2.txt`) generated the fixture text, and established the following APIs that no receipt documents: `ResourceLoader.CACHE_MODE_IGNORE` is 0 and `CACHE_MODE_REUSE` is 1; a default reload returns the same instance and an ignore reload a distinct one; `ResourceLoader.load` of a missing path returns `null`; `OS.get_cmdline_user_args()` returns the arguments after `--`; `quit(3)` exits the process with 3; `StringName` serializes as `&"..."`; the saver omits default-valued properties.
3. `probe_const_a.gd` and `probe_const_b.gd` (`probe-const-preload.txt`) established that `class_name` fails to resolve headless (`probe-apis-run1.txt`) and that a preload constant works. The first full runner run then showed that a `: GDScript`-typed constant hides static methods (`probe-notes.txt`, item 2).
4. `probe_duplicate.gd` (`probe-duplicate.txt`) established that shallow `duplicate()` shares packed arrays and `duplicate(true)` copies them.
5. `probe_runner_missing_fixture.gd` (`probe-harness-exit3.txt`) established the exit 3 path.
6. The S0-05-only checkpoint run (`run-s0-05-checkpoint.txt`) exited 0 with four `PASS` lines. The full run with S0-06 is recorded in the S0-06 page.

## Evidence limits

Proven on this host only: a text `.tres` round trip; an id that survives a path and filename change; a duplicate id refused; a session record that does not leak into the cached definition when created with `duplicate(true)`; refusal of an id without the `proof.` prefix.

Not proven, verbatim from the B3 design: the editor import pipeline; hot reload at a safe encounter boundary; exported asset references; `.tscn` scenes; save pinning to `content_revision`; merge friction; enforced immutability (it is a convention shown by `duplicate()`, and the shallow form fails it); anything 4.7.2-specific beyond this Linux host. Nothing here is qualification evidence under TADR-001. The temp file is written under `user://`, which this host resolves to `~/.local/share/godot/app_userdata/scrapkeep-native-proofs/`; the proof does not delete it.
