# Rationale: dependency map and open-question register for the asset production drafts

Staging draft DRAFT-ASSETS attempt A2, lease DRAFT-ASSETS-L2, revised at base `0ea92ce738d8ea0eb33de57eb34d5a6ce101bce4` after review R1 and Andrew's production decisions at TRACKING EV-0423. It accompanies `asset-production-cards.md` in this directory. It records the order in which the drafted cards can run, every registered or proposed question that gates them, and the disposition of each drafting question. It answers no question and authorizes no work: the coordinator cannot expand approved scope (ORCHESTRATOR line 21), so every card below runs only inside a sprint Andrew authorizes.

## Dependency map from concept to imported asset

Card states for existing dependencies are read from the TRACKING task index at the base. PD-01, PD-03, TH-18, TH-19, SC-03, SC-04 and SC-05 are done. FR-07 is ready. SC-06 and SC-08 are in review. SC-01 and SC-02 are blocked. SC-07, TH-17 and TH-20 to TH-31 are queued; TH-29 and TH-31 between them wait on TH-20 to TH-28 and TH-30, so the whole engineering handoff sits in front of every native-stage card that imports or executes.

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
| 3 | ART-03 rough blockout | ART-01, ART-02 | Q-P26 | concept |
| 4 | ART-04 silhouette and sightline check at the provisional distance | ART-03 | none | concept |
| 5 | ART-05 motion brief for Andrew's Q-P27 answer | ART-03 | none | concept |
| 6 | ART-06 core and cockpit model | ART-03, ART-04, ART-05 | Q-E01, Q-E03, Q-P26, Q-P27 | native |
| 7 | ART-07 pilot model | ART-02, ART-03, ART-04 | Q-E01, Q-E03, Q-P06, Q-P26 | native |
| 8 | ART-08 emitter, hoop and heads model | ART-02, ART-03, ART-04, ART-06 | Q-E01, Q-E03, Q-P13, Q-P26 | native |
| 9 | ART-09 core rig | ART-05, ART-06 | Q-E01, Q-E03, Q-P26, Q-P27 | native |
| 10 | ART-10 pilot rig | ART-05, ART-07 | Q-E01, Q-P06, Q-P26, Q-P27 | native |
| 11 | ART-11 hoop head rig | ART-05, ART-08, ART-09 | Q-E01, Q-P13, Q-P26, Q-P27 | native |
| 12 | ART-12 expression clips | ART-10 | Q-E01, Q-P26, Q-P27 | native |
| 13 | ART-13 tool action clips | ART-04, ART-11, FR-07 | Q-E01, Q-P13, Q-P20, Q-P26, Q-P27 | native |
| 14 | ART-15 discharge effect specifications, source masters only | ART-04, ART-11 | Q-E01, Q-P13, Q-P26 | native |
| 15 | ART-16 miscast tell specifications, source masters only | ART-13, ART-15 | Q-E01, Q-P13, Q-P26, Q-P30, Q-P38 | native |
| 16 | ART-17 core import | NQ-01, ART-06, ART-09, SC-01, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P26 | native |
| 17 | ART-18 pilot, tool and clip import, with the native silhouette recheck | NQ-01, ART-04, ART-07, ART-08, ART-10, ART-11, ART-12, ART-13, ART-17, FR-07, SC-01, SC-02, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P06, Q-P13, Q-P26 | native |
| 18 | ART-14 procedural motion in Godot | ART-05, ART-09, ART-12, ART-13, ART-17, ART-18, TH-29, TH-31 | Q-E01, Q-E04, Q-P22, Q-P27 | native |
| 19 | ART-19 effect build and import | NQ-01, ART-15, ART-16, ART-18, FR-07, SC-02, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P13, Q-P26 | native |

Before the first native-stage card can be ready, Andrew must record Q-E01's native slice and a production authorization (EV-0423 decision 1). ART-17, the first imported asset, also needs Q-P26's bounded manifest and measured budget, Q-P27's motion treatment, Q-E03 and Q-E04, NQ-01, SC-01, SC-07 and the engineering handoff through TH-31.

