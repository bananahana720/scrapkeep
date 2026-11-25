# TADR-006. Physics authority and verification basis

Status: **Accepted engineering direction.** Andrew decided D1 on 26 September 2026 ([TRACKING](../TRACKING.md) EV-0578) and authorized recording it as an ADR at EV-0579. This is not authorization to build.

Date: 26 September 2026. Depends on [TADR-001](TADR-001-engine-language-platforms.md) and [TADR-002](TADR-002-runtime-model.md). Written under [DF-01](../BACKLOG.md#df-01) revision 1.

## Context

Andrew has chosen the rigid ball in play three times. After the first ball-lab play he wrote "rigid body felt best" (entry 2 (`../docs/playtests/PLAYTEST-LOG.md`), `PLAYTEST-LOG.md:82`), and the entry records rigid-body mode, a Jolt `RigidBody3D` driven by torque, chosen over the hand-rolled kinematic ball (`:83`). In the mobility-kit play he confirmed it: "the kinematics is just really shaky in terms of my screen" (entry 3 (`../docs/playtests/PLAYTEST-LOG.md`), `:66`). After the Cable Bench play the same day he added that the kinematic shake meant "I couldn't really aim my grapple hook too well or see if it was in reach" (`:72`), and the entry makes visible grapple reach a requirement (`:73`). [The decision trail](../docs/decisions.tsv) (line 71) records these as three plays.

The Jev Lab ran both modes of the same ball headless. Kinematic mode reproduces exactly: the same scenario, seed and D/k give the same `trace_hash`, 360 of 360 ball-lab repeat pairs and 120 of 120 on Cable Bench (lessons (`../.agents/skills/scrapkeep-lab/references/lessons.md`) lines 51 and 52). Rigid mode does not. About 1 ball-lab repeat pair in 20 diverges, one pair went `timeout` against `success` on the same seed, and Cable Bench gave 120 of 120 identical pairs in one attempt and 119 and 118 of 120 in the next, so one clean repeat does not prove a rigid scenario deterministic (lessons lines 56 and 57). The lab gate already splits by mode. Kinematic records are held to exact trace and replay equality. Rigid records need n ≥ 20 on each side and carry a nondeterminism floor of 0.05, but the rigid gate compares no rate yet (lessons lines 61 and 62; `scripts/lab/gate.mjs:45-46`, `:413`). A kinematic gate failure means "behaviour differs from the pin", not "worse" (lessons line 66).

[TADR-002 § Consequences](TADR-002-runtime-model.md#consequences) line 40 states that explicit commands and seeded randomness help diagnosis but do not establish cross-platform determinism. The Step 0 review left "controlled repeatability versus cross-platform determinism" for later qualification ([README](README.md) line 35). TADR-002 line 28 rules out a custom physics engine. The admitted movement and query pages, TH-02 (`../docs/tech/sections/TH-02-movement-camera-and-active-aim.md`) and TH-15 (`../docs/tech/sections/TH-15-physics-query-contract.md`), predate every Godot sketch. They inherit HF-04a line 64, which resolves movers one at a time in stable entity-ID order, and neither names Jolt, a rigid body or a statistical test basis.

The open questions are which simulation owns the player's physical outcome, and what a test of that outcome may assert.

## Options

| Option | Disposition | Reason |
| --- | --- | --- |
| Rigid Jolt bodies as the authority, judged statistically; a kinematic twin kept only as a lab instrument for exact replay | **Accepted (D1, Andrew)** | Keeps the feel Andrew chose in entries 2 and 3 and keeps a deterministic instrument for the lab tools that need exact replay. |
| Kinematic ball as the authority, so the shipped game replays exactly | **Rejected** | Andrew's play rejected it three times. It shook the screen and hid grapple reach (`PLAYTEST-LOG.md:66`, `:72`). Exact replay serves the tools, not the player. |
| Make Jolt deterministic | **Rejected (Andrew, EV-0578)** | EV-0578 records the rejection without a reason; the reasons here are this ADR's inference. The lab measured divergence on one build and one host (lessons line 56), so determinism would need control of solver internals the project does not own. Neither TADR-001's two targets nor TADR-005's offline scope requires it. |
| Custom deterministic ball physics | **Rejected (Andrew, EV-0578)** | TADR-002 line 28 rules out a custom physics engine. The kinematic ball is already a hand-rolled deterministic ball, and it lost on feel (`PLAYTEST-LOG.md:83`). The second reason is this ADR's inference. |

## Decision

**Authority.** Rigid bodies simulated by Jolt Physics in Godot 4.7.2 are the game's physics authority for the player's ball and for every body whose motion the game resolves physically. The sketches already run this configuration (`sketches/mobility-kit/project.godot:17-18`). TADR-002's ownership still applies: the solver produces physical state, CollisionQueries reads and interprets it, and Encounter commits each gameplay outcome once. D1 does not forbid kinematically controlled bodies inside the Jolt world, such as scripted movers; the sketch enemies are `CharacterBody3D` (`sketches/mobility-kit/src/enemy.gd:1`). It forbids a second simulation of the player shipping beside the rigid one. That scope is this ADR's reading of EV-0578.

**The kinematic twin.** The kinematic ball is a lab instrument only. It lives in `sketches/ball-lab`, which stays byte-identical for that role (EV-0578), and in any later lab build. It never ships in `native/` or in any exported build. Trace hashes, replay of an action prefix and the EV-0573 decision tree run on it alone; EV-0573 (`TRACKING.md:879`) depends on kinematic lockstep. A kinematic result is evidence about the twin. It bears on the rigid game only after a rigid measurement confirms it, because rigid runs can diverge where the twin cannot (inference from lessons lines 56 and 66).

**Statistical judgment.** A claim about a rigid physical outcome, such as reaching a pad, clearing a jump, landing a grapple or knocking an enemy, is an outcome rate over n ≥ 20 trials on each side. The lab's nondeterminism floor of 0.05 applies (`gate.mjs:45-46`). One trial, or one identical repeat pair, never shows that a rigid scenario is deterministic or that a change is safe (lessons line 56). Intervals use the lab's existing Wilson and Newcombe functions (`scripts/lab/stats.mjs:14`, `:29`). This ADR chooses no rule for turning a rate difference into a regression verdict; at this base the rigid gate compares no rate (`gate.mjs:413`; lessons line 61).

**What "controlled repeatability" means.** TADR-002 line 40 and README line 35 leave the term open. Under D1 it has four meanings, and every test names the one it asserts.

1. *Exact replay* holds for the kinematic twin alone, on one build and one platform (lessons line 51).
2. *Exact invariants* hold on every rigid run and are asserted per run, not by comparing two runs. They are the gameplay-layer rules that do not depend on which physical outcome occurred: one geometry query and one draw per commitment, one consequence per committed contact (TH-15 PP-04 to PP-06, lines 297 to 299), P3 before P4 (TH-15 PO-02, line 130), and no display value in the query world (TH-15 PS-04, line 79).
3. *Stored outcomes* are read back rather than redrawn, so they match after any restore (TH-14 GT-07, line 149). D1 does not change this.
4. *Distributional repeatability* covers rigid physical outcomes and everything downstream of them, including the order in which seeded streams are consumed. They repeat in distribution on one build and one platform, not trial for trial.

Controlled engine worlds remain the test host (TADR-002 line 38). Rates and invariants do not judge feel. Andrew's play judges feel, and automated play is never feel evidence (`PLAYTEST-LOG.md:3`).

## Consequences

Physical assertions change form. A fixture that checks one run's physical result becomes a rate over n ≥ 20, while counting and ordering rules stay exact per run. Rigid checks cost at least twenty trials per scenario on each side, so they suit batch runs better than every commit (inference). Replaying a player's rigid session trial for trial is not promised. Bug reproduction uses rate sampling, the kinematic twin, or stored outcomes.

The lab keeps its exact tools, but their verdicts need a rigid confirmation before they bear on the game. The twin must follow ball-rule changes to stay useful. Both modes share one rule set today (`sketches/mobility-kit/src/ball_rules.gd:6-8`); a twin that drifts from that set says less about the game (inference).

Andrew keeps the feel he chose. The grapple-reach requirement (`PLAYTEST-LOG.md:73`) now depends on a display that stays steady under rigid motion, which is a qualification item below.

The passages below assume ordered, per-mover resolution or single-run physical observations, and need a later amendment under a separate card. This ADR does not edit them, and their stated hashes stay valid.

| Passage | What it says | Why D1 affects it |
| --- | --- | --- |
| `TH-02-movement-camera-and-active-aim.md:80` (MI-07) | Resolve movement against the physical world in stable entity-ID order | Jolt steps rigid bodies together in one solver step. A per-mover order can apply to queries and kinematic movers, not to the rigid solve (inference). |
| `TH-02-movement-camera-and-active-aim.md:121` (MO-04) | Movers resolve in stable entity-ID order; later movers see prior resolved updates | Same conflict as MI-07. The "post-movement world before any attack query" half still holds. |
| `TH-02-movement-camera-and-active-aim.md:124-125` (MO-07, MO-08) | A rebound is a contact consequence Encounter applies once at P5 | Under D1 the physical bounce is the solver's, from the body's physics material (`sketches/mobility-kit/src/rigid_ball.gd:36-39`). Encounter still applies the gameplay consequence once. The rule needs to separate the two. |
| `TH-02-movement-camera-and-active-aim.md:135` | The one-tick order: P3 resolves movers, P5 applies movement consequences | How the Jolt step maps onto P3 and P5 is unqualified (see below). |
| `TH-02-movement-camera-and-active-aim.md:153`, `:167` | The prototype table cites only the browser proof, including its "120 Hz deterministic browser simulation" | The Godot sketches are now the relevant prototype evidence: rigid Jolt at 90 Hz, played in entries 2 and 3. |
| `TH-15-physics-query-contract.md:43` (PW-04) | P3 drives body updates for movers in stable entity-ID order | Same conflict as TH-02 MI-07. |
| `TH-15-physics-query-contract.md:61` | P3 row of the query-order table: resolve movers in stable entity-ID order; the revision is identified when `resolve_movement` returns | Same conflict. It also assumes P3 returns this tick's physical result synchronously. |
| `TH-15-physics-query-contract.md:96` (PC-01) | Project the last committed poses onto the bodies before resolving movers | A rigid body carries velocity and contact state across steps. Overwriting its pose every tick may discard that state (inference, unmeasured). |
| `TH-15-physics-query-contract.md:120` (PK-06) | A rebound is a contact consequence applied once | Same split as TH-02 MO-08. |
| `TH-15-physics-query-contract.md:131` (PO-03), `:296` (PP-03) | Stable entity-ID mover order as a rule and as a parameter | Same conflict as TH-02 MO-04. |
| `TH-15-physics-query-contract.md:198`, `:200`, `:203`, `:206` (PX-04, PX-06, PX-09, PX-12) | Fixture observations of one run's physical result, such as a supporting contact returned once, exactly one `ContactResult`, and two runs differing only in extent | Under D1 a physical outcome is observed as a rate over n ≥ 20. The counting halves of these fixtures stay exact. |

Three further passages lie outside TH-02 and TH-15. HF-04a line 64 is the upstream source of the mover-order rule both pages inherit. TH-14 line 145 (GT-03) says two runs of one build consume the same streams in the same order for the same inputs; under rigid divergence (lessons line 56) that holds only when the physical outcomes match. TH-02 lines 100, 248 and 309 use "DF-01" for an HF-03b unlisted-edge register entry on aim authority. That entry is unrelated to the card family that wrote this ADR.

## Later qualification and reconsideration

An authorized native slice must qualify the following. Each item is an unmeasured requirement, not a claim that it works.

- **Fixed physics rate.** The sketches run at 90 Hz (`sketches/mobility-kit/project.godot:18`; `PLAYTEST-LOG.md:84`). The production interval is unset under [Q-E03](../BACKLOG.md#q-e03) (TH-02 line 239; TH-15 line 315). Measure outcome rates and Andrew's feel at the chosen rate. A rate change is a change in rigid behaviour, and the rates are measured again (inference).
- **Interpolation.** Neither sketch enables physics interpolation; neither `project.godot` sets it. The chase camera runs in `_process` and follows the body's raw position (`sketches/mobility-kit/src/chase_camera.gd:59`, `:67-68`; `player_ball.gd:76-77`). Production Presentation interpolates published snapshots (TH-02 line 146; TH-15 PC-07, line 102). Qualify that the display shows no visible stepping at display rates above and below the physics rate, on both TADR-001 targets. Why the kinematic mode shook was not diagnosed.
- **Camera and aim reading interpolated state.** The camera, the reticle and the requested grapple reach indicator (`PLAYTEST-LOG.md:74`) read interpolated state, while a commitment revalidates against the committed world (TADR-002 line 30; TH-02 MO-06, line 123). Measure how often the shown reach and the committed result disagree, as a rate. Andrew's play decides whether he can aim (`PLAYTEST-LOG.md:72-73`).
- **The solver step and the tick phases.** Qualify how the Jolt step relates to P3 and P5: whether P3 observes this tick's step or the previous one, and whether a committed pose may be written back to a rigid body without discarding solver state (TH-15 PC-01). This is engine behaviour that nobody has measured, and it needs a controlled world under [Q-E01](../BACKLOG.md#q-e01).
- **The rigid comparison metric.** The gate needs a rate comparison before a rigid change can be called a regression (lessons line 61; `gate.mjs:413`).
- **Platforms.** Measure rates on each target separately. A distribution measured on Linux x64 does not qualify Windows 11 x64 (inference).

Reconsider this decision if Andrew's play reverses the preference, if rigid divergence grows enough that n ≥ 20 cannot separate the changes he cares about, or if a product requirement for exact replay appears. Networked play is one such requirement, and it would also reopen TADR-005.
