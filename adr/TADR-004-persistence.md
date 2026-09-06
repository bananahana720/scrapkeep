# TADR-004. Local save format and durable transitions

Status: **Accepted engineering direction.** Andrew treated the architecture as settled and approved execution preparation on 6 September 2026. This is not authorization to build.

Date: 6 September 2026. Depends on [TADR-002](TADR-002-runtime-model.md) and [TADR-003](TADR-003-content-pipeline.md).

## Context

[Runs, regions, exits and saves](../BIBLE.md#runs-regions-exits-and-saves) requires completed levels, the build, resolved rewards and already offered choices to survive reload, with continuation at the next entrance. One standard revival is available. Reload cannot restore a spent revival or resurrect a terminal run.

[Discoveries](../BIBLE.md#55-what-a-discovery-changes) persist as knowledge; current equipment, tree progress and active bonuses are rebuilt each run. The exact mid-level interruption policy and revival health/placement remain open. Current orchard settings and baseline progress records do not implement this full-run contract.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| Versioned UTF-8 JSON aggregate with coordinated complete-generation writes | **Recommended** | Makes profile, checkpoint and run lifecycle one inspectable logical transaction without replaying a general event history. |
| JSON snapshots plus a durable transition journal | **Rejected as a mandatory baseline** | Can express the same lifecycle guarantees, but adds replay, compaction and multi-record recovery work before measured save size or write cost requires it. |
| Embedded transactional database | **Rejected for this baseline** | Offers transaction machinery but adds a database dependency and migration surface for a small local aggregate whose scale is still unmeasured. Reconsider if the file protocol or measured workload warrants it. |
| Whole-scene or engine-object serialization | **Rejected** | Couples persistent identity to object lifetimes and scene structure, and accidentally commits to restoring transient mid-level state. |

## Decision

Recommend a **versioned JSON save aggregate** under one persistence owner. It contains permanent profile progress, the active run identity, its latest completed-level checkpoint and current durable lifecycle facts. Preferences are a separate versioned record because changing sound or UI scale must not rewrite gameplay progress.

The checkpoint projection retains build selections, owned equipment, companion assembly, resolved rewards, accepted route/generation decisions, necessary random-generator state, stable offered choices and the next entrance. The precise device carry-over fields depend on the open device lifecycle rule. Persist actual offered options; a seed alone cannot justify rerolling them. Rebuild derived stats and active recipe bonuses from the restored selections and compatible content. Persist discovery knowledge once, without turning it into an extra combat bonus.

The envelope identifies its schema version, gameplay content revision, generation and transaction identity. One owner stages a complete candidate, validates it, commits it through a qualified filesystem protocol, and only then acknowledges the transition as durable. Reward settlement and its checkpoint/profile effects commit together. Duplicate delivery of the same transaction converges on the existing result.

**Checkpoint timing and lifecycle timing differ.** Spending the standard revival commits a new aggregate containing the spent flag, even if it retains the previous spatial checkpoint. Terminal defeat commits that run's closed status before another playable state can resume. A checkpoint predating either fact cannot override it. Companion assistance cannot create a second standard revival.

On a failed critical write, hold the transition and show a recoverable save error. Do not report successful saving or continue through a completed revival/terminal transition whose durability is unknown. This does not select a location or health value after an unfinished-level interruption. That product rule remains open, while spent-revival and terminal authority must survive under any selected rule.

Use explicit migrations between supported schema/content versions, validate the migrated result and preserve the original until the new generation commits. Unknown newer formats, unresolved IDs and incompatible content fail visibly without overwriting the source. Engine nodes, live pointers, render transforms, particles, audio voices and input-held state are not durable save identities.

## Consequences

Writing a small complete aggregate avoids mandatory event sourcing but still requires a real transaction protocol. Temporary files, a rename, a checksum or a backup alone do not prove power-loss durability. The later design must specify write ordering, flush/commit behavior, recovery evidence and single-writer ownership for each target OS.

Recovery must not silently choose an older living generation when a newer spent-revival or terminal result may exist. Preserve ambiguous/corrupt records and refuse automatic resumption unless lifecycle continuity can be established. Unsupported data can remain inspectable without becoming playable. Local persistence cannot prevent deliberate restoration of every file from an older copy; this is ordinary save consistency, not an online anti-cheat authority.

Keep existing browser storage and historical proof data intact. Importing or retiring those records requires a separate explicit policy. An engine-independent record format helps replacement, but changing what a lifecycle state means still needs migration work.

## Later qualification and reconsideration

Test interruption at every commit boundary for reward resolution, offered choices, revival use and terminal defeat. Test duplicate delivery/reload, failed writes, corruption and conservative backup recovery, unknown schema/content versions, migrations and repeated equipment/recipe reconstruction. Every authored type and mutable save projection needs the round-trip coverage specified in [TADR-003](TADR-003-content-pipeline.md).

Step 0 selects the logical format and ownership, not a proven storage implementation. If later qualification shows the complete-file protocol is less reliable or maintainable than an embedded database, amend this ADR before implementation expands. Never relax the Bible's death/reward invariants to preserve a preferred format.
