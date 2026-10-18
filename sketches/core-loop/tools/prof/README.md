# Headless per-function GDScript profiler

Godot's script profiler only reports to a remote debugger. `listen.gd` is a minimal debugger
client: it listens on 127.0.0.1:6007, turns on the `servers` profiler (up to 1,024 functions
a frame) and writes each decoded message to `$PROF_OUT`. `agg.py` sums self and total time
per function over the last N frames.

    PROF_OUT=/abs/raw.txt godot --headless --path tools/prof --script res://listen.gd &
    sleep 3
    godot --headless --path . --remote-debug tcp://127.0.0.1:6007 --script res://tools/perf_bench.gd -- --scene=s3 --out=/abs/s3.json
    python3 tools/prof/agg.py /abs/raw.txt 600 50

The profiler roughly doubles frame time, so read the ranking, not the absolute numbers.
`tools/prof` has its own project.godot so the listener never loads the game.
