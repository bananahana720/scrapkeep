# TADR-008. One ability contract

Status: **Accepted engineering direction.** Andrew authorized the direction foundation on 26 September 2026 ([TRACKING](../TRACKING.md) EV-0579) and left its technical choices to the coordinator. This records decision D3. It is not authorization to build.

Date: 26 September 2026. Depends on [TADR-002](TADR-002-runtime-model.md) and [TADR-003](TADR-003-content-pipeline.md). Line numbers cite files at commit `433a3f4`.

## Context

Play settled which movement abilities are worth keeping. In playtest entry 3 (`../docs/playtests/PLAYTEST-LOG.md`) Andrew kept the grapple, glide, slam and air dash. He asked for three changes that are rules, not tuning. The slam should "anchor the character for a second" for weight, "without stunning the player afterwards". The grapple should let him "see if it was in reach". Mag-cling becomes a pylon mount, "mounting your ball onto a surface to like start shooting or doing abilities or getting a breather from being surrounded". Entry 3 left "class versus item for each augment" unanswered. Entry 5 (`../docs/playtests/PLAYTEST-LOG.md`) asked for several ways to power up the character.

The Bible already holds the structure. There are four build slots: weapon, main hero skill, mobility and ultimate ([BIBLE.md](../BIBLE.md#game-identity) line 46; lines 531 to 536). Each slot has one binary tree of one root, two, four and eight endpoints (line 529). A class starts with a useful weapon and special mobility (lines 52, 400, 535). The [class tables](../BIBLE.md#4-characters) already describe every played augment as a candidate (lines 293, 314, 335, 356, 377; device line 410), as the harmonization review (`../artifacts/bible-harmonization-2026-09-26/REVIEW.md`) records in its mobility-slot row. Transformative items may replace movement or attacks (lines 454, 485, 552). [A committed attack means what it shows](../BIBLE.md#a-committed-attack-means-what-it-shows) states the governing rule. Simulation resolves geometry once, collision, previews, effects and damage use that result, and a placement preview must honestly show a blocked or invalid action (line 493). The player's loop is preview, choose, commit and observe (line 495). "Mandatory handling penalties" are not accepted rules (line 481).

The admitted sections fix most of the surrounding contract. TH-03 (`../docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md`) fixes the committed attack. Its provisional preview is built from the weapon origin and never promoted to the commitment (lines 66 to 70), each commitment resolves once (line 131), and damage and presentation read one descriptor (line 136). TH-04 (`../docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md`) keeps availability, cooldown, charge and effect lifetime inside the encounter (lines 52 to 58, 111 to 118) and leaves the kit itself to Q-P11, Q-P13 and Q-P20 (line 317). TH-07 (`../docs/tech/sections/TH-07-four-slots-and-milestone-progression.md`) binds each slot to one tree and rebuilds the effective build from selections (lines 63, 128 to 136). TH-10 (`../docs/tech/sections/TH-10-devices-and-one-main-companion.md`) makes a deployed device a composed controller inside the encounter (lines 72 to 81). None of them states how an ability that is not an attack fits the resolve-once path. That covers a grapple's attach, a glide or an anchor hold. None states what authored form abilities, augments and item modifiers take beyond TADR-003's general rule, how a preview that is not an aim reticle stays honest, or whether a hold the player chose breaks line 481.

The mobility-kit sketch (`../sketches/mobility-kit/README.md`) already uses the pattern this ADR adopts. It is prototype evidence, not proof. `intent.gd` (`../sketches/mobility-kit/src/intent.gd`) fills a plain intent record from a swappable source, so a headless test drives the same player with no input (lines 22 to 45). `augments.gd` (`../sketches/mobility-kit/src/augments.gd`) keeps one table of augment rows that the number keys and the HUD read (lines 5 to 19), and it applies every augment in one physics step (lines 35 to 44). `augment_kit.gd` (`../sketches/mobility-kit/src/augment_kit.gd`) holds the fitted flags and live augment state apart from the rules (lines 5 to 23). The crosshair and the grapple fire both call one query, `_aim_hit()` (`lab.gd`, `../sketches/mobility-kit/src/lab.gd`, lines 81 and 170). The sketch also shows what production must not inherit. The aim ray starts at the camera while reach is measured from the ball (`lab.gd` lines 86 to 98), so the crosshair can report a point the ball has no line to. The grapple fires from an input callback (`lab.gd` lines 126 to 172), not the physics step. Slam knockback is applied in a signal handler (`player_ball.gd`, `../sketches/mobility-kit/src/player_ball.gd`, lines 212 to 224). Augment rows and constants are code, not definitions.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| One pipeline: input becomes intent, the encounter resolves the ability once and owns its outcome, and presentation, audio and HUD read the committed result. Abilities, augments and item modifiers are typed Resource definitions. | **Recommended** | Extends TADR-002's ownership and TH-03's commitment to every ability, movement included, and gives ability content the single authored form TADR-003 requires. |
| Self-contained ability nodes: each ability is a scene or script with its own input handler, physics callback and effects, as parts of the sketch are. | **Rejected for this baseline** | Quick to sketch and close to the current code. It places gameplay mutation in actor callbacks and signal handlers, which TADR-002 lines 26 and 32 refuse, and lets an effect and its gameplay result come from different moments. |
| Two pipelines: attacks go through TH-03's ledger, while movement abilities act directly in the body's physics integration and their previews are computed by the view. | **Rejected for this baseline** | Matches how movement code is usually written. It makes the view a second authority on what is reachable. The sketch's camera-origin ray (`lab.gd` lines 89 to 96) is exactly the disagreement BIBLE line 493 forbids. |
| A general ability framework with tags, attribute sets, stacking rules and a scripting language for effects. | **Rejected for this baseline** | Scales to large rosters. It adds a framework before any roster exists, invents the content scripting language TADR-003 line 23 declines, and would answer stacking, which is Q-P19's (TH-10 line 99). |

## Decision

Adopt **one ability pipeline**. Input becomes intent. The encounter resolves the ability once and owns its outcome. Presentation, audio and the HUD read the committed result. This holds for every action a slot yields, whether weapon, main hero skill, mobility or ultimate, and for movement abilities as much as attacks.

Input produces requests and held samples only. An input callback submits an `ActionRequest`; it fires no grapple, applies no impulse and starts no cooldown (TH-03 lines 78 to 80; TH-02 line 132). Inside the encounter tick the phases already admitted carry each ability kind. Intent is derived at P2 from the captured frame and the installed capability set. Movement-bearing effects such as a dash impulse, glide lift, rope constraint, slam descent or anchor hold are applied inside P3's movement resolution through CollisionQueries. Every query-bearing commitment, such as a grapple attach, a slam impact or a weapon shot, is resolved once at P4. P5 applies outcomes once and P6 publishes (TH-15 (`../docs/tech/sections/TH-15-physics-query-contract.md`) lines 60 to 64). This placement is this ADR's reading of the admitted phase table. It adds no phase.

The encounter is the sole writer of an ability's state. Availability, cooldown, charge and effect windows stay in `EncounterState` as TH-04 fixes (lines 52 to 58, 111 to 118). An attack-bearing commitment stays in `AttackLedger` as TH-03 fixes. If content makes an anchor or pylon a deployed device, it is a composed controller under TH-10 (lines 72 to 81). A signal may report a committed result; it applies nothing (TADR-002 line 32; TH-15 line 80). Presentation, audio and the HUD draw the slam's shockwave, its sound and the dash's ready state from the published descriptor and snapshot (TH-03 line 136; TH-04 line 56). A cue with no committed entry behind it grants nothing (TH-10 line 83).

Abilities, augments and item modifiers are **typed Resource definitions with stable domain IDs**, under TADR-003. An ability definition names an action a slot can yield. It carries a reviewed behaviour identifier (TADR-003 line 23), its parameters, the query it commits if it has one, the preview it publishes if it has one, and any commitment beat it declares. An augment definition is a tree node's change to its slot's ability, addressed by tree ID and node key (TH-07 line 63). An item modifier changes a compatible action or, for a transformative item, replaces one (BIBLE lines 454, 552). Its reach is settled by TH-08's default-deny compatibility query (TH-10 lines 91 and 92). No definition holds run state (TADR-003 line 29).

Binding to slots and trees is data. A slot names one tree, a selection names a connected node prefix, and the whole rebuild turns selections and equipped items into the capability set installed at the intermission (TH-07 lines 63, 128 to 136; TH-04 line 57). No ability is bound to a slot in code. This ADR fixes these three definition kinds. Their field lists belong to the content coverage matrix TADR-003 line 45 requires.

**A preview and its action read one shared query.** The grapple reach indicator is the provisional result of the query the grapple's attach commits. It uses the same origin at the ball's committed pose, the same reach and the same collision mask. The query is shared and the result is not. Commitment re-runs it against the post-movement world, because a preview is never promoted (TH-03 lines 66 to 70; TH-02 line 183). The indicator therefore shows out of reach or blocked whenever the attach would fail, including an anchor the camera can see and the ball cannot reach (TH-03 line 133). The same rule covers any landing marker or valid-surface cue content adds for the slam or the pylon mount. TH-03's preview stage begins when a prepared action exists (line 35). An indicator shown whenever the grapple is ready, as the sketch shows it, needs that entry condition widened to a standing query. That is a later TH-03 amendment, not an edit here.

**A commitment beat is not a handling penalty.** A commitment beat is a bounded hold the player chose by acting. It meets four tests. The player's own action starts it. The ability definition declares it, and presentation shows it at commitment. It is an effect window in ticks that opens at commitment and closes at a committed boundary (TH-04 lines 112 and 113). When it closes, ordinary movement and full control return with no stun, slow or recovery debt. The slam anchor and the pylon mount are commitment beats under these tests, which is what entry 3 asked for. A hold that fails a test is a handling penalty under BIBLE line 481 and is not accepted. Examples are a stagger after every slam or a steering loss that grows with mass. Tarn's line 338 already asks for "readable commitment and recovery" on heavy contact; a beat is the player-side form of that.

The played augments already have candidate homes in the Bible. The table assigns nothing.

| Played augment | Entry 3 verdict | Candidate home, by BIBLE.md line | Status |
| --- | --- | --- | --- |
| Grapple and swing | Kept; reel to rework; reach indicator requested | Sable's mobility, line 293 | Candidate |
| Glide | Kept | Kest's brief lift, line 314 | Candidate |
| Slam, with an anchor beat | Kept; anchor requested | Tarn's planted claw pull, line 335 | Candidate |
| Air dash | Kept | Fuse's vent-assisted burst, line 356 | Candidate |
| Pylon mount, replacing mag-cling | Requested | Rivet's braced reposition, line 377; Sable's planted anchor foot, lines 294 and 410 | Candidate |

## Consequences

The sketch is evidence to port as patterns, not code to port. The intent record, the single augment table and the shared reach query carry over. The camera-origin ray, the input-callback fire and the signal-applied knockback are rewritten when an ability is promoted.

Each ability kind costs a reviewed behaviour identifier in code and a definition. A new behaviour is a code review. A new value is a definition edit, and that value is canonical in one Resource (TADR-003 line 27). Playtest tuning traceability is DF-01's card and is not decided here.

Under decision D1 ([TRACKING](../TRACKING.md) EV-0578) the ball is a rigid Jolt body. An anchor hold and a rope constraint must therefore act on that body through CollisionQueries on the encounter's ordered request (TH-15 line 78). The mechanism that holds a rigid body still for a beat is qualification work, not a choice made here.

Presentation, audio and the HUD compute nothing gameplay-relevant. Previews cost one provisional query per tick for each previewed ability, which is TH-03's existing cost for aim.

## Later qualification and reconsideration

Qualify the pipeline headless before any feel judgement. One movement ability and one attack-bearing ability each travel input, intent, one resolution and publication with no presentation attached. A refused ability costs nothing (TH-04 line 58). A removed item stops contributing after the rebuild. Each definition kind round-trips through its Resource codec with its stable ID.

Qualify the reach indicator against its action. When the world does not change between preview and release, the indicator predicts attach success in every attempt, including an anchor visible from the camera and blocked from the ball. Where it disagrees, the disagreement traces to a world change (TH-02 line 183). Rigid outcomes are judged as rates over at least 20 trials with a stated floor, per D1.

Qualify the slam anchor and the pylon mount against the four beat tests. Full control is measurable on the tick after the window closes. Feel is Andrew's verdict in the playtest log; automated play is never feel evidence (playtest log (`../docs/playtests/PLAYTEST-LOG.md`) line 3).

Later amendments, listed and not made here:

- TH-03 line 35 needs a standing-query entry condition if the reach indicator shows while the grapple is ready rather than only while prepared.

Open in the Bible and not decided here:

- Which augment is a root, a node or an item. Q-P11 owns the slot mapping; entry 3 left class versus item open; BIBLE lines 454 and 485 allow items to replace movement.
- Whether the pylon mount is a mobility action or a deployed device. Q-P15 owns the device lifecycle; TH-10 governs if it is a device.
- Every duration, cooldown and beat length, and whether ground boost and air dash share one cooldown. Q-P20 owns cadence; entry 3 left the shared cooldown unanswered.
- How the mount ends: on release, at a window's end, or either.
- The reel rework and a rope that collides and wraps. BIBLE line 293 is silent on rope physicality.
- Whether the reach indicator shows continuously or only while aiming, and how much momentum-aware aim assistance entry 3's request implies. Q-P30 and Q-P21 own them; line 483 fixes only that focused aiming helps line up a shot.
- The word "augment". The Bible has no such term; it comes from the sketch.

Revisit this ADR if a roster outgrows reviewed behaviour identifiers, or if measured input latency shows a mobility action cannot wait for the next tick.
