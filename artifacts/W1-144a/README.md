# W1-144a headless evidence and probe controls

The instrumented seed-1 ride on stage 1d5d77fc6 won after crossing both exits. Its flume entry tick was 50.741 ms, and its boss entry tick was 26.182 ms. The headless renderer produced no draw samples. The two frame excerpts are in `transition-frames.ndjson`. The slow signal handlers from this run are in `entry-1.ndjson`.

The new probe at c63c4e15d diagnoses drawn captures separately. Run `python3 artifacts/W1-144a/check-inputs.py` from the root of this proof branch to exercise both handover windows and the shutdown reader on controlled inputs. `focused.log` gives the observed results. Each zero means a pass, each one a measured failure, and each two missing or ambiguous evidence. The clean-shutdown control records the actual process exit in operational use. Its fixture deliberately truncates the stream to prove that an incomplete log cannot pass. A matched cold run on the same machine and commit must accompany any graded warm run.

## Headless runs

Use Godot 4.7.2 on the Mac, prepare the checkout with `node scripts/import-stamp.mjs import`, and give every child its own scratch HOME, XDG data and config under `artifacts/local/`. All game launches here use `--headless`.

The full ride used `--fixed-fps 90 --path sketches/core-loop --script res://tools/bot_run.gd`. The user arguments were `--out=<absolute scratch ride directory> --seeds=1 --policy=skipper --pilot=pylon_engineer --table=park --threaded-stages=1 --warm-band=1 --profile=sitting --frame-log=1 --entry-profile=1 --frame-split=1 --ticks=68000`. Put new output in `artifacts/local/W1-144/ride` to read it with `split.py`. Seed-1 timings can vary with worker scheduling.

Two shorter experiments drove the real flow directly. To repeat them, copy `transition-control.gd` and `prepared-entry.gd` from this directory to `artifacts/local/W1-144/`, then run `run-controls.py` and `profile-entry.py` from the repo root with Python. The first ran an ordinary entry and a second entry with a 50 ms sleep on each game event. The two text files retain the measured callback durations. These are forced-entry controls. The flume can still be building when a forced entry begins. The second experiment waited for flume terrain readiness, then attached the project's script profiler. `forced-entry-profile.json` lists the functions recorded in each entry frame. Nested and concurrent function times overlap.

## Open evidence

The warm off-screen Metal capture, its matched cold pass, the drawn 50 ms plant, and a source-level failing check for each confirmed cause are still due on the live stage. The draft PR holds the round record and links to the earlier teardown comparison.
