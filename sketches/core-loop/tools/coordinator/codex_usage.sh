#!/usr/bin/env bash
set -u
newest="$(find "$HOME/.codex/sessions" -name 'rollout-*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
if [ -z "$newest" ]; then
  echo "unknown"
  exit 1
fi
block="$(grep -o '"rate_limits":{[^}]*"primary":{[^}]*}' "$newest" | tail -1)"
if [ -z "$block" ]; then
  echo "unknown"
  exit 1
fi
pct="$(printf '%s' "$block" | grep -o '"used_percent":[0-9.]*' | tail -1 | cut -d: -f2)"
resets="$(printf '%s' "$block" | grep -o '"resets_at":[0-9]*' | tail -1 | cut -d: -f2)"
window="$(printf '%s' "$block" | grep -o '"window_minutes":[0-9]*' | tail -1 | cut -d: -f2)"
if [ "${1:-}" = "--percent" ]; then
  echo "${pct:-unknown}"
else
  if [ -n "$resets" ]; then
    resets="$(date -u -d "@$resets" +%Y-%m-%dT%H:%M:%SZ)"
  fi
  echo "used_percent ${pct:-unknown} resets ${resets:-unknown} window_minutes ${window:-unknown} source $(basename "$newest")"
fi
