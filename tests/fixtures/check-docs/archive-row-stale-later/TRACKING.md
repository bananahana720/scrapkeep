# Fixture tracking

## Task state index

| Task ID                   | Card rev | Record rev | State  | Blockers / admission | Accepted attempt | Last event |
| ------------------------- | -------- | ---------- | ------ | -------------------- | ---------------- | ---------- |
| [HF-01](BACKLOG.md#hf-01) | 1        | 2          | review | none                 | HF-01-A1         | EV-0001    |
| PS-01 (interim)           | interim  | 1          | queued | none                 | none             | EV-0003    |

## Question state index

| Question                  | Record rev | State | Answer / evidence | Last event |
| ------------------------- | ---------- | ----- | ----------------- | ---------- |
| [Q-E01](BACKLOG.md#q-e01) | 1          | open  | none              | EV-0001    |

## Append-only events

| Sequence | UTC timestamp             | Actor / kind           | Affected records | Change and evidence |
| -------- | ------------------------- | ---------------------- | ---------------- | ------------------- |
| EV-0002  | 2026-09-06T00:00:01+00:00 | Coordinator / handoff  | HF-01            | handoff             |
| EV-0003  | 2026-09-06T00:00:02+00:00 | Coordinator / interim  | PS-01            | interim row         |

## Notes

This is the post-split shape: HF-01's row points into the archive at EV-0001,
while EV-0002, which also names HF-01, stayed on the board, so the row is stale
even though its Last event resolves.
