# W1-143b at the Spillway stage of 18 November

Draft #1153 at `3266114510b51a744f9e363c9d3fe9c78aa0b4e4` includes stage `3cafd8fa3962934e11ba89c439b3af943dba5d8d`. The wider census passed all 71 checks across 43 stations. It found zero unlisted keys and 78 observations of trade counters held under ruling ci. Both plant runs named the planted box. The separate ride guard failed on both commits. [Census by scope and plant](census.json)

The stage and draft had exactly the same 132 ride keys. Four keys came from three reward gates. During physics tick 11911, the gates had 13 primitive meshes. All three matched a live offer at zero distance. By the start of idle processing on that same tick, all three had their authored arch and topper, with zero visible primitive meshes. This establishes the order of scene updates in the headless ride. The guard still reports the four keys. [Shared key set](ride-keys.tsv) · [Matched physics and idle samples](reward-gate-ticks.json)

The legacy ride also counts a sphere inside a closed pause menu. In a separate sitting launch, the sphere was visible inside its own 3D viewport while five enclosing UI nodes were hidden. Opening Pause fitted HeroCore and hid the sphere. The station scan counted zero spheres in both states. [Closed and open pause samples](pause-sphere.json)

The complete receipt producer refused the untracked Godot sidecars for `src/world/park/footings.gd` and `src/world/park/regions.gd`. The direct test results above use the project solo runner. All eight focused scripts passed on the merged draft. The existing clip test skipped both missing fin controls. All 60 selected fast tests passed. The isolated fast checkout named the verified stage SHA locally as `stage/alpha-w44`. [Focused suite](focused.json) · [Fast check](fast.json)

## Pictures and measurements for Sol

The probe starts the sitting-earned profile on the park table and fixes the place stations at seed 280928. Round 0 produced zero post rows or furnaces on either map. With both options explicitly enabled, the dam built two five-post rows, and the flume built one row and the furnace. With calm mode enabled, both places disappeared again. The current look harness enables calm at boot. Capturing these sites requires the normal stage build with calm off. The saved coordinates and headings locate the first row of each stage, the flume weighbridge and the furnace foot. Pixel visibility is still unmeasured. [Station coordinates and option controls](place-stations.json)

Four real Foundry Cutter presses covered the default and calibrated shells with both landing and flight cancellation after peak. All four reached ult_strike in flight. Both fin controls were missing in every fitted cutaway. The probe reads the signed targets from Rivet's machinery table, samples the first presentation update after peak, and checks rest after the ride. A missing bone yields a null angle and a failed check. The proposed cloud rig also needs a check of the physical outward swing and the fin rectangle against measured image noise. [Four trial results](fin-rides.json) · [Cloud recipe](../cloud/README.md)

Before READY, the card owner gives a separate GPT-6.2 Sol the blind pairs, round numbers and done-when. The pair set needs the following views on High and Low, with the same station, seed, tick and camera on both revisions.

| Subject | View and question | Measure |
| --- | --- | --- |
| Survey posts | Frozen place board, plan, rider entry and rider exit. Can a rolling rider see the row and pass it at speed? | Sitting launch, seen.post at least 0.2. |
| Bowl approach smoke | Frozen place board, flume approach from the route. Does the furnace lead the rider toward the bowl? | Sitting launch, seen.smoke at least 0.2. |
| Rivet | Rider strip over the real Foundry Cutter peak, with both fin tips in the measured rectangle, plus their return. Do the two leaves open outward? | Each fitted bone reaches its signed recipe angle at peak. Fin rectangle moves by more than station noise. |
| Replacements in the census | Configured flood mast and basin, the pilot-card practice yard, and the moving sluice front, at each replaced stand-in's station. The occurrence ledger identifies the remaining menu, camp, event and ending contexts. | Per-subject rectangle and guard noise, complete census and models-render. |

Sol judges landmark and route readability under ct, slowing and rolling under cu, continuity under cv, and the legibility of the visual cues under cx. Record the images Sol opened, its actual model and effort, and its verdict on the PR. The Gate's Claude reviewer handles admission. [Gate ruling](https://github.com/bananahana720/scrapkeep/issues/1106#issuecomment-6990045175) · [Occurrence ledger](../occurrence-results.tsv)

To repeat a probe, run Node on the proof branch's `b/run-probe.mjs` from the game revision under test, with `GODOT_BIN` set to the Godot 4.7.2 executable. Choose `places`, `gates`, `pause` or `fins`. For fins use the default or `FIN_VARIANT=shell_rivet_calibrated`, each with `FIN_EXIT=land` and `FIN_EXIT=bail`. The runner uses headless Godot at 90 Hz with a fresh scratch home for every invocation.
