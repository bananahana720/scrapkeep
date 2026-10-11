# Gunfire Reborn comps research (index)

Reference game for hand-authored room pools, a visible-trigger optional vault, and a weapon-plus-scroll build system in a stylized first-person roguelite. Scrapkeep borrows relationships, not content (BIBLE.md AD-10). Each note carries an evidence line, a parameter table with a source per row, a Mermaid diagram, and a lab measure. Study inputs: the public wiki (read by scouts, file and line cited), the shipped data tables (234 non-localization text assets, 231 of them JSON, counts and schemas, level 4 at measurement), 118 decoded stage-chunk files (footprint statistics only), and metadata over all 3,478 asset bundles (counts and dimensions, nothing exported). The game's logic is native code with encrypted metadata and was not read; every mechanic statement comes from the wiki or the tables and says so. The borrow list that ties these notes to the Bible is in [../README.md](../README.md); the three-game map comparison started here is [../maps-compared.md](../maps-compared.md).

Map cluster:

- [stage-anatomy.md](stage-anatomy.md): slots and level pools, the room chain, the vault's visible trigger and four kinds, events once per act, hazards that clear with the room, measured chunk footprints against Risk of Rain 2; where Gunfire's corridor is the opposite of Scrapkeep's open stage. Lead note.
- [run-pacing-and-economy.md](run-pacing-and-economy.md): acts, difficulty tiers and the Reincarnation ladder, copper and soul economies, trader and crafter, chest tiers, the between-run tree.

Systems cluster:

- [weapons-and-inscriptions.md](weapons-and-inscriptions.md): weapon classes, inscription slots that grow with stage, normal, rare, exclusive and paired inscriptions, the crafter's enhance and etch economy.
- [scrolls-and-synergies.md](scrolls-and-synergies.md): four tiers (203 scrolls), the cursed scroll as a pure downside that other scrolls pay out on, enhancement on the top difficulty, offer sources and category spread.
- [elements-and-fusion.md](elements-and-fusion.md): three elements, their statuses, the fusion grid, damage order and resistance stacking.
- [heroes-and-ascensions.md](heroes-and-ascensions.md): hero identity as stat spread plus skill pair plus weighted pick pool; three-level ascensions; the in-run tree seen in the tables.
- [enemies-and-bosses.md](enemies-and-bosses.md): enemy families per act, elite affixes, boss phases, the combat-force field and skill lists, what reads at range.
- [production-budgets.md](production-budgets.md): measured triangle, bone, texture and clip budgets by category, three-way against Risk of Rain 2 and the asset forge's bands.
- [data-tables.md](data-tables.md): the shipped JSON tables: stage slots and level pools, states, the in-run tree, and what is absent (combat stats, spawn waves).
- [provenance.md](provenance.md): the middleware roles bought (audio, navmesh, input, anti-cheat), license posture, two OFL fonts worth fetching upstream.
