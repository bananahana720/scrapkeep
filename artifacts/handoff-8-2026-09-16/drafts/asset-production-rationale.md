# Rationale: dependency map and open-question register for the asset production drafts

Staging draft DRAFT-ASSETS attempt A1, lease DRAFT-ASSETS-L1, base `fb7172775f060b6e74b5f81f4ec2aab67067ad3b`. It accompanies `asset-production-cards.md` in this directory. It records the order in which the drafted cards can run, every registered question that gates them, and the drafting questions the coordinator must dispose of before a definition-import event. It answers no question and authorizes no work.

## Dependency map from concept to imported asset

Card states for existing dependencies are read from the TRACKING task index at the base. PD-01, PD-03, TH-19 and the admitted TH sections are done. TH-17 is queued. SC-01 and SC-02 are blocked. SC-04 is in review. SC-05 and SC-06 are in progress. SC-07 is queued. TH-29 and TH-31 are queued, and between them they wait on TH-20 to TH-28 and TH-30, so the whole engineering handoff sits in front of every native production card.

### Lane 1: native qualification, in parallel with concept work

| Step | Card | Waits on | What it opens |
| --- | --- | --- | --- |
| 1 | NQ-01 | TH-19 | Synthetic fixtures, held unintegrated |
| 2 | NQ-02 | NQ-01 | TH-19 gates IG-01 to IG-04, required by every import card |

### Lane 2: shared chassis and Fuse, the first concept-to-import path

| Step | Card | Waits on (cards) | Waits on (questions that block) |
| --- | --- | --- | --- |
| 1 | ART-01 core and cockpit concept | PD-01 | none |
| 2 | ART-02 Fuse construction C concept | ART-01 | none |
| 3 | ART-03 blockout | ART-02 | none |
| 4a | ART-04 silhouette and sightline check, the model-lock gate | ART-03 | Q-P32 |
| 4b | ART-05 motion brief, delivered to Andrew as Q-P27 input | ART-03 | none |
| 5 | ART-06 core model, ART-07 pilot model, ART-08 emitter and heads model | ART-04; ART-05 for ART-06 | Q-P22, Q-P26, Q-P27 and Q-E03 for ART-06; Q-P06, Q-P26 and Q-E03 for ART-07; Q-P13, Q-P26 and Q-E03 for ART-08 |
| 6 | ART-09 core rig, ART-10 pilot rig, ART-11 hoop head rig | ART-05 with each model | Q-P26 and Q-P27 for all three; Q-E03 for ART-09; Q-P06 for ART-10; Q-P13 for ART-11 |
| 7 | ART-12 expression clips, ART-13 tool action clips | ART-10, ART-11 | Q-P27; Q-P13 and Q-P20 for ART-13 |
| 8 | ART-17 core import | NQ-02, ART-06, ART-09, SC-01, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P26 |
| 9 | ART-14 procedural motion in Godot | ART-05, ART-09, ART-17, TH-29, TH-31 | Q-E01, Q-E04, Q-P22, Q-P27 |
| 10 | ART-15 discharge effects, then ART-16 miscast tells | ART-11, SC-02, TH-29 and TH-31; ART-13 and ART-15 | Q-E01, Q-E04, Q-P13; Q-P30 for ART-16 |
| 11 | ART-18 Fuse pilot, tool and clip import | NQ-02, ART-07, ART-08, ART-10 to ART-13, ART-17, SC-01, SC-02, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P06, Q-P13, Q-P26 |
| 12 | ART-19 effect import | NQ-02, ART-15, ART-16, ART-18, SC-02, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P13, Q-P26 |

The first imported Fuse asset is ART-17, the shared core. Before it can run, Andrew must answer Q-P32 so ART-04 can lock the model, Q-P27 so the brief is selected, Q-P22 and Q-P26 so the model is bounded, and Q-E01, Q-E03 and Q-E04 so native import is authorized and qualified. NQ-02, SC-01, SC-07 and the engineering handoff through TH-31 must also be done.

### Lane 3: Iron Orchard enemy family

| Step | Card | Waits on (cards) | Waits on (questions that block) |
| --- | --- | --- | --- |
| 1 | ART-20 candidate concept and telegraph sheets | PD-01 | none; supports Andrew's Q-P25 selection |
| 2 | ART-21 blockout and telegraph-pose check | ART-20 | Q-P25, Q-P32 |
| 3 | ART-22 model | ART-21 | Q-E03, Q-P25, Q-P26 |
| 4 | ART-23 rig and stage clips | ART-22 and a disposition of DQ-04 | Q-E03, Q-P25, Q-P26 |
| 5 | ART-24 import | NQ-02, ART-23, SC-02, SC-04, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P25, Q-P26 |