### Lane 3: Iron Orchard enemy family

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | ART-20 candidate concept and telegraph sheets | PD-01 | none; supports Andrew's Q-P25 selection | concept |
| 2 | ART-21 rough blockout and telegraph-pose check | ART-20 | Q-P25, Q-P26, Q-P32 | concept |
| 3 | ART-22 model | ART-21 | Q-E01, Q-E03, Q-P25, Q-P26 | native |
| 4 | ART-23 rig | ART-22 | Q-E01, Q-E03, Q-P25, Q-P26, Q-P42 | native |
| 5 | ART-29 stage clips | ART-21, ART-23 | Q-E01, Q-P25, Q-P26, Q-P42 | native |
| 6 | ART-24 import | NQ-01, ART-22, ART-23, ART-29, SC-02, SC-04, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P25, Q-P26 | native |

### Lane 4: Iron Orchard environment module set

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | ART-25 landscape study and candidate modules | PD-01 | none | concept |
| 2 | ART-26 rough module blockout, no clearance measurement | ART-25 | Q-P23, Q-P26 | concept |
| 3 | ART-27 module model | ART-26 | Q-E01, Q-E03, Q-P26 | native |
| 4 | ART-28 module import | NQ-01, ART-27, SC-05, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P23, Q-P26 | native |
| 5 | NQ-03 fully grown clearance trial | ART-28, TH-15, TH-29, TH-31, and the module collision card of DQ-05 | Q-E01, Q-P22 | native |

### Lane 5: sound

| Step | Card | Waits on (cards) | Blocking questions | Stage |
| --- | --- | --- | --- | --- |
| 1 | SND-01 Fuse directed weapon cues | FR-07, PD-03, TH-17 | Q-E01, Q-P31, Q-P32 | native |
| 2 | SND-02 field and miscast cues | FR-07, PD-03, SND-01, TH-17 | Q-E01, Q-P13, Q-P31, Q-P32 | native |
| 3 | SND-03 ultimate cue | FR-07, PD-03, SND-01, TH-17 | Q-E01, Q-P17, Q-P20, Q-P31, Q-P32 | native |
| 4 | SND-04 enemy warning cues | ART-29, PD-03, TH-17 | Q-E01, Q-P25, Q-P31, Q-P32 | native |
| 5 | SND-05 audio import | NQ-01, SND-01, SND-02, SND-03, SND-04, SC-07, TH-17, TH-29, TH-31 | Q-E01, Q-E03, Q-P31 | native |

SND-05 waits on all four cue cards, so an unanswered Q-P13 or Q-P20 holds the whole audio import; splitting it is a recorded definition change for the coordinator to propose.

### What Andrew could authorize for the sprint after the current one

Under EV-0423 decision 1 the concept-stage cards are the candidates: ART-01, ART-02, ART-04, ART-05, ART-20 and ART-25 have no blocking question, and ART-03, ART-21 and ART-26 each need a recorded Q-P26 answer (a bounded manifest and allowed output paths) before they can be ready, plus Q-P25 and Q-P32 for ART-21 and Q-P23 for ART-26. NQ-01 needs only a native execution authorization. Each would enter a sprint only by Andrew's authorization recorded in TRACKING; this file proposes and does not add them to any scope.

### Human-hands steps across the batch

Andrew's hands are needed for: installing Blender, Krita and Audacity, none of which is installed at the base; recording execution authorization for Blender, Krita, Audacity and Godot; every verdict and review recorded under PD-01 PF-12; answering the questions below; and any physical sound recording. Each affected card names its own steps at the end of its Verification field.

### Re-sizing checks

ART-22, ART-23, ART-29 and ART-24 are sized for a small family and are re-sized, by definition change, if the Q-P25 answer names more members or attacks than one M card can review. ART-12, ART-13 and ART-18 are re-sized likewise when the Q-P27 answer fixes the clip lists, and SND-05 when the Q-P31 answer fixes the sound batch.

## Gating question register

Each question appears once. `Blocks` lists the cards whose Blocking questions field names it. `Shapes` lists the cards that register it as non-blocking and must hold under every answer. Partial answers are TRACKING's at the base; none is extended here.

