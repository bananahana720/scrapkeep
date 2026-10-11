# Roboquest comps research (index)

Reference game for a tile-and-connector level generator with authored pieces, a telegraph grammar with shipped timings, and class-driven movement in a stylized first-person roguelite. Scrapkeep borrows relationships, not content (BIBLE.md AD-10). Each note carries an evidence line, a parameter table with a source per row, a diagram, what Scrapkeep borrows, what it must not copy, and a lab measure. The engine is Unreal 4.26; the game is native code, so every rule comes from the shipped tables, the measured pieces and the public wiki, never from a code path.

Map cluster:

- [stage-anatomy.md](stage-anatomy.md) (lead): levels generated from 151 authored pieces in 13 kinds; one cell of about 120 to 158 m with four closable connectors in acts 1 to 3; arenas carry spawners, airlocks carry traps and puzzles, corridors carry squad anchors; a per-act pool of special interiors; secrets with a map tell; par-time curves; difficulty that fills the same map; where the fixed-cell chain is the opposite of Scrapkeep's open stage.
- [../maps-compared.md](../maps-compared.md): the four-game comparison, completed here.

Systems cluster:

- [movement-and-feel.md](movement-and-feel.md): wiki movement values at level 2, class movement abilities with uptime arithmetic, the frame-count gap and the capture method that closes it.
- [classes-and-perks.md](classes-and-perks.md): a class as baseline stats plus a perk pool plus a movement ability; the perk table split by class; against Scrapkeep's three characters.
- [weapons-and-affixes.md](weapons-and-affixes.md): five loot categories as a clip, reload and spread envelope; affixes as weapon-local, perks as player-global; rarity counts.
- [enemies-and-telegraphs.md](enemies-and-telegraphs.md): enemy stats by chassis, the telegraph grammar in seconds, the attack-token budget, stagger, elite as a flat tier, level curves and modifiers.
- [enemy-design-grammar.md](enemy-design-grammar.md) (separable extra for the asset forge): families with one read each, production bands per family, why not to rip and resculpt, and the CC0 and CC-BY base-mesh shortlist with a provenance recipe.

Production cluster:

- [production-budgets.md](production-budgets.md): measured triangles, bones, clips and textures by category, three-way against Risk of Rain 2 and Gunfire Reborn and the forge's bands.
- [data-tables.md](data-tables.md): the 60 shipped tables and 138 curves as statistics: what they hold, what they do not, how the generator is table-driven.
- [provenance.md](provenance.md): engine, container format, middleware roles, license posture, and the retained install clone as a private modding archive outside the Scrapkeep pipeline.