### Lane 4: Iron Orchard environment module set

| Step | Card | Waits on (cards) | Waits on (questions that block) |
| --- | --- | --- | --- |
| 1 | ART-25 landscape study and candidate modules | PD-01 | none |
| 2 | ART-26 blockout and paper clearance record | ART-25, ART-03 | Q-P22, Q-P23, Q-P26 |
| 3 | ART-27 model | ART-26 | Q-E03, Q-P26 |
| 4 | ART-28 import | NQ-02, ART-27, SC-05, SC-07, TH-29, TH-31 | Q-E01, Q-E03, Q-E04, Q-P23, Q-P26 |

### Lane 5: sound

| Step | Card | Waits on (cards) | Waits on (questions that block) |
| --- | --- | --- | --- |
| 1 | SND-01 Fuse directed weapon cues | PD-03, TH-17 | Q-P31, Q-P32 |
| 2 | SND-02 field and miscast cues; SND-03 ultimate cue | SND-01, TH-17 | Q-P13 for SND-02; Q-P17 and Q-P20 for SND-03; Q-P31 and Q-P32 for both |
| 3 | SND-04 enemy warning cues | ART-23, TH-17 | Q-P25, Q-P31, Q-P32 |
| 4 | SND-05 audio import | NQ-02, SND-01 to SND-04, SC-07, TH-17, TH-29, TH-31 | Q-E01, Q-E03, Q-P31 |

SND-05 waits on all four cue cards, so an unanswered Q-P13 or Q-P20 holds the whole audio import. If the coordinator wants the directed-weapon and warning cues imported first, SND-05 can be split while those answers are pending, as a recorded definition change.

### What can start without a new answer

Once admitted and authorized, NQ-01, ART-01, ART-20 and ART-25 have every dependency done and no blocking question. ART-02, ART-03 and ART-05 follow within the same lanes without a new answer. NQ-01 and NQ-02 also need a native execution authorization recorded in TRACKING. Every other card waits on at least one question below.

## Gating question register

Each registered question appears once. `Blocks` lists the cards whose Blocking questions field names it. `Shapes` lists the cards that register it as non-blocking and must hold under every answer. The partial answers quoted are TRACKING's at the base; none is extended here.

