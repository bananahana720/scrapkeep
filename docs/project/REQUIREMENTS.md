# Requirements and scope

Status as of 5 September 2026. These IDs map confirmed direction to current scope; [publisher discovery](../DISCOVERY.md) contains the original detail. “Implemented” describes the first proof. It does not mean the complete game has shipped.

| ID | Requirement | State and evidence |
| --- | --- | --- |
| R01 | Rolling, collecting and bumping define the hero; the cute animal remains inside accumulated scrap. | Implemented in proof; [enclosure and input checks](../FIRST-BUILD-VERIFICATION.md). Human feel pending. |
| R02 | Close third-person view; ordinary growth still fits routes. | Implemented in proof; bounded radius and ramp in [contract](../FIRST-BUILD-CONTRACT.md). |
| R03 | Distinct enemy motions have readable commitments and useful movement/attack counters. | Implemented Snipcart, Spreadleg and one Pruner arm; [tests and visual limits](../FIRST-BUILD-VERIFICATION.md). Difficulty pending. |
| R04 | Collection visibly changes the machine and its behavior. | Shear, Brace and one following companion implemented; [play guide](../FIRST-BUILD-PLAYGUIDE.md). |
| R05 | Preserve the existing demo during the new proof. | Both entries verified; [ADR 0001](../adr/0001-two-playable-entries.md). |
| R06 | Prove satisfying solo play before co-op. | Confirmed direction; solo proof implemented, co-op deferred. |
| R07 | Four distinct class fantasies: grapple, hover/mortar, cyborg laser, lightning caster. | Confirmed direction; full class implementation outside first proof. |
| R08 | Isaac-style transformative combinations, aimed high-damage attacks, class-specific and general upgrades. | Charge-release baseline implemented; class/item combination system pending scope. |
| R09 | Quick thematic autonomous deployments; loot-assembled companions that prime, support and intervene. | One earned priming companion is a partial proof; construction, recipes, buffs and clutch logic pending. |
| R10 | Low cooldown abilities and ultimates charged through class-specific actions. | Burst demonstrates low cooldown; class ultimates pending. |
| R11 | Themed 30–45 minute expeditions with exploration, combat/defense encounters, branches and bosses. | Confirmed direction; short orchard proof is not this expedition. |
| R12 | Between runs, unlock options and challenges while rebuilding combat power within each run. | Confirmed direction; expanded progression pending. Do not inherit baseline progression automatically. |
| R13 | Increasingly enormous battle consequences while keeping ordinary growth within designed routes. | One large enemy demonstrates scale; giant player transformations undecided. |
| R14 | Free/local tools by default, with explicit decisions for new external services. | Current runtime uses Three/Vite, local assets and synthesized sound; [asset record](ASSETS.md). |

## Change rule

Andrew's later explicit direction can change these requirements. Record the changed requirement and its impact before implementing dependent scope. Proposed boss families, concept images, paper encounters and market analogies do not automatically become approved production content. Exact constants and interfaces remain in code and the build contract.

Close a requirement for a build only with linked evidence of its actual acceptance. Distinguish unit tests, browser input, staged fixtures, hardware measurements and human playtests.
