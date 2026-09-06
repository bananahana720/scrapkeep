# Check a sprint closure receipt

The coordinator records one versioned JSON receipt for the selected sprint. [The operating manual](../../../ORCHESTRATOR.md#sprint-closure) owns closure authority. [The amendment packet](amendment-request.md) owns decisions and propagation. This checker reads a receipt and local evidence. It produces a result without editing TRACKING, BACKLOG, the receipt, or its evidence.

## Receipt schema

Version 1 uses the following fields. Unknown extra fields do not grant authority or change the result. Missing required fields and invalid types fail closed.

| Field | Contract |
| --- | --- |
| `schemaVersion` | Integer `1`. |
| `sprintId` | Stable nonempty sprint ID. |
| `integratedCommit` | Full 40-hex commit tested by every required gate. The selected checkout must have that HEAD and no tracked changes. |
| `scopeKind` | `documentation-only`, `native-proof`, or `gameplay`. |
| `decisionOwner` | `Coordinator`. |
| `authorization` | `owner` is `Andrew`; `reference` identifies the actual scope authorization. |
| `previousReceipt` | `null` for the first result, otherwise the previous receipt's SHA256. Preserve the prior receipt. |
| `selectedTasks` | Nonempty array of unique delivery-task objects with `id`, positive `revision`, and `state`. Every selected delivery task must be `done`. |
| `activeLeases` | Nonnegative integer. Closure requires zero active write leases. |
| `gates` | Unique gate objects described below. Default gates cannot be omitted or marked optional. |
| `gameplay` | For a proof, `{ "applicable": false, "reason": "No playable slice" }`. Gameplay scope uses `applicable: true`, an `objective`, and nonempty `pillars` objects with unique `id` and `test`. |
| `toolchain` | Required for native proofs. Nonempty `engineVersion`, 64-hex `editorSha256`, and 64-hex `templatesSha256` identify the actual pinned toolchain. |
| `amendments` | Array of request dispositions described below. Use `[]` only when the coordinator has reconciled the real request inventory. |
| `retroActions`, `groomingChanges` | Arrays of objects containing nonempty `cause`, `disposition`, and `reference`. Empty arrays mean no changes after actual review. |
| `nextProposal` | One proposal with `status: "awaiting_review"`, `approvalOwner: "Andrew"`, a nonempty `objective`, and at most four `cards`. |

The closure-control card evaluates the delivery set. For operational Sprint 0, S0-14 completes after evaluating S0-09, S0-10, S0-11, S0-12, and S0-13. Do not include S0-14 in its own `selectedTasks`. Reconcile all writer leases before checking the receipt. The coordinator then records the result and completes S0-14 as an administrative closure action. This ordering does not excuse an incomplete delivery card.

A next-proposal card names `id`, positive `revision`, `size` of `S` or `M`, and arrays of `dependencies`, `questions`, `permittedActions`, and `acceptance`. Actions and acceptance cannot be empty. `inputReady` and `initialDispatch` are booleans. List proposed cards in dependency order. Dependencies must name completed selected tasks or earlier proposed cards. Initial dispatch permits only input-ready cards with no unresolved questions and dependencies already done. A card waiting on an earlier proposed card stays outside initial dispatch. Zero proposed cards is valid when the objective explains why none is eligible.

### Gates and evidence

A gate contains `id`, boolean `required`, `status`, and an `evidence` array. Valid gate and evidence statuses are `passed`, `failed`, `pending_evidence`, `skipped`, and `inconclusive`. An optional additional gate requires a nonempty `reason`; its evidence does not qualify required work. Mark any additional gate required by the actual authorized scope as `required: true`.

Every required gate needs at least one evidence object with all of these fields.

| Evidence field | Contract |
| --- | --- |
| `path` | Existing repository-relative file. Absolute paths and symlinks escaping the checkout are rejected. Copy external reports into the permitted local evidence directory first. |
| `sha256` | SHA256 of the file's exact bytes. A mismatch is stale evidence. |
| `sourceCommit` | Full tested commit, equal to `integratedCommit`. |
| `status` | Explicit result. A gate cannot override an evidence failure by saying `passed`. |
| `method` | Actual command or observed procedure. |
| `limits` | Concrete limits on what the observation establishes. |

Use a distinct evidence file when the result or tested commit changes. Preserve original outputs. The checker compares bytes and metadata; the reviewer checks whether the file actually supports the declared result.

For `scenario-review`, at least one evidence object requires `independent: true` and a nonempty `reviewer` identity.

For native proof `linux-local`, at least one evidence object also requires `visible: true`, `success: true`, and `exitWorked: true`. For `linux-ci`, at least one evidence object requires nonempty `runId` and `toolchainIdentity`.

For gameplay `human-playtest`, evidence must identify `kind: "human"`, `observer: "Andrew"`, and a `pillars` array listing the applicable Pillar IDs observed. Every declared Pillar needs human evidence. Keep untested applicable Pillars in the receipt so missing feedback prevents closure. Automated evidence cannot fill these fields on Andrew's behalf.

### Amendment dispositions

Every amendment names unique `id`, boolean `applicable`, `state`, `kind`, `decisionOwner`, nonempty `reason`, and `affectedCards` with `id` and positive `revision`. States are `proposed`, `accepted`, `rejected`, and `deferred`. Kinds are `implementation`, `factual`, `architecture`, and `product`. Architecture and product decisions belong to Andrew. Implementation triage and factual corrections preserving accepted decisions belong to the coordinator.

A request affecting a selected delivery card cannot be marked inapplicable. Explain why an unselected request is outside the closure scope. Applicable proposed or deferred requests remain pending. Applicable rejected requests need `decisionEvidence` and `readinessChecked: true` before the unchanged contract can resume.

An applicable accepted request needs `decisionEvidence` and a separate `propagation` object. `decisionEvidence` uses the evidence fields above and may point to a current-commit reconciliation record that cites the original decision. Preserve that original decision and its actual date and identity.

Propagation contains the following fields.

| Field | Required proof |
| --- | --- |
| `sourceCommit` | Final integrated commit containing the admitted changes. |
| `sources` | Nonempty array of authoritative source `path` and `sha256` pairs. |
| `cards` | Unique `id` and positive `revision` objects covering every affected card revision. Selected tasks must use those revisions. |
| `reviewEvidence` | Evidence object with `independent: true` and nonempty `reviewer`, tied to the final integrated contract. Its file identifies the reviewed source/card changes and affected checks. |
| `readinessChecked` | `true` after source/card propagation, independent review, affected checks, and dependency reconciliation. |

Accepted without propagation remains `pending_evidence`. An acceptance message is not an admission receipt.

## Mandatory gates

These defaults come from the accepted closure contract. They are minimums, not a complete substitute for the selected cards' verification requirements.

| Scope | Mandatory gate IDs |
| --- | --- |
| `documentation-only` | `docs`, `project`, `scenario-review` |
| `native-proof` | `docs`, `project`, `scenario-review`, `adr-harness`, `linux-export`, `windows-export`, `linux-local`, `linux-ci` |
| `gameplay` | `docs`, `project`, `automated-smoke`, `human-playtest` |

Use `npm run check:docs` for `docs` and `npm run check:project` for `project`. `scenario-review` records independent review of the applicable closeout and amendment scenarios. Native proof gates retain the actual ADR harness, exports, visible local Linux launch/exit, and CI Linux execution receipts. Windows export establishes export only. Sprint 0 sets gameplay/Pillars not applicable because it contains no playable slice.

A failed required gate or failed evidence produces `failed`. Schema and recorded-authority errors also produce `failed` because the receipt is invalid. Absent, stale, skipped, or inconclusive required evidence produces `pending_evidence`. Active leases, incomplete delivery cards, and applicable unresolved/unapplied amendments also prevent a pass. `failed` takes precedence when both kinds of issues exist.

## Run the checker

Pin the clean integrated code commit before collecting final evidence. Save the receipt and generated results under the authorized evidence paths. The receipt itself may be untracked while checking that commit.

```sh
node scripts/sprint-close.mjs artifacts/local/sprint-0/closure.json --root /absolute/path/to/tested/checkout
```

The checker prints JSON. Exit code `0` means `passed`; exit code `1` means `failed` or `pending_evidence`. Invalid JSON, an unreadable receipt, or invalid CLI arguments also return nonzero JSON. No gate is executed by this command.

The output's `receiptId` is the SHA256 of the input bytes. `closureKey` derives from the sprint ID and integrated commit. Rechecking identical bytes against unchanged checkout/evidence produces byte-for-byte identical output. A revised receipt retains its sprint/commit key while receiving a new receipt ID. Retain the preceding ID in `previousReceipt`.

After the check, the coordinator may commit TRACKING and the closure receipt. That administrative commit is not retroactively runtime-tested. Keep `integratedCommit` pointing to the tested code commit. To reproduce the check later, use a clean checkout at that commit and restore the preserved evidence files. Checking against a later HEAD produces `pending_evidence`, even if its changes were administrative.

This documentation-only skeleton is intentionally incomplete. Replace placeholders, add actual delivery cards, and attach evidence before checking it. Empty evidence prevents a pass.

```json
{
  "schemaVersion": 1,
  "sprintId": "EXAMPLE",
  "integratedCommit": "<40-hex tested commit>",
  "scopeKind": "documentation-only",
  "decisionOwner": "Coordinator",
  "authorization": { "owner": "Andrew", "reference": "<actual scope record>" },
  "previousReceipt": null,
  "selectedTasks": [{ "id": "EXAMPLE-01", "revision": 1, "state": "done" }],
  "activeLeases": 0,
  "gates": [
    { "id": "docs", "required": true, "status": "pending_evidence", "evidence": [] },
    { "id": "project", "required": true, "status": "pending_evidence", "evidence": [] },
    { "id": "scenario-review", "required": true, "status": "pending_evidence", "evidence": [] }
  ],
  "gameplay": { "applicable": false, "reason": "No playable slice" },
  "amendments": [],
  "retroActions": [],
  "groomingChanges": [],
  "nextProposal": {
    "status": "awaiting_review",
    "approvalOwner": "Andrew",
    "objective": "<one next objective>",
    "cards": []
  }
}
```

## Evidence limits

The checker verifies declared structure, gate completeness, file bytes, repository identity, and recorded roles. It cannot authenticate Andrew's approval or playtest, find omitted tasks/amendments, infer every scope-specific gate, or judge whether an evidence file supports its claim. The coordinator and independent reviewer reconcile those facts against the canonical board and authorization.

The checker grants no admission, execution authority, hardware qualification, or gameplay approval. A passing synthetic test establishes the checker behavior exercised by that fixture. It does not close a real sprint.
