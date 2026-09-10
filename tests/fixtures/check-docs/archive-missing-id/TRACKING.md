# Fixture tracking

## Task state index

| Task ID                   | Card rev | Record rev | State  | Blockers / admission | Accepted attempt | Last event |
| ------------------------- | -------- | ---------- | ------ | -------------------- | ---------------- | ---------- |
| [HF-01](BACKLOG.md#hf-01) | 1        | 1          | queued | none                 | none             | EV-0001    |
| PS-01 (interim)           | interim  | 1          | queued | none                 | none             | EV-0099    |

## Question state index

| Question                  | Record rev | State | Answer / evidence | Last event |
| ------------------------- | ---------- | ----- | ----------------- | ---------- |
| [Q-E01](BACKLOG.md#q-e01) | 1          | open  | none              | EV-0001    |

## Append-only events

| Sequence | UTC timestamp             | Actor / kind          | Affected records | Change and evidence |
| -------- | ------------------------- | --------------------- | ---------------- | ------------------- |
| EV-0002  | 2026-09-06T00:00:01+00:00 | Coordinator / interim | PS-01            | interim row         |

## Notes

EV-0001 resolves from the archive, but EV-0099 exists in no checked source, so
the PS-01 row must still fail as unresolvable.
