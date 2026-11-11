# Scrapkeep design desk

**Start with the [Art & Game Bible](../BIBLE.md).** It is the shared reference for future collaborators, with the approved revised art direction, illustrated creative proposals and remaining decisions. The research and prototype records below retain their dated scope.

5 September 2026. Andrew approved the lightning caster increment after playing the first orchard proof. The new controls, waves, equipment and dashboard are implemented; technical checks passed; Andrew's next playtest is open. The original yard remains the baseline demo at `/`. Earlier research and art retain their original evidence limits.

**Working identity:** roll a cute animal's accumulated scrap ball through a threatened world; outplay its machines, make their parts useful, and turn familiar physical actions into increasingly enormous consequences.

The [accepted notebook interview](DISCOVERY.md#accepted-notebook-interview) updates future run, progression and character direction. The [runtime blueprint](RUNTIME-BLUEPRINT.md) separates content, encounter state, run checkpoints and permanent progression. These are future systems. The lightning playtest remains unfinished human evidence; current execution priorities and assignments are recorded only in [TRACKING.md](../TRACKING.md).

## Start here

The [project desk](project/README.md) owns orientation and requirements, [BACKLOG.md](../BACKLOG.md) owns task definitions, and [TRACKING.md](../TRACKING.md) owns current status as the only execution board. Development conventions are in [CONTRIBUTING](../CONTRIBUTING.md); durable implementation choices are in the [ADR index](adr/README.md).

| To review                                                   | Open                                                                                                                                  | Status                                                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| The current orchard build                                   | [Lightning play guide](LIGHTNING-PLAYGUIDE.md) and [approved increment](project/INCREMENT-01-lightning-playtest.md)                   | Implemented; technical checks passed, human playtest next                                      |
| Historical first proof                                      | [Integration contract](FIRST-BUILD-CONTRACT.md), [verification](FIRST-BUILD-VERIFICATION.md), and [team record](FIRST-BUILD-SWARM.md) | Preserved dated evidence                                                                       |
| The latest enemy family art and combat storyboard           | [Orchard concept study](CONCEPT-STUDY-03.md)                                                                                          | Visual proposals with inspection notes                                                         |
| The research brief behind the current encounter             | [Orchard encounter study](ORCHARD-ENCOUNTER-STUDY.md)                                                                                 | Historical paper sequence and pose brief; the playable implementation is documented separately |
| Boss-derived enemy hierarchies                              | [Enemy taxonomy](ENEMY-TAXONOMY.md)                                                                                                   | Three researched families; expanded roster is a comparison palette                             |
| Competition, transferable patterns and original positioning | [Market research](MARKET-RESEARCH.md) and [source ledger](MARKET-SOURCES.md)                                                          | Dated sources; no revenue forecast or representative demand study                              |
| Andrew's confirmed preferences and remaining questions      | [Publisher discovery](DISCOVERY.md)                                                                                                   | Source of truth for accepted direction                                                         |
| The earlier notebook                                        | [Transcription and interpretation](HANDWRITTEN-NOTES.md)                                                                              | Preserved source images; uncertain handwriting identified                                      |
| Conflict, defensive mechanics and boss alternatives         | [Combat workshop](CONFLICT-AND-COMBAT.md)                                                                                             | Working candidates, including Furnace Fleet; exact defensive rhythm remains open               |
| Loops you can't put down (11 Nov 2026)                      | [Loop design session](design/loops.md)                                                                                                | Proposal for the Feature fit pass; nothing built                                               |

## Deep research desk

5 September 2026. A coordinated design audit and a five-lane deep-research swarm produced the working documents below. The mutable desks below now distinguish accepted notebook direction from candidate content and historical examples. The [audit synthesis](DESIGN-AUDIT.md) and [review notes](research-2026-09-05/REVIEW-NOTES.md) preserve dated research; their mass-first sequence, three-stage timing and fixed campaign order are superseded. Begin with Discovery and the current decision register.

| To review                                                                                            | Open                                                | Status                                                                                   |
| ---------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Accepted rulings and remaining choices, with the next-session agenda                                 | [Decision register](project/DECISION-REGISTER.md)   | Current rulings and remaining decisions; approved lightning scope is recorded separately |
| High-impact areas, playfeel probe findings, and the proposed build sequence                          | [Design audit](DESIGN-AUDIT.md)                     | Historical audit; mass-first sequence and old run structure superseded                   |
| Character canon: pilots, Brindle and overseers, companions, Scrapbook voice                          | [Character bible](CHARACTER-BIBLE.md)               | Accepted chaos/tree direction; invented roster and fiction remain candidates             |
| Candidate enemy library by world, with proposed admission rows                                       | [Campaign enemy roster](ENEMY-ROSTER.md)            | Candidate world library; fixed campaign order superseded                                 |
| Per-biome environment kits, shared world rules, and the next-biome pick                              | [World and environment kits](WORLD-ENVIRONMENTS.md) | Candidate kits; four-world run is separate from catalogue size                           |
| Compact-level structure, generation options, branch/defense patterns and historical orchard study    | [Level design](LEVEL-DESIGN.md)                     | Accepted compact-level structure; historical dimensions and worked stage labeled         |
| Target systems: content, encounter, run and permanent state; progression, checkpoints and validation | [Runtime blueprint](RUNTIME-BLUEPRINT.md)           | Target system boundaries aligned; full-run implementation and migration pending          |
| How the research pass ran and what the critics found                                                 | [Deep research swarm](DEEP-RESEARCH-SWARM.md)       | Team record; 22 agents, verdicts and evidence limits                                     |

## What is established

- Rolling, collecting and bumping are the central appeal; the animal stays inside a visibly accumulated scrap ball.
- Prove solo play first. Quick autonomous deployments and loot-built companions support active combat.
- Isaac-style item combinations and high-damage skill shots matter; each class needs a distinct useful baseline.
- The expanded game targets a 60–75 minute run through four worlds of compact procedural levels. World transitions offer two random destinations; the player picks one. The bounded lightning encounter does not establish full-run duration.
- Each character has four slot trees, one selected route and eight endpoints per tree. Gameplay milestones advance the build; special opportunities permit tree respec.
- Themed loot can attune to characters/items; fixed endpoint combinations grant secret bonuses. Unlock options between runs and rebuild combat power each run.
- One standard revival per run; completed levels save progress for resume at the next entrance. The full lifecycle remains unimplemented.
- Ordinary physical growth fits designed routes. Battle scale and destructive consequences can escalate much further; a literal giant player form remains undecided.

## What the team is comparing

The proposed enemy roots are Cancrusher, Counterweight Crown, and Grand Pruner. The first proof implements Snipcart, Spreadleg, and one Grand Pruner arm in Three.js. The other roots, full roster, Furnace Fleet fiction, class systems, and a production-engine migration remain proposals. Earlier demo names remain in the original yard.

The orchard proof tests the relationship proposed by the latest study. Snipcart's closing jaws and Spreadleg's outward feet share machinery with Grand Pruner. The picture, paper encounter, executable fixtures, and live controls provide different evidence. Their results remain separate in the verification record.

## Team records

[First-build team](FIRST-BUILD-SWARM.md) · [Combat research swarm](COMBAT-DESIGN-SWARM.md) · [Taxonomy research swarm](ENEMY-TAXONOMY-SWARM.md) · [Orchard visual and encounter swarm](ORCHARD-VISUAL-SWARM.md) · [Deep research swarm](DEEP-RESEARCH-SWARM.md) · [Planning-prep swarm](PLANNING-PREP-SWARM.md).

Workers own bounded assignments; the coordinator integrates changes and records conflicts. The earlier research passes did not authorize implementation or create a session goal. The user subsequently approved this first build and its goal. Simulation and model lanes are now admitted; the coordinator completed build and integration verification.

## Current production checkpoint

The current increment addresses Andrew's first playtest: mouse-look shooting, double jump and rebounds, denser waves, accurate previews, and a readable combat HUD with a paused dashboard. The [lightning play guide](LIGHTNING-PLAYGUIDE.md) describes the controls and reward choices. Andrew's next playtest must establish handling, density and readability. A full stage and complete boss roster require later scope decisions. The production engine direction is settled by the [accepted engineering ADRs](../adr/README.md); its implementation is a separate authorized task, not an open scope decision.
