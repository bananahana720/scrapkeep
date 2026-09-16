# Draft cards: first production asset batch and TH-19 native qualification

Staging draft DRAFT-ASSETS attempt A2, lease DRAFT-ASSETS-L2, revised at base `0ea92ce738d8ea0eb33de57eb34d5a6ce101bce4` after review R1 (`artifacts/handoff-8-2026-09-16/drafts/review-R1.md`) and Andrew's production decisions at TRACKING EV-0423. This file is not a BACKLOG definition. It authorizes no production, native execution, image generation, sound generation, tool installation or asset work; the coordinator admits cards only through a recorded definition change, and Andrew authorizes each sprint that runs them. Every open question below is cited and none is answered.

## How to read these drafts

- **IDs.** Proposed families are `NQ` (native qualification), `ART` (art production) and `SND` (sound production); `AP-` and `AA-` rows already exist in TH-04, TH-10 and TRACKING. Attempt A2 retires NQ-02 by merging it into NQ-01, splits ART-23 into ART-23 (rig) and ART-29 (stage clips), and adds NQ-03 (the fully grown clearance evidence card). One question register entry, Q-P42, is proposed at the end of this file with Andrew's approach-level answer (TRACKING EV-0447 decision 3). The coordinator decides final IDs.
- **Links.** Dependency and question links use BACKLOG anchors so a card can be pasted into BACKLOG unchanged; the proposed Q-P42 anchor resolves inside this file until imported. Paths are repository-relative and backticked.
- **Batch.** TRACKING EV-0372 recorded the scope: the shared rolling core and enclosed cockpit, Fuse and its mounted tool at one growth state, one Iron Orchard enemy family and one Iron Orchard environment module set, hybrid motion, and Fuse's construction C with carried risks in `artifacts/handoff-8-2026-09-16/decisions/Q-P04-fuse-construction.json`.
- **Andrew's decisions at TRACKING EV-0423, recorded as production direction and not as card authorization.** Decision 1: art and sound production starts with concept sheets and rough blockouts after the current sprint, while final models, rigs, animation and sounds wait for the playable native build (Q-E01). Decision 2: the batch's one growth state is the starting mech, and the fully grown clearance check is a separate evidence card (NQ-03). Decision 3: concept art is made by image prompts plus paintover, with provenance recorded per PD-01's PF rows. Decision 4: the orchard browser proof's camera distance is the provisional silhouette distance for Fuse's model-lock check, rechecked in the native slice; it is not an answer to Q-P32's bounds.
- **Andrew's decisions at TRACKING EV-0447, recorded the same way.** Decision 1: the batch asset list and its file locations are recorded before the budget, so rough blockouts may be proposed for the next sprint, while the measured budget stays open until the native slice measures it and final models still wait for it. Decision 2: the orchard browser proof's camera distance is also the provisional silhouette distance for the Iron Orchard enemies, rechecked in the native slice; it is not an answer to Q-P32's bounds. Decision 3: enemy-family motion is hybrid, with procedural locomotion and turning in Godot and hand-keyed Blender wind-up and attack clips; the specifics stay open under Q-P42.
- **Two stages.** A card whose Lane says `concept stage` is proposed for the sprint after the current one under decision 1 and runs only inside a sprint Andrew authorizes. A card whose Lane says `native stage` names the gate `Q-E01 native slice and Andrew's production authorization` in its Blocking questions field and cannot be ready before both exist.
- **Evidence classes.** A static check, a staged fixture, an automated native trial, a human session and a hardware or performance measurement are different evidence (PD-01 line 76; TH-16 RQ-08). A review by Andrew is recorded separately as a human review record under PD-01 PF-12 and is not one of those five classes. Every Verification field names its evidence separately, states what is not established, and ends with the steps that need a human's hands.
- **Tools.** Blender, Krita and Audacity are not installed on this machine at the base. Installing a tool is Andrew's hands-on step, never a card outcome. The version installed at first use is pinned in the PD-01 PF-06 recipe row of each record that uses it (drafting question DQ-03). Blender, Krita, Audacity or Godot execution by an agent needs Andrew's execution authorization recorded in TRACKING before assignment.
- **Tool facts.** Blender and Godot behaviour is cited only from Context7 receipts, written as receipt name and line. The receipts are tracked at `artifacts/handoff-8-2026-09-16/drafts/ctx7/`, copied in attempt A3 from the writer's ignored `artifacts/local/tasks/DRAFT-ASSETS/ctx7/` (DQ-11), and every card cites them by that path. The Blender receipts come from the unversioned manual. Anything not retrieved is stated as a limit.
- **Paths.** Proposed paths follow the HF-01 families; `docs/art/production/**` and the Audio-owned path rows for `source-assets/*/audio/**` and `native/content/*/assets/audio/**` need the HF-01 amendment proposed in DQ-01. `rolling_core`, `fuse`, `iron_orchard_enemies` and `iron_orchard_modules` are the path groupings for the batch's file locations recorded at TRACKING EV-0447 decision 1, never durable IDs (HF-01 line 21; DQ-13). Paths inside a grouping are split per card so that cards able to run at the same time lease disjoint files.
- **Values.** No card states a count, budget, polycount, bone count, texture size, loudness, duration, distance or frame rate. Each such value is a parameter tied to its question or source line.

## Native qualification

TH-19 requires the runner repair and the synthetic import proof before any production source asset is admitted (TH-19 IG-01 to IG-04; HF-01 line 61). TH-19 RR-09 at line 212 puts the proof fixtures into the repair's first, failing run and integrates only the passing candidate, and ORCHESTRATOR lines 42 and 104 admit a card only when every prerequisite is done. One card therefore carries both.

<a id="nq-01"></a>

### NQ-01: Author the synthetic import proof, repair the sidecar exclusions and execute the proof

**Card revision:** 1 · **Owner:** Tooling with Verification · **Size:** M · **Lane:** native qualification

**Source and inputs:**

- `docs/tech/sections/TH-19-asset-import-export.md` § The synthetic import proof, line 220; TH-19 IQ-01 to IQ-07, PV-06, OC-08, GO-03, GO-04, IS-01, IS-02, IS-04, HR-01 to HR-04, RR-01 to RR-11, IG-01 to IG-07 and AQ-05, AQ-06, AQ-15, AQ-16, AQ-19 and AQ-20; the quoted base lines at TH-19 lines 183 to 187
- TH-19 RR-09 at line 212 (fixtures in the failing run, only the passing candidate integrated) and TH-19 line 216 (running the runner needs its own authorization)
- `ORCHESTRATOR.md` lines 42 and 104: a prerequisite is done only when integrated, which is why fixtures and repair are one card
- `.gitignore` line 20 and `scripts/native-smoke.mjs` lines 147, 148, 688, 742, 751 and 753 as TH-19 quotes them; re-inspect at assignment, and a moved anchor returns the card to the coordinator
- `docs/tech/sections/HF-01-production-conventions.md` lines 34, 47, 50, 61, 66 and 68; `native/README.md` lines 42 and 86 and `native/tests/fixtures/untyped_negative.gd`, as TH-19 line 220 cites them
- The Godot import-process receipt TH-19 line 13 retained under `artifacts/local/tasks/TH-19/`, and Context7 library `/websites/godotengine_en_4_7` for TH-19 AQ-05 and AQ-06, at most three queries per question with saved receipts

