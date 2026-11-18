# W1-144 watched handovers on the Mac

The game is stage `3cafd8fa3962934e11ba89c439b3af943dba5d8d`. Probe revision `13c9e4748` uses Godot 4.7.2 on the M5 Max, the embedded Metal display at 1920 × 1080, Forward+, High, Dummy audio and synthesized music. Both passes use seed 1, pylon engineer, skipper, the sitting profile, the park table, Tripo models and the cutaway ball. One Godot process plays a cold game to victory, releases that scene and plays a fresh game against the same renderer and scratch home. The second ride is graded. A drawn interval belongs to a handover if it overlaps the second before entry or the five seconds after it. The ceiling is 33.3 ms.

## Repeat the capture

Use the qualified version of the probe, the launcher and the pinned Mac editor. Set `GODOT_BIN` to the editor executable. The launcher supplies an isolated home, takes the exclusive drawn slot and holds the machine quiet for the timed rides. Run outside a wave gate, export or band capture.

```sh
node scripts/gate/display-run.mjs --offscreen res://tools/handover_capture.gd -- \
  --self-play --self-play-watch=1 --self-play-until=win --self-play-seed=1 \
  --self-play-pilot=pylon_engineer --self-play-policy=skipper --self-play-min=650 \
  --table=park --models=tripo --profile=sitting --ball-look=cutaway --preset=high \
  --fullscreen=0 > round.log 2>&1
status=$?
echo "DISPLAY_RUN_EXIT $status" >> round.log
node scripts/handover-frame-probe.mjs native round.log
```

Add `--w144-plant` to the fixed game arguments to sleep 50 ms at each warm handover. The additional `--w144-victory-flood` releases the flood warning light after the warm timing windows and after the victory record. Its shutdown is a separate diagnostic. The grader reports both the maximum within each window and the interval containing the entry signal. It refuses a budget verdict for an instrumented ride or a broken watcher trace. Captures with the original ten-minute timeout are historical preflights.

## Shutdown controls

The unmodified dam checkpoint produces two light-unpair errors. Releasing all lights moves both errors before quit. Releasing only the flood warning light, with every other light still in the scene, produces both at that release. The game creates the lamp in `sketches/core-loop/src/world/flood.gd:54`. The renderer reports `instance_set_scenario` and `instance_set_base` in `renderer_scene_cull.cpp`. The earlier flood-water change on PR #1127 concerns a different node.

Releasing every live GPU emitter or the whole game scene at the dam still leaves eight particle shaders and eight matching shader RIDs at quit. An empty scene and a scene containing one default GPU emitter both exit cleanly. Read the entries in `shutdown-controls.json` for the engine write order. The compressed logs keep the node inventories and detailed backtraces. `qualification.json` links the script digest, watcher counts and dead-frame measurement to `qualification.png`.

## What the controls establish

On the uninstrumented warm ride, dam-to-flume entry took 72.018 ms and the following drawn frame took 45.414 ms. A second unplanted ride found the same two long frames, 72.001 and 45.737 ms. Bowl entry was 19.825 and 18.889 ms respectively. The explicit 50 ms sleep raised the warm entry frames to 124.804 ms and 77.784 ms. The repeat with the post-victory lamp release has `planted: false`; the actual sleep control has `planted: true`. Each file retains the cold ride, warm ride and watcher receipt.

The separate profiler instruments the warm ride. Its repeated run passed the watcher after the first attempt missed five samples. The traced flume entry frame took 125.23 ms, added 446 nodes and freed 1,420. The largest measured stage-entry handler was `src/build/build.gd:1032` at 16.92 ms. ParkProps processing occupied 17.15 ms, audio processing 6.96 ms and the draw phase 6.94 ms. The following 96.51 ms frame removed 547 more nodes. These measurements locate work on both sides of the crossing. Profiler overhead changes the absolute frame time, and the measurements can overlap. A counterfactual that moves one piece of work while preserving all content is needed to establish its contribution to the uninstrumented 72 ms frame. The earlier report also describes multiple contributors. [Previous Mac investigation](https://github.com/bananahana720/scrapkeep/pull/1116)

After a warm victory the probe released only the Flood warning lamp, while leaving every other light in the scene. Both light-unpair errors occurred between the release markers. The full log is `repeat-victory-flood.log.gz`. A separate verbose dam run freed the entire scene and listed the surviving object classes at shutdown. No particle emitter or particle process material appeared in that list, while eight shader RIDs survived. The full-ride count varied from 21 to 23. An upstream report for the same Godot binary describes a particle-material shader-cache lookup that loses a shader even when all materials were destroyed. This remains a candidate explanation for Scrapkeep. A matched three-material case and the game’s own particle factories would distinguish it from a separate renderer lifetime issue. [Verbose object counts](quit-game-verbose.json) · [Upstream three-material control](https://github.com/godotengine/godot/issues/93344#issuecomment-6502639091) · [Pinned-version cache report](https://github.com/godotengine/godot/issues/125235)

## Updated game stage

After the Gate admitted the world-one hazard changes, the unchanged probe was rerun on `6b50426f9`, which includes `stage/alpha-w44` at `4f9017c58`. The warm dam-to-flume entry interval reached 133.841 ms. At the bowl the entry interval was 26.626 ms and the window maximum was 29.982 ms. Shutdown again reported both light-unpair errors, 21 unfreed particle shaders and 21 corresponding shader RIDs. The watcher counted 16,617 samples, zero missed, zero on-screen and zero focus changes. The stage change includes hazard and combat changes, so the increase cannot be attributed to any one of those changes. The later stage `f28fff6df` changed only release-tally scripts, tests and Gate documentation.
