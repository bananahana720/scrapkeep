# Records, gates, pins and epochs

## Run records

`scripts/lab/record.mjs` writes one `"scrapkeep-run/1"` record per batch or suite run (`artifacts/jev-lab-2026-09-25/plan.md:140-149`).

- Each run claims its own directory by creating `artifacts/local/runs/<run-id>/run-owner.json` with exclusive create, so two runs never share a directory.
- `artifacts/local/runs/<run-id>/run.json` holds the identity and result, provenance (git head, branch, `dirty`, source hashes at start and end, versions, the instrument block, the Jev model, calls and token fields), config, KPIs and KRIs as `{value, n, ci}`, findings with repro commands, and limits.
- A source-hash mismatch between start and end demotes the run to `inconclusive`. This is how the records launched from a moving coordinator worktree were caught (SKL-23).
- `dirty` and the source hashes cover the declared Node source paths only (`DEFAULT_SOURCES` in `scripts/lab/record.mjs`). A sketch in another repository has its head and dirty flag stamped once at launch and is not re-hashed (SKL-21).
- Token fields stay separate, and an unreported field is `null`, never `0`.

## Gate exits

`scrapkeep gate <run> --against <pin>` runs `scripts/lab/gate.mjs`. Its exits (`scripts/lab/metrics/status.mjs`):

| Exit | Meaning | Report it as |
| --- | --- | --- |
| 0 | Pass | "matches the pin" (kinematic) or "sample size met; no rate compared" (rigid) |
| 1 | A metric past its fail limit, or a kinematic trace that differs | "behaviour differs from the pin", never "worse" (SKL-11) |
| 2 | Usage, including batches that are not like for like (scenario, arm, D, k, physics mode, max ticks) | a usage error, not a result |
| 3 | Inconclusive: too few samples, a stale baseline, a dirty tree, or a blind set under 20 | "not decided", with the reason |
| 4 | Instrument invalid: a failed control, an invalid record, or a new epoch that has not re-passed | "no reading"; nothing else in the run counts |

`scripts/play.mjs` maps a lab script that did not finish to exit 4, so a crash never reads as a red KRI. Other exits can come from the launcher: a live jev batch whose preflight fails exits 6 before any record exists (SKL-28).

Known limits of the current gate:

- Kinematic comparison is trace equality, a change detector. It does not say whether success rose or fell (SKL-11).
- The rigid path compares no rate until JL-28 (SKL-10).
- `margin_vs_scripted` is shown without a tier until JL-28 (`NOT_GATED` in `scripts/lab/gate.mjs`).
- `bench-climb` is exempt from `unreachable_scenarios` because no arm can reach it (SKL-18).

## Pins

- Cut a pin with `node scripts/lab/gate.mjs --pin <run_id> --as <name>`. The pin copies the run record and any verdict cache to `artifacts/jev-lab-2026-09-25/pins/<name>/` and omits per-trial directories, source hashes and the owner file (`PIN_OMITS`).
- Pin only a record whose instrument epoch has passed its controls and blind corpus. Scripted and random records carry no instrument identity (SKL-22).
- A pin for a build outside the harness worktree, such as `andrew-anchor` for the build Andrew played (dc94b2c), takes `--subject-commit <rev> --subject-path <path>` so the pin names the subject's commit, path and tree hash (SKL-20).
- `andrew-anchor` never goes stale. It records a human verdict, not machine evidence that ages.
- Pins in this program: `andrew-anchor`, `ball-lab-suite`, `ball-lab-scripted-dummy-knock-kinematic` and `ball-lab-scripted-dummy-knock-rigid`. The two scripted `dummy-knock` pins are re-cut when JL-21b is admitted, because its state change will read as trace divergence (SKL-22, EV-0551).
- A rigid pin with 0 successes gives the reachability check nothing to compare (`artifacts/jev-lab-2026-09-25/reviews/JL-25.md:11`); prefer a rigid pin scenario that the arm sometimes completes (design choice).

## Instrument epochs

Each new question set starts an epoch (`artifacts/jev-lab-2026-09-25/plan.md:67-70`). The identity is `instrumentIdentity()` in `tools/jev-player/decide.mjs:56-63`: question-set sha, model, confidence floor and gate version. Its `model` is the requested alias, so the epoch record under `EPOCHS_ROOT` (`tools/jev-player/preflight.mjs`) also stores `resolved_models`.

- A new question set, a gate-version bump or a move of the alias to another resolved model starts a new epoch. It stays invalid, and the gate exits 4 on it, until the live controls and the blind corpus both re-pass (SKL-28).
- The per-stage threat rule is also a named epoch for the arm comparison (SKL-15; EV-0550). A change to it makes the old pins incomparable.
- Report the resolved model, not the alias. A verdict from a model other than the batch's anchor voids the batch (`scripts/lab/harness.mjs:30-32`).
- An all-error rerun writes `<key>.error.json` beside the existing epoch record and never replaces a passed one (`tools/jev-player/preflight.mjs:391-398`; `artifacts/jev-lab-2026-09-25/reviews/JL-18b.md:23`).
- The general rules for controls, blind corpora and pre-registration are in `reactive-model-loop`; do not restate them here.

Log each epoch change as a new §5 entry in the changelog of [lessons.md](lessons.md), with the resolved model and the control and blind-corpus results that qualified it.
