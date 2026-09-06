# Requirements and scope

Status as of 5 September 2026. These IDs map confirmed direction to current scope; [publisher discovery](../DISCOVERY.md) contains the original detail. “Implemented” describes the referenced proof, not the complete game. [Increment 01](INCREMENT-01-lightning-playtest.md) is approved and in progress; its acceptance is not yet claimed.

| ID | Requirement | State and evidence |
| --- | --- | --- |
| R01 | Rolling, collecting and impacts remain central; the animal stays enclosed and growth feels powerful and playful. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R02 | Mouse-controlled close third-person view, focused aim, double jump and controlled enemy rebounds; ordinary growth still fits routes. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R03 | Dense waves combine readable enemy commitments, useful spatial counters and height-aware attacks. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R04 | Collection visibly changes the machine and its behavior. | Shear, Brace and one following companion implemented; [play guide](../FIRST-BUILD-PLAYGUIDE.md). |
| R05 | Preserve the existing demo during the new proof. | Both entries verified; [ADR 0001](../adr/0001-two-playable-entries.md). |
| R06 | Prove satisfying solo play before co-op. | Confirmed direction; solo proof implemented, co-op deferred. |
| R07 | Four class fantasies remain the direction; first implement a compact lightning caster kit. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R08 | Accurate aimed attacks and optional full transformations; shared modifiers apply across compatible equipment and exceptional builds may dominate. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R09 | Quick autonomous class devices and one main loot-built companion; a priming companion demonstrates the first increment. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R10 | Frequent abilities and ultimates charged through useful class-specific actions. | Earlier proof evidence above remains historical; revised behavior is approved in [increment 01](INCREMENT-01-lightning-playtest.md), implementation and verification in progress. |
| R11 | Themed 30–45 minute expeditions with exploration, combat/defense encounters, branches and bosses. | Confirmed direction; short orchard proof is not this expedition. |
| R12 | Between runs, unlock options and challenges while rebuilding combat power within each run. | Confirmed direction; expanded progression pending. Do not inherit baseline progression automatically. |
| R13 | Increasingly enormous battle consequences while keeping ordinary growth within designed routes. | One large enemy demonstrates scale; giant player transformations undecided. |
| R14 | Free/local tools by default, with explicit decisions for new external services. | Current runtime uses Three/Vite, local assets and synthesized sound; [asset record](ASSETS.md). |
| R15 | Readable combat HUD and a toggleable character, equipment, companion, map and settings dashboard; reconfigure acquired items between fights. | Approved in [increment 01](INCREMENT-01-lightning-playtest.md); implementation and verification in progress. |

## Change rule

Andrew's later explicit direction can change these requirements. Record the changed requirement and its impact before implementing dependent scope. Proposed boss families, concept images, paper encounters and market analogies do not automatically become approved production content. Exact constants and interfaces remain in code and the build contract.

Close a requirement for a build only with linked evidence of its actual acceptance. Distinguish unit tests, browser input, staged fixtures, hardware measurements and human playtests.
