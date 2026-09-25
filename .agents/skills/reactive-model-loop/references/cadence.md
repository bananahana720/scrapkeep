# Cadence: blocking lockstep or realtime hold-last-intent

A running system has to decide what happens while the model call is in flight. There are two workable answers. Each buys one property by giving up another, so the choice follows what the run must prove. This page is a tradeoff, not a verdict. Lesson ids point at [the lesson ledger](lessons.md).

## The two modes

**Blocking lockstep.** The system snapshots its state on a fixed schedule, waits for the decision, and applies it at a fixed later tick. Nothing moves while the call is in flight.

**Realtime hold-last-intent.** The system keeps running. It applies the most recent intent until a newer one arrives, and it may interpolate between decisions. Calls run concurrently with the world.

## Tradeoff

| Property | Blocking lockstep | Realtime hold-last-intent |
| --- | --- | --- |
| Reproducibility | Exact in a deterministic mode. The trace depends on state and answers, not on latency. | Not shown. The trace depends on when each answer lands. Recording the tick at which each answer arrived might make it reproducible; that is unmeasured. |
| Replay from cache | Exact. Replay makes zero calls and reproduces the trace. | Unmeasured. Replay would need the recorded arrival tick of every answer as part of its input. |
| Feel | The world stalls for each round trip. | Continuous. Public projects report about 8 to 10 decisions per second (unaudited). |
| Stale answers | None. Each intent applies at a fixed tick. | Answers can arrive stale. A validity and staleness gate must drop them. |
| Call volume | One call per snapshot. | Calls per second times run length, with a concurrency cap. |
| Evidence grade | Evidence, when controls and corpus pass. | Demo, not evidence. |

The rule that follows is a design choice. Evidence runs block. Demos may stream, and every streamed run carries the label "demo, not evidence" wherever it is shown or recorded.

In one lab, blocking lockstep in its deterministic mode gave 360 of 360 identical trace hashes across three repeat sweeps, writer-reported repeat counts (RML-43). In the same lab's stochastic physics mode, about 1 trial in 20 diverged and could flip the outcome. Blocking buys reproducibility only where the world itself is deterministic. A matching hash counts only after a sensitivity control shows it moves when one answer or the schedule changes (RML-45).

The realtime side was never measured in that lab. Its properties above come from public projects and are unaudited.

## Systems that cannot pause

Some systems cannot wait for a decision: a live service, a device, a shared multiplayer world. Evidence for them comes from a simulator, or from a replay of recorded state, run in blocking mode against the same instrument. Treat live runs as field observations: useful for finding cases and checking feel, never a substitute for the blocking evidence run. This is a design choice.

## Build blocking lockstep

This pattern worked in one lab. It is a starting point, not a requirement.

1. Snapshot the state every D ticks. Keep applying the held intent until tick t + k, with k < D. Then the next snapshot always records which intent was held.
2. Block the simulation step with a sleep until the decision arrives. Do not use the engine's pause, which can change physics behaviour on resume.
3. Exchange files in one directory per trial, one writer per file. Write `<name>.tmp`, then rename. Readers ignore `*.tmp`.
4. Hash only the event log for the trace hash. Keep debug views, positions sampled for display and wall-clock values out of the hash.
5. Rank outcomes in a total order, such as stall, then rejected input, then a clean finish or an error, so racing failure paths always resolve one way.

## Build realtime hold-last-intent

These are notes from public projects, all unaudited:

- Run the model loop apart from the game loop, and share state through one owner.
- Gate every answer on validity and age before it executes. One public project pauses when the provider fails instead of acting on a stale answer.
- Keep reflex safety in code: collision stops and close-range reactions never wait for the model.
- Cap concurrent requests and the request rate.
- Show the fallback label and the demo label on screen.
