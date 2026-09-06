# TADR-003. Authored content and runtime admission

Status: **Accepted engineering direction.** Andrew treated the architecture as settled and approved execution preparation on 6 September 2026. This is not authorization to build.

Date: 6 September 2026. Depends on [TADR-001](TADR-001-engine-language-platforms.md) and [TADR-002](TADR-002-runtime-model.md).

## Context

The Bible defines [areas](../BIBLE.md#3-maps--areas), [character candidates](../BIBLE.md#4-characters), [weapons/items](../BIBLE.md#5-weapons--items) and [core systems](../BIBLE.md#6-core-systems). Workers need one inspectable definition source without mistaking candidate art or prototype tuning for approved content.

[Four-slot progression](../BIBLE.md#four-slots-and-milestone-progression) fixes one root, then two, four and eight endpoints in each tree. [Fixed secrets](../BIBLE.md#themed-loot-attunement-and-fixed-secrets) and [stable run choices](../BIBLE.md#runs-regions-exits-and-saves) make identity and compatibility durable concerns.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| Typed Godot Resources in text `.tres` files, with separate scene/presentation assembly | **Recommended** | Uses the selected editor/runtime directly while retaining inspectable definitions and stable domain IDs. |
| External JSON gameplay definitions converted into engine data | **Rejected for this baseline** | Strong portability and generic tooling, but adds conversion and parallel schema maintenance while gameplay already depends on Godot. JSON remains the save format. |
| Gameplay content embedded in actor code and arbitrary scene overrides | **Rejected for this baseline** | Makes ordinary content changes code changes and disperses tree, recipe and compatibility rules across unrelated files. |

## Decision

Recommend **typed custom Resources saved as reviewable text `.tres` definitions**, with `.tscn` scenes for composition and presentation. Godot's [Resource documentation](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html) describes native Inspector editing and text/binary serialization. Keep definitions small enough to assign to individual workers. Use reviewed behavior identifiers for complex effects rather than inventing a content scripting language.

Each gameplay definition has a stable ID independent of display name, path or engine resource identifier. A catalogue resolves these IDs. Engine paths and engine-generated IDs are implementation details, not durable save identity. Character roles, attacks, upgrades, encounters, generation policies, devices, companion parts and recipes must receive an explicit schema or an explicit embedded-record treatment in the later content coverage matrix.

The proposed pipeline is source assets and authored Resources/scenes, engine import, structural/domain validation, cross-reference/semantic validation, then admission of one versioned catalogue and asset manifest for export. Gameplay values have one canonical Resource definition. A scene may reference it but cannot override damage, milestones or compatibility in a second place. Presentation and collision assembly still need explicit validation against the authoritative attack contract.

Loaded Resources are shared. Treat admitted definitions as immutable project data and create fresh mutable session records for health, tree selections, inventory and companion assembly. Immutability is an enforced rule, not a guarantee supplied by the file extension. Definition methods must not accumulate per-run state.

Admission must check every binary tree's 15 nodes, 14 edges, eight endpoints, exactly two children per nonterminal, connectivity and absence of cycles/reconvergence. It must separately validate one selected lineage per slot, weapon/mobility start access, world-one main/ultimate milestones, recipe endpoints and compatibility references. Loaded/save data still requires validation beyond GDScript type hints. Missing content or an unsupported version produces a diagnostic, not a substituted default that changes a saved build.

Editor previews may load drafts. Gameplay hot reload stages and validates a candidate catalogue before a safe encounter boundary. A failed reload keeps the current catalogue. An active saved run stays pinned to its gameplay content revision unless an explicit migration succeeds. The later mechanism must avoid mutating shared cached Resources behind an active run. Engine editor reloading alone is not that mechanism.

Retain source-asset provenance and import settings; generated imports are rebuildable outputs. An auxiliary authoring tool may emit canonical Resources, but cannot create a second independently editable truth. Reference concepts and candidate names are not automatically admitted as production content.

## Consequences

This accepts Godot dependence for authoring, validation and execution. Multi-author scene/Resource merges can be awkward, so definition ownership and serial admission matter. A later engine or format migration requires real conversion tooling even when stable IDs survive.

[TADR-004](TADR-004-persistence.md) stores content revisions and references. Releases must provide compatible definitions for supported active saves or an explicit tested migration. Workers may not silently remap missing IDs, reroll a saved offer or retire an old run as a content-cleanup shortcut. Detailed support windows remain for Persistence.

## Later qualification and reconsideration

After approval, define the schema coverage matrix and example records. Every authored type must round-trip through its Resource/scene codec; every mutable save projection must round-trip through the JSON persistence codec. Types omitted from run saves need an explicit rationale, such as immutable definitions resolved by version and ID or transient presentation reconstructed on load. This makes the user's round-trip audit traceable without serializing engine assets into saves.

Qualify shared-definition isolation, exported asset references, malformed/cross-linked content rejection, failed reload retention, pinned-run compatibility and a migrated definition/save pair. No schema, importer, hot reload or round-trip test has been implemented in Step 0. Revisit the format if real authoring/merge friction or independent tooling requirements outweigh native integration.
