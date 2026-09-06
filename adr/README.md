# Accepted engineering direction

**Five accepted architecture decisions. 6 September 2026.**

Andrew approved [BIBLE.md](../BIBLE.md) as the source of truth for what the game is. These decisions define the engineering direction for that game. They do not approve implementation, resolve product details left open in the Bible, or replace the working browser proofs.

## Settled decisions

| ADR | Accepted choice | Main consequence |
| --- | --- | --- |
| [TADR-001. Engine, language and platforms](TADR-001-engine-language-platforms.md) | Godot 4.7.2 standard edition, typed GDScript, Windows 11 x64 and Linux x64 qualification targets. | A substantial rewrite; one native authoring/runtime toolchain with deliberate Godot dependence. |
| [TADR-002. Runtime model](TADR-002-runtime-model.md) | Hybrid scene composition and typed gameplay records, one session owner and one encounter tick coordinator. | Explicit simulation authority without a general ECS; tests and physical-world behavior remain engine-hosted. |
| [TADR-003. Content pipeline](TADR-003-content-pipeline.md) | Typed text Resource definitions, separate scene/presentation assembly, stable domain IDs and validated versioned catalogues. | Native authoring with strict separation of shared definitions from mutable run state. |
| [TADR-004. Persistence](TADR-004-persistence.md) | Versioned JSON aggregate containing profile, checkpoint and current run lifecycle, committed as one generation. | Revival use and terminal outcomes become durable independently of spatial checkpoint timing. |
| [TADR-005. Networking scope](TADR-005-networking-scope.md) | Offline single-player. No local or online multiplayer infrastructure. | A complete local run, with future connected/co-op features requiring new product and ownership decisions. |

All five statuses are **Accepted engineering direction** under Andrew's instruction to preserve the settled architecture. Each ADR contains context, options, a decision, consequences, at least two explicitly rejected alternatives and later qualification needs. TADR IDs distinguish this production proposal from [existing prototype ADRs](../docs/adr/README.md). The existing implementation remains governed by its current contracts until an explicit migration/consolidation decision.

## Why this combination

Two Astra workers produced materially different complete proposals. One used an engine-independent C# rules library and JSON content. The other used typed GDScript, native Resources and explicit session ownership. The coordinator read both, and a fresh Astra reviewer compared them against Bible fidelity, ownership/testability, content/save compatibility, maintainer simplicity and migration/evidence honesty.

The engine-native proposal is the base. Its explicit ownership can satisfy the Bible without maintaining another physical-world translation layer. The coordinator adopted two bounded ideas from the C# proposal: one complete save aggregate instead of a mandatory transaction journal, and explicit qualification of collision-query ordering, coordinate conversion and contact interpretation. The final design does not combine both runtime models or both save protocols.

The comparison also caught omissions in both candidate documents. The final ADRs explicitly compare ECS/hierarchy/hybrid, named save/storage formats, and none/local/online player scope. Focus-loss wording preserves explicit input clearing and prepared-action cancellation. These are document corrections, not implemented behavior.

## Assumptions and remaining decisions

The engine version, language and two target OS families above are settled direction. Their implementation still requires qualification. Distribution/driver minimums, exact hardware, controller support evidence and renderer choice remain unqualified. No frame, memory, load-time or asset-size budgets have been guessed at this gate. Those numbers belong in the later Constraints section and its decisions list, clearly marked as proposed until measured.

The Bible's [open system details](../BIBLE_DECISIONS.md#system-gaps-carried-from-planning) remain open. They include material/milestone allocation, node effects and kits, route/generation policy, chaos limits, attunement/recipes, companion/device lifecycle, revival health/placement and unfinished-level interruption. The ADRs preserve their required boundaries without assigning missing costs, capacities, probabilities or timings.

## Completed Step 0 checks

A fresh **gpt-6-astra, high reasoning** reviewer returned **PASS+NOTES** for document readiness, with no required fixes. This is one independent source/prose opinion at evidence level 2. Its remaining notes concern controlled repeatability versus cross-platform determinism, shared Resource isolation and filesystem durability. Those mechanisms need later qualification and are not claimed to work here.

The coordinator checked all five actual ADR files for required structure and at least two rejected options each. All 47 local links and heading anchors in this folder resolved. The existing `npm run check:project` check passed for 84 project Markdown files, 539 file links and package/lock metadata. The approved Bible body and frozen Art Direction were preserved; only approval metadata changed. Game source, assets, test/tool code and dependencies remain unchanged. The meaningful decisions are in the existing [decision trail](../docs/decisions.tsv).

## Review boundary and next step

Step 0 is document and source review only. No engine, package, game code, schema, content importer or runtime save implementation was created. No build, controller trial, performance benchmark or crash-recovery qualification was run. Approval metadata in the Bible and project desk records Andrew's latest instruction; it does not choose any still-open art direction variants.

The ADR review gate is superseded by Andrew's settled-architecture instruction. The [execution backlog](../BACKLOG.md), [operating manual](../ORCHESTRATOR.md) and [tracking board](../TRACKING.md) now govern preparation and dispatch. The proposed first sprint covers foundation contracts only. Per-system pages, TECH_BIBLE.md assembly, the complete engineering decisions list and the full AUDIT_REPORT.md follow as separate tasks. They have not been produced. Native qualification still requires separate build authorization.
