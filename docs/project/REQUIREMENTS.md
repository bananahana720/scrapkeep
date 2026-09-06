# Requirements and scope

Status as of 5 September 2026. These IDs map confirmed direction to current scope; [publisher discovery](../DISCOVERY.md) contains the original detail. “Implemented” describes the referenced proof, not the complete game. [Increment 01](INCREMENT-01-lightning-playtest.md) is implemented and has passed the recorded technical checks. Human handling/readability and successful physical capture remain open in the [verification record](../LIGHTNING-VERIFICATION.md).

| ID | Requirement | State and evidence |
| --- | --- | --- |
| R01 | Rolling, collecting and impacts remain central; the animal stays enclosed and growth feels powerful and playful. | Implemented for the bounded lightning encounter; [technical evidence and playtest limits](../LIGHTNING-VERIFICATION.md). |
| R02 | Mouse-controlled close third-person view, focused aim, double jump and controlled enemy rebounds; ordinary growth still fits routes. | Implemented for the bounded lightning encounter; [technical evidence and playtest limits](../LIGHTNING-VERIFICATION.md). |
| R03 | Dense waves combine readable enemy commitments, useful spatial counters and height-aware attacks. | Implemented for the bounded lightning encounter; [technical evidence and playtest limits](../LIGHTNING-VERIFICATION.md). |
| R04 | Collection visibly changes the machine and its behavior. | Shear, Brace, Ground Loop, Echo and automatic companion unlock implemented; [play guide](../LIGHTNING-PLAYGUIDE.md). |
| R05 | Preserve the existing demo during the new proof. | Both entries verified; [ADR 0001](../adr/0001-two-playable-entries.md). |
| R06 | Prove satisfying solo play before co-op. | Confirmed direction; solo proof implemented, co-op deferred. |
| R07 | Four class fantasies remain the direction; first implement a compact lightning caster kit. | Lightning kit implemented; additional classes remain later work. [Evidence](../LIGHTNING-VERIFICATION.md). |
| R08 | Accurate aimed attacks and optional full transformations; shared modifiers apply across compatible equipment and exceptional builds may dominate. | Accurate attack descriptors, Ground Loop and shared Echo implemented. Broader class-replacing transformations remain later work. [Evidence](../LIGHTNING-VERIFICATION.md). |
| R09 | Quick autonomous class devices and one main loot-built companion; a priming companion demonstrates the first increment. | Implemented for the bounded lightning encounter; [technical evidence and playtest limits](../LIGHTNING-VERIFICATION.md). |
| R10 | Frequent abilities and ultimates charged through useful class-specific actions. | Implemented for the bounded lightning encounter; [technical evidence and playtest limits](../LIGHTNING-VERIFICATION.md). |
| R11 | Themed 30–45 minute expeditions with exploration, combat/defense encounters, branches and bosses. | Confirmed direction; short orchard proof is not this expedition. |
| R12 | Between runs, unlock options and challenges while rebuilding combat power within each run. | Confirmed direction; expanded progression pending. Do not inherit baseline progression automatically. |
| R13 | Increasingly enormous battle consequences while keeping ordinary growth within designed routes. | One large enemy demonstrates scale; giant player transformations undecided. |
| R14 | Free/local tools by default, with explicit decisions for new external services. | Current runtime uses Three/Vite, local assets and synthesized sound; [asset record](ASSETS.md). |
| R15 | Readable combat HUD and a toggleable character, equipment, companion, map and settings dashboard; reconfigure acquired items between fights. | Implemented and inspected at both required resolutions, including keyboard navigation; [verification](../LIGHTNING-VERIFICATION.md). |

## Change rule

Andrew's later explicit direction can change these requirements. Record the changed requirement and its impact before implementing dependent scope. Proposed boss families, concept images, paper encounters and market analogies do not automatically become approved production content. Exact constants and interfaces remain in code and the build contract.

Close a requirement for a build only with linked evidence of its actual acceptance. Distinguish unit tests, browser input, staged fixtures, hardware measurements and human playtests.
