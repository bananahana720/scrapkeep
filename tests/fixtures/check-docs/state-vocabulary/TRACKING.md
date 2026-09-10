# Fixture tracking

## Task state index

| Task ID                   | Card rev | Record rev | State             | Blockers / admission | Accepted attempt | Last event |
| ------------------------- | -------- | ---------- | ----------------- | -------------------- | ---------------- | ---------- |
| [HF-01](BACKLOG.md#hf-01) | 1        | 1          | queued            | none                 | none             | EV-0001    |
| PS-01 (interim)           | interim  | 1          | blocked           | none                 | none             | EV-0002    |
| PS-02 (interim)           | interim  | 1          | ready             | none                 | none             | EV-0003    |
| PS-03 (interim)           | interim  | 1          | in_progress       | none                 | none             | EV-0004    |
| PS-04 (interim)           | interim  | 1          | review            | none                 | none             | EV-0005    |
| PS-05 (interim)           | interim  | 1          | changes_requested | none                 | none             | EV-0006    |
| PS-06 (interim)           | interim  | 1          | done              | none                 | none             | EV-0007    |
| PS-07 (interim)           | interim  | 1          | parked            | none                 | none             | EV-0008    |
| PS-08 (interim)           | interim  | 1          | cancelled         | none                 | none             | EV-0009    |

## Question state index

| Question                  | Record rev | State | Answer / evidence | Last event |
| ------------------------- | ---------- | ----- | ----------------- | ---------- |
| [Q-E01](BACKLOG.md#q-e01) | 1          | open  | none              | EV-0001    |

## Append-only events

| Sequence | UTC timestamp             | Actor / kind                          | Affected records                                                        | Change and evidence |
| -------- | ------------------------- | ------------------------------------- | ----------------------------------------------------------------------- | ------------------- |
| EV-0001  | 2026-09-06T00:00:00+00:00 | Coordinator / import                  | HF-01                                                                   | imported            |
| EV-0002  | 2026-09-06T00:00:01+00:00 | Coordinator / block                   | PS-01                                                                   | blocked             |
| EV-0003  | 2026-09-06T00:00:02+00:00 | Coordinator / readiness               | PS-02                                                                   | ready               |
| EV-0004  | 2026-09-06T00:00:03+00:00 | Coordinator / assignment and lease    | PS-03                                                                   | assigned            |
| EV-0005  | 2026-09-06T00:00:04+00:00 | Coordinator / handoff                 | PS-04                                                                   | handoff             |
| EV-0006  | 2026-09-06T00:00:05+00:00 | Coordinator / review verdict          | PS-05                                                                   | changes requested   |
| EV-0007  | 2026-09-06T00:00:06+00:00 | Coordinator / integration             | PS-06                                                                   | integrated          |
| EV-0008  | 2026-09-06T00:00:07+00:00 | Coordinator / park                    | PS-07                                                                   | parked              |
| EV-0009  | 2026-09-06T00:00:08+00:00 | Coordinator / cancel                  | PS-08                                                                   | cancelled           |
| EV-0010  | 2026-09-06T00:00:09+00:00 | Coordinator / authorization           | foundation-full, HF-01, PS-01, PS-02, PS-03, PS-04, PS-05, PS-06, PS-07, PS-08 | authorized          |

## Notes

Every vocabulary member is exercised, and the last event is a program-level
authorization that names all nine records without changing any of their rows.
