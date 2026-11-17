# Hand off the Spillway visual and map work

Start with the dam camera. Then judge Brindle contact on that camera revision. The wave marks and reward signs have separate owners and can proceed independently. For terrain or encounter changes, first compare the overhead route with the same decision at riding height. [Audit and baseline frames](README.md) · [Top-down map brief](MAP-DESIGN.md)

## Assign one outcome to each writer

These are proposed assignments for the coordinator to select against the current stage. Each linked spec contains the scene, source owner, design direction, dependencies, regression cases and evidence to return. Read [STATE](../../../STATE.md) before claiming a file.

| Writer | Deliverable | Coordination |
| --- | --- | --- |
| Camera | [See the floor at the dam Warden](tasks/dam-camera.md) | First camera change. Leave the open-space profile and aim controls as comparisons. |
| Boss presentation | [Recover the view under Brindle](tasks/brindle-camera.md) | Use the dam camera result. Check the current boss lead from [PR 1122](https://github.com/bananahana720/scrapkeep/pull/1122). |
| Combat VFX | [Keep reinforcement marks clear of live attacks](tasks/reinforcement-marks.md) | Yard and overtime share the same mark. The spec includes a concept plate. |
| Reward UI | [Keep the offer attached to its arch at the screen edge](tasks/reward-signs.md) | One writer owns gate layout and the handover from field tips. |
| Performance | [Attribute the repeated long frames](tasks/frame-pacing.md) | Coordinate with [PR 1116](https://github.com/bananahana720/scrapkeep/pull/1116). Use an idle machine for measurements. |
| Dam level design | [Make the fork at the Eye readable at speed](tasks/dam-route.md) | Compare against the water treatment in [PR 1120](https://github.com/bananahana720/scrapkeep/pull/1120). Coordinate the approach replay with the camera writer. |
| Flume level design | [Distinguish the upper carry from the lower return](tasks/flume-route.md) | Reconcile with the climb in [PR 1119](https://github.com/bananahana720/scrapkeep/pull/1119) before editing the flume or its graph. |
| Arena level design | [Orient the rider on the bowl entry tangent](tasks/bowl-route.md) | Use the boss writer’s charge evidence. Coordinate any hazard interaction with [PR 1123](https://github.com/bananahana720/scrapkeep/pull/1123). |
| Encounter design | [Curate the first decision in each wave](tasks/encounter-curation.md) | Preserve counts for the baseline. Share one route and encounter recording with the director writer. |
| Spawn placement | [Give arrivals a visible approach](tasks/spawn-approaches.md) | Separate ordinary director packs, authored homes, rotating yard waves and overtime. |
| Enemy art and animation | [Read body, tool and commitment in motion](tasks/enemy-motion.md) | Start with one of the [six captured machines](CREW-POSES.md). Compare script and clip poses at the same attack phase. |
| Traversal | [Grapple into a bank and roll out at speed](tasks/grapple-roll.md) | Select one park field. Coordinate with its level designer before moving a solid or baking a graph. |
| Enemy behavior | [Compare three ways to challenge a bowling pilot](tasks/fast-pack.md) | Run the existing flanker against stock first. Compare a bank-covering lobber and a bowl-through boom in separate encounters. |

## Pick the first experiment

The filmed camera, wave-mark and reward failures can go straight to reproduction. The roster and traversal proposals need a baseline for each named site. Pair the **fast pack** and **grapple line** baselines on the same route so both writers can see the moving player’s choice. Stage implementation one variable at a time. The frame-pacing writer can work independently on an idle machine. [Enemy roles by site](ENCOUNTERS.md)

The design sheets use OpenAI ImageGen for composition, pose and movement ideas. Terrain coordinates, attachment range, damage shapes, UI copy and timing come from game data. Each assignment names a chase-camera view for player judgment and a second view for diagnosis. The performance card uses measured frame intervals. The [map plans](MAP-DESIGN.md), [Godot pose gallery](CREW-POSES.md) and [film run](README.md) supply the comparisons.

## Replay the route

1. Record the candidate SHA and open stage. The baseline is `bf80564798868331c1d86bc51939d97d305abcaf`. Import the checkout with `node scripts/import-stamp.mjs import`. Use the Godot 4.7.2 executable specified in [DEVICES](../../../DEVICES.md).
2. On the Mac, run the command below from the repo root with `GODOT_BIN` set to the absolute executable path. Each run gets fresh save data. On the Gate PC use the supported scratch launcher and its safety check, with the same game flags. The baseline uses a fixed simulation rate and live drawing. Use the separate frame-time command in the performance spec for wall-clock measurements.

```sh
mkdir -p artifacts/local
capture=$(mktemp -d "$PWD/artifacts/local/w44-visual-XXXXXX")
mkdir -p "$capture/home" "$capture/film"
HOME="$capture/home" "$GODOT_BIN" --path sketches/core-loop \
  --audio-driver Dummy --resolution 1280x720 --fixed-fps 30 --disable-vsync -- \
  --table=park --models=tripo --ball-look=cutaway --profile=sitting --preset=high \
  --self-play --self-play-keys=1 --self-play-eyes=1 --self-play-watch=1 \
  --self-play-seed=1 --self-play-pilot=pylon_engineer --self-play-policy=skipper \
  --self-play-until=win --self-play-hold=1 --self-play-stall=150 \
  --self-play-film-live=1 --self-play-film-every=4 --self-play-film="$capture/film"
```

3. Match by stage, event, pose and contacted body. Clock times and filenames can drift between builds. The [baseline manifest](../../../../../artifacts/visual-audit-w44/evidence/film.ndjson) retains all 255 original frame names and readings. The repo includes the selected frames used in the report. Controlled 90 Hz attack and turn fixtures and warm wall-clock passes have their own [measurements](../../../../../artifacts/visual-audit-w44/evidence/measurements.json).
4. Run each focused test named in the spec with `npm run sketch:smoke -- --sketch core-loop --test <name>`. Run `npm run sketch:fast -- --base <open-stage>` and obtain independent review for a game change. Return the source SHA, machine, settings, before/after pictures, measurements and any failed control. Store disposable captures under `artifacts/local/` and publish the selected evidence with the writer’s draft PR.

The Gate owns admission, difficulty-band decisions and the release film. These targeted replays can guide a design decision. The sitting supplies the human judgment about feel. [Gate and film rules](../../../GATE.md)
