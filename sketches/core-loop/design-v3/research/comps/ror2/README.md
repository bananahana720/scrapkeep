# Risk of Rain 2 comps research (index)

Reference game for open stages with a charge-the-objective loop. Scrapkeep borrows relationships, not content (BIBLE.md AD-10). Each note carries an evidence line, a parameter table with sources, a Mermaid diagram, and a lab measure. Data: `data/stage-graphs.csv` holds measured node counts, footprints and credits for 76 stages plus a few non-stage scenes (numbers and stage keys only). The borrow list that ties these notes to the Bible is in [../README.md](../README.md).

Map cluster:

- [stage-anatomy.md](stage-anatomy.md): the node graph, credits, objective eligibility, player spawn; the open-stage-with-pockets proposal. Lead note.
- [events-and-objectives.md](events-and-objectives.md): holdout charge, boss credit, shrines as trades, arena rounds, portals, music flips, the unresolved cost of staying.
- [director-and-difficulty.md](director-and-difficulty.md): difficulty coefficient, credit income, card selection, elites, spawn bands, what reads the dial.
- [run-flow.md](run-flow.md): the stage sequence with owning classes and Godot 4 equivalents.

Systems cluster:

- [companions.md](companions.md): allies and drones as one architecture, the seven gaps, and the scrap-bot crew proposal. Lead note for companions.
- [items-and-stacking.md](items-and-stacking.md): tiers, stacking families, proc chains, the damage pipeline, the scrap economy.
- [characters-and-feel.md](characters-and-feel.md): stat and skill fields, movement constants, telegraphs, hitstop, shake, damage numbers.
- [progression-and-music.md](progression-and-music.md): unlocks as teaching, the logbook, run tallies, the adaptive score's parameters.
- [architecture.md](architecture.md): catalogs, body versus master, state machines, the damage pipeline, networking, pooling, saves, with Godot equivalents.
- [production-budgets.md](production-budgets.md): measured triangle, bone, texture and clip budgets by category, compared with the asset forge's bands.
- [provenance.md](provenance.md): the middleware roles the game bought, their licenses, and the two free fonts worth fetching upstream.
