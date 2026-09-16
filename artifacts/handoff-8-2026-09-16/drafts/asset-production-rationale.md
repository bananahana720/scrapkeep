# Rationale: dependency map and open-question register for the asset production drafts

Staging draft DRAFT-ASSETS attempt A3, lease DRAFT-ASSETS-L3, revised at base `8af2ead4ceb2e5691a9b390df11622f67a5a9b7c` as the import-readiness pass after review R2 (TRACKING EV-0435) and Andrew's production decisions at TRACKING EV-0447. It accompanies `asset-production-cards.md` in this directory. It records the batch asset list and its file locations, the order in which the drafted cards can run, every registered or proposed question that gates them, and the disposition of each drafting question. It answers no question and authorizes no work: the coordinator cannot expand approved scope (ORCHESTRATOR line 21), so every card below runs only inside a sprint Andrew authorizes.

## Recorded batch asset list and file locations

Andrew recorded the first batch's asset list and file locations before the budget at TRACKING EV-0447 decision 1, on top of the scope at TRACKING EV-0372 and the starting-mech growth state at TRACKING EV-0423 decision 2. The measured budget stays open under Q-P26 until the native slice measures it. The path groupings below are the file locations the cards lease; each is a path grouping and never a durable gameplay ID (HF-01 line 21). A card leases only its own sub-path, so cards able to run at the same time never share a write path.

| Asset | Concept and review records | Editable masters and provenance | Runtime inputs and scenes |
| --- | --- | --- | --- |
| Shared rolling core and enclosed cockpit, starting mech | `docs/art/production/rolling_core/**` | `source-assets/rolling_core/` with `blockout/`, `model/`, `textures/` and `provenance/` sub-paths | `native/content/rolling_core/assets/**` and `scenes/**`; procedural motion under `native/presentation/motion/` |
| Fuse the pilot, the cable hoop heads and the mounted tool, starting mech | `docs/art/production/fuse/**` | `source-assets/fuse/` with `blockout/`, `pilot/`, `tool/`, `effects/`, `audio/` and `provenance/` sub-paths | `native/content/fuse/assets/` and `scenes/` with `pilot/`, `tool/` and `effects/` sub-paths, and `native/content/fuse/assets/audio/**` |
| Iron Orchard enemy family | `docs/art/production/iron_orchard_enemies/**` | `source-assets/iron_orchard_enemies/` with `blockout/`, `models/`, `textures/`, `audio/` and `provenance/` sub-paths | `native/content/iron_orchard_enemies/assets/models/**`, `assets/audio/**` and `scenes/**` |
| Iron Orchard environment module set | `docs/art/production/iron_orchard_modules/**` | `source-assets/iron_orchard_modules/` with `blockout/`, `models/`, `textures/` and `provenance/` sub-paths | `native/content/iron_orchard_modules/assets/**` and `scenes/**` |

Which named enemies and which modules fill the enemy family and the module set stay with Q-P25 and with Andrew's review of ART-25; the list fixes the four assets and where their files go, not their members.

## Dependency map from concept to imported asset

Card states for existing dependencies are read from the TRACKING task index at the base. PD-01, PD-03, TH-15, TH-18, TH-19 and FR-07 are done. SC-02, SC-03, SC-04, SC-05, SC-06 and SC-08 are done; SC-01 is in review and SC-07 is queued. TH-17 and TH-20 to TH-31 are queued; TH-29 and TH-31 between them wait on TH-20 to TH-28 and TH-30, so the whole engineering handoff sits in front of every native-stage card that imports or executes.

