#!/usr/bin/env bash
job="$1"
f=""
for i in $(seq 1 30); do
  f=$(ls /home/andrew/.claude/plugins/data/codex-openai-codex/state/*/jobs/"$job".json 2>/dev/null | head -1)
  if [ -n "$f" ]; then
    break
  else
    sleep 2
  fi
done
if [ -z "$f" ]; then
  echo "job file for $job not found"
  exit 1
fi
pid=$(python3 -c "import json;print(json.load(open('$f')).get('pid') or '')")
if [ -n "$pid" ]; then
  while kill -0 "$pid" 2>/dev/null; do
    sleep 30
  done
fi
python3 -c "import json;d=json.load(open('$f'));print(d.get('status'),d.get('phase'));print((d.get('result') or {}).get('rawOutput','')[-3500:])"
