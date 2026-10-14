# Ideal dam pilot measurement

Round 8 is a diagnostic measurement. Production remains unadmitted. The real grown pilot breaks in 13.711667 s for seeds 1-4, duplicated; the small pilot breaks in 85.696111 s. Every live cycle lands a qualifying solver contact, with no fight resets. All 16 fight/trace pairs are byte-identical. `ideal-evaluation.json` gives each cycle's waiting, riding, ram approach, live return and contact times.

The Game uses the real park table, calm fixture isolation, Sable's normal input path and owner-derived starting heft. Pulse cadence, live window, reach, gain, posture and all production files remain unchanged. The per-frame cap allows two qualifying contacts on distinct frames in the first live sheet. There is no one-ram-per-cycle cap: 18/90 s are one-ram-per-cycle reference floors, not hard lower bounds. The observed two-cycle grown schedule's final sheet starts at 12 s, and the fourteen-cycle small schedule's final sheet starts at 84 s.

Run new measurements into fresh output directories to preserve these receipts. A case uses the normal Godot script arguments `--out=DIR --size=grown|small --seed=N`, with fixed 90 fps. The original exact invocations and separate XDG directories are retained in each case's `command.json`. The queued batch commands are in `ideal-a-command.json` and `ideal-b-command.json`; their scratch batch helper remains in the assigned round folder. Commands ran on heads 6f9cd68d and 2a74f641 with the same pilot source hash. Only the evaluator changed between those heads.

Evaluate two complete new batch folders with:

```sh
python3 sketches/core-loop/tools/park_reactor_ideal_check.py FIRST SECOND --report=OUTPUT.json
```

Command metadata has different output paths, head identities and wall seconds. Full gameplay records have no excluded fields. Raw identity, independent owner-derived gain checks, six red seeded mutations, restored controls, bands and shipping-default smoke receipts are retained here. Shipping-default smoke still fails the ordinary fight and repeat tests. The complete writer report and final result are in `/home/andrew/scratch/w13/sol/wt-park2-r8/REPORT.md` and `result.json`.
