#!/bin/bash
# Reproduce a terminal Ctrl-C: SIGINT to the whole wrapper process group, twice, one second apart.
WT=/home/andrew/Projects/scrapkeep-wt-PS-05b
OUT=$1
cd "$WT"
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"
setsid npm run playtest:agent -- --output "$OUT" > "$OUT.stdout.log" 2>&1 &
WRAP=$!
for i in $(seq 1 100); do [ -f "$OUT/build.log" ] && break; sleep 0.1; done
sleep ${GAP:-1}
PY=$(pgrep -f "^\S*python3 \S*tools/agent-player/run.py --output" | head -1)
echo "wrapper pid=$WRAP pgid=$(ps -o pgid= -p $WRAP | tr -d ' ') run.py pid=$PY build.log present=$([ -f "$OUT/build.log" ] && echo yes || echo no)"
echo "$(date +%T.%N) send SIGINT #1 to group"; kill -INT -- -$WRAP
sleep ${GAP:-1}
echo "$(date +%T.%N) run.py alive after ${GAP:-1}s: $(kill -0 $PY 2>/dev/null && echo yes || echo no)"
echo "$(date +%T.%N) send SIGINT #2 to group"; kill -INT -- -$WRAP 2>&1 || echo "group already gone"
wait $WRAP; echo "wrapper exit=$?"
echo "run.py still alive: $(kill -0 $PY 2>/dev/null && echo yes || echo no)"
echo "orphans: $(pgrep -f "^\S*python3 \S*tools/agent-player/run.py --output" | tr "\n" " ")"
echo "--- wrapper stdout/stderr"; cat "$OUT.stdout.log"
echo "--- report.json keys"; python3 -c "import json,sys; r=json.load(open('$OUT/report.json')); print(json.dumps({k: r.get(k) for k in ('error','passed','trials','cleanup_errors','desktop','source_unchanged','controller_unchanged')}, indent=1))"
ls "$OUT"
