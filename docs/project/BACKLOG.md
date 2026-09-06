# Ordered backlog

5 September 2026. Ordered by the next useful evidence and known maintenance risk. Effort is a rough estimate for the next bounded action: small is under half a day, medium is several focused sessions, decision means publisher input is necessary. These are open candidates, not a scheduled sprint.

| ID / priority | Work | Why it matters | Owner / effort | Close when |
| --- | --- | --- | --- | --- |
| P10 / active | Implement and playtest the lightning caster increment | Andrew's first playtest changed the next scope to shooter controls, physical jumping, dense waves and readable UI | Coordinator + Andrew / scoped increment | [Increment 01](INCREMENT-01-lightning-playtest.md) passes local and browser checks, then Andrew records handling, combat and readability feedback |
| T01 / medium | Choose a remote and publish the established checkout | The local checkout is real (branch `main`, baseline commit `4db9b31`, `.gitignore` covering `node_modules`, `dist`, `.private`, `.env`, and `artifacts/local`), but nothing leaves this machine yet, so there is no off-machine backup | Andrew + coordinator / small, pending authorization | Andrew authorizes a remote, the coordinator pushes the branch, and status confirms it tracks the remote |
| P02 / high | Review ranged circling and encounter pacing after P01 | Precise input cleared all enemies in about 37 seconds without damage | Combat implementation / small experiment | Record keep/tune decision; any tuning preserves ordinary damage and movement exits and has replay + playtest evidence |
| P03 / medium | Exercise real mouse capture and controller controls | DOM event checks did not use physical controller hardware | Coordinator + available hardware / small | Record device/browser and results for start, movement, aim, charge, pause/recovery and restart |
| T02 / medium | Decide orchard QA packaging before public distribution | Its mutable QA bridge is intentionally included behind ?qa; baseline QA is development-only | Build owner / small | Choose release vs test build behavior and verify both entry bundles and required QA paths |
| T03 / medium | Establish a sustained performance baseline on target hardware | A short local FPS sample is insufficient for performance budgets | Rendering owner / small | Name hardware, encounter and sampling method; save frame-time distribution and choose budgets before optimization |
| P05 / deferred | Decide mobile support timing and camera controls | Touch actions exist; camera gesture and device ergonomics are unfinished | Andrew + input owner / decision | Either defer explicitly or test a complete control scheme on selected hardware |
| T04 / before external release | Review project/asset redistribution terms and required notices | Local package metadata is not a release-ready asset/legal review | Andrew + release owner / decision | Choose project licensing, inventory shipped assets and include applicable notices; keep private notebook references out of build assets |
| P06 / decision | Rule on the deep-research canon set: character roster (Vane, Fuse, mole Rivet, provisioner Moss, five overseers), enemy reconciliations (Glassjaw and Old Ironroot adoption, Kiln Strider promotion, Jettling admission), fixed lighting keyframes over dynamic weather | Five desk documents build on these namings; character art and registry rows are blocked until they hold | Andrew + coordinator / decision | Each ruling recorded in decisions.tsv or the owning document; amended names propagated through the desk |
| P07 / decision | Choose the stage-generation model and the next authored biome | Level design recommends seeded arrangement of authored pockets; world recommends Spillway Works; P04 increment scoping depends on both | Andrew + coordinator / decision | Both choices recorded; P04 scoping cites them |
| P08 / next | Add level-grammar telemetry before a full-stage playtest | Hurt-bearing with banner coverage, per-beat timestamps and off-screen-hit events are what will diagnose defense awareness across stage pockets | Simulation owner / small | Events emit in fixtures and the full-stage playtest records them, per the [level design telemetry list](../LEVEL-DESIGN.md) |
| P09 / parked | Validate deflect grades with the Sluiceback basin experiment if deflect mechanics are selected later | Every non-implemented attack grade in the roster is paper; the combat paper names the deflect chip economy its highest risk | Combat implementation / small experiment | Fixture plus playtest evidence recorded for one deflectable and one heavy attack |
| T05 / decision | Approve save schema v2 with the v1 migration rule, and adopt the engine decision gate | Scrapbook, ledger and unlocks need the widened profile; the gate defers the Godot question to the imported-asset trigger | Andrew + runtime owner / decision | Schema and gate recorded; the schema lands only with the increment that needs it |
| T06 / high | Make the worker windup stagger per-lane | The global one-windup gate makes multi-lane defense waves queue behind one another | Simulation owner / small | Two lanes in the stage-1 defense arena hold simultaneous windups without suppressing each other |
| T07 / medium | Extend groundHeight to pocket-resolved terrain | The z-only ramp band cannot express a five-pocket stage | Simulation owner / small | Stage 1's five pockets report correct height with no cross-pocket bleed |
| T08 / medium | Grounding pass for the 13 new enemy designs | Their occupational groundings are labeled inference; the taxonomy's citation discipline requires a dated reference per design | Research / small | Each new roster row carries a URL and access date or is relabeled |
| T09 / medium | Audit baseline collection and signup art against the species canon | Canonizing Pip as hamster and Rivet as mole may contradict shipped portraits players meet first | Art owner / small | Inventory produced with a keep or redraw list |
| T10 / medium | Verify telegraph decal readability on dark ground | Foundry Crown and Furnace City keyframes are the first dark floors under the low-opacity telegraph decals | Rendering owner / small | Fixture screenshots at both keyframes show strokes readable at chase distance |
| T11 / medium | Package the orchard environment as reusable pocket modules | The current arena is hand-laid; the seeded-stage model needs a module kit per biome | Scene owner / medium | Iron Orchard stage-1 pockets assemble from the module kit |
| T12 / medium | Write the one-page audio and voice direction note | The character bible fixes a bark budget but no audio direction document exists | Coordinator / small | Note admitted to the desk; the bark budget confirmed or revised there |

Detailed evidence for P01–P03 and T02–T03: [first-build verification](../FIRST-BUILD-VERIFICATION.md). P06–P09 and T05–T12 come from the 5 September deep-research pass; their documents are indexed in the [design desk](../DESIGN-INDEX.md) and the critics' notes in [review notes](../research-2026-09-05/REVIEW-NOTES.md). Source/licensing inventory: [assets](ASSETS.md). Current environment finding: [closeout](HOUSEKEEPING.md). Every decision-typed row above maps to an entry in the [decision register](DECISION-REGISTER.md), which the [planning protocol](PLANNING.md) works through before scoping.

## Completed planning decisions

- P01: Andrew played the original orchard. Movement was decent, but mouse/ability controls, enemy volume, physics and UI readability need the revised caster foundation. Play duration was not recorded. Feedback and approval are in [increment 01](INCREMENT-01-lightning-playtest.md).
- P04: Andrew approved and requested implementation of increment 01, including a small class/item/device example.

## Completed this closeout

- Added one developer entry point, project requirements/status, four retrospective ADRs and this backlog.
- Added a dependency-free verification command and checked package/lock metadata.
- Routed repeated test/probe output to disposable artifacts and fixed browser-test startup cleanup.
- Preserved the first-build and baseline evidence as dated records.

Add a new backlog item only for an observed defect, a specific evidence gap, or an explicit product decision. Include the consequence and a checkable closure condition. Do not fill this file with generic future refactors.