Each row names one card. A card's row comes after the rows of every drafted card it depends on. `Stage` is `concept` for cards proposed for the sprint after the current one under EV-0423 decision 1, `native` for cards gated on `Q-E01 native slice and Andrew's production authorization`, and `proof` for NQ-01.

### Lane 1: native qualification

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | NQ-01 synthetic import proof and sidecar repair, one card under TH-19 RR-09 | TH-19 | none; native execution authorization | proof |

### Lane 2: shared chassis and Fuse, the first concept-to-import path

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | ART-01 core and cockpit concept | PD-01 | none | concept |
| 2 | ART-02 Fuse construction C concept | ART-01, PD-01 | none | concept |
| 3 | ART-03 rough blockout | ART-01, ART-02 | none; the EV-0447 decision 1 list and locations | concept |
| 4 | ART-04 silhouette and sightline check at the provisional distance | ART-03 | none | concept |
| 5 | ART-05 motion brief for Andrew's Q-P27 answer | ART-03 | none | concept |
| 6 | ART-06 core and cockpit model | ART-03, ART-04, ART-05 | Q-E01, Q-E03, Q-P26, Q-P27 | native |
| 7 | ART-07 pilot model | ART-02, ART-03, ART-04 | Q-E01, Q-E03, Q-P06, Q-P26 | native |
| 8 | ART-08 emitter, hoop and heads model | ART-02, ART-03, ART-04, ART-06 | Q-E01, Q-E03, Q-P13, Q-P26 | native |
| 9 | ART-09 core rig | ART-05, ART-06 | Q-E01, Q-E03, Q-P26, Q-P27 | native |
| 10 | ART-10 pilot rig | ART-05, ART-07 | Q-E01, Q-E03, Q-P06, Q-P26, Q-P27 | native |
| 11 | ART-11 hoop head rig | ART-05, ART-08, ART-09 | Q-E01, Q-E03, Q-P13, Q-P26, Q-P27 | native |
| 12 | ART-12 expression clips | ART-10 | Q-E01, Q-E03, Q-P26, Q-P27 | native |
| 13 | ART-13 tool action clips | ART-04, ART-11, FR-07 | Q-E01, Q-E03, Q-P13, Q-P20, Q-P26, Q-P27 | native |
| 14 | ART-15 discharge effect specifications, source masters only | ART-04, ART-11 | Q-E01, Q-E03, Q-P13, Q-P26 | native |
| 15 | ART-16 miscast tell specifications, source masters only | ART-13, ART-15 | Q-E01, Q-E03, Q-P13, Q-P26, Q-P30, Q-P38 | native |
| 16 | ART-17 core import | NQ-01, ART-06, ART-09, SC-01, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P26 | native |
| 17 | ART-18 pilot, tool and clip import, with the native silhouette recheck | NQ-01, ART-04, ART-07, ART-08, ART-10, ART-11, ART-12, ART-13, ART-17, FR-07, SC-01, SC-02, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P06, Q-P13, Q-P26 | native |
| 18 | ART-14 procedural motion in Godot | ART-05, ART-09, ART-12, ART-13, ART-17, ART-18, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P22, Q-P27 | native |
| 19 | ART-19 effect build and import | NQ-01, ART-15, ART-16, ART-18, FR-07, SC-02, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P13, Q-P26 | native |

Before the first native-stage card can be ready, Andrew must record Q-E01's native slice and a production authorization (EV-0423 decision 1). ART-17, the first imported asset, also needs Q-P26's measured budget, Q-P27's motion treatment, Q-E03 and Q-E04, NQ-01, SC-01, SC-07 and the engineering handoff through TH-31.

### Lane 3: Iron Orchard enemy family

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | ART-20 candidate concept and telegraph sheets | PD-01 | none; supports Andrew's Q-P25 selection | concept |
| 2 | ART-21 rough blockout and telegraph-pose check at the provisional distance | ART-20 | Q-P25 | concept |
| 3 | ART-22 model | ART-21 | Q-E01, Q-E03, Q-P25, Q-P26 | native |
| 4 | ART-23 rig under the hybrid approach | ART-22 | Q-E01, Q-E03, Q-P25, Q-P26 | native |
| 5 | ART-29 hand-keyed wind-up and attack clips | ART-21, ART-23 | Q-E01, Q-P25, Q-P26 | native |
| 6 | ART-24 import, with the native telegraph-pose recheck | NQ-01, ART-21, ART-22, ART-23, ART-29, SC-02, SC-04, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P25, Q-P26 | native |

### Lane 4: Iron Orchard environment module set

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | ART-25 landscape study and candidate modules | PD-01 | none | concept |
| 2 | ART-26 rough module blockout, no clearance measurement | ART-25 | Q-P23 | concept |
| 3 | ART-27 module model | ART-26 | Q-E01, Q-E03, Q-P26 | native |
| 4 | ART-28 module import | NQ-01, ART-27, SC-05, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P23, Q-P26 | native |
| 5 | NQ-03 fully grown clearance trial, held back from import until its collision card exists | ART-28, TH-15, TH-29, TH-31, and the module collision card of DQ-05 | Q-E01, Q-P22 | native |

### Lane 5: sound

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | SND-01 Fuse directed weapon cues | FR-07, PD-03, TH-17 | Q-E01, Q-P31, Q-P32 | native |
| 2 | SND-02 field and miscast cues | FR-07, PD-03, SND-01, TH-17 | Q-E01, Q-P13, Q-P31, Q-P32 | native |
| 3 | SND-03 ultimate cue | FR-07, PD-03, SND-01, TH-17 | Q-E01, Q-P17, Q-P20, Q-P31, Q-P32 | native |
| 4 | SND-04 enemy warning cues | ART-29, PD-03, TH-17 | Q-E01, Q-P25, Q-P31, Q-P32 | native |
| 5 | SND-05 audio import | NQ-01, SND-01, SND-02, SND-03, SND-04, SC-07, TH-17, TH-29, TH-31 | Q-E01, Q-E03, Q-P31 | native |

SND-05 waits on all four cue cards, so an unanswered Q-P13 or Q-P20 holds the whole audio import; splitting it is a recorded definition change for the coordinator to propose. Sound cards do not block on Q-P26 because its affected work names no audio and Q-P31 is the sound batch's manifest gate (DQ-15).

### What Andrew could authorize for the sprint after the current one

Under EV-0423 decision 1 and EV-0447 decision 1 the concept-stage cards are the candidates. ART-01, ART-02, ART-03, ART-04, ART-05, ART-20 and ART-25 have no blocking question once their lane predecessors are done; ART-21 needs Q-P25 and ART-26 needs Q-P23. Every concept-stage card leases concrete paths, so none waits on its own outcome. NQ-01 needs only a native execution authorization. Each would enter a sprint only by Andrew's authorization recorded in TRACKING; this file proposes and does not add them to any scope.

### Human-hands steps across the batch

Andrew's hands are needed for: installing Blender, Krita and Audacity, none of which is installed at the base; recording execution authorization for Blender, Krita, Audacity and Godot; every verdict and review recorded under PD-01 PF-12, including the native rechecks in ART-18 and ART-24; answering the questions below; and any physical sound recording. Each affected card names its own steps at the end of its Verification field.

### Re-sizing checks

ART-22, ART-23, ART-29 and ART-24 are sized for a small family and are re-sized, by definition change, if the Q-P25 answer names more members or attacks than one M card can review. ART-12, ART-13 and ART-18 are re-sized likewise when the Q-P27 answer fixes the clip lists, and SND-05 when the Q-P31 answer fixes the sound batch. At the Q-E01 answer, the native-stage cards that rely on runtime pieces without cards yet (ART-14, ART-17, ART-24, ART-28 and NQ-03) have their dependencies re-validated (review R2 note 12; BACKLOG line 28).

## Gating question register

Each question appears once. `Blocks` lists the cards whose Blocking questions field names it. `Shapes` lists the cards that register it as non-blocking and must hold under every answer. Partial answers are TRACKING's at the base; none is extended here.

| Question | What it owns for this batch | Blocks | Shapes |
| --- | --- | --- | --- |
| [Q-E01](#q-e01) | The approved native slice and explicit go; with Andrew's production authorization it is the gate of every native-stage card (EV-0423 decision 1) | ART-06, ART-07, ART-08, ART-09, ART-10, ART-11, ART-12, ART-13, ART-14, ART-15, ART-16, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-27, ART-28, ART-29, NQ-03, SND-01, SND-02, SND-03, SND-04, SND-05 | none |
| [Q-E03](#q-e03) | Target hardware and the measured asset budgets that bound meshes, textures, rigs, clips, effects and audio | ART-06, ART-07, ART-08, ART-09, ART-10, ART-11, ART-12, ART-13, ART-14, ART-15, ART-16, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-27, ART-28, SND-05 | NQ-01 |
| [Q-E04](#q-e04) | Renderer, backend and texture formats for import settings and effects | ART-14, ART-17, ART-18, ART-19, ART-24, ART-28 | ART-06, ART-15, ART-16, ART-27 |
| [Q-E06](#q-e06) | Licensing and notices; admission records evidence without distribution approval | none | ART-17, ART-18, ART-19, ART-24, ART-28, SND-01, SND-02, SND-03, SND-04, SND-05 |
| [Q-E10](#q-e10) | Overlapping attack admission and pressure limits the enemy sheets and poses depict | none | ART-20, ART-21 |
| [Q-E13](#q-e13) | Proof scripts and diagnostics in exports | none | ART-17, ART-18, ART-24, ART-28, NQ-01 |
| [Q-P06](#q-p06) | Fuse's species and whether the cast stays animal-only; Fuse as first kit is recorded (EV-0372) | ART-07, ART-10, ART-18 | ART-01, ART-02, SND-01 |
| [Q-P07](#q-p07) | Which regions enter production beyond the Iron Orchard content EV-0372 names | none | ART-25 |
| [Q-P10](#q-p10) | Visible mass change at the starting mech | none | ART-01, ART-03, ART-06 |
| [Q-P11](#q-p11) | Node content that could change tool actions | none | ART-13 |
| [Q-P13](#q-p13) | Element pool, and so the head set, plus miscast eligibility, frequency, severity and warnings; the shape rule is recorded (EV-0322) | ART-08, ART-11, ART-13, ART-15, ART-16, ART-18, ART-19, SND-02 | ART-02, ART-03, ART-12 |
| [Q-P17](#q-p17) | Music states that an ultimate cue may interact with | SND-03 | none |
| [Q-P20](#q-p20) | What the ultimate is and how it is earned, for its tool action and cue | ART-13, SND-03 | ART-02, ART-08 |
| [Q-P21](#q-p21) | Movement and defensive rhythm behind suspension and retraction ranges | none | ART-05, ART-09, ART-14 |
| [Q-P22](#q-p22) | The ordinary growth envelope and minimum route clearance; the batch's authored state is the starting mech (EV-0423 decision 2) | ART-14, NQ-03 | ART-01, ART-02, ART-03, ART-04, ART-05, ART-06, ART-08, ART-09, ART-25, ART-26 |
| [Q-P23](#q-p23) | How modules assemble into levels | ART-26, ART-28 | ART-25, NQ-03 |
| [Q-P24](#q-p24) | Terrain consequence mechanics a module might carry | none | ART-25, ART-26, NQ-03 |
| [Q-P25](#q-p25) | Which named enemy family members and attack grammar enter production | ART-21, ART-22, ART-23, ART-24, ART-29, SND-04 | ART-20 |
| [Q-P26](#q-p26) | The measured budget, which blocks final assets only; the asset list and file locations are recorded (EV-0447 decision 1), as are the scope (EV-0372) and the starting mech (EV-0423 decision 2) | ART-06, ART-07, ART-08, ART-09, ART-10, ART-11, ART-12, ART-13, ART-15, ART-16, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-27, ART-28, ART-29 | ART-03, ART-21, ART-25, ART-26 |
| [Q-P27](#q-p27) | The mech's motion treatment specifics, including expression and tool action lists and the fabrication sequence; the hybrid split is recorded (EV-0372) | ART-06, ART-09, ART-10, ART-11, ART-12, ART-13, ART-14 | ART-01, ART-02, ART-03, ART-04, ART-05, ART-07 |
| [Q-P28](#q-p28) | Barks and voice, excluded from expression clips and cues | none | ART-12, SND-01 |
| [Q-P30](#q-p30) | Which cues and tells are required feedback | ART-16 | ART-15, ART-19, SND-04 |
| [Q-P31](#q-p31) | The first sound batch, source method, durations and audition setup; the sound batch's manifest gate | SND-01, SND-02, SND-03, SND-04, SND-05 | none |
| [Q-P32](#q-p32) | Camera distance bounds and response, cue tails and priority; the orchard distance is provisional for Fuse (EV-0423 decision 4) and the enemies (EV-0447 decision 2), with native rechecks in ART-18 and ART-24 | SND-01, SND-02, SND-03, SND-04 | ART-02, ART-04, ART-05, ART-14, ART-15, ART-18, ART-21 |
| [Q-P33](#q-p33) | Regional lighting, weather and wayfinding the sheets and textures assume | none | ART-01, ART-20, ART-25, ART-26, ART-27 |
| [Q-P38](#q-p38) | Requiredness of feedback that TH-16 RP-17 routes to it alongside Q-P30 | ART-16 | ART-15, ART-19 |
| [Q-P42](#q-p42) | Proposed entry: the enemy family's motion specifics per member; the hybrid approach is recorded (EV-0447 decision 3), and the remainder gates the parameter rows of ART-23 and ART-29 | none | ART-23, ART-29 |

Q-P04 is resolved (EV-0372) and is cited as an input, not a gate. Production authorization is Andrew's (ORCHESTRATOR line 32; EV-0423 decision 1), not a coordinator decision at admission. Review R2's three plain-language questions are answered by EV-0447 decisions 1 to 3.

## Drafting question dispositions

| ID | Question | Disposition | Cards affected |
| --- | --- | --- | --- |
| DQ-01 | HF-01 owns no path for production concept work or for the Audio cards' writes. | Proposed amendment for the coordinator, written as disjoint rows because HF-01 line 19 requires rows to be disjoint and a card to claim no unlisted path. Row 1: `docs/art/production/**`, owner Technical art, permitting production concept sheets, image prompt records, paintovers, review captures, check records and motion briefs carrying PD-01 PF provenance, forbidding runtime inputs, editable 3D masters, generated engine cache and any claim that an image proves a physical property, governed by TADR-003 line 35 and consistent with TH-19 OC-07. Row 2: `source-assets/*/audio/**`, owner Audio, permitting editable audio masters, synthesis and transformation recipes, provenance, license evidence and notices, forbidding runtime loading, generated engine cache and credentials, governed by TADR-003 line 35. Row 3: `native/content/*/assets/audio/**`, owner Audio, permitting reviewed audio runtime inputs with adjacent import settings and UID sidecars, forbidding editable masters, generated cache and unadmitted content, governed by TADR-003 lines 27 and 35. The existing `source-assets/**` and `native/content/*/assets/**` rows gain the words "excluding the audio rows" so every path keeps exactly one row. | ART-01, ART-02, ART-04, ART-05, ART-18, ART-20, ART-21, ART-24, ART-25, SND-01 to SND-05 |
| DQ-02 | HF-01 line 30 permits materials but names no shader source. | Settled from sources: effects use a ParticleProcessMaterial until a coordinator amendment admits shader source (ART-15 item 3; ART-19 boundary). | ART-15, ART-19 |
| DQ-03 | Blender, Krita and Audacity have no pinned versions and are not installed. | Proposal: pin the versions installed at first use, recorded in the PD-01 PF-06 recipe row of each record that uses them. Installation is Andrew's hands-on step, not a card outcome. | Every card that uses a tool |
| DQ-04 | No question owned the enemy family's motion treatment. | Replaced by proposed register entry Q-P42, registered by the coordinator with Andrew's approach-level answer (EV-0447 decision 3); the per-member specifics are parameter rows in ART-23 and ART-29, gated on Q-P42's remainder. | ART-23, ART-29 |
| DQ-05 | No card owns module collision geometry. | Settled from sources: a later card under TH-15's fixture contract, defined in grooming. NQ-03 is held back from the closure definition import until that card exists (TRACKING EV-0435), and ART-26 and ART-27 write no collision geometry. | ART-26, ART-27, NQ-03 |
| DQ-06 | Camera distance for the silhouette checks. | Settled by EV-0423 decision 4 for Fuse and EV-0447 decision 2 for the Iron Orchard enemies: the orchard distance at `src/orchard/scene.js` line 410 is provisional, rechecked natively in ART-18 and ART-24; not an answer to Q-P32. | ART-04, ART-18, ART-21, ART-24 |
| DQ-07 | Budget and hardware gating of final assets. | Settled by EV-0423 decision 1 and EV-0447 decision 1: final models, rigs, clips, effects and sounds wait for the native build. Every native-stage art card that writes `source-assets/**` blocks on Q-P26's budget, and every final model, rig, clip, effect and import card from ART-06 to ART-19 blocks on Q-E03 (review R2 note 6). | Native-stage cards |
| DQ-08 | NQ sequencing and admissibility. | Settled by merging NQ-01 and NQ-02 into NQ-01, whose definition of done records TH-19 RR-09's failing run and integrates only the passing candidate (ORCHESTRATOR lines 42 and 104). NQ-02 is retired. | NQ-01 |
| DQ-09 | Who makes concept art. | Settled by EV-0423 decision 3: image prompts plus paintover, provenance per PD-01 PF rows, the generator and its output terms recorded as PD-01 PF-05 license evidence before use (ART-01 item 2), and no claim that a generated image proves a physical property (PD-01 line 63). | ART-01, ART-02, ART-20, ART-25 |
| DQ-10 | Schema dependencies. | Settled from sources: SC-06 gates nothing because the batch has no device (BIBLE line 413); SC-05 owns level modules and is admitted at `docs/tech/schemas/SC-05.md`; SC-01 is in review and SC-07 queued at the base. | ART-17, ART-18, ART-28 |
| DQ-11 | Cited receipts sat in an ignored path. | Done in attempt A3: the nine receipts are copied to the tracked `artifacts/handoff-8-2026-09-16/drafts/ctx7/`, every card cites that path, and the check reads receipts from it by default. | Every card citing a receipt |
| DQ-12 | Evidence cards not drafted. | Clearance is NQ-03 under EV-0423 decision 2, using TH-15 PX-09's two-extent setup with its own pass rule, because PX-09's expected observation is a stopped larger extent and PX-10 tests install timing (review R2 note 2). The PD-01 PE-01 and PE-05 executed trials beyond ART-14's, and the PD-03 AU-01 to AU-06, FT-01 and FT-02 sessions, stay grooming work until the handoff's commands and a playable native build exist. | ART-14, NQ-03, SND-01 to SND-05 |
| DQ-13 | Unit names. | Settled from HF-01 line 21 and EV-0447 decision 1: `rolling_core`, `fuse`, `iron_orchard_enemies` and `iron_orchard_modules` are concrete path groupings leased by every card that knows the unit, including ART-20 and ART-25 (review R2 F1); no unit is a durable ID, and members are named inside a grouping only after Q-P25 and Andrew's review of ART-25. | Every card with a unit path |
| DQ-14 | EV-0447 decision 3 makes enemy locomotion and turning procedural in Godot, and no drafted card implements it. | Grooming work for a Rendering/input/UI card analogous to ART-14, defined after Q-P42's specifics and ART-23's bone list exist; not drafted here. | ART-23, ART-24 |
| DQ-15 | SND cards write `source-assets/**` without blocking on Q-P26. | Recorded deviation from attempt A2's required change 5: BACKLOG Q-P26's affected work names models, textures, rigs, attachment sizing, material and lighting work and import checks, not audio, and Q-P31 is the sound batch's manifest gate, which already blocks every SND card (review R2 note 8). | SND-01 to SND-04 |

## Context7 receipts

Nine receipts, each recording command, UTC retrieval time and exit status 0, retrieved at 2026-09-16T19:36:37Z except `g1b-gltf-skinned-import.txt` at 19:36:55Z, and tracked at `artifacts/handoff-8-2026-09-16/drafts/ctx7/` since attempt A3. At most two queries were used per question. No tool fact was added in attempts A2 or A3, so no query ran.

| Receipt | Library | Query topic | Lines cited |
| --- | --- | --- | --- |
| `b1-armatures.txt` | `/websites/blender_manual_en` | armature deform parenting | 8, 16 and 24 |
| `b2-weight-paint.txt` | `/websites/blender_manual_en` | weight painting and vertex groups | 20 and 28 |
| `b3-actions-nla.txt` | `/websites/blender_manual_en` | actions and NLA | 8, 32 and 40 |
| `b4-gltf-export.txt` | `/websites/blender_manual_en` | glTF export of skinned meshes | 4, 8, 16, 24 and 40 |
| `g1-gltf-import.txt` | `/websites/godotengine_en_4_7` | scene import scripts | 8 and 111 |
| `g1b-gltf-skinned-import.txt` | `/websites/godotengine_en_4_7` | glTF skins, skeletons and animations on import | 14, 22 to 36, 53 and 83 to 94 |
| `g2-skeleton.txt` | `/websites/godotengine_en_4_7` | procedural bone poses | 8, 50, 58 and 66 |
| `g3-animtree.txt` | `/websites/godotengine_en_4_7` | AnimationTree and AnimationPlayer | 75 and 83 |
| `g4-particles.txt` | `/websites/godotengine_en_4_7` | GPU particles and process materials | 26, 81 and 91 |

Retrieval limits: no receipt states Godot's import options for a skinned glTF scene beyond the import-state classes, how imported clip names map from Blender action or track names, Audacity or Krita behaviour, or any IK node. The cards assert none of those, and ART-18's clip-name check is an observation to make, not a documented guarantee.

## Evidence limits

This is a paper plan. The executable check (`artifacts/local/tasks/DRAFT-ASSETS/check_drafts.py`) establishes card structure, that cited section rows, questions and dependency cards exist, that each card's body names no drafted card outside its dependencies or downstream cards, that the dependency graph has no cycle and the map respects it, that stage gates, Lane labels and Q-P26 gating agree with each card's files, that cards able to run at the same time lease disjoint write paths, that no concept-stage card leases a placeholder path, register consistency, and that every digit is an ID, a line citation or tied to the cited line that contains it. It does not verify line citations to Bible, section or project files, that a citation supports its sentence, spelled-out counts, hyphenated tokens that only resemble IDs, or numbers chained after a line citation (review R2 item 5). No asset, image, sound, installation, network retrieval, engine or Blender run took place.
