#!/usr/bin/env bash

set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"

role="" wave="" unit="" cwd="" brief=""
add_dirs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --role) role="$2"; shift 2 ;;
    --wave) wave="$2"; shift 2 ;;
    --unit) unit="$2"; shift 2 ;;
    --cwd) cwd="$2"; shift 2 ;;
    --brief) brief="$2"; shift 2 ;;
    --add-dir) add_dirs+=("$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$role" ] || [ -z "$wave" ] || [ -z "$unit" ] || [ -z "$cwd" ] || [ -z "$brief" ]; then
  echo "missing a required argument" >&2
  exit 2
fi
if [ ! -f "$brief" ]; then
  echo "brief not found: $brief" >&2
  exit 2
fi
if [ ! -d "$cwd" ]; then
  echo "cwd not found: $cwd" >&2
  exit 2
fi

case "$role" in
  write) model="gpt-6.1-sol"; sandbox="workspace-write" ;;
  verify) model="gpt-6-astra"; sandbox="workspace-write" ;;
  judge) model="gpt-6.1-sol"; sandbox="read-only" ;;
  *) echo "unknown role: $role" >&2; exit 2 ;;
esac

out="$repo/artifacts/local/alpha/push/$wave/$unit/$role"
mkdir -p "$out"

prompt="$out/prompt.md"
if [ "$role" = "verify" ]; then
  python3 -I - "$repo/.codex/agents/scrapkeep-verifier.toml" > "$prompt" <<'EOF'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    print(tomllib.load(f)["developer_instructions"])
EOF
  printf '\n\n---\n\n' >> "$prompt"
  cat "$brief" >> "$prompt"
else
  cp "$brief" "$prompt"
fi

cmd=(codex exec --skip-git-repo-check -C "$cwd" -m "$model"
  -c 'model_reasoning_effort="high"' -c "service_tier=\"${SOL_TIER:-priority}\""
  -s "$sandbox" -o "$out/report.md")
for d in "${add_dirs[@]}"; do
  cmd+=(--add-dir "$d")
done
cmd+=(-)

printf '%q ' "${cmd[@]}" > "$out/cmd.txt"
echo >> "$out/cmd.txt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$out/started"

"${cmd[@]}" < "$prompt" > "$out/run.log" 2>&1
code=$?
echo "$code" > "$out/exit"
date -u +%Y-%m-%dT%H:%M:%SZ > "$out/finished"

{
  echo "unit $unit role $role wave $wave exit $code"
  echo "started $(cat "$out/started") finished $(cat "$out/finished")"
  grep -m3 -E '^(model|reasoning effort|session id):' "$out/run.log"
  echo "receipts $out"
  echo "--- report tail"
  if [ -f "$out/report.md" ]; then
    tail -n 40 "$out/report.md"
  else
    echo "(no report written)"
    tail -n 20 "$out/run.log"
  fi
} > "$out/summary.txt"
cat "$out/summary.txt"
exit "$code"