| Question | What it owns for this batch | Blocks | Shapes |
| --- | --- | --- | --- |
| [Q-E01](#q-e01) | The approved native slice and explicit go that native import, procedural motion and effect authoring need | ART-14, ART-15, ART-16, ART-17, ART-18, ART-19, ART-24, ART-28, SND-05 | none |
| [Q-E03](#q-e03) | Target hardware and the measured asset budgets that bound meshes, textures, rigs, effects and audio | ART-06, ART-07, ART-08, ART-09, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-27, ART-28, SND-05 | ART-14, ART-15, NQ-01, NQ-02 |
| [Q-E04](#q-e04) | Renderer, backend and texture formats for import settings and effects | ART-14, ART-15, ART-16, ART-17, ART-18, ART-19, ART-24, ART-28 | ART-06, ART-27 |
| [Q-E06](#q-e06) | Licensing and notices; admission records evidence without distribution approval | none | ART-17, ART-18, ART-19, ART-24, ART-28, SND-01, SND-02, SND-03, SND-04, SND-05 |
| [Q-E10](#q-e10) | Overlapping attack admission and pressure limits the enemy sheets and poses depict | none | ART-20, ART-21 |
| [Q-E13](#q-e13) | Proof scripts and diagnostics in exports | none | ART-17, ART-18, ART-24, ART-28, NQ-01, NQ-02 |
| [Q-P06](#q-p06) | Fuse's species and whether the cast stays animal-only; Fuse as first kit is recorded (EV-0372) | ART-07, ART-10, ART-18 | ART-01, ART-02, SND-01 |
| [Q-P07](#q-p07) | Which regions enter production beyond the Iron Orchard content EV-0372 names | none | ART-25 |
| [Q-P10](#q-p10) | Visible mass change at the authored growth state | none | ART-01, ART-03, ART-06 |
| [Q-P11](#q-p11) | Node content that could change tool actions | none | ART-13 |
| [Q-P13](#q-p13) | Element pool, and so the head set, plus miscast eligibility, frequency, severity and warnings; the shape rule is recorded (EV-0322) | ART-08, ART-11, ART-13, ART-15, ART-16, ART-18, ART-19, SND-02 | ART-02, ART-03, ART-12 |
| [Q-P17](#q-p17) | Music states that an ultimate cue may interact with | SND-03 | none |
| [Q-P20](#q-p20) | What the ultimate is and how it is earned, for its tool action and cue | ART-13, SND-03 | ART-02, ART-08 |
| [Q-P21](#q-p21) | Movement and defensive rhythm behind suspension and retraction ranges | none | ART-05, ART-09, ART-14 |
| [Q-P22](#q-p22) | The ordinary growth envelope and minimum route clearance | ART-06, ART-14, ART-26 | ART-01, ART-02, ART-03, ART-04, ART-05, ART-08, ART-09, ART-25 |
| [Q-P23](#q-p23) | How modules assemble into levels | ART-26, ART-28 | ART-25 |
| [Q-P24](#q-p24) | Terrain consequence mechanics a module might carry | none | ART-25, ART-26 |
| [Q-P25](#q-p25) | Which named enemy family and attack grammar enter production | ART-21, ART-22, ART-23, ART-24, SND-04 | ART-20 |
| [Q-P26](#q-p26) | The bounded asset manifest, including module membership, and the measured budget; batch scope is recorded (EV-0372) | ART-06, ART-07, ART-08, ART-09, ART-10, ART-11, ART-17, ART-18, ART-19, ART-22, ART-23, ART-24, ART-26, ART-27, ART-28 | ART-03, ART-25 |
| [Q-P27](#q-p27) | The motion treatment's specifics, including expression and tool action lists; the hybrid split is recorded (EV-0372) | ART-06, ART-09, ART-10, ART-11, ART-12, ART-13, ART-14 | ART-01, ART-02, ART-03, ART-04, ART-05, ART-07 |
| [Q-P28](#q-p28) | Barks and voice, excluded from expression clips and cues | none | ART-12, SND-01 |
| [Q-P30](#q-p30) | Which cues and tells are required feedback | ART-16 | ART-15, SND-04 |
| [Q-P31](#q-p31) | The first sound batch, source method, durations and audition setup | SND-01, SND-02, SND-03, SND-04, SND-05 | none |
| [Q-P32](#q-p32) | Camera distance and response for the silhouette checks, and cue tails and priority | ART-04, ART-21, SND-01, SND-02, SND-03, SND-04 | ART-02, ART-05, ART-14, ART-15 |
| [Q-P33](#q-p33) | Regional lighting, weather and wayfinding the sheets and textures assume | none | ART-01, ART-20, ART-25, ART-26, ART-27 |

Q-P04 is resolved (EV-0372) and is cited as an input, not a gate. Q-E01 is cited only by native cards. Concept, blockout, model and rig cards are not native implementation, and their production authorization is a scope decision the coordinator records at admission.

## Drafting questions for the coordinator

These are not register entries. Each needs a disposition before the cards that cite it are admitted.

| ID | Question | Evidence | Cards affected |
| --- | --- | --- | --- |
| DQ-01 | HF-01 owns no path family for production concept sheets, paintovers, review captures or a motion brief. The drafts propose `docs/art/production/<unit>/**`, and HF-01 line 19 requires an ownership amendment before a card claims an unlisted path. | HF-01 lines 19 and 23 to 37; TH-19 OC-07 classes `docs/art/**` as concept images, a path no HF-01 row lists | ART-01, ART-02, ART-04, ART-05, ART-20, ART-21, ART-25 |
| DQ-02 | HF-01's assets row permits materials but names no shader source file. The effect cards may need a particles shader on a process material (`g4-particles.txt` line 26). | HF-01 line 30 | ART-15, ART-16, ART-19 |
| DQ-03 | Blender, Krita and Audacity have no pinned versions, and the Blender receipts come from the unversioned manual (source URLs under `manual/en/latest`). A pin, with a retrieval of the matching manual, should precede ART-06 and ART-09. | `docs/DISCOVERY.md` line 211; receipts `b1-armatures.txt` to `b4-gltf-export.txt` | ART-03, ART-06 to ART-13, ART-22, ART-23, ART-27, SND-01 to SND-04 |
| DQ-04 | No registered question owns the enemy family's motion treatment. Q-P27 names the selected mech only, and ART-23 proposes hand-keyed stage clips without selecting that. | BACKLOG Q-P27 missing information; TRACKING EV-0372 | ART-23, ART-24, SND-04 |
| DQ-05 | No card or path family is named for module collision geometry. TH-15 owns the fixture contract, and ART-26 records only a paper clearance check. | TH-15 PX-09 and PX-10; HF-01 lines 23 to 37 | ART-26, ART-28 |
| DQ-06 | Camera-distance circularity. Q-P32's bounds stay open until a native slice plays (TRACKING Q-P32 row), while EV-0372 requires the camera-distance check before model lock. Unless Andrew records a check distance, ART-04 and ART-21 stay blocked and so do all downstream models. | TRACKING question index Q-P32; EV-0372 carried risks | ART-04, ART-21 and their descendants |
| DQ-07 | Budget circularity. EV-0372 keeps the measured budget open until a native slice measures it, while TH-19 IG-05 requires the batch and its measured budget recorded before production import. | TRACKING EV-0372; TH-19 IG-05 | Every model, rig and import card |
| DQ-08 | NQ sequencing. TH-19 RR-09 puts the fixtures in the repair's failing run and integrates only the passing candidate, so NQ-01's commit is held unintegrated as NQ-02's base. The coordinator confirms the arrangement. The TH-19 IQ-05 fallback card is not drafted. | TH-19 line 212 and IQ-05 | NQ-01, NQ-02 |
| DQ-09 | Concept method authorization. PD-01 authorizes no image generation, and DISCOVERY names built-in generation as available but not open-source. Andrew's authorization of a method is needed for any generated concept. | PD-01 line 5; `docs/DISCOVERY.md` line 213 | ART-01, ART-02, ART-20, ART-25 |
| DQ-10 | Schema dependencies differ from the packet's list. SC-06 gates nothing here because the batch excludes the discharge post device (BIBLE line 413), and SC-05 is added because module definitions are its scope. | BACKLOG SC-05 and SC-06 definitions of done | ART-28 |
| DQ-11 | The Context7 receipts cited by the cards live under ignored `artifacts/local/tasks/DRAFT-ASSETS/ctx7/`. The task contract copies cited receipts to a tracked record at handoff, and the coordinator names the destination for this sprint. | BACKLOG.md line 26 | Every card citing a receipt |
| DQ-12 | Evidence cards not drafted: the executed PD-01 PE-01 and PE-04 trials, which need the handoff's commands and TH-15 PX-09 and PX-10, and the PD-03 AU-01 to AU-06 and FT-01 and FT-02 sessions, which need a playable native build. | PD-01 PE-01 and PE-04; PD-03 AU-01 to AU-06 | ART-14, ART-26, SND-01 to SND-05 |
| DQ-13 | Unit names. `rolling_core` and `fuse` are proposed path groupings, and `<enemy_unit>` and `<orchard_modules_unit>` stay placeholders until Q-P25 and Q-P26 supply content. A unit is never a durable ID. | HF-01 line 21 | Every card with a `native/content` or `source-assets` path |

## Context7 receipts

Saved under `artifacts/local/tasks/DRAFT-ASSETS/ctx7/`. Each file records the command, the UTC retrieval time and the exit status. All nine exited 0. Eight were retrieved at 2026-09-16T19:36:37Z and one at 19:36:55Z. At most two queries were used per question.

| Receipt | Library | Query topic | Facts cited |
| --- | --- | --- | --- |
| `b1-armatures.txt` | `/websites/blender_manual_en` | armature deform parenting | lines 8, 16 and 24 |
| `b2-weight-paint.txt` | `/websites/blender_manual_en` | weight painting and vertex groups | lines 20 and 28 |
| `b3-actions-nla.txt` | `/websites/blender_manual_en` | actions and NLA | lines 8, 32 and 40 |
| `b4-gltf-export.txt` | `/websites/blender_manual_en` | glTF export of skinned meshes | lines 4, 8, 16, 24 and 40 |
| `g1-gltf-import.txt` | `/websites/godotengine_en_4_7` | scene import scripts | lines 8 and 111 |
| `g1b-gltf-skinned-import.txt` | `/websites/godotengine_en_4_7` | glTF skins, skeletons and animations on import | lines 14, 22 to 36, 53 and 83 to 94 |
| `g2-skeleton.txt` | `/websites/godotengine_en_4_7` | procedural bone poses | lines 8, 50, 58 and 66 |
| `g3-animtree.txt` | `/websites/godotengine_en_4_7` | AnimationTree and AnimationPlayer | lines 75 and 83 |
| `g4-particles.txt` | `/websites/godotengine_en_4_7` | GPU particles and process materials | lines 26, 81 and 91 |

Retrieval limits: no receipt states Godot's import options for a skinned glTF scene beyond the import-state classes, how imported clip names map from Blender action or track names, Audacity or Krita behaviour, or any IK node. The cards therefore assert none of those, and ART-18's clip-name check is an observation to make, not a documented guarantee.

## Evidence limits

This is a paper plan. The executable check (`artifacts/local/tasks/DRAFT-ASSETS/check_drafts.py`) establishes card structure, that cited section rows, questions and dependency cards exist, register consistency and the absence of unsourced numbers. It does not establish that a citation supports the sentence around it, that the ordering is optimal, or that any card is sized correctly in practice. No asset, image, sound, engine or Blender run took place.
