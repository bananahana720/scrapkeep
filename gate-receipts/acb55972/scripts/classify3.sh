#!/bin/bash
# classify.sh <head worktree> <base worktree> <test>...: rerun each failing test alone on head, then on base.
G=/opt/scrapkeep-toolchain/Godot_v4.7.2-stable_linux.x86_64
H=$1; B=$2; shift 2
OUT=${OUT:-/home/user/scrapkeep/artifacts/local/gate/classify-w18b}; mkdir -p $OUT
verdict() { # dir test label
  XDG_DATA_HOME=$(mktemp -d) timeout 1800 $G --headless --fixed-fps 90 --path $1/sketches/core-loop --script res://tests/$2.gd > $OUT/$2.$3.log 2>&1; local c=$?
  local v=$(grep -E "^$2: (PASS|FAIL)" $OUT/$2.$3.log | tail -1)
  local e=$(grep -cE "^(ERROR|SCRIPT ERROR)" $OUT/$2.$3.log)
  if [ $c -eq 0 ] && [ $e -eq 0 ] && echo "$v" | grep -q PASS; then echo pass; else echo "red(exit=$c errors=$e ${v:-no-verdict})"; fi
}
for t in "$@"; do
  h=$(verdict $H $t head)
  if [ "$h" = pass ]; then echo "$t: head-solo PASS (loaded-lane fail only)"; continue; fi
  b=$(verdict $B $t base)
  echo "$t: head $h | base $b"
done
