# TADR-011. The scrap-bot crew

Status: **Accepted direction.** Andrew decided this on 10 October 2026 after reading the CS-01 comps pack: "Crew. Go with the scrap-bot crew, amend BIBLE.md section 6 and write the ADR the pack proposes" ([TRACKING](../TRACKING.md) CS-01-A1, EV-0626). This is not authorization to build.

Date: 10 October 2026. Depends on [TADR-002](TADR-002-runtime-model.md), [TADR-003](TADR-003-content-pipeline.md), [TADR-004](TADR-004-persistence.md) and [TADR-010](TADR-010-open-stages-and-event-director.md).

## Context

The Bible gave the run one main companion. [BIBLE.md](../BIBLE.md) § 6 "Devices and one main companion" (lines 566 to 575, before this amendment) said one main companion anchors the run's assembled support build, that temporary helper effects "do not establish a second companion management roster", and that chassis and assembly rules remain unresolved. BIBLE_DECISIONS.md (`../BIBLE_DECISIONS.md`) BD-15 carried the same boundary. The admitted tech section TH-10 (`../docs/tech/sections/TH-10-devices-and-one-main-companion.md`) made it a contract: DC-01 (line 106) says exactly one main companion anchors the build and the save envelope holds one `run.checkpoint.companion` object, not an array; DC-05 (line 110) keeps helpers as effect windows; DM-09 (line 279) names a second assembled companion a failure. HF-07a (`../docs/tech/sections/HF-07a-save-envelope.md`) line 159 holds that single object and SC-06 (`../docs/tech/schemas/SC-06.md`) F-07 (line 49) defines companion parts "assembled into the one main companion".

On 10 October 2026 Andrew asked what Scrapkeep can take from Risk of Rain 2, Gunfire Reborn, Roboquest and The Binding of Isaac without copyright infringement, and set two directions for the study: stages are one open stage with authored pockets, and companions are a crew of scrap bots assembled from scrap over the run, each with a role, that grow with the run, persist across stages and can be repaired or revived, and have personality and voice. He did not choose direct command controls ([comps README](../sketches/core-loop/design-v3/research/comps/README.md) line 28).

The study's companions note ([companions.md](../sketches/core-loop/design-v3/research/comps/ror2/companions.md)) read Risk of Rain 2's drone code and separated what works from what made its drones feel half-baked. What works is an architecture: an owner and a leash, a priority list of data-driven skill drivers (target, movement, aim, distance band, conditions), item inheritance through an explicit filter, and repair as a cost. The seven gaps are the failures: allies that do not persist, orphan on owner loss, a purchase-and-forget vendor, opaque item sharing, a 2^n growth curve, per-kind slot limits as the only cap, and no voice. The crew proposal there answers Andrew's three requirements with that architecture and avoids the seven gaps. Its numbers are proposals.

Andrew's principles from playtest entry 6 (PLAYTEST-LOG.md (`../docs/playtests/PLAYTEST-LOG.md`) lines 98 to 105) bound the design: opt-in layers (a crew the player may ignore but is rewarded for building) and readability first (every crew action has its own silhouette and sound), with the pilot never a passenger (BIBLE line 572).

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| A crew of scrap bots under one crew cap: found as salvage or assembled from banked scrap, each with a role, growing with the run, persisting across stages, repaired at a scrap cost, voiced; no direct command controls | **Accepted** | Andrew's decision. It carries his three requirements and the opt-in and readability principles, reuses the proven ownership, leash, driver-list, inheritance and repair architecture, and names the seven gaps as what not to build. |
| Keep one main companion as the Bible and TH-10 wrote it | **Rejected** | Andrew chose the crew. One chassis cannot carry the role variety, growth and personality he asked for without becoming a second progression system of its own. |
| One main companion plus temporary helpers, the Bible's existing allowance widened | **Rejected** | Helpers without persistence are the stage-bound summons the study found half-baked; they cannot be repaired, revived or grow, which are two of the three requirements. |
| Per-kind deployable slots as the roster, Risk of Rain 2's drone model | **Rejected** | Slot-per-kind limits and the doubling growth curve are among the seven gaps. A crew of named bots needs one readable cap, not one slot per gadget kind. |
| A commandable squad with direct orders | **Rejected** | Andrew did not choose commands. The four established slots leave no input for orders, and a pilot issuing orders becomes the passenger BIBLE line 572 forbids. |

## Decision

**A crew of scrap bots replaces the one main companion.** The run's assembled support build is a crew under one crew cap. The cap is proposed at three and stays a tunable parameter under [Q-P15](../BACKLOG.md#q-p15); it is one cap for the crew, never a limit per bot kind. Each bot has a role, and a role is an ordered list of typed drivers (target kind, movement kind, aim kind, distance band, conditions), of which the first passing driver runs. Guard, repair and harvest are the starting role candidates. Roles, drivers and bot definitions are typed, stable-ID Resources under [TADR-003](TADR-003-content-pipeline.md), so a new role is content when it fits an existing driver kind.

