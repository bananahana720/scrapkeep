# Fixture tracking

## Task state index

| Task ID                   | Card rev | Record rev | State  | Blockers / admission | Accepted attempt | Last event |
| ------------------------- | -------- | ---------- | ------ | -------------------- | ---------------- | ---------- |
| [HF-01](BACKLOG.md#hf-01) | 1        | 1          | queued | none                 | none             | EV-0001    |
| PS-01 (interim)           | interim  | 1          | queued | none                 | none             | EV-0003    |

## Question state index

| Question                  | Record rev | State | Answer / evidence | Last event |
| ------------------------- | ---------- | ----- | ----------------- | ---------- |
| [Q-E01](BACKLOG.md#q-e01) | 1          | open  | none              | EV-0001    |

## Append-only events

| Sequence | UTC timestamp             | Actor / kind          | Affected records | Change and evidence |
| -------- | ------------------------- | --------------------- | ---------------- | ------------------- |
| EV-0003  | 2026-09-06T00:00:02+00:00 | Coordinator / interim | PS-01            | interim row         |

## Notes

EV-0001 and EV-0002 moved to the archive file. HF-01's index row still cites
EV-0001, which only the archive resolves, and the board's own sequence continues
at EV-0003 after the archived prefix.