| Question | What it owns for this batch | Blocks | Shapes |
| --- | --- | --- | --- |
| [Q-E01](#q-e01) | The approved native slice and explicit go; with Andrew's production authorization it is the gate of every native-stage card (EV-0423 decision 1) | ART-06, ART-07, ART-08, ART-09, ART-10, ART-11, ART-12, ART-13, ART-14, ART-15, ART-16, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-27, ART-28, ART-29, NQ-03, SND-01, SND-02, SND-03, SND-04, SND-05 | none |
| [Q-E03](#q-e03) | Target hardware and the measured asset budgets that bound meshes, textures, rigs, effects and audio | ART-06, ART-07, ART-08, ART-09, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-27, ART-28, SND-05 | ART-14, ART-15, NQ-01 |
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
| [Q-P25](#q-p25) | Which named enemy family and attack grammar enter production | ART-21, ART-22, ART-23, ART-24, ART-29, SND-04 | ART-20 |
| [Q-P26](#q-p26) | The bounded asset manifest, allowed output paths and measured budget; batch scope (EV-0372) and the starting-mech growth state (EV-0423 decision 2) are recorded | ART-03, ART-06, ART-07, ART-08, ART-09, ART-10, ART-11, ART-12, ART-13, ART-15, ART-16, ART-17, ART-18, ART-19, ART-21, ART-22, ART-23, ART-24, ART-26, ART-27, ART-28, ART-29 | ART-25 |
| [Q-P27](#q-p27) | The motion treatment's specifics, including expression and tool action lists and the fabrication sequence; the hybrid split is recorded (EV-0372) | ART-06, ART-09, ART-10, ART-11, ART-12, ART-13, ART-14 | ART-01, ART-02, ART-03, ART-04, ART-05, ART-07 |
| [Q-P28](#q-p28) | Barks and voice, excluded from expression clips and cues | none | ART-12, SND-01 |
| [Q-P30](#q-p30) | Which cues and tells are required feedback | ART-16 | ART-15, ART-19, SND-04 |
| [Q-P31](#q-p31) | The first sound batch, source method, durations and audition setup; the sound equivalent of Q-P26's manifest gate | SND-01, SND-02, SND-03, SND-04, SND-05 | none |
| [Q-P32](#q-p32) | Camera distance bounds and response, cue tails and priority; decision 4's provisional distance covers Fuse's model-lock check only | ART-21, SND-01, SND-02, SND-03, SND-04 | ART-02, ART-04, ART-05, ART-14, ART-15, ART-18 |
| [Q-P33](#q-p33) | Regional lighting, weather and wayfinding the sheets and textures assume | none | ART-01, ART-20, ART-25, ART-26, ART-27 |
| [Q-P38](#q-p38) | Requiredness of feedback that TH-16 RP-17 routes to it alongside Q-P30 | ART-16 | ART-15, ART-19 |
| [Q-P42](#q-p42) | Proposed entry: the enemy family's motion treatment, owned by Andrew (replaces A1's DQ-04) | ART-23, ART-29 | none |

Q-P04 is resolved (EV-0372) and is cited as an input, not a gate. Production authorization is Andrew's (ORCHESTRATOR line 32; EV-0423 decision 1), not a coordinator decision at admission. The plain-language questions review R1 proposed for Andrew are answered by EV-0423 decisions 1 to 4 except these, which stay open and are put to him through the register: whether decision 4's provisional distance also serves the enemy telegraph check (ART-21, under Q-P32), and whether Q-P26's manifest and output paths can be recorded before its budget so rough blockouts can start (ART-03, ART-21, ART-26).

## Drafting question dispositions

| ID | Question | Disposition | Cards affected |
| --- | --- | --- | --- |
| DQ-01 | HF-01 owns no path for production concept work, and the SND cards write Technical-art families. | Proposed amendment for the coordinator (HF-01 line 19 requires one before a card claims the path). Add a row: `docs/art/production/**` owned by Technical art, permitting production concept sheets, image prompt records, paintovers, review captures, check records and motion briefs carrying PD-01 PF provenance, forbidding runtime inputs, editable 3D masters, generated engine cache and any claim that an image proves a physical property, governed by TADR-003 line 35 and consistent with TH-19 OC-07. Amend the `source-assets/**` and `native/content/*/assets/**` rows to name Audio as owner of audio masters, audio recipes and audio runtime inputs with their sidecars, under the same forbidden content. | ART-01, ART-02, ART-04, ART-05, ART-18, ART-20, ART-21, ART-25, SND-01 to SND-05 |
| DQ-02 | HF-01 line 30 permits materials but names no shader source. | Settled from sources as R1 proposed: effects use a ParticleProcessMaterial until a coordinator amendment admits shader source (ART-15 item 3; ART-19 boundary). | ART-15, ART-19 |
| DQ-03 | Blender, Krita and Audacity have no pinned versions and are not installed. | Proposal: pin the versions installed at first use, recorded in the PD-01 PF-06 recipe row of each record that uses them. Installation is Andrew's hands-on step, not a card outcome. | Every card that uses a tool |
| DQ-04 | No question owned the enemy family's motion treatment. | Replaced by proposed register entry Q-P42 owned by Andrew, blocking ART-23 and ART-29 (R1 B4). | ART-23, ART-29 |
| DQ-05 | No card owns module collision geometry. | Settled from sources as R1 proposed: a later card under TH-15's fixture contract, defined in grooming; NQ-03 is not assignable until it is done, and ART-26 and ART-27 write none. | ART-26, ART-27, NQ-03 |
| DQ-06 | Camera distance for the model-lock check. | Settled by EV-0423 decision 4: the orchard browser proof's distance (`src/orchard/scene.js` line 410) is provisional for Fuse's check, rechecked in the native slice by ART-18; not an answer to Q-P32. | ART-04, ART-18 |
| DQ-07 | Budget before import. | Settled by EV-0423 decision 1: final models, rigs, clips and sounds wait for the playable native build, where Q-P26's budget can be measured; every such card blocks on Q-P26 and Q-E03. | Native-stage cards |
| DQ-08 | NQ sequencing and admissibility. | Settled by merging NQ-01 and NQ-02 into NQ-01, whose definition of done records TH-19 RR-09's failing run and integrates only the passing candidate (R1 B2; ORCHESTRATOR lines 42 and 104). NQ-02 is retired. | NQ-01 |
| DQ-09 | Who makes concept art. | Settled by EV-0423 decision 3: image prompts plus paintover, provenance per PD-01 PF rows, and no claim that a generated image proves a physical property (PD-01 line 63). | ART-01, ART-02, ART-20, ART-25 |
| DQ-10 | Schema dependencies differ from the A1 packet. | Settled from sources: SC-06 gates nothing because the batch has no device (BIBLE line 413), and SC-05, now admitted at `docs/tech/schemas/SC-05.md`, owns level modules (EV-0412, EV-0423). | ART-28 |
| DQ-11 | Cited receipts sit in an ignored path. | Resolved: the tracked destination is `artifacts/handoff-8-2026-09-16/drafts/ctx7/`, cited in the cards' reading notes. Copying the nine receipts there from `artifacts/local/tasks/DRAFT-ASSETS/ctx7/` is a coordinator step before import (BACKLOG line 26), outside this lease. | Every card citing a receipt |
| DQ-12 | Evidence cards not drafted. | Clearance: drafted as NQ-03 under EV-0423 decision 2. The PD-01 PE-01 and PE-05 executed trials beyond ART-14's, and the PD-03 AU-01 to AU-06 and FT-01 and FT-02 sessions, stay grooming work until the handoff's commands and a playable native build exist. | ART-14, SND-01 to SND-05 |
| DQ-13 | Unit names. | Settled from HF-01 line 21: `rolling_core` and `fuse` are path groupings; `<enemy_unit>` and `<orchard_modules_unit>` are named at the definition change after Q-P25 and Q-P26 answers; no unit is a durable ID. | Every card with a unit path |

## Context7 receipts

Nine receipts, each recording command, UTC retrieval time and exit status 0, retrieved at 2026-09-16T19:36:37Z except `g1b-gltf-skinned-import.txt` at 19:36:55Z. At most two queries were used per question. Tracked destination under DQ-11: `artifacts/handoff-8-2026-09-16/drafts/ctx7/`. No new tool fact was needed for attempt A2, so no query ran.

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

This is a paper plan. The executable check (`artifacts/local/tasks/DRAFT-ASSETS/check_drafts.py`) establishes card structure, that cited section rows, questions and dependency cards exist, that each card's body names no drafted card outside its dependencies or downstream cards, that the dependency graph has no cycle and the map respects it, that stage gates and Q-P26 gating are present, register consistency, and that every digit is an ID, a line citation or tied to the cited line that contains it. It does not verify line citations to Bible, section or project files, that a citation supports its sentence, or spelled-out counts. No asset, image, sound, installation, engine or Blender run took place.
