# Trace the three long frames in the dam fight

**Performance writer · W1-20 and MG-05.** Identify which work coincides with the repeated hitch windows and measure any fix in the same scene. The baseline passes p99 and records three frames over 33 ms on each of two warm passes. [Timing data](../../../../../../artifacts/visual-audit-w44/evidence/measurements.json)

1. Read the current state of [PR 1116](https://github.com/bananahana720/scrapkeep/pull/1116). At the audit date its candidate `645ba4c9` handles music baking in drawn dummy-audio runs, moves Moss’s speech synthesis off the main thread and adds a frame probe. Compare that candidate or its landed successor before assigning another audio patch. The audit used synthesized music. Record the audio driver and whether stems or synthesis actually played.
2. On the Mac, prepare the imported checkout as in the [handoff](../HANDOFF.md). On an idle machine run the command below from the repo root. Save the cold result and use its scratch home for both warm passes. Supply the reused home as `--home=/absolute/path/to/the/cold/run/home` before the separator. Capture base and candidate under the same renderer, resolution, audio content and cache conditions. Use the project’s PC device rules for any Linux measurement. [Device instructions](../../../../DEVICES.md) · [Frame logger](../../../../../../scripts/frametime-check.mjs)

```sh
node scripts/frametime-check.mjs --capture=engine --self-play \
  --self-play-seed=1 --self-play-pilot=pylon_engineer --self-play-policy=skipper \
  --self-play-until=1 --self-play-hold=103 --self-play-watch=1 --warmup=50 --seconds=48 \
  -- --table=park --profile=sitting --models=tripo --ball-look=cutaway --preset=high
```

3. On a build carrying the probe, add `--self-play-probe=<absolute scratch file>` after the separator on a separate diagnostic pass. If allocation churn needs attribution, enable `--self-play-probe-signals=1`. Align the 19–20, 33 and 46 s windows to the logger’s sample start. Compare bot time, draw work, pipeline compilation, added/freed nodes and audio activity where observable. Confirm a candidate cause by varying that work alone.
4. Investigate the two in-play light-unpair errors separately. The pinned backtrace reaches `Natural._end` when it frees a water surface. Reproduce that natural event ending on a drawn build and compare repeated stage entry/exit with one shutdown. Distinguish event cleanup from shutdown-only particle shader/resource messages. Attach a trace if cleanup overlaps a long frame. [Recorded engine backtraces](../../../../../../artifacts/visual-audit-w44/evidence/renderer.log) · [Natural event owner](../../../../../../sketches/core-loop/src/world/events/natural.gd)

**Return** the p50, p99, maximum and every interval above 33 ms for two uninstrumented warm passes. The target is p99 ≤16.7 ms and zero frames over 33 ms in each 48 s window. If the hitches persist, return the trace and the smallest remaining experiment. A Linux result must name the packed build, renderer and device. A Mac result only qualifies the measured Mac scenario.
