# Fixture tracking

## Task state index

| Task ID                   | Card rev | Record rev | State  | Blockers / admission | Accepted attempt | Last event |
| ------------------------- | -------- | ---------- | ------ | -------------------- | ---------------- | ---------- |
| [HF-01](BACKLOG.md#hf-01) | 1        | 1          | queued | none                 | none             | EV-0001    |
| PS-01 (interim)           | interim  | 1          | queued | none                 | none             | EV-0001    |

## Question state index

| Question                  | Record rev | State | Answer / evidence | Last event |
| ------------------------- | ---------- | ----- | ----------------- | ---------- |
| [Q-E01](BACKLOG.md#q-e01) | 1          | open  | none              | EV-0001    |

## Append-only events

| Sequence | UTC timestamp             | Actor / kind             | Affected records | Change and evidence |
| -------- | ------------------------- | ------------------------ | ---------------- | ------------------- |
| EV-0001  | 2026-09-06T00:00:00+00:00 | Coordinator / assignment | HF-01            | assigned            |

## Notes

HF-01's row points at EV-0001, but EV-0002 names HF-01 as well and lives in the
archive file, so the stale-row rule has to read across the boundary.
