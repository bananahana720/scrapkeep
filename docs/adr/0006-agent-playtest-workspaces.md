# 0006: Named agent desktops for playtesting

Date: 6 September 2026. Status: accepted by Andrew and operational for the verified local paths.

## Context

Andrew authorized native keyboard/mouse control and delegated desktop work to accelerate game development. He wants to keep using his own input devices while agents test the game and operate supporting applications.

## Decision

Use independently managed nested Hyprland desktops under the existing Unix account. The default game desktop hosts the playtest; a separate studio desktop hosts delegated application work. Each has its own input/focus state, browser profile, persistent working directory and runtime identity. Further named desktops can be started when a concrete concurrent task needs one.

One actor claims a bounded lease per desktop. All managed control operations and lifecycle mutations share a cross-process lock. The controller retains that lock through input release. Separate desktops can proceed independently; multiple writers do not share one game's input stream.

Use exact-window AT-SPI actions when the application exposes the required capability. Use focused native input for gameplay and unsupported text controls. Semantic handles expire and are consumed once; revalidate process identity, frame membership and control capabilities before dispatch. The global emergency-stop flag is checked independently of workspace locks.

## Consequences

The installed source and operations guide own this controller. Game code remains in the repository and parallel writing agents still use disjoint Git worktrees. GUI workspace ownership does not replace source ownership.

The maintained game runner lives in `tools/agent-player/` and imports this installed controller. Each invocation builds a private production copy, opens it in a dedicated `playtest` workspace, claims ownership before lifecycle changes, and releases input before capture cleanup. It uses screenshots for combat and exact exposed accessibility controls for menus. Game/studio workspaces stay available for interactive work. The runner's evidence records source, controller and served-build identities and checks that source stayed unchanged during execution.

These workspaces share Unix authority and session services. They are not security VMs, and application launch requires checking that a distinct instance appears in the child desktop. Semantic button/editable-text success does not establish general desktop parity or skillful gameplay. The historical direct player is superseded by the maintained leased runner and must not share a managed desktop.

## Amendment 2026-09-06

The runner pins the installed controller with `tools/agent-player/controller-manifest.json`; `run.py` recomputes every controller `*.py` hash before it builds or leases, refuses to run on a mismatch unless `--allow-controller-drift` is passed, and records the outcome in its report (PS-05b).

## Revisit trigger

Revisit when a required editor/toolkit cannot expose useful controls, an application forwards to a host instance, stronger filesystem/process isolation is required, or a different compositor becomes a supported target. Keep the accepted independent-workspace behavior while changing its implementation.

Sources: [engineering scope](../project/AGENT-PLAYTEST-ENGINEERING.md), the installed desktop controller's operations guide and its named-workspace receipt (`agent-desktop/README.md` and `agent-desktop/verification/workspaces-2026-09-06/receipt.json` under the user's local share directory for codex-native-input, outside this repository).
