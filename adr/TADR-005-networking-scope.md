# TADR-005. Networking and player scope

Status: **Accepted engineering direction.** Andrew treated the architecture as settled and approved execution preparation on 6 September 2026. This is not authorization to build.

Date: 6 September 2026. Applies to the initial standalone production game.

## Context

[Game identity](../BIBLE.md#game-identity) is solo-first. [HUD/dashboard interaction](../BIBLE.md#hud-dashboard-and-settings) and [run continuity](../BIBLE.md#runs-regions-exits-and-saves) assume one player's choices, local progression and a usable solo pause. The Bible establishes no shared reward, co-op camera, player revival pool, matchmaking or server authority rules.

An architecture should identify the accepted scope now. Local co-op also changes game ownership even when it needs no network transport.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| None. Offline single-player authority | **Recommended** | Matches the defined player fantasy and leaves a complete run usable without an external service. |
| Local shared-device multiplayer, including couch/split-screen co-op | **Rejected for initial scope** | Requires decisions about cameras, device/player assignment, pause, simultaneous upgrades, rewards and the revival rule. Those are new product contracts. |
| Online multiplayer, including LAN or internet host/client co-op | **Rejected for initial scope** | Adds shared authority, synchronization, disconnect and recovery rules alongside the unresolved co-op design. Transport support alone does not resolve them. |

## Decision

Recommend **offline solo play with no networking subsystem**. [TADR-002](TADR-002-runtime-model.md) has one local simulation authority; [TADR-004](TADR-004-persistence.md) owns local run/profile continuity. Do not add accounts, lobbies, replication, server deployment or speculative rollback/lockstep infrastructure.

Commands, scoped presentation events, stable IDs and seeded generation exist for explicit ownership, content, saving and testing. They are not a promise that multiplayer can later be added cheaply. Physical-world results are not claimed deterministic across machines.

Cloud saves, cross-device profile merging, leaderboards, telemetry services or downloadable service-driven progression are also outside this proposed architecture. They require their own scoped decision if requested. Existing browser lead-capture history remains preserved and does not become a production-game dependency.

## Consequences

Solo pause can stop authoritative gameplay while menus remain interactive. The initial save authority and failure model stay local. There is no server operational burden, account gate or connectivity requirement for completing a run.

Adding local or online multiplayer later can alter timing, input ownership, pause, combat reconciliation, run generation, rewards and persistence. This proposal accepts that future redesign cost. It does not scatter speculative interfaces through every system to conceal it.

The explicit rejected options are scope choices, not claims that the selected engine cannot support multiplayer. A later proposal must first settle the shared player experience, then revisit this ADR and every affected ownership/save boundary.

## Later qualification and reconsideration

In an authorized implementation, start, play, save, resume and finish with network access unavailable. Verify that pausing/menu focus cannot advance combat or produce accidental actions. No such runtime test occurred in this document-only Step 0.

Reopen this ADR only for an approved multiplayer or connected-service requirement. A worker adding a dependency must not silently convert offline solo into an account- or network-dependent game.
