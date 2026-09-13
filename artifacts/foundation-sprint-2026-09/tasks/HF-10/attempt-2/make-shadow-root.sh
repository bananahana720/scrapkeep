#!/usr/bin/env bash
# Rebuild the symlink shadow root used to rerun HF-01/check-coverage.py and
# HF-02/check-register.py. Both read pathlib.Path.cwd() and write to a hardcoded
# artifacts/local/tasks/HF-0x/ destination, so they must run with a working
# directory whose artifacts/local is writable and outside the retained tree.
# Usage: make-shadow-root.sh <repo-root> <shadow-root-dir>
set -euo pipefail
ROOT=$(cd "$1" && pwd)
S=$2
rm -rf "$S"; mkdir -p "$S/artifacts/local/tasks/HF-01" "$S/artifacts/local/tasks/HF-02"
for e in $(ls -A "$ROOT" | grep -v '^artifacts$'); do ln -s "$ROOT/$e" "$S/$e"; done
for e in $(ls -A "$ROOT/artifacts" | grep -v '^local$'); do ln -s "$ROOT/artifacts/$e" "$S/artifacts/$e"; done
echo "shadow root at $S"
