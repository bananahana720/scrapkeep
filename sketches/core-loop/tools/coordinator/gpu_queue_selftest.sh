#!/usr/bin/env bash
set -uo pipefail
q="$(dirname "$(readlink -f "$0")")/gpu_queue.sh"
fail=0

pair_wall() {
	local a=$1
	local b=$2
	local flag=$3
	local t0
	t0=$(date +%s.%N)
	if [ -n "$flag" ]; then
		bash "$q" --gpu "$a" --need 100 --name selftest-a "$flag" -- sleep 8 &
		pa=$!
		bash "$q" --gpu "$b" --need 100 --name selftest-b "$flag" -- sleep 8 &
		pb=$!
	else
		bash "$q" --gpu "$a" --need 100 --name selftest-a -- sleep 8 &
		pa=$!
		bash "$q" --gpu "$b" --need 100 --name selftest-b -- sleep 8 &
		pb=$!
	fi
	wait "$pa"
	wait "$pb"
	awk -v s="$t0" -v e="$(date +%s.%N)" 'BEGIN { printf "%.1f", e - s }'
}

check() {
	local label=$1
	local wall=$2
	local op=$3
	local limit=$4
	local ok
	ok=$(awk -v w="$wall" -v l="$limit" -v o="$op" 'BEGIN { if (o == "lt") print (w < l) ? 1 : 0; else print (w >= l) ? 1 : 0 }')
	if [ "$ok" -eq 1 ]; then
		echo "PASS $label wall=${wall}s"
	else
		echo "FAIL $label wall=${wall}s (need $op $limit)"
		fail=1
	fi
}

w=$(pair_wall 0 1 "")
check "different cards overlap" "$w" lt 12
w=$(pair_wall 1 1 "")
if [ "$(awk -v w="$w" 'BEGIN { print (w > 30) ? 1 : 0 }')" -eq 1 ]; then
	echo "same-card first wall ${w}s above 30 s (sibling lock holds); rerunning"
	w=$(pair_wall 1 1 "")
fi
check "same card serializes" "$w" ge 16
w=$(pair_wall 1 1 --shared)
check "shared pair overlaps" "$w" lt 12
if [ "$fail" -eq 0 ]; then
	echo "PASS selftest"
fi
exit "$fail"