**Dependencies:** [TH-19](#th-19). **Blocking questions:** None. Gate: a native execution authorization for the pinned editor and the runner, recorded in TRACKING by Andrew before assignment (TH-19 line 216). **Registered non-blocking questions:** [Q-E03](#q-e03) for hosts beyond the runner's (TH-19 AQ-16), [Q-E13](#q-e13) for proof scripts in exports (TH-19 AQ-15).

**Files touched:** `native/proofs/tadr-003-import/**` (typed `proof_runner.gd` and its UID sidecar, the authored, variant and negative inputs, and the committed `.import` sidecars of the authored and variant inputs); `.gitignore`, deletion of line 20 only (TH-19 RR-01, under the coordinator's shared-file lease); `scripts/native-smoke.mjs`, TH-19 RR-02 to RR-06 only; `artifacts/local/tasks/NQ-01/` for the fixture receipt, the failing proof-mode receipt, the passing proof-mode receipt, the export-mode receipt and the clean-checkout receipt.

**Definition of done:**

1. The proof directory holds the three synthetic importable inputs TH-19 line 220 names: an authored input whose committed sidecar sets one parameter away from its default, a variant with byte-identical content whose committed sidecar differs only in that parameter, and a negative input committed without a sidecar. Each records itself as synthetic (TH-19 PV-06). The fixture file type (TH-19 AQ-06), the parameter, its value and the observation method (TH-19 AQ-05) are selected from retrieved Godot documentation with receipt lines; with no supporting text the card returns blocked.
2. The sidecars are produced by the pinned editor's import, which TH-19 IS-01 documents as writing a sidecar beside its input; an edit outside the Import dock is followed by a reimport (TH-19 IS-04). No sidecar for the negative input and no `native/.godot/` path remains staged or on disk in the proof directory (TH-19 GO-04; TH-19 RR-08).
3. `proof_runner.gd` extends `SceneTree`, loads the authored and variant inputs through the Resource Loader (TH-19 GO-03), prints `PASS` only when the authored input shows the non-default effect and the two observations differ (TH-19 IQ-02, IQ-04), and under `-- --inject-fault` applies the TH-19 IQ-02 assertion to the negative input and fails with the output and exit status TH-19 IQ-06 names.
4. TH-19 RR-09's failing run is recorded on this card's own branch. With the fixtures and TH-19 RR-01, RR-04 and RR-05 applied, and before TH-19 RR-02, RR-03 and RR-06 are applied, `npm run native:smoke` fails at the TH-19 IQ-02 observation; a failure for any other reason is not the reproduced failure and returns the card. With TH-19 RR-02, RR-03 and RR-06 then applied, the same command passes and reports `staged-import`, `staged-reimport` and each `proof-<name>-rebuilt` check (TH-19 IQ-02, IQ-03, IQ-04, IQ-06). Only the passing candidate is offered for integration.
5. The ignore diff is exactly TH-19 RR-01 and the runner diff exactly TH-19 RR-02 to RR-06 (TH-19 RR-07). `git check-ignore` exits 1 for a sidecar path under `native/content/*/assets/` and under `native/proofs/`, and exits 0 for a path under `native/.godot/imported/`, as TH-19 RR-01's acceptance column states.
6. `node scripts/native-smoke.mjs --export` passes and reports `proof-tadr-003-import-exported` (TH-19 RR-06, IQ-05). If the exported binary does not run the script (TH-19 AQ-19), TH-19 RR-06 fails the export run, so the card cannot complete: it returns blocked with TH-19 IG-04 recorded absent, its receipts preserved, and a request that the coordinator define the TH-19 IQ-05 fallback as a separate Verification card. Nothing is integrated in that case.
7. TH-19 IQ-01's clean-checkout procedure, which TH-19 assigns to the proof card, runs at the candidate commit. Every receipt carries TH-19 IQ-07's identity fields, including a false `sourceDirty` (TH-19 RR-08).
8. The handoff lists TH-19 IG-01 to IG-04 each as closed with the receipt that shows it; TH-19 IG-05 to IG-07 stay open and are not claimed.

**Verification and evidence:** Automated native trial for items 4 and 6, on the runner's Linux host (TH-19 AQ-16), with source commit, engine pin and binary hash in each receipt. Static git inspection for items 1, 2, 5 and 7, and `npm run check:scope -- <base> <candidate>` for the required check set. The failing receipt is the reproduced failure and the passing receipts are the fix, on one branch. Not established: Windows execution, any production importer or asset, renderer, budget or human review (TH-19 line 232), or what `--editor --import` does beyond the runner's observed result (TH-19 AQ-20). Human-hands steps: Andrew records the native execution authorization; no other hands-on step.

**Boundary:** No change to export presets, `package.json`, `npm run verify`, the networking grep, the boots or the existing `editor-import` step (TH-19 RR-07). TH-19 RR-10 and RR-11 stay rejected. No production asset is admitted, and no candidate that has not passed items 4 and 6 is integrated.

## Fuse and shared chassis: concept to import

Ordered so the concept-to-import path for the shared core and Fuse reads first.

<a id="art-01"></a>

### ART-01: Make concept and paintover sheets for the shared rolling core and enclosed cockpit

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 (the rolling core and cockpit all five candidates share); TRACKING EV-0423 decisions 1, 2 and 3
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-02, AC-05, AC-06, AC-07, AC-08, AC-09, AC-13, AC-14, AC-17, AC-18, AC-20 and AC-22; PD-01 VW-01, VW-02, VW-04, VW-05 and VW-10; PD-01 PF-01 to PF-15; PD-01 RL-02 to RL-05; PD-01 lines 5 and 63
- BIBLE.md § 5.2 lines 420 and 422; § 7 lines 620, 682, 719, 725, 727 and 739; § 6 line 487
- `docs/DISCOVERY.md` lines 213 and 215: the proposed workflow starts from concept and paintover, and raster art is not a production mesh, rig or clip
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-06, RQ-07 and RM-06; `docs/tech/sections/TH-19-asset-import-export.md` TH-19 CI-01 to CI-04
- Existing concept records, as references only: PD-01 CC-01 and CC-03

**Dependencies:** [PD-01](#pd-01). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P06](#q-p06), [Q-P10](#q-p10), [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P33](#q-p33). The sheets must hold under every candidate answer and caption each unselected value as unset.

**Files touched:** `docs/art/production/rolling_core/**` (sheets, prompt records, paintovers, captions and each sheet's provenance record; path under the DQ-01 amendment); `artifacts/local/tasks/ART-01/`.

**Definition of done:**

1. A view set for the shared core and cockpit: a PD-01 VW-04 turnaround that answers where the cockpit is, what moves, how scrap enters and which feature identifies the role; a PD-01 VW-05 cutaway of intake, sorting paths and fabrication chamber with its enlargement stated; a PD-01 VW-01 gameplay view; and a PD-01 VW-10 motion sequence captioned approximate. The PD-01 VW-02 beauty view is a separate member.
2. Each sheet is made by image prompts plus paintover (TRACKING EV-0423 decision 3). Its provenance record carries the prompt text and generator under PD-01 PF-03 and PF-04, the paintover and its tool under PD-01 PF-06, and any reference image it paints over; a reference stays a concept record (TH-19 CI-04). The image generator and its output terms are recorded as PD-01 PF-05 license evidence before the generator is first used (HF-01 line 72; ASSETS.md line 17).
3. No sheet carries a class tool. The cockpit encloses a neutral pilot silhouette captioned as a placeholder, not a species selection (PD-01 AC-20; Q-P06).
4. Growth is shown at the starting mech (TRACKING EV-0423 decision 2), with no mass value (Q-P10); the ordinary maximum envelope stays unset (TH-02 MP-16; Q-P22) and is not depicted as settled.
5. Each sheet carries PD-01 PF-01 to PF-13 and PF-15 and a caption stating image ID, proposal status and what it does not establish. No caption or record claims that a generated image proves articulation, mounting dimension, growth extent or route clearance (PD-01 line 63; PD-01 AC-22, PE-01, PE-02 and PE-04).
6. The review record under PD-01 PF-12 lists the acceptance check IDs applied and Andrew's verdict.

**Verification and evidence:** Static: a paper check lists, per sheet, the view ID, caption, prompt record and provenance field IDs, and fails on a missing member. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-01, AC-02, AC-05 to AC-09, AC-13, AC-14, AC-17, AC-18, AC-20 and AC-22. Not established: rolling articulation, dimensions, clearance or motion (PD-01 RL-02). No automated or native evidence applies. Human-hands steps: Andrew's review and verdict; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept work only. Sheets remain concept references and never runtime inputs (TH-19 CI-01). No model lock, budget, species or motion selection.

<a id="art-02"></a>

### ART-02: Make concept and paintover sheets for Fuse's construction C and mounted emitter

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372: Q-P04 resolved to construction C, the cable hoop with separate discharge heads, and its carried risks; `artifacts/handoff-8-2026-09-16/decisions/Q-P04-fuse-construction.json`; TRACKING EV-0423 decisions 1 to 3
- BIBLE.md § 4.4 lines 342, 346, 348 and 354 to 359; § 5.1 lines 413 and 416; § 5.2 line 428; § 7 lines 682, 721, 731 and 739
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-06, AC-10, AC-13, AC-14, AC-16, AC-20 and AC-22; PD-01 VW-01, VW-04, VW-07 and VW-11; PD-01 PF-01 to PF-15; PD-01 line 63
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-05, RR-10, RR-12 and RM-06; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-06, TP-21 and TP-22
- TRACKING EV-0322: a miscast never changes the previewed danger shape (Q-P13 partial)
- ART-01's sheets

**Dependencies:** [ART-01](#art-01), [PD-01](#pd-01). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P06](#q-p06), [Q-P13](#q-p13), [Q-P20](#q-p20), [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32).

**Files touched:** `docs/art/production/fuse/**` (sheets, prompt records, paintovers, captions and provenance records; DQ-01); `artifacts/local/tasks/ART-02/`.

**Definition of done:**

1. Construction C on ART-01's core at the starting mech: an open cable frame with separate discharge heads legible above it and the aiming nozzle landmark kept (BIBLE lines 359, 416). It is shown in a PD-01 VW-04 turnaround, a PD-01 VW-01 gameplay view and a PD-01 VW-11 combat-readability diagram of tool, danger footprint and escape, captioned as intended geometry (TH-16 RR-12).
2. Each discharge head is drawn as a working mechanism whose construction differs where behaviour differs, never as a colour swap (EV-0372 carried risk; PD-01 AC-10; BIBLE lines 428, 682). A PD-01 VW-07 lineup of candidate heads carries a common size reference, is captioned as a relative comparison, and captions the head set as candidates under Q-P13 (PD-01 AC-20).
3. A miscast-tell panel shows instability localized to one head while the nozzle's aim line and danger shape stay unchanged (EV-0322; TH-16 RR-10). It is captioned as a candidate with warning timing unset (TH-03 TP-22), and localization is labelled unproven while Q-P13 is open (EV-0372).
4. A pilot panel shows Fuse seated in the enclosed cockpit, with expressiveness from the whole seated body and ears and tail inside (BIBLE line 346), captioned as a candidate species under Q-P06.
5. Method, provenance and captions as ART-01 items 2 and 5, and a PD-01 PF-12 review record.

**Verification and evidence:** Static: the ART-01 paper check applied to this set. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-01, AC-06, AC-10, AC-13, AC-14, AC-16, AC-20 and AC-22. Not established: occlusion or sightline at camera distance, which is ART-04's; miscast localization; mounting dimension (PD-01 PE-02); articulation. Human-hands steps: Andrew's review and verdict; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept only. No element pool, head count, failure rate, instability meter or self-damage amount is selected (BIBLE line 359; Q-P13). The discharge post device (BIBLE line 413) is outside this batch.

<a id="art-03"></a>

### ART-03: Make rough blockouts of the shared core, cockpit and Fuse's construction C

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- ART-01 and ART-02 sheets and review records; TRACKING EV-0423 decisions 1 and 2
- BIBLE.md § 7 line 719 (leave useful gaps around moving assemblies); § 5.1 line 416 (landmarks that mounts grow around)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-06, PF-08, PF-09, PE-02 and PE-03
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 and PV-02; `docs/tech/sections/HF-01-production-conventions.md` lines 31 and 72
- TRACKING EV-0447 decision 1: the batch asset list and file locations are recorded before the budget, so rough blockouts may be proposed for the next sprint; Q-P26's measured budget stays open
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-16 and MP-17; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11 and CO-14
- `docs/DISCOVERY.md` line 215 (model and pivot authoring in Blender)

**Dependencies:** [ART-01](#art-01), [ART-02](#art-02). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P10](#q-p10), [Q-P13](#q-p13), [Q-P22](#q-p22), [Q-P26](#q-p26) (the measured budget only), [Q-P27](#q-p27).

**Files touched:** `source-assets/rolling_core/blockout/**` and `source-assets/fuse/blockout/**` (editable Blender masters; HF-01 line 31); `source-assets/rolling_core/provenance/blockout/**` and `source-assets/fuse/provenance/blockout/**`; `artifacts/local/tasks/ART-03/` (renders).

**Definition of done:**

1. Low-detail blockouts at the starting mech (TRACKING EV-0423 decision 2) of the core mass, cockpit enclosure, suspension and retracting mounts, and construction C's cable hoop, head mounts and emitter nozzle, as separately named objects so moving and stable parts can be told apart (BIBLE line 719; PD-01 AC-10).
2. Units, axes and the scale reference are recorded under PD-01 PF-08. Every dimension is labelled a provisional blockout value, is not a mounting record (PD-01 PE-02), and says nothing about the ordinary maximum envelope (TH-02 MP-16, MP-17).
3. A list of parts proposed as moving or stable is recorded as input to ART-05, not as a motion selection (Q-P27).
4. Each TH-19 OC-01 record carries PD-01 PF-01 to PF-13 and PF-15, the Blender version pinned at first use in PD-01 PF-06, and links forward to the ART-01 and ART-02 sheets it realizes. Masters stay outside `native/` (TH-19 OC-01).

**Verification and evidence:** Static: a reviewer checks the provenance records and compares the recorded object list with turnaround renders from each master. Human review record (PD-01 PF-12): Andrew compares the renders with ART-01 and ART-02 for PD-01 AC-01, AC-02 and AC-10. Not established: any dimension, clearance, articulation or in-engine appearance. Human-hands steps: Andrew installs Blender and records Blender execution authorization before assignment; Andrew's review.

**Boundary:** Rough blockouts only. No final topology, UVs, textures, rig, runtime input or import. No blockout value becomes a mounted dimension, growth envelope or route clearance.

<a id="art-04"></a>

### ART-04: Check silhouette and pilot sightline at the provisional camera distance before model lock

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 carried risk and the `risks_to_watch` list in `artifacts/handoff-8-2026-09-16/decisions/Q-P04-fuse-construction.json`
- TRACKING EV-0423 decision 4: the orchard browser proof's camera distance is the provisional distance, rechecked in the native slice, and is not an answer to Q-P32's bounds
- `src/orchard/scene.js` lines 410 and 412: the orchard chase camera's distance expression and the camera position derived from it
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-06, AC-10, AC-13 and AC-16; PD-01 VW-01
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-04 and MP-23; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-06 and RR-05
- BIBLE.md lines 416, 483, 663 and 682
- ART-03's blockouts

**Dependencies:** [ART-03](#art-03). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32) (the native recheck belongs to ART-18).

**Files touched:** `docs/art/production/fuse/review/**` (captures, paintover proposals, the check record and its PD-01 PF-12 review record; DQ-01); `artifacts/local/tasks/ART-04/`.

**Definition of done:**

1. The check record states the provisional camera distance as the orchard expression at `src/orchard/scene.js` line 410 evaluated for the starting mech, with every input to that expression named, and labels it provisional under TRACKING EV-0423 decision 4; the card writes no distance value of its own.
2. Renders of ART-03's blockout in close third person (TH-02 MP-04) at that distance, from the aiming, rear-quarter and side views the record names.
3. For each view the record states whether the cockpit and pilot are findable (PD-01 AC-01), whether the hoop or heads obstruct the aiming nozzle landmark or its aim line (BIBLE line 416), and whether each head reads as a distinct mechanism at that distance (PD-01 AC-06, AC-10).
4. Each failing view gets a paintover proposal. The record ends with a lock or revise verdict recorded by Andrew; model lock, meaning the start of ART-06 to ART-08, requires the lock verdict.
5. The record names the native recheck at the native slice's camera as an open obligation carried by ART-18, not as satisfied.

**Verification and evidence:** Human review record (PD-01 PF-12): Andrew's verdict. Static: every required view exists at the recorded distance, and the distance traces to `src/orchard/scene.js` line 410. Not established: in-engine camera collision, the native camera, occlusion while rolling (Q-P27), human feel or hardware. Human-hands steps: Andrew's verdict; Andrew installs Blender if renders are made from the masters.

**Boundary:** The provisional distance is Andrew's decision and not an answer to Q-P32. No change to the blockout beyond paintover proposals.

<a id="art-05"></a>

### ART-05: Propose the motion brief for the rolling core, suspension, retraction and fabrication sequence

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372, Q-P27 partial answer (hybrid); BACKLOG Q-P27's missing information (rolling core, stable cockpit, retracting equipment and the intake-to-fabrication sequence) and closure evidence (moving and stable parts, required action phases and ordinary route clearance)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PE-01, PE-05, VW-10, RL-02 and RL-05
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RT-01 to RT-07, RQ-02, RQ-03, RQ-07 and RM-06; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11 and CO-14
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-03, MP-06, MP-16, MP-17 and MP-23; `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 22
- BIBLE.md lines 481, 487, 725, 727 and 719
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g2-skeleton.txt` lines 50, 58 and 66 (a skeleton modifier's per-update pose hook, influence blending by the parent skeleton, and a pose-override caution), cited as documented candidates only
- ART-03's moving-and-stable part list

**Dependencies:** [ART-03](#art-03). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P21](#q-p21), [Q-P22](#q-p22), [Q-P27](#q-p27), [Q-P32](#q-p32). This card produces input for Andrew's Q-P27 answer and does not answer it.

**Files touched:** `docs/art/production/rolling_core/motion-brief.md` (DQ-01); `artifacts/local/tasks/ART-05/`.

**Definition of done:**

1. Every part in ART-03's list is classified as procedurally moving, hand-keyed or stable, including the rolling core, cockpit, suspension, retracting mounts and the hoop head mounts, with the EV-0372 hybrid split kept.
2. Each procedurally moving part names the published value it derives from, the committed pose, extent and basis (TH-16 RM-06, RT-06). The brief states that no displayed motion advances a gameplay interval or feeds the query world (TH-16 RT-05, RT-07; HF-04a line 22).
3. Action phases for suspension and retraction are listed per movement action in TH-02 MP-03 (rolling, jumping, rebounds, impacts).
4. The intake-to-fabrication sequence is described in the phases PD-01 PE-05 names (attraction, intake, internal processing and construction of the changed part), with the retained attachment to the chassis identified, each phase classed as procedural or hand-keyed, and presented only from committed values (TH-05 CO-11, CO-14; TH-16 RQ-07; BIBLE lines 725, 727).
5. Rates, ranges, growth extent, route clearance and camera response are listed as parameters tied to Q-P21 (TH-02 MP-06), Q-P22 (TH-02 MP-16, MP-17) and Q-P32 (TH-02 MP-23), with no value.
6. Godot mechanisms appear only as candidates with receipt lines. A mechanism with no receipt is recorded as a limit.
7. The brief goes to the coordinator for Andrew. The card completes on reviewed delivery, not on Q-P27's answer.

**Verification and evidence:** Static paper check: every listed part and every PD-01 PE-05 phase is classified, every parameter row has a question ID and no value, and every engine statement cites a receipt line; one independent review. Not established: the executed trials PD-01 PE-01 and PE-05 require, feel or clearance. Human-hands steps: Andrew reads the brief and answers Q-P27.

**Boundary:** No motion selected, no script, no rig and no value. Q-P27 stays open until Andrew records an answer in TRACKING.

<a id="art-06"></a>

### ART-06: Model, UV and texture the shared rolling core and cockpit

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-03's blockout, ART-04's lock verdict, and ART-05's brief with Andrew's recorded Q-P27 answer; TRACKING EV-0423 decisions 1 and 2
- `docs/tech/sections/TH-04-abilities-ultimates-and-combat-rhythm.md` TH-04 AS-01 to AS-04, AA-02 and AA-03; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-02, AC-05, AC-06, AC-07 and AC-09; PD-01 PF-01 to PF-15; PD-01 PE-02 and PE-03; PD-01 VW-01, VW-02 and VW-04
- BIBLE.md § 5.2 line 422; § 7 lines 645, 699 and 701
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03; `docs/tech/sections/HF-01-production-conventions.md` lines 31, 68 and 72
- `docs/DISCOVERY.md` line 211 (Blender and Krita as free local candidates)
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` lines 16 and 24 (the exporter supports meshes and textures; quads and n-gons are triangulated on export)

**Dependencies:** [ART-03](#art-03), [ART-04](#art-04), [ART-05](#art-05). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P10](#q-p10), [Q-P22](#q-p22).

**Files touched:** `source-assets/rolling_core/model/**` (Blender master), `source-assets/rolling_core/textures/**` (texture masters) and `source-assets/rolling_core/provenance/model/**` (provenance and notice records); `artifacts/local/tasks/ART-06/`.

**Definition of done:**

1. Final topology is separated into the moving and stable parts the approved brief names, with pivots at the brief's joints.
2. UVs and texture masters place wear by material and use (PD-01 AC-05) and keep materials distinct at gameplay distance (PD-01 AC-06). Mesh and texture limits come from the Q-P26 and Q-E03 answers, recorded as review parameters; the card states no limit of its own.
3. The model is at the starting mech (TRACKING EV-0423 decision 2). Its PD-01 PE-03 record names the capability-set selection it derives from: the run-start set, with weapon and special mobility available and the main hero skill and ultimate locked (TH-04 AS-01 to AS-04; TH-04 AA-02), holding only the slot selections the run's initial state holds (TH-04 AA-03), and reaching the encounter only as an installed value (TH-05 CO-11). No grown state is modelled.
4. The TH-19 OC-01 record carries PD-01 PF-01 to PF-13 and PF-15, tool versions pinned in PD-01 PF-06, license evidence and notice obligation for every texture source (TH-19 NO-02, NO-03), and the recipe to the future runtime input (TH-19 PV-03).
5. No runtime input is written. Export to `native/content/` belongs to ART-17.

**Verification and evidence:** Static: provenance and license fields; budget conformance by the method the Q-P26 answer records. Human review record (PD-01 PF-12): Andrew reviews PD-01 VW-02, VW-04 and VW-01 renders for PD-01 AC-01, AC-02, AC-05, AC-06, AC-07 and AC-09. Not established: in-engine appearance, renderer (Q-E04), measured performance (Q-E03) or articulation (PD-01 PE-01). Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No rig, runtime input, import or admission. No budget value invented. No paid tool, download or LFS (HF-01 line 72).

<a id="art-07"></a>

### ART-07: Model, UV and texture Fuse the pilot

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-02's pilot panel, ART-03's cockpit enclosure and ART-04's lock verdict; TRACKING EV-0423 decision 1
- BIBLE.md § 4.4 lines 346 and 348; § 7 lines 620 and 701
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-01, AC-06, AC-18, AC-19 and AC-20; PD-01 PF-01 to PF-15; PD-01 RL-04
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03

**Dependencies:** [ART-02](#art-02), [ART-03](#art-03), [ART-04](#art-04). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P06](#q-p06) (species and animal-only cast), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P27](#q-p27).

**Files touched:** `source-assets/fuse/pilot/**`; `source-assets/fuse/provenance/pilot/**`; `artifacts/local/tasks/ART-07/`.

**Definition of done:**

1. A seated pilot model that fits ART-03's cockpit enclosure, with ears and tail inside the cockpit (BIBLE line 346) and a species that matches the Q-P06 answer.
2. Topology and joint placement support whole-seated-body expression (BIBLE line 346), with the expression list left to Q-P27.
3. UVs and texture masters simplify fine fur and glass detail before it obscures the pilot at gameplay distance (PD-01 AC-06, RL-04), within the Q-P26 and Q-E03 answers.
4. TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance and license fields; budget conformance by the Q-P26 method. Human review record (PD-01 PF-12): Andrew reviews turnaround and in-cockpit renders at the ART-04 distance for PD-01 AC-01, AC-18 and AC-19. Not established: expression range, in-engine appearance or human feel. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No rig, clip, runtime input or import. No species, roster or cast decision beyond the recorded Q-P06 answer.

<a id="art-08"></a>

### ART-08: Model, UV and texture Fuse's emitter, cable hoop and discharge heads

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-02's sheets, ART-03's blockout, ART-04's lock verdict and ART-06's chassis master; TRACKING EV-0423 decision 1
- BIBLE.md lines 354, 359, 413, 416 and 428; the EV-0372 carried risk that each head is a working mechanism, not a colour swap
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-07, AC-10 and AC-16; PD-01 PE-02; PD-01 PF-01 to PF-15
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RM-06; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-06, TP-06 and TP-21

**Dependencies:** [ART-02](#art-02), [ART-03](#art-03), [ART-04](#art-04), [ART-06](#art-06). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13) (which elements, and so which heads), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P20](#q-p20), [Q-P22](#q-p22).

**Files touched:** `source-assets/fuse/tool/**`; `source-assets/fuse/provenance/tool/**`; `artifacts/local/tasks/ART-08/`.

**Definition of done:**

1. An emitter with the aiming nozzle landmark and a visible working chamber (BIBLE lines 413, 416).
2. A cable hoop carrying one head per element in the Q-P13 answer, each head with its own working mechanism (PD-01 AC-10; BIBLE line 428).
3. A dimensioned mounting record against ART-06's chassis in the provenance record, with units and axes (PD-01 PE-02, PF-08). Dimensions live in the master, not in this card.
4. Texture and mesh limits from the Q-P26 and Q-E03 answers; TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance, mounting record and license fields. Human review record (PD-01 PF-12): Andrew reviews turnaround and gameplay-distance renders for PD-01 AC-07, AC-10 and AC-16. Not established: mounted fit in engine, head mechanism motion or miscast localization. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No element pool, head count or failure behaviour chosen by the card. No device. No rig, import or runtime input.

<a id="art-09"></a>

### ART-09: Rig the rolling core, suspension and retracting mounts for procedural drive

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-05's brief with Andrew's recorded Q-P27 answer; ART-06's master; TRACKING EV-0423 decision 1
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8, 16 and 24 (armature deform parenting with automatic, envelope or empty-group weights; a bone's Deform toggle excludes it), `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` lines 20 and 28 (painting bone vertex groups; deform groups), `artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` lines 4, 8 and 16 (the glTF exporter covers armatures and skinning), `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 22 to 36 and 83 to 94 (glTF skins and skeletons in Godot's import state)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-09 and PE-01; `docs/tech/sections/TH-19-asset-import-export.md` TH-19 PV-05

**Dependencies:** [ART-05](#art-05), [ART-06](#art-06). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P21](#q-p21), [Q-P22](#q-p22).

**Files touched:** `source-assets/rolling_core/model/**` (the armature in the master) and `source-assets/rolling_core/provenance/rig/**` (PD-01 PF-09 record); `artifacts/local/tasks/ART-09/` (test export and renders).

**Definition of done:**

1. Bones exist exactly for the parts the approved brief marks as procedurally driven, named for the Godot-side driver of ART-14, with deform and non-deform bones distinguished (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` line 24), including the mount bones the hoop attaches to.
2. Skin weights use the method recorded under PD-01 PF-09, whether automatic, envelope or painted (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` line 20), and are reviewed at every joint.
3. No hand-keyed action is authored on these bones (EV-0372 hybrid split).
4. PD-01 PF-09 records the bone list, rest pose, units and axes. The bone count stays within the Q-P26 and Q-E03 answers, and the card states none.
5. A test export in glTF 2.0 (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` line 4) with skinning goes to the receipts directory only, to show the rig exports. It is not a runtime input.

**Verification and evidence:** Static: PD-01 PF-09 record and bone naming against the brief. Human review record (PD-01 PF-12): Andrew reviews pose-range renders for deformation at joints and PD-01 AC-02. Not established: Godot import of the skeleton, procedural behaviour or PD-01 PE-01's trial. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No motion values, no clips, no runtime input and no import.

<a id="art-10"></a>

### ART-10: Rig Fuse the pilot for hand-keyed expressions

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, native stage

**Source and inputs:**

- ART-07's master; ART-05's brief and Andrew's recorded Q-P27 answer (expressions are hand-keyed Blender clips, EV-0372); TRACKING EV-0423 decision 1
- BIBLE.md line 346
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` lines 20 and 28; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 8 (NLA tracks hold action strips)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-09

**Dependencies:** [ART-05](#art-05), [ART-07](#art-07). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P06](#q-p06), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).

**Files touched:** `source-assets/fuse/pilot/**`; `source-assets/fuse/provenance/pilot/**`; `artifacts/local/tasks/ART-10/`.

**Definition of done:**

1. An armature whose controls cover the whole-seated-body expression range the Q-P27 answer lists (BIBLE line 346).
2. Weights use a method recorded under PD-01 PF-09 and are reviewed at every joint the answered expressions move.
3. PD-01 PF-09 records the bone list, rest pose, units and axes within the Q-P26 and Q-E03 answers. A test export goes to receipts only.

**Verification and evidence:** Static: PD-01 PF-09 record. Human review record (PD-01 PF-12): Andrew reviews pose renders for each answered expression's extreme. Not established: clip quality, in-engine playback or human feel. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No clips, runtime input or import.

<a id="art-11"></a>

### ART-11: Rig Fuse's emitter and cable hoop heads as working mechanisms

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, native stage

**Source and inputs:**

- ART-08's master and ART-09's mount bones; ART-05's brief and Andrew's recorded Q-P27 answer (tool actions are hand-keyed; retraction is procedural); TRACKING EV-0423 decision 1
- The EV-0372 carried risk: each head a visible working mechanism
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RC-02, RR-01 and RR-10; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 TP-06
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-10, PE-02 and PF-09
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 8

**Dependencies:** [ART-05](#art-05), [ART-08](#art-08), [ART-09](#art-09). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).

**Files touched:** `source-assets/fuse/tool/**`; `source-assets/fuse/provenance/tool/**`; `artifacts/local/tasks/ART-11/`.

**Definition of done:**

1. Each head's working mechanism has its own controls, so its action is visible and not a material change (PD-01 AC-10).
2. The nozzle's aim reference is a separate control that head actions never move, because committed geometry originates at the weapon and a miscast never moves it (TH-03 TP-06; TH-16 RR-01, RR-10). At runtime a view sets it only from published values Session supplies (TH-16 RC-02).
3. The hoop's attachment to ART-09's mount bones is recorded against PD-01 PE-02.
4. PD-01 PF-09 record within the Q-P26 and Q-E03 answers. A test export goes to receipts only.

**Verification and evidence:** Static: PD-01 PF-09 record and control list against the Q-P13 head set. Human review record (PD-01 PF-12): Andrew reviews renders of each head's mechanism at its extremes. Not established: in-engine playback, miscast localization or effect alignment. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No clips, effects, runtime input or import.

<a id="art-12"></a>

### ART-12: Hand-key Fuse's pilot expression clips

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-10's rig; Andrew's recorded Q-P27 answer listing expressions and phases; TRACKING EV-0423 decision 1
- BIBLE.md lines 346 and 350
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` lines 8, 32 and 40 (actions as NLA strips; Push Down moves the active action into a track; the glTF exporter's NLA Tracks mode exports each track as its own animation); `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 14 and 53 (glTF animations become animations in an AnimationPlayer node on import)
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RE-07 and RT-07; `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 22; `docs/tech/sections/HF-01-production-conventions.md` line 68

**Dependencies:** [ART-10](#art-10). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P13](#q-p13), [Q-P28](#q-p28).

**Files touched:** `source-assets/fuse/pilot/**` (actions in the master); `source-assets/fuse/provenance/pilot/**` (PD-01 PF-09 per clip); `artifacts/local/tasks/ART-12/` (captures and test export).

**Definition of done:**

1. One action per expression in the Q-P27 answer, each on its own NLA track so the exporter's NLA Tracks mode emits it as an independent animation (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40), with snake_case names (HF-01 line 68).
2. Each clip's record names the published fact meant to trigger it. No clip decides, times or advances gameplay (TH-16 RE-07, RT-07; HF-04a line 22).
3. Clip lengths and the authoring frame rate are recorded as parameters under the Q-P27 answer, with no value in the card.
4. No clip is synchronized to a voiced line or bark (Q-P28).

**Verification and evidence:** Static: PD-01 PF-09 per clip and track organization. Human review record (PD-01 PF-12): Andrew reviews rendered captures of each clip against BIBLE line 346. Not established: in-engine blending, timing against published results, or human feel. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No runtime input or import. No clip for an unanswered expression. No voice.

<a id="art-13"></a>

### ART-13: Hand-key Fuse's tool action clips

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-11's rig; Andrew's recorded Q-P27 answer listing tool actions and phases; TRACKING EV-0423 decision 1
- TRACKING EV-0411 and FR-07's accepted AM-H8-003: kit weapon, main hero skill, mobility and ultimate actions reference ability definitions (HF-06a row N-021) that reference the attacks they produce
- BIBLE.md lines 354, 357, 413 and 428
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RE-05, RE-07, RR-10 and RT-07; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-05 and EP-01
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40; `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 14 and 53

**Dependencies:** [ART-04](#art-04), [ART-11](#art-11), [FR-07](#fr-07). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P20](#q-p20), [Q-P26](#q-p26), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P11](#q-p11).

**Files touched:** `source-assets/fuse/tool/**`; `source-assets/fuse/provenance/tool/**`; `artifacts/local/tasks/ART-13/`.

**Definition of done:**

1. One action per tool action in the Q-P27 answer, each on its own NLA track (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40). Candidate names come from BIBLE lines 354, 357 and 428 and are used only where the answer admits them. A miscast action exists only for an element Q-P13 makes miscastable, and an ultimate action only as Q-P20 defines it.
2. Each clip's record names its trigger as the published result of an ability definition or of an attack that ability produces (AM-H8-003 through FR-07), never a raw input.
3. No clip moves the nozzle aim control, and a miscast clip stays local to one head (TH-16 RR-10; EV-0372 carried risk).
4. No clip decides, rerolls or advances an outcome (TH-16 RE-05, RE-07, RT-07; TH-03 CH-05).
5. Clip lengths and frame rate are parameters under the Q-P27 answer.

**Verification and evidence:** Static: PD-01 PF-09 per clip, with each trigger naming an ability or produced attack. Human review record (PD-01 PF-12): Andrew reviews captures of each clip at the ART-04 distance. Not established: alignment with committed geometry, in-engine playback or feel. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No effect, cue, runtime input or import. No node or upgrade content (Q-P11).

<a id="art-14"></a>

### ART-14: Implement the procedural rolling core, suspension and retraction motion in Godot

**Card revision:** 1 · **Owner:** Rendering/input/UI · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-05's brief with Andrew's recorded Q-P27 answer; ART-09's bone list; the scenes ART-17 and ART-18 admitted, including the ART-12 and ART-13 clips
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RC-02, RT-01 to RT-08, RM-06, RQ-02, RQ-03 and RE-06
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-04, MP-06, MP-16 and MP-23; `docs/tech/sections/HF-04a-runtime-lifecycle.md` line 22
- `docs/tech/sections/HF-01-production-conventions.md` lines 26, 27, 66 and 68; Godot 4.7.2 (BACKLOG.md line 9) with typed GDScript
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/g2-skeleton.txt` lines 8, 50, 58 and 66; `artifacts/handoff-8-2026-09-16/drafts/ctx7/g3-animtree.txt` lines 75 and 83 (AnimationTree for blending beyond the player's fixed cross-fades)
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PE-01

**Dependencies:** [ART-05](#art-05), [ART-09](#art-09), [ART-12](#art-12), [ART-13](#art-13), [ART-17](#art-17), [ART-18](#art-18), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P22](#q-p22), [Q-P27](#q-p27). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P21](#q-p21), [Q-P32](#q-p32).

**Files touched:** `native/presentation/motion/rolling_core_motion.gd` and its UID sidecar; `native/presentation/motion/rolling_core_motion.tscn` (the presentation composition that binds the script to the admitted core scene; HF-01 line 27); `artifacts/local/tasks/ART-14/`.

**Definition of done:**

1. Typed GDScript drives exactly ART-09's procedural bones from the published pose, extent and movement values Session supplies on D06 (TH-16 RC-02, RM-06), with the mechanism the approved brief selects from retrieved documentation.
2. Motion holds when no newer snapshot exists and on pause (TH-16 RT-02, RT-03). It is display-only with no writeback (TH-16 RT-05) and never advances a gameplay interval (TH-16 RT-07; HF-04a line 22).
3. The ART-12 and ART-13 clips imported by ART-18 play over the procedural pose, and the blending method and precedence are recorded (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g3-animtree.txt` lines 75 and 83).
4. Rates and ranges are read from parameters tied to the Q-P21, Q-P22 and Q-P32 answers. No authored tuning is duplicated in code (HF-01 line 26).
5. PD-01 PE-01's trial runs with the command the engineering handoff (TH-29) names and is recorded with source identity. If no command exists, the card returns blocked.

**Verification and evidence:** Automated native trial by the handoff's command for items 1, 2 and 5. Static: typed-boundary review against HF-01 line 66. Human review record (PD-01 PF-12): Andrew reviews captures from the trial for PD-01 AC-02. Not established: human feel, controller support, performance on target hardware (Q-E03) or route clearance (PD-01 PE-04). Human-hands steps: Andrew records Godot execution authorization; Andrew's review.

**Boundary:** Reads only D06 values. No gameplay record, camera, clearance claim or `native/runtime/**` change.

<a id="art-15"></a>

### ART-15: Design Fuse's elemental discharge effects as source masters

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RC-03, RE-01 to RE-09, RR-01, RR-05, RR-06, RR-08, RR-10, RP-16, RP-17, RP-20, RX-09 and RX-12
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 AT-17, CH-03, CH-05 and TP-06; `docs/tech/sections/TH-13-chaos-outcomes.md` TH-13 XP-01, XP-02 and XP-04
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-03, AC-16 and VW-11; BIBLE.md lines 493, 495 and 731
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g4-particles.txt` lines 26, 81 and 91 (a `GPUParticles3D` node needs a process material and at least one draw pass; the process material can be a ParticleProcessMaterial or carry a particles shader)
- `docs/tech/sections/HF-01-production-conventions.md` line 30 (materials permitted, shader source not named; DQ-02) and line 31; TH-19 IG-01 to IG-07 (no runtime input before the gates); ART-11's head controls; TRACKING EV-0423 decision 1

**Dependencies:** [ART-04](#art-04), [ART-11](#art-11). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P30](#q-p30), [Q-P32](#q-p32), [Q-P38](#q-p38).

**Files touched:** `source-assets/fuse/effects/**` (effect specification records, texture masters and provenance); `artifacts/local/tasks/ART-15/`. Nothing under the native tree; runtime effect scenes and materials are built at ART-19 after the import gates.

**Definition of done:**

1. One effect specification per head in the Q-P13 answer, stating that the effect is presented from the committed descriptor's parts and derives no geometry (TH-16 RC-03, RR-01), rooted at the firing head and the weapon origin (TH-03 TP-06).
2. The composition order keeps tool, danger footprint and escape visible before effects (TH-16 RR-05; BIBLE line 731), and each specification shows it with a mock frame over an ART-04 capture.
3. The specification names a ParticleProcessMaterial as the process material; a particles shader is not used until the DQ-02 amendment admits shader source.
4. Cosmetic variation changes no published part (TH-16 RE-08), instances hold no per-run state (TH-16 RE-06), and resources will reach Presentation only as handles (TH-16 RE-02).
5. Counts, lifetimes and pool sizes are parameters bound to TH-16 RP-20 under Q-E04 and Q-E03, and requiredness is bound to TH-16 RP-17 under Q-P30 and Q-P38, with no value.
6. Texture masters carry provenance (TH-19 PV-01) and tool versions pinned in PD-01 PF-06.

**Verification and evidence:** Static: review of each specification against TH-16 RE-01 to RE-09 and RR-10. Human review record (PD-01 PF-12): Andrew reviews the mock frames for PD-01 AC-03 and AC-16. Not established: engine behaviour of any effect, dense-fight readability (TH-16 RR-06), performance or human feel. Human-hands steps: Andrew installs Krita and records execution authorization; Andrew's review.

**Boundary:** No `native/` write, gameplay value, geometry or outcome. No sound.

<a id="art-16"></a>

### ART-16: Design Fuse's miscast tells as source masters

**Card revision:** 1 · **Owner:** Technical art · **Size:** S · **Lane:** asset production, native stage

**Source and inputs:**

- TRACKING EV-0322 (a miscast never changes the previewed danger shape) and the EV-0372 carried risk (miscast localization unproven while Q-P13 is open); TRACKING EV-0423 decision 1
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-08, RR-09, RR-10, RT-07 and RP-17; `docs/tech/sections/TH-13-chaos-outcomes.md` TH-13 XP-02 and XP-06; `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 CH-03 and TP-22
- ART-13's miscast clips and ART-15's effect specifications

**Dependencies:** [ART-13](#art-13), [ART-15](#art-15). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P13](#q-p13), [Q-P26](#q-p26), [Q-P30](#q-p30), [Q-P38](#q-p38). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04).

**Files touched:** `source-assets/fuse/effects/**`; `artifacts/local/tasks/ART-16/`.

**Definition of done:**

1. A tell specification for each miscast the Q-P13 answer allows, localized to one head, with its warning timing and disclosure following the answer (TH-03 TP-22).
2. No tell widens, moves or retargets the danger shape (TH-16 RR-10), and no tell advances or lengthens a window (TH-16 RT-07).
3. Requiredness follows the Q-P30 and Q-P38 answers (TH-16 RR-09, RP-17). A required tell that cannot be drawn holds the encounter (TH-16 RR-08; TH-13 XP-06).

**Verification and evidence:** Static: review against TH-16 RR-08 to RR-10. Human review record (PD-01 PF-12): Andrew reviews mock frames of each tell. Not established: that players read the tell before harm, which needs a human session, or localization in play. Human-hands steps: Andrew's review.

**Boundary:** No `native/` write. No miscast rule, frequency or warning policy chosen by the card. No gameplay change.

<a id="art-17"></a>

### ART-17: Import and admit the shared rolling core and cockpit through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01 to OC-05, PV-01 to PV-07, IS-01 to IS-09, SI-01 to SI-06, GO-01 to GO-06, AR-01 to AR-08, EM-01 to EM-08, NO-02 to NO-04, AG-01 to AG-09 and IG-01 to IG-07, and walk W1 at lines 306 to 329
- `docs/tech/sections/HF-05-content-admission.md` lines 24, 25, 49 and 52; `docs/tech/sections/HF-01-production-conventions.md` lines 30, 36, 61, 72 and 85
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RM-01, RM-02 and RM-07; `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-11
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40 and `artifacts/handoff-8-2026-09-16/drafts/ctx7/b4-gltf-export.txt` line 40 (export modes); `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1-gltf-import.txt` lines 8 and 111 (a post-import script is set through the Custom Script import property); `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 22 to 36 and 83 to 94
- NQ-01's receipts; ART-06 and ART-09 masters; TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [ART-06](#art-06), [ART-09](#art-09), [SC-01](#sc-01), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13).

**Files touched:** `native/content/rolling_core/assets/**` (exported glTF input and textures with their `.import` sidecars); `native/content/rolling_core/scenes/**` (composition scene); `source-assets/rolling_core/provenance/import/**` (TH-19 PV-02 links and recipe); `artifacts/local/tasks/ART-17/`.

**Definition of done:**

1. TH-19 IG-01 to IG-07 are each closed with named evidence before any file is staged (TH-19 AG-01).
2. The runtime input is exported from the masters by the recipe recorded under PD-01 PF-06, with the exporter mode recorded (TH-19 PV-03).
3. Each sidecar is committed beside its input and reviewed as sidecar bytes (TH-19 IS-01, IS-02). Texture import settings follow the Q-E04 answer (TH-19 AQ-12). A custom post-import script is used only if a Tooling card under `native/editor_tools/**` supplies it (HF-01 line 36).
4. The composition scene references inputs by exact path and definitions by domain ID and carries no second gameplay value (TH-19 AR-01, AR-02, AR-07). A missing reference is a diagnostic, never a fallback (TH-19 AR-06; TH-16 RM-07).
5. TH-19's W1 order is walked for this unit through the authorized export, ending with the exported-load receipt (TH-19 EM-06, AG-09).
6. Every manifest entry reaches its provenance link and notice obligation (TH-19 EM-02, NO-04).

**Verification and evidence:** Automated native: import of a staged copy, validation of TH-19 AG-05 to AG-07, and the exported load of TH-19 AG-09, by the handoff's commands. Static: each sidecar tracked and not ignored, no `.godot` path staged (TH-19 GO-04), provenance complete. Human review record (PD-01 PF-12): Andrew compares in-engine captures with ART-06's review renders for PD-01 AC-01, AC-02 and AC-06, with any difference recorded as a finding. Not established: renderer qualification, budgets measured on target hardware, Windows execution or human feel. Human-hands steps: Andrew installs Blender for the export and records Blender and Godot execution authorization; Andrew's review.

**Boundary:** Admission is not distribution approval (TH-19 NO-05; Q-E06). No definition authoring, which belongs to Content cards. No editor tool. No gameplay value.

<a id="art-18"></a>

### ART-18: Import and admit Fuse's pilot, tool and clips through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row
- TRACKING EV-0411 and FR-07's accepted AM-H8-003: slot actions reference ability definitions (HF-06a row N-021), and HF-06a row N-013 distinguishes a slot action's visual reference from an attack's
- TRACKING EV-0423 decision 4: the provisional distance of ART-04 is rechecked in the native slice
- Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` lines 14 and 53 (glTF animations become AnimationPlayer animations on import)
- ART-04's check record; ART-07, ART-08, ART-10, ART-11, ART-12 and ART-13 masters and PD-01 PF-09 records

**Dependencies:** [NQ-01](#nq-01), [ART-04](#art-04), [ART-07](#art-07), [ART-08](#art-08), [ART-10](#art-10), [ART-11](#art-11), [ART-12](#art-12), [ART-13](#art-13), [ART-17](#art-17), [FR-07](#fr-07), [SC-01](#sc-01), [SC-02](#sc-02), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P06](#q-p06), [Q-P13](#q-p13), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13), [Q-P32](#q-p32).

**Files touched:** `native/content/fuse/assets/pilot/**` and `native/content/fuse/assets/tool/**` (inputs with sidecars; the effects folder is ART-19's and the audio folder belongs to the sound import card); `native/content/fuse/scenes/pilot/**` and `native/content/fuse/scenes/tool/**` (compositions mounted on ART-17's core scene); `source-assets/fuse/provenance/import/**`; `docs/art/production/fuse/review/native/**` (the native recheck record; DQ-01); `artifacts/local/tasks/ART-18/`.

**Definition of done:**

1. ART-17 items 1 to 6 hold for the pilot and tool inputs.
2. Every clip in the ART-12 and ART-13 records is present after import under its recorded name (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` line 53). A missing or renamed clip is a rejection.
3. Each tool-action clip's binding names the ability definition or produced attack its record names (AM-H8-003 through FR-07), and the tool's visual reference is kept distinct from an attack's (HF-06a row N-013).
4. The tool mounts on the core scene at ART-11's recorded attachment, and the nozzle aim control is left for published values (TH-16 RC-02).
5. ART-04's silhouette and sightline check is repeated at the native slice's camera and recorded beside ART-04's provisional verdict; a disagreement returns the model to Andrew as a finding (TRACKING EV-0423 decision 4).

**Verification and evidence:** As ART-17, plus an automated check listing imported clip names against the PD-01 PF-09 records. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each clip and the native recheck. Not established: blending with ART-14's procedural motion in play, Q-P32's bounds, or human feel. Human-hands steps: as ART-17, and Andrew's native recheck verdict.

**Boundary:** As ART-17. No effects, which belong to ART-19. The native recheck answers nothing about Q-P32's bounds.

<a id="art-19"></a>

### ART-19: Build, import and admit Fuse's discharge effects and miscast tells through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RE-02 to RE-04, RP-17 and RX-10
- ART-15 and ART-16 specifications and texture masters; Context7 receipt `artifacts/handoff-8-2026-09-16/drafts/ctx7/g4-particles.txt` lines 81 and 91
- TRACKING EV-0411 and FR-07 (HF-06a row N-013's visual references); TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [ART-15](#art-15), [ART-16](#art-16), [ART-18](#art-18), [FR-07](#fr-07), [SC-02](#sc-02), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P13](#q-p13), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-P30](#q-p30), [Q-P38](#q-p38).

**Files touched:** `native/content/fuse/assets/effects/**` (textures, process materials and sidecars); `native/content/fuse/scenes/effects/**` (effect scenes); `source-assets/fuse/provenance/effects_import/**`; `artifacts/local/tasks/ART-19/`.

**Definition of done:**

1. After TH-19 IG-01 to IG-07 are closed (TH-19 AG-01), one effect scene per ART-15 specification and one per ART-16 tell is built with the process material and draw pass the specification names (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g4-particles.txt` lines 81 and 91).
2. ART-17 items 2 to 6 hold for every effect input.
3. A presentation-only effect replacement is staged as a new catalogue revision, and it keeps the gameplay content revision only after validation (TH-16 RE-04; TH-19 SI-04).

**Verification and evidence:** As ART-17. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each effect and tell against the specifications' mock frames. Not established: dense-fight readability or performance. Human-hands steps: Andrew records Godot execution authorization; Andrew's review.

**Boundary:** As ART-17. No shader source until DQ-02's amendment. No gameplay value.

## Iron Orchard enemy family

<a id="art-20"></a>

### ART-20: Make candidate concept and telegraph sheets for the Iron Orchard enemy family

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 (one Iron Orchard enemy family); TRACKING EV-0423 decisions 1 and 3; BIBLE.md lines 221, 225, 519, 521, 523, 525 and 731
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4, EP-01, EP-06, EP-09 and TP-15; `docs/tech/sections/TH-06-encounters-waves-and-enemies.md` TH-06 AV-03 and AV-06
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-01, RR-02, RR-05, RR-06 and RR-07
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-10, AC-13, AC-14, AC-16, AC-19, AC-20 and AC-22; PD-01 VW-01, VW-03, VW-04 and VW-11; PD-01 CC-06, CC-07 and RL-05; PD-01 PF-01 to PF-15; PD-01 line 63
- `docs/ENEMY-ROSTER.md` as a candidate reference only

**Dependencies:** [PD-01](#pd-01). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-E10](#q-e10), [Q-P25](#q-p25), [Q-P33](#q-p33). The sheets support Andrew's Q-P25 selection and select nothing.

**Files touched:** `docs/art/production/iron_orchard_enemies/**` (DQ-01); `artifacts/local/tasks/ART-20/`.

**Definition of done:**

1. A PD-01 VW-03 comparison of candidate families drawn from the orchard mechanisms the Bible names (BIBLE line 225), each with a PD-01 VW-04 turnaround of its working tool.
2. For each candidate attack, a panel set for prepare, commit, execute and recover (TH-03 EN-1 to EN-4) in which the working tool explains the threat before any danger shape exists (TH-03 EP-01), and a PD-01 VW-11 diagram captioned intended geometry with the height band drawn (TH-16 RR-02).
3. One overlapping-commitment panel shows two windups each keeping its own drawing (TH-16 RR-06), with admission limits captioned unset (Q-E10).
4. Sheets are made by image prompts plus paintover with provenance as ART-01 item 2 (TRACKING EV-0423 decision 3). Captions name every family, shape, band and window as a candidate, TH-03 TP-15 values stay unset under Q-P25, and no caption claims a generated image proves a timing, hitbox or physical property (PD-01 line 63).

**Verification and evidence:** Static: a paper check per sheet for view IDs, stage panels, prompt records and provenance fields. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-10, AC-13, AC-14, AC-16, AC-19, AC-20 and AC-22. Not established: a verified hitbox, timing or readability in play. Human-hands steps: Andrew's review; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept only. No roster, family, attack grammar or defensive grade chosen.

<a id="art-21"></a>

### ART-21: Make rough blockouts of the selected enemy family and check telegraph-pose silhouettes

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- ART-20's sheets; Andrew's recorded Q-P25 answer naming the family and its attack grammar; TRACKING EV-0423 decision 1; TRACKING EV-0447 decisions 1 and 2 (the orchard camera distance is the provisional distance for these enemies, rechecked natively)
- `src/orchard/scene.js` lines 410 and 412: the orchard chase camera's distance expression and the camera position derived from it
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4, EP-01 and TP-15; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-02, RR-05 and RR-06
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-04 and MP-23; `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-16 and VW-01

**Dependencies:** [ART-20](#art-20). **Blocking questions:** [Q-P25](#q-p25). Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-E10](#q-e10), [Q-P26](#q-p26) (the measured budget only), [Q-P32](#q-p32) (the provisional distance is Andrew's decision at TRACKING EV-0447 decision 2, not an answer to Q-P32's bounds; the native recheck belongs to ART-24).

**Files touched:** `source-assets/iron_orchard_enemies/blockout/**`; `source-assets/iron_orchard_enemies/provenance/blockout/**`; `docs/art/production/iron_orchard_enemies/review/**` (DQ-01); `artifacts/local/tasks/ART-21/`.

**Definition of done:**

1. Rough blockouts for each family member the Q-P25 answer names, with a held pose for each of that member's attack stages (TH-03 EN-1 to EN-4).
2. Renders at the provisional distance record, per stage pose, whether the tool, danger footprint and escape stay visible (TH-16 RR-05) and whether the height band reads (TH-16 RR-02).
3. The check record states the provisional distance as the orchard expression at `src/orchard/scene.js` line 410 evaluated for each member, with every input to that expression named, and labels it provisional under TRACKING EV-0447 decision 2 (TH-02 MP-23 stays unset); the card writes no distance value of its own.
4. The check record ends with a lock or revise verdict recorded by Andrew, and names the native recheck at the native slice's camera as an open obligation carried by ART-24.

**Verification and evidence:** Human review record (PD-01 PF-12): Andrew's verdict. Static: every stage pose has renders at the recorded camera parameters. Not established: committed geometry, timing or play readability. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's verdict.

**Boundary:** No shape, band or window value. The provisional distance is Andrew's decision and not an answer to Q-P32.

<a id="art-22"></a>

### ART-22: Model, UV and texture the selected enemy family

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-21's locked blockouts; TRACKING EV-0423 decision 1; BIBLE.md lines 221, 225 and 645
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-05, AC-06, AC-10 and AC-19; PD-01 PF-01 to PF-15
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03

**Dependencies:** [ART-21](#art-21). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1).

**Files touched:** `source-assets/iron_orchard_enemies/models/**`, `source-assets/iron_orchard_enemies/textures/**` and `source-assets/iron_orchard_enemies/provenance/model/**`; `artifacts/local/tasks/ART-22/`.

**Definition of done:**

1. Final models for each member in the Q-P25 answer, with the working tool's joints separated at the locked pivots.
2. UVs and textures place wear by use and stay distinct at gameplay distance (PD-01 AC-05, AC-06), within the Q-P26 and Q-E03 answers.
3. TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance and license fields; budget conformance by the Q-P26 method. Human review record (PD-01 PF-12): Andrew reviews turnaround and gameplay-distance renders for PD-01 AC-05, AC-06, AC-10 and AC-19. Not established: in-engine appearance or performance. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No rig, poses, runtime input or import. Re-size check: split per member if the Q-P25 answer names more members than one M card can review.

<a id="art-23"></a>

### ART-23: Rig the enemy family's working tools

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-22's masters; Andrew's recorded Q-P25 answer; TRACKING EV-0423 decision 1; TRACKING EV-0447 decision 3 (hybrid enemy motion: procedural locomotion and turning in Godot, hand-keyed Blender wind-up and attack clips; specifics open)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4 and EP-01
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8, 16 and 24; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` line 20
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PF-09

**Dependencies:** [ART-22](#art-22). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P42](#q-p42) (the hybrid approach is recorded at TRACKING EV-0447 decision 3; the per-member split is the parameter row in item 2).

**Files touched:** `source-assets/iron_orchard_enemies/models/**` (armatures in the masters); `source-assets/iron_orchard_enemies/provenance/rig/**`; `artifacts/local/tasks/ART-23/`.

**Definition of done:**

1. An armature for each member covering every attack stage the Q-P25 answer names (TH-03 EN-1 to EN-4), under the hybrid approach of TRACKING EV-0447 decision 3: bones for locomotion and turning are named for a Godot-side procedural driver, and working-tool joints carry controls for hand-keyed wind-up and attack clips.
2. Parameter row: which motions of each member are procedural and which are keyed, recovery included. Value unset, gated on the specifics Q-P42 leaves open; bones for a motion whose treatment is unset are recorded as provisional.
3. Weights use a method recorded under PD-01 PF-09 (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b1-armatures.txt` lines 8 and 16; `artifacts/handoff-8-2026-09-16/drafts/ctx7/b2-weight-paint.txt` line 20).
4. PD-01 PF-09 records the bone list, rest pose, units and axes within the Q-P26 and Q-E03 answers. A test export goes to receipts only.

**Verification and evidence:** Static: PD-01 PF-09 record against the Q-P25 attack list. Human review record (PD-01 PF-12): Andrew reviews pose-range renders of each tool. Not established: clip quality, committed geometry or playback. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No clips, attack values, runtime input or import. Re-size check as ART-22.

<a id="art-29"></a>

### ART-29: Key the enemy family's telegraph stage clips

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-23's rigs; Andrew's recorded Q-P25 answer; TRACKING EV-0423 decision 1; TRACKING EV-0447 decision 3 (hand-keyed Blender wind-up and attack clips; procedural locomotion and turning in Godot; specifics open)
- `docs/tech/sections/TH-03-a-committed-attack-means-what-it-shows.md` TH-03 EN-1 to EN-4, EP-01, EP-09, AO-01 and TP-15; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RR-01, RR-07, RE-05 and RT-07
- Context7 receipts `artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` lines 8 and 40

**Dependencies:** [ART-21](#art-21), [ART-23](#art-23). **Blocking questions:** [Q-E01](#q-e01), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-P42](#q-p42) (the hybrid approach is recorded at TRACKING EV-0447 decision 3; which stages are keyed per member is the parameter row in item 2).

**Files touched:** `source-assets/iron_orchard_enemies/models/**` (actions in the masters); `source-assets/iron_orchard_enemies/provenance/clips/**`; `artifacts/local/tasks/ART-29/`.

**Definition of done:**

1. One hand-keyed action per wind-up and attack stage per attack in the Q-P25 answer (TH-03 EN-1 to EN-3), each on its own NLA track (`artifacts/handoff-8-2026-09-16/drafts/ctx7/b3-actions-nla.txt` line 40), under TRACKING EV-0447 decision 3; locomotion and turning are procedural in Godot and are not keyed here.
2. Parameter row: whether each member's recovery stage (TH-03 EN-4) and any other motion is keyed or procedural. Value unset, gated on the specifics Q-P42 leaves open.
3. Poses present the declared geometry and never define it (TH-16 RR-01, RE-05; TH-03 EP-01). Clip progress never advances a windup, active window or recovery (TH-03 AO-01; TH-16 RT-07).
4. Stage lengths are parameters under TH-03 TP-15 and Q-P25, with no value.

**Verification and evidence:** Static: PD-01 PF-09 per clip. Human review record (PD-01 PF-12): Andrew reviews captures of each stage at the ART-21 camera distance. Not established: alignment with committed geometry, timing or play readability. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** No attack shape, band or window. Re-size check: split per member if the Q-P25 answer's clip list exceeds one M card.

<a id="art-24"></a>

### ART-24: Import and admit the enemy family through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row; ART-21's check record, ART-22 and ART-23 masters and ART-29 clip records; TRACKING EV-0423 decision 1; TRACKING EV-0447 decision 2 (native recheck of the provisional distance)

**Dependencies:** [NQ-01](#nq-01), [ART-21](#art-21), [ART-22](#art-22), [ART-23](#art-23), [ART-29](#art-29), [SC-02](#sc-02), [SC-04](#sc-04), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P25](#q-p25), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13).

**Files touched:** `native/content/iron_orchard_enemies/assets/models/**` (inputs with sidecars; the audio folder belongs to the sound import card); `native/content/iron_orchard_enemies/scenes/**`; `source-assets/iron_orchard_enemies/provenance/import/**`; `docs/art/production/iron_orchard_enemies/review/native/**` (the native recheck record; DQ-01); `artifacts/local/tasks/ART-24/`.

**Definition of done:**

1. ART-17 items 1 to 6 hold for every member input.
2. Every stage clip is present after import under its recorded name (`artifacts/handoff-8-2026-09-16/drafts/ctx7/g1b-gltf-skinned-import.txt` line 53).
3. Scenes reference the enemy definition by domain ID and carry no attack value (TH-19 AR-07; TH-16 RE-05).
4. ART-21's telegraph-pose check is repeated at the native slice's camera and recorded beside ART-21's provisional verdict; a disagreement returns the member to Andrew as a finding (TRACKING EV-0447 decision 2).

**Verification and evidence:** As ART-17, plus the imported clip-name check. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each stage and the native recheck. Not established: telegraph readability in play, which needs PD-03 AU-02 or a play session, or Q-P32's bounds. Human-hands steps: as ART-17, and Andrew's native recheck verdict.

**Boundary:** As ART-17. No encounter or enemy definition authoring. Re-size check as ART-22.

## Iron Orchard environment module set

<a id="art-25"></a>

### ART-25: Make the Iron Orchard landscape study and candidate module sheets

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- TRACKING EV-0372 (one Iron Orchard environment module set); TRACKING EV-0423 decisions 1 and 3; BIBLE.md lines 215, 219, 221, 223 and 227; § 7 lines 655, 684, 685, 709 and 711
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-04, AC-11, AC-12, AC-17, AC-18 and AC-20; PD-01 VW-02, VW-08 and VW-09; PD-01 PE-04, PE-07 and RL-01; PD-01 PF-01 to PF-15; PD-01 line 63
- `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-04; `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-17

**Dependencies:** [PD-01](#pd-01). **Blocking questions:** None. Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P07](#q-p07), [Q-P22](#q-p22), [Q-P23](#q-p23), [Q-P24](#q-p24), [Q-P26](#q-p26), [Q-P33](#q-p33).

**Files touched:** `docs/art/production/iron_orchard_modules/**` (DQ-01); `artifacts/local/tasks/ART-25/`.

**Definition of done:**

1. A PD-01 VW-08 landscape study of the Iron Orchard with the region's terrain language (tree rows, irrigation hardware, patched greenhouses, worn turning aprons, terraces, service ramps and greenhouse courts; BIBLE lines 221, 223), under one coherent lighting condition captioned as a candidate under Q-P33 (PD-01 AC-04).
2. A module sheet decomposing that language into candidate modules with a shared scale reference, captioned as candidates whose membership belongs to Q-P26.
3. Route-clearance callouts are captioned unset (TH-02 MP-17; Q-P22) and make no clearance claim (PD-01 PE-04).
4. Terrain consequences and generated-level assembly are captioned as proposals under Q-P24 and Q-P23.
5. Sheets are made by image prompts plus paintover with provenance as ART-01 item 2, and no caption claims a generated image proves clearance or a physical property (PD-01 line 63).

**Verification and evidence:** Static: paper check of view IDs, captions, prompt records and provenance fields. Human review record (PD-01 PF-12): Andrew observes PD-01 AC-04, AC-11, AC-12, AC-17, AC-18 and AC-20. Not established: clearance, lighting behaviour in play (PD-01 PE-07) or wayfinding. Human-hands steps: Andrew's review; Andrew installs Krita if the paintover uses it.

**Boundary:** Concept only. No module list, region scope, lighting rule or level technique chosen.

<a id="art-26"></a>

### ART-26: Make rough blockouts of the Iron Orchard module set

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, concept stage

**Source and inputs:**

- ART-25's sheets and Andrew's review record of them; the module set recorded at TRACKING EV-0447 decision 1; TRACKING EV-0423 decisions 1 and 2
- `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-17; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-04
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-12, AC-17 and PE-04; BIBLE.md lines 487 and 711

**Dependencies:** [ART-25](#art-25). **Blocking questions:** [Q-P23](#q-p23). Gate: proposed for the sprint after the current one under TRACKING EV-0423 decision 1, with the batch asset list and file locations recorded at TRACKING EV-0447 decision 1; runs only inside a sprint Andrew authorizes. **Registered non-blocking questions:** [Q-P22](#q-p22), [Q-P24](#q-p24), [Q-P26](#q-p26) (the measured budget only), [Q-P33](#q-p33).

**Files touched:** `source-assets/iron_orchard_modules/blockout/**`; `source-assets/iron_orchard_modules/provenance/blockout/**`; `artifacts/local/tasks/ART-26/`.

**Definition of done:**

1. Rough blockouts for each candidate module ART-25's sheet names and Andrew's review record keeps, with connection points assembled as the Q-P23 answer allows.
2. Each passage is labelled with its intended route role; clearance is not measured here, because the fully grown clearance check is NQ-03's executed trial (TRACKING EV-0423 decision 2; PD-01 PE-04).
3. Provenance records carry PD-01 PF-01 to PF-13 and PF-15, with the Blender version pinned in PD-01 PF-06.

**Verification and evidence:** Static: provenance records and the route-role labels. Human review record (PD-01 PF-12): Andrew reviews blockout renders for PD-01 AC-12 and AC-17. Not established: clearance, collision behaviour or play. Human-hands steps: Andrew installs Blender and records execution authorization; Andrew's review.

**Boundary:** Rough blockouts only. No collision geometry (DQ-05), no clearance measurement, and no envelope or clearance value.

<a id="art-27"></a>

### ART-27: Model, UV and texture the Iron Orchard module set

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- ART-26's blockouts; TRACKING EV-0423 decision 1; BIBLE.md lines 221, 223, 699, 701 and 711
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 AC-05, AC-06, AC-11 and AC-12; PD-01 PF-01 to PF-15
- `docs/tech/sections/TH-19-asset-import-export.md` TH-19 OC-01, PV-01 to PV-05, NO-02 and NO-03

**Dependencies:** [ART-26](#art-26). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E04](#q-e04), [Q-P33](#q-p33).

**Files touched:** `source-assets/iron_orchard_modules/models/**`, `source-assets/iron_orchard_modules/textures/**` and `source-assets/iron_orchard_modules/provenance/model/**`; `artifacts/local/tasks/ART-27/`.

**Definition of done:**

1. Final modules that keep each blockout passage's route role and connection points.
2. UVs and textures within the Q-P26 and Q-E03 answers, with vegetation bands related to rock and slope (PD-01 AC-11; BIBLE line 711).
3. TH-19 OC-01 record as ART-06 item 4.

**Verification and evidence:** Static: provenance and license fields. Human review record (PD-01 PF-12): Andrew reviews PD-01 VW-02 and VW-08 renders for PD-01 AC-05, AC-06, AC-11 and AC-12. Not established: lighting behaviour, performance or clearance in play. Human-hands steps: Andrew installs Blender and Krita and records execution authorization; Andrew's review.

**Boundary:** No collision geometry, runtime input or import.

<a id="art-28"></a>

### ART-28: Import and admit the Iron Orchard module set through TH-19

**Card revision:** 1 · **Owner:** Technical art · **Size:** M · **Lane:** asset production, native stage

**Source and inputs:**

- Every ART-17 source row; ART-27 masters; `docs/tech/schemas/SC-05.md` (admitted; level module definitions); TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [ART-27](#art-27), [SC-05](#sc-05), [SC-07](#sc-07), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-E04](#q-e04), [Q-P23](#q-p23), [Q-P26](#q-p26). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-E13](#q-e13).

**Files touched:** `native/content/iron_orchard_modules/assets/**`; `native/content/iron_orchard_modules/scenes/**`; `source-assets/iron_orchard_modules/provenance/import/**`; `artifacts/local/tasks/ART-28/`.

**Definition of done:**

1. ART-17 items 1 to 6 hold for every module input.
2. Module scenes reference level module definitions by domain ID and carry no second gameplay value (TH-19 AR-07).

**Verification and evidence:** As ART-17. Human review record (PD-01 PF-12): Andrew reviews in-engine captures of each module. Not established: executed clearance, which is NQ-03's, lighting behaviour or performance. Human-hands steps: as ART-17.

**Boundary:** As ART-17. No level definition, route or generation rule.

<a id="nq-03"></a>

### NQ-03: Run the fully grown route-clearance trial on the Iron Orchard modules

**Card revision:** 1 · **Owner:** Verification · **Size:** S · **Lane:** native qualification, native stage

**Source and inputs:**

- TRACKING EV-0423 decision 2: the fully grown clearance check is a separate evidence card
- `docs/product/sections/PD-01-art-acceptance.md` PD-01 PE-04; BIBLE.md line 487 (test the loop at ordinary maximum growth)
- `docs/tech/sections/TH-15-physics-query-contract.md` TH-15 PX-09 (its two-extent setup only) and TH-15 PX-10 (install timing, not used); `docs/tech/sections/TH-02-movement-camera-and-active-aim.md` TH-02 MP-16 and MP-17; `docs/tech/sections/TH-16-rendering-integration.md` TH-16 RQ-04 and RQ-05; `docs/tech/sections/TH-05-electromagnetic-collection-recycling-and-growth.md` TH-05 CO-11
- The modules ART-28 admitted, and the module collision geometry the TH-15 card named in DQ-05 supplies

**Dependencies:** [ART-28](#art-28), [TH-15](#th-15), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-P22](#q-p22) (ordinary maximum envelope and minimum clearance). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1); held back from the closure definition import until the module collision card DQ-05 names exists (TRACKING EV-0435). **Registered non-blocking questions:** [Q-P23](#q-p23), [Q-P24](#q-p24).

**Files touched:** `native/tests/clearance/orchard_modules_clearance.gd` and its UID sidecar (proposed name, renamed only if the engineering handoff names another; HF-01 line 33); `artifacts/local/tasks/NQ-03/`.

**Definition of done:**

1. Using TH-15 PX-09's two-extent setup with this card's own pass rule, not the expected observation of TH-15 PX-09 that the larger extent is stopped, each admitted module passage runs with the starter extent and the ordinary maximum extent the Q-P22 answer records, installed as values through the rebuild route (TH-05 CO-11), with the handoff's command. TH-15 PX-10 tests install timing, not passage clearance, and is not used.
2. Each passage's result is recorded as pass or content defect; a passage that fits only the starter is a defect and the runtime never shrinks the actor (TH-16 RQ-04).
3. PD-01 PE-04 is reported satisfied only for the recorded modules, host and version.

**Verification and evidence:** Automated native trial by the handoff's command, with source identity. Not established: play feel, other regions, or Windows (TH-16 RQ-05). Human-hands steps: Andrew records Godot execution authorization.

**Boundary:** No module geometry change; a failing passage is recorded as a finding against the module models. No envelope value chosen by the card.

## Sound production

Every sound card waits on TH-17 for cue ownership and mix, on PD-03's questions, and on the playable native build (TRACKING EV-0423 decision 1; BIBLE line 747). No card here produces a listening result that stands in for PD-03's audition matrix, which needs that build (PD-03 AU-01 to AU-06). Sound cards do not block on Q-P26: BACKLOG Q-P26's affected work names models, textures, rigs, attachment sizing, material and lighting work and import checks, not audio, and Q-P31 is the sound batch's manifest gate (a recorded deviation from attempt A2's required change 5).

<a id="snd-01"></a>

### SND-01: Record or synthesize Fuse's directed weapon cues

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-07 and SE-08; PD-03 SI-01 to SI-04, SI-11 and SI-12; PD-03 UD-03 and UD-06; PD-03 SP-06, SP-07 and SP-14; PD-03 BP-01 to BP-07 as non-precedent
- TRACKING EV-0411 and FR-07's accepted AM-H8-003 (weapon actions reference ability definitions, HF-06a row N-021); TRACKING EV-0423 decision 1
- BIBLE.md lines 745, 747, 776 and 789; `docs/DISCOVERY.md` line 211 (Audacity as a free local candidate)
- `docs/project/ASSETS.md` line 17; `docs/tech/sections/TH-19-asset-import-export.md` TH-19 PV-04, NO-02 and NO-03, and Seam 2 at line 296
- TH-17's admitted section (cue ownership and mix)

**Dependencies:** [FR-07](#fr-07), [PD-03](#pd-03), [TH-17](#th-17). **Blocking questions:** [Q-E01](#q-e01), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-P06](#q-p06), [Q-P28](#q-p28).

**Files touched:** `source-assets/fuse/audio/weapon/**` (editable masters, synthesis recipes and provenance with license evidence; HF-01 line 31 with the DQ-01 Audio amendment); `artifacts/local/tasks/SND-01/`.

**Definition of done:**

1. Masters for PD-03 SE-07's preparation, contact and reset tail and for PD-03 SE-08's directed-cast identity for Fuse (BIBLE line 776), each keyed to the published result of the weapon's ability definition or an attack it produces (AM-H8-003 through FR-07).
2. The source method follows the Q-P31 answer, recorded or synthesized with a free local tool (`docs/DISCOVERY.md` line 211), with the tool version pinned at first use. Provenance records creator, license evidence and notice obligation (ASSETS.md line 17; TH-19 NO-02, NO-03). A recording names its physical source. Nothing is downloaded unless the Q-P31 answer allows it and license evidence is recorded.
3. No cue is aligned to a beat, and none carries timing that could lengthen a window (PD-03 SI-02, SI-03). Durations and tails are recorded against the PD-03 SP-06 answer, with no value in the card.
4. Variation for repeated details follows the PD-03 SP-07 answer, with no count in the card.
5. No runtime input is written. Export belongs to SND-05.

**Verification and evidence:** Static: provenance and license fields per master. Human review record: Andrew's listening review of the masters in isolation, recorded as one listener's opinion and explicitly not PD-03 AU-01. Not established: mix or priority in play (PD-03 SI-01), fatigue (PD-03 FT-01), playback hardware or human feel. Human-hands steps: Andrew installs Audacity or the chosen tool and records execution authorization; Andrew's listening review; any physical recording.

**Boundary:** No bus, voice or mix decision (TH-17). No music (Q-P17). No voice or barks (PD-03 UD-07). No paid tool or generation service.

<a id="snd-02"></a>

### SND-02: Record or synthesize Fuse's field and miscast cues

**Card revision:** 1 · **Owner:** Audio · **Size:** S · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-08, SI-08, SI-11, UD-04 and SP-12; TRACKING EV-0322
- Every SND-01 source row

**Dependencies:** [FR-07](#fr-07), [PD-03](#pd-03), [SND-01](#snd-01), [TH-17](#th-17). **Blocking questions:** [Q-E01](#q-e01), [Q-P13](#q-p13), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06).

**Files touched:** `source-assets/fuse/audio/field_miscast/**`; `artifacts/local/tasks/SND-02/`.

**Definition of done:**

1. Masters that tell automatic field activity and each miscast the Q-P13 answer allows apart from SND-01's directed cast (PD-03 SE-08), keyed to the main hero skill's ability definition or the miscast outcome it publishes.
2. No miscast cue implies a danger shape other than the previewed one (PD-03 SI-08), and no cosmetic variation rerolls an outcome (PD-03 SI-11).
3. Provenance, timing and variation as SND-01 items 2 to 4.

**Verification and evidence:** As SND-01. Not established: whether players hear a miscast before harm, which needs a human session. Human-hands steps: as SND-01.

**Boundary:** As SND-01. No miscast rule or warning policy chosen.

<a id="snd-03"></a>

### SND-03: Record or synthesize Fuse's ultimate cue

**Card revision:** 1 · **Owner:** Audio · **Size:** S · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-10, SI-01, SI-14, UD-05 and SP-11; BIBLE.md lines 745 and 791
- Every SND-01 source row

**Dependencies:** [FR-07](#fr-07), [PD-03](#pd-03), [SND-01](#snd-01), [TH-17](#th-17). **Blocking questions:** [Q-E01](#q-e01), [Q-P17](#q-p17), [Q-P20](#q-p20), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06).

**Files touched:** `source-assets/fuse/audio/ultimate/**`; `artifacts/local/tasks/SND-03/`.

**Definition of done:**

1. Masters for anticipation and main consequence of the ultimate the Q-P20 answer defines (PD-03 SE-10), keyed to the ultimate's ability definition.
2. The consequence earns an added layer, not a rising master level (PD-03 SI-14), and leaves threats audible first (PD-03 SI-01). Any music interaction follows the Q-P17 answer.
3. Provenance, timing and variation as SND-01 items 2 to 4.

**Verification and evidence:** As SND-01. Not established: PD-03 AU-05's exceptional-build session. Human-hands steps: as SND-01.

**Boundary:** As SND-01. No charge or cadence value.

<a id="snd-04"></a>

### SND-04: Record or synthesize the enemy family's warning cues

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SE-11, SE-12 and SE-13; PD-03 SI-02, SI-03, SI-05 and SI-10; PD-03 UD-10 and UD-11; PD-03 BP-02 (no browser precedent for warnings)
- BIBLE.md lines 777 and 789; ART-29's stage clips, whose working mechanism each cue voices
- Every SND-01 source row

**Dependencies:** [ART-29](#art-29), [PD-03](#pd-03), [TH-17](#th-17). **Blocking questions:** [Q-E01](#q-e01), [Q-P25](#q-p25), [Q-P31](#q-p31), [Q-P32](#q-p32). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06), [Q-P30](#q-p30).

**Files touched:** `source-assets/iron_orchard_enemies/audio/warnings/**`; `artifacts/local/tasks/SND-04/`.

**Definition of done:**

1. Masters for preparation, commitment and release, and recovery for each attack in the Q-P25 answer (PD-03 SE-11 to SE-13), voicing that member's working mechanism (BIBLE line 777).
2. No warning is deferred, quantized or aligned to a beat (PD-03 SI-02). Each is paired with visible information, so sound disabled removes no needed warning (PD-03 SI-05).
3. An arrival cue is made only if the Q-P30 answer makes one required (PD-03 UD-10).
4. Provenance, timing and variation as SND-01 items 2 to 4.

**Verification and evidence:** As SND-01. Not established: PD-03 AU-02 and AU-04, the sound-disabled readability sessions, or dense-fight audibility (PD-03 AU-03). Human-hands steps: as SND-01.

**Boundary:** As SND-01. No attack timing.

<a id="snd-05"></a>

### SND-05: Import and admit the batch's sound inputs through TH-19

**Card revision:** 1 · **Owner:** Audio · **Size:** M · **Lane:** sound production, native stage

**Source and inputs:**

- `docs/tech/sections/TH-19-asset-import-export.md` Seam 2 at line 296, TH-19 OC-02, OC-03, IS-01, SI-01, EM-02, NO-02, NO-04, AG-01 to AG-09, IG-01 to IG-07 and AQ-18
- `docs/product/sections/PD-03-sound-feel-events.md` PD-03 SI-04 and SI-12; `docs/tech/sections/HF-01-production-conventions.md` lines 30 and 72
- SND-01 to SND-04 masters and records; TRACKING EV-0423 decision 1

**Dependencies:** [NQ-01](#nq-01), [SND-01](#snd-01), [SND-02](#snd-02), [SND-03](#snd-03), [SND-04](#snd-04), [SC-07](#sc-07), [TH-17](#th-17), [TH-29](#th-29), [TH-31](#th-31). **Blocking questions:** [Q-E01](#q-e01), [Q-E03](#q-e03), [Q-P31](#q-p31). Gate: Q-E01 native slice and Andrew's production authorization (TRACKING EV-0423 decision 1). **Registered non-blocking questions:** [Q-E06](#q-e06).

**Files touched:** `native/content/fuse/assets/audio/**` and `native/content/iron_orchard_enemies/assets/audio/**` (inputs with `.import` sidecars; DQ-01 Audio amendment); `source-assets/fuse/audio/import/**` and `source-assets/iron_orchard_enemies/audio/import/**` (recipes and provenance links); `artifacts/local/tasks/SND-05/`.

**Definition of done:**

1. TH-19 IG-01 to IG-07 are closed with named evidence before staging (TH-19 AG-01).
2. Each audio input is exported from its master by a recorded recipe, with its sidecar committed and reviewed as bytes (TH-19 IS-01, SI-01).
3. Every manifest entry reaches its provenance and notice obligation (TH-19 EM-02, NO-04).
4. No cue fact becomes durable (PD-03 SI-04).

**Verification and evidence:** Automated native: import and validation of a staged copy by the handoff's commands. Static: sidecars tracked, provenance complete. Human review record: Andrew's listening review of the imported cues, recorded as one listener's opinion. Not established: PD-03 AU-01 to AU-06, PD-03 FT-01 and FT-02, playback hardware or the mix. Human-hands steps: Andrew records Godot execution authorization; Andrew's listening review.

**Boundary:** As ART-17. No cue definitions, which belong to SC-07. No bus or mix. Re-size check: split by owner unit if the Q-P31 answer's batch exceeds one M card.

## Proposed register entry

Proposed for the coordinator's definition import; the ID is the next free number after the register's last entry and is the coordinator's to confirm. It replaces A1's drafting question DQ-04 (review R1 B4) and carries Andrew's approach-level answer (TRACKING EV-0447 decision 3).

<a id="q-p42"></a>

### Q-P42 (proposed): Enemy family motion treatment

**Source:** BACKLOG Q-P27's missing information names the selected mech only; TRACKING EV-0372 recorded the hybrid treatment for the mech and nothing for enemies; TH-03 EP-01 and AO-01.

**Missing information:** The approach is recorded at TRACKING EV-0447 decision 3: hybrid, with procedural locomotion and turning in Godot and hand-keyed Blender wind-up and attack clips. Still missing: for each family member, which motions are procedural and which are keyed, recovery included, and which parts are stable.

**Decision owner:** Andrew

**Affected work:** The parameter rows of ART-23 and ART-29, and through them ART-24 and SND-04.

**Evidence needed to close:** A recorded selection per family member naming the treatment for each attack stage, with poses still presenting the declared geometry and never advancing a window.
