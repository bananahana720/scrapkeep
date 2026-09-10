# Fixture tracking

## Task state index

| Task ID                   | Card rev | Record rev | State  | Blockers / admission | Accepted attempt | Last event |
| ------------------------- | -------- | ---------- | ------ | -------------------- | ---------------- | ---------- |
| [HF-01](BACKLOG.md#hf-01) | 1        | 1          | queued | none                 | none             | EV-0001    |
| PS-01 (interim)           | interim  | 2          | queued | none                 | none             | EV-0003    |

## Question state index

| Question                  | Record rev | State | Answer / evidence | Last event |
| ------------------------- | ---------- | ----- | ----------------- | ---------- |
| [Q-E01](BACKLOG.md#q-e01) | 1          | open  | none              | EV-0001    |

## Append-only events

| Sequence | UTC timestamp             | Actor / kind                   | Affected records | Change and evidence |
| -------- | ------------------------- | ------------------------------ | ---------------- | ------------------- |
| EV-0001  | 2026-09-06T00:00:00+00:00 | Coordinator / assignment       | HF-01            | assigned            |
| EV-0002  | 2026-09-06T00:00:01+00:00 | Coordinator / checkpoint       | HF-01            | checkpoint          |
| EV-0003  | 2026-09-06T00:00:02+00:00 | Coordinator / review admission | PS-01            | integrated          |

## Notes

The delivered HF-01 handoff is EV-0002; the row still points at its assignment
EV-0001, the stale-row shape the HF-05 recovery recorded. Prose after the table.