**A bot joins by salvage or assembly.** It is found as salvage on the stage and repaired for scrap, or assembled from banked scrap at a pocket workbench. One crew slot opens per stage cleared, up to the cap. These are proposals for play and the lab; no price or cadence is adopted here.

**The crew grows with the run.** A bot's level rises from the run's own tally (stages cleared, objectives done), never from elapsed time ([TADR-010](TADR-010-open-stages-and-event-director.md): time scales threat, never progression). Found items reach bots through an explicit allow-list per role, so the player knows which finds their crew receives. Each bot may have a small upgrade path of the same binary shape as the character trees (BIBLE line 527), at most two forks deep. Per-bot growth is capped at a readable level and adds breadth (a new driver unlocks) before depth; the doubling curve is not copied.

**The crew persists, is repaired and can be revived.** The crew is run state that outlives stage scenes and crosses the completed-stage checkpoint ([TADR-004](TADR-004-persistence.md)). A downed bot becomes a salvage pile; repair is a scrap cost paid at the pile from the same pool that grows the build, and a revive costs more than a repair. A bot whose leader is lost enters a stalled state at the last safe place and waits; it never wanders leaderless. A bot left dead past a stage boundary becomes a rescue objective in a later pocket. No crew action grants the player another standard revival (BIBLE line 572, TH-01 lifecycle); a rescue opens a recoverable moment and nothing more.

**The crew acts inside the encounter's boundary.** Each bot is a composed controller within Encounter under [TADR-002](TADR-002-runtime-model.md) line 26 and TH-10's ownership clause (line 32): no bot callback is a second gameplay-time authority, bots are placed and attack through the same committed queries as every arrival (TH-06 AV-01 to AV-06), and the crew's live action state lives in `EncounterState` while the crew's durable facts live in run state. Compatible effects reach a bot through TH-08's admitted interfaces exactly as they reached the one companion.

**Every crew action is readable without looking.** Each driver owns a short sound motif, each bot has a bark table keyed by game events, and barks, animation and motif read one shared state variable so they cannot drift apart (BIBLE lines 767 and 795). Quirks (a preferred driver order, a favourite scrap type, a flinch) are data in the same definition.

**No direct command controls.** The player shapes the crew by what is found, assembled, repaired and upgraded, and by which bots are present. Devices stay as BIBLE line 568 describes them, quick autonomous deployments; Risk of Rain 2's deployable slot model is one candidate answer for device capacity, lifetime and recall and remains open under Q-P15.

## Consequences

The Bible is amended in place. § 6 "Devices and one main companion" keeps its heading so the links across BACKLOG, TH-10, SC-06, PD-02 and HF-06a still resolve, and its body now describes the crew; lines 5, 46, 65, 454 and 608 and the glossary are reworded to match, and BD-15 in BIBLE_DECISIONS records the new boundary.

Admitted sections need revision, and this ADR does not edit them. The sections index (`../docs/tech/sections/README.md`) lists what is superseded: TH-10's heading and DC-01, DC-05's "never a second roster" reading, DM-09 and the Acting companion row; HF-07a's single `run.checkpoint.companion` object, which a crew turns into an array, a durable-field change that also touches HF-06b and TADR-004's aggregate; SC-06 F-07 and SP-15; PD-03 SE-20's "the companion"; TH-12's dashboard companion panel. A heavy-lane card owns those revisions. Everything in TH-10 that is not about the count survives: the ownership clause, the compatible-effect rules, the support states and every `unset` parameter row.

Save state grows from one companion object to a crew array with per-bot level, role, items, upgrades and repair state. That is more to migrate (HF-09) and more to validate at load.

Readability is the main risk. Three autonomous allies, deployed devices and a director's layered events all compete for the player's attention. The mix priority at BIBLE line 795 drops repeated companion layers first, and that rule now covers the crew; the per-driver motif exists so the crew explains itself by ear. Only Andrew's play settles whether three is the right cap.

Content carries the variety. Roles, drivers, barks and quirks are authored data, so a crew with character costs content, not code, once the driver kinds exist.

## Later qualification and reconsideration

Open and not chosen here: the crew cap (three is a proposal); the role set and each role's driver list; repair and revive prices; the slot cadence; which items each role inherits; the bot upgrade paths; the rescue objective's shape; the stalled-state wait location; and every sound motif and bark line. Q-P15 widens from the companion's chassis and components to these.

Qualify in play and in the lab. Andrew plays a stage set with a crew of three and judges whether he can tell what each bot is doing by ear and silhouette, whether losing one hurts, and whether the crew ever makes him a passenger. The headless lab measure from the companions note: a scripted crew of three through three stage loads with the leader killed in stage two passes when every bot survives each load, the stalled state engages within one second of leader loss and clears on respawn, a repair spends exactly the declared scrap and restores the bot's level, and the bark log shows each bark fired at most once per trigger within its cooldown with animation state and bark reason matching on every event. Test that a crew bot's committed attack reaches collision, damage and presentation from one committed state, as TADR-006 requires of every attack.

Revisit this ADR if play shows the crew needs direct commands, if a crew of any size fails readability, or if the crew's durable state cannot fit TADR-004's single committed aggregate.
