#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
wave="$1" unit="$2" wt="$3"
r="$repo/artifacts/local/alpha/push/$wave/$unit/write"
echo "== $unit exit $(cat "$r/exit" 2>/dev/null) $(cat "$r/started" 2>/dev/null) -> $(cat "$r/finished" 2>/dev/null)"
if [ -f "$r/report.md" ]; then
  head -c 900 "$r/report.md" | head -n 6
else
  echo "(no report)"
fi
echo "-- changes (excluding .uid and .import)"
git -C "$wt" status --short -uall | grep -v -E '\.(uid|import)$' | grep -v ' artifacts/' | head -40
echo "-- commits over base: $(git -C "$wt" rev-list --count 955e7e55aa10a69c3d0f6c71d0bd2eb4763c5970..HEAD)"
if [ -d "$wt/artifacts/local/dress-preview/$unit" ]; then
  echo "-- previews: $(find "$wt/artifacts/local/dress-preview/$unit" -name '*.png' | wc -l) png"
else
  echo "-- previews: none"
fi
