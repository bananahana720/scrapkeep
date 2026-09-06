# Verification artifacts

There are two kinds of output in this directory.

- Named build records, including `orchard-first-build/`, earlier screenshots, JSON receipts and `visual-iterations/`, are historical evidence. Their source version, test method and limitations belong in the linked verification document. Historical JavaScript snapshots are not active source.
- `local/` is disposable, ignored output from current commands. `npm run verify` writes `local/verify/`; the browser wrappers and balance probe write here by default. `ARTIFACT_DIR` can select another destination for those wrappers/probes. Do not point it at a retained build record.

Rerunning a test must not silently replace a dated claim. When retaining a new result, copy the needed files to a named build/session directory, record source hashes or a real commit, commands, date, outcome and evidence type, and link that record from the owning verification document. A PASS from a fixture is not a human playthrough.

The existing records were preserved during closeout. [Lightning verification](../docs/LIGHTNING-VERIFICATION.md) owns the new `lightning-playtest/` record. [First-build verification](../docs/FIRST-BUILD-VERIFICATION.md) remains the historical first-proof evidence owner. [Housekeeping](../docs/project/HOUSEKEEPING.md) owns this closeout. The new local verification report overwrites its own disposable previous run and records whether every planned stage ran.
